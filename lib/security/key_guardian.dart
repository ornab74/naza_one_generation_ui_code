import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_database.dart';

const _guardianFormat = 'naza-key-guardian-v1';

enum NazaGuardianProtection {
  /// Test-only/in-memory implementations.
  volatileMemory,

  /// The root is held by the operating-system protected secret store. This
  /// raises the bar over ordinary application files but is not claimed to be a
  /// non-exportable hardware key.
  platformSecureStore,

  /// Reserved for platform implementations backed by TPM / StrongBox /
  /// Secure Enclave or another non-exportable hardware primitive.
  hardwareBacked,
}

enum NazaGuardianPurpose {
  capabilityRoot,
  auditRoot,
  ipcRoot,
  modelTrustRoot,
}

/// Opaque reference to guardian-managed root material.
///
/// Callers receive an identifier and protection metadata, never the durable
/// root key bytes themselves.
final class NazaKeyHandle {
  final String id;
  final NazaGuardianPurpose purpose;
  final NazaGuardianProtection protection;
  final bool exportable;

  const NazaKeyHandle({
    required this.id,
    required this.purpose,
    required this.protection,
    required this.exportable,
  });
}

abstract interface class NazaKeyGuardian {
  Future<NazaKeyHandle> ensureRoot({
    required String vaultId,
    required NazaGuardianPurpose purpose,
  });

  /// Derives an ephemeral, purpose-bound secret from an opaque root handle.
  /// The caller owns and must clear the returned mutable bytes as soon as the
  /// operation/session ends.
  Future<Uint8List> deriveEphemeralSecret({
    required NazaKeyHandle handle,
    required String label,
    required Map<String, Object?> context,
  });

  Future<void> revokeRoot(NazaKeyHandle handle);
}

/// Portable guardian used by the current Flutter implementation.
///
/// Durable root bytes are serialized only into [NazaDeviceKeyStore]. They are
/// loaded inside this guardian long enough to derive a short-lived child key
/// and are then overwritten on a best-effort basis. Dart cannot guarantee that
/// runtime copies never existed, so this is intentionally *not* described as
/// RAM-proof or hardware non-exportable.
final class NazaSecureStoreKeyGuardian implements NazaKeyGuardian {
  NazaSecureStoreKeyGuardian(this._store);

  final NazaDeviceKeyStore _store;
  final Hmac _hmac = Hmac.sha256();

  @override
  Future<NazaKeyHandle> ensureRoot({
    required String vaultId,
    required NazaGuardianPurpose purpose,
  }) async {
    _validateVaultId(vaultId);
    final id = '$_guardianFormat/$vaultId/${purpose.name}';
    final storageKey = _storageKey(id);
    final existing = await _store.read(storageKey);
    if (existing == null || existing.isEmpty) {
      final root = _randomBytes(32);
      try {
        await _store.write(storageKey, base64Encode(root));
      } finally {
        _zero(root);
      }
    } else {
      final decoded = _decodeRoot(existing);
      _zero(decoded);
    }
    return NazaKeyHandle(
      id: id,
      purpose: purpose,
      protection: NazaGuardianProtection.platformSecureStore,
      exportable: false,
    );
  }

  @override
  Future<Uint8List> deriveEphemeralSecret({
    required NazaKeyHandle handle,
    required String label,
    required Map<String, Object?> context,
  }) async {
    if (handle.exportable ||
        handle.protection != NazaGuardianProtection.platformSecureStore ||
        !handle.id.startsWith('$_guardianFormat/')) {
      throw const NazaKeyGuardianException(
        'invalid_handle',
        'The guardian key handle is not valid for this provider.',
      );
    }
    if (label.isEmpty || label.length > 128) {
      throw ArgumentError.value(label, 'label', 'Invalid derivation label.');
    }
    final encodedRoot = await _store.read(_storageKey(handle.id));
    if (encodedRoot == null || encodedRoot.isEmpty) {
      throw const NazaKeyGuardianException(
        'root_missing',
        'The protected guardian root is unavailable.',
      );
    }
    final root = _decodeRoot(encodedRoot);
    try {
      final transcript = utf8.encode(
        _canonicalJson(<String, Object?>{
          'format': _guardianFormat,
          'handle': handle.id,
          'label': label,
          'purpose': handle.purpose.name,
          'context': context,
        }),
      );
      final mac = await _hmac.calculateMac(
        transcript,
        secretKey: SecretKey(root),
      );
      return Uint8List.fromList(mac.bytes);
    } finally {
      _zero(root);
    }
  }

  @override
  Future<void> revokeRoot(NazaKeyHandle handle) async {
    if (!handle.id.startsWith('$_guardianFormat/')) {
      throw const NazaKeyGuardianException(
        'invalid_handle',
        'The guardian key handle is not valid for this provider.',
      );
    }
    await _store.delete(_storageKey(handle.id));
  }

  Uint8List _decodeRoot(String encoded) {
    try {
      final bytes = Uint8List.fromList(base64Decode(encoded));
      if (bytes.length != 32) {
        _zero(bytes);
        throw const FormatException('unexpected root length');
      }
      return bytes;
    } catch (error) {
      throw NazaKeyGuardianException(
        'root_corrupt',
        'Protected guardian root is malformed: $error',
      );
    }
  }

  String _storageKey(String id) =>
      'naza-guardian-${base64UrlEncode(utf8.encode(id)).replaceAll('=', '')}';
}

final class NazaKeyGuardianException implements Exception {
  final String code;
  final String message;

  const NazaKeyGuardianException(this.code, this.message);

  @override
  String toString() => 'NazaKeyGuardianException($code): $message';
}

void _validateVaultId(String vaultId) {
  if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId)) {
    throw ArgumentError.value(vaultId, 'vaultId', 'Invalid vault identifier.');
  }
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value
        .map<Object?>((item) => _canonicalize(item))
        .toList(growable: false);
  }
  if (value is num || value is bool || value is String || value == null) {
    return value;
  }
  return value.toString();
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

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
