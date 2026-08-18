// LLM-CONTEXT:BEGIN
// FILE: test_archive/security_kernel_test.dart
// ROLE: Owns security kernel test behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/security_kernel.dart';

void main() {
  NazaSecurityState state(int epoch, {String model = 'model-a'}) {
    return NazaSecurityState(
      epoch: epoch,
      vaultId: 'vault-1234567890abcdef',
      appIdentity: 'app-sha256:aaa',
      modelIdentity: model,
      policyIdentity: 'policy-sha256:bbb',
      recoveryGeneration: 'recovery-7',
      trustRootIdentity: 'trust-root-3',
    );
  }

  test('capability kernel rejects weak or malformed key lengths', () {
    for (final length in <int>[0, 16, 31, 33, 64]) {
      expect(
        () => NazaSecurityKernel(
          capabilityKey: Uint8List(length),
          initialState: state(1),
        ),
        throwsArgumentError,
        reason: 'length $length',
      );
    }
    expect(
      () => NazaSecurityKernel(
        capabilityKey: Uint8List(32),
        initialState: state(1),
      ),
      returnsNormally,
    );
  });

  test('single-use capability cannot be replayed', () async {
    final kernel = NazaSecurityKernel(
      capabilityKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      initialState: state(10),
    );

    final lease = await kernel.issueLease(
      action: NazaPrivilegedAction.exportVault,
      resource: 'vault-1234567890abcdef',
    );

    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.exportVault,
      resource: 'vault-1234567890abcdef',
    );

    expect(
      () => kernel.consumeLease(
        lease,
        action: NazaPrivilegedAction.exportVault,
        resource: 'vault-1234567890abcdef',
      ),
      throwsA(isA<NazaSecurityException>()),
    );
  });

  test('unused capability expires on monotonic time', () async {
    var monotonicMicros = 0;
    final kernel = NazaSecurityKernel(
      capabilityKey: Uint8List.fromList(List<int>.filled(32, 11)),
      initialState: state(11),
      monotonicMicros: () => monotonicMicros,
    );
    final lease = await kernel.issueLease(
      action: NazaPrivilegedAction.changeRecovery,
      resource: 'recovery',
      ttl: const Duration(seconds: 30),
    );

    monotonicMicros += const Duration(seconds: 31).inMicroseconds;

    await expectLater(
      kernel.consumeLease(
        lease,
        action: NazaPrivilegedAction.changeRecovery,
        resource: 'recovery',
      ),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          'capability_expired',
        ),
      ),
    );
  });

  test('capability is invalidated when security state changes', () async {
    final kernel = NazaSecurityKernel(
      capabilityKey: Uint8List.fromList(List<int>.filled(32, 7)),
      initialState: state(20),
    );

    final lease = await kernel.issueLease(
      action: NazaPrivilegedAction.replaceModel,
      resource: 'model-slot',
      maxUses: 2,
    );

    kernel.transition(state(21, model: 'model-b'));

    expect(
      () => kernel.consumeLease(
        lease,
        action: NazaPrivilegedAction.replaceModel,
        resource: 'model-slot',
      ),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          anyOf('capability_invalid', 'capability_stale'),
        ),
      ),
    );
  });

  test('security epoch cannot move backwards', () {
    final kernel = NazaSecurityKernel(
      capabilityKey: Uint8List.fromList(List<int>.filled(32, 9)),
      initialState: state(30),
    );

    expect(
      () => kernel.transition(state(29)),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          'epoch_rollback',
        ),
      ),
    );
  });

  test('rollback guard rejects an older persisted epoch', () async {
    final store = NazaMemoryCounterStore();
    final guard = NazaRollbackGuard(store, storageKey: 'vault/epoch');

    await guard.commit(42);
    await guard.verify(42);
    await guard.verify(43);

    expect(
      () => guard.verify(41),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          'rollback_detected',
        ),
      ),
    );
  });

  test('audit chain advances sequence and previous-tip binding', () async {
    final audit = NazaForwardSecureAudit(
      initialKey: Uint8List.fromList(List<int>.generate(32, (i) => 255 - i)),
    );

    final first = await audit.append(
      event: 'vault_unlock',
      data: const {'method': 'password'},
      securityEpoch: 5,
    );
    final firstTip = audit.tip;
    final second = await audit.append(
      event: 'model_attested',
      data: const {'model': 'sha256:abc'},
      securityEpoch: 5,
    );

    expect(first.sequence, 1);
    expect(second.sequence, 2);
    expect(second.previous, firstTip);
    expect(audit.tip, isNot(firstTip));
  });

  test('state digest changes when a bound security identity changes', () async {
    final key = Uint8List.fromList(List<int>.filled(32, 3));
    final firstKernel = NazaSecurityKernel(
      capabilityKey: key,
      initialState: state(1, model: 'model-a'),
    );
    final secondKernel = NazaSecurityKernel(
      capabilityKey: key,
      initialState: state(1, model: 'model-b'),
    );

    expect(
      await firstKernel.stateDigest(),
      isNot(await secondKernel.stateDigest()),
    );
  });
}
