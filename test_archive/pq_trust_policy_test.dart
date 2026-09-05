// LLM-CONTEXT:BEGIN
// FILE: test_archive/pq_trust_policy_test.dart
// ROLE: Owns pq trust policy test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('maximum policy accepts hybrid ML-KEM-1024 with dual signatures', () {
    final policy = NazaPqTrustPolicy.maximum();
    policy.validateManifest(
      const NazaPqManifestSecurity(
        generation: 2,
        pqKem: 'ML-KEM-1024',
        classicalKem: 'X25519',
        pqSignature: 'ML-DSA-87',
        classicalSignature: 'Ed25519',
      ),
    );
    expect(policy.identity(), hasLength(64));
  });

  test('maximum policy rejects legacy ML-KEM-768 downgrade', () {
    final policy = NazaPqTrustPolicy.maximum();
    expect(
      () => policy.validateManifest(
        const NazaPqManifestSecurity(
          generation: 2,
          pqKem: 'ML-KEM-768',
          classicalKem: 'X25519',
          pqSignature: 'ML-DSA-87',
          classicalSignature: 'Ed25519',
        ),
      ),
      throwsA(
        isA<NazaPqTrustException>().having(
          (error) => error.code,
          'code',
          anyOf('pq_kem_rejected', 'pq_kem_downgrade'),
        ),
      ),
    );
  });

  test('maximum policy rejects missing classical companion', () {
    final policy = NazaPqTrustPolicy.maximum();
    expect(
      () => policy.validateManifest(
        const NazaPqManifestSecurity(
          generation: 2,
          pqKem: 'ML-KEM-1024',
          classicalKem: null,
          pqSignature: 'ML-DSA-87',
          classicalSignature: 'Ed25519',
        ),
      ),
      throwsA(
        isA<NazaPqTrustException>().having(
          (error) => error.code,
          'code',
          'hybrid_kem_required',
        ),
      ),
    );
  });

  test('maximum policy rejects unsigned or singly signed trust objects', () {
    final policy = NazaPqTrustPolicy.maximum();
    expect(
      () => policy.validateManifest(
        const NazaPqManifestSecurity(
          generation: 2,
          pqKem: 'ML-KEM-1024',
          classicalKem: 'X25519',
          pqSignature: null,
          classicalSignature: 'Ed25519',
        ),
      ),
      throwsA(isA<NazaPqTrustException>()),
    );
    expect(
      () => policy.validateManifest(
        const NazaPqManifestSecurity(
          generation: 2,
          pqKem: 'ML-KEM-1024',
          classicalKem: 'X25519',
          pqSignature: 'ML-DSA-87',
          classicalSignature: null,
        ),
      ),
      throwsA(isA<NazaPqTrustException>()),
    );
  });

  test('trust policy transition cannot lower enforced minima', () {
    final policy = NazaPqTrustPolicy.maximum();
    const weaker = NazaPqTrustPolicy(
      generation: 3,
      minimumGeneration: 2,
      requireHybridKem: true,
      requirePqSignature: true,
      requireClassicalSignature: true,
      minimumKem: 'ML-KEM-768',
      minimumPqSignature: 'ML-DSA-65',
      allowedKems: {'ML-KEM-768', 'ML-KEM-1024'},
      allowedPqSignatures: {'ML-DSA-65', 'ML-DSA-87'},
      allowedClassicalSignatures: {'Ed25519'},
    );

    expect(
      () => policy.validateTransition(
        next: weaker,
        oldRootApproved: true,
        newRootSelfApproved: true,
      ),
      throwsA(
        isA<NazaPqTrustException>().having(
          (error) => error.code,
          'code',
          'trust_policy_downgrade',
        ),
      ),
    );
  });
}
