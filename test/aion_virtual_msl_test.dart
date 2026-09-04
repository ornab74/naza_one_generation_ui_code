import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/aion_entropy_federation.dart';
import 'package:naza_one/security/aion_virtual_msl.dart';
import 'package:naza_one/security/metameric_surface_lattice.dart';

final class _FederatedVerifier
    implements AionContributionVerifier, AionContributorTrustPolicy {
  @override
  Future<bool> verify({
    required String sourceId,
    required int round,
    required Uint8List signedMessage,
    required Uint8List signature,
  }) async => round == 1;

  @override
  String? trustDomainFor({required String sourceId, required int round}) =>
      round == 1 ? 'domain-$sourceId' : null;
}

final class _LegacyCheckpointStore implements AionCheckpointStore {
  @override
  Future<AionCheckpoint?> load(AionProfile profile) async => AionCheckpoint(
    suiteVersion: 1,
    epoch: 1,
    ratchet: Uint8List(64),
    merkleRoot: Uint8List(32),
  );

  @override
  Future<void> compareAndCommit({
    required AionProfile profile,
    required int expectedEpoch,
    required AionCheckpoint next,
  }) async {}
}

final class _ExternalSchedule implements AionExternalKeySchedule {
  @override
  Future<Uint8List> deriveActiveKey({
    required Uint8List transcriptDigest,
    required Uint8List priorRatchet,
    required Uint8List freshEntropy,
    required Uint8List postQuantumSecret,
    required Uint8List federationSecret,
  }) async => Uint8List(64)..fillRange(0, 64, 11);
}

AionContribution _federatedContribution(String source, bool confidential) {
  final reveal = Uint8List(32)..fillRange(0, 32, source.codeUnitAt(0));
  return AionContribution(
    sourceId: source,
    round: 1,
    visibility: confidential
        ? AionContributionVisibility.confidential
        : AionContributionVisibility.public,
    commitment: AionEntropyFederation.commitmentFor(
      sourceId: source,
      round: 1,
      reveal: reveal,
    ),
    reveal: reveal,
    signature: Uint8List(64)..fillRange(0, 64, 1),
  );
}

void main() {
  test('advances, commits, and punctures one-use capabilities', () async {
    final engine = AionVirtualMslEngine(
      policy: AionPolicy.maximum,
      counterStore: MslMemoryCounterStore(),
      checkpointStore: AionMemoryCheckpointStore(),
      deviceRoot: Uint8List(32)..fillRange(0, 32, 1),
      userRoot: Uint8List(32)..fillRange(0, 32, 2),
      entropy: (n) => Uint8List(n)..fillRange(0, n, 3),
    );
    final result = await engine.advance(
      purpose: 'vault/unlock',
      verifierNonce: Uint8List(32)..fillRange(0, 32, 4),
      postQuantumSecret: Uint8List(32)..fillRange(0, 32, 5),
      chaosFrames: [AionChaosFrame(List.filled(16, .25))],
    );
    expect(result.epoch, 1);
    expect(result.entropyCreditBits, 256);
    expect(
      engine.authorize(result.capability, Uint8List.fromList([1])),
      hasLength(64),
    );
    expect(
      () => engine.authorize(result.capability, Uint8List.fromList([1])),
      throwsA(isA<MslProtocolException>()),
    );
    engine.dispose();
  });
  test('maximum mode rejects missing PQ and malformed chaos', () async {
    final engine = AionVirtualMslEngine(
      policy: AionPolicy.maximum,
      counterStore: MslMemoryCounterStore(),
      checkpointStore: AionMemoryCheckpointStore(),
      deviceRoot: Uint8List(32),
      entropy: (n) => Uint8List(n),
    );
    await expectLater(
      engine.advance(
        purpose: 'vault/unlock',
        verifierNonce: Uint8List(32),
        postQuantumSecret: Uint8List(0),
        chaosFrames: [AionChaosFrame(List.filled(8, 0))],
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (e) => e.code,
          'code',
          'aion_pq_required',
        ),
      ),
    );
    expect(
      () => AionChaosFrame(List.filled(8, 2)).canonicalBytes(),
      throwsA(isA<MslProtocolException>()),
    );
  });

  test(
    'federated maximum cannot downgrade to a single-host transition',
    () async {
      expect(
        () => AionVirtualMslEngine(
          policy: AionPolicy.federatedMaximum,
          counterStore: MslMemoryCounterStore(),
          checkpointStore: AionMemoryCheckpointStore(),
          deviceRoot: Uint8List(32),
          entropy: (n) => Uint8List(n),
        ),
        throwsA(
          isA<MslProtocolException>().having(
            (error) => error.code,
            'code',
            'aion_external_schedule_required',
          ),
        ),
      );
    },
  );

  test('federated maximum enforces the independent quorum profile', () async {
    final mix =
        await AionEntropyFederation(
          verifier: _FederatedVerifier(),
          minimumSources: 5,
          minimumConfidentialSources: 3,
          minimumConfidentialTrustDomains: 3,
        ).combine([
          _federatedContribution('alpha', true),
          _federatedContribution('bravo', true),
          _federatedContribution('charlie', true),
          _federatedContribution('delta', false),
          _federatedContribution('echo', false),
        ]);
    final engine = AionVirtualMslEngine(
      policy: AionPolicy.federatedMaximum,
      counterStore: MslMemoryCounterStore(),
      checkpointStore: AionMemoryCheckpointStore(),
      externalKeySchedule: _ExternalSchedule(),
      entropy: (n) => Uint8List(n)..fillRange(0, n, 2),
    );
    final proof = await engine.advance(
      purpose: 'vault/unlock',
      verifierNonce: Uint8List(32)..fillRange(0, 32, 3),
      postQuantumSecret: Uint8List(32)..fillRange(0, 32, 4),
      chaosFrames: [AionChaosFrame(List.filled(8, .1))],
      federation: mix,
    );
    expect(proof.epoch, 1);
    engine.dispose();
  });

  test('restores the encrypted ratchet checkpoint across restarts', () async {
    final counters = MslMemoryCounterStore();
    final checkpoints = AionMemoryCheckpointStore();
    AionVirtualMslEngine build() => AionVirtualMslEngine(
      policy: AionPolicy.research,
      counterStore: counters,
      checkpointStore: checkpoints,
      deviceRoot: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (n) => Uint8List(n)..fillRange(0, n, 8),
    );
    final first = build();
    expect(
      (await first.advance(
        purpose: 'test',
        verifierNonce: Uint8List(32),
        postQuantumSecret: Uint8List(0),
        chaosFrames: [AionChaosFrame(List.filled(8, 0))],
      )).epoch,
      1,
    );
    first.dispose();
    final second = build();
    expect(
      (await second.advance(
        purpose: 'test',
        verifierNonce: Uint8List(32)..fillRange(0, 32, 1),
        postQuantumSecret: Uint8List(0),
        chaosFrames: [AionChaosFrame(List.filled(8, .1))],
      )).epoch,
      2,
    );
    second.dispose();
  });

  test('rejects repeated live CSPRNG output', () async {
    final engine = AionVirtualMslEngine(
      policy: AionPolicy.research,
      counterStore: MslMemoryCounterStore(),
      checkpointStore: AionMemoryCheckpointStore(),
      deviceRoot: Uint8List(32)..fillRange(0, 32, 1),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 7),
    );
    await engine.advance(
      purpose: 'test',
      verifierNonce: Uint8List(32),
      postQuantumSecret: Uint8List(0),
      chaosFrames: [AionChaosFrame(List.filled(8, 0))],
    );
    await expectLater(
      engine.advance(
        purpose: 'test',
        verifierNonce: Uint8List(32)..fillRange(0, 32, 1),
        postQuantumSecret: Uint8List(0),
        chaosFrames: [AionChaosFrame(List.filled(8, .1))],
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'entropy_repetition',
        ),
      ),
    );
    engine.dispose();
  });

  test('rejects legacy checkpoint suite downgrade', () async {
    final engine = AionVirtualMslEngine(
      policy: AionPolicy.research,
      counterStore: MslMemoryCounterStore(),
      checkpointStore: _LegacyCheckpointStore(),
      deviceRoot: Uint8List(32),
      entropy: (length) => Uint8List(length),
    );
    await expectLater(
      engine.advance(
        purpose: 'test',
        verifierNonce: Uint8List(32),
        postQuantumSecret: Uint8List(0),
        chaosFrames: [AionChaosFrame(List.filled(8, 0))],
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_suite_downgrade',
        ),
      ),
    );
    engine.dispose();
  });
}
