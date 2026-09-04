import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pqcrypto/pqcrypto.dart';

import 'metameric_surface_lattice.dart';

enum AionContributionVisibility { public, confidential }

final class AionContribution {
  AionContribution({
    required this.sourceId,
    required this.round,
    required this.visibility,
    required Uint8List commitment,
    required Uint8List reveal,
    required Uint8List signature,
  }) : commitment = Uint8List.fromList(commitment),
       reveal = Uint8List.fromList(reveal),
       signature = Uint8List.fromList(signature);

  final String sourceId;
  final int round;
  final AionContributionVisibility visibility;
  final Uint8List commitment;
  final Uint8List reveal;
  final Uint8List signature;
}

abstract interface class AionContributionVerifier {
  Future<bool> verify({
    required String sourceId,
    required int round,
    required Uint8List signedMessage,
    required Uint8List signature,
  });
}

abstract interface class AionContributorTrustPolicy {
  String? trustDomainFor({required String sourceId, required int round});
}

final class AionMlDsaContributorIdentity {
  AionMlDsaContributorIdentity({
    required this.sourceId,
    required Uint8List publicKey,
    required this.trustDomain,
    this.parameterSet = DilithiumParameter.mlDsa65,
    this.validFromRound = 1,
    this.validThroughRound = 0x7fffffffffffffff,
  }) : _publicKey = Uint8List.fromList(publicKey) {
    if (!RegExp(r'^[A-Za-z0-9._:/-]{1,64}$').hasMatch(sourceId) ||
        !RegExp(r'^[A-Za-z0-9._:/-]{1,64}$').hasMatch(trustDomain) ||
        validFromRound < 1 ||
        validThroughRound < validFromRound ||
        publicKey.length != DilithiumParams.get(parameterSet).publicKeyBytes) {
      throw const MslProtocolException(
        'aion_mldsa_identity_invalid',
        'The pinned ML-DSA contributor identity is malformed.',
      );
    }
  }

  final String sourceId;
  final String trustDomain;
  final Uint8List _publicKey;
  Uint8List get publicKey => Uint8List.fromList(_publicKey);
  final DilithiumParameter parameterSet;
  final int validFromRound;
  final int validThroughRound;
}

/// A fail-closed FIPS 204 verifier backed by an immutable identity-key map.
/// Verification runs away from the UI isolate. A Dart isolate limits workload
/// interference but is not an operating-system security sandbox.
final class PinnedMlDsaContributorVerifier
    implements AionContributionVerifier, AionContributorTrustPolicy {
  PinnedMlDsaContributorVerifier(
    Iterable<AionMlDsaContributorIdentity> identities,
  ) : _identities = Map.unmodifiable({
        for (final identity in identities) identity.sourceId: identity,
      }) {
    if (_identities.isEmpty || _identities.length != identities.length) {
      throw const MslProtocolException(
        'aion_mldsa_pins_invalid',
        'ML-DSA contributor pins must be non-empty and uniquely named.',
      );
    }
  }

  static final Uint8List _context = Uint8List.fromList(
    utf8.encode('NAZA-AION-FEDERATION-v1'),
  );
  final Map<String, AionMlDsaContributorIdentity> _identities;

  static Uint8List get signingContext => Uint8List.fromList(_context);

  @override
  String? trustDomainFor({required String sourceId, required int round}) {
    final identity = _identities[sourceId];
    if (identity == null ||
        round < identity.validFromRound ||
        round > identity.validThroughRound) {
      return null;
    }
    return identity.trustDomain;
  }

  @override
  Future<bool> verify({
    required String sourceId,
    required int round,
    required Uint8List signedMessage,
    required Uint8List signature,
  }) async {
    final identity = _identities[sourceId];
    if (identity == null ||
        round < identity.validFromRound ||
        round > identity.validThroughRound ||
        signedMessage.isEmpty ||
        signedMessage.length > 4096 ||
        signature.length !=
            DilithiumParams.get(identity.parameterSet).signatureBytes) {
      return false;
    }
    final request = _MlDsaVerificationRequest(
      publicKey: Uint8List.fromList(identity.publicKey),
      message: Uint8List.fromList(signedMessage),
      signature: Uint8List.fromList(signature),
      parameterSet: identity.parameterSet,
      context: Uint8List.fromList(_context),
    );
    try {
      return await Isolate.run(() => _verifyMlDsa(request));
    } catch (_) {
      return false;
    }
  }
}

final class _MlDsaVerificationRequest {
  const _MlDsaVerificationRequest({
    required this.publicKey,
    required this.message,
    required this.signature,
    required this.parameterSet,
    required this.context,
  });
  final Uint8List publicKey;
  final Uint8List message;
  final Uint8List signature;
  final DilithiumParameter parameterSet;
  final Uint8List context;
}

bool _verifyMlDsa(_MlDsaVerificationRequest request) => MlDsa.verify(
  request.publicKey,
  request.message,
  request.signature,
  DilithiumParams.get(request.parameterSet),
  ctx: request.context,
);

final class AionFederationMix {
  AionFederationMix._({
    required this.round,
    required Uint8List transcriptCommitment,
    required Uint8List confidentialMix,
    required List<String> acceptedSources,
    required List<String> confidentialSources,
    required List<String> confidentialTrustDomains,
  }) : _transcriptCommitment = Uint8List.fromList(transcriptCommitment),
       _confidentialMix = Uint8List.fromList(confidentialMix),
       acceptedSources = List.unmodifiable(acceptedSources),
       confidentialSources = List.unmodifiable(confidentialSources),
       confidentialTrustDomains = List.unmodifiable(confidentialTrustDomains);

  final int round;
  final Uint8List _transcriptCommitment;
  final Uint8List _confidentialMix;
  final List<String> acceptedSources;
  final List<String> confidentialSources;
  final List<String> confidentialTrustDomains;
  bool _consumed = false;

  Uint8List get transcriptCommitment =>
      Uint8List.fromList(_transcriptCommitment);
  Uint8List get confidentialMix => Uint8List.fromList(_confidentialMix);

  AionFederationBinding consumeForEpoch(int expectedEpoch) {
    if (_consumed || round != expectedEpoch) {
      throw const MslProtocolException(
        'aion_federation_replay',
        'The federation mix is stale, reused, or bound to another epoch.',
      );
    }
    _consumed = true;
    return AionFederationBinding._(
      round: round,
      transcriptCommitment: _transcriptCommitment,
      confidentialMix: _confidentialMix,
      acceptedSourceCount: acceptedSources.length,
      confidentialSourceCount: confidentialSources.length,
      confidentialTrustDomainCount: confidentialTrustDomains.length,
    );
  }

  // Public beacons improve freshness and auditability, but are predictable to
  // observers and therefore receive no secret-entropy credit.
  int get publicEntropyCreditBits => 0;
}

final class AionFederationBinding {
  AionFederationBinding._({
    required this.round,
    required Uint8List transcriptCommitment,
    required Uint8List confidentialMix,
    required this.acceptedSourceCount,
    required this.confidentialSourceCount,
    required this.confidentialTrustDomainCount,
  }) : transcriptCommitment = Uint8List.fromList(transcriptCommitment),
       confidentialMix = Uint8List.fromList(confidentialMix);

  final int round;
  final Uint8List transcriptCommitment;
  final Uint8List confidentialMix;
  final int acceptedSourceCount;
  final int confidentialSourceCount;
  final int confidentialTrustDomainCount;
}

final class AionEntropyFederation {
  const AionEntropyFederation({
    required this.verifier,
    this.minimumSources = 3,
    this.minimumConfidentialSources = 1,
    this.minimumConfidentialTrustDomains = 1,
  });

  final AionContributionVerifier verifier;
  final int minimumSources;
  final int minimumConfidentialSources;
  final int minimumConfidentialTrustDomains;

  Future<AionFederationMix> combine(
    List<AionContribution> contributions,
  ) async {
    if (minimumSources < 2 ||
        minimumSources > 16 ||
        minimumConfidentialSources < 1 ||
        minimumConfidentialSources > minimumSources ||
        minimumConfidentialTrustDomains < 1 ||
        minimumConfidentialTrustDomains > minimumConfidentialSources ||
        contributions.length < minimumSources ||
        contributions.length > 16) {
      throw const MslProtocolException(
        'aion_federation_quorum',
        'The contribution federation does not satisfy its bounded quorum.',
      );
    }
    final ordered = [...contributions]
      ..sort((left, right) => left.sourceId.compareTo(right.sourceId));
    final round = ordered.first.round;
    final seen = <String>{};
    final confidential = <AionContribution>[];
    final confidentialTrustDomains = <String>{};
    final transcript = BytesBuilder(copy: false)
      ..add(utf8.encode('AION-FEDERATION/transcript/v1'))
      ..add(_u64(round));

    for (final contribution in ordered) {
      if (!RegExp(
            r'^[A-Za-z0-9._:/-]{1,64}$',
          ).hasMatch(contribution.sourceId) ||
          !seen.add(contribution.sourceId) ||
          round <= 0 ||
          contribution.round != round ||
          contribution.commitment.length != 32 ||
          contribution.reveal.length < 32 ||
          contribution.reveal.length > 128 ||
          contribution.signature.length < 64 ||
          !_constantTimeEqual(
            contribution.commitment,
            commitmentFor(
              sourceId: contribution.sourceId,
              round: round,
              reveal: contribution.reveal,
            ),
          )) {
        throw const MslProtocolException(
          'aion_federation_invalid',
          'A federation contribution is malformed, duplicated, or substituted.',
        );
      }
      final signedMessage = signedMessageFor(contribution);
      if (!await verifier.verify(
        sourceId: contribution.sourceId,
        round: contribution.round,
        signedMessage: signedMessage,
        signature: contribution.signature,
      )) {
        throw const MslProtocolException(
          'aion_federation_signature',
          'A federation contribution signature was rejected.',
        );
      }
      transcript
        ..add(_lengthPrefixed(utf8.encode(contribution.sourceId)))
        ..add(_u64(contribution.round))
        ..add([contribution.visibility.index])
        ..add(contribution.commitment)
        ..add(_hash(contribution.signature));
      if (contribution.visibility == AionContributionVisibility.confidential) {
        confidential.add(contribution);
        if (verifier is AionContributorTrustPolicy) {
          final policy = verifier as AionContributorTrustPolicy;
          final domain = policy.trustDomainFor(
            sourceId: contribution.sourceId,
            round: contribution.round,
          );
          if (domain == null) {
            throw const MslProtocolException(
              'aion_federation_trust_domain',
              'A confidential contributor has no active trust domain.',
            );
          }
          confidentialTrustDomains.add(domain);
        }
      }
    }
    if (confidential.length < minimumConfidentialSources) {
      throw const MslProtocolException(
        'aion_federation_confidential_quorum',
        'The confidential contribution quorum was not met.',
      );
    }
    if (minimumConfidentialTrustDomains > 1 &&
        confidentialTrustDomains.length < minimumConfidentialTrustDomains) {
      throw const MslProtocolException(
        'aion_federation_trust_domain_quorum',
        'The independent confidential trust-domain quorum was not met.',
      );
    }
    final secretMaterial = BytesBuilder(copy: false)
      ..add(utf8.encode('AION-FEDERATION/confidential/v1'))
      ..add(_u64(round));
    for (final contribution in confidential) {
      secretMaterial
        ..add(_lengthPrefixed(utf8.encode(contribution.sourceId)))
        ..add(_lengthPrefixed(contribution.reveal));
    }
    return AionFederationMix._(
      round: round,
      transcriptCommitment: _hash(transcript.takeBytes()),
      confidentialMix: _hash(secretMaterial.takeBytes()),
      acceptedSources: List.unmodifiable(
        ordered.map((value) => value.sourceId),
      ),
      confidentialSources: List.unmodifiable(
        confidential.map((value) => value.sourceId),
      ),
      confidentialTrustDomains: List.unmodifiable(
        confidentialTrustDomains.toList()..sort(),
      ),
    );
  }

  static Uint8List commitmentFor({
    required String sourceId,
    required int round,
    required Uint8List reveal,
  }) => _hash([
    ...utf8.encode('AION-FEDERATION/commit/v1'),
    ..._lengthPrefixed(utf8.encode(sourceId)),
    ..._u64(round),
    ..._lengthPrefixed(reveal),
  ]);

  static Uint8List signedMessageFor(AionContribution value) =>
      Uint8List.fromList([
        ...utf8.encode('AION-FEDERATION/sign/v1'),
        ..._lengthPrefixed(utf8.encode(value.sourceId)),
        ..._u64(value.round),
        value.visibility.index,
        ...value.commitment,
      ]);
}

Uint8List _hash(List<int> value) =>
    Uint8List.fromList(crypto.sha256.convert(value).bytes);

Uint8List _lengthPrefixed(List<int> value) => Uint8List.fromList([
  ...(ByteData(4)..setUint32(0, value.length, Endian.big)).buffer.asUint8List(),
  ...value,
]);

Uint8List _u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.big)).buffer.asUint8List();

bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = math.min(left.length, right.length);
  for (var index = 0; index < length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
