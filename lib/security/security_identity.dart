import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'post_quantum_export.dart';
import 'pq_trust_policy.dart';

/// Structured model identity that can only be constructed from verified model
/// attestation data. This keeps the security kernel from accepting a free-form
/// caller string as the model trust identity.
final class NazaVerifiedModelIdentity {
  final String modelSha256;
  final String tokenizerSha256;
  final String runtimeIdentity;
  final String backendIdentity;
  final String policySha256;

  const NazaVerifiedModelIdentity({
    required this.modelSha256,
    required this.tokenizerSha256,
    required this.runtimeIdentity,
    required this.backendIdentity,
    required this.policySha256,
  });

  void validate() {
    _requireHexDigest(modelSha256, 'modelSha256');
    _requireHexDigest(tokenizerSha256, 'tokenizerSha256');
    _requireHexDigest(policySha256, 'policySha256');
    if (runtimeIdentity.trim().isEmpty || backendIdentity.trim().isEmpty) {
      throw const NazaSecurityIdentityException(
        'model_identity_incomplete',
        'Verified model identity requires runtime and backend identity.',
      );
    }
  }

  Map<String, Object?> toCanonicalMap() {
    validate();
    return <String, Object?>{
      'backendIdentity': backendIdentity,
      'modelSha256': modelSha256.toLowerCase(),
      'policySha256': policySha256.toLowerCase(),
      'runtimeIdentity': runtimeIdentity,
      'tokenizerSha256': tokenizerSha256.toLowerCase(),
    };
  }
}

final class NazaSecurityIdentitySnapshot {
  final String modelIdentity;
  final String recoveryIdentity;
  final String trustPolicyIdentity;

  const NazaSecurityIdentitySnapshot({
    required this.modelIdentity,
    required this.recoveryIdentity,
    required this.trustPolicyIdentity,
  });
}

/// Derives security-kernel identities from validated structured state rather
/// than accepting caller-provided identity strings.
final class NazaSecurityIdentityDeriver {
  const NazaSecurityIdentityDeriver();

  Future<NazaSecurityIdentitySnapshot> derive({
    required NazaVerifiedModelIdentity model,
    required NazaPostQuantumRecoveryState recovery,
    required NazaPqTrustPolicy trustPolicy,
  }) async {
    model.validate();
    _validateRecoveryState(recovery);
    _validateTrustPolicy(trustPolicy);

    final modelIdentity = await _digestMap(<String, Object?>{
      'kind': 'model-attestation',
      ...model.toCanonicalMap(),
    });
    final recoveryIdentity = await _digestMap(<String, Object?>{
      'kind': 'pq-recovery-state',
      'format': NazaPostQuantumRecoveryState.format,
      'policyEnabled': recovery.policyEnabled,
      'profile': recovery.profile.wireName,
      'suite': recovery.suite,
      'status': recovery.status.name,
      'fingerprint': recovery.fingerprint ?? '',
      'enrolledAt': recovery.enrolledAt?.toUtc().toIso8601String() ?? '',
      'lastVerifiedAt': recovery.lastVerifiedAt?.toUtc().toIso8601String() ?? '',
    });
    final trustIdentity = trustPolicy.identity();

    return NazaSecurityIdentitySnapshot(
      modelIdentity: modelIdentity,
      recoveryIdentity: recoveryIdentity,
      trustPolicyIdentity: trustIdentity,
    );
  }

  void _validateRecoveryState(NazaPostQuantumRecoveryState recovery) {
    if (!recovery.policyEnabled) {
      throw const NazaSecurityIdentityException(
        'recovery_policy_disabled',
        'Post-quantum recovery policy must remain enabled in hardened mode.',
      );
    }
    if (recovery.profile != NazaPostQuantumProfile.maximumHybrid ||
        recovery.suite != NazaPostQuantumProfile.maximumHybrid.suite) {
      throw const NazaSecurityIdentityException(
        'recovery_downgrade',
        'Hardened mode requires the maximum hybrid post-quantum recovery profile.',
      );
    }
    if (recovery.status != NazaPostQuantumRecoveryStatus.actionRequired) {
      final fingerprint = recovery.fingerprint ?? '';
      if (fingerprint.isEmpty || recovery.enrolledAt == null) {
        throw const NazaSecurityIdentityException(
          'recovery_identity_incomplete',
          'Enrolled recovery state is missing its authenticated identity metadata.',
        );
      }
    }
  }

  void _validateTrustPolicy(NazaPqTrustPolicy policy) {
    if (policy.generation < policy.minimumGeneration ||
        policy.minimumGeneration < 2 ||
        !policy.requireHybridKem ||
        !policy.requirePqSignature ||
        !policy.requireClassicalSignature ||
        policy.minimumKem != 'ML-KEM-1024' ||
        policy.minimumPqSignature != 'ML-DSA-87' ||
        !policy.allowedKems.contains('ML-KEM-1024') ||
        !policy.allowedPqSignatures.contains('ML-DSA-87') ||
        !policy.allowedClassicalSignatures.contains('Ed25519')) {
      throw const NazaSecurityIdentityException(
        'trust_policy_downgrade',
        'Hardened mode requires the maximum hybrid post-quantum trust policy.',
      );
    }
  }

  Future<String> _digestMap(Map<String, Object?> map) async {
    final digest = await Sha256().hash(
      utf8.encode(jsonEncode(_canonicalize(map))),
    );
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

final class NazaSecurityIdentityException implements Exception {
  final String code;
  final String message;

  const NazaSecurityIdentityException(this.code, this.message);

  @override
  String toString() => 'NazaSecurityIdentityException($code): $message';
}

void _requireHexDigest(String value, String label) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
    throw NazaSecurityIdentityException(
      'invalid_digest',
      '$label must be a 32-byte SHA-256 hex digest.',
    );
  }
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value
        .map<Object?>((item) => _canonicalize(item))
        .toList(growable: false);
  }
  if (value is num || value is bool || value is String || value == null) {
    return value;
  }
  return value.toString();
}
