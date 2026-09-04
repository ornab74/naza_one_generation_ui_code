// LLM-CONTEXT:BEGIN
// FILE: lib/memory/chromatic_spatial_repository.dart
// ROLE: Owns encrypted event-segment persistence for physical-world observations.
// DOMAIN: chromatic-spatial-memory
// SECURITY-INVARIANT: Persist only bounded compact observations in the unlocked authenticated vault; raw sensor media is never accepted.
// CHANGE-GUARD: Preserve append-only observation semantics, atomic manifest changes, strict format validation, and recoverable compaction.
// DOCS: See /docs/llm-context-schema.md and /docs/chromatic-spatial-memory.md.
// LLM-CONTEXT:END
import 'dart:convert';

import '../security/secure_database.dart';
import 'chromatic_spatial_models.dart';

/// Loaded durable state. Observation segments are the authority; all runtime
/// indexes and probability surfaces are deterministic, rebuildable views.
final class CsdRepositoryLoad {
  const CsdRepositoryLoad({
    required this.observations,
    required this.generation,
    required this.eventSegmentCount,
    required this.checkpointShardCount,
  });

  final List<CsdObservation> observations;
  final int generation;
  final int eventSegmentCount;
  final int checkpointShardCount;
}

abstract interface class CsdObservationRepository {
  Future<CsdRepositoryLoad> load();

  /// Appends a bounded batch. Callers must remove already-known observation
  /// IDs first; duplicate IDs in durable state are treated as corruption.
  Future<void> append(List<CsdObservation> observations);

  /// Rewrites the same immutable observations into checkpoint shards and
  /// atomically switches the manifest. This compacts storage, not history.
  Future<void> compact(List<CsdObservation> observations);

  Future<void> clear();
}

/// Encrypted, segmented, event-sourced repository built on [NazaSecureDatabase].
///
/// The manifest and every referenced segment are independently authenticated
/// vault records. Compaction first writes a complete new generation and then
/// atomically points the manifest at it. Previous keys remain listed as
/// `retired` until cleanup succeeds, so clear/recovery can still find them.
final class CsdEncryptedObservationRepository
    implements CsdObservationRepository {
  CsdEncryptedObservationRepository({
    NazaSecureDatabase? database,
    this.segmentCapacity = 96,
    this.maxObservations = 20000,
    this.maxBatchSize = 512,
  }) : _database = database ?? NazaSecureDatabase.instance {
    if (segmentCapacity < 8 || segmentCapacity > 256) {
      throw ArgumentError.value(segmentCapacity, 'segmentCapacity');
    }
    if (maxObservations < segmentCapacity || maxObservations > 100000) {
      throw ArgumentError.value(maxObservations, 'maxObservations');
    }
    if (maxBatchSize < 1 || maxBatchSize > 1024) {
      throw ArgumentError.value(maxBatchSize, 'maxBatchSize');
    }
  }

  static const String namespace = 'naza-csd-v1';
  static const String _manifestKey = 'manifest';
  static const String _manifestFormat = 'naza-csd-manifest-v1';
  static const String _shardFormat = 'naza-csd-observation-shard-v1';
  static const int _version = 1;
  static const int _maxManifestKeys = 4096;
  static const int _maxCompactMetadataBytes = 8192;

  final NazaSecureDatabase _database;
  final int segmentCapacity;
  final int maxObservations;
  final int maxBatchSize;
  Future<void> _tail = Future<void>.value();

  @override
  Future<CsdRepositoryLoad> load() => _enqueue(_loadNow);

  @override
  Future<void> append(List<CsdObservation> observations) {
    final frozen = List<CsdObservation>.unmodifiable(observations);
    if (frozen.length > maxBatchSize) {
      throw ArgumentError.value(
        frozen.length,
        'observations',
        'A single CSD append may contain at most $maxBatchSize observations.',
      );
    }
    for (final observation in frozen) {
      _assertCompactObservation(observation);
    }
    return _enqueue(() => _appendNow(frozen));
  }

  @override
  Future<void> compact(List<CsdObservation> observations) {
    final frozen = List<CsdObservation>.unmodifiable(observations);
    if (frozen.length > maxObservations) {
      throw ArgumentError.value(frozen.length, 'observations');
    }
    final ids = <String>{};
    for (final observation in frozen) {
      _assertCompactObservation(observation);
      if (!ids.add(observation.id)) {
        throw ArgumentError.value(
          observation.id,
          'observations',
          'Checkpoint input contains a duplicate observation ID.',
        );
      }
    }
    return _enqueue(() => _compactNow(frozen));
  }

  @override
  Future<void> clear() => _enqueue(() async {
    final manifest = await _readManifest();
    if (manifest != null) {
      final keys = <String>{
        ...manifest.checkpointKeys,
        ...manifest.eventSegments.map((segment) => segment.key),
        ...manifest.retiredKeys,
      };
      for (final key in keys) {
        await _database.delete(namespace, key);
      }
    }
    await _database.delete(namespace, _manifestKey);
  });

  Future<CsdRepositoryLoad> _loadNow() async {
    var manifest = await _readManifest();
    if (manifest == null) {
      return const CsdRepositoryLoad(
        observations: <CsdObservation>[],
        generation: 0,
        eventSegmentCount: 0,
        checkpointShardCount: 0,
      );
    }

    final observations = <CsdObservation>[];
    final ids = <String>{};
    for (var i = 0; i < manifest.checkpointKeys.length; i++) {
      final shard = await _readShard(
        manifest.checkpointKeys[i],
        expectedKind: _CsdShardKind.checkpoint,
        expectedGeneration: manifest.generation,
        expectedSequence: i,
      );
      _appendValidated(shard, observations, ids);
    }
    for (final descriptor in manifest.eventSegments) {
      final shard = await _readShard(
        descriptor.key,
        expectedKind: _CsdShardKind.event,
        expectedGeneration: manifest.generation,
        expectedSequence: descriptor.sequence,
      );
      if (shard.length != descriptor.count) {
        throw const NazaVaultException(
          'invalid_csd_segment',
          'An encrypted spatial-memory segment count does not match its manifest.',
        );
      }
      _appendValidated(shard, observations, ids);
    }
    if (observations.length != manifest.totalObservations ||
        observations.length > maxObservations) {
      throw const NazaVaultException(
        'invalid_csd_manifest',
        'The encrypted spatial-memory manifest has an invalid observation count.',
      );
    }

    if (manifest.retiredKeys.isNotEmpty) {
      manifest = await _cleanupRetired(manifest);
    }
    return CsdRepositoryLoad(
      observations: List<CsdObservation>.unmodifiable(observations),
      generation: manifest.generation,
      eventSegmentCount: manifest.eventSegments.length,
      checkpointShardCount: manifest.checkpointKeys.length,
    );
  }

  Future<void> _appendNow(List<CsdObservation> observations) async {
    if (observations.isEmpty) return;
    var manifest = await _readManifest() ?? _CsdManifest.empty();
    if (manifest.retiredKeys.isNotEmpty) {
      manifest = await _cleanupRetired(manifest);
    }
    if (manifest.totalObservations + observations.length > maxObservations) {
      throw const NazaVaultException(
        'csd_capacity',
        'Chromatic spatial memory reached its configured observation limit.',
      );
    }

    final pending = observations.toList(growable: true);
    final segments = manifest.eventSegments.toList(growable: true);
    final writes = <NazaVaultRecordKey, Object?>{};
    if (segments.isNotEmpty && segments.last.count < segmentCapacity) {
      final last = segments.removeLast();
      final existing = await _readShard(
        last.key,
        expectedKind: _CsdShardKind.event,
        expectedGeneration: manifest.generation,
        expectedSequence: last.sequence,
      );
      if (existing.length != last.count) {
        throw const NazaVaultException(
          'invalid_csd_segment',
          'The active spatial-memory segment is inconsistent.',
        );
      }
      final room = segmentCapacity - existing.length;
      final take = room < pending.length ? room : pending.length;
      final combined = <CsdObservation>[...existing, ...pending.take(take)];
      pending.removeRange(0, take);
      writes[NazaVaultRecordKey(namespace, last.key)] = _shardJson(
        kind: _CsdShardKind.event,
        generation: manifest.generation,
        sequence: last.sequence,
        observations: combined,
      );
      segments.add(last.copyWith(count: combined.length));
    }

    var nextSequence = manifest.nextEventSequence;
    while (pending.isNotEmpty) {
      final take = pending.length < segmentCapacity
          ? pending.length
          : segmentCapacity;
      final part = pending.take(take).toList(growable: false);
      pending.removeRange(0, take);
      final key = _eventKey(manifest.generation, nextSequence);
      writes[NazaVaultRecordKey(namespace, key)] = _shardJson(
        kind: _CsdShardKind.event,
        generation: manifest.generation,
        sequence: nextSequence,
        observations: part,
      );
      segments.add(
        _CsdSegmentDescriptor(
          key: key,
          sequence: nextSequence,
          count: part.length,
        ),
      );
      nextSequence++;
    }

    final next = manifest.copyWith(
      eventSegments: segments,
      nextEventSequence: nextSequence,
      totalObservations: manifest.totalObservations + observations.length,
      updatedAt: DateTime.now().toUtc(),
    );
    writes[const NazaVaultRecordKey(namespace, _manifestKey)] = next.toJson();
    await _database.importRecords(writes);
  }

  Future<void> _compactNow(List<CsdObservation> observations) async {
    final previous = await _readManifest() ?? _CsdManifest.empty();
    final generation = previous.generation + 1;
    final writes = <NazaVaultRecordKey, Object?>{};
    final checkpointKeys = <String>[];
    var sequence = 0;
    for (var offset = 0; offset < observations.length;) {
      final end = (offset + segmentCapacity).clamp(0, observations.length);
      final shard = observations.sublist(offset, end);
      final key = _checkpointKey(generation, sequence);
      checkpointKeys.add(key);
      writes[NazaVaultRecordKey(namespace, key)] = _shardJson(
        kind: _CsdShardKind.checkpoint,
        generation: generation,
        sequence: sequence,
        observations: shard,
      );
      sequence++;
      offset = end;
    }

    final retired = <String>{
      ...previous.checkpointKeys,
      ...previous.eventSegments.map((segment) => segment.key),
      ...previous.retiredKeys,
    }..removeWhere(checkpointKeys.contains);
    final next = _CsdManifest(
      generation: generation,
      checkpointKeys: checkpointKeys,
      eventSegments: const <_CsdSegmentDescriptor>[],
      retiredKeys: retired.toList(growable: false),
      nextEventSequence: 0,
      totalObservations: observations.length,
      updatedAt: DateTime.now().toUtc(),
    );
    writes[const NazaVaultRecordKey(namespace, _manifestKey)] = next.toJson();
    await _database.importRecords(writes);
    await _cleanupRetired(next);
  }

  Future<_CsdManifest> _cleanupRetired(_CsdManifest manifest) async {
    for (final key in manifest.retiredKeys) {
      await _database.delete(namespace, key);
    }
    final clean = manifest.copyWith(retiredKeys: const <String>[]);
    await _database.writeJson(namespace, _manifestKey, clean.toJson());
    return clean;
  }

  Future<_CsdManifest?> _readManifest() async {
    final raw = await _database.readJson(namespace, _manifestKey);
    if (raw == null) return null;
    if (raw is! Map) {
      throw const NazaVaultException(
        'invalid_csd_manifest',
        'The encrypted spatial-memory manifest is malformed.',
      );
    }
    try {
      return _CsdManifest.fromJson(Map<String, Object?>.from(raw));
    } catch (error) {
      throw NazaVaultException(
        'invalid_csd_manifest',
        'The encrypted spatial-memory manifest is malformed.',
        error,
      );
    }
  }

  Future<List<CsdObservation>> _readShard(
    String key, {
    required _CsdShardKind expectedKind,
    required int expectedGeneration,
    required int expectedSequence,
  }) async {
    final raw = await _database.readJson(namespace, key);
    if (raw is! Map) {
      throw const NazaVaultException(
        'invalid_csd_segment',
        'An encrypted spatial-memory segment is missing or malformed.',
      );
    }
    try {
      final map = Map<String, Object?>.from(raw);
      if (map['format'] != _shardFormat ||
          map['version'] != _version ||
          map['kind'] != expectedKind.name ||
          map['generation'] != expectedGeneration ||
          map['sequence'] != expectedSequence) {
        throw const FormatException('CSD shard identity mismatch.');
      }
      final rows = map['observations'];
      if (rows is! List || rows.length > segmentCapacity) {
        throw const FormatException('Invalid CSD shard rows.');
      }
      return rows
          .map((row) {
            if (row is! Map)
              throw const FormatException('Invalid observation row.');
            final observation = CsdObservation.fromJson(
              Map<String, Object?>.from(row),
            );
            _assertCompactObservation(observation);
            return observation;
          })
          .toList(growable: false);
    } catch (error) {
      throw NazaVaultException(
        'invalid_csd_segment',
        'An encrypted spatial-memory segment is malformed.',
        error,
      );
    }
  }

  void _appendValidated(
    List<CsdObservation> shard,
    List<CsdObservation> output,
    Set<String> ids,
  ) {
    for (final observation in shard) {
      if (!ids.add(observation.id)) {
        throw const NazaVaultException(
          'duplicate_csd_observation',
          'Encrypted spatial memory contains a duplicate observation ID.',
        );
      }
      output.add(observation);
    }
  }

  void _assertCompactObservation(CsdObservation observation) {
    final metadata = jsonEncode(observation.metadata);
    if (utf8.encode(metadata).length > _maxCompactMetadataBytes) {
      throw ArgumentError.value(
        observation.id,
        'observation',
        'CSD metadata exceeds the compact-record limit.',
      );
    }
    for (final key in observation.metadata.keys) {
      final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      final looksLikeRawMedia =
          normalized.contains('rawimage') ||
          normalized.contains('imagebytes') ||
          normalized.contains('pixeldata') ||
          normalized.contains('photobytes') ||
          normalized.contains('videobytes') ||
          normalized.contains('audiobytes');
      if (looksLikeRawMedia) {
        throw ArgumentError.value(
          key,
          'observation.metadata',
          'Raw sensor media is not permitted in CSD compact observations.',
        );
      }
    }
  }

  Map<String, Object?> _shardJson({
    required _CsdShardKind kind,
    required int generation,
    required int sequence,
    required List<CsdObservation> observations,
  }) => <String, Object?>{
    'format': _shardFormat,
    'version': _version,
    'kind': kind.name,
    'generation': generation,
    'sequence': sequence,
    'count': observations.length,
    'observations': observations
        .map((observation) => observation.toJson())
        .toList(growable: false),
  };

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }

  static String _eventKey(int generation, int sequence) =>
      'event:g$generation:s${sequence.toString().padLeft(8, '0')}';

  static String _checkpointKey(int generation, int sequence) =>
      'checkpoint:g$generation:p${sequence.toString().padLeft(8, '0')}';
}

enum _CsdShardKind { event, checkpoint }

final class _CsdSegmentDescriptor {
  const _CsdSegmentDescriptor({
    required this.key,
    required this.sequence,
    required this.count,
  });

  final String key;
  final int sequence;
  final int count;

  _CsdSegmentDescriptor copyWith({int? count}) => _CsdSegmentDescriptor(
    key: key,
    sequence: sequence,
    count: count ?? this.count,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'sequence': sequence,
    'count': count,
  };

  factory _CsdSegmentDescriptor.fromJson(Map<String, Object?> json) {
    final key = json['key'];
    final sequence = json['sequence'];
    final count = json['count'];
    if (key is! String ||
        !RegExp(r'^event:g\d+:s\d{8}$').hasMatch(key) ||
        sequence is! int ||
        sequence < 0 ||
        count is! int ||
        count < 1 ||
        count > 256) {
      throw const FormatException('Invalid CSD segment descriptor.');
    }
    return _CsdSegmentDescriptor(key: key, sequence: sequence, count: count);
  }
}

final class _CsdManifest {
  const _CsdManifest({
    required this.generation,
    required this.checkpointKeys,
    required this.eventSegments,
    required this.retiredKeys,
    required this.nextEventSequence,
    required this.totalObservations,
    required this.updatedAt,
  });

  factory _CsdManifest.empty() => _CsdManifest(
    generation: 0,
    checkpointKeys: const <String>[],
    eventSegments: const <_CsdSegmentDescriptor>[],
    retiredKeys: const <String>[],
    nextEventSequence: 0,
    totalObservations: 0,
    updatedAt: DateTime.now().toUtc(),
  );

  final int generation;
  final List<String> checkpointKeys;
  final List<_CsdSegmentDescriptor> eventSegments;
  final List<String> retiredKeys;
  final int nextEventSequence;
  final int totalObservations;
  final DateTime updatedAt;

  _CsdManifest copyWith({
    List<_CsdSegmentDescriptor>? eventSegments,
    List<String>? retiredKeys,
    int? nextEventSequence,
    int? totalObservations,
    DateTime? updatedAt,
  }) => _CsdManifest(
    generation: generation,
    checkpointKeys: checkpointKeys,
    eventSegments: eventSegments ?? this.eventSegments,
    retiredKeys: retiredKeys ?? this.retiredKeys,
    nextEventSequence: nextEventSequence ?? this.nextEventSequence,
    totalObservations: totalObservations ?? this.totalObservations,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'format': CsdEncryptedObservationRepository._manifestFormat,
    'version': CsdEncryptedObservationRepository._version,
    'generation': generation,
    'checkpointKeys': checkpointKeys,
    'eventSegments': eventSegments
        .map((segment) => segment.toJson())
        .toList(growable: false),
    'retiredKeys': retiredKeys,
    'nextEventSequence': nextEventSequence,
    'totalObservations': totalObservations,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory _CsdManifest.fromJson(Map<String, Object?> json) {
    if (json['format'] != CsdEncryptedObservationRepository._manifestFormat ||
        json['version'] != CsdEncryptedObservationRepository._version) {
      throw const FormatException('Unsupported CSD manifest.');
    }
    final generation = json['generation'];
    final checkpointRaw = json['checkpointKeys'];
    final segmentRaw = json['eventSegments'];
    final retiredRaw = json['retiredKeys'];
    final nextSequence = json['nextEventSequence'];
    final total = json['totalObservations'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (generation is! int ||
        generation < 0 ||
        nextSequence is! int ||
        nextSequence < 0 ||
        total is! int ||
        total < 0 ||
        updatedAt == null ||
        checkpointRaw is! List ||
        segmentRaw is! List ||
        retiredRaw is! List) {
      throw const FormatException('Invalid CSD manifest fields.');
    }
    if (checkpointRaw.length + segmentRaw.length + retiredRaw.length >
        CsdEncryptedObservationRepository._maxManifestKeys) {
      throw const FormatException('CSD manifest contains too many keys.');
    }
    final checkpoints = checkpointRaw
        .map((key) {
          if (key is! String ||
              !RegExp(r'^checkpoint:g\d+:p\d{8}$').hasMatch(key)) {
            throw const FormatException('Invalid CSD checkpoint key.');
          }
          return key;
        })
        .toList(growable: false);
    final segments = segmentRaw
        .map((segment) {
          if (segment is! Map) {
            throw const FormatException('Invalid CSD event segment.');
          }
          return _CsdSegmentDescriptor.fromJson(
            Map<String, Object?>.from(segment),
          );
        })
        .toList(growable: false);
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].sequence != i ||
          !segments[i].key.startsWith('event:g$generation:')) {
        throw const FormatException('CSD event sequence is not contiguous.');
      }
    }
    final retired = retiredRaw
        .map((key) {
          if (key is! String || key.isEmpty || key.length > 120) {
            throw const FormatException('Invalid retired CSD key.');
          }
          return key;
        })
        .toList(growable: false);
    if (checkpoints.any((key) => !key.startsWith('checkpoint:g$generation:')) ||
        nextSequence != segments.length) {
      throw const FormatException('CSD manifest generation mismatch.');
    }
    return _CsdManifest(
      generation: generation,
      checkpointKeys: List<String>.unmodifiable(checkpoints),
      eventSegments: List<_CsdSegmentDescriptor>.unmodifiable(segments),
      retiredKeys: List<String>.unmodifiable(retired),
      nextEventSequence: nextSequence,
      totalObservations: total,
      updatedAt: updatedAt.toUtc(),
    );
  }
}
