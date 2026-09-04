// Authenticated persistence adapter for the MSL monotonic protocol counter.
import 'dart:async';

import 'metameric_surface_lattice.dart';
import 'secure_database.dart';

final class MslSecureDatabaseCounterStore implements MslMonotonicCounterStore {
  MslSecureDatabaseCounterStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  final NazaSecureDatabase _database;
  Future<void> _tail = Future<void>.value();

  @override
  Future<int> current({
    required String deviceId,
    required String profileId,
  }) async {
    final value = await _database.readJson(
      'msl-pq',
      _recordKey(deviceId, profileId),
    );
    if (value == null) return 0;
    if (value is! int || value < 0) {
      throw const MslProtocolException(
        'counter_rollback_detected',
        'The encrypted MSL counter is malformed.',
      );
    }
    return value;
  }

  @override
  Future<int> advance({
    required String deviceId,
    required String profileId,
    required int expectedCurrent,
  }) {
    final completer = Completer<int>();
    _tail = _tail.then((_) async {
      try {
        final key = _recordKey(deviceId, profileId);
        final value = await _database.readJson('msl-pq', key);
        final current = value ?? 0;
        if (current is! int || current < 0 || current != expectedCurrent) {
          throw const MslProtocolException(
            'counter_rollback_detected',
            'The encrypted MSL counter is missing, malformed, or rolled back.',
          );
        }
        final next = current + 1;
        await _database.writeJson('msl-pq', key, next);
        final readBack = await _database.readJson('msl-pq', key);
        if (readBack != next) {
          throw const MslProtocolException(
            'counter_commit_invalid',
            'The encrypted MSL counter failed read-back verification.',
          );
        }
        completer.complete(next);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static String _recordKey(String deviceId, String profileId) {
    // IDs have already passed the protocol's restricted identifier grammar.
    return 'counter.v2.$deviceId.$profileId';
  }
}
