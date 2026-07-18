import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartArgon2id;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/secure_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late NazaSecureDatabase vault;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-vault-test-');
    vault = NazaSecureDatabase.forTesting(directory);
  });

  tearDown(() async {
    await vault.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('single-worker Argon2 derives the standard-compatible key', () async {
    final password = SecretKey(utf8.encode('compatibility-password'));
    final salt = Uint8List.fromList(List<int>.generate(16, (index) => index));
    final standard = Argon2id(
      parallelism: 1,
      memory: 64,
      iterations: 2,
      hashLength: 32,
    );
    const singleWorker = DartArgon2id(
      parallelism: 1,
      memory: 64,
      iterations: 2,
      hashLength: 32,
      maxIsolates: 0,
      blocksPerProcessingChunk: -1,
    );

    final standardBytes = await (await standard.deriveKey(
      secretKey: password,
      nonce: salt,
    )).extractBytes();
    final singleWorkerBytes = await (await singleWorker.deriveKey(
      secretKey: password,
      nonce: salt,
    )).extractBytes();

    expect(singleWorkerBytes, standardBytes);
  });

  test('requires setup, unlocks, and never stores record plaintext', () async {
    expect((await vault.inspect()).access, NazaVaultAccess.setupRequired);

    await vault.create(password: 'test-password');
    await vault.writeJson('history', 'thread-1', {
      'message': 'sensitive phrase that must stay encrypted',
    });

    expect(
      await vault.readJson('history', 'thread-1'),
      containsPair('message', 'sensitive phrase that must stay encrypted'),
    );
    expect(await vault.integrityCheck(), 'ok');

    final databaseBytes = await (await vault.databaseFile()).readAsBytes();
    final raw = latin1.decode(databaseBytes, allowInvalid: true);
    expect(raw, isNot(contains('sensitive phrase that must stay encrypted')));
    expect(raw, isNot(contains('thread-1')));
    expect(raw, isNot(contains('history')));
  });

  test('wrong password fails closed without mutating records', () async {
    await vault.create(password: 'correct-password');
    await vault.writeJson('settings', 'generation', {'passes': 4});
    await vault.lock();

    await expectLater(
      vault.unlock('wrong-password'),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'authentication_failed',
        ),
      ),
    );
    expect(vault.isUnlocked, isFalse);

    await vault.unlock('correct-password');
    expect(
      await vault.readJson('settings', 'generation'),
      containsPair('passes', 4),
    );
  });

  test('password change rewraps keys without rewriting the database', () async {
    await vault.create(password: 'first-password');
    await vault.writeJson('memory', 'chunks', ['one', 'two']);
    final before = await (await vault.databaseFile()).stat();

    await vault.changeUnlock(
      newPassword: 'second-password',
      passwordRequired: true,
    );
    final after = await (await vault.databaseFile()).stat();
    expect(after.size, before.size);

    await vault.lock();
    await expectLater(
      vault.unlock('first-password'),
      throwsA(isA<NazaVaultException>()),
    );
    await vault.unlock('second-password');
    expect(await vault.readJson('memory', 'chunks'), ['one', 'two']);
  });

  test('data-key rotation preserves records and retires old key ids', () async {
    await vault.create(password: 'rotate-password');
    await vault.writeJson('history', 'one', {'value': 1});
    await vault.writeJson('history', 'two', {'value': 2});
    final oldKeyId = vault.activeDataKeyId;

    await vault.rotateDataKey();
    expect(vault.activeDataKeyId, isNot(oldKeyId));
    expect(await vault.readJson('history', 'one'), containsPair('value', 1));
    expect(await vault.readJson('history', 'two'), containsPair('value', 2));

    await vault.lock();
    final db = sqlite.sqlite3.open((await vault.databaseFile()).path);
    final keyIds = db
        .select('SELECT DISTINCT key_id FROM vault_records')
        .map((row) => row['key_id'])
        .toSet();
    db.close();
    expect(keyIds, hasLength(1));

    await vault.unlock('rotate-password');
    expect(await vault.readJson('history', 'two'), containsPair('value', 2));
  });

  test(
    'tampered ciphertext is reported instead of becoming empty data',
    () async {
      await vault.create(password: 'tamper-password');
      await vault.writeJson('history', 'one', {'value': 'keep me'});
      await vault.lock();

      final db = sqlite.sqlite3.open((await vault.databaseFile()).path);
      final row = db
          .select(
            'SELECT record_id, cipher_text FROM vault_records '
            'ORDER BY updated_at DESC LIMIT 1',
          )
          .single;
      final ciphertext = Uint8List.fromList(row['cipher_text'] as Uint8List);
      ciphertext[0] ^= 0x01;
      db.execute('UPDATE vault_records SET cipher_text=? WHERE record_id=?', [
        ciphertext,
        row['record_id'],
      ]);
      db.close();

      await vault.unlock('tamper-password');
      await expectLater(
        vault.readJson('history', 'one'),
        throwsA(
          isA<NazaVaultException>().having(
            (error) => error.code,
            'code',
            'record_authentication',
          ),
        ),
      );
    },
  );

  test('optional no-password mode uses the device key store', () async {
    final deviceKeys = NazaMemoryDeviceKeyStore();
    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: deviceKeys,
    );
    await vault.create(password: '', passwordRequired: false);
    await vault.writeJson('settings', 'mode', {'local': true});
    await vault.lock();

    final inspection = await vault.inspect();
    expect(inspection.passwordRequired, isFalse);
    await vault.unlockWithDeviceKey();
    expect(
      await vault.readJson('settings', 'mode'),
      containsPair('local', true),
    );
  });
}
