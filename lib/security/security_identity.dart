// LLM-CONTEXT:BEGIN
// FILE: lib/security/security_identity.dart
// ROLE: Owns security identity behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import 'post_quantum_export.dart';
import 'pq_trust_policy.dart';

/// Identity minted only after hashing actual model/tokenizer/policy bytes.
///
/// The source paths are retained privately so hardened runtime entry and
/// privileged operations can re-verify the artifacts, closing the common
/// "verify once, replace later" trust gap.
final class NazaVerifiedModelIdentity {
  final String modelSha256;
  final String tokenizerSha256;
  final String runtimeIdentity;
  final String backendIdentity;
  final String policySha256;
  final int modelBytes;
  final int tokenizerBytes;
  final String _modelPath;
  final String _tokenizerPath;
  final List<int> _policyBytes;

  NazaVerifiedModelIdentity._({
    required this.modelSha256,
    required this.tokenizerSha256,
    required this.runtimeIdentity,
    required this.backendIdentity,
    required this.policySha256,
    required this.modelBytes,
    required this.tokenizerBytes,
    required String modelPath,
    required String tokenizerPath,
    required List<int> policyBytes,
  }) :
       // Private source bindings intentionally keep public constructor names
       // while retaining private fields for runtime re-verification.
       // ignore: prefer_initializing_formals
       _modelPath = modelPath,
       // ignore: prefer_initializing_formals
       _tokenizerPath = tokenizerPath,
       _policyBytes = List<int>.unmodifiable(policyBytes);

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
    if (modelBytes < 1 || tokenizerBytes < 1) {
      throw const NazaSecurityIdentityException(
        'model_identity_size',
        'Verified model identity requires non-empty model and tokenizer artifacts.',
      );
    }
    if (_modelPath.isEmpty || _tokenizerPath.isEmpty) {
      throw const NazaSecurityIdentityException(
        'model_identity_path',
        'Verified model identity lost its source artifact binding.',
      );
    }
  }

  /// Re-hashes the bound files and verifies exact byte lengths. Hardened code
  /// should call this immediately before opening a model for inference and
  /// before security-sensitive operations that depend on model identity.
  Future<void> reverifyArtifacts() async {
    validate();
    final modelFile = File(_modelPath);
    final tokenizerFile = File(_tokenizerPath);
    if (!await modelFile.exists() || !await tokenizerFile.exists()) {
      throw const NazaSecurityIdentityException(
        'model_artifact_missing',
        'The previously attested model or tokenizer artifact is missing.',
      );
    }
    final modelStat = await modelFile.stat();
    final tokenizerStat = await tokenizerFile.stat();
    if (modelStat.size != modelBytes) {
      throw const NazaSecurityIdentityException(
        'model_size_mismatch',
        'The model artifact changed after attestation.',
      );
    }
    if (tokenizerStat.size != tokenizerBytes) {
      throw const NazaSecurityIdentityException(
        'tokenizer_size_mismatch',
        'The tokenizer artifact changed after attestation.',
      );
    }
    final modelDigest = await _sha256File(modelFile);
    final tokenizerDigest = await _sha256File(tokenizerFile);
    if (_policyBytes.isEmpty) {
      throw const NazaSecurityIdentityException(
        'policy_artifact_unbound',
        'The attested policy has no retained source binding for re-verification.',
      );
    }
    final policyDigest = crypto.sha256.convert(_policyBytes).toString();
    _requireDigestMatch(
      actual: policyDigest,
      expected: policySha256,
      code: 'policy_digest_mismatch',
      message: 'The model policy bytes changed after attestation.',
    );
    _requireDigestMatch(
      actual: modelDigest,
      expected: modelSha256,
      code: 'model_digest_mismatch',
      message: 'The model bytes changed after attestation.',
    );
    _requireDigestMatch(
      actual: tokenizerDigest,
      expected: tokenizerSha256,
      code: 'tokenizer_digest_mismatch',
      message: 'The tokenizer bytes changed after attestation.',
    );
  }

  Map<String, Object?> toCanonicalMap() {
    validate();
    return <String, Object?>{
      'backendIdentity': backendIdentity,
      'modelBytes': modelBytes,
      'modelSha256': modelSha256.toLowerCase(),
      'policySha256': policySha256.toLowerCase(),
      'runtimeIdentity': runtimeIdentity,
      'tokenizerBytes': tokenizerBytes,
      'tokenizerSha256': tokenizerSha256.toLowerCase(),
    };
  }
}

final class NazaModelFileAttestor {
  const NazaModelFileAttestor();

  Future<NazaVerifiedModelIdentity> attest({
    required File modelFile,
    required File tokenizerFile,
    required List<int> policyBytes,
    required String expectedModelSha256,
    required String expectedTokenizerSha256,
    required String expectedPolicySha256,
    required String runtimeIdentity,
    required String backendIdentity,
    int? expectedModelBytes,
    int? expectedTokenizerBytes,
  }) async {
    _requireHexDigest(expectedModelSha256, 'expectedModelSha256');
    _requireHexDigest(expectedTokenizerSha256, 'expectedTokenizerSha256');
    _requireHexDigest(expectedPolicySha256, 'expectedPolicySha256');
    if (runtimeIdentity.trim().isEmpty || backendIdentity.trim().isEmpty) {
      throw const NazaSecurityIdentityException(
        'model_identity_incomplete',
        'Runtime and backend identity are required for model attestation.',
      );
    }
    if (policyBytes.isEmpty) {
      throw const NazaSecurityIdentityException(
        'policy_empty',
        'The attested model policy must not be empty.',
      );
    }
    if (!await modelFile.exists() || !await tokenizerFile.exists()) {
      throw const NazaSecurityIdentityException(
        'model_artifact_missing',
        'The model or tokenizer artifact is missing.',
      );
    }

    final modelStat = await modelFile.stat();
    final tokenizerStat = await tokenizerFile.stat();
    if (modelStat.size < 1 || tokenizerStat.size < 1) {
      throw const NazaSecurityIdentityException(
        'model_artifact_empty',
        'The model and tokenizer artifacts must not be empty.',
      );
    }
    if (expectedModelBytes != null && modelStat.size != expectedModelBytes) {
      throw const NazaSecurityIdentityException(
        'model_size_mismatch',
        'The model artifact length does not match the trusted manifest.',
      );
    }
    if (expectedTokenizerBytes != null &&
        tokenizerStat.size != expectedTokenizerBytes) {
      throw const NazaSecurityIdentityException(
        'tokenizer_size_mismatch',
        'The tokenizer artifact length does not match the trusted manifest.',
      );
    }

    final modelDigest = await _sha256File(modelFile);
    final tokenizerDigest = await _sha256File(tokenizerFile);
    final policyDigest = crypto.sha256.convert(policyBytes).toString();

    _requireDigestMatch(
      actual: modelDigest,
      expected: expectedModelSha256,
      code: 'model_digest_mismatch',
      message: 'The model bytes do not match the trusted SHA-256.',
    );
    _requireDigestMatch(
      actual: tokenizerDigest,
      expected: expectedTokenizerSha256,
      code: 'tokenizer_digest_mismatch',
      message: 'The tokenizer bytes do not match the trusted SHA-256.',
    );
    _requireDigestMatch(
      actual: policyDigest,
      expected: expectedPolicySha256,
      code: 'policy_digest_mismatch',
      message: 'The model policy bytes do not match the trusted SHA-256.',
    );

    return NazaVerifiedModelIdentity._(
      modelSha256: modelDigest,
      tokenizerSha256: tokenizerDigest,
      runtimeIdentity: runtimeIdentity,
      backendIdentity: backendIdentity,
      policySha256: policyDigest,
      modelBytes: modelStat.size,
      tokenizerBytes: tokenizerStat.size,
      modelPath: modelFile.absolute.path,
      tokenizerPath: tokenizerFile.absolute.path,
      policyBytes: policyBytes,
    );
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

Future<String> _sha256File(File file) async {
  final digest = await crypto.sha256.bind(file.openRead()).first;
  return digest.toString();
}

void _requireDigestMatch({
  required String actual,
  required String expected,
  required String code,
  required String message,
}) {
  if (!_constantTimeHexEquals(actual, expected)) {
    throw NazaSecurityIdentityException(code, message);
  }
}

bool _constantTimeHexEquals(String a, String b) {
  final aa = ascii.encode(a.toLowerCase());
  final bb = ascii.encode(b.toLowerCase());
  var difference = aa.length ^ bb.length;
  final length = aa.length < bb.length ? aa.length : bb.length;
  for (var index = 0; index < length; index++) {
    difference |= aa[index] ^ bb[index];
  }
  return difference == 0;
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
