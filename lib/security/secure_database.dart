import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartArgon2id;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _vaultFormat = 'naza-vault-v3';
const _databaseFileName = 'naza_one_vault.sqlite3';
const _headerFileName = 'naza_one_vault.header.json';
const _deviceKeyName = 'naza-one-device-unlock-v3';
const _sentinelNamespace = '_system';
const _sentinelKey = 'vault-sentinel';
const _recordIdSeparator = '\u001f';
const _maxHeaderBytes = 1024 * 1024;
const _maxArgonMemoryKiB = 256 * 1024;
const _maxArgonIterations = 10;

enum NazaVaultAccess { setupRequired, locked, unlocked }

final class NazaVaultInspection {
  final NazaVaultAccess access;
  final bool passwordRequired;
  final bool legacyDataPresent;

  const NazaVaultInspection({
    required this.access,
    required this.passwordRequired,
    required this.legacyDataPresent,
  });
}

final class NazaVaultCryptoPolicy {
  final int argonMemoryKiB;
  final int argonIterations;
  final int argonParallelism;
  final int minimumPasswordCharacters;

  const NazaVaultCryptoPolicy({
    this.argonMemoryKiB = 64 * 1024,
    this.argonIterations = 3,
    this.argonParallelism = 1,
    this.minimumPasswordCharacters = 12,
  });

  const NazaVaultCryptoPolicy.testing()
    : argonMemoryKiB = 64,
      argonIterations = 1,
      argonParallelism = 1,
      minimumPasswordCharacters = 4;
}

final class NazaVaultRecordKey {
  final String namespace;
  final String key;

  const NazaVaultRecordKey(this.namespace, this.key);

  @override
  bool operator ==(Object other) {
    return other is NazaVaultRecordKey &&
        other.namespace == namespace &&
        other.key == key;
  }

  @override
  int get hashCode => Object.hash(namespace, key);

  @override
  String toString() => '$namespace/$key';
}

final class NazaVaultException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NazaVaultException(this.code, this.message, [this.cause]);

  @override
  String toString() => 'NazaVaultException($code): $message';
}

abstract interface class NazaDeviceKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class NazaPlatformDeviceKeyStore implements NazaDeviceKeyStore {
  const NazaPlatformDeviceKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class NazaMemoryDeviceKeyStore implements NazaDeviceKeyStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// A SQLite record store whose values and logical identifiers are protected by
/// AES-256-GCM. SQLite still reveals schema, row counts, update times, and
/// ciphertext lengths; this is intentionally not described as page encryption.
final class NazaSecureDatabase {
  NazaSecureDatabase._({
    required Future<Directory> Function() directoryProvider,
    required NazaDeviceKeyStore deviceKeyStore,
    required NazaVaultCryptoPolicy policy,
  }) : this._configured(directoryProvider, deviceKeyStore, policy);

  NazaSecureDatabase._configured(
    this._directoryProvider,
    this._deviceKeyStore,
    this._policy,
  );

  static final NazaSecureDatabase instance = NazaSecureDatabase._(
    directoryProvider: getApplicationSupportDirectory,
    deviceKeyStore: const NazaPlatformDeviceKeyStore(),
    policy: const NazaVaultCryptoPolicy(),
  );

  factory NazaSecureDatabase.forTesting(
    Directory directory, {
    NazaDeviceKeyStore? deviceKeyStore,
    NazaVaultCryptoPolicy policy = const NazaVaultCryptoPolicy.testing(),
  }) {
    return NazaSecureDatabase._(
      directoryProvider: () async => directory,
      deviceKeyStore: deviceKeyStore ?? NazaMemoryDeviceKeyStore(),
      policy: policy,
    );
  }

  final Future<Directory> Function() _directoryProvider;
  final NazaDeviceKeyStore _deviceKeyStore;
  final NazaVaultCryptoPolicy _policy;
  final AesGcm _aes = AesGcm.with256bits();
  final Hmac _hmac = Hmac.sha256();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<void> _tail = Future<void>.value();
  sqlite.Database? _database;
  Map<String, Object?>? _header;
  Uint8List? _vaultUnlockKey;
  Uint8List? _indexKey;
  final Map<int, Uint8List> _dataKeys = <int, Uint8List>{};
  int? _activeDataKeyId;

  bool get isUnlocked => _database != null && _vaultUnlockKey != null;

  int? get activeDataKeyId => _activeDataKeyId;

  Future<NazaVaultInspection> inspect() {
    return _enqueue(() async {
      if (isUnlocked) {
        return NazaVaultInspection(
          access: NazaVaultAccess.unlocked,
          passwordRequired: _header?['passwordRequired'] != false,
          legacyDataPresent: false,
        );
      }
      final headerFile = await _headerFile();
      final legacy = await _legacyDataPresent();
      if (!await headerFile.exists()) {
        return NazaVaultInspection(
          access: NazaVaultAccess.setupRequired,
          passwordRequired: true,
          legacyDataPresent: legacy,
        );
      }
      final header = await _readHeader(headerFile);
      return NazaVaultInspection(
        access: NazaVaultAccess.locked,
        passwordRequired: header['passwordRequired'] != false,
        legacyDataPresent: legacy,
      );
    });
  }

  Future<void> create({
    required String password,
    bool passwordRequired = true,
    Map<NazaVaultRecordKey, Object?> initialRecords = const {},
  }) {
    return _enqueue(
      () => _createNow(
        password: password,
        passwordRequired: passwordRequired,
        initialRecords: initialRecords,
      ),
    );
  }

  Future<void> unlock(String password) {
    return _enqueue(() => _unlockNow(password: password));
  }

  Future<void> unlockWithDeviceKey() {
    return _enqueue(() => _unlockNow());
  }

  Future<void> lock() {
    return _enqueue(() async => _lockNow());
  }

  Future<Object?> readJson(String namespace, String key) {
    _validatePublicRecordKey(namespace, key);
    return _enqueue(() => _readJsonNow(namespace, key));
  }

  Future<void> writeJson(String namespace, String key, Object? value) {
    _validatePublicRecordKey(namespace, key);
    return _enqueue(() => _writeJsonNow(namespace, key, value));
  }

  Future<void> delete(String namespace, String key) {
    _validatePublicRecordKey(namespace, key);
    return _enqueue(() async {
      final db = _requireDatabase();
      final recordId = await _recordId(namespace, key);
      db.execute('DELETE FROM vault_records WHERE record_id = ?', [recordId]);
    });
  }

  Future<Map<NazaVaultRecordKey, Object?>> exportRecords() {
    return _enqueue(_exportRecordsNow);
  }

  Future<void> importRecords(
    Map<NazaVaultRecordKey, Object?> records, {
    bool replace = false,
  }) {
    for (final recordKey in records.keys) {
      _validatePublicRecordKey(recordKey.namespace, recordKey.key);
    }
    return _enqueue(() async {
      final db = _requireDatabase();
      db.execute('BEGIN IMMEDIATE');
      try {
        if (replace) {
          db.execute('DELETE FROM vault_records WHERE record_id != ?', [
            await _recordId(_sentinelNamespace, _sentinelKey),
          ]);
        }
        for (final entry in records.entries) {
          await _writeJsonNow(
            entry.key.namespace,
            entry.key.key,
            entry.value,
            database: db,
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  Future<bool> verifyPassword(String password) {
    return _enqueue(() async {
      final header = _header ?? await _readHeader(await _headerFile());
      if (header['passwordRequired'] == false) return false;
      Uint8List? key;
      Uint8List? unwrappedVaultKey;
      try {
        key = await _passwordKey(password, header);
        unwrappedVaultKey = await _unwrapVaultKey(header, key);
        return true;
      } on SecretBoxAuthenticationError {
        return false;
      } finally {
        _zero(key);
        _zero(unwrappedVaultKey);
      }
    });
  }

  /// Rewraps the stable vault-unlock key. Database rows are not rewritten.
  Future<void> changeUnlock({
    required String newPassword,
    required bool passwordRequired,
  }) {
    return _enqueue(
      () => _changeUnlockNow(
        newPassword: newPassword,
        passwordRequired: passwordRequired,
      ),
    );
  }

  /// Rotates the active data-encryption key transactionally. A pending header
  /// retains both keys until a database scan proves that the old key is unused.
  Future<void> rotateDataKey() {
    return _enqueue(_rotateDataKeyNow);
  }

  Future<String> integrityCheck() {
    return _enqueue(() async {
      final rows = _requireDatabase().select('PRAGMA integrity_check');
      return rows.isEmpty ? 'unknown' : rows.first.columnAt(0).toString();
    });
  }

  Future<File> databaseFile() => _databaseFile();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }

  Future<void> _createNow({
    required String password,
    required bool passwordRequired,
    required Map<NazaVaultRecordKey, Object?> initialRecords,
  }) async {
    await _lockNow();
    _validatePolicy();
    for (final recordKey in initialRecords.keys) {
      _validatePublicRecordKey(recordKey.namespace, recordKey.key);
    }
    final headerFile = await _headerFile();
    if (await headerFile.exists()) {
      throw const NazaVaultException(
        'already_exists',
        'A vault already exists. Unlock it instead of replacing it.',
      );
    }
    if (passwordRequired) _validateNewPassword(password);

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final databaseFile = await _databaseFile();
    final databasePart = File('${databaseFile.path}.creating');
    if (await databasePart.exists()) await databasePart.delete();
    if (await databaseFile.exists()) {
      throw const NazaVaultException(
        'orphaned_database',
        'A vault database exists without its header. It was preserved for recovery.',
      );
    }

    Uint8List? authKey;
    Uint8List? vaultKey;
    Uint8List? dataKey;
    var deviceKeyWritten = false;
    String? createdVaultId;
    sqlite.Database? db;
    try {
      final vaultId = base64UrlEncode(_randomBytes(18)).replaceAll('=', '');
      createdVaultId = vaultId;
      final salt = _randomBytes(16);
      final header = <String, Object?>{
        'format': _vaultFormat,
        'version': 3,
        'vaultId': vaultId,
        'generation': 1,
        'passwordRequired': passwordRequired,
        'kdf': passwordRequired
            ? <String, Object?>{
                'algorithm': 'Argon2id-1.3',
                'salt': base64Encode(salt),
                'memoryKiB': _policy.argonMemoryKiB,
                'iterations': _policy.argonIterations,
                'parallelism': _policy.argonParallelism,
                'length': 32,
              }
            : <String, Object?>{'algorithm': 'platform-secure-storage'},
        'activeDataKeyId': 1,
        'rotationPending': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      if (passwordRequired) {
        authKey = await _deriveArgon2(
          password: password,
          salt: salt,
          memoryKiB: _policy.argonMemoryKiB,
          iterations: _policy.argonIterations,
          parallelism: _policy.argonParallelism,
        );
      } else {
        authKey = _randomBytes(32);
        try {
          await _deviceKeyStore.write(
            _deviceStorageKey(vaultId),
            base64Encode(authKey),
          );
          deviceKeyWritten = true;
        } catch (error) {
          throw NazaVaultException(
            'secure_storage_unavailable',
            'Boot-password bypass requires the operating system secure key store.',
            error,
          );
        }
      }

      vaultKey = _randomBytes(32);
      dataKey = _randomBytes(32);
      header['wrappedVaultKey'] = await _seal(
        vaultKey,
        authKey,
        _vaultKeyAad(header),
      );
      header['wrappedDataKeys'] = <Object?>[
        {
          'id': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'envelope': await _seal(dataKey, vaultKey, _dataKeyAad(vaultId, 1)),
        },
      ];

      _header = header;
      _vaultUnlockKey = Uint8List.fromList(vaultKey);
      _indexKey = await _deriveIndexKey(vaultKey, vaultId);
      _dataKeys[1] = Uint8List.fromList(dataKey);
      _activeDataKeyId = 1;

      db = sqlite.sqlite3.open(databasePart.path);
      _configureAndCreateSchema(db);
      await _writeJsonNow(_sentinelNamespace, _sentinelKey, {
        'vaultId': vaultId,
        'format': _vaultFormat,
      }, database: db);
      for (final entry in initialRecords.entries) {
        await _writeJsonNow(
          entry.key.namespace,
          entry.key.key,
          entry.value,
          database: db,
        );
      }
      final check = db.select('PRAGMA integrity_check').first.columnAt(0);
      if (check != 'ok') {
        throw NazaVaultException(
          'database_integrity',
          'The new SQLite vault failed its integrity check: $check',
        );
      }
      db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      db.close();
      db = null;

      await databasePart.rename(databaseFile.path);
      await _harden(databaseFile);
      await _writeHeader(headerFile, header);
      await _openAndVerify(header);
    } catch (_) {
      db?.close();
      await _lockNow();
      if (await databasePart.exists()) await databasePart.delete();
      if (!await headerFile.exists() && await databaseFile.exists()) {
        await databaseFile.delete();
      }
      if (deviceKeyWritten) {
        try {
          if (createdVaultId != null) {
            await _deviceKeyStore.delete(_deviceStorageKey(createdVaultId));
          }
        } catch (_) {}
      }
      rethrow;
    } finally {
      _zero(authKey);
      _zero(vaultKey);
      _zero(dataKey);
    }
  }

  Future<void> _unlockNow({String? password}) async {
    await _lockNow();
    final headerFile = await _headerFile();
    if (!await headerFile.exists()) {
      throw const NazaVaultException(
        'setup_required',
        'Create the encrypted vault before unlocking it.',
      );
    }
    final header = await _readHeader(headerFile);
    final passwordRequired = header['passwordRequired'] != false;
    Uint8List? authKey;
    Uint8List? vaultKey;
    try {
      if (passwordRequired) {
        if (password == null || password.isEmpty) {
          throw const NazaVaultException(
            'password_required',
            'Enter the startup password.',
          );
        }
        authKey = await _passwordKey(password, header);
      } else {
        final vaultId = header['vaultId']?.toString() ?? '';
        try {
          final encoded = await _deviceKeyStore.read(
            _deviceStorageKey(vaultId),
          );
          if (encoded == null) {
            throw const FormatException('Device unlock key is missing.');
          }
          authKey = Uint8List.fromList(base64Decode(encoded));
        } catch (error) {
          throw NazaVaultException(
            'secure_storage_unavailable',
            'The operating system secure key store could not unlock this vault.',
            error,
          );
        }
      }
      if (authKey.length != 32) {
        throw const NazaVaultException(
          'invalid_key',
          'The vault unlock key has an invalid length.',
        );
      }
      vaultKey = await _unwrapVaultKey(header, authKey);
      final dataKeys = await _unwrapDataKeys(header, vaultKey);
      final activeId = _intValue(header['activeDataKeyId']);
      if (!dataKeys.containsKey(activeId)) {
        throw const NazaVaultException(
          'invalid_header',
          'The active data key is missing from the vault header.',
        );
      }
      _header = header;
      _vaultUnlockKey = Uint8List.fromList(vaultKey);
      _indexKey = await _deriveIndexKey(vaultKey, header['vaultId'].toString());
      _dataKeys.addAll(dataKeys);
      _activeDataKeyId = activeId;
      await _openAndVerify(header);
      if (header['rotationPending'] == true) {
        await _resumeRotation();
      }
    } on SecretBoxAuthenticationError catch (error) {
      await _lockNow();
      throw NazaVaultException(
        'authentication_failed',
        passwordRequired
            ? 'The startup password is incorrect.'
            : 'The device unlock key could not authenticate the vault.',
        error,
      );
    } on FormatException catch (error) {
      await _lockNow();
      throw NazaVaultException(
        'invalid_header',
        'The vault header is malformed.',
        error,
      );
    } catch (_) {
      await _lockNow();
      rethrow;
    } finally {
      _zero(authKey);
      _zero(vaultKey);
    }
  }

  Future<void> _openAndVerify(Map<String, Object?> header) async {
    final file = await _databaseFile();
    if (!await file.exists()) {
      throw const NazaVaultException(
        'database_missing',
        'The encrypted SQLite vault is missing.',
      );
    }
    final db = sqlite.sqlite3.open(file.path);
    try {
      _configureConnection(db);
      if (db.userVersion != 3) {
        throw NazaVaultException(
          'database_version',
          'Unsupported vault database version ${db.userVersion}.',
        );
      }
      _database = db;
      final sentinel = await _readJsonNow(_sentinelNamespace, _sentinelKey);
      if (sentinel is! Map || sentinel['vaultId'] != header['vaultId']) {
        throw const NazaVaultException(
          'sentinel_mismatch',
          'The vault header and encrypted database do not belong together.',
        );
      }
    } catch (_) {
      if (identical(_database, db)) _database = null;
      db.close();
      rethrow;
    }
  }

  Future<Object?> _readJsonNow(String namespace, String key) async {
    final db = _requireDatabase();
    final recordId = await _recordId(namespace, key);
    final rows = db.select(
      'SELECT key_id, nonce, cipher_text, mac FROM vault_records '
      'WHERE record_id = ?',
      [recordId],
    );
    if (rows.isEmpty) return null;
    return _decryptRecord(rows.single, recordId, namespace, key);
  }

  Future<void> _writeJsonNow(
    String namespace,
    String key,
    Object? value, {
    sqlite.Database? database,
  }) async {
    _validateLogicalKey(namespace, 'namespace');
    _validateLogicalKey(key, 'key');
    final db = database ?? _requireDatabase();
    final keyId = _activeDataKeyId;
    final dataKey = keyId == null ? null : _dataKeys[keyId];
    if (keyId == null || dataKey == null) {
      throw const NazaVaultException('locked', 'The vault is locked.');
    }
    final recordId = await _recordId(namespace, key);
    final clear = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'namespace': namespace, 'key': key, 'value': value}),
      ),
    );
    try {
      final box = await _aes.encrypt(
        clear,
        secretKey: SecretKey(dataKey),
        aad: _recordAad(recordId, keyId),
      );
      db.execute(
        'INSERT INTO vault_records '
        '(record_id, key_id, nonce, cipher_text, mac, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(record_id) DO UPDATE SET '
        'key_id=excluded.key_id, nonce=excluded.nonce, '
        'cipher_text=excluded.cipher_text, mac=excluded.mac, '
        'updated_at=excluded.updated_at',
        [
          recordId,
          keyId,
          Uint8List.fromList(box.nonce),
          Uint8List.fromList(box.cipherText),
          Uint8List.fromList(box.mac.bytes),
          DateTime.now().toUtc().millisecondsSinceEpoch,
        ],
      );
    } finally {
      _zero(clear);
    }
  }

  Future<Object?> _decryptRecord(
    sqlite.Row row,
    Uint8List recordId,
    String expectedNamespace,
    String expectedKey,
  ) async {
    final keyId = _intValue(row['key_id']);
    final dataKey = _dataKeys[keyId];
    if (dataKey == null) {
      throw NazaVaultException(
        'missing_data_key',
        'Encrypted record references unavailable key $keyId.',
      );
    }
    Uint8List? clear;
    try {
      clear = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            List<int>.from(row['cipher_text'] as Uint8List),
            nonce: List<int>.from(row['nonce'] as Uint8List),
            mac: Mac(List<int>.from(row['mac'] as Uint8List)),
          ),
          secretKey: SecretKey(dataKey),
          aad: _recordAad(recordId, keyId),
        ),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map ||
          decoded['namespace'] != expectedNamespace ||
          decoded['key'] != expectedKey) {
        throw const NazaVaultException(
          'record_identity',
          'An encrypted record was substituted into the wrong vault slot.',
        );
      }
      return decoded['value'];
    } on SecretBoxAuthenticationError catch (error) {
      throw NazaVaultException(
        'record_authentication',
        'Encrypted vault record authentication failed.',
        error,
      );
    } finally {
      _zero(clear);
    }
  }

  Future<Map<NazaVaultRecordKey, Object?>> _exportRecordsNow() async {
    final db = _requireDatabase();
    final rows = db.select(
      'SELECT record_id, key_id, nonce, cipher_text, mac FROM vault_records',
    );
    final result = <NazaVaultRecordKey, Object?>{};
    for (final row in rows) {
      final recordId = Uint8List.fromList(row['record_id'] as Uint8List);
      final keyId = _intValue(row['key_id']);
      final dataKey = _dataKeys[keyId];
      if (dataKey == null) {
        throw NazaVaultException(
          'missing_data_key',
          'Encrypted record references unavailable key $keyId.',
        );
      }
      Uint8List? clear;
      try {
        clear = Uint8List.fromList(
          await _aes.decrypt(
            SecretBox(
              List<int>.from(row['cipher_text'] as Uint8List),
              nonce: List<int>.from(row['nonce'] as Uint8List),
              mac: Mac(List<int>.from(row['mac'] as Uint8List)),
            ),
            secretKey: SecretKey(dataKey),
            aad: _recordAad(recordId, keyId),
          ),
        );
        final decoded = jsonDecode(utf8.decode(clear));
        if (decoded is! Map) {
          throw const NazaVaultException(
            'invalid_record',
            'An encrypted vault record is malformed.',
          );
        }
        final namespace = decoded['namespace']?.toString() ?? '';
        final key = decoded['key']?.toString() ?? '';
        if (namespace == _sentinelNamespace) continue;
        final expectedId = await _recordId(namespace, key);
        if (!_constantTimeEquals(recordId, expectedId)) {
          throw const NazaVaultException(
            'record_identity',
            'An encrypted record identifier failed validation.',
          );
        }
        result[NazaVaultRecordKey(namespace, key)] = decoded['value'];
      } on SecretBoxAuthenticationError catch (error) {
        throw NazaVaultException(
          'record_authentication',
          'Encrypted vault record authentication failed.',
          error,
        );
      } finally {
        _zero(clear);
      }
    }
    return result;
  }

  Future<void> _changeUnlockNow({
    required String newPassword,
    required bool passwordRequired,
  }) async {
    final vaultKey = _requireVaultKey();
    final header = Map<String, Object?>.from(_requireHeader());
    if (passwordRequired) _validateNewPassword(newPassword);
    final oldPasswordRequired = header['passwordRequired'] != false;
    if (!passwordRequired && !oldPasswordRequired) return;
    final vaultId = header['vaultId'].toString();
    Uint8List? authKey;
    var deviceKeyWritten = false;
    try {
      header['generation'] = _intValue(header['generation']) + 1;
      header['passwordRequired'] = passwordRequired;
      if (passwordRequired) {
        final salt = _randomBytes(16);
        header['kdf'] = <String, Object?>{
          'algorithm': 'Argon2id-1.3',
          'salt': base64Encode(salt),
          'memoryKiB': _policy.argonMemoryKiB,
          'iterations': _policy.argonIterations,
          'parallelism': _policy.argonParallelism,
          'length': 32,
        };
        authKey = await _deriveArgon2(
          password: newPassword,
          salt: salt,
          memoryKiB: _policy.argonMemoryKiB,
          iterations: _policy.argonIterations,
          parallelism: _policy.argonParallelism,
        );
      } else {
        authKey = _randomBytes(32);
        try {
          await _deviceKeyStore.write(
            _deviceStorageKey(vaultId),
            base64Encode(authKey),
          );
          deviceKeyWritten = true;
        } catch (error) {
          throw NazaVaultException(
            'secure_storage_unavailable',
            'The operating system secure key store is unavailable; the startup password remains enabled.',
            error,
          );
        }
        header['kdf'] = <String, Object?>{
          'algorithm': 'platform-secure-storage',
        };
      }
      header['wrappedVaultKey'] = await _seal(
        vaultKey,
        authKey,
        _vaultKeyAad(header),
      );
      header['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _writeHeader(await _headerFile(), header);
      _header = header;
      if (passwordRequired && !oldPasswordRequired) {
        await _deviceKeyStore.delete(_deviceStorageKey(vaultId));
      }
    } catch (_) {
      if (deviceKeyWritten && oldPasswordRequired) {
        try {
          await _deviceKeyStore.delete(_deviceStorageKey(vaultId));
        } catch (_) {}
      }
      rethrow;
    } finally {
      _zero(authKey);
    }
  }

  Future<void> _rotateDataKeyNow() async {
    final header = Map<String, Object?>.from(_requireHeader());
    final vaultKey = _requireVaultKey();
    final db = _requireDatabase();
    final oldIds = _dataKeys.keys.toList(growable: false);
    final nextId = oldIds.isEmpty ? 1 : oldIds.reduce(math.max) + 1;
    final nextKey = _randomBytes(32);
    try {
      final wrapped = List<Object?>.from(
        (header['wrappedDataKeys'] as List?) ?? const [],
      );
      wrapped.add({
        'id': nextId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'envelope': await _seal(
          nextKey,
          vaultKey,
          _dataKeyAad(header['vaultId'].toString(), nextId),
        ),
      });
      header['wrappedDataKeys'] = wrapped;
      header['activeDataKeyId'] = nextId;
      header['rotationPending'] = true;
      header['generation'] = _intValue(header['generation']) + 1;
      await _writeHeader(await _headerFile(), header);
      _header = header;
      _dataKeys[nextId] = Uint8List.fromList(nextKey);
      _activeDataKeyId = nextId;

      db.execute('BEGIN IMMEDIATE');
      try {
        final rows = db.select(
          'SELECT record_id, key_id, nonce, cipher_text, mac '
          'FROM vault_records WHERE key_id != ?',
          [nextId],
        );
        for (final row in rows) {
          await _reencryptRow(db, row, nextId, nextKey);
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      await _finalizeRotation();
    } finally {
      _zero(nextKey);
    }
  }

  Future<void> _resumeRotation() async {
    final activeId = _activeDataKeyId;
    final activeKey = activeId == null ? null : _dataKeys[activeId];
    if (activeId == null || activeKey == null) {
      throw const NazaVaultException(
        'rotation_state',
        'Vault rotation metadata is incomplete.',
      );
    }
    final db = _requireDatabase();
    db.execute('BEGIN IMMEDIATE');
    try {
      final rows = db.select(
        'SELECT record_id, key_id, nonce, cipher_text, mac '
        'FROM vault_records WHERE key_id != ?',
        [activeId],
      );
      for (final row in rows) {
        await _reencryptRow(db, row, activeId, activeKey);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    await _finalizeRotation();
  }

  Future<void> _reencryptRow(
    sqlite.Database db,
    sqlite.Row row,
    int nextId,
    Uint8List nextKey,
  ) async {
    final recordId = Uint8List.fromList(row['record_id'] as Uint8List);
    final oldId = _intValue(row['key_id']);
    final oldKey = _dataKeys[oldId];
    if (oldKey == null) {
      throw NazaVaultException(
        'missing_data_key',
        'Cannot rotate record encrypted with missing key $oldId.',
      );
    }
    Uint8List? clear;
    try {
      clear = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            List<int>.from(row['cipher_text'] as Uint8List),
            nonce: List<int>.from(row['nonce'] as Uint8List),
            mac: Mac(List<int>.from(row['mac'] as Uint8List)),
          ),
          secretKey: SecretKey(oldKey),
          aad: _recordAad(recordId, oldId),
        ),
      );
      final box = await _aes.encrypt(
        clear,
        secretKey: SecretKey(nextKey),
        aad: _recordAad(recordId, nextId),
      );
      db.execute(
        'UPDATE vault_records SET key_id=?, nonce=?, cipher_text=?, mac=?, '
        'updated_at=? WHERE record_id=?',
        [
          nextId,
          Uint8List.fromList(box.nonce),
          Uint8List.fromList(box.cipherText),
          Uint8List.fromList(box.mac.bytes),
          DateTime.now().toUtc().millisecondsSinceEpoch,
          recordId,
        ],
      );
    } finally {
      _zero(clear);
    }
  }

  Future<void> _finalizeRotation() async {
    final db = _requireDatabase();
    final activeId = _activeDataKeyId!;
    final remaining = db.select(
      'SELECT COUNT(*) AS count FROM vault_records WHERE key_id != ?',
      [activeId],
    ).single['count'];
    if (_intValue(remaining) != 0) {
      throw const NazaVaultException(
        'rotation_incomplete',
        'Old encrypted records remain after data-key rotation.',
      );
    }
    final header = Map<String, Object?>.from(_requireHeader());
    final wrapped = ((header['wrappedDataKeys'] as List?) ?? const [])
        .whereType<Map>()
        .where((entry) => _intValue(entry['id']) == activeId)
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
    if (wrapped.length != 1) {
      throw const NazaVaultException(
        'rotation_state',
        'The active wrapped data key is missing or duplicated.',
      );
    }
    header['wrappedDataKeys'] = wrapped;
    header['rotationPending'] = false;
    header['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _writeHeader(await _headerFile(), header);
    for (final id in _dataKeys.keys.toList()) {
      if (id == activeId) continue;
      _zero(_dataKeys.remove(id));
    }
    _header = header;
  }

  Future<Uint8List> _recordId(String namespace, String key) async {
    _validateLogicalKey(namespace, 'namespace');
    _validateLogicalKey(key, 'key');
    final indexKey = _indexKey;
    if (indexKey == null) {
      throw const NazaVaultException('locked', 'The vault is locked.');
    }
    final mac = await _hmac.calculateMac(
      utf8.encode('$_vaultFormat\u001f$namespace\u001f$key'),
      secretKey: SecretKey(indexKey),
    );
    return Uint8List.fromList(mac.bytes);
  }

  Future<Uint8List> _deriveIndexKey(List<int> vaultKey, String vaultId) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(vaultKey),
      nonce: utf8.encode(vaultId),
      info: utf8.encode('$_vaultFormat/index-key'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<Uint8List> _passwordKey(
    String password,
    Map<String, Object?> header,
  ) async {
    _validatePasswordInput(password);
    final kdf = header['kdf'];
    if (kdf is! Map || kdf['algorithm'] != 'Argon2id-1.3') {
      throw const FormatException('Unsupported password KDF.');
    }
    return _deriveArgon2(
      password: password,
      salt: Uint8List.fromList(base64Decode(kdf['salt'].toString())),
      memoryKiB: _intValue(kdf['memoryKiB']),
      iterations: _intValue(kdf['iterations']),
      parallelism: _intValue(kdf['parallelism']),
    );
  }

  Future<Uint8List> _unwrapVaultKey(
    Map<String, Object?> header,
    List<int> authKey,
  ) async {
    final envelope = header['wrappedVaultKey'];
    if (envelope is! Map) throw const FormatException('Missing wrapped VUK.');
    final clear = await _openEnvelope(
      Map<String, Object?>.from(envelope),
      authKey,
      _vaultKeyAad(header),
    );
    if (clear.length != 32) throw const FormatException('Invalid VUK length.');
    return clear;
  }

  Future<Map<int, Uint8List>> _unwrapDataKeys(
    Map<String, Object?> header,
    List<int> vaultKey,
  ) async {
    final raw = header['wrappedDataKeys'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('Missing wrapped data keys.');
    }
    final vaultId = header['vaultId'].toString();
    final result = <int, Uint8List>{};
    try {
      for (final item in raw) {
        if (item is! Map || item['envelope'] is! Map) {
          throw const FormatException('Malformed wrapped data key.');
        }
        final id = _intValue(item['id']);
        if (id < 1) throw const FormatException('Invalid data key ID.');
        final clear = await _openEnvelope(
          Map<String, Object?>.from(item['envelope'] as Map),
          vaultKey,
          _dataKeyAad(vaultId, id),
        );
        if (clear.length != 32 || result.containsKey(id)) {
          _zero(clear);
          throw const FormatException('Invalid or duplicate data key.');
        }
        result[id] = clear;
      }
      return result;
    } catch (_) {
      for (final key in result.values) {
        _zero(key);
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _seal(
    List<int> clear,
    List<int> key,
    List<int> aad,
  ) async {
    final box = await _aes.encrypt(clear, secretKey: SecretKey(key), aad: aad);
    return {
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Uint8List> _openEnvelope(
    Map<String, Object?> envelope,
    List<int> key,
    List<int> aad,
  ) async {
    if (envelope['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported vault cipher.');
    }
    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(envelope['cipherText'].toString()),
        nonce: base64Decode(envelope['nonce'].toString()),
        mac: Mac(base64Decode(envelope['mac'].toString())),
      ),
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(clear);
  }

  List<int> _vaultKeyAad(Map<String, Object?> header) {
    final kdf = header['kdf'];
    final normalizedKdf = kdf is Map
        ? Map<String, Object?>.from(kdf)
        : const <String, Object?>{};
    return utf8.encode(
      jsonEncode({
        'format': _vaultFormat,
        'version': header['version'],
        'vaultId': header['vaultId'],
        'passwordRequired': header['passwordRequired'],
        'kdf': normalizedKdf,
      }),
    );
  }

  List<int> _dataKeyAad(String vaultId, int keyId) {
    return utf8.encode('$_vaultFormat/$vaultId/data-key/$keyId');
  }

  List<int> _recordAad(Uint8List recordId, int keyId) {
    return utf8.encode(
      '$_vaultFormat/record/$keyId/${base64UrlEncode(recordId)}',
    );
  }

  Future<Map<String, Object?>> _readHeader(File file) async {
    try {
      final stat = await file.stat();
      if (stat.size <= 0 || stat.size > _maxHeaderBytes) {
        throw const FormatException('Invalid vault header size.');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) throw const FormatException('Header is not a map.');
      final header = Map<String, Object?>.from(decoded);
      if (header['format'] != _vaultFormat || header['version'] != 3) {
        throw const FormatException('Unsupported vault header version.');
      }
      final vaultId = header['vaultId']?.toString() ?? '';
      if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId)) {
        throw const FormatException('Invalid vault identifier.');
      }
      return header;
    } catch (error) {
      if (error is NazaVaultException) rethrow;
      throw NazaVaultException(
        'invalid_header',
        'The vault header is missing, corrupt, or unsupported.',
        error,
      );
    }
  }

  Future<void> _writeHeader(File file, Map<String, Object?> header) async {
    await _atomicWrite(
      file,
      const JsonEncoder.withIndent('  ').convert(header),
    );
    final verify = await _readHeader(file);
    if (verify['generation'] != header['generation'] ||
        verify['vaultId'] != header['vaultId']) {
      throw const NazaVaultException(
        'header_write',
        'The new vault header failed read-back verification.',
      );
    }
  }

  void _configureAndCreateSchema(sqlite.Database db) {
    _configureConnection(db);
    db.execute('''
CREATE TABLE IF NOT EXISTS vault_records (
  record_id BLOB PRIMARY KEY NOT NULL,
  key_id INTEGER NOT NULL,
  nonce BLOB NOT NULL CHECK(length(nonce) = 12),
  cipher_text BLOB NOT NULL,
  mac BLOB NOT NULL CHECK(length(mac) = 16),
  updated_at INTEGER NOT NULL
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS vault_records_key_id ON vault_records(key_id);
''');
    db.userVersion = 3;
  }

  void _configureConnection(sqlite.Database db) {
    db.execute('PRAGMA trusted_schema=OFF');
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA secure_delete=ON');
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    db.execute('PRAGMA busy_timeout=5000');
  }

  Future<void> _lockNow() async {
    final db = _database;
    _database = null;
    if (db != null) {
      try {
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (_) {}
      db.close();
    }
    _header = null;
    _zero(_vaultUnlockKey);
    _zero(_indexKey);
    _vaultUnlockKey = null;
    _indexKey = null;
    for (final key in _dataKeys.values) {
      _zero(key);
    }
    _dataKeys.clear();
    _activeDataKeyId = null;
  }

  sqlite.Database _requireDatabase() {
    final db = _database;
    if (db == null) {
      throw const NazaVaultException('locked', 'The vault is locked.');
    }
    return db;
  }

  Uint8List _requireVaultKey() {
    final key = _vaultUnlockKey;
    if (key == null) {
      throw const NazaVaultException('locked', 'The vault is locked.');
    }
    return key;
  }

  Map<String, Object?> _requireHeader() {
    final header = _header;
    if (header == null) {
      throw const NazaVaultException('locked', 'The vault is locked.');
    }
    return header;
  }

  void _validateNewPassword(String password) {
    final characters = password.runes.length;
    if (characters < _policy.minimumPasswordCharacters) {
      throw NazaVaultException(
        'weak_password',
        'Use at least ${_policy.minimumPasswordCharacters} characters.',
      );
    }
    if (characters > 1024) {
      throw const NazaVaultException(
        'password_too_long',
        'The startup password is too long.',
      );
    }
  }

  void _validatePasswordInput(String password) {
    final characters = password.runes.length;
    if (characters < 1 || characters > 1024) {
      throw const NazaVaultException(
        'invalid_password',
        'The startup password must contain 1-1024 characters.',
      );
    }
  }

  void _validatePolicy() {
    if (_policy.argonMemoryKiB < 64 ||
        _policy.argonMemoryKiB > _maxArgonMemoryKiB ||
        _policy.argonIterations < 1 ||
        _policy.argonIterations > _maxArgonIterations ||
        _policy.argonParallelism < 1 ||
        _policy.argonParallelism > 16 ||
        _policy.minimumPasswordCharacters < 1 ||
        _policy.minimumPasswordCharacters > 1024) {
      throw const NazaVaultException(
        'invalid_crypto_policy',
        'The vault cryptographic policy is outside supported safety limits.',
      );
    }
  }

  void _validatePublicRecordKey(String namespace, String key) {
    _validateLogicalKey(namespace, 'namespace');
    _validateLogicalKey(key, 'key');
    if (namespace == _sentinelNamespace) {
      throw ArgumentError.value(
        namespace,
        'namespace',
        'The vault system namespace is reserved.',
      );
    }
  }

  void _validateLogicalKey(String value, String label) {
    if (value.isEmpty ||
        value.length > 240 ||
        value.contains('\u0000') ||
        value.contains(_recordIdSeparator)) {
      throw ArgumentError.value(value, label, 'Invalid vault record $label.');
    }
  }

  Future<bool> _legacyDataPresent() async {
    final directory = await _directoryProvider();
    const names = [
      'naza_one_vault.key',
      'naza_one_history.aesgcm.json',
      'naza_scanner_drafts.sqlite.aesgcm.json',
      'naza_one_vector_memory.aesgcm.json',
      'naza_verification_state.aesgcm.json',
      'naza_generation_settings.sqlite.aesgcm.json',
    ];
    for (final name in names) {
      if (await File('${directory.path}/$name').exists()) return true;
    }
    return false;
  }

  Future<File> _databaseFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}/$_databaseFileName');
  }

  Future<File> _headerFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}/$_headerFileName');
  }

  String _deviceStorageKey(String vaultId) => '$_deviceKeyName-$vaultId';

  Uint8List _randomBytes(int length) {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    var difference = a.length ^ b.length;
    final length = math.min(a.length, b.length);
    for (var i = 0; i < length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  void _zero(List<int>? bytes) {
    if (bytes == null) return;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  Future<void> _atomicWrite(File file, String contents) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.new');
    if (await part.exists()) await part.delete();
    await part.writeAsString(contents, flush: true);
    await _harden(part);
    if (Platform.isWindows && await file.exists()) await file.delete();
    await part.rename(file.path);
    await _harden(file);
  }

  Future<void> _harden(File file) async {
    if (Platform.isWindows || !await file.exists()) return;
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {}
  }
}

Future<Uint8List> _deriveArgon2({
  required String password,
  required Uint8List salt,
  required int memoryKiB,
  required int iterations,
  required int parallelism,
}) async {
  if (salt.length < 16 ||
      memoryKiB < 64 ||
      memoryKiB > _maxArgonMemoryKiB ||
      iterations < 1 ||
      iterations > _maxArgonIterations ||
      parallelism < 1 ||
      parallelism > 16) {
    throw const FormatException('Unsafe Argon2id parameters.');
  }
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  try {
    final derived = await Isolate.run<List<int>>(() async {
      // This function already owns a dedicated worker isolate. The default
      // desktop Argon2 implementation would otherwise spawn another isolate
      // inside it, causing avoidable isolate-group startup/safepoint pauses in
      // debug builds. The KDF parameters and resulting bytes are unchanged.
      const noNestedWorkers = 0;
      const uninterruptedWorkerChunk = -1;
      final algorithm = DartArgon2id(
        parallelism: parallelism,
        memory: memoryKiB,
        iterations: iterations,
        hashLength: 32,
        maxIsolates: noNestedWorkers,
        blocksPerProcessingChunk: uninterruptedWorkerChunk,
      );
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(passwordBytes),
        nonce: salt,
      );
      return key.extractBytes();
    });
    return Uint8List.fromList(derived);
  } finally {
    for (var i = 0; i < passwordBytes.length; i++) {
      passwordBytes[i] = 0;
    }
  }
}
