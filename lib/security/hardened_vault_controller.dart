import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'secure_database.dart';
import 'security_kernel.dart';

const _securityStateNamespace = 'security.kernel';
const _securityStateKey = 'state-v1';
const _securityStateFormat = 'naza-security-state-v1';
const _kernelKeyPrefix = 'naza-security-kernel-key-v1';
const _rollbackKeyPrefix = 'naza-security-highest-epoch-v1';

/// Hardened facade over [NazaSecureDatabase].
///
/// This layer adds deterministic authorization for privileged operations and a
/// two-copy rollback signal:
///
///  * the current security epoch is stored as an encrypted vault record;
///  * the highest observed epoch is stored independently in the platform secure
///    store through [NazaDeviceKeyStore].
///
/// Restoring an older database/header pair therefore fails closed once a newer
/// security epoch has been committed to the device store.
final class NazaHardenedVaultController {
  NazaHardenedVaultController({
    required this.vault,
    required this.secureStore,
    required this.appIdentity,
    required this.modelIdentity,
    required this.policyIdentity,
    required this.recoveryGeneration,
    required this.trustRootIdentity,
  });

  final NazaSecureDatabase vault;
  final NazaDeviceKeyStore secureStore;

  String appIdentity;
  String modelIdentity;
  String policyIdentity;
  String recoveryGeneration;
  String trustRootIdentity;

  NazaSecurityKernel? _kernel;
  NazaRollbackGuard? _rollbackGuard;
  NazaForwardSecureAudit? _audit;
  String? _vaultId;
  int? _securityEpoch;

  bool get isReady => vault.isUnlocked && _kernel != null;
  int? get securityEpoch => _securityEpoch;
  NazaSecurityState? get securityState => _kernel?.state;

  Future<void> create({
    required String password,
    bool passwordRequired = true,
    Map<NazaVaultRecordKey, Object?> initialRecords = const {},
  }) async {
    _rejectReservedRecords(initialRecords.keys);
    await vault.create(
      password: password,
      passwordRequired: passwordRequired,
      initialRecords: initialRecords,
    );
    try {
      await _attachSecurityState(allowMigration: true);
      await _auditEvent('vault-created', const <String, Object?>{});
    } catch (_) {
      await vault.lock();
      rethrow;
    }
  }

  Future<void> unlock(String password) async {
    await vault.unlock(password);
    try {
      await _attachSecurityState(allowMigration: true);
      await _auditEvent('vault-unlocked', const <String, Object?>{
        'method': 'password',
      });
    } catch (_) {
      await vault.lock();
      _destroySessionSecurity();
      rethrow;
    }
  }

  Future<void> unlockWithDeviceKey() async {
    await vault.unlockWithDeviceKey();
    try {
      await _attachSecurityState(allowMigration: true);
      await _auditEvent('vault-unlocked', const <String, Object?>{
        'method': 'device-key',
      });
    } catch (_) {
      await vault.lock();
      _destroySessionSecurity();
      rethrow;
    }
  }

  Future<void> lock() async {
    if (_kernel != null) {
      await _auditEvent('vault-locking', const <String, Object?>{});
    }
    _destroySessionSecurity();
    await vault.lock();
  }

  Future<Object?> readJson(String namespace, String key) {
    _rejectReservedKey(namespace, key);
    _requireReady();
    return vault.readJson(namespace, key);
  }

  Future<void> writeJson(String namespace, String key, Object? value) {
    _rejectReservedKey(namespace, key);
    _requireReady();
    return vault.writeJson(namespace, key, value);
  }

  Future<void> delete(String namespace, String key) {
    _rejectReservedKey(namespace, key);
    _requireReady();
    return vault.delete(namespace, key);
  }

  /// Fresh password verification is intentionally required for capabilities
  /// that authorize privileged operations. Device-only convenience unlock does
  /// not silently become authority to export or mutate trust configuration.
  Future<NazaCapabilityLease> authorizeWithPassword({
    required String password,
    required NazaPrivilegedAction action,
    String resource = 'vault',
  }) async {
    final kernel = _requireKernel();
    final verified = await vault.verifyPassword(password);
    if (!verified) {
      throw const NazaSecurityException(
        'fresh_auth_required',
        'A fresh startup-password verification is required for this operation.',
      );
    }
    final lease = await kernel.issueLease(
      action: action,
      resource: resource,
      maxUses: 1,
    );
    await _auditEvent('capability-issued', <String, Object?>{
      'action': action.name,
      'resource': resource,
    });
    return lease;
  }

  Future<Map<NazaVaultRecordKey, Object?>> exportRecordsAuthorized(
    NazaCapabilityLease lease,
  ) async {
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.exportVault,
      resource: 'vault',
    );
    final records = await vault.exportRecords();
    records.remove(const NazaVaultRecordKey(_securityStateNamespace, _securityStateKey));
    await _auditEvent('vault-exported', <String, Object?>{
      'recordCount': records.length,
    });
    return records;
  }

  Future<void> importRecordsAuthorized(
    NazaCapabilityLease lease,
    Map<NazaVaultRecordKey, Object?> records, {
    bool replace = false,
  }) async {
    _rejectReservedRecords(records.keys);
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.importVault,
      resource: 'vault',
    );
    await vault.importRecords(records, replace: replace);
    await _advanceSecurityEpoch('vault-imported', <String, Object?>{
      'replace': replace,
      'recordCount': records.length,
    });
  }

  Future<void> rotateDataKeyAuthorized(NazaCapabilityLease lease) async {
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.rotateKeys,
      resource: 'vault',
    );
    await vault.rotateDataKey();
    await _advanceSecurityEpoch('data-key-rotated', const <String, Object?>{});
  }

  Future<void> changeUnlockAuthorized(
    NazaCapabilityLease lease, {
    required String newPassword,
    required bool passwordRequired,
  }) async {
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.changeAuthentication,
      resource: 'vault',
    );
    await vault.changeUnlock(
      newPassword: newPassword,
      passwordRequired: passwordRequired,
    );
    await _advanceSecurityEpoch('authentication-changed', <String, Object?>{
      'passwordRequired': passwordRequired,
    });
  }

  Future<void> replaceModelIdentityAuthorized(
    NazaCapabilityLease lease, {
    required String newModelIdentity,
  }) async {
    if (newModelIdentity.trim().isEmpty) {
      throw ArgumentError.value(newModelIdentity, 'newModelIdentity');
    }
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.replaceModel,
      resource: 'model',
    );
    modelIdentity = newModelIdentity;
    await _advanceSecurityEpoch('model-identity-changed', <String, Object?>{
      'modelIdentity': newModelIdentity,
    });
  }

  Future<void> changeRecoveryIdentityAuthorized(
    NazaCapabilityLease lease, {
    required String newRecoveryGeneration,
  }) async {
    if (newRecoveryGeneration.trim().isEmpty) {
      throw ArgumentError.value(newRecoveryGeneration, 'newRecoveryGeneration');
    }
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.changeRecovery,
      resource: 'recovery',
    );
    recoveryGeneration = newRecoveryGeneration;
    await _advanceSecurityEpoch('recovery-generation-changed', <String, Object?>{
      'recoveryGeneration': newRecoveryGeneration,
    });
  }

  Future<void> changeTrustRootIdentityAuthorized(
    NazaCapabilityLease lease, {
    required String newTrustRootIdentity,
  }) async {
    if (newTrustRootIdentity.trim().isEmpty) {
      throw ArgumentError.value(newTrustRootIdentity, 'newTrustRootIdentity');
    }
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.changeTrustRoot,
      resource: 'trust-root',
    );
    trustRootIdentity = newTrustRootIdentity;
    await _advanceSecurityEpoch('trust-root-changed', <String, Object?>{
      'trustRootIdentity': newTrustRootIdentity,
    });
  }

  Future<void> _attachSecurityState({required bool allowMigration}) async {
    if (!vault.isUnlocked) {
      throw const NazaSecurityException('vault_locked', 'Vault must be unlocked first.');
    }

    final snapshot = await _readVaultHeaderSnapshot();
    _vaultId = snapshot.vaultId;
    final counter = NazaDeviceKeyCounterAdapter(secureStore);
    final guard = NazaRollbackGuard(
      counter,
      storageKey: '$_rollbackKeyPrefix-${snapshot.vaultId}',
    );
    final minimumEpoch = await guard.minimumEpoch();

    final rawState = await vault.readJson(_securityStateNamespace, _securityStateKey);
    int epoch;
    if (rawState == null) {
      if (!allowMigration || minimumEpoch > 0) {
        throw const NazaSecurityException(
          'rollback_state_missing',
          'Protected rollback state exists but the encrypted vault security state is missing.',
        );
      }
      epoch = math.max(1, snapshot.headerGeneration);
      await _writeSecurityMetadata(
        epoch: epoch,
        headerGeneration: snapshot.headerGeneration,
      );
    } else {
      final state = _parseSecurityMetadata(rawState, expectedVaultId: snapshot.vaultId);
      epoch = state.epoch;
      if (state.headerGeneration > snapshot.headerGeneration) {
        throw const NazaSecurityException(
          'header_rollback_detected',
          'The vault header generation is older than the encrypted security state.',
        );
      }
    }

    await guard.verify(epoch);
    final capabilityKey = await _loadOrCreateSecret(
      '$_kernelKeyPrefix-${snapshot.vaultId}',
    );
    final auditSeed = _randomBytes(32);
    try {
      final kernel = NazaSecurityKernel(
        capabilityKey: capabilityKey,
        initialState: _buildState(snapshot.vaultId, epoch),
      );
      _kernel?.destroy();
      _audit?.destroy();
      _kernel = kernel;
      _audit = NazaForwardSecureAudit(initialKey: auditSeed);
      _rollbackGuard = guard;
      _securityEpoch = epoch;
      await guard.commit(epoch);
    } finally {
      _zero(capabilityKey);
      _zero(auditSeed);
    }
  }

  Future<void> _advanceSecurityEpoch(
    String event,
    Map<String, Object?> data,
  ) async {
    final kernel = _requireKernel();
    final guard = _rollbackGuard;
    final vaultId = _vaultId;
    final current = _securityEpoch;
    if (guard == null || vaultId == null || current == null) {
      throw const NazaSecurityException('security_state_missing', 'Security state is not attached.');
    }
    final snapshot = await _readVaultHeaderSnapshot();
    if (snapshot.vaultId != vaultId) {
      throw const NazaSecurityException(
        'vault_identity_changed',
        'Vault identity changed while the security session was active.',
      );
    }
    final next = current + 1;

    // Crash-safe order: commit the authenticated in-vault epoch first. If the
    // process dies before the device-store commit, the vault is newer than the
    // guard and remains recoverable. The reverse ordering could brick a valid
    // vault after a crash.
    await _writeSecurityMetadata(
      epoch: next,
      headerGeneration: snapshot.headerGeneration,
    );
    await guard.commit(next);
    _securityEpoch = next;
    kernel.transition(_buildState(vaultId, next));
    await _auditEvent(event, data);
  }

  Future<void> _writeSecurityMetadata({
    required int epoch,
    required int headerGeneration,
  }) {
    if (epoch < 1 || headerGeneration < 1) {
      throw const NazaSecurityException('invalid_epoch', 'Security generations must be positive.');
    }
    return vault.writeJson(_securityStateNamespace, _securityStateKey, <String, Object?>{
      'format': _securityStateFormat,
      'vaultId': _vaultId ?? '',
      'epoch': epoch,
      'headerGeneration': headerGeneration,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  _VaultSecurityMetadata _parseSecurityMetadata(
    Object raw, {
    required String expectedVaultId,
  }) {
    if (raw is! Map) {
      throw const NazaSecurityException('security_state_corrupt', 'Encrypted security state is malformed.');
    }
    final format = raw['format']?.toString() ?? '';
    final vaultId = raw['vaultId']?.toString() ?? '';
    final epoch = _positiveInt(raw['epoch']);
    final headerGeneration = _positiveInt(raw['headerGeneration']);
    if (format != _securityStateFormat ||
        vaultId != expectedVaultId ||
        epoch == null ||
        headerGeneration == null) {
      throw const NazaSecurityException(
        'security_state_corrupt',
        'Encrypted security state failed validation.',
      );
    }
    return _VaultSecurityMetadata(
      epoch: epoch,
      headerGeneration: headerGeneration,
    );
  }

  Future<_VaultHeaderSnapshot> _readVaultHeaderSnapshot() async {
    final databaseFile = await vault.databaseFile();
    final headerFile = File('${databaseFile.parent.path}/naza_one_vault.header.json');
    if (!await headerFile.exists()) {
      throw const NazaSecurityException('header_missing', 'Vault header is missing.');
    }
    try {
      final decoded = jsonDecode(await headerFile.readAsString());
      if (decoded is! Map) throw const FormatException('header is not a map');
      final vaultId = decoded['vaultId']?.toString() ?? '';
      final generation = _positiveInt(decoded['generation']);
      if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId) || generation == null) {
        throw const FormatException('invalid header identity');
      }
      return _VaultHeaderSnapshot(vaultId: vaultId, headerGeneration: generation);
    } catch (error) {
      throw NazaSecurityException('header_invalid', 'Vault header security metadata is invalid: $error');
    }
  }

  NazaSecurityState _buildState(String vaultId, int epoch) {
    return NazaSecurityState(
      epoch: epoch,
      vaultId: vaultId,
      appIdentity: appIdentity,
      modelIdentity: modelIdentity,
      policyIdentity: policyIdentity,
      recoveryGeneration: recoveryGeneration,
      trustRootIdentity: trustRootIdentity,
    );
  }

  Future<Uint8List> _loadOrCreateSecret(String storageKey) async {
    final encoded = await secureStore.read(storageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final value = Uint8List.fromList(base64Decode(encoded));
        if (value.length != 32) throw const FormatException('wrong secret length');
        return value;
      } catch (error) {
        throw NazaSecurityException(
          'secure_state_corrupt',
          'Protected security-kernel state is malformed: $error',
        );
      }
    }
    final created = _randomBytes(32);
    await secureStore.write(storageKey, base64Encode(created));
    return created;
  }

  Future<void> _auditEvent(String event, Map<String, Object?> data) async {
    final audit = _audit;
    final epoch = _securityEpoch;
    if (audit == null || epoch == null) return;
    await audit.append(event: event, data: data, securityEpoch: epoch);
  }

  void _destroySessionSecurity() {
    _kernel?.destroy();
    _audit?.destroy();
    _kernel = null;
    _audit = null;
    _rollbackGuard = null;
    _vaultId = null;
    _securityEpoch = null;
  }

  NazaSecurityKernel _requireKernel() {
    final kernel = _kernel;
    if (kernel == null || !vault.isUnlocked) {
      throw const NazaSecurityException('security_session_missing', 'Hardened security session is not active.');
    }
    return kernel;
  }

  void _requireReady() => _requireKernel();

  void _rejectReservedRecords(Iterable<NazaVaultRecordKey> keys) {
    for (final key in keys) {
      _rejectReservedKey(key.namespace, key.key);
    }
  }

  void _rejectReservedKey(String namespace, String key) {
    if (namespace == _securityStateNamespace) {
      throw ArgumentError.value(
        '$namespace/$key',
        'record',
        'The hardened security namespace is reserved.',
      );
    }
  }
}

final class NazaDeviceKeyCounterAdapter implements NazaDeviceCounterStore {
  const NazaDeviceKeyCounterAdapter(this.store);

  final NazaDeviceKeyStore store;

  @override
  Future<String?> read(String key) => store.read(key);

  @override
  Future<void> write(String key, String value) => store.write(key, value);
}

final class _VaultHeaderSnapshot {
  final String vaultId;
  final int headerGeneration;

  const _VaultHeaderSnapshot({required this.vaultId, required this.headerGeneration});
}

final class _VaultSecurityMetadata {
  final int epoch;
  final int headerGeneration;

  const _VaultSecurityMetadata({required this.epoch, required this.headerGeneration});
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

Uint8List _randomBytes(int length) {
  final random = math.Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
