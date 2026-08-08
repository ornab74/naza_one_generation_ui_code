import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/intent_guard.dart';
import 'package:naza_one/security/security_kernel.dart';

void main() {
  const state = NazaSecurityState(
    epoch: 7,
    vaultId: 'abcdefghijklmnop',
    appIdentity: 'app',
    modelIdentity: 'model',
    policyIdentity: 'policy',
    recoveryGeneration: 'recovery',
    trustRootIdentity: 'root',
  );

  test('external content cannot authorize privileged action', () {
    const intent = NazaProposedIntent(
      id: 'intent-1',
      operation: 'export vault',
      risk: NazaIntentRisk.privileged,
      privilegedAction: NazaPrivilegedAction.exportVault,
      resource: 'vault',
      explicitUserRequest: false,
      provenance: <NazaContextProvenance>[
        NazaContextProvenance(
          sourceId: 'web-page',
          trustClass: NazaTrustClass.externalUntrusted,
          sensitivity: 'public',
          securityEpoch: 7,
        ),
      ],
    );

    final decision = const NazaIntentGuard().evaluate(
      intent: intent,
      state: state,
    );
    expect(decision.allowed, isFalse);
    expect(decision.freshAuthorizationRequired, isFalse);
    expect(decision.reason, 'untrusted-content-cannot-authorize-actions');
  });

  test('model generated command cannot self-authorize', () {
    const intent = NazaProposedIntent(
      id: 'intent-2',
      operation: 'rotate keys',
      risk: NazaIntentRisk.privileged,
      privilegedAction: NazaPrivilegedAction.rotateKeys,
      resource: 'vault',
      explicitUserRequest: false,
      provenance: <NazaContextProvenance>[
        NazaContextProvenance(
          sourceId: 'model-output',
          trustClass: NazaTrustClass.modelGenerated,
          sensitivity: 'private',
          securityEpoch: 7,
        ),
      ],
    );

    final decision = const NazaIntentGuard().evaluate(
      intent: intent,
      state: state,
    );
    expect(decision.allowed, isFalse);
    expect(decision.freshAuthorizationRequired, isFalse);
  });

  test('stale provenance is rejected even for explicit user intent', () {
    const intent = NazaProposedIntent(
      id: 'intent-3',
      operation: 'read history',
      risk: NazaIntentRisk.privateRead,
      privilegedAction: null,
      resource: 'history',
      explicitUserRequest: true,
      provenance: <NazaContextProvenance>[
        NazaContextProvenance(
          sourceId: 'old-session',
          trustClass: NazaTrustClass.userAuthored,
          sensitivity: 'private',
          securityEpoch: 6,
        ),
      ],
    );

    final decision = const NazaIntentGuard().evaluate(
      intent: intent,
      state: state,
    );
    expect(decision.allowed, isFalse);
    expect(decision.reason, 'stale-provenance');
  });

  test('explicit user private read is allowed without privilege lease', () {
    const intent = NazaProposedIntent(
      id: 'intent-4',
      operation: 'read history',
      risk: NazaIntentRisk.privateRead,
      privilegedAction: null,
      resource: 'history',
      explicitUserRequest: true,
      provenance: <NazaContextProvenance>[
        NazaContextProvenance(
          sourceId: 'user',
          trustClass: NazaTrustClass.userAuthored,
          sensitivity: 'private',
          securityEpoch: 7,
        ),
      ],
    );

    final decision = const NazaIntentGuard().evaluate(
      intent: intent,
      state: state,
    );
    expect(decision.allowed, isTrue);
    expect(decision.freshAuthorizationRequired, isFalse);
  });

  test('privileged action requires and consumes exact one-shot lease', () async {
    final kernel = NazaSecurityKernel(
      capabilityKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
      initialState: state,
    );
    addTearDown(kernel.destroy);

    const intent = NazaProposedIntent(
      id: 'intent-5',
      operation: 'export vault',
      risk: NazaIntentRisk.privileged,
      privilegedAction: NazaPrivilegedAction.exportVault,
      resource: 'vault',
      explicitUserRequest: true,
      provenance: <NazaContextProvenance>[
        NazaContextProvenance(
          sourceId: 'user',
          trustClass: NazaTrustClass.userAuthored,
          sensitivity: 'private',
          securityEpoch: 7,
        ),
      ],
    );

    final guard = const NazaIntentGuard();
    final decision = guard.evaluate(intent: intent, state: state);
    expect(decision.allowed, isFalse);
    expect(decision.freshAuthorizationRequired, isTrue);

    final lease = await kernel.issueLease(
      action: NazaPrivilegedAction.exportVault,
      resource: 'vault',
    );
    await guard.authorizePrivileged(
      decision: decision,
      intent: intent,
      kernel: kernel,
      lease: lease,
    );

    await expectLater(
      guard.authorizePrivileged(
        decision: decision,
        intent: intent,
        kernel: kernel,
        lease: lease,
      ),
      throwsA(isA<NazaSecurityException>()),
    );
  });
}
