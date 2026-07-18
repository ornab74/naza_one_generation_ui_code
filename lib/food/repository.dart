import 'dart:async';

import 'package:flutter/foundation.dart';

import '../security/secure_database.dart';
import 'config.dart';
import 'models.dart';

const String _foodEntryKeyPrefix = 'entry:';

/// Durable storage boundary for the food surfaces.
///
/// Implementations keep newest captures first and apply [limit] after
/// [offset]. A null limit returns every retained entry after the offset.
abstract interface class FoodRepository {
  ValueNotifier<int> get revision;

  Future<void> saveFridgeLog(FridgeLog log);

  Future<List<FridgeLog>> listFridgeLogs({int? limit, int offset = 0});

  Future<FridgeLog?> getFridgeLog(String id);

  Future<void> deleteFridgeLog(String id);

  Future<void> clearFridgeLogs();

  Future<void> saveBakeLog(BakeLog log);

  Future<List<BakeLog>> listBakeLogs({int? limit, int offset = 0});

  Future<BakeLog?> getBakeLog(String id);

  Future<void> deleteBakeLog(String id);

  Future<void> clearBakeLogs();

  Future<void> clearAll();
}

/// Stores food captures as independently authenticated records in the
/// encrypted SQLite vault. The encrypted index contains only bounded IDs and
/// capture times, allowing history pages to load without decrypting every
/// retained image first.
final class EncryptedFoodRepository implements FoodRepository {
  EncryptedFoodRepository({
    NazaSecureDatabase? database,
    this.fridgeLimit = FoodVisionConfig.fridgeLogLimit,
    this.bakeLimit = FoodVisionConfig.bakeLogLimit,
  }) : _database = database ?? NazaSecureDatabase.instance {
    _validateRetentionLimit(fridgeLimit, 'fridgeLimit');
    _validateRetentionLimit(bakeLimit, 'bakeLimit');
  }

  static const String _fridgeKind = 'fridge';
  static const String _bakeKind = 'bake';

  final NazaSecureDatabase _database;
  final int fridgeLimit;
  final int bakeLimit;
  Future<void> _tail = Future<void>.value();

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<void> saveFridgeLog(FridgeLog log) {
    _validateFridgeLog(log);
    return _enqueue(() async {
      final index = await _readIndex(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        kind: _fridgeKind,
      );
      final mutation = index.withEntry(
        id: log.id,
        capturedAt: log.capturedAt,
        maximumEntries: fridgeLimit,
      );
      await _database.importRecords(<NazaVaultRecordKey, Object?>{
        NazaVaultRecordKey(FoodVisionConfig.fridgeNamespace, _entryKey(log.id)):
            log.toJson(),
        const NazaVaultRecordKey(
          FoodVisionConfig.fridgeNamespace,
          FoodVisionConfig.fridgeIndexKey,
        ): mutation.index
            .toJson(),
      });
      revision.value++;
      await _deletePruned(
        namespace: FoodVisionConfig.fridgeNamespace,
        ids: mutation.prunedIds,
      );
    });
  }

  @override
  Future<List<FridgeLog>> listFridgeLogs({int? limit, int offset = 0}) {
    _validatePage(limit: limit, offset: offset);
    return _enqueue(() async {
      final index = await _readIndex(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        kind: _fridgeKind,
      );
      final result = <FridgeLog>[];
      for (final entry in index.entries.skip(offset)) {
        if (limit != null && result.length >= limit) break;
        final log = await _readFridgeLog(entry.id);
        if (log != null) result.add(log);
      }
      return List<FridgeLog>.unmodifiable(result);
    });
  }

  @override
  Future<FridgeLog?> getFridgeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() => _readFridgeLog(validId));
  }

  @override
  Future<void> deleteFridgeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async {
      await _database.delete(
        FoodVisionConfig.fridgeNamespace,
        _entryKey(validId),
      );
      final index = await _readIndex(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        kind: _fridgeKind,
      );
      await _writeIndex(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        index: index.without(validId),
      );
      revision.value++;
    });
  }

  @override
  Future<void> clearFridgeLogs() {
    return _enqueue(() async {
      await _clearNamespace(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        kind: _fridgeKind,
      );
      revision.value++;
    });
  }

  @override
  Future<void> saveBakeLog(BakeLog log) {
    _validateBakeLog(log);
    return _enqueue(() async {
      final index = await _readIndex(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        kind: _bakeKind,
      );
      final mutation = index.withEntry(
        id: log.id,
        capturedAt: log.capturedAt,
        maximumEntries: bakeLimit,
      );
      await _database.importRecords(<NazaVaultRecordKey, Object?>{
        NazaVaultRecordKey(FoodVisionConfig.bakeNamespace, _entryKey(log.id)):
            log.toJson(),
        const NazaVaultRecordKey(
          FoodVisionConfig.bakeNamespace,
          FoodVisionConfig.bakeIndexKey,
        ): mutation.index
            .toJson(),
      });
      revision.value++;
      await _deletePruned(
        namespace: FoodVisionConfig.bakeNamespace,
        ids: mutation.prunedIds,
      );
    });
  }

  @override
  Future<List<BakeLog>> listBakeLogs({int? limit, int offset = 0}) {
    _validatePage(limit: limit, offset: offset);
    return _enqueue(() async {
      final index = await _readIndex(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        kind: _bakeKind,
      );
      final result = <BakeLog>[];
      for (final entry in index.entries.skip(offset)) {
        if (limit != null && result.length >= limit) break;
        final log = await _readBakeLog(entry.id);
        if (log != null) result.add(log);
      }
      return List<BakeLog>.unmodifiable(result);
    });
  }

  @override
  Future<BakeLog?> getBakeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() => _readBakeLog(validId));
  }

  @override
  Future<void> deleteBakeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async {
      await _database.delete(
        FoodVisionConfig.bakeNamespace,
        _entryKey(validId),
      );
      final index = await _readIndex(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        kind: _bakeKind,
      );
      await _writeIndex(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        index: index.without(validId),
      );
      revision.value++;
    });
  }

  @override
  Future<void> clearBakeLogs() {
    return _enqueue(() async {
      await _clearNamespace(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        kind: _bakeKind,
      );
      revision.value++;
    });
  }

  @override
  Future<void> clearAll() {
    return _enqueue(() async {
      await _clearNamespace(
        namespace: FoodVisionConfig.fridgeNamespace,
        indexKey: FoodVisionConfig.fridgeIndexKey,
        kind: _fridgeKind,
      );
      await _clearNamespace(
        namespace: FoodVisionConfig.bakeNamespace,
        indexKey: FoodVisionConfig.bakeIndexKey,
        kind: _bakeKind,
      );
      revision.value++;
    });
  }

  Future<FridgeLog?> _readFridgeLog(String id) async {
    final raw = await _database.readJson(
      FoodVisionConfig.fridgeNamespace,
      _entryKey(id),
    );
    if (raw == null) return null;
    final json = _recordMap(
      raw,
      expectedFormat: 'naza-fridge-log-v1',
      expectedId: id,
      label: 'fridge log',
    );
    try {
      return FridgeLog.fromJson(json);
    } catch (error) {
      throw NazaVaultException(
        'invalid_food_fridge_log',
        'An encrypted fridge log is malformed.',
        error,
      );
    }
  }

  Future<BakeLog?> _readBakeLog(String id) async {
    final raw = await _database.readJson(
      FoodVisionConfig.bakeNamespace,
      _entryKey(id),
    );
    if (raw == null) return null;
    final json = _recordMap(
      raw,
      expectedFormat: 'naza-bake-log-v1',
      expectedId: id,
      label: 'bake log',
    );
    try {
      return BakeLog.fromJson(json);
    } catch (error) {
      throw NazaVaultException(
        'invalid_food_bake_log',
        'An encrypted bake log is malformed.',
        error,
      );
    }
  }

  Future<_FoodIndex> _readIndex({
    required String namespace,
    required String indexKey,
    required String kind,
  }) async {
    final raw = await _database.readJson(namespace, indexKey);
    if (raw == null) return _FoodIndex.empty(kind);
    try {
      return _FoodIndex.fromJson(raw, expectedKind: kind);
    } catch (error) {
      throw NazaVaultException(
        'invalid_food_index',
        'The encrypted $kind history index is malformed.',
        error,
      );
    }
  }

  Future<void> _writeIndex({
    required String namespace,
    required String indexKey,
    required _FoodIndex index,
  }) {
    return _database.writeJson(namespace, indexKey, index.toJson());
  }

  Future<void> _clearNamespace({
    required String namespace,
    required String indexKey,
    required String kind,
  }) async {
    final index = await _readIndex(
      namespace: namespace,
      indexKey: indexKey,
      kind: kind,
    );
    for (final entry in index.entries) {
      await _database.delete(namespace, _entryKey(entry.id));
    }
    await _database.delete(namespace, indexKey);
  }

  Future<void> _deletePruned({
    required String namespace,
    required Iterable<String> ids,
  }) async {
    for (final id in ids) {
      await _database.delete(namespace, _entryKey(id));
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

/// Deterministic repository used by widget tests and previews. It mirrors the
/// encrypted implementation's ordering, page semantics, and retention caps.
final class MemoryFoodRepository implements FoodRepository {
  MemoryFoodRepository({
    Iterable<FridgeLog> fridgeLogs = const <FridgeLog>[],
    Iterable<BakeLog> bakeLogs = const <BakeLog>[],
    this.fridgeLimit = FoodVisionConfig.fridgeLogLimit,
    this.bakeLimit = FoodVisionConfig.bakeLogLimit,
  }) {
    _validateRetentionLimit(fridgeLimit, 'fridgeLimit');
    _validateRetentionLimit(bakeLimit, 'bakeLimit');
    for (final log in fridgeLogs) {
      _validateFridgeLog(log);
      _fridgeLogs[log.id] = log;
    }
    for (final log in bakeLogs) {
      _validateBakeLog(log);
      _bakeLogs[log.id] = log;
    }
    _pruneFridge();
    _pruneBake();
  }

  final int fridgeLimit;
  final int bakeLimit;
  final Map<String, FridgeLog> _fridgeLogs = <String, FridgeLog>{};
  final Map<String, BakeLog> _bakeLogs = <String, BakeLog>{};
  Future<void> _tail = Future<void>.value();

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<void> saveFridgeLog(FridgeLog log) {
    _validateFridgeLog(log);
    return _enqueue(() async {
      _fridgeLogs[log.id] = log;
      _pruneFridge();
      revision.value++;
    });
  }

  @override
  Future<List<FridgeLog>> listFridgeLogs({int? limit, int offset = 0}) {
    _validatePage(limit: limit, offset: offset);
    return _enqueue(() async {
      final ordered = _orderedFridge().skip(offset);
      final selected = limit == null ? ordered : ordered.take(limit);
      return List<FridgeLog>.unmodifiable(selected);
    });
  }

  @override
  Future<FridgeLog?> getFridgeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async => _fridgeLogs[validId]);
  }

  @override
  Future<void> deleteFridgeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async {
      _fridgeLogs.remove(validId);
      revision.value++;
    });
  }

  @override
  Future<void> clearFridgeLogs() {
    return _enqueue(() async {
      _fridgeLogs.clear();
      revision.value++;
    });
  }

  @override
  Future<void> saveBakeLog(BakeLog log) {
    _validateBakeLog(log);
    return _enqueue(() async {
      _bakeLogs[log.id] = log;
      _pruneBake();
      revision.value++;
    });
  }

  @override
  Future<List<BakeLog>> listBakeLogs({int? limit, int offset = 0}) {
    _validatePage(limit: limit, offset: offset);
    return _enqueue(() async {
      final ordered = _orderedBake().skip(offset);
      final selected = limit == null ? ordered : ordered.take(limit);
      return List<BakeLog>.unmodifiable(selected);
    });
  }

  @override
  Future<BakeLog?> getBakeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async => _bakeLogs[validId]);
  }

  @override
  Future<void> deleteBakeLog(String id) {
    final validId = _validateId(id);
    return _enqueue(() async {
      _bakeLogs.remove(validId);
      revision.value++;
    });
  }

  @override
  Future<void> clearBakeLogs() {
    return _enqueue(() async {
      _bakeLogs.clear();
      revision.value++;
    });
  }

  @override
  Future<void> clearAll() {
    return _enqueue(() async {
      _fridgeLogs.clear();
      _bakeLogs.clear();
      revision.value++;
    });
  }

  List<FridgeLog> _orderedFridge() {
    return _fridgeLogs.values.toList(growable: false)
      ..sort((a, b) => _compareCapture(a.capturedAt, a.id, b.capturedAt, b.id));
  }

  List<BakeLog> _orderedBake() {
    return _bakeLogs.values.toList(growable: false)
      ..sort((a, b) => _compareCapture(a.capturedAt, a.id, b.capturedAt, b.id));
  }

  void _pruneFridge() {
    final ordered = _orderedFridge();
    for (final log in ordered.skip(fridgeLimit)) {
      _fridgeLogs.remove(log.id);
    }
  }

  void _pruneBake() {
    final ordered = _orderedBake();
    for (final log in ordered.skip(bakeLimit)) {
      _bakeLogs.remove(log.id);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

final class _FoodIndexEntry {
  final String id;
  final DateTime capturedAt;

  const _FoodIndexEntry({required this.id, required this.capturedAt});

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };

  factory _FoodIndexEntry.fromJson(Map<Object?, Object?> json) {
    final id = _validateId(json['id']?.toString() ?? '');
    final capturedAt = DateTime.tryParse(json['captured_at']?.toString() ?? '');
    if (capturedAt == null) {
      throw const FormatException('A food index timestamp is invalid.');
    }
    return _FoodIndexEntry(id: id, capturedAt: capturedAt);
  }
}

final class _FoodIndex {
  final String kind;
  final List<_FoodIndexEntry> entries;

  const _FoodIndex({required this.kind, required this.entries});

  factory _FoodIndex.empty(String kind) {
    return _FoodIndex(kind: kind, entries: const <_FoodIndexEntry>[]);
  }

  factory _FoodIndex.fromJson(Object? raw, {required String expectedKind}) {
    if (raw is! Map) {
      throw const FormatException('A food index must be a JSON object.');
    }
    if (raw['format'] != 'naza-food-log-index-v1' ||
        raw['kind'] != expectedKind ||
        raw['entries'] is! List) {
      throw const FormatException('A food index has an unsupported format.');
    }
    final byId = <String, _FoodIndexEntry>{};
    for (final item in raw['entries'] as List) {
      if (item is! Map) {
        throw const FormatException('A food index entry is malformed.');
      }
      final entry = _FoodIndexEntry.fromJson(item);
      final existing = byId[entry.id];
      if (existing == null || entry.capturedAt.isAfter(existing.capturedAt)) {
        byId[entry.id] = entry;
      }
    }
    final entries = byId.values.toList(growable: false)..sort(_compareEntries);
    return _FoodIndex(
      kind: expectedKind,
      entries: List<_FoodIndexEntry>.unmodifiable(entries),
    );
  }

  _FoodIndexMutation withEntry({
    required String id,
    required DateTime capturedAt,
    required int maximumEntries,
  }) {
    final byId = <String, _FoodIndexEntry>{
      for (final entry in entries)
        if (entry.id != id) entry.id: entry,
      id: _FoodIndexEntry(id: id, capturedAt: capturedAt),
    };
    final sorted = byId.values.toList(growable: false)..sort(_compareEntries);
    final kept = sorted.take(maximumEntries).toList(growable: false);
    final pruned = sorted
        .skip(maximumEntries)
        .map((entry) => entry.id)
        .toList(growable: false);
    return _FoodIndexMutation(
      index: _FoodIndex(
        kind: kind,
        entries: List<_FoodIndexEntry>.unmodifiable(kept),
      ),
      prunedIds: pruned,
    );
  }

  _FoodIndex without(String id) {
    return _FoodIndex(
      kind: kind,
      entries: List<_FoodIndexEntry>.unmodifiable(
        entries.where((entry) => entry.id != id),
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-food-log-index-v1',
    'kind': kind,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };
}

final class _FoodIndexMutation {
  final _FoodIndex index;
  final List<String> prunedIds;

  const _FoodIndexMutation({required this.index, required this.prunedIds});
}

Map<String, Object?> _recordMap(
  Object? raw, {
  required String expectedFormat,
  required String expectedId,
  required String label,
}) {
  if (raw is! Map ||
      raw['format'] != expectedFormat ||
      raw['id']?.toString() != expectedId) {
    throw NazaVaultException(
      'invalid_food_record',
      'The encrypted $label has an invalid identity or format.',
    );
  }
  return <String, Object?>{
    for (final entry in raw.entries) entry.key.toString(): entry.value,
  };
}

String _entryKey(String id) => '$_foodEntryKeyPrefix${_validateId(id)}';

String _validateId(String id) {
  if (id.isEmpty ||
      id != id.trim() ||
      id.length > 180 ||
      id.contains('\u0000') ||
      id.contains('\u001f')) {
    throw ArgumentError.value(id, 'id', 'Invalid food log ID.');
  }
  return id;
}

void _validateRetentionLimit(int value, String name) {
  if (value < 1 || value > 10000) {
    throw ArgumentError.value(value, name, 'Use a limit from 1 to 10000.');
  }
}

void _validatePage({required int? limit, required int offset}) {
  if (offset < 0) {
    throw ArgumentError.value(offset, 'offset', 'Offset cannot be negative.');
  }
  if (limit != null && limit < 0) {
    throw ArgumentError.value(limit, 'limit', 'Limit cannot be negative.');
  }
}

void _validateImage(FoodVisionImage image) {
  if (image.bytes.isEmpty ||
      image.bytes.length > FoodVisionConfig.visionMaxImageBytes) {
    throw ArgumentError.value(
      image.bytes.length,
      'image.bytes',
      'A normalized food image must contain 1-${FoodVisionConfig.visionMaxImageBytes} bytes.',
    );
  }
  if (image.width < 1 ||
      image.height < 1 ||
      image.width > FoodVisionConfig.visionMaxImageDimension ||
      image.height > FoodVisionConfig.visionMaxImageDimension) {
    throw ArgumentError(
      'A normalized food image must fit within '
      '${FoodVisionConfig.visionMaxImageDimension} × '
      '${FoodVisionConfig.visionMaxImageDimension} pixels.',
    );
  }
}

void _validateFridgeLog(FridgeLog log) {
  _validateId(log.id);
  _validateImage(log.image);
}

void _validateBakeLog(BakeLog log) {
  _validateId(log.id);
  _validateImage(log.image);
}

int _compareEntries(_FoodIndexEntry a, _FoodIndexEntry b) {
  return _compareCapture(a.capturedAt, a.id, b.capturedAt, b.id);
}

int _compareCapture(DateTime aTime, String aId, DateTime bTime, String bId) {
  final byTime = bTime.compareTo(aTime);
  return byTime != 0 ? byTime : bId.compareTo(aId);
}
