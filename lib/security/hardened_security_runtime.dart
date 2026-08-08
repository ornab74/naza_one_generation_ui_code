import 'dart:typed_data';

import 'hardened_vault_controller.dart';
import 'key_guardian.dart';
import 'persistent_audit.dart';
import 'post_quantum_export.dart';
import 'pq_trust_policy.dart';
import 'secure_database.dart';
import 'security_identity.dart';
import 'security_kernel.dart';

final class NazaHardenedSecurityRuntime {
  NazaHardenedSecurityRuntime({
    required this.vault,
    required this.secureStore,
    required this.guardian,
    required this.appIdentity,
    required this.trustRootIdentity,
  });

  final NazaSecureDatabase vault;
  final NazaDeviceKeyStore secureStore;
  final NazaKeyGuardian guardian;
  final String appIdentity;
  final String trustRootIdentity;

  NazaHardenedVaultController? _controller;
  NazaPersistentForwardAudit? _persistentAudit;
  NazaKeyHandle? _capabilityRoot;
  NazaKeyHandle? _auditRoot;
  NazaVerifiedModelIdentity? _activeModel;
  Uint8List? _sessionBinding;

  bool get isReady =>
      _controller?.isReady == true && _persistentAudit?.initialized == true;

  NazaHardenedVaultController get controller {
    final value = _controller;
    if (value == null || !isReady) {
      throw const NazaSecurityException(
        'runtime_not_ready',
        'Hardened security runtime is not initialized.',
      );
    }
    return value;
  }

  int? get securityEpoch => _controller?.securityEpoch;
  int? get auditSequence => _persistentAudit?.sequence;
  String? get auditTip => _persistentAudit?.tip;

  Future<void> create({
    required String password,
    required NazaVerifiedModelIdentity model,
    required NazaPostQuantumRecoveryState recovery,
    NazaPqTrustPolicy? trustPolicy,
    bool passwordRequired = true,
    Map<NazaVaultRecordKey, Object?> initialRecords = const {},
  }) async {
    await model.reverifyArtifacts();
    final identities = await const NazaSecurityIdentityDeriver().derive(
      model: model,
      recovery: recovery,
      trustPolicy: trustPolicy ?? NazaPqTrustPolicy.maximum(),
    );
    final hardened = _newController(identities);
    await hardened.create(
      password: password,
      passwordRequired: passwordRequired,
      initialRecords: initialRecords,
    );
    try {
      _activeModel = model;
      _controller = hardened;
      await _initializeRuntimeSecurity(identities);
      await _appendPersistent('runtime-created', <String, Object?>{
        'modelIdentity': identities.modelIdentity,
        'recoveryIdentity': identities.recoveryIdentity,
        'trustPolicyIdentity': identities.trustPolicyIdentity,
      });
    } catch (_) {
      await hardened.lock();
      _destroySessionState();
      rethrow;
    }
  }

  Future<void> unlock({
    required String password,
    required NazaVerifiedModelIdentity model,
    required NazaPostQuantumRecoveryState recovery,
    NazaPqTrustPolicy? trustPolicy,
  }) async {
    await model.reverifyArtifacts();
    final identities = await const NazaSecurityIdentityDeriver().derive(
      model: model,
      recovery: recovery,
      trustPolicy: trustPolicy ?? NazaPqTrustPolicy.maximum(),
    );
    final hardened = _newController(identities);
    await hardened.unlock(password);
    try {
      _activeModel = model;
      _controller = hardened;
      await _initializeRuntimeSecurity(identities);
      await _appendPersistent('runtime-unlocked', <String, Object?>{
        'method': 'password',
        'modelIdentity': identities.modelIdentity,
        'recoveryIdentity': identities.recoveryIdentity,
      });
    } catch (_) {
      await hardened.lock();
      _destroySessionState();
      rethrow;
    }
  }

  Future<void> lock() async {
    if (isReady) {
      await _appendPersistent('runtime-locking', const <String, Object?>{});
    }
    _persistentAudit?.destroy();
    _persistentAudit = null;
    _activeModel = null;
    _zero(_sessionBinding);
    _sessionBinding = null;
    final hardened = _controller;
    _controller = null;
    if (hardened != null) {
      await hardened.lock();
    } else if (vault.isUnlocked) {
      await vault.lock();
    }
  }

  /// Call immediately before the model worker opens/uses the artifact. The
  /// production loader's own attestation checks remain complementary; this is
  /// the hardened security runtime's independent trust gate.
  Future<void> assertModelStillTrusted() async {
    final model = _activeModel;
    if (model == null || !isReady) {
      throw const NazaSecurityException(
        'model_trust_unavailable',
        'No active byte-verified model identity is bound to this runtime.',
      );
    }
    await model.reverifyArtifacts();
  }

  Future<NazaCapabilityLease> authorizeWithPassword({
    required String password,
    required NazaPrivilegedAction action,
    String resource = 'vault',
  }) async {
    await assertModelStillTrusted();
    final lease = await controller.authorizeWithPassword(
      password: password,
      action: action,
      resource: resource,
    );
    await _appendPersistent('runtime-capability-issued', <String, Object?>{
      'action': action.name,
      'resource': resource,
    });
    return lease;
  }

  Future<Map<NazaVaultRecordKey, Object?>> exportRecordsAuthorized(
    NazaCapabilityLease lease,
  ) async {
    await assertModelStillTrusted();
    final records = await controller.exportRecordsAuthorized(lease);
    records.removeWhere((record, _) => record.namespace.startsWith('security.'));
    await _appendPersistent('runtime-vault-exported', <String, Object?>{
      'recordCount': records.length,
    });
    return records;
  }

  Future<void> rotateDataKeyAuthorized(NazaCapabilityLease lease) async {
    await assertModelStillTrusted();
    await controller.rotateDataKeyAuthorized(lease);
    await _appendPersistent(
      'runtime-data-key-rotated',
      const <String, Object?>{},
    );
  }

  Future<void> verifyPersistentAudit({int maxEntries = 256}) async {
    final audit = _persistentAudit;
    if (audit == null || !audit.initialized) {
      throw const NazaSecurityException(
        'audit_not_ready',
        'Persistent audit is not initialized.',
      );
    }
    await audit.verifyRecent(maxEntries: maxEntries);
  }

  NazaHardenedVaultController _newController(
    NazaSecurityIdentitySnapshot identities,
  ) {
    return NazaHardenedVaultController(
      vault: vault,
      secureStore: secureStore,
      keyGuardian: guardian,
      appIdentity: appIdentity,
      modelIdentity: identities.modelIdentity,
      policyIdentity: identities.trustPolicyIdentity,
      recoveryGeneration: identities.recoveryIdentity,
      trustRootIdentity: trustRootIdentity,
    );
  }

  Future<void> _initializeRuntimeSecurity(
    NazaSecurityIdentitySnapshot identities,
  ) async {
    final state = _controller?.securityState;
    if (state == null) {
      throw const NazaSecurityException(
        'security_state_missing',
        'Controller did not expose an active security state.',
      );
    }

    _capabilityRoot = await guardian.ensureRoot(
      vaultId: state.vaultId,
      purpose: NazaGuardianPurpose.capabilityRoot,
    );
    _auditRoot = await guardian.ensureRoot(
      vaultId: state.vaultId,
      purpose: NazaGuardianPurpose.auditRoot,
    );
    if (_capabilityRoot!.exportable || _auditRoot!.exportable) {
      throw const NazaSecurityException(
        'guardian_exportable_root',
        'Hardened runtime roots must be represented by non-exportable handles.',
      );
    }

    final derived = await guardian.deriveEphemeralSecret(
      handle: _capabilityRoot!,
      label: 'runtime-session-binding',
      context: <String, Object?>{
        'epoch': state.epoch,
        'modelIdentity': identities.modelIdentity,
        'recoveryIdentity': identities.recoveryIdentity,
        'trustPolicyIdentity': identities.trustPolicyIdentity,
      },
    );
    _zero(_sessionBinding);
    _sessionBinding = derived;

    final checkpointKey = await guardian.deriveEphemeralSecret(
      handle: _auditRoot!,
      label: 'persistent-audit-checkpoint',
      context: <String, Object?>{
        'vaultId': state.vaultId,
        'format': 'naza-audit-checkpoint-v2',
      },
    );
    try {
      final audit = NazaPersistentForwardAudit(
        vault: vault,
        secureStore: secureStore,
        vaultId: state.vaultId,
        checkpointKey: checkpointKey,
      );
      await audit.initialize();
      await audit.verifyRecent();
      _persistentAudit?.destroy();
      _persistentAudit = audit;
    } finally {
      _zero(checkpointKey);
    }
  }

  Future<void> _appendPersistent(
    String event,
    Map<String, Object?> data,
  ) async {
    final audit = _persistentAudit;
    final epoch = _controller?.securityEpoch;
    if (audit == null || epoch == null) {
      throw const NazaSecurityException(
        'audit_not_ready',
        'Persistent audit is not initialized.',
      );
    }
    await audit.append(
      event: event,
      data: <String, Object?>{
        ...data,
        'guardianCapabilityProtection':
            _capabilityRoot?.protection.name ?? '',
        'guardianAuditProtection': _auditRoot?.protection.name ?? '',
      },
      securityEpoch: epoch,
    );
  }

  void _destroySessionState() {
    _persistentAudit?.destroy();
    _persistentAudit = null;
    _activeModel = null;
    _zero(_sessionBinding);
    _sessionBinding = null;
    _controller = null;
  }
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
