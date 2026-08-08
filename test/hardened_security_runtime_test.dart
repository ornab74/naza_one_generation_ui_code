import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/hardened_security_runtime.dart';
import 'package:naza_one/security/key_guardian.dart';
import 'package:naza_one/security/post_quantum_export.dart';
import 'package:naza_one/security/pq_trust_policy.dart';
import 'package:naza_one/security/secure_database.dart';
import 'package:naza_one/security/security_identity.dart';
import 'package:naza_one/security/security_kernel.dart';

void main() {
  late Directory directory;
  late NazaMemoryDeviceKeyStore secureStore;
  late NazaSecureDatabase vault;
  late NazaHardenedSecurityRuntime runtime;

  const model = NazaVerifiedModelIdentity(
    modelSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    tokenizerSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    runtimeIdentity: 'litert-lm/test-runtime',
    backendIdentity: 'cpu-test-backend',
    policySha256:
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-hardened-runtime-');
    secureStore = NazaMemoryDeviceKeyStore();
    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: secureStore,
    );
    runtime = NazaHardenedSecurityRuntime(
      vault: vault,
      secureStore: secureStore,
      guardian: NazaSecureStoreKeyGuardian(secureStore),
      appIdentity: 'naza-test-app',
      trustRootIdentity: 'test-root-v1',
    );
  });

  tearDown(() async {
    await runtime.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('derives stable identities from structured model and recovery state', () async {
    final recovery = NazaPostQuantumRecoveryState.defaults();
    final deriver = const NazaSecurityIdentityDeriver();

    final first = await deriver.derive(
      model: model,
      recovery: recovery,
      trustPolicy: NazaPqTrustPolicy.maximum(),
    );
    final second = await deriver.derive(
      model: model,
      recovery: recovery,
      trustPolicy: NazaPqTrustPolicy.maximum(),
    );

    expect(first.modelIdentity, second.modelIdentity);
    expect(first.recoveryIdentity, second.recoveryIdentity);
    expect(first.trustPolicyIdentity, second.trustPolicyIdentity);
    expect(first.modelIdentity, isNotEmpty);
    expect(first.recoveryIdentity, isNotEmpty);
  });

  test('rejects malformed model attestation digests', () async {
    const malformed = NazaVerifiedModelIdentity(
      modelSha256: 'not-a-sha256',
      tokenizerSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      runtimeIdentity: 'runtime',
      backendIdentity: 'backend',
      policySha256:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );

    await expectLater(
      const NazaSecurityIdentityDeriver().derive(
        model: malformed,
        recovery: NazaPostQuantumRecoveryState.defaults(),
        trustPolicy: NazaPqTrustPolicy.maximum(),
      ),
      throwsA(isA<NazaSecurityIdentityException>()),
    );
  });

  test('runtime persists audit continuity across lock and unlock', () async {
    await runtime.create(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
      initialRecords: const <NazaVaultRecordKey, Object?>{
        NazaVaultRecordKey('history', 'one'): <String, Object?>{'value': 1},
      },
    );

    expect(runtime.isReady, isTrue);
    final firstSequence = runtime.auditSequence;
    expect(firstSequence, isNotNull);
    expect(firstSequence!, greaterThan(0));
    await runtime.verifyPersistentAudit();

    await runtime.lock();
    expect(runtime.isReady, isFalse);

    runtime = NazaHardenedSecurityRuntime(
      vault: vault,
      secureStore: secureStore,
      guardian: NazaSecureStoreKeyGuardian(secureStore),
      appIdentity: 'naza-test-app',
      trustRootIdentity: 'test-root-v1',
    );
    await runtime.unlock(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
    );

    expect(runtime.isReady, isTrue);
    expect(runtime.auditSequence, greaterThan(firstSequence));
    await runtime.verifyPersistentAudit();
  });

  test('one-shot privileged rotation advances security epoch', () async {
    await runtime.create(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
    );

    final beforeEpoch = runtime.securityEpoch!;
    final beforeKey = vault.activeDataKeyId;
    final lease = await runtime.authorizeWithPassword(
      password: 'runtime-password',
      action: NazaPrivilegedAction.rotateKeys,
    );

    await runtime.rotateDataKeyAuthorized(lease);

    expect(runtime.securityEpoch, beforeEpoch + 1);
    expect(vault.activeDataKeyId, isNot(beforeKey));
    await runtime.verifyPersistentAudit();

    await expectLater(
      runtime.rotateDataKeyAuthorized(lease),
      throwsA(isA<NazaSecurityException>()),
    );
  });

  test('user export strips every internal security namespace', () async {
    await runtime.create(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
      initialRecords: const <NazaVaultRecordKey, Object?>{
        NazaVaultRecordKey('history', 'one'): <String, Object?>{'value': 1},
      },
    );

    final lease = await runtime.authorizeWithPassword(
      password: 'runtime-password',
      action: NazaPrivilegedAction.exportVault,
    );
    final exported = await runtime.exportRecordsAuthorized(lease);

    expect(exported.keys, contains(const NazaVaultRecordKey('history', 'one')));
    expect(
      exported.keys.where((key) => key.namespace.startsWith('security.')),
      isEmpty,
    );
  });
}
