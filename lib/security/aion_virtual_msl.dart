// Hardwareless AION-MSL security mode. Simulated chaos receives zero entropy
// credit; security comes from cryptographic roots, fresh CSPRNG output, the
// monotonic store, and (for maximum mode) an authenticated ML-KEM secret.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'aion_entropy_federation.dart';
import 'metameric_surface_lattice.dart';

enum AionProfile { research, local, maximum, federatedMaximum }

final class AionCheckpoint {
  AionCheckpoint({
    this.suiteVersion = AionVirtualMslEngine.suiteVersion,
    required this.epoch,
    required Uint8List ratchet,
    required Uint8List merkleRoot,
  }) : ratchet = Uint8List.fromList(ratchet),
       merkleRoot = Uint8List.fromList(merkleRoot);
  final int epoch;
  final int suiteVersion;
  final Uint8List ratchet;
  final Uint8List merkleRoot;
}

abstract interface class AionCheckpointStore {
  Future<AionCheckpoint?> load(AionProfile profile);
  Future<void> compareAndCommit({
    required AionProfile profile,
    required int expectedEpoch,
    required AionCheckpoint next,
  });
}

final class AionMemoryCheckpointStore implements AionCheckpointStore {
  AionCheckpoint? _value;
  @override
  Future<AionCheckpoint?> load(AionProfile profile) async => _value == null
      ? null
      : AionCheckpoint(
          suiteVersion: _value!.suiteVersion,
          epoch: _value!.epoch,
          ratchet: _value!.ratchet,
          merkleRoot: _value!.merkleRoot,
        );
  @override
  Future<void> compareAndCommit({
    required AionProfile profile,
    required int expectedEpoch,
    required AionCheckpoint next,
  }) async {
    if ((_value?.epoch ?? 0) != expectedEpoch ||
        next.epoch != expectedEpoch + 1 ||
        next.suiteVersion != AionVirtualMslEngine.suiteVersion) {
      throw const MslProtocolException(
        'aion_checkpoint_fork',
        'The AION checkpoint has forked or rolled back.',
      );
    }
    _value = AionCheckpoint(
      suiteVersion: next.suiteVersion,
      epoch: next.epoch,
      ratchet: next.ratchet,
      merkleRoot: next.merkleRoot,
    );
  }
}

final class AionPolicy {
  const AionPolicy({
    required this.profile,
    required this.latticeWidth,
    required this.sequentialRounds,
    required this.challengeDepth,
    required this.handleLifetime,
    this.requiresFederation = false,
  });

  final AionProfile profile;
  final int latticeWidth;
  final int sequentialRounds;
  final int challengeDepth;
  final Duration handleLifetime;
  final bool requiresFederation;

  static const research = AionPolicy(
    profile: AionProfile.research,
    latticeWidth: 256,
    sequentialRounds: 64,
    challengeDepth: 8,
    handleLifetime: Duration(seconds: 30),
  );
  static const local = AionPolicy(
    profile: AionProfile.local,
    latticeWidth: 2048,
    sequentialRounds: 2048,
    challengeDepth: 24,
    handleLifetime: Duration(seconds: 20),
  );
  static const maximum = AionPolicy(
    profile: AionProfile.maximum,
    latticeWidth: 8192,
    sequentialRounds: 8192,
    challengeDepth: 48,
    handleLifetime: Duration(seconds: 10),
  );
  static const federatedMaximum = AionPolicy(
    profile: AionProfile.federatedMaximum,
    latticeWidth: 8192,
    sequentialRounds: 8192,
    challengeDepth: 48,
    handleLifetime: Duration(seconds: 10),
    requiresFederation: true,
  );

  void validate() {
    if (latticeWidth < 256 ||
        latticeWidth > 65536 ||
        sequentialRounds < 1 ||
        sequentialRounds > 1000000 ||
        challengeDepth < 8 ||
        challengeDepth > 256 ||
        handleLifetime <= Duration.zero ||
        handleLifetime > const Duration(minutes: 5)) {
      throw const MslProtocolException(
        'aion_policy_invalid',
        'The AION policy exceeds its bounded security envelope.',
      );
    }
  }
}

final class AionChaosFrame {
  const AionChaosFrame(this.coordinates);
  final List<double> coordinates;

  Uint8List canonicalBytes() {
    if (coordinates.length < 8 ||
        coordinates.length > 4096 ||
        coordinates.any((v) => !v.isFinite || v < -1 || v > 1)) {
      throw const MslProtocolException(
        'aion_chaos_invalid',
        'The simulated chaos frame is malformed.',
      );
    }
    final data = ByteData(4 + coordinates.length * 8)
      ..setUint32(0, coordinates.length, Endian.big);
    for (var i = 0; i < coordinates.length; i++) {
      data.setFloat64(4 + i * 8, coordinates[i], Endian.big);
    }
    return data.buffer.asUint8List();
  }
}

final class AionCapability {
  const AionCapability._(this.id, this.purpose, this.epoch, this.expiresAt);
  final String id;
  final String purpose;
  final int epoch;
  final DateTime expiresAt;
}

final class AionProof {
  const AionProof({
    required this.epoch,
    required this.transcriptDigest,
    required this.stateCommitment,
    required this.proof,
    required this.capability,
    required this.entropyCreditBits,
  });
  final int epoch;
  final Uint8List transcriptDigest;
  final Uint8List stateCommitment;
  final Uint8List proof;
  final AionCapability capability;
  final int entropyCreditBits;
}

typedef AionEntropySource = Uint8List Function(int length);

abstract interface class AionExternalKeySchedule {
  Future<Uint8List> deriveActiveKey({
    required Uint8List transcriptDigest,
    required Uint8List priorRatchet,
    required Uint8List freshEntropy,
    required Uint8List postQuantumSecret,
    required Uint8List federationSecret,
  });
}

final class AionVirtualMslEngine {
  static const int suiteVersion = 2;

  AionVirtualMslEngine({
    required this.policy,
    required this.counterStore,
    required this.checkpointStore,
    Uint8List? deviceRoot,
    Uint8List? userRoot,
    this.externalKeySchedule,
    AionEntropySource? entropy,
    DateTime Function()? clock,
  }) : _deviceRoot = Uint8List.fromList(deviceRoot ?? const []),
       _userRoot = userRoot == null ? null : Uint8List.fromList(userRoot),
       _entropy = entropy ?? _secureEntropy,
       _clock = clock ?? DateTime.now {
    policy.validate();
    if (policy.requiresFederation &&
        (externalKeySchedule == null ||
            deviceRoot != null ||
            userRoot != null)) {
      throw const MslProtocolException(
        'aion_external_schedule_required',
        'Federated maximum requires an external key schedule and forbids host-resident roots.',
      );
    }
    if (!policy.requiresFederation &&
        (deviceRoot == null ||
            deviceRoot.length < 32 ||
            deviceRoot.length > 128 ||
            (userRoot != null &&
                (userRoot.length < 32 || userRoot.length > 128)))) {
      throw const MslProtocolException(
        'aion_root_invalid',
        'AION roots must contain at least 256 bits.',
      );
    }
    _ratchet = policy.requiresFederation
        ? _hmac(
            _hash(utf8.encode('AION-MSL/external/genesis/v2')),
            utf8.encode('AION-MSL/ratchet/genesis/v2'),
          )
        : _hmac(_deviceRoot, utf8.encode('AION-MSL/ratchet/genesis/v1'));
    _merkleRoot = _hash(utf8.encode('AION-MSL/merkle/empty/v1'));
  }

  final AionPolicy policy;
  final MslMonotonicCounterStore counterStore;
  final AionCheckpointStore checkpointStore;
  final AionExternalKeySchedule? externalKeySchedule;
  final Uint8List _deviceRoot;
  final Uint8List? _userRoot;
  final AionEntropySource _entropy;
  final DateTime Function() _clock;
  final Map<String, _AionStoredCapability> _capabilities = {};
  late Uint8List _ratchet;
  late Uint8List _merkleRoot;
  int _epoch = 0;
  bool _busy = false;
  bool _initialized = false;
  Uint8List? _lastEntropyDigest;

  Future<AionProof> advance({
    required String purpose,
    required Uint8List verifierNonce,
    required Uint8List postQuantumSecret,
    required List<AionChaosFrame> chaosFrames,
    AionFederationMix? federation,
  }) async {
    if (_busy)
      throw const MslProtocolException(
        'aion_busy',
        'AION is already advancing.',
      );
    if (!RegExp(r'^[A-Za-z0-9._:/-]{1,64}$').hasMatch(purpose) ||
        verifierNonce.length != 32 ||
        chaosFrames.isEmpty ||
        chaosFrames.length > 64) {
      throw const MslProtocolException(
        'aion_request_invalid',
        'The AION request is malformed.',
      );
    }
    if ((policy.profile == AionProfile.maximum ||
            policy.profile == AionProfile.federatedMaximum) &&
        postQuantumSecret.length < 32) {
      throw const MslProtocolException(
        'aion_pq_required',
        'Maximum AION requires an authenticated ML-KEM secret.',
      );
    }
    if (postQuantumSecret.length > 128)
      throw const MslProtocolException(
        'aion_pq_invalid',
        'The PQ contribution is oversized.',
      );
    if (policy.requiresFederation && federation == null) {
      throw const MslProtocolException(
        'aion_federation_required',
        'Federated-maximum AION cannot run without a verified federation.',
      );
    }
    _busy = true;
    Uint8List? working;
    Uint8List? freshMaterial;
    Uint8List? extractInput;
    Uint8List? pseudorandomKey;
    try {
      final persisted = await counterStore.current(
        deviceId: 'aion-virtual',
        profileId: policy.profile.name,
      );
      final checkpoint = await checkpointStore.load(policy.profile);
      if (!_initialized) {
        if (checkpoint != null) {
          if (checkpoint.suiteVersion != suiteVersion) {
            throw const MslProtocolException(
              'aion_suite_downgrade',
              'The AION checkpoint belongs to an unsupported cryptographic suite.',
            );
          }
          _zero(_ratchet);
          _ratchet = Uint8List.fromList(checkpoint.ratchet);
          _merkleRoot = Uint8List.fromList(checkpoint.merkleRoot);
          _epoch = checkpoint.epoch;
        }
        _initialized = true;
      } else if (checkpoint == null ||
          checkpoint.epoch != _epoch ||
          !_constantTimeEqual(checkpoint.merkleRoot, _merkleRoot)) {
        throw const MslProtocolException(
          'aion_checkpoint_fork',
          'The durable AION checkpoint diverged from live state.',
        );
      }
      if (persisted != _epoch)
        throw const MslProtocolException(
          'counter_rollback_detected',
          'The AION counter and encrypted checkpoint disagree.',
        );
      final next = _epoch + 1;
      final federationBinding = federation?.consumeForEpoch(next);
      if (policy.profile == AionProfile.federatedMaximum &&
          (federationBinding == null ||
              federationBinding.acceptedSourceCount < 5 ||
              federationBinding.confidentialSourceCount < 3 ||
              federationBinding.confidentialTrustDomainCount < 3)) {
        throw const MslProtocolException(
          'aion_federation_strength',
          'Federated maximum requires five sources, three confidential sources, and three independent trust domains.',
        );
      }
      final chaosDigest = _hash(
        _join(chaosFrames.map((f) => f.canonicalBytes())),
      );
      final fresh = _entropy(64);
      freshMaterial = fresh;
      if (fresh.length != 64)
        throw const MslProtocolException(
          'entropy_failure',
          'AION requires 512 fresh OS-random bits.',
        );
      final entropyDigest = _hash(fresh);
      if (_lastEntropyDigest != null &&
          _constantTimeEqual(_lastEntropyDigest!, entropyDigest)) {
        throw const MslProtocolException(
          'entropy_repetition',
          'AION detected a repeated CSPRNG block in the live engine.',
        );
      }
      _lastEntropyDigest = entropyDigest;
      final transcript = _join([
        utf8.encode('AION-MSL/transcript/v2'),
        _lengthPrefixed(utf8.encode(policy.profile.name)),
        _lengthPrefixed(utf8.encode(purpose)),
        verifierNonce,
        _u64(next),
        chaosDigest,
        _merkleRoot,
        if (federationBinding != null) federationBinding.transcriptCommitment,
        if (federationBinding != null) _u64(federationBinding.round),
      ]);
      final transcriptDigest = _hash(transcript);
      late Uint8List active;
      if (externalKeySchedule case final schedule?) {
        final externalTranscript = Uint8List.fromList(transcriptDigest);
        final externalRatchet = Uint8List.fromList(_ratchet);
        final externalFresh = Uint8List.fromList(fresh);
        final externalPq = Uint8List.fromList(postQuantumSecret);
        final externalFederation =
            federationBinding?.confidentialMix ?? Uint8List(0);
        try {
          active = await schedule.deriveActiveKey(
            transcriptDigest: externalTranscript,
            priorRatchet: externalRatchet,
            freshEntropy: externalFresh,
            postQuantumSecret: externalPq,
            federationSecret: externalFederation,
          );
        } finally {
          _zero(externalTranscript);
          _zero(externalRatchet);
          _zero(externalFresh);
          _zero(externalPq);
          _zero(externalFederation);
        }
        if (active.length != 64) {
          _zero(active);
          throw const MslProtocolException(
            'aion_external_schedule_invalid',
            'The external key schedule returned an invalid result.',
          );
        }
      } else {
        extractInput = _join([
          _lengthPrefixed(_deviceRoot),
          _lengthPrefixed(_userRoot ?? Uint8List(0)),
          _lengthPrefixed(_ratchet),
          _lengthPrefixed(fresh),
          _lengthPrefixed(postQuantumSecret),
          _lengthPrefixed(federationBinding?.confidentialMix ?? Uint8List(0)),
        ]);
        pseudorandomKey = _hmac(
          _join([utf8.encode('AION-MSL/extract/v2'), transcriptDigest]),
          extractInput,
        );
        active = _hmac(
          pseudorandomKey,
          _join([
            utf8.encode('AION-MSL/expand/active/v2'),
            transcriptDigest,
            [1],
          ]),
        );
      }
      working = active;
      for (var i = 0; i < policy.sequentialRounds; i++) {
        active = _hmac(active, _join([transcriptDigest, _u64(i), chaosDigest]));
        working = active;
      }
      final lattice = BytesBuilder(copy: false);
      var block = active;
      while (lattice.length < policy.latticeWidth) {
        block = _hmac(block, _join([transcriptDigest, _u64(lattice.length)]));
        lattice.add(block);
      }
      final latticeDigest = _hash(lattice.takeBytes());
      final newRatchet = _hmac(
        active,
        _join([utf8.encode('puncture'), latticeDigest, fresh]),
      );
      final newMerkle = _hash(
        _join([
          _merkleRoot,
          _hash(_join([_u64(next), transcriptDigest, latticeDigest])),
        ]),
      );
      await checkpointStore.compareAndCommit(
        profile: policy.profile,
        expectedEpoch: _epoch,
        next: AionCheckpoint(
          suiteVersion: suiteVersion,
          epoch: next,
          ratchet: newRatchet,
          merkleRoot: newMerkle,
        ),
      );
      final committed = await counterStore.advance(
        deviceId: 'aion-virtual',
        profileId: policy.profile.name,
        expectedCurrent: _epoch,
      );
      if (committed != next)
        throw const MslProtocolException(
          'counter_commit_invalid',
          'AION counter transition failed.',
        );
      final capabilityKey = _hmac(
        active,
        _join([utf8.encode('capability'), transcriptDigest]),
      );
      final id = base64UrlEncode(
        _hash(_join([capabilityKey, _entropy(16)])),
      ).replaceAll('=', '');
      final now = _clock().toUtc();
      _capabilities[id] = _AionStoredCapability(
        capabilityKey,
        purpose,
        next,
        now.add(policy.handleLifetime),
      );
      _zero(_ratchet);
      _ratchet = newRatchet;
      _merkleRoot = newMerkle;
      _epoch = next;
      final proof = _hmac(
        capabilityKey,
        _join([utf8.encode('proof'), transcriptDigest, newMerkle]),
      );
      return AionProof(
        epoch: next,
        transcriptDigest: transcriptDigest,
        stateCommitment: Uint8List.fromList(newMerkle),
        proof: proof,
        capability: AionCapability._(
          id,
          purpose,
          next,
          now.add(policy.handleLifetime),
        ),
        entropyCreditBits: policy.profile == AionProfile.research ? 0 : 256,
      );
    } finally {
      if (working != null) _zero(working);
      if (freshMaterial != null) _zero(freshMaterial);
      if (extractInput != null) _zero(extractInput);
      if (pseudorandomKey != null) _zero(pseudorandomKey);
      _busy = false;
    }
  }

  Uint8List authorize(AionCapability capability, Uint8List message) {
    final stored = _capabilities.remove(capability.id);
    if (stored == null ||
        stored.purpose != capability.purpose ||
        stored.epoch != capability.epoch ||
        !_clock().toUtc().isBefore(stored.expiresAt) ||
        message.length > 1048576) {
      if (stored != null) _zero(stored.key);
      throw const MslProtocolException(
        'aion_capability_rejected',
        'The AION capability is expired, reused, altered, or invalid.',
      );
    }
    try {
      return _hmac(
        stored.key,
        _join([
          utf8.encode('AION-MSL/use/v1'),
          utf8.encode(stored.purpose),
          message,
        ]),
      );
    } finally {
      _zero(stored.key);
    }
  }

  void dispose() {
    _zero(_ratchet);
    _zero(_deviceRoot);
    final userRoot = _userRoot;
    if (userRoot != null) _zero(userRoot);
    for (final value in _capabilities.values) {
      _zero(value.key);
    }
    _capabilities.clear();
  }
}

final class _AionStoredCapability {
  const _AionStoredCapability(
    this.key,
    this.purpose,
    this.epoch,
    this.expiresAt,
  );
  final Uint8List key;
  final String purpose;
  final int epoch;
  final DateTime expiresAt;
}

Uint8List _hash(List<int> value) =>
    Uint8List.fromList(crypto.sha256.convert(value).bytes);
Uint8List _hmac(List<int> key, List<int> value) =>
    Uint8List.fromList(crypto.Hmac(crypto.sha512, key).convert(value).bytes);
Uint8List _join(Iterable<List<int>> values) {
  final b = BytesBuilder(copy: false);
  for (final v in values) {
    b.add(v);
  }
  return b.takeBytes();
}

Uint8List _lengthPrefixed(List<int> value) {
  final length = ByteData(4)..setUint32(0, value.length, Endian.big);
  return _join([length.buffer.asUint8List(), value]);
}

Uint8List _u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.big)).buffer.asUint8List();
Uint8List _secureEntropy(int length) {
  final r = math.Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

void _zero(Uint8List value) => value.fillRange(0, value.length, 0);
bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = math.min(left.length, right.length);
  for (var i = 0; i < length; i++) difference |= left[i] ^ right[i];
  return difference == 0;
}
