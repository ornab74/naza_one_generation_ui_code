// LLM-CONTEXT:BEGIN
// FILE: lib/security/metameric_surface_lattice.dart
// ROLE: Hardened host-side protocol boundary for an external MSL optical root.
// DOMAIN: security
// SECURITY-INVARIANT: Raw optical responses and reconstructed secrets never cross the reader boundary; only opaque key handles and proofs leave this module.
// CHANGE-GUARD: Do not treat simulations, camera data, entropy scores, or quantum-inspired transforms as physical possession evidence.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'aion_authorization_event.dart';

const String mslProtocolVersion = 'MSL-PQ/host-v2';

enum MslReaderState { reset, ready, executing, reconstructing, complete, fault }

final class MslProtocolException implements Exception {
  const MslProtocolException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'MslProtocolException($code): $message';
}

final class MslProfile {
  const MslProfile({
    required this.id,
    required this.challengeCount,
    required this.wavelengthsNm,
    required this.intensitiesMilli,
    required this.incidenceMilliDegrees,
    required this.polarizationMilliDegrees,
    required this.durationsMicros,
    required this.maxCumulativeEnergyUnits,
    this.maximumTemperatureMilliC = 65000,
    this.minimumTemperatureMilliC = -10000,
    this.maximumTimingErrorMicros = 150,
  });

  final String id;
  final int challengeCount;
  final List<int> wavelengthsNm;
  final List<int> intensitiesMilli;
  final List<int> incidenceMilliDegrees;
  final List<int> polarizationMilliDegrees;
  final List<int> durationsMicros;
  final int maxCumulativeEnergyUnits;
  final int minimumTemperatureMilliC;
  final int maximumTemperatureMilliC;
  final int maximumTimingErrorMicros;

  void validate() {
    if (!_safeId(id) || challengeCount < 8 || challengeCount > 256) {
      throw const MslProtocolException(
        'profile_invalid',
        'The MSL profile identity or challenge count is invalid.',
      );
    }
    _boundedSet(wavelengthsNm, 350, 850, 'wavelength');
    _boundedSet(intensitiesMilli, 1, 2000, 'intensity');
    _boundedSet(incidenceMilliDegrees, 0, 90000, 'incidence');
    _boundedSet(polarizationMilliDegrees, 0, 179999, 'polarization');
    _boundedSet(durationsMicros, 10, 10000000, 'duration');
    if (maxCumulativeEnergyUnits <= 0 ||
        maxCumulativeEnergyUnits > 1000000000 ||
        minimumTemperatureMilliC < -40000 ||
        maximumTemperatureMilliC > 125000 ||
        minimumTemperatureMilliC >= maximumTemperatureMilliC ||
        maximumTimingErrorMicros < 1 ||
        maximumTimingErrorMicros > 100000) {
      throw const MslProtocolException(
        'profile_invalid',
        'The MSL safety envelope is invalid.',
      );
    }
  }

  static void _boundedSet(
    List<int> values,
    int minimum,
    int maximum,
    String name,
  ) {
    if (values.isEmpty ||
        values.length > 256 ||
        values.toSet().length != values.length) {
      throw MslProtocolException(
        'profile_invalid',
        'The $name set is empty, duplicated, or too large.',
      );
    }
    if (values.any((value) => value < minimum || value > maximum)) {
      throw MslProtocolException(
        'profile_invalid',
        'The $name set exceeds its safety bounds.',
      );
    }
  }
}

final class MslChallengeInstruction {
  const MslChallengeInstruction({
    required this.wavelengthNm,
    required this.intensityMilli,
    required this.incidenceMilliDegrees,
    required this.polarizationMilliDegrees,
    required this.durationMicros,
  });

  final int wavelengthNm;
  final int intensityMilli;
  final int incidenceMilliDegrees;
  final int polarizationMilliDegrees;
  final int durationMicros;

  Uint8List canonicalBytes() {
    final data = ByteData(20)
      ..setUint32(0, wavelengthNm, Endian.big)
      ..setUint32(4, intensityMilli, Endian.big)
      ..setUint32(8, incidenceMilliDegrees, Endian.big)
      ..setUint32(12, polarizationMilliDegrees, Endian.big)
      ..setUint32(16, durationMicros, Endian.big);
    return data.buffer.asUint8List();
  }
}

final class MslChallengeProgram {
  const MslChallengeProgram({
    required this.profileId,
    required this.instructions,
  });

  final String profileId;
  final List<MslChallengeInstruction> instructions;

  Uint8List canonicalBytes() {
    final builder = BytesBuilder(copy: false)
      ..add(_field(utf8.encode(mslProtocolVersion)))
      ..add(_field(utf8.encode(profileId)))
      ..add(_u32(instructions.length));
    for (final instruction in instructions) {
      builder.add(instruction.canonicalBytes());
    }
    return builder.takeBytes();
  }
}

final class MslReaderHealth {
  const MslReaderHealth({
    required this.temperatureMilliC,
    required this.maximumTimingErrorMicros,
    required this.detectorSaturated,
    required this.detectorUnderexposed,
    required this.resetVerified,
    required this.productionFirmware,
  });

  final int temperatureMilliC;
  final int maximumTimingErrorMicros;
  final bool detectorSaturated;
  final bool detectorUnderexposed;
  final bool resetVerified;
  final bool productionFirmware;
}

/// Result created inside a trusted reader after feature reconstruction.
/// [surfaceSecret] must be newly allocated and is destroyed by the host engine.
final class MslReaderResult {
  MslReaderResult({
    required this.surfaceSecret,
    required this.executedProgramDigest,
    required this.firmwareMeasurement,
    required this.attestation,
    required this.health,
  });

  final Uint8List surfaceSecret;
  final Uint8List executedProgramDigest;
  final Uint8List firmwareMeasurement;
  final Uint8List attestation;
  final MslReaderHealth health;
}

/// Native implementations own optical execution, calibration, quantization,
/// fuzzy reconstruction, and immediate erasure of all raw response material.
abstract interface class MslSecureReader {
  String get deviceId;
  String get profileId;
  MslReaderState get state;

  Future<MslReaderResult> execute(MslChallengeProgram program);
  Future<void> resetAfterFault();
}

/// Verifies a native reader signature rooted in a provisioned manufacturer or
/// fleet trust anchor. The signature must cover the device/profile identity,
/// executed-program digest, firmware measurement, and health summary. A
/// boolean firmware flag is never sufficient by itself.
abstract interface class MslReaderAttestationVerifier {
  Future<bool> verify({
    required String deviceId,
    required String profileId,
    required Uint8List requestedProgramDigest,
    required MslReaderResult result,
  });
}

/// Atomic monotonic storage. Implementations must reject rollback and perform
/// compare-and-advance as one serialized operation.
abstract interface class MslMonotonicCounterStore {
  Future<int> current({required String deviceId, required String profileId});

  Future<int> advance({
    required String deviceId,
    required String profileId,
    required int expectedCurrent,
  });
}

/// Intended for tests and ephemeral prototypes only.
final class MslMemoryCounterStore implements MslMonotonicCounterStore {
  MslMemoryCounterStore([this._value = 0]);
  int _value;

  @override
  Future<int> current({
    required String deviceId,
    required String profileId,
  }) async => _value;

  @override
  Future<int> advance({
    required String deviceId,
    required String profileId,
    required int expectedCurrent,
  }) async {
    if (_value != expectedCurrent) {
      throw const MslProtocolException(
        'counter_rollback_detected',
        'The monotonic MSL counter does not match persisted state.',
      );
    }
    return _value = expectedCurrent + 1;
  }
}

final class MslAuthenticationRequest {
  const MslAuthenticationRequest({
    required this.verifierNonce,
    required this.purpose,
    required this.issuedAt,
    required this.authorizationIntent,
  });

  final Uint8List verifierNonce;
  final String purpose;
  final DateTime issuedAt;
  final AionAuthorizationIntent authorizationIntent;
}

final class MslAuthorizationBinding {
  const MslAuthorizationBinding._({
    required this.intent,
    required this.deviceId,
    required this.profileId,
    required this.counter,
    required this.transcriptDigest,
    required this.receiptDigest,
  });

  final AionAuthorizationIntent intent;
  final String deviceId;
  final String profileId;
  final int counter;
  final Uint8List transcriptDigest;
  final Uint8List receiptDigest;
}

final class MslKeyHandle {
  const MslKeyHandle._(this.id, this.createdAt, this.expiresAt);

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
}

final class MslAuthenticationProof {
  const MslAuthenticationProof({
    required this.deviceId,
    required this.profileId,
    required this.transcriptDigest,
    required this.proof,
    required this.keyHandle,
    required this.counter,
    required this.authorizationBinding,
  });

  final String deviceId;
  final String profileId;
  final Uint8List transcriptDigest;
  final Uint8List proof;
  final MslKeyHandle keyHandle;
  final int counter;
  final MslAuthorizationBinding authorizationBinding;
}

typedef MslEntropySource = Uint8List Function(int length);

/// Host-side MSL protocol controller. A real deployment must persist [counter]
/// through an authenticated monotonic store and provide a native secure reader.
final class MslProtocolEngine {
  MslProtocolEngine({
    required this.reader,
    required this.profile,
    required this.attestationVerifier,
    required this.counterStore,
    required Uint8List enrollmentBindingKey,
    MslEntropySource? entropy,
    DateTime Function()? clock,
    this.requestLifetime = const Duration(minutes: 2),
    this.keyLifetime = const Duration(minutes: 5),
    this.maximumRequestsPerWindow = 8,
    this.rateWindow = const Duration(minutes: 1),
    int initialCounter = 0,
  }) : _bindingKey = Uint8List.fromList(enrollmentBindingKey),
       _entropy = entropy ?? _secureEntropy,
       _clock = clock ?? DateTime.now,
       _counter = initialCounter {
    profile.validate();
    if (!_safeId(reader.deviceId) ||
        reader.profileId != profile.id ||
        enrollmentBindingKey.length < 32) {
      throw const MslProtocolException(
        'enrollment_invalid',
        'The reader enrollment binding is invalid.',
      );
    }
    if (initialCounter < 0 ||
        requestLifetime <= Duration.zero ||
        requestLifetime > const Duration(minutes: 5) ||
        keyLifetime <= Duration.zero ||
        keyLifetime > const Duration(hours: 1) ||
        maximumRequestsPerWindow < 1 ||
        maximumRequestsPerWindow > 100 ||
        rateWindow <= Duration.zero ||
        rateWindow > const Duration(hours: 1)) {
      throw const MslProtocolException(
        'policy_invalid',
        'The MSL host policy is invalid.',
      );
    }
  }

  final MslSecureReader reader;
  final MslProfile profile;
  final MslReaderAttestationVerifier attestationVerifier;
  final MslMonotonicCounterStore counterStore;
  final Uint8List _bindingKey;
  final MslEntropySource _entropy;
  final DateTime Function() _clock;
  final Duration requestLifetime;
  final Duration keyLifetime;
  final int maximumRequestsPerWindow;
  final Duration rateWindow;
  final Map<String, _MslStoredKey> _sessionKeys = <String, _MslStoredKey>{};
  final Map<String, DateTime> _usedNonces = <String, DateTime>{};
  final List<DateTime> _requestTimes = <DateTime>[];
  int _counter;
  bool _busy = false;

  int get counter => _counter;

  Future<MslAuthenticationProof> authenticate(
    MslAuthenticationRequest request, {
    required Uint8List postQuantumSharedSecret,
  }) async {
    _validateRequest(request, postQuantumSharedSecret);
    if (_busy) {
      throw const MslProtocolException(
        'reader_busy',
        'The MSL reader is already executing a protocol.',
      );
    }
    _busy = true;
    Uint8List? surfaceSecret;
    Uint8List? sessionKey;
    final now = _clock().toUtc();
    final nonceId = _hex(_sha3(request.verifierNonce));
    try {
      _enforceRateLimit(now);
      _usedNonces.removeWhere(
        (_, usedAt) => now.difference(usedAt) > requestLifetime,
      );
      if (_usedNonces.containsKey(nonceId)) {
        throw const MslProtocolException(
          'replay_rejected',
          'The verifier nonce was already consumed.',
        );
      }
      _usedNonces[nonceId] = now;
      final persistedCounter = await counterStore.current(
        deviceId: reader.deviceId,
        profileId: profile.id,
      );
      if (persistedCounter < _counter) {
        throw const MslProtocolException(
          'counter_rollback_detected',
          'The persisted MSL counter moved backwards.',
        );
      }
      _counter = persistedCounter;
      final nextCounter = _counter + 1;
      if (request.authorizationIntent.expectedMslCounter != nextCounter) {
        throw const MslProtocolException(
          'authorization_event_counter_mismatch',
          'The authorization intent does not bind the next physical counter.',
        );
      }
      final deviceNonce = _entropy(32);
      if (deviceNonce.length != 32) {
        throw const MslProtocolException(
          'entropy_failure',
          'The entropy source returned an invalid nonce.',
        );
      }
      final seed = _hmacSha512(
        _bindingKey,
        _concat([
          _field(utf8.encode('MSL/challenge-seed/v2')),
          _field(request.verifierNonce),
          _field(deviceNonce),
          _u64(nextCounter),
          _field(utf8.encode(profile.id)),
          _field(request.authorizationIntent.commitment),
        ]),
      );
      final program = _generateProgram(seed);
      final requestedDigest = _sha3(program.canonicalBytes());
      final result = await reader.execute(program);
      surfaceSecret = result.surfaceSecret;
      if (surfaceSecret.length < 32 ||
          result.executedProgramDigest.length != requestedDigest.length ||
          !_constantTimeEqual(result.executedProgramDigest, requestedDigest)) {
        throw const MslProtocolException(
          'reader_transcript_mismatch',
          'The reader did not prove execution of the requested program.',
        );
      }
      if (result.firmwareMeasurement.length != 32 ||
          result.attestation.length < 64 ||
          !await attestationVerifier.verify(
            deviceId: reader.deviceId,
            profileId: profile.id,
            requestedProgramDigest: requestedDigest,
            result: result,
          )) {
        throw const MslProtocolException(
          'reader_attestation_rejected',
          'The reader firmware or execution attestation is not trusted.',
        );
      }
      _validateHealth(result.health);
      final transcript = _concat([
        _field(utf8.encode(mslProtocolVersion)),
        _field(utf8.encode(reader.deviceId)),
        _field(utf8.encode(profile.id)),
        _field(utf8.encode(request.purpose)),
        _field(request.verifierNonce),
        _field(deviceNonce),
        _u64(nextCounter),
        _field(requestedDigest),
        _field(result.firmwareMeasurement),
        _field(request.authorizationIntent.commitment),
        _field(request.authorizationIntent.postQuantumContextDigest),
        _field(request.authorizationIntent.targetDigest),
      ]);
      final transcriptDigest = _sha3(transcript);
      sessionKey = _extractAndExpand(
        surfaceSecret,
        postQuantumSharedSecret,
        transcriptDigest,
        request.purpose,
      );
      final proof = _hmacSha512(
        sessionKey,
        _concat([
          _field(utf8.encode('MSL/proof/v2')),
          _field(transcriptDigest),
        ]),
      );
      final handleId = base64UrlEncode(
        _sha3(_concat([sessionKey, _entropy(16)])),
      ).replaceAll('=', '');
      final committedCounter = await counterStore.advance(
        deviceId: reader.deviceId,
        profileId: profile.id,
        expectedCurrent: _counter,
      );
      if (committedCounter != nextCounter) {
        throw const MslProtocolException(
          'counter_commit_invalid',
          'The monotonic counter store returned an invalid transition.',
        );
      }
      _counter = committedCounter;
      _sessionKeys[handleId] = _MslStoredKey(sessionKey, now.add(keyLifetime));
      sessionKey = null; // Ownership moved into the opaque handle store.
      _purgeExpiredKeys(now);
      final receiptDigest = _sha3(
        _concat([
          _field(utf8.encode('MSL/authorization-receipt/v1')),
          _field(request.authorizationIntent.commitment),
          _field(transcriptDigest),
          _field(proof),
          _u64(nextCounter),
        ]),
      );
      return MslAuthenticationProof(
        deviceId: reader.deviceId,
        profileId: profile.id,
        transcriptDigest: transcriptDigest,
        proof: proof,
        keyHandle: MslKeyHandle._(handleId, now, now.add(keyLifetime)),
        counter: nextCounter,
        authorizationBinding: MslAuthorizationBinding._(
          intent: request.authorizationIntent,
          deviceId: reader.deviceId,
          profileId: profile.id,
          counter: nextCounter,
          transcriptDigest: Uint8List.fromList(transcriptDigest),
          receiptDigest: receiptDigest,
        ),
      );
    } catch (_) {
      try {
        await reader.resetAfterFault();
      } catch (_) {
        // Preserve the original failure; the next call still checks state.
      }
      rethrow;
    } finally {
      if (surfaceSecret != null) _zeroize(surfaceSecret);
      if (sessionKey != null) _zeroize(sessionKey);
      _busy = false;
    }
  }

  Uint8List authenticateMessage(MslKeyHandle handle, Uint8List message) {
    final key = _resolveHandle(handle);
    if (message.length > 1024 * 1024) {
      throw const MslProtocolException(
        'message_too_large',
        'The authenticated message exceeds one MiB.',
      );
    }
    return _hmacSha512(
      key,
      _concat([_field(utf8.encode('MSL/application-mac/v2')), _field(message)]),
    );
  }

  void destroyHandle(MslKeyHandle handle) {
    final stored = _sessionKeys.remove(handle.id);
    if (stored != null) _zeroize(stored.key);
  }

  void dispose() {
    for (final stored in _sessionKeys.values) {
      _zeroize(stored.key);
    }
    _sessionKeys.clear();
    _zeroize(_bindingKey);
  }

  void _validateRequest(MslAuthenticationRequest request, Uint8List pqSecret) {
    final now = _clock().toUtc();
    final issued = request.issuedAt.toUtc();
    try {
      request.authorizationIntent.validateAt(now);
    } catch (_) {
      throw const MslProtocolException(
        'authorization_event_invalid',
        'The shared authorization intent is expired or not yet valid.',
      );
    }
    if (request.verifierNonce.length != 32 ||
        request.purpose.isEmpty ||
        request.purpose.length > 64 ||
        !_safePurpose(request.purpose) ||
        issued.isAfter(now.add(const Duration(seconds: 30))) ||
        now.difference(issued) > requestLifetime) {
      throw const MslProtocolException(
        'request_invalid',
        'The verifier request is malformed, expired, or outside policy.',
      );
    }
    final intent = request.authorizationIntent;
    if (intent.purpose != request.purpose ||
        !_constantTimeEqual(intent.verifierNonce, request.verifierNonce) ||
        intent.issuedAt.toUtc() != issued ||
        intent.mslDeviceId != reader.deviceId ||
        intent.mslProfileId != profile.id) {
      throw const MslProtocolException(
        'authorization_event_mismatch',
        'The physical request does not match its authorization intent.',
      );
    }
    if (pqSecret.length < 32 || pqSecret.length > 128) {
      throw const MslProtocolException(
        'pq_secret_invalid',
        'A 32-128 byte authenticated post-quantum shared secret is required.',
      );
    }
    if (reader.state == MslReaderState.executing ||
        reader.state == MslReaderState.reconstructing ||
        reader.state == MslReaderState.fault) {
      throw const MslProtocolException(
        'reader_state_invalid',
        'The reader is not in a safe state for authentication.',
      );
    }
  }

  void _enforceRateLimit(DateTime now) {
    _requestTimes.removeWhere((time) => now.difference(time) >= rateWindow);
    if (_requestTimes.length >= maximumRequestsPerWindow) {
      throw const MslProtocolException(
        'rate_limited',
        'The physical interrogation rate limit was reached.',
      );
    }
    _requestTimes.add(now);
  }

  MslChallengeProgram _generateProgram(Uint8List seed) {
    var stream = Uint8List.fromList(seed);
    var offset = stream.length;
    int nextInt(int bound) {
      if (offset + 4 > stream.length) {
        stream = _hmacSha512(
          _bindingKey,
          _concat([
            _field(utf8.encode('MSL/challenge-expand/v2')),
            _field(stream),
          ]),
        );
        offset = 0;
      }
      final value = ByteData.sublistView(stream).getUint32(offset, Endian.big);
      offset += 4;
      return value % bound;
    }

    final instructions = <MslChallengeInstruction>[];
    var energy = 0;
    for (var index = 0; index < profile.challengeCount; index++) {
      final intensity =
          profile.intensitiesMilli[nextInt(profile.intensitiesMilli.length)];
      final duration =
          profile.durationsMicros[nextInt(profile.durationsMicros.length)];
      energy += intensity * math.max(1, duration ~/ 1000);
      if (energy > profile.maxCumulativeEnergyUnits) {
        throw const MslProtocolException(
          'optical_dose_exceeded',
          'The generated program exceeds the optical dose limit.',
        );
      }
      instructions.add(
        MslChallengeInstruction(
          wavelengthNm:
              profile.wavelengthsNm[nextInt(profile.wavelengthsNm.length)],
          intensityMilli: intensity,
          incidenceMilliDegrees:
              profile.incidenceMilliDegrees[nextInt(
                profile.incidenceMilliDegrees.length,
              )],
          polarizationMilliDegrees:
              profile.polarizationMilliDegrees[nextInt(
                profile.polarizationMilliDegrees.length,
              )],
          durationMicros: duration,
        ),
      );
    }
    return MslChallengeProgram(
      profileId: profile.id,
      instructions: List.unmodifiable(instructions),
    );
  }

  void _validateHealth(MslReaderHealth health) {
    if (!health.productionFirmware ||
        !health.resetVerified ||
        health.detectorSaturated ||
        health.detectorUnderexposed ||
        health.temperatureMilliC < profile.minimumTemperatureMilliC ||
        health.temperatureMilliC > profile.maximumTemperatureMilliC ||
        health.maximumTimingErrorMicros > profile.maximumTimingErrorMicros) {
      throw const MslProtocolException(
        'reader_health_rejected',
        'The optical execution was outside its authenticated operating envelope.',
      );
    }
  }

  Uint8List _extractAndExpand(
    Uint8List surface,
    Uint8List pq,
    Uint8List transcript,
    String purpose,
  ) {
    final salt = _sha3(
      _concat([
        _field(utf8.encode('MSL/hybrid-extract/v2')),
        _field(transcript),
      ]),
    );
    final prk = _hmacSha512(salt, _concat([_field(surface), _field(pq)]));
    try {
      return _hmacSha512(
        prk,
        _concat([
          _field(utf8.encode('MSL/session-key/v2')),
          _field(utf8.encode(reader.deviceId)),
          _field(utf8.encode(profile.id)),
          _field(utf8.encode(purpose)),
          _field(transcript),
          Uint8List.fromList([1]),
        ]),
      ).sublist(0, 32);
    } finally {
      _zeroize(prk);
    }
  }

  Uint8List _resolveHandle(MslKeyHandle handle) {
    final now = _clock().toUtc();
    if (!now.isBefore(handle.expiresAt)) {
      destroyHandle(handle);
      throw const MslProtocolException(
        'key_handle_expired',
        'The MSL key handle expired.',
      );
    }
    final stored = _sessionKeys[handle.id];
    if (stored == null) {
      throw const MslProtocolException(
        'key_handle_unknown',
        'The MSL key handle is unknown or destroyed.',
      );
    }
    return stored.key;
  }

  void _purgeExpiredKeys(DateTime now) {
    final expired = _sessionKeys.entries
        .where((entry) => !now.isBefore(entry.value.expiresAt))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in expired) {
      final stored = _sessionKeys.remove(id);
      if (stored != null) _zeroize(stored.key);
    }
  }
}

final class _MslStoredKey {
  const _MslStoredKey(this.key, this.expiresAt);
  final Uint8List key;
  final DateTime expiresAt;
}

bool _safeId(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value);
bool _safePurpose(String value) =>
    RegExp(r'^[A-Za-z0-9._:/-]+$').hasMatch(value);

Uint8List _field(List<int> value) =>
    _concat([_u32(value.length), Uint8List.fromList(value)]);
Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.big)).buffer.asUint8List();
Uint8List _u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.big)).buffer.asUint8List();
Uint8List _concat(Iterable<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.takeBytes();
}

Uint8List _sha3(List<int> value) {
  // SHA-512/256 is unavailable in package:crypto. SHA-256 remains a standard
  // collision-resistant transcript digest; HMAC-SHA-512 performs extraction.
  return Uint8List.fromList(crypto.sha256.convert(value).bytes);
}

Uint8List _hmacSha512(List<int> key, List<int> value) =>
    Uint8List.fromList(crypto.Hmac(crypto.sha512, key).convert(value).bytes);

Uint8List _secureEntropy(int length) {
  final random = math.Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256), growable: false),
  );
}

bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = math.min(left.length, right.length);
  for (var index = 0; index < length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _zeroize(Uint8List value) => value.fillRange(0, value.length, 0);
String _hex(List<int> value) =>
    value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
