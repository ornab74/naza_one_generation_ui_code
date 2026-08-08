import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final class NazaSecurityState {
  final int epoch;
  final String vaultId;
  final String appIdentity;
  final String modelIdentity;
  final String policyIdentity;
  final String recoveryGeneration;
  final String trustRootIdentity;

  const NazaSecurityState({
    required this.epoch,
    required this.vaultId,
    required this.appIdentity,
    required this.modelIdentity,
    required this.policyIdentity,
    required this.recoveryGeneration,
    required this.trustRootIdentity,
  });

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'appIdentity': appIdentity,
    'epoch': epoch,
    'modelIdentity': modelIdentity,
    'policyIdentity': policyIdentity,
    'recoveryGeneration': recoveryGeneration,
    'trustRootIdentity': trustRootIdentity,
    'vaultId': vaultId,
  };
}

enum NazaPrivilegedAction {
  readPrivateData,
  writePrivateData,
  exportVault,
  importVault,
  rotateKeys,
  changeAuthentication,
  changeRecovery,
  replaceModel,
  changeTrustRoot,
  eraseVault,
}

/// Single-purpose bearer capability bound to security state, use budget, and a
/// short authorization lifetime measured by a session-monotonic clock.
final class NazaCapabilityLease {
  final String id;
  final NazaPrivilegedAction action;
  final String resource;
  final int issuedEpoch;
  final String stateDigest;
  final int maxUses;
  final int issuedMonotonicCounter;
  final int issuedAtMicros;
  final int expiresAtMicros;

  int _uses = 0;
  bool _revoked = false;

  NazaCapabilityLease._({
    required this.id,
    required this.action,
    required this.resource,
    required this.issuedEpoch,
    required this.stateDigest,
    required this.maxUses,
    required this.issuedMonotonicCounter,
    required this.issuedAtMicros,
    required this.expiresAtMicros,
  });

  int get uses => _uses;
  bool get revoked => _revoked;
  bool get exhausted => _uses >= maxUses;

  void revoke() => _revoked = true;
}

final class NazaSecurityKernel {
  NazaSecurityKernel({
    required List<int> capabilityKey,
    required NazaSecurityState initialState,
    int Function()? monotonicMicros,
  }) : _capabilityKey = Uint8List.fromList(capabilityKey),
       _state = initialState,
       _monotonicMicros = monotonicMicros ?? _newMonotonicClock();

  final Uint8List _capabilityKey;
  final Hmac _hmac = Hmac.sha256();
  final int Function() _monotonicMicros;
  NazaSecurityState _state;
  int _counter = 0;
  final Map<String, NazaCapabilityLease> _leases = <String, NazaCapabilityLease>{};

  NazaSecurityState get state => _state;

  Future<String> stateDigest() async {
    final bytes = utf8.encode(_canonicalJson(_state.toCanonicalMap()));
    final mac = await _hmac.calculateMac(
      bytes,
      secretKey: SecretKey(_capabilityKey),
    );
    return base64UrlEncode(mac.bytes).replaceAll('=', '');
  }

  Future<NazaCapabilityLease> issueLease({
    required NazaPrivilegedAction action,
    required String resource,
    int maxUses = 1,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    if (maxUses < 1 || maxUses > 1024) {
      throw ArgumentError.value(maxUses, 'maxUses', 'Use count must be 1-1024.');
    }
    if (ttl < const Duration(seconds: 1) ||
        ttl > const Duration(minutes: 5)) {
      throw ArgumentError.value(
        ttl,
        'ttl',
        'Capability lifetime must be between 1 second and 5 minutes.',
      );
    }
    _counter++;
    final digest = await stateDigest();
    final nonce = _randomBytes(16);
    final issuedAt = _monotonicMicros();
    final expiresAt = issuedAt + ttl.inMicroseconds;
    final material = utf8.encode(
      '${action.name}\u001f$resource\u001f${_state.epoch}\u001f$_counter\u001f$issuedAt\u001f$expiresAt\u001f$digest',
    );
    final idMac = await _hmac.calculateMac(
      <int>[...nonce, ...material],
      secretKey: SecretKey(_capabilityKey),
    );
    final id = base64UrlEncode(idMac.bytes).replaceAll('=', '');
    final lease = NazaCapabilityLease._(
      id: id,
      action: action,
      resource: resource,
      issuedEpoch: _state.epoch,
      stateDigest: digest,
      maxUses: maxUses,
      issuedMonotonicCounter: _counter,
      issuedAtMicros: issuedAt,
      expiresAtMicros: expiresAt,
    );
    _leases[id] = lease;
    return lease;
  }

  Future<void> consumeLease(
    NazaCapabilityLease lease, {
    required NazaPrivilegedAction action,
    required String resource,
  }) async {
    final current = _leases[lease.id];
    if (!identical(current, lease) || lease.revoked) {
      throw const NazaSecurityException(
        'capability_invalid',
        'Capability is unknown or revoked.',
      );
    }
    final now = _monotonicMicros();
    if (now > lease.expiresAtMicros) {
      lease.revoke();
      _leases.remove(lease.id);
      throw const NazaSecurityException(
        'capability_expired',
        'Capability authorization has expired; authenticate again.',
      );
    }
    if (lease.exhausted) {
      throw const NazaSecurityException(
        'capability_exhausted',
        'Capability use budget is exhausted.',
      );
    }
    if (lease.action != action || lease.resource != resource) {
      throw const NazaSecurityException(
        'capability_scope',
        'Capability does not authorize this operation.',
      );
    }
    if (lease.issuedEpoch != _state.epoch ||
        lease.stateDigest != await stateDigest()) {
      throw const NazaSecurityException(
        'capability_stale',
        'Capability was issued under a previous security state.',
      );
    }
    lease._uses++;
    if (lease.exhausted) {
      lease.revoke();
      _leases.remove(lease.id);
    }
  }

  void transition(NazaSecurityState next) {
    if (next.epoch <= _state.epoch) {
      throw const NazaSecurityException(
        'epoch_rollback',
        'Security epoch must increase monotonically.',
      );
    }
    _state = next;
    revokeAll();
  }

  void revokeAll() {
    for (final lease in _leases.values) {
      lease.revoke();
    }
    _leases.clear();
  }

  void destroy() {
    revokeAll();
    _zero(_capabilityKey);
  }
}

final class NazaForwardSecureAudit {
  NazaForwardSecureAudit({required List<int> initialKey})
    : _key = Uint8List.fromList(initialKey);

  final Hmac _hmac = Hmac.sha256();
  Uint8List _key;
  int _sequence = 0;
  String _tip = 'GENESIS';

  int get sequence => _sequence;
  String get tip => _tip;

  Future<NazaAuditEntry> append({
    required String event,
    required Map<String, Object?> data,
    required int securityEpoch,
  }) async {
    if (event.isEmpty || event.length > 128) {
      throw ArgumentError.value(event, 'event', 'Invalid audit event name.');
    }
    final sequence = ++_sequence;
    final body = <String, Object?>{
      'data': _canonicalize(data),
      'event': event,
      'previous': _tip,
      'securityEpoch': securityEpoch,
      'sequence': sequence,
    };
    final encoded = utf8.encode(_canonicalJson(body));
    final mac = await _hmac.calculateMac(
      encoded,
      secretKey: SecretKey(_key),
    );
    final macText = base64UrlEncode(mac.bytes).replaceAll('=', '');
    final entry = NazaAuditEntry(
      sequence: sequence,
      securityEpoch: securityEpoch,
      event: event,
      data: Map<String, Object?>.unmodifiable(data),
      previous: _tip,
      mac: macText,
    );
    _tip = await _entryDigest(entry);
    final nextKey = await _ratchet(_key, sequence);
    _zero(_key);
    _key = nextKey;
    return entry;
  }

  void destroy() {
    _zero(_key);
  }

  Future<Uint8List> _ratchet(List<int> key, int sequence) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('naza-forward-audit-v1/$sequence'),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(mac.bytes);
  }

  Future<String> _entryDigest(NazaAuditEntry entry) async {
    final hash = await Sha256().hash(
      utf8.encode(_canonicalJson(entry.toCanonicalMap())),
    );
    return base64UrlEncode(hash.bytes).replaceAll('=', '');
  }
}

final class NazaAuditEntry {
  final int sequence;
  final int securityEpoch;
  final String event;
  final Map<String, Object?> data;
  final String previous;
  final String mac;

  const NazaAuditEntry({
    required this.sequence,
    required this.securityEpoch,
    required this.event,
    required this.data,
    required this.previous,
    required this.mac,
  });

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'data': _canonicalize(data),
    'event': event,
    'mac': mac,
    'previous': previous,
    'securityEpoch': securityEpoch,
    'sequence': sequence,
  };
}

/// Legacy/simple counter guard retained for low-level tests and non-hardened
/// consumers. Hardened vaults use NazaAuthenticatedRollbackGuard instead.
final class NazaRollbackGuard {
  NazaRollbackGuard(this._store, {required this.storageKey});

  final NazaDeviceCounterStore _store;
  final String storageKey;

  Future<int> minimumEpoch() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    final value = int.tryParse(raw);
    if (value == null || value < 0) {
      throw const NazaSecurityException(
        'rollback_state_corrupt',
        'Stored rollback state is malformed.',
      );
    }
    return value;
  }

  Future<void> verify(int candidateEpoch) async {
    final minimum = await minimumEpoch();
    if (candidateEpoch < minimum) {
      throw NazaSecurityException(
        'rollback_detected',
        'Vault epoch $candidateEpoch is older than protected epoch $minimum.',
      );
    }
  }

  Future<void> commit(int epoch) async {
    final current = await minimumEpoch();
    if (epoch < current) {
      throw const NazaSecurityException(
        'epoch_rollback',
        'Rollback guard cannot move backwards.',
      );
    }
    await _store.write(storageKey, epoch.toString());
  }
}

abstract interface class NazaDeviceCounterStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class NazaMemoryCounterStore implements NazaDeviceCounterStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

final class NazaSecurityException implements Exception {
  final String code;
  final String message;

  const NazaSecurityException(this.code, this.message);

  @override
  String toString() => 'NazaSecurityException($code): $message';
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

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Uint8List _randomBytes(int length) {
  final random = math.Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

int Function() _newMonotonicClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsedMicroseconds;
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = 0;
  }
}
