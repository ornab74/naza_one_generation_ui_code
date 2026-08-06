import 'dart:async';

import 'package:flutter/foundation.dart';

import '../security/secure_database.dart';
import 'models.dart';

abstract interface class PantryRepository {
  ValueNotifier<int> get revision;

  Future<PantryState> loadState();

  Future<void> saveState(PantryState state);

  Future<List<PantryOrderPlan>> listOrderPlans();

  Future<void> saveOrderPlan(PantryOrderPlan plan);

  Future<void> clear();
}

final class EncryptedPantryRepository implements PantryRepository {
  EncryptedPantryRepository({
    NazaSecureDatabase? database,
    this.orderHistoryLimit = 50,
  }) : _database = database ?? NazaSecureDatabase.instance {
    if (orderHistoryLimit < 1 || orderHistoryLimit > 500) {
      throw ArgumentError.value(orderHistoryLimit, 'orderHistoryLimit');
    }
  }

  static const String _namespace = 'pantry-autopilot-v1';
  static const String _stateKey = 'state';
  static const String _ordersKey = 'orders';

  final NazaSecureDatabase _database;
  final int orderHistoryLimit;
  Future<void> _tail = Future<void>.value();

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<PantryState> loadState() {
    return _enqueue(() async {
      final raw = await _database.readJson(_namespace, _stateKey);
      if (raw == null) return const PantryState();
      try {
        return PantryState.fromJson(_map(raw));
      } catch (error) {
        throw NazaVaultException(
          'invalid_pantry_state',
          'The encrypted pantry state is malformed.',
          error,
        );
      }
    });
  }

  @override
  Future<void> saveState(PantryState state) {
    _validateState(state);
    return _enqueue(() async {
      await _database.writeJson(_namespace, _stateKey, state.toJson());
      revision.value++;
    });
  }

  @override
  Future<List<PantryOrderPlan>> listOrderPlans() {
    return _enqueue(() async {
      final raw = await _database.readJson(_namespace, _ordersKey);
      if (raw == null) return const <PantryOrderPlan>[];
      try {
        final plans =
            _mapList(_map(raw)['plans'])
                .take(orderHistoryLimit)
                .map(PantryOrderPlan.fromJson)
                .toList(growable: false)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return List<PantryOrderPlan>.unmodifiable(plans);
      } catch (error) {
        throw NazaVaultException(
          'invalid_pantry_orders',
          'The encrypted pantry order history is malformed.',
          error,
        );
      }
    });
  }

  @override
  Future<void> saveOrderPlan(PantryOrderPlan plan) {
    _validatePlan(plan);
    return _enqueue(() async {
      final raw = await _database.readJson(_namespace, _ordersKey);
      final existing = raw == null
          ? <PantryOrderPlan>[]
          : _mapList(
              _map(raw)['plans'],
            ).map(PantryOrderPlan.fromJson).toList(growable: true);
      existing.removeWhere((entry) => entry.id == plan.id);
      existing.add(plan);
      existing.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final retained = existing.take(orderHistoryLimit).toList(growable: false);
      await _database.writeJson(_namespace, _ordersKey, <String, Object?>{
        'format': 'naza-pantry-orders-v1',
        'plans': retained
            .map((entry) => entry.toJson())
            .toList(growable: false),
      });
      revision.value++;
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      await _database.delete(_namespace, _stateKey);
      await _database.delete(_namespace, _ordersKey);
      revision.value++;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

final class MemoryPantryRepository implements PantryRepository {
  MemoryPantryRepository({
    PantryState state = const PantryState(),
    Iterable<PantryOrderPlan> plans = const <PantryOrderPlan>[],
    this.orderHistoryLimit = 50,
  }) : _state = state,
       _plans = <PantryOrderPlan>[...plans] {
    if (orderHistoryLimit < 1 || orderHistoryLimit > 500) {
      throw ArgumentError.value(orderHistoryLimit, 'orderHistoryLimit');
    }
    _validateState(state);
    for (final plan in _plans) {
      _validatePlan(plan);
    }
    _prune();
  }

  PantryState _state;
  final List<PantryOrderPlan> _plans;
  final int orderHistoryLimit;
  Future<void> _tail = Future<void>.value();

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<PantryState> loadState() => _enqueue(() async => _state);

  @override
  Future<void> saveState(PantryState state) {
    _validateState(state);
    return _enqueue(() async {
      _state = state;
      revision.value++;
    });
  }

  @override
  Future<List<PantryOrderPlan>> listOrderPlans() {
    return _enqueue(() async {
      final ordered = <PantryOrderPlan>[..._plans]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List<PantryOrderPlan>.unmodifiable(ordered);
    });
  }

  @override
  Future<void> saveOrderPlan(PantryOrderPlan plan) {
    _validatePlan(plan);
    return _enqueue(() async {
      _plans.removeWhere((entry) => entry.id == plan.id);
      _plans.add(plan);
      _prune();
      revision.value++;
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      _state = const PantryState();
      _plans.clear();
      revision.value++;
    });
  }

  void _prune() {
    _plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_plans.length > orderHistoryLimit) {
      _plans.removeRange(orderHistoryLimit, _plans.length);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

void _validateState(PantryState state) {
  if (state.items.length > 400) {
    throw ArgumentError.value(state.items.length, 'state.items.length');
  }
  final ids = <String>{};
  for (final item in state.items) {
    if (item.id.trim().isEmpty || !ids.add(item.id)) {
      throw ArgumentError('Pantry item IDs must be non-empty and unique.');
    }
    if (!item.quantity.isFinite ||
        !item.targetQuantity.isFinite ||
        !item.reorderPoint.isFinite ||
        !item.dailyUse.isFinite ||
        !item.estimatedUnitPrice.isFinite ||
        item.quantity < 0 ||
        item.targetQuantity < 0 ||
        item.reorderPoint < 0 ||
        item.dailyUse < 0 ||
        item.estimatedUnitPrice < 0) {
      throw ArgumentError('Pantry quantities and prices must be finite.');
    }
  }
}

void _validatePlan(PantryOrderPlan plan) {
  if (plan.id.trim().isEmpty || plan.lines.length > 200) {
    throw ArgumentError('The pantry order plan is outside storage limits.');
  }
  if (!plan.budgetCap.isFinite || plan.budgetCap < 0) {
    throw ArgumentError.value(plan.budgetCap, 'plan.budgetCap');
  }
  for (final line in plan.lines) {
    if (!line.quantity.isFinite ||
        !line.estimatedUnitPrice.isFinite ||
        line.quantity < 0 ||
        line.estimatedUnitPrice < 0) {
      throw ArgumentError('Order quantities and prices must be finite.');
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map<String, Object?>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! Iterable) return const <Map<String, Object?>>[];
  return value.whereType<Map>().map(_map).toList(growable: false);
}
