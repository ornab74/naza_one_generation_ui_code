import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/post_quantum_export.dart';
import 'package:naza_one/security/post_quantum_recovery.dart';

void main() {
  const password = 'correct-recovery-password';
  const otherPassword = 'different-recovery-password';
  const maximumPolicy = NazaPostQuantumPolicy.testing();
  const legacyPolicy = NazaPostQuantumPolicy.testing(
    profile: NazaPostQuantumProfile.legacyHybrid,
  );
  final clearPayload = Uint8List.fromList(
    utf8.encode('{"format":"test-vault-export","records":[1,2,3]}'),
  );

  late NazaRecoveryBundle maximumBundle;
  late NazaRecoveryBundle otherMaximumBundle;
  late NazaRecoveryBundle legacyBundle;
  late String maximumEncryptedBackup;
  late String maximumKeyKit;
  late String maximumBackupArtifact;

  setUpAll(() async {
    maximumBundle = await NazaPostQuantumExport.generateRecoveryBundle(
      password: password,
      policy: maximumPolicy,
    );
    otherMaximumBundle = await NazaPostQuantumExport.generateRecoveryBundle(
      password: otherPassword,
      policy: maximumPolicy,
    );
    legacyBundle = await NazaPostQuantumExport.generateRecoveryBundle(
      password: password,
      policy: legacyPolicy,
    );

    maximumEncryptedBackup = await NazaPostQuantumExport.encryptBackup(
      clearBytes: clearPayload,
      recipientPublicKeyJson: maximumBundle.publicKeyJson,
      encryptedPrivateKeyJson: maximumBundle.encryptedPrivateKeyJson,
      recoveryPassword: password,
      payloadFormat: 'test-vault-export',
      recordCount: 3,
    );
    maximumKeyKit = NazaPostQuantumRecoveryCodec.buildKeyKit(maximumBundle);
    maximumBackupArtifact = NazaPostQuantumRecoveryCodec.buildBackupArtifact(
      encryptedBackupJson: maximumEncryptedBackup,
      recipient: await NazaPostQuantumExport.inspectPublicKey(
        maximumBundle.publicKeyJson,
      ),
    );
  });

  test(
    'separated v2 key kit and backup restore and decrypt end to end',
    () async {
      final kit = _jsonMap(maximumKeyKit);
      final artifact = _jsonMap(maximumBackupArtifact);

      expect(kit['format'], 'naza-pq-recovery-key-kit-v2');
      expect(kit['profile'], NazaPostQuantumProfile.maximumHybrid.wireName);
      expect(kit['suite'], NazaPostQuantumProfile.maximumHybrid.suite);
      expect(kit['fingerprint'], maximumBundle.fingerprint);
      expect(kit['publicKey'], isA<Map>());
      expect(kit['encryptedPrivateKey'], isA<Map>());

      expect(artifact['format'], 'naza-pq-recovery-backup-artifact-v2');
      expect(
        artifact['profile'],
        NazaPostQuantumProfile.maximumHybrid.wireName,
      );
      expect(artifact['suite'], NazaPostQuantumProfile.maximumHybrid.suite);
      expect(artifact['fingerprint'], maximumBundle.fingerprint);
      expect(artifact['encryptedBackup'], isA<Map>());
      expect(artifact, isNot(contains('encryptedPrivateKey')));

      final inspected =
          await NazaPostQuantumRecoveryCodec.inspectBackupArtifact(
            maximumBackupArtifact,
          );
      expect(inspected.profile, NazaPostQuantumProfile.maximumHybrid);
      expect(inspected.suite, maximumBundle.suite);
      expect(inspected.fingerprint, maximumBundle.fingerprint);
      expect(inspected.createdAt, isNotNull);
      expect(inspected.requiresSeparateKeyKit, isTrue);

      final material = await NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: maximumBackupArtifact,
        keyKitJson: maximumKeyKit,
      );
      expect(material.info.fingerprint, maximumBundle.fingerprint);
      expect(material.info.requiresSeparateKeyKit, isTrue);
      expect(
        _jsonMap(material.publicKeyJson),
        _jsonMap(maximumBundle.publicKeyJson),
      );

      final recovered = await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: material.encryptedBackupJson,
        encryptedPrivateKeyJson: material.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      expect(recovered, orderedEquals(clearPayload));

      final signingMaterial =
          await NazaPostQuantumRecoveryCodec.materialForBackupSigning(
            keyKitJson: maximumKeyKit,
            enrolledPublicKeyJson: maximumBundle.publicKeyJson,
          );
      expect(signingMaterial.info.fingerprint, maximumBundle.fingerprint);
      expect(
        _jsonMap(signingMaterial.encryptedPrivateKeyJson),
        _jsonMap(maximumBundle.encryptedPrivateKeyJson),
      );
    },
  );

  test('separated v2 recovery rejects missing and wrong key kits', () async {
    await expectLater(
      NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: maximumBackupArtifact,
      ),
      _throwsCode('recovery_key_required'),
    );

    final wrongIdentityKit = NazaPostQuantumRecoveryCodec.buildKeyKit(
      otherMaximumBundle,
    );
    await expectLater(
      NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: maximumBackupArtifact,
        keyKitJson: wrongIdentityKit,
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );

    final wrongFormatKit = _jsonMap(maximumKeyKit)
      ..['format'] = 'naza-pq-recovery-key-kit-v1';
    await expectLater(
      NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: maximumBackupArtifact,
        keyKitJson: jsonEncode(wrongFormatKit),
      ),
      _throwsCode('recovery_key_format'),
    );
  });

  test('tampered v2 outer manifest is rejected before decryption', () async {
    final fingerprintTamper = _jsonMap(maximumBackupArtifact)
      ..['fingerprint'] = 'attacker-controlled-fingerprint';
    await expectLater(
      NazaPostQuantumRecoveryCodec.inspectBackupArtifact(
        jsonEncode(fingerprintTamper),
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );
    await expectLater(
      NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: jsonEncode(fingerprintTamper),
        keyKitJson: maximumKeyKit,
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );

    final suiteTamper = _jsonMap(maximumBackupArtifact)
      ..['suite'] = NazaPostQuantumProfile.legacyHybrid.suite;
    await expectLater(
      NazaPostQuantumRecoveryCodec.inspectBackupArtifact(
        jsonEncode(suiteTamper),
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );

    final createdAtTamper = _jsonMap(maximumBackupArtifact)
      ..['createdAt'] = '2000-01-01T00:00:00.000Z';
    await expectLater(
      NazaPostQuantumRecoveryCodec.inspectBackupArtifact(
        jsonEncode(createdAtTamper),
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );

    final profileTamper = _jsonMap(maximumKeyKit)
      ..['profile'] = NazaPostQuantumProfile.legacyHybrid.wireName;
    await expectLater(
      NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: maximumBackupArtifact,
        keyKitJson: jsonEncode(profileTamper),
      ),
      _throwsCode('recovery_manifest_mismatch'),
    );
  });

  test(
    'explicit legacy v1 profile restores a historical combined package',
    () async {
      expect(legacyBundle.profile, NazaPostQuantumProfile.legacyHybrid);
      expect(legacyBundle.profile.isDefault, isFalse);

      final legacyEncryptedBackup = await NazaPostQuantumExport.encryptBackup(
        clearBytes: clearPayload,
        recipientPublicKeyJson: legacyBundle.publicKeyJson,
      );
      final combinedPackage = jsonEncode({
        'format': 'naza-hybrid-recovery-package-v1',
        'warning': 'Historical combined recovery package fixture.',
        'fingerprint': legacyBundle.fingerprint,
        'publicKey': jsonDecode(legacyBundle.publicKeyJson),
        'encryptedPrivateKey': jsonDecode(legacyBundle.encryptedPrivateKeyJson),
        'encryptedBackup': jsonDecode(legacyEncryptedBackup),
      });

      final inspected =
          await NazaPostQuantumRecoveryCodec.inspectBackupArtifact(
            combinedPackage,
          );
      expect(inspected.profile, NazaPostQuantumProfile.legacyHybrid);
      expect(inspected.suite, NazaPostQuantumProfile.legacyHybrid.suite);
      expect(inspected.fingerprint, legacyBundle.fingerprint);
      expect(inspected.createdAt, isNull);
      expect(inspected.requiresSeparateKeyKit, isFalse);

      final material = await NazaPostQuantumRecoveryCodec.materialForRestore(
        backupArtifactJson: combinedPackage,
      );
      expect(material.info.profile, NazaPostQuantumProfile.legacyHybrid);
      expect(material.info.requiresSeparateKeyKit, isFalse);

      final recovered = await NazaPostQuantumExport.decryptBackup(
        encryptedBackupJson: material.encryptedBackupJson,
        encryptedPrivateKeyJson: material.encryptedPrivateKeyJson,
        recoveryPassword: password,
      );
      expect(recovered, orderedEquals(clearPayload));
    },
  );
}

Map<String, Object?> _jsonMap(String value) {
  return Map<String, Object?>.from(jsonDecode(value) as Map);
}

Matcher _throwsCode(String code) {
  return throwsA(
    isA<NazaPostQuantumException>().having((error) => error.code, 'code', code),
  );
}
