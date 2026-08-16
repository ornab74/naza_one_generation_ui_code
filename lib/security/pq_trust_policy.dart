// LLM-CONTEXT:BEGIN
// FILE: lib/security/pq_trust_policy.dart
// ROLE: Owns pq trust policy behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Explicit post-quantum trust policy for long-lived Naza trust objects.
///
/// This does not replace record encryption. It governs whether recovery,
/// release, model, and trust-root manifests are cryptographically acceptable.
final class NazaPqTrustPolicy {
  final int generation;
  final int minimumGeneration;
  final bool requireHybridKem;
  final bool requirePqSignature;
  final bool requireClassicalSignature;
  final String minimumKem;
  final String minimumPqSignature;
  final Set<String> allowedKems;
  final Set<String> allowedPqSignatures;
  final Set<String> allowedClassicalSignatures;
  final Set<String> allowedClassicalKems;

  const NazaPqTrustPolicy({
    required this.generation,
    required this.minimumGeneration,
    required this.requireHybridKem,
    required this.requirePqSignature,
    required this.requireClassicalSignature,
    required this.minimumKem,
    required this.minimumPqSignature,
    required this.allowedKems,
    required this.allowedPqSignatures,
    required this.allowedClassicalSignatures,
    this.allowedClassicalKems = const <String>{'X25519'},
  });

  factory NazaPqTrustPolicy.maximum() => const NazaPqTrustPolicy(
    generation: 2,
    minimumGeneration: 2,
    requireHybridKem: true,
    requirePqSignature: true,
    requireClassicalSignature: true,
    minimumKem: 'ML-KEM-1024',
    minimumPqSignature: 'ML-DSA-87',
    allowedKems: <String>{'ML-KEM-1024'},
    allowedPqSignatures: <String>{'ML-DSA-87'},
    allowedClassicalSignatures: <String>{'Ed25519'},
    allowedClassicalKems: <String>{'X25519'},
  );

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'allowedClassicalSignatures': (allowedClassicalSignatures.toList()..sort()),
    'allowedClassicalKems': (allowedClassicalKems.toList()..sort()),
    'allowedKems': (allowedKems.toList()..sort()),
    'allowedPqSignatures': (allowedPqSignatures.toList()..sort()),
    'generation': generation,
    'minimumGeneration': minimumGeneration,
    'minimumKem': minimumKem,
    'minimumPqSignature': minimumPqSignature,
    'requireClassicalSignature': requireClassicalSignature,
    'requireHybridKem': requireHybridKem,
    'requirePqSignature': requirePqSignature,
  };

  String identity() {
    final bytes = utf8.encode(jsonEncode(toCanonicalMap()));
    return crypto.sha256.convert(bytes).toString();
  }

  void validateManifest(NazaPqManifestSecurity manifest) {
    if (manifest.generation < minimumGeneration) {
      throw const NazaPqTrustException(
        'pq_generation_downgrade',
        'The manifest generation is below the minimum accepted generation.',
      );
    }
    if (!allowedKems.contains(manifest.pqKem)) {
      throw NazaPqTrustException(
        'pq_kem_rejected',
        'Post-quantum KEM ${manifest.pqKem} is not accepted by policy.',
      );
    }
    if (requireHybridKem && manifest.classicalKem == null) {
      throw const NazaPqTrustException(
        'hybrid_kem_required',
        'The security policy requires an independent classical KEM component.',
      );
    }
    if (requireHybridKem &&
        !allowedClassicalKems.contains(manifest.classicalKem)) {
      throw const NazaPqTrustException(
        'classical_kem_rejected',
        'The hybrid manifest does not contain an approved classical KEM.',
      );
    }
    if (requirePqSignature) {
      final signature = manifest.pqSignature;
      if (signature == null || !allowedPqSignatures.contains(signature)) {
        throw const NazaPqTrustException(
          'pq_signature_required',
          'The security policy requires an approved post-quantum signature.',
        );
      }
    }
    if (requireClassicalSignature) {
      final signature = manifest.classicalSignature;
      if (signature == null ||
          !allowedClassicalSignatures.contains(signature)) {
        throw const NazaPqTrustException(
          'classical_signature_required',
          'The security policy requires an approved classical signature.',
        );
      }
    }
    if (_kemStrength(manifest.pqKem) < _kemStrength(minimumKem)) {
      throw const NazaPqTrustException(
        'pq_kem_downgrade',
        'The manifest KEM is weaker than the minimum accepted KEM.',
      );
    }
    final pqSignature = manifest.pqSignature;
    if (pqSignature != null &&
        _signatureStrength(pqSignature) < _signatureStrength(minimumPqSignature)) {
      throw const NazaPqTrustException(
        'pq_signature_downgrade',
        'The manifest signature is weaker than the minimum accepted signature.',
      );
    }
  }

  void validateTransition({
    required NazaPqTrustPolicy next,
    required bool oldRootApproved,
    required bool newRootSelfApproved,
  }) {
    if (!oldRootApproved || !newRootSelfApproved) {
      throw const NazaPqTrustException(
        'trust_transition_unapproved',
        'A trust-policy transition requires both old-root approval and new-root self-approval.',
      );
    }
    if (next.generation <= generation ||
        next.minimumGeneration < minimumGeneration ||
        _kemStrength(next.minimumKem) < _kemStrength(minimumKem) ||
        _signatureStrength(next.minimumPqSignature) <
            _signatureStrength(minimumPqSignature)) {
      throw const NazaPqTrustException(
        'trust_policy_downgrade',
        'The proposed post-quantum trust policy would weaken an enforced minimum.',
      );
    }
    if (requireHybridKem && !next.requireHybridKem) {
      throw const NazaPqTrustException(
        'trust_policy_downgrade',
        'Hybrid KEM enforcement cannot be silently disabled.',
      );
    }
    if (requirePqSignature && !next.requirePqSignature) {
      throw const NazaPqTrustException(
        'trust_policy_downgrade',
        'Post-quantum signature enforcement cannot be silently disabled.',
      );
    }
    if (requireClassicalSignature && !next.requireClassicalSignature) {
      throw const NazaPqTrustException(
        'trust_policy_downgrade',
        'Classical companion signature enforcement cannot be silently disabled.',
      );
    }
  }

  static int _kemStrength(String name) => switch (name) {
    'ML-KEM-512' => 1,
    'ML-KEM-768' => 2,
    'ML-KEM-1024' => 3,
    _ => 0,
  };

  static int _signatureStrength(String name) => switch (name) {
    'ML-DSA-44' => 1,
    'ML-DSA-65' => 2,
    'ML-DSA-87' => 3,
    _ => 0,
  };
}

final class NazaPqManifestSecurity {
  final int generation;
  final String pqKem;
  final String? classicalKem;
  final String? pqSignature;
  final String? classicalSignature;

  const NazaPqManifestSecurity({
    required this.generation,
    required this.pqKem,
    required this.classicalKem,
    required this.pqSignature,
    required this.classicalSignature,
  });
}

final class NazaPqTrustException implements Exception {
  final String code;
  final String message;

  const NazaPqTrustException(this.code, this.message);

  @override
  String toString() => 'NazaPqTrustException($code): $message';
}
