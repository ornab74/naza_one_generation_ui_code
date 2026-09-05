// LLM-CONTEXT:BEGIN
// FILE: test/encrypted_voice_cache_test.dart
// ROLE: Verifies encrypted speech persistence, recall, integrity, and retention bounds.
// DOMAIN: verification
// SECURITY-INVARIANT: Cached voice bytes and identities remain authenticated ciphertext and fail closed on mismatch.
// CHANGE-GUARD: Preserve hash binding, strict WAV validation, bounded retention, and locked-vault behavior.
// DOCS: See /SECURITY.md and /lib/audio/encrypted_voice_cache.dart.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

const _voice = 'marin';
const _model = 'gpt-4o-mini-tts';
const _instructions = 'Read this private message naturally.';
const _zeroHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

void main() {
  late Directory directory;
  late NazaSecureDatabase vault;
  late DateTime now;
  late NazaEncryptedVoiceCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-voice-test-');
    vault = NazaSecureDatabase.forTesting(directory);
    await vault.create(password: 'voice-test-password');
    now = DateTime.utc(2026, 9, 2, 18);
    cache = NazaEncryptedVoiceCache(
      database: vault,
      clock: () => now,
      maximumEntries: 8,
      maximumEntryBytes: 1024 * 1024,
      maximumTotalAudioBytes: 4 * 1024 * 1024,
    );
  });

  tearDown(() async {
    await vault.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'stores and recalls hash-bound WAV bytes across vault unlocks',
    () async {
      const text = 'A private message that should be recalled securely.';
      final wav = _pcmWav(400);
      final stored = await cache.store(
        text: text,
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
        wav: wav,
      );

      expect(stored.requestHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(stored.messageHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(stored.audioSha256, matches(RegExp(r'^[0-9a-f]{64}$')));

      now = now.add(const Duration(minutes: 2));
      await cache.recordPlayback(stored.requestHash);
      await vault.lock();
      await vault.unlock('voice-test-password');

      final reopened = NazaEncryptedVoiceCache(
        database: vault,
        clock: () => now,
        maximumEntries: 8,
        maximumEntryBytes: 1024 * 1024,
        maximumTotalAudioBytes: 4 * 1024 * 1024,
      );
      final recalled = await reopened.recall(
        text: text,
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
      );

      expect(recalled, isNotNull);
      expect(recalled!.wav, orderedEquals(wav));
      expect(recalled.audioSha256, stored.audioSha256);
      expect(recalled.playCount, 1);
      expect(recalled.lastPlayedAt, now);
    },
  );

  test(
    'keeps message identity and WAV payload out of SQLite plaintext',
    () async {
      const text = 'Never expose this spoken secret in the SQLite file.';
      final wav = _pcmWav(600);
      final stored = await cache.store(
        text: text,
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
        wav: wav,
      );

      final forbidden = <String>[
        text,
        base64Encode(wav),
        NazaEncryptedVoiceCache.namespace,
        NazaEncryptedVoiceCache.recordFormat,
        stored.requestHash,
        stored.audioSha256,
      ];
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final raw = latin1.decode(
          await entity.readAsBytes(),
          allowInvalid: true,
        );
        for (final value in forbidden) {
          expect(raw, isNot(contains(value)), reason: entity.path);
        }
      }
    },
  );

  test('request hash changes with voice instructions and normalized text', () {
    final base = NazaEncryptedVoiceCache.requestHash(
      text: 'same   message',
      voice: _voice,
      model: _model,
      instructions: _instructions,
      speed: 1,
    );
    expect(
      NazaEncryptedVoiceCache.requestHash(
        text: ' same message ',
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
      ),
      base,
    );
    expect(
      NazaEncryptedVoiceCache.requestHash(
        text: 'same message',
        voice: 'alloy',
        model: _model,
        instructions: _instructions,
        speed: 1,
      ),
      isNot(base),
    );
    expect(
      NazaEncryptedVoiceCache.requestHash(
        text: 'same message',
        voice: _voice,
        model: _model,
        instructions: 'Read quickly.',
        speed: 1,
      ),
      isNot(base),
    );
  });

  test('authenticated but inconsistent audio hash fails closed', () async {
    const text = 'Detect a mismatched cached artifact.';
    final stored = await cache.store(
      text: text,
      voice: _voice,
      model: _model,
      instructions: _instructions,
      speed: 1,
      wav: _pcmWav(256),
    );
    final entryKey = 'entry:${stored.requestHash}';
    final record = Map<String, Object?>.from(
      await vault.readJson(NazaEncryptedVoiceCache.namespace, entryKey) as Map,
    )..['audioSha256'] = _zeroHash;
    final index = Map<String, Object?>.from(
      await vault.readJson(
            NazaEncryptedVoiceCache.namespace,
            NazaEncryptedVoiceCache.indexKey,
          )
          as Map,
    );
    final entries = (index['entries'] as List)
        .map((entry) => Map<String, Object?>.from(entry as Map))
        .toList(growable: false);
    entries.single['audioSha256'] = _zeroHash;
    index['entries'] = entries;
    await vault.importRecords(<NazaVaultRecordKey, Object?>{
      NazaVaultRecordKey(NazaEncryptedVoiceCache.namespace, entryKey): record,
      const NazaVaultRecordKey(
        NazaEncryptedVoiceCache.namespace,
        NazaEncryptedVoiceCache.indexKey,
      ): index,
    });

    await expectLater(
      cache.recall(
        text: text,
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
      ),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'voice_hash_mismatch',
        ),
      ),
    );
  });

  test('prunes least-recent entries at the configured bound', () async {
    cache = NazaEncryptedVoiceCache(
      database: vault,
      clock: () => now,
      maximumEntries: 2,
      maximumEntryBytes: 1024,
      maximumTotalAudioBytes: 2048,
    );
    final first = await cache.store(
      text: 'first voice',
      voice: _voice,
      model: _model,
      instructions: _instructions,
      speed: 1,
      wav: _pcmWav(100),
    );
    now = now.add(const Duration(minutes: 1));
    await cache.store(
      text: 'second voice',
      voice: _voice,
      model: _model,
      instructions: _instructions,
      speed: 1,
      wav: _pcmWav(100),
    );
    now = now.add(const Duration(minutes: 1));
    await cache.recordPlayback(first.requestHash);
    now = now.add(const Duration(minutes: 1));
    await cache.store(
      text: 'third voice',
      voice: _voice,
      model: _model,
      instructions: _instructions,
      speed: 1,
      wav: _pcmWav(100),
    );

    expect(await _recall(cache, 'first voice'), isNotNull);
    expect(await _recall(cache, 'second voice'), isNull);
    expect(await _recall(cache, 'third voice'), isNotNull);
  });

  test('locked vault prevents cache reads and writes', () async {
    await vault.lock();

    await expectLater(
      _recall(cache, 'locked voice'),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'voice_cache_locked',
        ),
      ),
    );
    await expectLater(
      cache.store(
        text: 'locked voice',
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
        wav: _pcmWav(100),
      ),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'voice_cache_locked',
        ),
      ),
    );
  });

  test('rejects non-canonical and oversized WAV input', () {
    expect(
      () => cache.store(
        text: 'bad audio',
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
        wav: Uint8List(44),
      ),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'invalid_voice_audio',
        ),
      ),
    );

    final smallCache = NazaEncryptedVoiceCache(
      database: vault,
      maximumEntries: 1,
      maximumEntryBytes: 64,
      maximumTotalAudioBytes: 64,
    );
    expect(
      () => smallCache.store(
        text: 'oversized audio',
        voice: _voice,
        model: _model,
        instructions: _instructions,
        speed: 1,
        wav: _pcmWav(100),
      ),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'invalid_voice_audio',
        ),
      ),
    );
  });
}

Future<NazaCachedVoice?> _recall(NazaEncryptedVoiceCache cache, String text) {
  return cache.recall(
    text: text,
    voice: _voice,
    model: _model,
    instructions: _instructions,
    speed: 1,
  );
}

Uint8List _pcmWav(int pcmBytes) {
  final alignedBytes = pcmBytes.isEven ? pcmBytes : pcmBytes + 1;
  final wav = Uint8List(44 + alignedBytes);
  final view = ByteData.sublistView(wav);
  _writeAscii(wav, 0, 'RIFF');
  view.setUint32(4, wav.length - 8, Endian.little);
  _writeAscii(wav, 8, 'WAVE');
  _writeAscii(wav, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 24000, Endian.little);
  view.setUint32(28, 48000, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  _writeAscii(wav, 36, 'data');
  view.setUint32(40, alignedBytes, Endian.little);
  for (var i = 44; i < wav.length; i++) {
    wav[i] = (i * 17) & 0xff;
  }
  return wav;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    bytes[offset + i] = value.codeUnitAt(i);
  }
}
