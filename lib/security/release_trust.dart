// LLM-CONTEXT:BEGIN
// FILE: lib/security/release_trust.dart
// ROLE: Owns release trust behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:pqcrypto/pqcrypto.dart';

const _releaseFormat = 'naza-release-manifest-v1';
const _releaseContext = 'NazaOne/ReleaseManifest/v1';

final class NazaReleaseManifest {
  final String releaseVersion;
  final int buildNumber;
  final int trustGeneration;
  final String artifactSha256;
  final int artifactBytes;
  final String securityPolicySha256;
  final String issuedAt;
  final String mlDsa87Signature;
  final String ed25519Signature;

  const NazaReleaseManifest({
    required this.releaseVersion,
    required this.buildNumber,
    required this.trustGeneration,
    required this.artifactSha256,
    required this.artifactBytes,
    required this.securityPolicySha256,
    required this.issuedAt,
    required this.mlDsa87Signature,
    required this.ed25519Signature,
  });

  Map<String, Object?> signedPayload() => <String, Object?>{
    'artifactBytes': artifactBytes,
    'artifactSha256': artifactSha256.toLowerCase(),
    'buildNumber': buildNumber,
    'format': _releaseFormat,
    'issuedAt': issuedAt,
    'releaseVersion': releaseVersion,
    'securityPolicySha256': securityPolicySha256.toLowerCase(),
    'trustGeneration': trustGeneration,
  };

  factory NazaReleaseManifest.fromJson(Map<String, Object?> json) {
    if (json['format'] != _releaseFormat) {
      throw const NazaReleaseTrustException(
        'release_format',
        'Unsupported release manifest format.',
      );
    }
    return NazaReleaseManifest(
      releaseVersion: json['releaseVersion']?.toString() ?? '',
      buildNumber: _positiveInt(json['buildNumber']) ?? -1,
      trustGeneration: _positiveInt(json['trustGeneration']) ?? -1,
      artifactSha256: json['artifactSha256']?.toString() ?? '',
      artifactBytes: _positiveInt(json['artifactBytes']) ?? -1,
      securityPolicySha256: json['securityPolicySha256']?.toString() ?? '',
      issuedAt: json['issuedAt']?.toString() ?? '',
      mlDsa87Signature: json['mlDsa87Signature']?.toString() ?? '',
      ed25519Signature: json['ed25519Signature']?.toString() ?? '',
    );
  }
}

final class NazaVerifiedReleaseTrust {
  final String appIdentity;
  final String trustRootIdentity;
  final int trustGeneration;
  final String releaseVersion;
  final int buildNumber;
  final String artifactSha256;
  final String securityPolicySha256;
  final String _artifactPath;
  final int _artifactBytes;

  const NazaVerifiedReleaseTrust._({
    required this.appIdentity,
    required this.trustRootIdentity,
    required this.trustGeneration,
    required this.releaseVersion,
    required this.buildNumber,
    required this.artifactSha256,
    required this.securityPolicySha256,
    required String artifactPath,
    required int artifactBytes,
  }) :
       // Public parameter names keep construction readable while the bound
       // artifact path/length remain private implementation details.
       // ignore: prefer_initializing_formals
       _artifactPath = artifactPath,
       // ignore: prefer_initializing_formals
       _artifactBytes = artifactBytes;

  Future<void> reverifyArtifact() async {
    final file = File(_artifactPath);
    if (!await file.exists()) {
      throw const NazaReleaseTrustException(
        'release_artifact_missing',
        'The verified application artifact is missing.',
      );
    }
    final stat = await file.stat();
    if (stat.size != _artifactBytes) {
      throw const NazaReleaseTrustException(
        'release_artifact_size',
        'The application artifact changed after release verification.',
      );
    }
    final digest = await _sha256File(file);
    if (!_constantTimeTextEquals(digest, artifactSha256)) {
      throw const NazaReleaseTrustException(
        'release_artifact_digest',
        'The application artifact changed after release verification.',
      );
    }
  }
}

final class NazaReleaseTrustVerifier {
  NazaReleaseTrustVerifier({
    required List<int> trustedMlDsa87PublicKey,
    required List<int> trustedEd25519PublicKey,
    required this.minimumTrustGeneration,
    this.minimumBuildNumber = 1,
  }) : _trustedMlDsa87PublicKey = Uint8List.fromList(trustedMlDsa87PublicKey),
       _trustedEd25519PublicKey = Uint8List.fromList(trustedEd25519PublicKey) {
    if (minimumTrustGeneration < 1) {
      throw ArgumentError.value(minimumTrustGeneration, 'minimumTrustGeneration');
    }
    if (minimumBuildNumber < 1) {
      throw ArgumentError.value(minimumBuildNumber, 'minimumBuildNumber');
    }
    if (_trustedEd25519PublicKey.length != 32) {
      throw ArgumentError.value(
        _trustedEd25519PublicKey.length,
        'trustedEd25519PublicKey',
        'Ed25519 public key must be 32 bytes.',
      );
    }
    final expectedMlDsa = DilithiumParams.mlDsa87.publicKeyBytes;
    if (_trustedMlDsa87PublicKey.length != expectedMlDsa) {
      throw ArgumentError.value(
        _trustedMlDsa87PublicKey.length,
        'trustedMlDsa87PublicKey',
        'ML-DSA-87 public key has an invalid length.',
      );
    }
  }

  final Uint8List _trustedMlDsa87PublicKey;
  final Uint8List _trustedEd25519PublicKey;
  final int minimumTrustGeneration;
  final int minimumBuildNumber;
  final Ed25519 _ed25519 = Ed25519();

  Future<NazaVerifiedReleaseTrust> verify({
    required NazaReleaseManifest manifest,
    required File applicationArtifact,
    required List<int> securityPolicyBytes,
  }) async {
    _validateManifestFields(manifest);
    if (manifest.trustGeneration < minimumTrustGeneration) {
      throw const NazaReleaseTrustException(
        'release_trust_downgrade',
        'Release trust generation is below the accepted minimum.',
      );
    }
    if (manifest.buildNumber < minimumBuildNumber) {
      throw const NazaReleaseTrustException(
        'release_build_rollback',
        'Release build is below the accepted anti-rollback floor.',
      );
    }
    if (securityPolicyBytes.isEmpty) {
      throw const NazaReleaseTrustException(
        'release_policy_empty',
        'Release security policy must not be empty.',
      );
    }
    if (!await applicationArtifact.exists()) {
      throw const NazaReleaseTrustException(
        'release_artifact_missing',
        'Application artifact is missing.',
      );
    }
    final stat = await applicationArtifact.stat();
    if (stat.size != manifest.artifactBytes) {
      throw const NazaReleaseTrustException(
        'release_artifact_size',
        'Application artifact length does not match the signed manifest.',
      );
    }
    final artifactDigest = await _sha256File(applicationArtifact);
    if (!_constantTimeTextEquals(artifactDigest, manifest.artifactSha256)) {
      throw const NazaReleaseTrustException(
        'release_artifact_digest',
        'Application artifact digest does not match the signed manifest.',
      );
    }
    final policyDigest = crypto.sha256.convert(securityPolicyBytes).toString();
    if (!_constantTimeTextEquals(policyDigest, manifest.securityPolicySha256)) {
      throw const NazaReleaseTrustException(
        'release_policy_digest',
        'Security policy digest does not match the signed manifest.',
      );
    }

    final payload = Uint8List.fromList(
      utf8.encode(_canonicalJson(manifest.signedPayload())),
    );
    final signedDigest = Uint8List.fromList(
      crypto.sha512.convert(payload).bytes,
    );
    final pqSignature = _decodeSignature(
      manifest.mlDsa87Signature,
      code: 'release_pq_signature_encoding',
    );
    final classicalSignature = _decodeSignature(
      manifest.ed25519Signature,
      code: 'release_classical_signature_encoding',
    );
    try {
      final pqPublic = Uint8List.fromList(_trustedMlDsa87PublicKey);
      final pqDigest = Uint8List.fromList(signedDigest);
      final pqSig = Uint8List.fromList(pqSignature);
      final pqVerified = await Isolate.run(() {
        return MlDsa.verify(
          pqPublic,
          pqDigest,
          pqSig,
          DilithiumParams.mlDsa87,
          ctx: Uint8List.fromList(utf8.encode(_releaseContext)),
        );
      });
      if (!pqVerified) {
        throw const NazaReleaseTrustException(
          'release_pq_signature',
          'ML-DSA-87 release signature verification failed.',
        );
      }

      final classicalVerified = await _ed25519.verify(
        signedDigest,
        signature: Signature(
          classicalSignature,
          publicKey: SimplePublicKey(
            _trustedEd25519PublicKey,
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!classicalVerified) {
        throw const NazaReleaseTrustException(
          'release_classical_signature',
          'Ed25519 release signature verification failed.',
        );
      }

      final rootIdentity = crypto.sha256
          .convert(<int>[
            ...utf8.encode('$_releaseFormat/root-v1'),
            ..._trustedMlDsa87PublicKey,
            ..._trustedEd25519PublicKey,
            ...utf8.encode(minimumTrustGeneration.toString()),
          ])
          .toString();
      final appIdentity = crypto.sha256
          .convert(<int>[
            ...utf8.encode('$_releaseFormat/app-v1'),
            ...payload,
            ...utf8.encode(artifactDigest),
            ...utf8.encode(rootIdentity),
          ])
          .toString();

      return NazaVerifiedReleaseTrust._(
        appIdentity: appIdentity,
        trustRootIdentity: rootIdentity,
        trustGeneration: manifest.trustGeneration,
        releaseVersion: manifest.releaseVersion,
        buildNumber: manifest.buildNumber,
        artifactSha256: artifactDigest,
        securityPolicySha256: policyDigest,
        artifactPath: applicationArtifact.absolute.path,
        artifactBytes: stat.size,
      );
    } finally {
      _zero(signedDigest);
      _zero(pqSignature);
      _zero(classicalSignature);
    }
  }

  void _validateManifestFields(NazaReleaseManifest manifest) {
    if (manifest.releaseVersion.trim().isEmpty ||
        manifest.buildNumber < 1 ||
        manifest.trustGeneration < 1 ||
        manifest.artifactBytes < 1 ||
        !_isSha256(manifest.artifactSha256) ||
        !_isSha256(manifest.securityPolicySha256) ||
        DateTime.tryParse(manifest.issuedAt)?.isUtc != true ||
        manifest.mlDsa87Signature.isEmpty ||
        manifest.ed25519Signature.isEmpty) {
      throw const NazaReleaseTrustException(
        'release_manifest_invalid',
        'Release manifest contains invalid or incomplete signed fields.',
      );
    }
  }
}

final class NazaReleaseTrustException implements Exception {
  final String code;
  final String message;

  const NazaReleaseTrustException(this.code, this.message);

  @override
  String toString() => 'NazaReleaseTrustException($code): $message';
}

Uint8List _decodeSignature(String encoded, {required String code}) {
  try {
    final bytes = Uint8List.fromList(base64Decode(encoded));
    if (bytes.isEmpty) throw const FormatException('empty signature');
    return bytes;
  } catch (_) {
    throw NazaReleaseTrustException(code, 'Release signature encoding is invalid.');
  }
}

Future<String> _sha256File(File file) async {
  final digest = await crypto.sha256.bind(file.openRead()).first;
  return digest.toString();
}

bool _isSha256(String value) => RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map<Object?>(_canonicalize).toList(growable: false);
  }
  if (value is num || value is bool || value is String || value == null) {
    return value;
  }
  return value.toString();
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

bool _constantTimeTextEquals(String a, String b) {
  final aa = ascii.encode(a.toLowerCase());
  final bb = ascii.encode(b.toLowerCase());
  var difference = aa.length ^ bb.length;
  final length = aa.length < bb.length ? aa.length : bb.length;
  for (var index = 0; index < length; index++) {
    difference |= aa[index] ^ bb[index];
  }
  return difference == 0;
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
