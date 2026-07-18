import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/post_quantum_export.dart';

void main() {
  const password = 'recovery-password';
  const otherPassword = 'other-recovery-password';
  const defaultPolicy = NazaPostQuantumPolicy.testing();
  const legacyPolicy = NazaPostQuantumPolicy.testing(
    profile: NazaPostQuantumProfile.legacyHybrid,
  );
  late NazaRecoveryBundle advanced;
  late NazaRecoveryBundle legacy;
  late NazaRecoveryBundle secondaryAdvanced;

  setUpAll(() async {
    advanced = await NazaPostQuantumExport.generateRecoveryBundle(
      password: password,
      policy: defaultPolicy,
    );
    legacy = await NazaPostQuantumExport.generateRecoveryBundle(
      password: password,
      policy: legacyPolicy,
    );
    secondaryAdvanced = await NazaPostQuantumExport.generateRecoveryBundle(
      password: otherPassword,
      policy: defaultPolicy,
    );
  });

  test(
    'maximum hybrid v2 is the default and publishes complete metadata',
    () async {
      final publicKey = _jsonMap(advanced.publicKeyJson);
      final privateKey = _jsonMap(advanced.encryptedPrivateKeyJson);
      final kdf = Map<String, Object?>.from(privateKey['kdf']! as Map);
      final inspected = await NazaPostQuantumExport.inspectPublicKey(
        advanced.publicKeyJson,
      );

      expect(advanced.profile, NazaPostQuantumProfile.maximumHybrid);
      expect(advanced.profile.isDefault, isTrue);
      expect(advanced.profile.wireName, 'maximum-hybrid-v2');
      expect(advanced.suite, _advancedSuite);
      expect(publicKey, containsPair('format', 'naza-pq-recovery-public-v2'));
      expect(publicKey, containsPair('suite', _advancedSuite));
      expect(publicKey, containsPair('profile', 'maximum-hybrid-v2'));
      expect(publicKey, containsPair('kem', 'ML-KEM-1024'));
      expect(publicKey, containsPair('classicalKem', 'X25519'));
      expect(publicKey, containsPair('keyDerivation', 'HKDF-SHA512'));
      expect(publicKey, containsPair('aead', 'AES-256-GCM'));
      expect(publicKey, containsPair('backupAuthentication', 'ML-DSA-87'));
      expect(
        base64Decode(publicKey['mlDsaPublicKey']! as String),
        hasLength(2592),
      );
      expect(
        publicKey['keyId'],
        isA<String>().having(
          (id) => id.length,
          'length',
          greaterThanOrEqualTo(16),
        ),
      );
      expect(DateTime.tryParse(publicKey['createdAt']! as String), isNotNull);
      expect(publicKey['fingerprint'], advanced.fingerprint);
      expect(advanced.fingerprint, hasLength(86));

      expect(privateKey, containsPair('format', 'naza-pq-recovery-private-v2'));
      expect(privateKey, containsPair('suite', _advancedSuite));
      expect(privateKey, containsPair('profile', 'maximum-hybrid-v2'));
      expect(privateKey, containsPair('cipher', 'AES-256-GCM'));
      expect(
        privateKey,
        containsPair(
          'privateEncoding',
          'ML-KEM-1024-SK||X25519-SK||ML-DSA-87-SK',
        ),
      );
      expect(base64Decode(kdf['salt']! as String), hasLength(32));
      expect(
        advanced.encryptedPrivateKeyJson,
        isNot(contains('mlKemPrivateKey')),
      );
      expect(
        advanced.encryptedPrivateKeyJson,
        isNot(contains('x25519PrivateKey')),
      );
      expect(
        advanced.encryptedPrivateKeyJson,
        isNot(contains('mlDsaPrivateKey')),
      );

      expect(inspected.profile, NazaPostQuantumProfile.maximumHybrid);
      expect(inspected.suite, _advancedSuite);
      expect(inspected.fingerprint, advanced.fingerprint);
      expect(inspected.createdAt, isNotNull);
    },
  );

  test('default v2 backup round-trips binary and empty payloads', () async {
    final clear = Uint8List.fromList(
      List<int>.generate(1024, (index) => index & 0xff),
    );
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: clear,
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );
    final envelope = _jsonMap(encrypted);

    expect(envelope, containsPair('format', 'naza-pq-backup-v2'));
    expect(envelope, containsPair('suite', _advancedSuite));
    expect(envelope, containsPair('profile', 'maximum-hybrid-v2'));
    expect(envelope, containsPair('cipher', 'AES-256-GCM'));
    final origin = Map<String, Object?>.from(
      envelope['originAuthentication']! as Map,
    );
    expect(origin, containsPair('format', 'naza-pq-backup-origin-v2'));
    expect(origin, containsPair('algorithm', 'ML-DSA-87'));
    expect(origin, containsPair('signerFingerprint', advanced.fingerprint));
    expect(base64Decode(origin['signature']! as String), hasLength(4627));
    final payload = Map<String, Object?>.from(envelope['payload']! as Map);
    expect(
      payload['sha512'],
      isA<String>().having((value) => value.length, 'length', 86),
    );
    expect(payload, isNot(contains('sha256')));
    expect(envelope['recipientFingerprint'], advanced.fingerprint);
    expect(
      envelope['recipientKeyId'],
      _jsonMap(advanced.publicKeyJson)['keyId'],
    );
    expect(
      await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      orderedEquals(clear),
    );

    final encryptedEmpty = await NazaPostQuantumExport.encryptBackup(
      clearBytes: const [],
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );
    expect(
      await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encryptedEmpty,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      isEmpty,
    );
  });

  test('explicit legacy v1 profile remains readable and writable', () async {
    final publicKey = _jsonMap(legacy.publicKeyJson);
    final privateKey = _jsonMap(legacy.encryptedPrivateKeyJson);
    final kdf = Map<String, Object?>.from(privateKey['kdf']! as Map);
    final clear = utf8.encode('legacy recovery package');

    expect(legacy.profile, NazaPostQuantumProfile.legacyHybrid);
    expect(legacy.profile.isDefault, isFalse);
    expect(legacy.suite, _legacySuite);
    expect(publicKey, containsPair('format', 'naza-pq-recovery-public-v1'));
    expect(publicKey, containsPair('suite', _legacySuite));
    expect(publicKey, isNot(contains('profile')));
    expect(privateKey, containsPair('format', 'naza-pq-recovery-private-v1'));
    expect(
      privateKey,
      containsPair('privateEncoding', 'ML-KEM-768-SK||X25519-SK'),
    );
    expect(privateKey, isNot(contains('profile')));
    expect(base64Decode(kdf['salt']! as String), hasLength(16));

    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: clear,
      recipientPublicKeyJson: legacy.publicKeyJson,
    );
    final envelope = _jsonMap(encrypted);
    expect(envelope, containsPair('format', 'naza-pq-backup-v1'));
    expect(envelope, containsPair('suite', _legacySuite));
    expect(envelope, isNot(contains('profile')));
    expect(
      await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: legacy.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      orderedEquals(clear),
    );
  });

  test('mixed v1/v2 keys and backup envelopes fail closed', () async {
    final advancedBackup = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('advanced'),
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );
    final legacyBackup = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('legacy'),
      recipientPublicKeyJson: legacy.publicKeyJson,
    );

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: advancedBackup,
        encryptedPrivateKeyJson: legacy.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      _throwsCode('unsupported_suite'),
    );
    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: legacyBackup,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      _throwsCode('unsupported_suite'),
    );

    final mixedPublic = _jsonMap(advanced.publicKeyJson)
      ..['format'] = 'naza-pq-recovery-public-v1';
    await expectLater(
      NazaPostQuantumExport.encryptBackup(
        clearBytes: const [1],
        recipientPublicKeyJson: jsonEncode(mixedPublic),
      ),
      _throwsCode('unsupported_suite'),
    );
  });

  test('wrong recovery password fails authentication', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: 'wrong-password',
      ),
      _throwsCode('authentication_failed'),
    );
  });

  test(
    'maximum-profile backup creation requires private authorization',
    () async {
      await expectLater(
        NazaPostQuantumExport.encryptBackup(
          clearBytes: utf8.encode('public-key-only forgery'),
          recipientPublicKeyJson: advanced.publicKeyJson,
        ),
        _throwsCode('backup_authorization_required'),
      );
    },
  );

  test(
    'authenticated v2 backup fields and ciphertext reject tampering',
    () async {
      final encrypted = await NazaPostQuantumExport.encryptBackup(
        clearBytes: utf8.encode('vault backup'),
        recipientPublicKeyJson: advanced.publicKeyJson,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      final createdAtTamper = _jsonMap(encrypted)
        ..['createdAt'] = '2000-01-01T00:00:00.000Z';
      final ciphertextTamper = _jsonMap(encrypted);
      ciphertextTamper['cipherText'] = _flipFirstBase64Byte(
        ciphertextTamper['cipherText']! as String,
      );

      for (final tampered in [createdAtTamper, ciphertextTamper]) {
        await expectLater(
          NazaPostQuantumExport.decryptBackup(
            encryptedBackupJson: jsonEncode(tampered),
            encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
            recoveryPassword: password,
          ),
          _throwsCode('origin_authentication_failed'),
        );
      }
    },
  );

  test(
    'v2 profile and recipient identity tampering fail before recovery',
    () async {
      final encrypted = await NazaPostQuantumExport.encryptBackup(
        clearBytes: utf8.encode('vault backup'),
        recipientPublicKeyJson: advanced.publicKeyJson,
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      final keyIdTamper = _jsonMap(encrypted)
        ..['recipientKeyId'] = 'other-key-id';
      final profileTamper = _jsonMap(advanced.encryptedPrivateKeyJson)
        ..['profile'] = 'legacy-hybrid-v1';

      await expectLater(
        NazaPostQuantumExport.decryptBackup(
          encryptedBackupJson: jsonEncode(keyIdTamper),
          encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
          recoveryPassword: password,
        ),
        _throwsCode('wrong_recipient'),
      );
      await expectLater(
        NazaPostQuantumExport.decryptBackup(
          encryptedBackupJson: encrypted,
          encryptedPrivateKeyJson: jsonEncode(profileTamper),
          recoveryPassword: password,
        ),
        _throwsCode('wrong_recipient'),
      );
    },
  );

  test('v2 public cryptographic metadata is fingerprint-bound', () async {
    final malformedMetadata = _jsonMap(advanced.publicKeyJson)
      ..['keyDerivation'] = 'HKDF-SHA256';
    final alteredFingerprint = _jsonMap(advanced.publicKeyJson)
      ..['fingerprint'] = 'not-the-generated-fingerprint';

    await expectLater(
      NazaPostQuantumExport.encryptBackup(
        clearBytes: utf8.encode('vault backup'),
        recipientPublicKeyJson: jsonEncode(malformedMetadata),
      ),
      _throwsCode('invalid_public_key'),
    );
    await expectLater(
      NazaPostQuantumExport.encryptBackup(
        clearBytes: utf8.encode('vault backup'),
        recipientPublicKeyJson: jsonEncode(alteredFingerprint),
      ),
      _throwsCode('public_key_fingerprint'),
    );
  });

  test('backup cannot be opened with a different v2 recovery key', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: encrypted,
        encryptedPrivateKeyJson: secondaryAdvanced.encryptedPrivateKeyJson,
        recoveryPassword: otherPassword,
      ),
      _throwsCode('wrong_recipient'),
    );
  });

  test('hostile KDF parameters are rejected before password work', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );
    final privateKey = _jsonMap(advanced.encryptedPrivateKeyJson);
    final kdf = Map<String, Object?>.from(privateKey['kdf']! as Map)
      ..['memoryKiB'] = 1024 * 1024;
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

  test(
    'all-zero recipient X25519 keys normalize to invalid_public_key',
    () async {
      final publicKey = _jsonMap(advanced.publicKeyJson)
        ..['x25519PublicKey'] = base64Encode(Uint8List(32));
      publicKey['fingerprint'] = await _v2Fingerprint(publicKey);

      await expectLater(
        NazaPostQuantumExport.encryptBackup(
          clearBytes: utf8.encode('vault backup'),
          recipientPublicKeyJson: jsonEncode(publicKey),
        ),
        _throwsCode('invalid_public_key'),
      );
    },
  );

  test('all-zero ephemeral X25519 keys normalize to invalid_backup', () async {
    final encrypted = await NazaPostQuantumExport.encryptBackup(
      clearBytes: utf8.encode('vault backup'),
      recipientPublicKeyJson: advanced.publicKeyJson,
      encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
      recoveryPassword: password,
    );
    final tampered = _jsonMap(encrypted)
      ..['ephemeralX25519PublicKey'] = base64Encode(Uint8List(32));

    await expectLater(
      NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: jsonEncode(tampered),
        encryptedPrivateKeyJson: advanced.encryptedPrivateKeyJson,
        recoveryPassword: password,
      ),
      _throwsCode('origin_authentication_failed'),
    );
  });
}

const _advancedSuite = 'ML-KEM-1024+X25519+ML-DSA-87+HKDF-SHA512+AES-256-GCM';
const _legacySuite = 'ML-KEM-768+X25519+HKDF-SHA256+AES-256-GCM';

Map<String, Object?> _jsonMap(String json) {
  return Map<String, Object?>.from(jsonDecode(json) as Map);
}

String _flipFirstBase64Byte(String encoded) {
  final bytes = Uint8List.fromList(base64Decode(encoded));
  bytes[0] ^= 1;
  return base64Encode(bytes);
}

Future<String> _v2Fingerprint(Map<String, Object?> publicKey) async {
  final canonical = utf8.encode(
    jsonEncode(<String, Object?>{
      'format': publicKey['format'],
      'suite': publicKey['suite'],
      'profile': publicKey['profile'],
      'kem': publicKey['kem'],
      'classicalKem': publicKey['classicalKem'],
      'keyDerivation': publicKey['keyDerivation'],
      'aead': publicKey['aead'],
      'backupAuthentication': publicKey['backupAuthentication'],
      'keyId': publicKey['keyId'],
      'createdAt': publicKey['createdAt'],
      'mlKemPublicKey': publicKey['mlKemPublicKey'],
      'x25519PublicKey': publicKey['x25519PublicKey'],
      'mlDsaPublicKey': publicKey['mlDsaPublicKey'],
    }),
  );
  final digest = await Sha512().hash(canonical);
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

Matcher _throwsCode(String code) {
  return throwsA(
    isA<NazaPostQuantumException>().having((error) => error.code, 'code', code),
  );
}
