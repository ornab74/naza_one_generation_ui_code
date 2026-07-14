import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/post_quantum_export.dart';

void main() {
  const password = 'recovery-password';
  const policy = NazaPostQuantumPolicy.testing();
  late NazaRecoveryBundle primary;
  late NazaRecoveryBundle secondary;

  setUpAll(() async {
    primary = await NazaPostQuantumExport.generateRecoveryBundle(
      password: password,
      policy: policy,
    );
    secondary = await NazaPostQuantumExport.generateRecoveryBundle(
      password: 'other-recovery-password',
      policy: policy,
    );
  });

  test('generates a password-encrypted hybrid recovery bundle', () {
    final publicKey = _jsonMap(primary.publicKeyJson);
    final privateKey = _jsonMap(primary.encryptedPrivateKeyJson);

    expect(publicKey['format'], 'naza-pq-recovery-public-v1');
    expect(publicKey['suite'], 'ML-KEM-768+X25519+HKDF-SHA256+AES-256-GCM');
    expect(publicKey['fingerprint'], primary.fingerprint);
    expect(privateKey['format'], 'naza-pq-recovery-private-v1');
    expect(privateKey['cipher'], 'AES-256-GCM');
    expect(privateKey['privateEncoding'], 'ML-KEM-768-SK||X25519-SK');
    expect(primary.encryptedPrivateKeyJson, isNot(contains('mlKemPrivateKey')));
    expect(
      primary.encryptedPrivateKeyJson,
      isNot(contains('x25519PrivateKey')),
    );
  });

  test(
    'hybrid backup encryption round-trips binary and empty payloads',
    () async {
      final clear = Uint8List.fromList(
        List<int>.generate(1024, (index) => index & 0xff),
      );
      final encrypted = await NazaPostQuantumExport.encryptBackup(
        clearBytes: clear,
        recipientPublicKeyJson: primary.publicKeyJson,
      );
      final recovered = await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: primary.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      expect(recovered, orderedEquals(clear));

      final encryptedEmpty = await NazaPostQuantumExport.encryptBackup(
        clearBytes: const [],
        recipientPublicKeyJson: primary.publicKeyJson,
      );
      final recoveredEmpty = await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encryptedEmpty,
        encryptedPrivateKeyJson: primary.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      expect(recoveredEmpty, isEmpty);
    },
  );

  test('wrong recovery password fails authentication', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: primary.publicKeyJson,
    );

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: primary.encryptedPrivateKeyJson,
        recoveryPassword: 'wrong-password',
      ),
      _throwsCode('authentication_failed'),
    );
  });

  test('authenticated backup metadata cannot be altered', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: primary.publicKeyJson,
    );
    final tampered = _jsonMap(encrypted);
    tampered['createdAt'] = '2000-01-01T00:00:00.000Z';

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: jsonEncode(tampered),
        encryptedPrivateKeyJson: primary.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      _throwsCode('authentication_failed'),
    );
  });

  test('backup cannot be opened with a different recovery key', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: primary.publicKeyJson,
    );

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: secondary.encryptedPrivateKeyJson,
        recoveryPassword: 'other-recovery-password',
      ),
      _throwsCode('wrong_recipient'),
    );
  });

  test('hostile KDF parameters are rejected before password work', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: primary.publicKeyJson,
    );
    final privateKey = _jsonMap(primary.encryptedPrivateKeyJson);
    final kdf = Map<String, Object?>.from(privateKey['kdf']! as Map);
    kdf['memoryKiB'] = 1024 * 1024;
    privateKey['kdf'] = kdf;

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: jsonEncode(privateKey),
        recoveryPassword: password,
      ),
      _throwsCode('unsafe_kdf'),
    );
  });

  test('altered public-key fingerprints are rejected', () async {
    final publicKey = _jsonMap(primary.publicKeyJson);
    publicKey['fingerprint'] = 'not-the-generated-fingerprint';

    await expectLater(
      NazaPostQuantumExport.encryptBackup(
        clearBytes: utf8.encode('vault backup'),
        recipientPublicKeyJson: jsonEncode(publicKey),
      ),
      _throwsCode('public_key_fingerprint'),
    );
  });
}

Map<String, Object?> _jsonMap(String json) {
  return Map<String, Object?>.from(jsonDecode(json) as Map);
}

Matcher _throwsCode(String code) {
  return throwsA(
    isA<NazaPostQuantumException>().having((error) => error.code, 'code', code),
  );
}
