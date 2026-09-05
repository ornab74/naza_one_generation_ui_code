import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:naza_one/main.dart';

// Test-only reader and attestation verifier. Obtain the receipt through the
// real protocol engine; production receipt construction stays private.
Future<MslAuthorizationBinding> createTestMslAuthorizationBinding(
  DateTime now,
) async {
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
  final intent = AionAuthorizationIntent(
    purpose: 'vault/unlock',
    eventNonce: Uint8List(32)..fillRange(0, 32, 6),
    verifierNonce: Uint8List(32)..fillRange(0, 32, 3),
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 1)),
    expectedAionEpoch: 1,
    expectedMslCounter: 1,
    mslDeviceId: 'surface-device-01',
    mslProfileId: profile.id,
    postQuantumContextDigest: Uint8List(32)..fillRange(0, 32, 4),
    targetDigest: Uint8List(32)..fillRange(0, 32, 5),
  );
  final engine = MslProtocolEngine(
    reader: _FakeReader(profile.id),
    profile: profile,
    attestationVerifier: const _FakeAttestationVerifier(),
    counterStore: MslMemoryCounterStore(),
    enrollmentBindingKey: Uint8List(32)..fillRange(0, 32, 7),
    entropy: (length) => Uint8List(length)..fillRange(0, length, 9),
    clock: () => now,
  );
  try {
    final proof = await engine.authenticate(
      MslAuthenticationRequest(
        verifierNonce: intent.verifierNonce,
        purpose: intent.purpose,
        issuedAt: intent.issuedAt,
        authorizationIntent: intent,
      ),
      postQuantumSharedSecret: Uint8List(32)..fillRange(0, 32, 4),
    );
    return proof.authorizationBinding;
  } finally {
    engine.dispose();
  }
}

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
  const _FakeAttestationVerifier();

  @override
  Future<bool> verify({
    required String deviceId,
    required String profileId,
    required Uint8List requestedProgramDigest,
    required MslReaderResult result,
  }) async =>
      deviceId == 'surface-device-01' &&
      profileId == 'msl-high-v2' &&
      result.attestation.length == 64;
}

// Test-only SHA-256 helper kept local so the fake reader independently computes
// the exact digest expected by the protocol contract.
Uint8List _digest(Uint8List input) {
  return Uint8List.fromList(crypto.sha256.convert(input).bytes);
}
