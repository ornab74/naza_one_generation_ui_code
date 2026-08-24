// LLM-CONTEXT:BEGIN
// FILE: lib/agentic/collaboration_queue.dart
// ROLE: Bounded MMO-coding collaboration pools, edit claims, and encrypted
// agent-to-agent handoff envelopes.
// DOMAIN: agentic-coding
// SECURITY-INVARIANT: Queue records never contain source payloads, plaintext
// messages, credentials, private keys, cookies, or arbitrary commands. They
// contain references to separately encrypted CID/key material only.
// CHANGE-GUARD: Relative paths only, bounded dependency fan-out, immutable
// base fingerprints, explicit claims/receipts, and strict public projections.
// LLM-CONTEXT:END
import 'package:flutter/foundation.dart';

import '../security/secure_database.dart';

const String nazaCollaborationHybridSuite =
    'ML-KEM-1024+X25519+ML-DSA-87+HKDF-SHA512+AES-256-GCM';

enum NazaCollaborationPoolState { active, paused, archived }

extension NazaCollaborationPoolStateX on NazaCollaborationPoolState {
  String get label => switch (this) {
    NazaCollaborationPoolState.active => 'Active',
    NazaCollaborationPoolState.paused => 'Paused',
    NazaCollaborationPoolState.archived => 'Archived',
  };
}

enum NazaQueuedEditState {
  queued,
  claimed,
  working,
  awaitingReview,
  merged,
  blocked,
  rejected,
  cancelled,
}

extension NazaQueuedEditStateX on NazaQueuedEditState {
  String get label => switch (this) {
    NazaQueuedEditState.queued => 'Queued',
    NazaQueuedEditState.claimed => 'Claimed',
    NazaQueuedEditState.working => 'Working',
    NazaQueuedEditState.awaitingReview => 'Awaiting review',
    NazaQueuedEditState.merged => 'Merged',
    NazaQueuedEditState.blocked => 'Blocked',
    NazaQueuedEditState.rejected => 'Rejected',
    NazaQueuedEditState.cancelled => 'Cancelled',
  };
}

enum NazaAgentEnvelopeKind { proposal, dependency, handoff, conflict, review }

@immutable
final class NazaCollaborationPool {
  const NazaCollaborationPool({
    required this.id,
    required this.name,
    required this.workspaceFingerprint,
    required this.createdAt,
    this.peerGroup = 'local-only',
    this.state = NazaCollaborationPoolState.active,
    this.maxConcurrentEdits = 4,
    this.requiresSignedReceipts = true,
    this.bondSuite = nazaCollaborationHybridSuite,
  });

  final String id;
  final String name;
  final String workspaceFingerprint;
  final String peerGroup;
  final NazaCollaborationPoolState state;
  final int maxConcurrentEdits;
  final bool requiresSignedReceipts;
  final String bondSuite;
  final DateTime createdAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(id)) errors.add('Invalid collaboration pool ID.');
    if (!_validLabel(name, 100)) errors.add('Pool name is invalid.');
    if (!_fingerprint(workspaceFingerprint)) {
      errors.add('Workspace fingerprint must be an immutable digest.');
    }
    if (!_validLabel(peerGroup, 120)) errors.add('Peer group is invalid.');
    if (maxConcurrentEdits < 1 || maxConcurrentEdits > 64) {
      errors.add('Concurrent edit limit must be 1–64.');
    }
    if (bondSuite != nazaCollaborationHybridSuite) {
      errors.add('Unsupported collaboration bond suite.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'workspaceFingerprint': workspaceFingerprint,
    'peerGroup': peerGroup,
    'state': state.name,
    'maxConcurrentEdits': maxConcurrentEdits,
    'requiresSignedReceipts': requiresSignedReceipts,
    'bondSuite': bondSuite,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static NazaCollaborationPool? fromJson(Object? value) {
    if (value is! Map) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final state = _enumByName<NazaCollaborationPoolState>(
      value['state']?.toString(),
      NazaCollaborationPoolState.values,
    );
    final pool = NazaCollaborationPool(
      id: value['id']?.toString() ?? '',
      name: value['name']?.toString() ?? '',
      workspaceFingerprint: value['workspaceFingerprint']?.toString() ?? '',
      peerGroup: value['peerGroup']?.toString() ?? 'local-only',
      state: state ?? NazaCollaborationPoolState.active,
      maxConcurrentEdits: value['maxConcurrentEdits'] is num
          ? (value['maxConcurrentEdits'] as num).round()
          : 4,
      requiresSignedReceipts: value['requiresSignedReceipts'] != false,
      bondSuite: value['bondSuite']?.toString() ?? '',
      createdAt: createdAt?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    return createdAt == null || pool.validate().isNotEmpty ? null : pool;
  }
}

@immutable
final class NazaQueuedEdit {
  const NazaQueuedEdit({
    required this.id,
    required this.poolId,
    required this.relativePath,
    required this.goal,
    required this.baseFingerprint,
    required this.createdAt,
    this.sector = 'whole-file',
    this.dependencies = const <String>[],
    this.priority = 50,
    this.state = NazaQueuedEditState.queued,
    this.claimedByAgent,
    this.executionNodeId,
    this.encryptedContextCid,
    this.receiptCid,
  });

  final String id;
  final String poolId;
  final String relativePath;
  final String sector;
  final String goal;
  final String baseFingerprint;
  final List<String> dependencies;
  final int priority;
  final NazaQueuedEditState state;
  final String? claimedByAgent;
  final String? executionNodeId;
  final String? encryptedContextCid;
  final String? receiptCid;
  final DateTime createdAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(id) || !_validId(poolId))
      errors.add('Invalid edit identity.');
    if (!_relativePath(relativePath)) {
      errors.add('Edit path must be relative and traversal-safe.');
    }
    if (!_validLabel(sector, 80)) errors.add('Edit sector is invalid.');
    if (!_validLabel(goal, 500)) errors.add('Edit goal is invalid.');
    if (!_fingerprint(baseFingerprint))
      errors.add('Base fingerprint is invalid.');
    if (dependencies.length > 32 || dependencies.any((id) => !_validId(id))) {
      errors.add('Edit dependencies are invalid or too numerous.');
    }
    if (priority < 0 || priority > 100)
      errors.add('Edit priority must be 0–100.');
    if (encryptedContextCid != null && !_validCid(encryptedContextCid!)) {
      errors.add('Encrypted context CID is invalid.');
    }
    if (receiptCid != null && !_validCid(receiptCid!)) {
      errors.add('Receipt CID is invalid.');
    }
    return List<String>.unmodifiable(errors);
  }

  NazaQueuedEdit copyWith({
    NazaQueuedEditState? state,
    String? claimedByAgent,
    String? executionNodeId,
    String? encryptedContextCid,
    String? receiptCid,
  }) {
    return NazaQueuedEdit(
      id: id,
      poolId: poolId,
      relativePath: relativePath,
      sector: sector,
      goal: goal,
      baseFingerprint: baseFingerprint,
      dependencies: dependencies,
      priority: priority,
      state: state ?? this.state,
      claimedByAgent: claimedByAgent ?? this.claimedByAgent,
      executionNodeId: executionNodeId ?? this.executionNodeId,
      encryptedContextCid: encryptedContextCid ?? this.encryptedContextCid,
      receiptCid: receiptCid ?? this.receiptCid,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'poolId': poolId,
    'relativePath': relativePath,
    'sector': sector,
    'goal': goal,
    'baseFingerprint': baseFingerprint,
    'dependencies': dependencies,
    'priority': priority,
    'state': state.name,
    if (claimedByAgent != null) 'claimedByAgent': claimedByAgent,
    if (executionNodeId != null) 'executionNodeId': executionNodeId,
    if (encryptedContextCid != null) 'encryptedContextCid': encryptedContextCid,
    if (receiptCid != null) 'receiptCid': receiptCid,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static NazaQueuedEdit? fromJson(Object? value) {
    if (value is! Map) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final state = _enumByName<NazaQueuedEditState>(
      value['state']?.toString(),
      NazaQueuedEditState.values,
    );
    if (createdAt == null || state == null) return null;
    final edit = NazaQueuedEdit(
      id: value['id']?.toString() ?? '',
      poolId: value['poolId']?.toString() ?? '',
      relativePath: value['relativePath']?.toString() ?? '',
      sector: value['sector']?.toString() ?? 'whole-file',
      goal: value['goal']?.toString() ?? '',
      baseFingerprint: value['baseFingerprint']?.toString() ?? '',
      dependencies: _strings(value['dependencies'], 32),
      priority: value['priority'] is num
          ? (value['priority'] as num).round()
          : 50,
      state: state,
      claimedByAgent: _nullable(value['claimedByAgent']?.toString()),
      executionNodeId: _nullable(value['executionNodeId']?.toString()),
      encryptedContextCid: _nullable(value['encryptedContextCid']?.toString()),
      receiptCid: _nullable(value['receiptCid']?.toString()),
      createdAt: createdAt.toUtc(),
    );
    return edit.validate().isEmpty ? edit : null;
  }
}

/// Only a ciphertext CID and public-key references cross this boundary. The
/// actual envelope encryption/signature belongs to the node adapter using the
/// configured ML-KEM/X25519/ML-DSA hybrid key service.
@immutable
final class NazaAgentEnvelope {
  const NazaAgentEnvelope({
    required this.id,
    required this.poolId,
    required this.kind,
    required this.senderBondKeyId,
    required this.ciphertextCid,
    required this.signatureKeyId,
    required this.createdAt,
    this.recipientBondKeyId,
    this.editId,
    this.sequence = 0,
  });

  final String id;
  final String poolId;
  final NazaAgentEnvelopeKind kind;
  final String senderBondKeyId;
  final String? recipientBondKeyId;
  final String ciphertextCid;
  final String signatureKeyId;
  final String? editId;
  final int sequence;
  final DateTime createdAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(id) || !_validId(poolId))
      errors.add('Invalid envelope identity.');
    if (!_validKeyReference(senderBondKeyId) ||
        !_validKeyReference(signatureKeyId)) {
      errors.add('Sender and signature key references are required.');
    }
    if (recipientBondKeyId != null &&
        !_validKeyReference(recipientBondKeyId!)) {
      errors.add('Recipient bond key reference is invalid.');
    }
    if (!_validCid(ciphertextCid))
      errors.add('Envelope ciphertext CID is invalid.');
    if (editId != null && !_validId(editId!))
      errors.add('Envelope edit reference is invalid.');
    if (sequence < 0 || sequence > 1000000)
      errors.add('Envelope sequence is invalid.');
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'poolId': poolId,
    'kind': kind.name,
    'senderBondKeyId': senderBondKeyId,
    if (recipientBondKeyId != null) 'recipientBondKeyId': recipientBondKeyId,
    'ciphertextCid': ciphertextCid,
    'signatureKeyId': signatureKeyId,
    if (editId != null) 'editId': editId,
    'sequence': sequence,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static NazaAgentEnvelope? fromJson(Object? value) {
    if (value is! Map) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final kind = _enumByName<NazaAgentEnvelopeKind>(
      value['kind']?.toString(),
      NazaAgentEnvelopeKind.values,
    );
    if (createdAt == null || kind == null) return null;
    final envelope = NazaAgentEnvelope(
      id: value['id']?.toString() ?? '',
      poolId: value['poolId']?.toString() ?? '',
      kind: kind,
      senderBondKeyId: value['senderBondKeyId']?.toString() ?? '',
      recipientBondKeyId: _nullable(value['recipientBondKeyId']?.toString()),
      ciphertextCid: value['ciphertextCid']?.toString() ?? '',
      signatureKeyId: value['signatureKeyId']?.toString() ?? '',
      editId: _nullable(value['editId']?.toString()),
      sequence: value['sequence'] is num
          ? (value['sequence'] as num).round()
          : 0,
      createdAt: createdAt.toUtc(),
    );
    return envelope.validate().isEmpty ? envelope : null;
  }
}

final class NazaCollaborationQueueStore {
  NazaCollaborationQueueStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String _namespace = 'agentic-collaboration';
  static const String _poolsKey = 'pools-v1';
  static const String _editsKey = 'edits-v1';
  static const String _envelopesKey = 'envelopes-v1';
  static const int maxPools = 24;
  static const int maxEdits = 500;
  static const int maxEnvelopes = 1000;

  final NazaSecureDatabase _database;

  Future<List<NazaCollaborationPool>> loadPools() async {
    final raw = await _database.readJson(_namespace, _poolsKey);
    if (raw is! List) return const <NazaCollaborationPool>[];
    return List<NazaCollaborationPool>.unmodifiable(
      raw
          .map(NazaCollaborationPool.fromJson)
          .whereType<NazaCollaborationPool>()
          .take(maxPools),
    );
  }

  Future<List<NazaQueuedEdit>> loadEdits(String poolId) async {
    final raw = await _database.readJson(_namespace, _editsKey);
    if (raw is! List) return const <NazaQueuedEdit>[];
    return List<NazaQueuedEdit>.unmodifiable(
      raw
          .map(NazaQueuedEdit.fromJson)
          .whereType<NazaQueuedEdit>()
          .where((edit) => edit.poolId == poolId)
          .take(maxEdits),
    );
  }

  Future<List<NazaAgentEnvelope>> loadEnvelopes(String poolId) async {
    final raw = await _database.readJson(_namespace, _envelopesKey);
    if (raw is! List) return const <NazaAgentEnvelope>[];
    return List<NazaAgentEnvelope>.unmodifiable(
      raw
          .map(NazaAgentEnvelope.fromJson)
          .whereType<NazaAgentEnvelope>()
          .where((envelope) => envelope.poolId == poolId)
          .take(maxEnvelopes),
    );
  }

  Future<void> savePool(NazaCollaborationPool pool) async {
    _throwIfInvalid(pool.validate());
    final current = await loadPools();
    final next = <NazaCollaborationPool>[
      ...current.where((item) => item.id != pool.id),
      pool,
    ];
    final bounded = next.length <= maxPools
        ? next
        : next.sublist(next.length - maxPools);
    await _database.writeJson(
      _namespace,
      _poolsKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<void> enqueueEdit(NazaQueuedEdit edit) async {
    _throwIfInvalid(edit.validate());
    final pools = await loadPools();
    if (!pools.any(
      (pool) =>
          pool.id == edit.poolId &&
          pool.state == NazaCollaborationPoolState.active,
    )) {
      throw const FormatException('Edit pool is not active.');
    }
    final raw = await _database.readJson(_namespace, _editsKey);
    final current = raw is List
        ? raw.map(NazaQueuedEdit.fromJson).whereType<NazaQueuedEdit>().toList()
        : <NazaQueuedEdit>[];
    final next = <NazaQueuedEdit>[
      ...current.where((item) => item.id != edit.id),
      edit,
    ];
    final bounded = next.length <= maxEdits
        ? next
        : next.sublist(next.length - maxEdits);
    await _database.writeJson(
      _namespace,
      _editsKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<void> postEnvelope(NazaAgentEnvelope envelope) async {
    _throwIfInvalid(envelope.validate());
    final pools = await loadPools();
    if (!pools.any(
      (pool) =>
          pool.id == envelope.poolId &&
          pool.state == NazaCollaborationPoolState.active,
    )) {
      throw const FormatException('Envelope pool is not active.');
    }
    final raw = await _database.readJson(_namespace, _envelopesKey);
    final current = raw is List
        ? raw
              .map(NazaAgentEnvelope.fromJson)
              .whereType<NazaAgentEnvelope>()
              .toList()
        : <NazaAgentEnvelope>[];
    final next = <NazaAgentEnvelope>[
      ...current.where((item) => item.id != envelope.id),
      envelope,
    ];
    final bounded = next.length <= maxEnvelopes
        ? next
        : next.sublist(next.length - maxEnvelopes);
    await _database.writeJson(
      _namespace,
      _envelopesKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  static void _throwIfInvalid(List<String> errors) {
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
  }
}

bool _validId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$').hasMatch(value.trim());

bool _validLabel(String value, int max) {
  final clean = value.trim();
  return clean.isNotEmpty && clean.length <= max && !clean.contains('\u0000');
}

bool _relativePath(String value) {
  final clean = value.trim().replaceAll('\\', '/');
  return clean.isNotEmpty &&
      clean.length <= 640 &&
      !clean.startsWith('/') &&
      !clean.contains('\u0000') &&
      !clean.split('/').contains('..');
}

bool _fingerprint(String value) {
  final clean = value.trim();
  return RegExp(r'^(?:sha256:)?[a-fA-F0-9]{32,128}$').hasMatch(clean);
}

bool _validCid(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 128 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(clean);
}

bool _validKeyReference(String value) {
  final clean = value.trim();
  return clean.length >= 8 &&
      clean.length <= 160 &&
      RegExp(r'^[A-Za-z0-9._:+/-]+$').hasMatch(clean);
}

String? _nullable(String? value) {
  final clean = value?.trim() ?? '';
  return clean.isEmpty
      ? null
      : clean.length <= 160
      ? clean
      : clean.substring(0, 160);
}

List<String> _strings(Object? value, int max) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .take(max),
  );
}

T? _enumByName<T extends Enum>(String? value, List<T> values) {
  if (value == null) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}
