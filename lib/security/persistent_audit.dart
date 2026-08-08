import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_database.dart';

const _auditFormat = 'naza-persistent-audit-v1';
const _auditNamespace = 'security.audit';
const _auditCheckpointPrefix = 'naza-audit-checkpoint-v1';

final class NazaPersistentAuditEntry {
  final int sequence;
  final int securityEpoch;
  final String event;
  final Map<String, Object?> data;
  final String previous;
  final String mac;
  final String digest;

  const NazaPersistentAuditEntry({
    required this.sequence,
    required this.securityEpoch,
    required this.event,
    required this.data,
    required this.previous,
    required this.mac,
    required this.digest,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'format': _auditFormat,
    'sequence': sequence,
    'securityEpoch': securityEpoch,
    'event': event,
    'data': _canonicalize(data),
    'previous': previous,
    'mac': mac,
    'digest': digest,
  };
}

final class NazaPersistentAuditCheckpoint {
  final int sequence;
  final String tip;
  final String ratchetKey;

  const NazaPersistentAuditCheckpoint({
    required this.sequence,
    required this.tip,
    required this.ratchetKey,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'format': _auditFormat,
    'sequence': sequence,
    'tip': tip,
    'ratchetKey': ratchetKey,
  };

  factory NazaPersistentAuditCheckpoint.fromJson(Map<String, Object?> json) {
    if (json['format'] != _auditFormat) {
      throw const NazaPersistentAuditException(
        'checkpoint_format',
        'Persistent audit checkpoint format is invalid.',
      );
    }
    final sequence = _positiveOrZeroInt(json['sequence']);
    final tip = json['tip']?.toString() ?? '';
    final ratchetKey = json['ratchetKey']?.toString() ?? '';
    if (sequence == null || tip.isEmpty || ratchetKey.isEmpty) {
      throw const NazaPersistentAuditException(
        'checkpoint_corrupt',
        'Persistent audit checkpoint is malformed.',
      );
    }
    return NazaPersistentAuditCheckpoint(
      sequence: sequence,
      tip: tip,
      ratchetKey: ratchetKey,
    );
  }
}

/// Forward-secure audit log with restart persistence.
///
/// Entries are stored as encrypted vault records. The ratchet checkpoint is
/// stored independently in the platform protected store. The previous ratchet
/// key is erased on a best-effort basis after each successful checkpoint.
///
/// Crash order:
///   1. write encrypted audit entry to the vault;
///   2. advance protected checkpoint.
///
/// On restart, one exactly-next vault entry may exist beyond the protected
/// checkpoint. It is verified with the current ratchet key and then adopted.
/// More than one uncheckpointed entry, gaps, reordering, or digest mismatch are
/// treated as tamper/corruption rather than silently repaired.
final class NazaPersistentForwardAudit {
  NazaPersistentForwardAudit({
    required this.vault,
    required this.secureStore,
    required this.vaultId,
  });

  final NazaSecureDatabase vault;
  final NazaDeviceKeyStore secureStore;
  final String vaultId;

  final Hmac _hmac = Hmac.sha256();
  final Sha256 _sha256 = Sha256();

  int _sequence = 0;
  String _tip = 'GENESIS';
  Uint8List? _ratchetKey;
  bool _initialized = false;

  int get sequence => _sequence;
  String get tip => _tip;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    _validateVaultId(vaultId);
    if (!vault.isUnlocked) {
      throw const NazaPersistentAuditException(
        'vault_locked',
        'Vault must be unlocked before the persistent audit can initialize.',
      );
    }
    destroy();

    final checkpointRaw = await secureStore.read(_checkpointStorageKey);
    if (checkpointRaw == null || checkpointRaw.isEmpty) {
      final key = _randomBytes(32);
      _ratchetKey = Uint8List.fromList(key);
      _sequence = 0;
      _tip = 'GENESIS';
      await _persistCheckpoint();
      _zero(key);
    } else {
      final checkpoint = _decodeCheckpoint(checkpointRaw);
      final key = _decodeKey(checkpoint.ratchetKey);
      _ratchetKey = key;
      _sequence = checkpoint.sequence;
      _tip = checkpoint.tip;
    }

    await _reconcilePendingEntry();
    _initialized = true;
  }

  Future<NazaPersistentAuditEntry> append({
    required String event,
    required Map<String, Object?> data,
    required int securityEpoch,
  }) async {
    _requireInitialized();
    if (event.isEmpty || event.length > 128) {
      throw ArgumentError.value(event, 'event', 'Invalid audit event name.');
    }
    if (securityEpoch < 1) {
      throw ArgumentError.value(securityEpoch, 'securityEpoch');
    }
    final key = _requireRatchetKey();
    final nextSequence = _sequence + 1;
    final body = <String, Object?>{
      'format': _auditFormat,
      'sequence': nextSequence,
      'securityEpoch': securityEpoch,
      'event': event,
      'data': _canonicalize(data),
      'previous': _tip,
    };
    final mac = await _macForBody(body, key);
    final digest = await _digestFor(<String, Object?>{
      ...body,
      'mac': mac,
    });
    final entry = NazaPersistentAuditEntry(
      sequence: nextSequence,
      securityEpoch: securityEpoch,
      event: event,
      data: Map<String, Object?>.unmodifiable(data),
      previous: _tip,
      mac: mac,
      digest: digest,
    );

    await vault.writeJson(
      _auditNamespace,
      _entryKey(nextSequence),
      entry.toJson(),
    );

    final nextKey = await _ratchet(key, nextSequence);
    final oldKey = _ratchetKey;
    _ratchetKey = nextKey;
    _sequence = nextSequence;
    _tip = digest;
    try {
      await _persistCheckpoint();
    } catch (_) {
      _zero(_ratchetKey);
      _ratchetKey = oldKey;
      _sequence = nextSequence - 1;
      _tip = entry.previous;
      rethrow;
    }
    if (!identical(oldKey, _ratchetKey)) _zero(oldKey);
    return entry;
  }

  Future<void> verifyRecent({int maxEntries = 256}) async {
    _requireInitialized();
    if (maxEntries < 1 || maxEntries > 4096) {
      throw ArgumentError.value(maxEntries, 'maxEntries');
    }
    if (_sequence == 0) return;

    final start = math.max(1, _sequence - maxEntries + 1);
    String? expectedPrevious;
    for (var seq = start; seq <= _sequence; seq++) {
      final raw = await vault.readJson(_auditNamespace, _entryKey(seq));
      if (raw is! Map) {
        throw NazaPersistentAuditException(
          'audit_gap',
          'Persistent audit entry $seq is missing.',
        );
      }
      final entry = _parseEntry(raw);
      if (entry.sequence != seq) {
        throw const NazaPersistentAuditException(
          'audit_sequence',
          'Persistent audit entry sequence is invalid.',
        );
      }
      if (expectedPrevious != null && entry.previous != expectedPrevious) {
        throw const NazaPersistentAuditException(
          'audit_chain',
          'Persistent audit hash chain is broken.',
        );
      }
      expectedPrevious = entry.digest;
    }
    if (expectedPrevious != _tip) {
      throw const NazaPersistentAuditException(
        'audit_tip_mismatch',
        'Persistent audit tip does not match protected checkpoint.',
      );
    }
  }

  Future<void> _reconcilePendingEntry() async {
    final currentKey = _requireRatchetKey();
    final pendingSequence = _sequence + 1;
    final raw = await vault.readJson(_auditNamespace, _entryKey(pendingSequence));
    if (raw == null) return;
    if (raw is! Map) {
      throw const NazaPersistentAuditException(
        'audit_entry_corrupt',
        'Pending audit entry is malformed.',
      );
    }
    final entry = _parseEntry(raw);
    if (entry.sequence != pendingSequence || entry.previous != _tip) {
      throw const NazaPersistentAuditException(
        'audit_pending_invalid',
        'Pending audit entry does not extend the protected checkpoint.',
      );
    }
    final body = <String, Object?>{
      'format': _auditFormat,
      'sequence': entry.sequence,
      'securityEpoch': entry.securityEpoch,
      'event': entry.event,
      'data': _canonicalize(entry.data),
      'previous': entry.previous,
    };
    final expectedMac = await _macForBody(body, currentKey);
    if (!_constantTimeTextEquals(expectedMac, entry.mac)) {
      throw const NazaPersistentAuditException(
        'audit_authentication',
        'Pending audit entry authentication failed.',
      );
    }
    final expectedDigest = await _digestFor(<String, Object?>{
      ...body,
      'mac': entry.mac,
    });
    if (!_constantTimeTextEquals(expectedDigest, entry.digest)) {
      throw const NazaPersistentAuditException(
        'audit_digest',
        'Pending audit entry digest failed validation.',
      );
    }

    final unexpectedNext = await vault.readJson(
      _auditNamespace,
      _entryKey(pendingSequence + 1),
    );
    if (unexpectedNext != null) {
      throw const NazaPersistentAuditException(
        'audit_multi_pending',
        'Multiple uncheckpointed audit entries were found.',
      );
    }

    final nextKey = await _ratchet(currentKey, pendingSequence);
    final oldKey = _ratchetKey;
    _ratchetKey = nextKey;
    _sequence = pendingSequence;
    _tip = entry.digest;
    await _persistCheckpoint();
    _zero(oldKey);
  }

  Future<String> _macForBody(Map<String, Object?> body, List<int> key) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(_canonicalJson(body)),
      secretKey: SecretKey(key),
    );
    return base64UrlEncode(mac.bytes).replaceAll('=', '');
  }

  Future<String> _digestFor(Map<String, Object?> body) async {
    final digest = await _sha256.hash(utf8.encode(_canonicalJson(body)));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<Uint8List> _ratchet(List<int> key, int sequence) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('$_auditFormat/ratchet/$vaultId/$sequence'),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(mac.bytes);
  }

  Future<void> _persistCheckpoint() async {
    final checkpoint = NazaPersistentAuditCheckpoint(
      sequence: _sequence,
      tip: _tip,
      ratchetKey: base64Encode(_requireRatchetKey()),
    );
    await secureStore.write(
      _checkpointStorageKey,
      jsonEncode(checkpoint.toJson()),
    );
  }

  NazaPersistentAuditCheckpoint _decodeCheckpoint(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException('not a map');
      return NazaPersistentAuditCheckpoint.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } catch (error) {
      if (error is NazaPersistentAuditException) rethrow;
      throw NazaPersistentAuditException(
        'checkpoint_corrupt',
        'Protected audit checkpoint is malformed: $error',
      );
    }
  }

  NazaPersistentAuditEntry _parseEntry(Map raw) {
    final map = Map<String, Object?>.from(raw);
    if (map['format'] != _auditFormat) {
      throw const NazaPersistentAuditException(
        'audit_entry_format',
        'Persistent audit entry format is invalid.',
      );
    }
    final sequence = _positiveInt(map['sequence']);
    final epoch = _positiveInt(map['securityEpoch']);
    final event = map['event']?.toString() ?? '';
    final previous = map['previous']?.toString() ?? '';
    final mac = map['mac']?.toString() ?? '';
    final digest = map['digest']?.toString() ?? '';
    final dataRaw = map['data'];
    if (sequence == null ||
        epoch == null ||
        event.isEmpty ||
        previous.isEmpty ||
        mac.isEmpty ||
        digest.isEmpty ||
        dataRaw is! Map) {
      throw const NazaPersistentAuditException(
        'audit_entry_corrupt',
        'Persistent audit entry is malformed.',
      );
    }
    return NazaPersistentAuditEntry(
      sequence: sequence,
      securityEpoch: epoch,
      event: event,
      data: Map<String, Object?>.from(dataRaw),
      previous: previous,
      mac: mac,
      digest: digest,
    );
  }

  Uint8List _decodeKey(String encoded) {
    try {
      final key = Uint8List.fromList(base64Decode(encoded));
      if (key.length != 32) {
        _zero(key);
        throw const FormatException('wrong key length');
      }
      return key;
    } catch (error) {
      throw NazaPersistentAuditException(
        'checkpoint_key',
        'Protected audit ratchet key is invalid: $error',
      );
    }
  }

  String get _checkpointStorageKey => '$_auditCheckpointPrefix-$vaultId';

  String _entryKey(int sequence) => sequence.toString().padLeft(20, '0');

  Uint8List _requireRatchetKey() {
    final key = _ratchetKey;
    if (key == null) {
      throw const NazaPersistentAuditException(
        'audit_uninitialized',
        'Persistent audit is not initialized.',
      );
    }
    return key;
  }

  void _requireInitialized() {
    if (!_initialized || _ratchetKey == null) {
      throw const NazaPersistentAuditException(
        'audit_uninitialized',
        'Persistent audit is not initialized.',
      );
    }
  }

  void destroy() {
    _initialized = false;
    _sequence = 0;
    _tip = 'GENESIS';
    _zero(_ratchetKey);
    _ratchetKey = null;
  }
}

final class NazaPersistentAuditException implements Exception {
  final String code;
  final String message;

  const NazaPersistentAuditException(this.code, this.message);

  @override
  String toString() => 'NazaPersistentAuditException($code): $message';
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value
        .map<Object?>((item) => _canonicalize(item))
        .toList(growable: false);
  }
  if (value is num || value is bool || value is String || value == null) {
    return value;
  }
  return value.toString();
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _positiveOrZeroInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}

bool _constantTimeTextEquals(String a, String b) {
  final aa = utf8.encode(a);
  final bb = utf8.encode(b);
  var difference = aa.length ^ bb.length;
  final length = math.min(aa.length, bb.length);
  for (var index = 0; index < length; index++) {
    difference |= aa[index] ^ bb[index];
  }
  return difference == 0;
}

Uint8List _randomBytes(int length) {
  final random = math.Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

void _validateVaultId(String vaultId) {
  if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId)) {
    throw ArgumentError.value(vaultId, 'vaultId', 'Invalid vault identifier.');
  }
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
