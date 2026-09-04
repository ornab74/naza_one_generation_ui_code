import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/metameric_surface_lattice.dart';

void main() {
  final profile = MslProfile(
    id: 'msl-high-v2',
    challengeCount: 8,
    wavelengthsNm: const [420, 470, 520, 570, 620, 670],
    intensitiesMilli: const [600, 800, 1000],
    incidenceMilliDegrees: const [15000, 30000, 45000, 60000],
    polarizationMilliDegrees: const [0, 45000, 90000, 135000],
    durationsMicros: const [1000, 1500, 2000],
    maxCumulativeEnergyUnits: 40000,
  );

  test('binds a healthy physical result to a one-time transcript', () async {
    final reader = _FakeReader(profile.id);
    final engine = MslProtocolEngine(
      reader: reader,
      profile: profile,
      attestationVerifier: const _FakeAttestationVerifier(),
      counterStore: MslMemoryCounterStore(),
      enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
      clock: () => DateTime.utc(2026, 9, 4, 12),
    );
    final request = MslAuthenticationRequest(
      verifierNonce: Uint8List(32)..fillRange(0, 32, 3),
      purpose: 'vault/unlock',
      issuedAt: DateTime.utc(2026, 9, 4, 11, 59, 30),
    );
    final proof = await engine.authenticate(
      request,
      postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 5),
    );

    expect(proof.counter, 1);
    expect(proof.proof, hasLength(64));
    expect(proof.transcriptDigest, hasLength(32));
    expect(
      engine.authenticateMessage(
        proof.keyHandle,
        Uint8List.fromList([1, 2, 3]),
      ),
      hasLength(64),
    );
    expect(reader.lastProgram?.instructions, hasLength(8));
    await expectLater(
      engine.authenticate(
        request,
        postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 5),
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'replay_rejected',
        ),
      ),
    );
    engine.dispose();
  });

  test(
    'fails closed when the reader executes a different transcript',
    () async {
      final reader = _FakeReader(profile.id)..mismatchTranscript = true;
      final engine = _engine(reader, profile);
      await expectLater(
        engine.authenticate(
          _request(),
          postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
        ),
        throwsA(
          isA<MslProtocolException>().having(
            (error) => error.code,
            'code',
            'reader_transcript_mismatch',
          ),
        ),
      );
      expect(reader.resetCount, 1);
    },
  );

  test('rejects debug firmware and unhealthy measurements', () async {
    final reader = _FakeReader(profile.id)..productionFirmware = false;
    final engine = _engine(reader, profile);
    await expectLater(
      engine.authenticate(
        _request(),
        postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'reader_health_rejected',
        ),
      ),
    );
  });

  test('rejects an untrusted reader attestation', () async {
    final reader = _FakeReader(profile.id);
    final engine = MslProtocolEngine(
      reader: reader,
      profile: profile,
      attestationVerifier: const _FakeAttestationVerifier(accept: false),
      counterStore: MslMemoryCounterStore(),
      enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
      clock: () => DateTime.utc(2026, 9, 4, 12),
    );
    await expectLater(
      engine.authenticate(
        _request(),
        postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'reader_attestation_rejected',
        ),
      ),
    );
  });

  test('detects persisted counter rollback', () async {
    final reader = _FakeReader(profile.id);
    final engine = MslProtocolEngine(
      reader: reader,
      profile: profile,
      attestationVerifier: const _FakeAttestationVerifier(),
      counterStore: MslMemoryCounterStore(3),
      initialCounter: 4,
      enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
      clock: () => DateTime.utc(2026, 9, 4, 12),
    );
    await expectLater(
      engine.authenticate(
        _request(),
        postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'counter_rollback_detected',
        ),
      ),
    );
    expect(reader.lastProgram, isNull);
  });

  test('requires a real hybrid contribution and expires key handles', () async {
    var now = DateTime.utc(2026, 9, 4, 12);
    final reader = _FakeReader(profile.id);
    final engine = MslProtocolEngine(
      reader: reader,
      profile: profile,
      attestationVerifier: const _FakeAttestationVerifier(),
      counterStore: MslMemoryCounterStore(),
      enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
      clock: () => now,
      keyLifetime: const Duration(seconds: 10),
    );
    await expectLater(
      engine.authenticate(_request(), postQuantumSharedSecret: Uint8List(16)),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'pq_secret_invalid',
        ),
      ),
    );
    final proof = await engine.authenticate(
      _request(),
      postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
    );
    now = now.add(const Duration(seconds: 11));
    expect(
      () => engine.authenticateMessage(proof.keyHandle, Uint8List(1)),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'key_handle_expired',
        ),
      ),
    );
  });
}

MslAuthenticationRequest _request() => MslAuthenticationRequest(
  verifierNonce: Uint8List(32)..fillRange(0, 32, 3),
  purpose: 'vault/unlock',
  issuedAt: DateTime.utc(2026, 9, 4, 11, 59, 30),
);

MslProtocolEngine _engine(_FakeReader reader, MslProfile profile) =>
    MslProtocolEngine(
      reader: reader,
      profile: profile,
      attestationVerifier: const _FakeAttestationVerifier(),
      counterStore: MslMemoryCounterStore(),
      enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
      entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
      clock: () => DateTime.utc(2026, 9, 4, 12),
    );

final class _FakeReader implements MslSecureReader {
  _FakeReader(this.profileId);

  @override
  final String profileId;
  @override
  String get deviceId => 'surface-device-01';
  @override
  MslReaderState state = MslReaderState.ready;
  bool mismatchTranscript = false;
  bool productionFirmware = true;
  int resetCount = 0;
  MslChallengeProgram? lastProgram;

  @override
  Future<MslReaderResult> execute(MslChallengeProgram program) async {
    state = MslReaderState.executing;
    lastProgram = program;
    final digest = _digest(program.canonicalBytes());
    if (mismatchTranscript) digest[0] ^= 1;
    state = MslReaderState.complete;
    return MslReaderResult(
      surfaceSecret: Uint8List(32)..fillRange(0, 32, 11),
      executedProgramDigest: digest,
      firmwareMeasurement: Uint8List(32)..fillRange(0, 32, 12),
      attestation: Uint8List(64)..fillRange(0, 64, 13),
      health: MslReaderHealth(
        temperatureMilliC: 25000,
        maximumTimingErrorMicros: 20,
        detectorSaturated: false,
        detectorUnderexposed: false,
        resetVerified: true,
        productionFirmware: productionFirmware,
      ),
    );
  }

  @override
  Future<void> resetAfterFault() async {
    resetCount++;
    state = MslReaderState.ready;
  }
}

final class _FakeAttestationVerifier implements MslReaderAttestationVerifier {
  const _FakeAttestationVerifier({this.accept = true});

  final bool accept;

  @override
  Future<bool> verify({
    required String deviceId,
    required String profileId,
    required Uint8List requestedProgramDigest,
    required MslReaderResult result,
  }) async =>
      accept &&
      deviceId == 'surface-device-01' &&
      profileId == 'msl-high-v2' &&
      result.attestation.length == 64;
}

// Test-only SHA-256 helper kept local so the fake reader independently computes
// the exact digest expected by the protocol contract.
Uint8List _digest(Uint8List input) {
  return Uint8List.fromList(crypto.sha256.convert(input).bytes);
}
