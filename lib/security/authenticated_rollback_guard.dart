import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'security_kernel.dart';

const _rollbackFormat = 'naza-authenticated-rollback-v1';

/// Authenticated highest-seen epoch stored outside the encrypted vault.
///
/// This does not claim to be a hardware monotonic counter. It does ensure that
/// an attacker who can rewrite the counter storage but cannot use the guardian
/// root cannot lower or forge the rollback floor without detection.
final class NazaAuthenticatedRollbackGuard {
  NazaAuthenticatedRollbackGuard(
    this._store, {
    required this.storageKey,
    required List<int> authenticationKey,
  }) : _authenticationKey = Uint8List.fromList(authenticationKey) {
    if (_authenticationKey.length != 32) {
      _zero(_authenticationKey);
      throw ArgumentError.value(
        authenticationKey.length,
        'authenticationKey',
        'Rollback authentication key must be 32 bytes.',
      );
    }
  }

  final NazaDeviceCounterStore _store;
  final String storageKey;
  final Uint8List _authenticationKey;
  final Hmac _hmac = Hmac.sha256();

  Future<int> minimumEpoch() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['format'] != _rollbackFormat) {
        throw const FormatException('invalid rollback record format');
      }
      final epoch = _nonNegativeInt(decoded['epoch']);
      final mac = decoded['mac']?.toString() ?? '';
      if (epoch == null || mac.isEmpty) {
        throw const FormatException('malformed rollback record');
      }
      final expected = await _macFor(epoch);
      if (!_constantTimeTextEquals(expected, mac)) {
        throw const NazaSecurityException(
          'rollback_state_authentication',
          'Protected rollback state authentication failed.',
        );
      }
      return epoch;
    } on NazaSecurityException {
      rethrow;
    } catch (_) {
      throw const NazaSecurityException(
        'rollback_state_corrupt',
        'Protected rollback state is malformed.',
      );
    }
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
    if (epoch < 0) {
      throw ArgumentError.value(epoch, 'epoch');
    }
    final current = await minimumEpoch();
    if (epoch < current) {
      throw const NazaSecurityException(
        'epoch_rollback',
        'Rollback guard cannot move backwards.',
      );
    }
    final mac = await _macFor(epoch);
    await _store.write(
      storageKey,
      jsonEncode(<String, Object?>{
        'format': _rollbackFormat,
        'epoch': epoch,
        'mac': mac,
      }),
    );
  }

  Future<String> _macFor(int epoch) async {
    final material = utf8.encode(
      '$_rollbackFormat\u001f$storageKey\u001f$epoch',
    );
    final mac = await _hmac.calculateMac(
      material,
      secretKey: SecretKey(_authenticationKey),
    );
    return base64UrlEncode(mac.bytes).replaceAll('=', '');
  }

  void destroy() => _zero(_authenticationKey);
}

int? _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}

bool _constantTimeTextEquals(String a, String b) {
  final aa = utf8.encode(a);
  final bb = utf8.encode(b);
  var difference = aa.length ^ bb.length;
  final length = math.min(aa.length, bb.length);
  for (var index = 0; index < length; index++) {
    difference |= aa[index] ^ bb[index];
  }
  return difference == 0;
}

void _zero(List<int>? bytes) {
  if (bytes == null) return;
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
