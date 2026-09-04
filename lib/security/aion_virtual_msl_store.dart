import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'aion_virtual_msl.dart';
import 'metameric_surface_lattice.dart';
import 'secure_database.dart';

final class AionSecureDatabaseCheckpointStore implements AionCheckpointStore {
  AionSecureDatabaseCheckpointStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;
  final NazaSecureDatabase _database;
  Future<void> _tail = Future<void>.value();

  String _key(AionProfile profile) => 'checkpoint.v1.${profile.name}';

  @override
  Future<AionCheckpoint?> load(AionProfile profile) async {
    final raw = await _database.readJson('aion-msl', _key(profile));
    if (raw == null) return null;
    if (raw is! Map ||
        raw['suite'] != AionVirtualMslEngine.suiteVersion ||
        raw['epoch'] is! int ||
        raw['ratchet'] is! String ||
        raw['merkle'] is! String) {
      throw const MslProtocolException(
        'aion_checkpoint_invalid',
        'The encrypted AION checkpoint is malformed.',
      );
    }
    try {
      final ratchet = base64Decode(raw['ratchet'] as String);
      final merkle = base64Decode(raw['merkle'] as String);
      if (ratchet.length != 64 ||
          merkle.length != 32 ||
          (raw['epoch'] as int) < 1)
        throw const FormatException();
      return AionCheckpoint(
        suiteVersion: raw['suite'] as int,
        epoch: raw['epoch'] as int,
        ratchet: Uint8List.fromList(ratchet),
        merkleRoot: Uint8List.fromList(merkle),
      );
    } catch (_) {
      throw const MslProtocolException(
        'aion_checkpoint_invalid',
        'The encrypted AION checkpoint encoding is invalid.',
      );
    }
  }

  @override
  Future<void> compareAndCommit({
    required AionProfile profile,
    required int expectedEpoch,
    required AionCheckpoint next,
  }) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        final current = await load(profile);
        if ((current?.epoch ?? 0) != expectedEpoch ||
            next.epoch != expectedEpoch + 1 ||
            next.suiteVersion != AionVirtualMslEngine.suiteVersion ||
            next.ratchet.length != 64 ||
            next.merkleRoot.length != 32) {
          throw const MslProtocolException(
            'aion_checkpoint_fork',
            'The encrypted AION checkpoint compare-and-commit failed.',
          );
        }
        final value = <String, Object>{
          'suite': AionVirtualMslEngine.suiteVersion,
          'epoch': next.epoch,
          'ratchet': base64Encode(next.ratchet),
          'merkle': base64Encode(next.merkleRoot),
        };
        await _database.writeJson('aion-msl', _key(profile), value);
        final readBack = await load(profile);
        if (readBack == null || readBack.epoch != next.epoch)
          throw const MslProtocolException(
            'aion_checkpoint_commit_invalid',
            'AION checkpoint read-back failed.',
          );
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}
