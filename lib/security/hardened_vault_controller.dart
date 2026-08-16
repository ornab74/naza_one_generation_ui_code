// LLM-CONTEXT:BEGIN
// FILE: lib/security/hardened_vault_controller.dart
// ROLE: Owns hardened vault controller behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'authenticated_rollback_guard.dart';
import 'key_guardian.dart';
import 'secure_database.dart';
import 'security_kernel.dart';

const _securityStateNamespace = 'security.kernel';
const _securityStateKey = 'state-v2';
const _securityStateFormat = 'naza-security-state-v2';
const _legacySecurityStateKey = 'state-v1';
const _legacySecurityStateFormat = 'naza-security-state-v1';
const _rollbackKeyPrefix = 'naza-security-highest-epoch-v2';

final class NazaHardenedVaultController {
  NazaHardenedVaultController({
    required this.vault,
    required this.secureStore,
    required this.appIdentity,
    required this.modelIdentity,
    required this.policyIdentity,
    required this.recoveryGeneration,
    required this.trustRootIdentity,
    NazaKeyGuardian? keyGuardian,
  }) : keyGuardian = keyGuardian ?? NazaSecureStoreKeyGuardian(secureStore);

  final NazaSecureDatabase vault;
  final NazaDeviceKeyStore secureStore;
  final NazaKeyGuardian keyGuardian;

  String appIdentity;
  String modelIdentity;
  String policyIdentity;
  String recoveryGeneration;
  String trustRootIdentity;

  NazaSecurityKernel? _kernel;
  NazaAuthenticatedRollbackGuard? _rollbackGuard;
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
      // Creation is deliberately recoverable. The encrypted vault is already
      // a valid user-data boundary at this point; deleting it here would turn
      // a late audit/attachment failure into data loss. Clear all in-memory
      // capability material, then leave the vault available for a normal
      // unlock/retry path instead of reporting a non-existent setup state.
      _destroySessionSecurity();
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

  /// Issues a fresh lease for passwordless vaults by re-authenticating through
  /// the OS/device-key unlock boundary. Password verification is intentionally
  /// not used because it is unavailable by policy in this mode.
  Future<NazaCapabilityLease> authorizeWithDeviceKey({
    required NazaPrivilegedAction action,
    String resource = 'vault',
  }) async {
    _requireKernel();
    if (vault.passwordRequired) {
      throw const NazaSecurityException(
        'password_auth_required',
        'This vault requires fresh password authorization.',
      );
    }
    await vault.lock();
    _destroySessionSecurity();
    try {
      await vault.unlockWithDeviceKey();
      await _attachSecurityState(allowMigration: false);
    } catch (_) {
      await vault.lock();
      _destroySessionSecurity();
      rethrow;
    }
    final lease = await _requireKernel().issueLease(
      action: action,
      resource: resource,
      maxUses: 1,
    );
    await _auditEvent('capability-issued-device-key', <String, Object?>{
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
    records.removeWhere((key, _) => key.namespace.startsWith('security.'));
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
    await _advanceSecurityEpoch('vault-imported', <String, Object?>{
      'replace': replace,
      'recordCount': records.length,
    });
    await vault.importRecords(records, replace: replace);
  }

  Future<void> rotateDataKeyAuthorized(NazaCapabilityLease lease) async {
    final kernel = _requireKernel();
    await kernel.consumeLease(
      lease,
      action: NazaPrivilegedAction.rotateKeys,
      resource: 'vault',
    );
    await _advanceSecurityEpoch('data-key-rotated', const <String, Object?>{});
    await vault.rotateDataKey();
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
    await _advanceSecurityEpoch('authentication-changed', <String, Object?>{
      'passwordRequired': passwordRequired,
    });
    await vault.changeUnlock(
      newPassword: newPassword,
      passwordRequired: passwordRequired,
    );
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
      throw const NazaSecurityException(
        'vault_locked',
        'Vault must be unlocked first.',
      );
    }

    final snapshot = await _readVaultHeaderSnapshot();
    _vaultId = snapshot.vaultId;
    final counter = NazaDeviceKeyCounterAdapter(secureStore);
    final rollbackHandle = await keyGuardian.ensureRoot(
      vaultId: snapshot.vaultId,
      purpose: NazaGuardianPurpose.rollbackRoot,
    );
    if (rollbackHandle.exportable) {
      throw const NazaSecurityException(
        'guardian_exportable_root',
        'Hardened rollback roots must not be exportable handles.',
      );
    }
    final rollbackKey = await keyGuardian.deriveEphemeralSecret(
      handle: rollbackHandle,
      label: 'rollback-floor-authentication',
      context: <String, Object?>{'vaultId': snapshot.vaultId},
    );
    final rollbackStorageKey = '$_rollbackKeyPrefix-${snapshot.vaultId}';
    final guard = NazaAuthenticatedRollbackGuard(
      counter,
      storageKey: rollbackStorageKey,
      authenticationKey: rollbackKey,
    );
    _zero(rollbackKey);

    try {
      final protectedRollbackRaw = await secureStore.read(rollbackStorageKey);
      final currentRaw = await vault.readJson(
        _securityStateNamespace,
        _securityStateKey,
      );
      final legacyRaw = currentRaw == null
          ? await vault.readJson(_securityStateNamespace, _legacySecurityStateKey)
          : null;

      int epoch;
      var migration = false;
      if (currentRaw != null) {
      final state = _parseSecurityMetadata(
          currentRaw,
          expectedVaultId: snapshot.vaultId,
        );
        if (!state.rollbackProtected) {
          throw const NazaSecurityException(
            'rollback_state_unprotected',
            'Hardened security state unexpectedly lacks rollback protection.',
          );
        }
        if (protectedRollbackRaw == null || protectedRollbackRaw.isEmpty) {
          throw const NazaSecurityException(
            'rollback_state_missing',
            'An established hardened vault is missing its protected rollback state.',
          );
        }
        epoch = state.epoch;
        if (state.headerGeneration > snapshot.headerGeneration) {
          throw const NazaSecurityException(
            'header_rollback_detected',
            'The vault header generation is older than the encrypted security state.',
          );
        }
        if (state.identities.isNotEmpty) {
          _verifyPersistedIdentities(state);
        } else {
          await _writeSecurityMetadata(
            epoch: state.epoch,
            headerGeneration: state.headerGeneration,
          );
        }
      } else if (legacyRaw != null) {
        if (!allowMigration) {
          throw const NazaSecurityException(
            'security_migration_required',
            'Legacy hardened state requires an authenticated migration.',
          );
        }
        final state = _parseLegacySecurityMetadata(
          legacyRaw,
          expectedVaultId: snapshot.vaultId,
        );
        epoch = state.epoch;
        migration = true;
      } else {
        if (!allowMigration) {
          throw const NazaSecurityException(
            'security_state_missing',
            'Encrypted security state is missing.',
          );
        }
        epoch = math.max(1, snapshot.headerGeneration);
        migration = true;
      }

      if (!migration) {
        await guard.verify(epoch);
      } else {
        // Migration is allowed only when no authenticated v2 floor exists. If
        // one exists but the encrypted v2 state disappeared, treat that as a
        // rollback/deletion event instead of silently rebuilding protection.
        if (protectedRollbackRaw != null && protectedRollbackRaw.isNotEmpty) {
          throw const NazaSecurityException(
            'security_state_missing',
            'Protected rollback state exists but encrypted v2 security state is missing.',
          );
        }
        // The encrypted metadata is written only after the protected rollback
        // floor is committed below. This prevents a half-established v2
        // security state when the external floor write fails.
      }

      final nextKernel = await _createEpochKernel(snapshot.vaultId, epoch);
      final auditSeed = _randomBytes(32);
      try {
        _kernel?.destroy();
        _audit?.destroy();
        _rollbackGuard?.destroy();
        _kernel = nextKernel;
        _audit = NazaForwardSecureAudit(initialKey: auditSeed);
        _rollbackGuard = guard;
        _securityEpoch = epoch;
        await guard.commit(epoch);
        if (migration) {
          await _writeSecurityMetadata(
            epoch: epoch,
            headerGeneration: snapshot.headerGeneration,
          );
        }
        if (migration && legacyRaw != null) {
          await vault.delete(_securityStateNamespace, _legacySecurityStateKey);
        }
      } finally {
        _zero(auditSeed);
      }
    } catch (_) {
      guard.destroy();
      rethrow;
    }
  }

  Future<NazaSecurityKernel> _createEpochKernel(
    String vaultId,
    int epoch,
  ) async {
    final state = _buildState(vaultId, epoch);
    final handle = await keyGuardian.ensureRoot(
      vaultId: vaultId,
      purpose: NazaGuardianPurpose.capabilityRoot,
    );
    if (handle.exportable) {
      throw const NazaSecurityException(
        'guardian_exportable_root',
        'Hardened capability roots must not be exposed as exportable handles.',
      );
    }
    final capabilityKey = await keyGuardian.deriveEphemeralSecret(
      handle: handle,
      label: 'capability-kernel-epoch',
      context: <String, Object?>{
        'epoch': epoch,
        'vaultId': vaultId,
        'appIdentity': state.appIdentity,
        'modelIdentity': state.modelIdentity,
        'policyIdentity': state.policyIdentity,
        'recoveryGeneration': state.recoveryGeneration,
        'trustRootIdentity': state.trustRootIdentity,
      },
    );
    try {
      return NazaSecurityKernel(
        capabilityKey: capabilityKey,
        initialState: state,
      );
    } finally {
      _zero(capabilityKey);
    }
  }

  Future<void> _advanceSecurityEpoch(
    String event,
    Map<String, Object?> data,
  ) async {
    _requireKernel();
    final guard = _rollbackGuard;
    final vaultId = _vaultId;
    final current = _securityEpoch;
    if (guard == null || vaultId == null || current == null) {
      throw const NazaSecurityException(
        'security_state_missing',
        'Security state is not attached.',
      );
    }
    final snapshot = await _readVaultHeaderSnapshot();
    if (snapshot.vaultId != vaultId) {
      throw const NazaSecurityException(
        'vault_identity_changed',
        'Vault identity changed while the security session was active.',
      );
    }
    final next = current + 1;

    await _writeSecurityMetadata(
      epoch: next,
      headerGeneration: snapshot.headerGeneration,
    );
    await guard.commit(next);
    final nextKernel = await _createEpochKernel(vaultId, next);
    final oldKernel = _kernel;
    _kernel = nextKernel;
    _securityEpoch = next;
    oldKernel?.destroy();
    await _auditEvent(event, data);
  }

  Future<void> _writeSecurityMetadata({
    required int epoch,
    required int headerGeneration,
  }) {
    if (epoch < 1 || headerGeneration < 1) {
      throw const NazaSecurityException(
        'invalid_epoch',
        'Security generations must be positive.',
      );
    }
    return vault.writeJson(
      _securityStateNamespace,
      _securityStateKey,
      <String, Object?>{
        'format': _securityStateFormat,
        'vaultId': _vaultId ?? '',
        'epoch': epoch,
        'headerGeneration': headerGeneration,
        'rollbackProtected': true,
        'appIdentity': appIdentity,
        'modelIdentity': modelIdentity,
        'policyIdentity': policyIdentity,
        'recoveryGeneration': recoveryGeneration,
        'trustRootIdentity': trustRootIdentity,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  _VaultSecurityMetadata _parseSecurityMetadata(
    Object raw, {
    required String expectedVaultId,
  }) {
    if (raw is! Map) {
      throw const NazaSecurityException(
        'security_state_corrupt',
        'Encrypted security state is malformed.',
      );
    }
    final format = raw['format']?.toString() ?? '';
    final vaultId = raw['vaultId']?.toString() ?? '';
    final epoch = _positiveInt(raw['epoch']);
    final headerGeneration = _positiveInt(raw['headerGeneration']);
    final rollbackProtected = raw['rollbackProtected'] == true;
    final identities = <String, String>{
      'appIdentity': raw['appIdentity']?.toString() ?? '',
      'modelIdentity': raw['modelIdentity']?.toString() ?? '',
      'policyIdentity': raw['policyIdentity']?.toString() ?? '',
      'recoveryGeneration': raw['recoveryGeneration']?.toString() ?? '',
      'trustRootIdentity': raw['trustRootIdentity']?.toString() ?? '',
    };
    if (format != _securityStateFormat ||
        vaultId != expectedVaultId ||
        epoch == null ||
        headerGeneration == null) {
      throw const NazaSecurityException(
        'security_state_corrupt',
        'Encrypted security state failed validation.',
      );
    }
    if (identities.values.any((value) => value.isEmpty) &&
        identities.values.any((value) => value.isNotEmpty)) {
      throw const NazaSecurityException(
        'security_identity_missing',
        'Persisted hardened security identities are incomplete.',
      );
    }
    return _VaultSecurityMetadata(
      epoch: epoch,
      headerGeneration: headerGeneration,
      rollbackProtected: rollbackProtected,
      identities: identities,
    );
  }

  void _verifyPersistedIdentities(_VaultSecurityMetadata state) {
    final expected = <String, String>{
      'appIdentity': appIdentity,
      'modelIdentity': modelIdentity,
      'policyIdentity': policyIdentity,
      'recoveryGeneration': recoveryGeneration,
      'trustRootIdentity': trustRootIdentity,
    };
    for (final entry in expected.entries) {
      if (state.identities[entry.key] != entry.value) {
        throw NazaSecurityException(
          'security_identity_changed',
          'Persisted ${entry.key} does not match the currently verified identity.',
        );
      }
    }
  }

  _VaultSecurityMetadata _parseLegacySecurityMetadata(
    Object raw, {
    required String expectedVaultId,
  }) {
    if (raw is! Map ||
        raw['format']?.toString() != _legacySecurityStateFormat ||
        raw['vaultId']?.toString() != expectedVaultId) {
      throw const NazaSecurityException(
        'legacy_security_state_corrupt',
        'Legacy encrypted security state failed validation.',
      );
    }
    final epoch = _positiveInt(raw['epoch']);
    final headerGeneration = _positiveInt(raw['headerGeneration']);
    if (epoch == null || headerGeneration == null) {
      throw const NazaSecurityException(
        'legacy_security_state_corrupt',
        'Legacy encrypted security state is malformed.',
      );
    }
    return _VaultSecurityMetadata(
      epoch: epoch,
      headerGeneration: headerGeneration,
      rollbackProtected: false,
      identities: const <String, String>{},
    );
  }

  Future<_VaultHeaderSnapshot> _readVaultHeaderSnapshot() async {
    final databaseFile = await vault.databaseFile();
    final headerFile = File(
      '${databaseFile.parent.path}/naza_one_vault.header.json',
    );
    if (!await headerFile.exists()) {
      throw const NazaSecurityException(
        'header_missing',
        'Vault header is missing.',
      );
    }
    try {
      final decoded = jsonDecode(await headerFile.readAsString());
      if (decoded is! Map) throw const FormatException('header is not a map');
      final vaultId = decoded['vaultId']?.toString() ?? '';
      final generation = _positiveInt(decoded['generation']);
      if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId) ||
          generation == null) {
        throw const FormatException('invalid header identity');
      }
      return _VaultHeaderSnapshot(
        vaultId: vaultId,
        headerGeneration: generation,
      );
    } catch (error) {
      throw NazaSecurityException(
        'header_invalid',
        'Vault header security metadata is invalid: $error',
      );
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

  Future<void> _auditEvent(
    String event,
    Map<String, Object?> data,
  ) async {
    final audit = _audit;
    final epoch = _securityEpoch;
    if (audit == null || epoch == null) return;
    await audit.append(
      event: event,
      data: data,
      securityEpoch: epoch,
    );
  }

  void _destroySessionSecurity() {
    _kernel?.destroy();
    _audit?.destroy();
    _rollbackGuard?.destroy();
    _kernel = null;
    _audit = null;
    _rollbackGuard = null;
    _vaultId = null;
    _securityEpoch = null;
  }

  NazaSecurityKernel _requireKernel() {
    final kernel = _kernel;
    if (kernel == null || !vault.isUnlocked) {
      throw const NazaSecurityException(
        'security_session_missing',
        'Hardened security session is not active.',
      );
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
    if (namespace.startsWith('security.')) {
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

  const _VaultHeaderSnapshot({
    required this.vaultId,
    required this.headerGeneration,
  });
}

final class _VaultSecurityMetadata {
  final int epoch;
  final int headerGeneration;
  final bool rollbackProtected;
  final Map<String, String> identities;

  const _VaultSecurityMetadata({
    required this.epoch,
    required this.headerGeneration,
    required this.rollbackProtected,
    required this.identities,
  });
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
