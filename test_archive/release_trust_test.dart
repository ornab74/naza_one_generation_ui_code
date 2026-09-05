// LLM-CONTEXT:BEGIN
// FILE: test_archive/release_trust_test.dart
// ROLE: Owns release trust test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';
import 'package:pqcrypto/pqcrypto.dart';

void main() {
  late Uint8List pqPublic;
  late Uint8List pqPrivate;
  late SimpleKeyPair edKeyPair;
  late SimplePublicKey edPublic;

  setUpAll(() async {
    final pqPair = await Isolate.run(
      () => MlDsa.generateKeyPair(DilithiumParams.mlDsa87),
    );
    pqPublic = Uint8List.fromList(pqPair.$1);
    pqPrivate = Uint8List.fromList(pqPair.$2);
    edKeyPair = await Ed25519().newKeyPair();
    edPublic = await edKeyPair.extractPublicKey();
  });

  tearDownAll(() {
    for (var index = 0; index < pqPrivate.length; index++) {
      pqPrivate[index] = 0;
    }
    edKeyPair.destroy();
  });

  test('dual signatures and actual artifact mint release trust', () async {
    final directory = await Directory.systemTemp.createTemp('naza-release-trust-');
    try {
      final artifact = File('${directory.path}/naza.bin');
      final artifactBytes = utf8.encode('signed-naza-artifact-v1');
      final policyBytes = utf8.encode('security-policy-v1');
      await artifact.writeAsBytes(artifactBytes, flush: true);

      final manifest = await _signedManifest(
        artifactBytes: artifactBytes,
        policyBytes: policyBytes,
        pqPrivate: pqPrivate,
        edKeyPair: edKeyPair,
      );
      final verifier = NazaReleaseTrustVerifier(
        minimumBuildNumber: 1,
        trustedMlDsa87PublicKey: pqPublic,
        trustedEd25519PublicKey: edPublic.bytes,
        minimumTrustGeneration: 7,
      );

      final verified = await verifier.verify(
        manifest: manifest,
        applicationArtifact: artifact,
        securityPolicyBytes: policyBytes,
      );

      expect(verified.appIdentity, hasLength(64));
      expect(verified.trustRootIdentity, hasLength(64));
      expect(verified.trustGeneration, 7);
      await verified.reverifyArtifact();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('same-size application replacement invalidates verified release', () async {
    final directory = await Directory.systemTemp.createTemp('naza-release-toctou-');
    try {
      final artifact = File('${directory.path}/naza.bin');
      final artifactBytes = utf8.encode('signed-naza-artifact-v1');
      final policyBytes = utf8.encode('security-policy-v1');
      await artifact.writeAsBytes(artifactBytes, flush: true);
      final manifest = await _signedManifest(
        artifactBytes: artifactBytes,
        policyBytes: policyBytes,
        pqPrivate: pqPrivate,
        edKeyPair: edKeyPair,
      );
      final verifier = NazaReleaseTrustVerifier(
        minimumBuildNumber: 1,
        trustedMlDsa87PublicKey: pqPublic,
        trustedEd25519PublicKey: edPublic.bytes,
        minimumTrustGeneration: 7,
      );
      final verified = await verifier.verify(
        manifest: manifest,
        applicationArtifact: artifact,
        securityPolicyBytes: policyBytes,
      );

      await artifact.writeAsBytes(
        List<int>.filled(artifactBytes.length, 0x41),
        flush: true,
      );

      await expectLater(
        verified.reverifyArtifact(),
        throwsA(
          isA<NazaReleaseTrustException>().having(
            (error) => error.code,
            'code',
            'release_artifact_digest',
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('forged Ed25519 companion signature is rejected', () async {
    final directory = await Directory.systemTemp.createTemp('naza-release-forge-');
    try {
      final artifact = File('${directory.path}/naza.bin');
      final artifactBytes = utf8.encode('signed-naza-artifact-v1');
      final policyBytes = utf8.encode('security-policy-v1');
      await artifact.writeAsBytes(artifactBytes, flush: true);
      final manifest = await _signedManifest(
        artifactBytes: artifactBytes,
        policyBytes: policyBytes,
        pqPrivate: pqPrivate,
        edKeyPair: edKeyPair,
      );
      final forged = NazaReleaseManifest(
        releaseVersion: manifest.releaseVersion,
        buildNumber: manifest.buildNumber,
        trustGeneration: manifest.trustGeneration,
        artifactSha256: manifest.artifactSha256,
        artifactBytes: manifest.artifactBytes,
        securityPolicySha256: manifest.securityPolicySha256,
        issuedAt: manifest.issuedAt,
        mlDsa87Signature: manifest.mlDsa87Signature,
        ed25519Signature: base64Encode(List<int>.filled(64, 0x42)),
      );
      final verifier = NazaReleaseTrustVerifier(
        minimumBuildNumber: 1,
        trustedMlDsa87PublicKey: pqPublic,
        trustedEd25519PublicKey: edPublic.bytes,
        minimumTrustGeneration: 7,
      );

      await expectLater(
        verifier.verify(
          manifest: forged,
          applicationArtifact: artifact,
          securityPolicyBytes: policyBytes,
        ),
        throwsA(
          isA<NazaReleaseTrustException>().having(
            (error) => error.code,
            'code',
            'release_classical_signature',
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Future<NazaReleaseManifest> _signedManifest({
  required List<int> artifactBytes,
  required List<int> policyBytes,
  required Uint8List pqPrivate,
  required SimpleKeyPair edKeyPair,
}) async {
  final unsigned = NazaReleaseManifest(
    releaseVersion: '1.0.10',
    buildNumber: 10,
    trustGeneration: 7,
    artifactSha256: crypto.sha256.convert(artifactBytes).toString(),
    artifactBytes: artifactBytes.length,
    securityPolicySha256: crypto.sha256.convert(policyBytes).toString(),
    issuedAt: DateTime.utc(2026, 8, 8, 3).toIso8601String(),
    mlDsa87Signature: 'pending',
    ed25519Signature: 'pending',
  );
  final payload = Uint8List.fromList(
    utf8.encode(jsonEncode(unsigned.signedPayload())),
  );
  final digest = Uint8List.fromList(crypto.sha512.convert(payload).bytes);
  final privateCopy = Uint8List.fromList(pqPrivate);
  final pqSignature = await Isolate.run(() {
    try {
      return MlDsa.sign(
        privateCopy,
        digest,
        DilithiumParams.mlDsa87,
        ctx: Uint8List.fromList(utf8.encode('NazaOne/ReleaseManifest/v1')),
      );
    } finally {
      for (var index = 0; index < privateCopy.length; index++) {
        privateCopy[index] = 0;
      }
    }
  });
  final edSignature = await Ed25519().sign(digest, keyPair: edKeyPair);
  return NazaReleaseManifest(
    releaseVersion: unsigned.releaseVersion,
    buildNumber: unsigned.buildNumber,
    trustGeneration: unsigned.trustGeneration,
    artifactSha256: unsigned.artifactSha256,
    artifactBytes: unsigned.artifactBytes,
    securityPolicySha256: unsigned.securityPolicySha256,
    issuedAt: unsigned.issuedAt,
    mlDsa87Signature: base64Encode(pqSignature),
    ed25519Signature: base64Encode(edSignature.bytes),
  );
}
