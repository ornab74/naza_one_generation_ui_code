// LLM-CONTEXT:BEGIN
// FILE: lib/audio/encrypted_voice_cache.dart
// ROLE: Owns authenticated encrypted persistence and recall for generated speech audio.
// DOMAIN: audio
// SECURITY-INVARIANT: Never persist voice bytes outside the unlocked AES-GCM vault; verify request and audio hashes before recall.
// CHANGE-GUARD: Preserve bounded retention, authenticated identity checks, strict WAV validation, and fail-closed parsing.
// DOCS: See /SECURITY.md and /lib/security/secure_database.dart.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../security/secure_database.dart';

/// An authenticated voice artifact recalled from the encrypted vault.
final class NazaCachedVoice {
  const NazaCachedVoice({
    required this.requestHash,
    required this.messageHash,
    required this.audioSha256,
    required this.voice,
    required this.model,
    required this.speed,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.playCount,
    required this.wav,
  });

  final String requestHash;
  final String messageHash;
  final String audioSha256;
  final String voice;
  final String model;
  final double speed;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final int playCount;
  final Uint8List wav;
}

/// Bounded encrypted cache for OpenAI speech responses.
///
/// The cache stores no plaintext message text. A SHA-256 request identity
/// covers the normalized message, instructions, model, voice, speed and output
/// format. Voice bytes are independently SHA-256 checked after the vault's
/// AES-256-GCM authentication succeeds.
final class NazaEncryptedVoiceCache {
  NazaEncryptedVoiceCache({
    NazaSecureDatabase? database,
    this.maximumEntries = 64,
    this.maximumTotalAudioBytes = 32 * 1024 * 1024,
    this.maximumEntryBytes = 16 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _database = database ?? NazaSecureDatabase.instance,
       _clock = clock ?? DateTime.now {
    if (maximumEntries < 1 || maximumEntries > 512) {
      throw ArgumentError.value(
        maximumEntries,
        'maximumEntries',
        'Use a voice-cache limit from 1 to 512.',
      );
    }
    if (maximumEntryBytes < 44 || maximumEntryBytes > 64 * 1024 * 1024) {
      throw ArgumentError.value(
        maximumEntryBytes,
        'maximumEntryBytes',
        'Use a per-entry limit from 44 bytes to 64 MiB.',
      );
    }
    if (maximumTotalAudioBytes < maximumEntryBytes ||
        maximumTotalAudioBytes > 256 * 1024 * 1024) {
      throw ArgumentError.value(
        maximumTotalAudioBytes,
        'maximumTotalAudioBytes',
        'The total cache budget must cover one entry and not exceed 256 MiB.',
      );
    }
  }

  static final NazaEncryptedVoiceCache instance = NazaEncryptedVoiceCache();

  static const String namespace = 'naza-encrypted-voice-cache-v1';
  static const String indexKey = 'index';
  static const String recordFormat = 'naza-encrypted-voice-record-v1';
  static const String indexFormat = 'naza-encrypted-voice-index-v1';
  static const String _entryPrefix = 'entry:';
  static const int _maximumMessageCharacters = 200000;
  static const int _maximumInstructionsCharacters = 8000;

  final NazaSecureDatabase _database;
  final int maximumEntries;
  final int maximumTotalAudioBytes;
  final int maximumEntryBytes;
  final DateTime Function() _clock;
  Future<void> _tail = Future<void>.value();

  bool get isUnlocked => _database.isUnlocked;

  /// Normalizes text exactly as the speech request chunker does.
  static String normalizeText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty ||
        normalized.runes.length > _maximumMessageCharacters) {
      throw ArgumentError.value(
        value.length,
        'text',
        'Speech text must contain 1-$_maximumMessageCharacters characters.',
      );
    }
    return normalized;
  }

  static String requestHash({
    required String text,
    required String voice,
    required String model,
    required String instructions,
    required double speed,
  }) {
    return _identity(
      text: text,
      voice: voice,
      model: model,
      instructions: instructions,
      speed: speed,
    ).requestHash;
  }

  Future<NazaCachedVoice?> recall({
    required String text,
    required String voice,
    required String model,
    required String instructions,
    required double speed,
  }) {
    final identity = _identity(
      text: text,
      voice: voice,
      model: model,
      instructions: instructions,
      speed: speed,
    );
    return _enqueue(() => _recallNow(identity));
  }

  Future<NazaCachedVoice> store({
    required String text,
    required String voice,
    required String model,
    required String instructions,
    required double speed,
    required Uint8List wav,
  }) {
    final identity = _identity(
      text: text,
      voice: voice,
      model: model,
      instructions: instructions,
      speed: speed,
    );
    final copy = Uint8List.fromList(wav);
    _validateWav(copy, maximumBytes: maximumEntryBytes);
    return _enqueue(() => _storeNow(identity, copy));
  }

  Future<void> recordPlayback(String requestHash) {
    _validateHash(requestHash, 'requestHash');
    return _enqueue(() async {
      _requireUnlocked();
      final index = await _readIndex();
      final mutation = index.withPlayback(requestHash, _clock().toUtc());
      if (mutation == null) {
        throw const NazaVaultException(
          'voice_cache_incomplete',
          'The encrypted voice record is missing from its authenticated index.',
        );
      }
      await _database.writeJson(namespace, indexKey, mutation.toJson());
    });
  }

  Future<void> clear() {
    return _enqueue(() async {
      _requireUnlocked();
      final index = await _readIndex();
      for (final entry in index.entries) {
        await _database.delete(namespace, _entryKey(entry.requestHash));
      }
      await _database.delete(namespace, indexKey);
    });
  }

  Future<NazaCachedVoice?> _recallNow(_VoiceRequestIdentity identity) async {
    _requireUnlocked();
    final index = await _readIndex();
    final indexEntry = index.byRequestHash(identity.requestHash);
    if (indexEntry == null) return null;

    final raw = await _database.readJson(
      namespace,
      _entryKey(identity.requestHash),
    );
    if (raw == null) {
      throw const NazaVaultException(
        'voice_cache_incomplete',
        'The authenticated voice index references a missing encrypted record.',
      );
    }
    return _decodeRecord(raw, identity, indexEntry);
  }

  Future<NazaCachedVoice> _storeNow(
    _VoiceRequestIdentity identity,
    Uint8List wav,
  ) async {
    _requireUnlocked();
    final now = _clock().toUtc();
    final audioHash = _sha256(wav);
    final index = await _readIndex();
    final entry = _VoiceIndexEntry(
      requestHash: identity.requestHash,
      audioSha256: audioHash,
      voice: identity.voice,
      model: identity.model,
      bytes: wav.length,
      createdAt: now,
      lastPlayedAt: null,
      playCount: 0,
    );
    final mutation = index.withStored(
      entry,
      maximumEntries: maximumEntries,
      maximumTotalBytes: maximumTotalAudioBytes,
    );
    final record = <String, Object?>{
      'format': recordFormat,
      'requestHash': identity.requestHash,
      'messageHash': identity.messageHash,
      'instructionsHash': identity.instructionsHash,
      'audioSha256': audioHash,
      'voice': identity.voice,
      'model': identity.model,
      'speed': identity.speed,
      'bytes': wav.length,
      'createdAt': now.toIso8601String(),
      'wavBase64': base64Encode(wav),
    };
    await _database.importRecords(<NazaVaultRecordKey, Object?>{
      NazaVaultRecordKey(namespace, _entryKey(identity.requestHash)): record,
      const NazaVaultRecordKey(namespace, indexKey): mutation.index.toJson(),
    });
    for (final hash in mutation.prunedRequestHashes) {
      await _database.delete(namespace, _entryKey(hash));
    }
    return NazaCachedVoice(
      requestHash: identity.requestHash,
      messageHash: identity.messageHash,
      audioSha256: audioHash,
      voice: identity.voice,
      model: identity.model,
      speed: identity.speed,
      createdAt: now,
      lastPlayedAt: null,
      playCount: 0,
      wav: Uint8List.fromList(wav),
    );
  }

  NazaCachedVoice _decodeRecord(
    Object raw,
    _VoiceRequestIdentity identity,
    _VoiceIndexEntry indexEntry,
  ) {
    if (raw is! Map || raw['format'] != recordFormat) {
      throw const NazaVaultException(
        'invalid_voice_cache',
        'An encrypted voice record has an unsupported format.',
      );
    }
    final requestHash = raw['requestHash']?.toString() ?? '';
    final messageHash = raw['messageHash']?.toString() ?? '';
    final instructionsHash = raw['instructionsHash']?.toString() ?? '';
    final audioHash = raw['audioSha256']?.toString() ?? '';
    final voice = raw['voice']?.toString() ?? '';
    final model = raw['model']?.toString() ?? '';
    final speed = (raw['speed'] as num?)?.toDouble();
    final byteLength = (raw['bytes'] as num?)?.toInt() ?? -1;
    final encoded = raw['wavBase64'];
    final createdAt = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
    if (!_constantTimeEquals(requestHash, identity.requestHash) ||
        !_constantTimeEquals(messageHash, identity.messageHash) ||
        !_constantTimeEquals(instructionsHash, identity.instructionsHash) ||
        !_constantTimeEquals(audioHash, indexEntry.audioSha256) ||
        voice != identity.voice ||
        indexEntry.voice != identity.voice ||
        model != identity.model ||
        indexEntry.model != identity.model ||
        speed != identity.speed ||
        byteLength != indexEntry.bytes ||
        createdAt == null ||
        createdAt.toUtc() != indexEntry.createdAt ||
        encoded is! String ||
        encoded.length > _maximumBase64Characters(maximumEntryBytes)) {
      throw const NazaVaultException(
        'invalid_voice_cache',
        'An encrypted voice record failed identity or bounds validation.',
      );
    }

    Uint8List wav;
    try {
      wav = Uint8List.fromList(base64Decode(encoded));
    } on FormatException catch (error) {
      throw NazaVaultException(
        'invalid_voice_cache',
        'An encrypted voice record contains malformed audio encoding.',
        error,
      );
    }
    _validateWav(wav, maximumBytes: maximumEntryBytes);
    if (wav.length != byteLength ||
        !_constantTimeEquals(_sha256(wav), audioHash)) {
      throw const NazaVaultException(
        'voice_hash_mismatch',
        'The recalled voice failed its SHA-256 integrity check.',
      );
    }
    return NazaCachedVoice(
      requestHash: requestHash,
      messageHash: messageHash,
      audioSha256: audioHash,
      voice: voice,
      model: model,
      speed: speed!,
      createdAt: createdAt.toUtc(),
      lastPlayedAt: indexEntry.lastPlayedAt,
      playCount: indexEntry.playCount,
      wav: wav,
    );
  }

  Future<_VoiceCacheIndex> _readIndex() async {
    final raw = await _database.readJson(namespace, indexKey);
    if (raw == null) return const _VoiceCacheIndex(<_VoiceIndexEntry>[]);
    return _VoiceCacheIndex.fromJson(raw);
  }

  void _requireUnlocked() {
    if (!_database.isUnlocked) {
      throw const NazaVaultException(
        'voice_cache_locked',
        'Unlock the encrypted vault before using Read Aloud.',
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }

  static _VoiceRequestIdentity _identity({
    required String text,
    required String voice,
    required String model,
    required String instructions,
    required double speed,
  }) {
    final normalized = normalizeText(text);
    final cleanVoice = _validateParameter(voice, 'voice', maximum: 80);
    final cleanModel = _validateParameter(model, 'model', maximum: 160);
    if (instructions.isEmpty ||
        instructions.runes.length > _maximumInstructionsCharacters ||
        instructions.contains('\u0000')) {
      throw ArgumentError.value(
        instructions.length,
        'instructions',
        'Speech instructions must contain 1-$_maximumInstructionsCharacters characters.',
      );
    }
    if (!speed.isFinite || speed < 0.25 || speed > 4) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Speech speed must be finite and between 0.25 and 4.',
      );
    }
    final messageHash = _sha256(utf8.encode(normalized));
    final instructionsHash = _sha256(utf8.encode(instructions));
    final requestHash = _sha256(
      utf8.encode(
        jsonEncode(<Object?>[
          'naza-reading-request-v1',
          messageHash,
          instructionsHash,
          cleanVoice,
          cleanModel,
          speed,
          'wav',
        ]),
      ),
    );
    return _VoiceRequestIdentity(
      requestHash: requestHash,
      messageHash: messageHash,
      instructionsHash: instructionsHash,
      voice: cleanVoice,
      model: cleanModel,
      speed: speed,
    );
  }

  static String _validateParameter(
    String value,
    String name, {
    required int maximum,
  }) {
    if (value.isEmpty ||
        value != value.trim() ||
        value.length > maximum ||
        value.contains('\u0000')) {
      throw ArgumentError.value(value, name, 'Invalid speech $name.');
    }
    return value;
  }

  static String _entryKey(String requestHash) {
    _validateHash(requestHash, 'requestHash');
    return '$_entryPrefix$requestHash';
  }
}

final class _VoiceRequestIdentity {
  const _VoiceRequestIdentity({
    required this.requestHash,
    required this.messageHash,
    required this.instructionsHash,
    required this.voice,
    required this.model,
    required this.speed,
  });

  final String requestHash;
  final String messageHash;
  final String instructionsHash;
  final String voice;
  final String model;
  final double speed;
}

final class _VoiceCacheIndex {
  const _VoiceCacheIndex(this.entries);

  factory _VoiceCacheIndex.fromJson(Object raw) {
    if (raw is! Map || raw['format'] != NazaEncryptedVoiceCache.indexFormat) {
      throw const NazaVaultException(
        'invalid_voice_cache_index',
        'The encrypted voice index has an unsupported format.',
      );
    }
    final rawEntries = raw['entries'];
    if (rawEntries is! List || rawEntries.length > 512) {
      throw const NazaVaultException(
        'invalid_voice_cache_index',
        'The encrypted voice index exceeds its safe entry budget.',
      );
    }
    final entries = <_VoiceIndexEntry>[];
    final hashes = <String>{};
    for (final rawEntry in rawEntries) {
      final entry = _VoiceIndexEntry.fromJson(rawEntry);
      if (!hashes.add(entry.requestHash)) {
        throw const NazaVaultException(
          'invalid_voice_cache_index',
          'The encrypted voice index contains a duplicate identity.',
        );
      }
      entries.add(entry);
    }
    return _VoiceCacheIndex(List<_VoiceIndexEntry>.unmodifiable(entries));
  }

  final List<_VoiceIndexEntry> entries;

  _VoiceIndexEntry? byRequestHash(String requestHash) {
    for (final entry in entries) {
      if (_constantTimeEquals(entry.requestHash, requestHash)) return entry;
    }
    return null;
  }

  _VoiceCacheMutation withStored(
    _VoiceIndexEntry stored, {
    required int maximumEntries,
    required int maximumTotalBytes,
  }) {
    final candidates = <_VoiceIndexEntry>[
      stored,
      ...entries.where(
        (entry) => !_constantTimeEquals(entry.requestHash, stored.requestHash),
      ),
    ];
    final retained = <_VoiceIndexEntry>[];
    final pruned = <String>[];
    var totalBytes = 0;
    for (final entry in candidates) {
      if (retained.length < maximumEntries &&
          totalBytes + entry.bytes <= maximumTotalBytes) {
        retained.add(entry);
        totalBytes += entry.bytes;
      } else {
        pruned.add(entry.requestHash);
      }
    }
    return _VoiceCacheMutation(
      index: _VoiceCacheIndex(List<_VoiceIndexEntry>.unmodifiable(retained)),
      prunedRequestHashes: List<String>.unmodifiable(pruned),
    );
  }

  _VoiceCacheIndex? withPlayback(String requestHash, DateTime playedAt) {
    final existing = byRequestHash(requestHash);
    if (existing == null) return null;
    final updated = existing.copyWithPlayback(playedAt);
    return _VoiceCacheIndex(<_VoiceIndexEntry>[
      updated,
      ...entries.where(
        (entry) => !_constantTimeEquals(entry.requestHash, requestHash),
      ),
    ]);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': NazaEncryptedVoiceCache.indexFormat,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };
}

final class _VoiceIndexEntry {
  const _VoiceIndexEntry({
    required this.requestHash,
    required this.audioSha256,
    required this.voice,
    required this.model,
    required this.bytes,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.playCount,
  });

  factory _VoiceIndexEntry.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NazaVaultException(
        'invalid_voice_cache_index',
        'The encrypted voice index contains a malformed entry.',
      );
    }
    final requestHash = raw['requestHash']?.toString() ?? '';
    final audioHash = raw['audioSha256']?.toString() ?? '';
    final voice = raw['voice']?.toString() ?? '';
    final model = raw['model']?.toString() ?? '';
    final bytes = (raw['bytes'] as num?)?.toInt() ?? -1;
    final createdAt = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
    final rawLastPlayedAt = raw['lastPlayedAt'];
    final lastPlayedAt = rawLastPlayedAt == null
        ? null
        : DateTime.tryParse(rawLastPlayedAt.toString());
    final playCount = (raw['playCount'] as num?)?.toInt() ?? -1;
    _validateHash(requestHash, 'requestHash');
    _validateHash(audioHash, 'audioSha256');
    if (voice.isEmpty ||
        voice.length > 80 ||
        model.isEmpty ||
        model.length > 160 ||
        bytes < 44 ||
        bytes > 64 * 1024 * 1024 ||
        createdAt == null ||
        (rawLastPlayedAt != null && lastPlayedAt == null) ||
        playCount < 0 ||
        playCount > 1000000000) {
      throw const NazaVaultException(
        'invalid_voice_cache_index',
        'The encrypted voice index entry failed bounds validation.',
      );
    }
    return _VoiceIndexEntry(
      requestHash: requestHash,
      audioSha256: audioHash,
      voice: voice,
      model: model,
      bytes: bytes,
      createdAt: createdAt.toUtc(),
      lastPlayedAt: lastPlayedAt?.toUtc(),
      playCount: playCount,
    );
  }

  final String requestHash;
  final String audioSha256;
  final String voice;
  final String model;
  final int bytes;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final int playCount;

  _VoiceIndexEntry copyWithPlayback(DateTime playedAt) => _VoiceIndexEntry(
    requestHash: requestHash,
    audioSha256: audioSha256,
    voice: voice,
    model: model,
    bytes: bytes,
    createdAt: createdAt,
    lastPlayedAt: playedAt.toUtc(),
    playCount: playCount + 1,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'requestHash': requestHash,
    'audioSha256': audioSha256,
    'voice': voice,
    'model': model,
    'bytes': bytes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastPlayedAt': lastPlayedAt?.toUtc().toIso8601String(),
    'playCount': playCount,
  };
}

final class _VoiceCacheMutation {
  const _VoiceCacheMutation({
    required this.index,
    required this.prunedRequestHashes,
  });

  final _VoiceCacheIndex index;
  final List<String> prunedRequestHashes;
}

String _sha256(List<int> bytes) => crypto.sha256.convert(bytes).toString();

void _validateHash(String value, String name) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw NazaVaultException(
      'invalid_voice_cache',
      'The encrypted voice $name is malformed.',
    );
  }
}

void _validateWav(Uint8List wav, {required int maximumBytes}) {
  if (wav.length < 44 || wav.length > maximumBytes) {
    throw const NazaVaultException(
      'invalid_voice_audio',
      'Voice audio is outside the encrypted cache size budget.',
    );
  }
  final view = ByteData.sublistView(wav);
  final channels = view.getUint16(22, Endian.little);
  final sampleRate = view.getUint32(24, Endian.little);
  final byteRate = view.getUint32(28, Endian.little);
  final blockAlign = view.getUint16(32, Endian.little);
  final bitsPerSample = view.getUint16(34, Endian.little);
  final expectedBlockAlign = channels * (bitsPerSample ~/ 8);
  if (!_asciiEquals(wav, 0, 'RIFF') ||
      !_asciiEquals(wav, 8, 'WAVE') ||
      !_asciiEquals(wav, 12, 'fmt ') ||
      !_asciiEquals(wav, 36, 'data') ||
      view.getUint32(4, Endian.little) != wav.length - 8 ||
      view.getUint32(16, Endian.little) != 16 ||
      view.getUint16(20, Endian.little) != 1 ||
      (channels != 1 && channels != 2) ||
      sampleRate < 8000 ||
      sampleRate > 96000 ||
      bitsPerSample != 16 ||
      blockAlign != expectedBlockAlign ||
      byteRate != sampleRate * expectedBlockAlign ||
      view.getUint32(40, Endian.little) != wav.length - 44) {
    throw const NazaVaultException(
      'invalid_voice_audio',
      'Voice audio is not a canonical bounded PCM WAV.',
    );
  }
}

bool _asciiEquals(Uint8List bytes, int offset, String expected) {
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected.codeUnitAt(i)) return false;
  }
  return true;
}

int _maximumBase64Characters(int bytes) => ((bytes + 2) ~/ 3) * 4;

bool _constantTimeEquals(String left, String right) {
  var diff = left.length ^ right.length;
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final leftCode = i < left.length ? left.codeUnitAt(i) : 0;
    final rightCode = i < right.length ? right.codeUnitAt(i) : 0;
    diff |= leftCode ^ rightCode;
  }
  return diff == 0;
}
