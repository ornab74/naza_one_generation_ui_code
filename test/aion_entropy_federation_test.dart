import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/aion_entropy_federation.dart';
import 'package:naza_one/security/metameric_surface_lattice.dart';
import 'package:pqcrypto/pqcrypto.dart';

final class _AcceptingVerifier
    implements AionContributionVerifier, AionContributorTrustPolicy {
  @override
  Future<bool> verify({
    required String sourceId,
    required int round,
    required Uint8List signedMessage,
    required Uint8List signature,
  }) async => sourceId.isNotEmpty && round > 0 && signedMessage.isNotEmpty;

  @override
  String? trustDomainFor({required String sourceId, required int round}) =>
      round == 42 ? 'operator-$sourceId' : null;
}

AionContribution _contribution(
  String sourceId,
  int marker,
  AionContributionVisibility visibility,
) {
  final reveal = Uint8List(32)..fillRange(0, 32, marker);
  return AionContribution(
    sourceId: sourceId,
    round: 42,
    visibility: visibility,
    commitment: AionEntropyFederation.commitmentFor(
      sourceId: sourceId,
      round: 42,
      reveal: reveal,
    ),
    reveal: reveal,
    signature: Uint8List(64)..fillRange(0, 64, marker + 10),
  );
}

void main() {
  test('pinned ML-DSA verifier accepts only the matching identity', () async {
    final keys = MlDsa.generateKeyPair(DilithiumParams.mlDsa44);
    final identity = AionMlDsaContributorIdentity(
      sourceId: 'node-a',
      trustDomain: 'operator-a',
      publicKey: keys.$1,
      parameterSet: DilithiumParameter.mlDsa44,
      validThroughRound: 42,
    );
    final verifier = PinnedMlDsaContributorVerifier([identity]);
    keys.$1[0] ^= 0xff;
    identity.publicKey[0] ^= 0xff;
    final contribution = _contribution(
      'node-a',
      7,
      AionContributionVisibility.confidential,
    );
    final message = AionEntropyFederation.signedMessageFor(contribution);
    final signature = MlDsa.sign(
      keys.$2,
      message,
      DilithiumParams.mlDsa44,
      ctx: PinnedMlDsaContributorVerifier.signingContext,
    );

    expect(
      await verifier.verify(
        sourceId: 'node-a',
        round: 42,
        signedMessage: message,
        signature: signature,
      ),
      isTrue,
    );
    message[0] ^= 0xff;
    expect(
      await verifier.verify(
        sourceId: 'node-a',
        round: 42,
        signedMessage: message,
        signature: signature,
      ),
      isFalse,
    );
    expect(
      await verifier.verify(
        sourceId: 'node-a',
        round: 43,
        signedMessage: AionEntropyFederation.signedMessageFor(contribution),
        signature: signature,
      ),
      isFalse,
    );
    expect(
      await verifier.verify(
        sourceId: 'unpinned',
        round: 42,
        signedMessage: message,
        signature: signature,
      ),
      isFalse,
    );
    keys.$2.fillRange(0, keys.$2.length, 0);
  });

  test(
    'combines an ordered signed quorum with zero public entropy credit',
    () async {
      final federation = AionEntropyFederation(verifier: _AcceptingVerifier());
      final result = await federation.combine([
        _contribution('public-beacon', 1, AionContributionVisibility.public),
        _contribution('node-b', 2, AionContributionVisibility.confidential),
        _contribution('node-a', 3, AionContributionVisibility.confidential),
      ]);

      expect(result.round, 42);
      expect(result.acceptedSources, ['node-a', 'node-b', 'public-beacon']);
      expect(result.confidentialSources, ['node-a', 'node-b']);
      expect(result.confidentialTrustDomains, [
        'operator-node-a',
        'operator-node-b',
      ]);
      expect(result.transcriptCommitment, hasLength(32));
      expect(result.confidentialMix, hasLength(32));
      expect(result.publicEntropyCreditBits, 0);
      final exposedCopy = result.confidentialMix;
      final originalFirstByte = exposedCopy.first;
      exposedCopy[0] ^= 0xff;
      expect(result.confidentialMix.first, originalFirstByte);
      final binding = result.consumeForEpoch(42);
      expect(binding.round, 42);
      expect(
        () => result.consumeForEpoch(42),
        throwsA(
          isA<MslProtocolException>().having(
            (error) => error.code,
            'code',
            'aion_federation_replay',
          ),
        ),
      );
    },
  );

  test('rejects duplicate sources and reveal substitution', () async {
    final federation = AionEntropyFederation(verifier: _AcceptingVerifier());
    final duplicate = _contribution(
      'node-a',
      2,
      AionContributionVisibility.confidential,
    );
    await expectLater(
      federation.combine([
        _contribution('node-a', 1, AionContributionVisibility.confidential),
        duplicate,
        _contribution('node-b', 3, AionContributionVisibility.public),
      ]),
      throwsA(isA<MslProtocolException>()),
    );

    final substituted = _contribution(
      'node-c',
      4,
      AionContributionVisibility.confidential,
    );
    substituted.reveal[0] ^= 0xff;
    await expectLater(
      federation.combine([
        _contribution('node-a', 1, AionContributionVisibility.confidential),
        _contribution('node-b', 2, AionContributionVisibility.public),
        substituted,
      ]),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_federation_invalid',
        ),
      ),
    );
  });
}
