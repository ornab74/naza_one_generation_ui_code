// LLM-CONTEXT:BEGIN
// FILE: test_archive/hardened_security_runtime_test.dart
// ROLE: Owns hardened security runtime test behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  late Directory directory;
  late NazaMemoryDeviceKeyStore secureStore;
  late NazaSecureDatabase vault;
  late NazaHardenedSecurityRuntime runtime;
  late File modelFile;
  late File tokenizerFile;
  late List<int> policyBytes;
  late NazaVerifiedModelIdentity model;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-hardened-runtime-');
    modelFile = File('${directory.path}/model.bin');
    tokenizerFile = File('${directory.path}/tokenizer.bin');
    final modelBytes = utf8.encode('verified-model-bytes-v1');
    final tokenizerBytes = utf8.encode('verified-tokenizer-bytes-v1');
    policyBytes = utf8.encode('verified-policy-bytes-v1');
    await modelFile.writeAsBytes(modelBytes, flush: true);
    await tokenizerFile.writeAsBytes(tokenizerBytes, flush: true);
    model = await const NazaModelFileAttestor().attest(
      modelFile: modelFile,
      tokenizerFile: tokenizerFile,
      policyBytes: policyBytes,
      expectedModelSha256: crypto.sha256.convert(modelBytes).toString(),
      expectedTokenizerSha256: crypto.sha256.convert(tokenizerBytes).toString(),
      expectedPolicySha256: crypto.sha256.convert(policyBytes).toString(),
      expectedModelBytes: modelBytes.length,
      expectedTokenizerBytes: tokenizerBytes.length,
      runtimeIdentity: 'litert-lm/test-runtime',
      backendIdentity: 'cpu-test-backend',
    );

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

  test('derives stable identities from byte-verified model and recovery state', () async {
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

  test('model substitution fails attestation before identity minting', () async {
    await modelFile.writeAsString('attacker-substituted-model', flush: true);

    await expectLater(
      const NazaModelFileAttestor().attest(
        modelFile: modelFile,
        tokenizerFile: tokenizerFile,
        policyBytes: policyBytes,
        expectedModelSha256: model.modelSha256,
        expectedTokenizerSha256: model.tokenizerSha256,
        expectedPolicySha256: model.policySha256,
        runtimeIdentity: 'litert-lm/test-runtime',
        backendIdentity: 'cpu-test-backend',
      ),
      throwsA(isA<NazaSecurityIdentityException>()),
    );
  });

  test('model replacement after runtime start removes privileged authority', () async {
    await runtime.create(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
    );

    // Preserve length so the defense must reach the digest check rather than
    // relying only on a cheap file-size mismatch.
    final replacement = List<int>.filled(model.modelBytes, 0x41);
    await modelFile.writeAsBytes(replacement, flush: true);

    await expectLater(
      runtime.authorizeWithPassword(
        password: 'runtime-password',
        action: NazaPrivilegedAction.exportVault,
      ),
      throwsA(
        isA<NazaSecurityIdentityException>().having(
          (error) => error.code,
          'code',
          'model_digest_mismatch',
        ),
      ),
    );
  });

  test('runtime persists audit continuity across lock and unlock', () async {
    await runtime.create(
      password: 'runtime-password',
      model: model,
      recovery: NazaPostQuantumRecoveryState.defaults(),
      initialRecords: <NazaVaultRecordKey, Object?>{
        const NazaVaultRecordKey('history', 'one'): <String, Object?>{'value': 1},
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
      initialRecords: <NazaVaultRecordKey, Object?>{
        const NazaVaultRecordKey('history', 'one'): <String, Object?>{'value': 1},
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
