import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pqcrypto/pqcrypto.dart';

const _publicFormat = 'naza-pq-recovery-public-v1';
const _privateFormat = 'naza-pq-recovery-private-v1';
const _backupFormat = 'naza-pq-backup-v1';
const _suite = 'ML-KEM-768+X25519+HKDF-SHA256+AES-256-GCM';
const _cipher = 'AES-256-GCM';
const _argonAlgorithm = 'Argon2id-1.3';
const _privateEncoding = 'ML-KEM-768-SK||X25519-SK';
const _maxArgonMemoryKiB = 256 * 1024;
const _maxArgonIterations = 10;
const _maxPublicJsonCharacters = 64 * 1024;
const _maxPrivateJsonCharacters = 128 * 1024;
const _maxPrivateClearBytes = 16 * 1024;
const _maxBackupClearBytes = 256 * 1024 * 1024;
const _maxBackupJsonCharacters = 384 * 1024 * 1024;

final class NazaPostQuantumPolicy {
  final int argonMemoryKiB;
  final int argonIterations;
  final int minimumPasswordCharacters;

  const NazaPostQuantumPolicy({
    this.argonMemoryKiB = 64 * 1024,
    this.argonIterations = 3,
    this.minimumPasswordCharacters = 12,
  });

  const NazaPostQuantumPolicy.testing()
    : argonMemoryKiB = 64,
      argonIterations = 1,
      minimumPasswordCharacters = 4;
}

final class NazaRecoveryBundle {
  final String publicKeyJson;
  final String encryptedPrivateKeyJson;
  final String fingerprint;

  const NazaRecoveryBundle({
    required this.publicKeyJson,
    required this.encryptedPrivateKeyJson,
    required this.fingerprint,
  });
}

final class NazaPostQuantumException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NazaPostQuantumException(this.code, this.message, [this.cause]);

  @override
  String toString() => 'NazaPostQuantumException($code): $message';
}

/// Optional recovery/export cryptography. It is deliberately isolated from the
/// local vault unlock path: ML-KEM only helps when the recovery private key is
/// stored somewhere other than the device holding the encrypted backup.
final class NazaPostQuantumExport {
  const NazaPostQuantumExport._();

  static final AesGcm _aes = AesGcm.with256bits();
  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Sha256 _sha256 = Sha256();
  static final KyberKem _mlKem = PqcKem.kyber768;

  static Future<NazaRecoveryBundle> generateRecoveryBundle({
    required String password,
    NazaPostQuantumPolicy policy = const NazaPostQuantumPolicy(),
  }) async {
    _validatePolicy(policy);
    _validatePassword(password, policy);
    SimpleKeyPair? xPair;
    Uint8List? mlPrivate;
    Uint8List? xPrivate;
    Uint8List? passwordKey;
    Uint8List? privateClear;
    try {
      final generated = _mlKem.generateKeyPair();
      final mlPublic = generated.$1;
      mlPrivate = generated.$2;
      xPair = await _x25519.newKeyPair();
      final xPublic = await xPair.extractPublicKey();
      xPrivate = Uint8List.fromList(await xPair.extractPrivateKeyBytes());
      final publicMap = <String, Object?>{
        'format': _publicFormat,
        'suite': _suite,
        'mlKemPublicKey': base64Encode(mlPublic),
        'x25519PublicKey': base64Encode(xPublic.bytes),
      };
      final fingerprint = await _fingerprint(publicMap);
      publicMap['fingerprint'] = fingerprint;
      final salt = _randomBytes(16);
      final kdf = <String, Object?>{
        'algorithm': _argonAlgorithm,
        'salt': base64Encode(salt),
        'memoryKiB': policy.argonMemoryKiB,
        'iterations': policy.argonIterations,
        'parallelism': 1,
        'length': 32,
      };
      passwordKey = await _derivePasswordKey(
        password,
        salt,
        policy.argonMemoryKiB,
        policy.argonIterations,
      );
      privateClear = Uint8List(mlPrivate.length + xPrivate.length)
        ..setAll(0, mlPrivate)
        ..setAll(mlPrivate.length, xPrivate);
      final aad = _privateKeyAad(publicMap, kdf);
      final box = await _aes.encrypt(
        privateClear,
        secretKey: SecretKey(passwordKey),
        aad: aad,
      );
      final privateMap = <String, Object?>{
        'format': _privateFormat,
        'suite': _suite,
        'privateEncoding': _privateEncoding,
        'publicKey': publicMap,
        'kdf': kdf,
        'cipher': _cipher,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      };
      return NazaRecoveryBundle(
        publicKeyJson: const JsonEncoder.withIndent('  ').convert(publicMap),
        encryptedPrivateKeyJson: const JsonEncoder.withIndent(
          '  ',
        ).convert(privateMap),
        fingerprint: fingerprint,
      );
    } finally {
      xPair?.destroy();
      _zero(mlPrivate);
      _zero(xPrivate);
      _zero(passwordKey);
      _zero(privateClear);
    }
  }

  static Future<String> encryptBackup({
    required List<int> clearBytes,
    required String recipientPublicKeyJson,
  }) async {
    if (clearBytes.length > _maxBackupClearBytes) {
      throw const NazaPostQuantumException(
        'backup_too_large',
        'The in-memory recovery backup exceeds the supported size limit.',
      );
    }
    final publicMap = await _parsePublicKey(recipientPublicKeyJson);
    final mlPublic = _decodeBase64Field(
      publicMap,
      'mlKemPublicKey',
      exactLength: _mlKem.params.publicKeyBytes,
      materialCode: 'invalid_public_key',
    );
    final xPublic = _decodeBase64Field(
      publicMap,
      'x25519PublicKey',
      exactLength: 32,
      materialCode: 'invalid_public_key',
    );

    final (mlCiphertext, mlShared) = _mlKem.encapsulate(mlPublic);
    SimpleKeyPair? ephemeralPair;
    Uint8List? classicalShared;
    Uint8List? combined;
    Uint8List? contentKey;
    try {
      ephemeralPair = await _x25519.newKeyPair();
      final ephemeralPublic = await ephemeralPair.extractPublicKey();
      final shared = await _x25519.sharedSecretKey(
        keyPair: ephemeralPair,
        remotePublicKey: SimplePublicKey(xPublic, type: KeyPairType.x25519),
      );
      try {
        classicalShared = Uint8List.fromList(await shared.extractBytes());
      } finally {
        shared.destroy();
      }
      final createdAt = DateTime.now().toUtc().toIso8601String();
      final header = <String, Object?>{
        'format': _backupFormat,
        'suite': _suite,
        'cipher': _cipher,
        'recipientFingerprint': publicMap['fingerprint'],
        'mlKemCiphertext': base64Encode(mlCiphertext),
        'ephemeralX25519PublicKey': base64Encode(ephemeralPublic.bytes),
        'createdAt': createdAt,
      };
      final aad = _backupAad(header);
      combined = _concatenateSecrets(mlShared, classicalShared);
      contentKey = await _combineSecrets(combined, aad);
      final box = await _aes.encrypt(
        clearBytes,
        secretKey: SecretKey(contentKey),
        aad: aad,
      );
      return const JsonEncoder.withIndent('  ').convert({
        ...header,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      });
    } finally {
      ephemeralPair?.destroy();
      _zero(mlShared);
      _zero(classicalShared);
      _zero(combined);
      _zero(contentKey);
    }
  }

  static Future<Uint8List> decryptBackup({
    required String encryptedBackupJson,
    required String encryptedPrivateKeyJson,
    required String recoveryPassword,
  }) async {
    _validateRecoveryPasswordInput(recoveryPassword);
    final privateMap = _jsonMap(
      encryptedPrivateKeyJson,
      _privateFormat,
      maxCharacters: _maxPrivateJsonCharacters,
    );
    if (privateMap['suite'] != _suite ||
        privateMap['cipher'] != _cipher ||
        privateMap['privateEncoding'] != _privateEncoding) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The encrypted recovery-key suite is unsupported.',
      );
    }
    final publicRaw = privateMap['publicKey'];
    final kdfRaw = privateMap['kdf'];
    if (publicRaw is! Map || kdfRaw is! Map) {
      throw const NazaPostQuantumException(
        'invalid_private_key',
        'The encrypted recovery key is malformed.',
      );
    }
    final publicMap = Map<String, Object?>.from(publicRaw);
    await _validatePublicMap(publicMap);
    final kdf = Map<String, Object?>.from(kdfRaw);
    final backup = _jsonMap(
      encryptedBackupJson,
      _backupFormat,
      maxCharacters: _maxBackupJsonCharacters,
    );
    if (backup['suite'] != _suite || backup['cipher'] != _cipher) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery cryptographic suite is unsupported.',
      );
    }
    if (backup['recipientFingerprint'] != publicMap['fingerprint']) {
      throw const NazaPostQuantumException(
        'wrong_recipient',
        'This encrypted backup belongs to a different recovery key.',
      );
    }

    Uint8List? passwordKey;
    Uint8List? privateClear;
    Uint8List? mlPrivate;
    Uint8List? xPrivate;
    SimpleKeyPairData? xPair;
    Uint8List? mlShared;
    Uint8List? classicalShared;
    Uint8List? combined;
    Uint8List? contentKey;
    Uint8List? clear;
    try {
      passwordKey = await _passwordKeyFromKdf(recoveryPassword, kdf);
      privateClear = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            _decodeBase64Field(
              privateMap,
              'cipherText',
              maxLength: _maxPrivateClearBytes,
              materialCode: 'invalid_private_key',
            ),
            nonce: _decodeBase64Field(
              privateMap,
              'nonce',
              exactLength: 12,
              materialCode: 'invalid_private_key',
            ),
            mac: Mac(
              _decodeBase64Field(
                privateMap,
                'mac',
                exactLength: 16,
                materialCode: 'invalid_private_key',
              ),
            ),
          ),
          secretKey: SecretKey(passwordKey),
          aad: _privateKeyAad(publicMap, kdf),
        ),
      );
      final mlPrivateLength = _mlKem.params.secretKeyBytes;
      if (privateClear.length != mlPrivateLength + 32) {
        throw const NazaPostQuantumException(
          'invalid_private_key',
          'The encrypted recovery private key has an invalid length.',
        );
      }
      mlPrivate = Uint8List.fromList(
        Uint8List.sublistView(privateClear, 0, mlPrivateLength),
      );
      xPrivate = Uint8List.fromList(
        Uint8List.sublistView(privateClear, mlPrivateLength),
      );
      final xPublic = _decodeBase64Field(
        publicMap,
        'x25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_public_key',
      );
      xPair = SimpleKeyPairData(
        xPrivate,
        publicKey: SimplePublicKey(xPublic, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      final mlCiphertext = _decodeBase64Field(
        backup,
        'mlKemCiphertext',
        exactLength: _mlKem.params.ciphertextBytes,
        materialCode: 'invalid_backup',
      );
      mlShared = _mlKem.decapsulate(mlPrivate, mlCiphertext);
      final ephemeralPublic = _decodeBase64Field(
        backup,
        'ephemeralX25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_backup',
      );
      final shared = await _x25519.sharedSecretKey(
        keyPair: xPair,
        remotePublicKey: SimplePublicKey(
          ephemeralPublic,
          type: KeyPairType.x25519,
        ),
      );
      try {
        classicalShared = Uint8List.fromList(await shared.extractBytes());
      } finally {
        shared.destroy();
      }
      final header = <String, Object?>{
        'format': backup['format'],
        'suite': backup['suite'],
        'cipher': backup['cipher'],
        'recipientFingerprint': backup['recipientFingerprint'],
        'mlKemCiphertext': backup['mlKemCiphertext'],
        'ephemeralX25519PublicKey': backup['ephemeralX25519PublicKey'],
        'createdAt': backup['createdAt'],
      };
      final aad = _backupAad(header);
      combined = _concatenateSecrets(mlShared, classicalShared);
      contentKey = await _combineSecrets(combined, aad);
      clear = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            _decodeBase64Field(
              backup,
              'cipherText',
              maxLength: _maxBackupClearBytes,
              allowEmpty: true,
              materialCode: 'invalid_backup',
            ),
            nonce: _decodeBase64Field(
              backup,
              'nonce',
              exactLength: 12,
              materialCode: 'invalid_backup',
            ),
            mac: Mac(
              _decodeBase64Field(
                backup,
                'mac',
                exactLength: 16,
                materialCode: 'invalid_backup',
              ),
            ),
          ),
          secretKey: SecretKey(contentKey),
          aad: aad,
        ),
      );
      final result = Uint8List.fromList(clear);
      return result;
    } on NazaPostQuantumException {
      rethrow;
    } on SecretBoxAuthenticationError catch (error) {
      throw NazaPostQuantumException(
        'authentication_failed',
        'The recovery password is wrong or the recovery material was altered.',
        error,
      );
    } on FormatException catch (error) {
      throw NazaPostQuantumException(
        'invalid_encoding',
        'The recovery material is not valid JSON/base64.',
        error,
      );
    } finally {
      xPair?.destroy();
      _zero(passwordKey);
      _zero(privateClear);
      _zero(mlPrivate);
      _zero(xPrivate);
      _zero(mlShared);
      _zero(classicalShared);
      _zero(combined);
      _zero(contentKey);
      _zero(clear);
    }
  }

  static Future<Map<String, Object?>> _parsePublicKey(String json) async {
    final map = _jsonMap(
      json,
      _publicFormat,
      maxCharacters: _maxPublicJsonCharacters,
    );
    await _validatePublicMap(map);
    return map;
  }

  static Future<void> _validatePublicMap(Map<String, Object?> map) async {
    if (map['format'] != _publicFormat || map['suite'] != _suite) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery public-key suite is unsupported.',
      );
    }
    try {
      final expected = await _fingerprint(map);
      if (!_constantTimeText(expected, map['fingerprint']?.toString() ?? '')) {
        throw const NazaPostQuantumException(
          'public_key_fingerprint',
          'The recovery public-key fingerprint is invalid.',
        );
      }
      _decodeBase64Field(
        map,
        'x25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_public_key',
      );
      final mlPublic = _decodeBase64Field(
        map,
        'mlKemPublicKey',
        exactLength: _mlKem.params.publicKeyBytes,
        materialCode: 'invalid_public_key',
      );
      // Validation is performed by encapsulation without using its result.
      final (ciphertext, shared) = _mlKem.encapsulate(mlPublic);
      _zero(ciphertext);
      _zero(shared);
    } on NazaPostQuantumException {
      rethrow;
    } catch (error) {
      throw NazaPostQuantumException(
        'invalid_public_key',
        'The recovery public key is malformed.',
        error,
      );
    }
  }

  static Future<String> _fingerprint(Map<String, Object?> publicMap) async {
    final canonical = utf8.encode(
      jsonEncode({
        'format': publicMap['format'],
        'suite': publicMap['suite'],
        'mlKemPublicKey': publicMap['mlKemPublicKey'],
        'x25519PublicKey': publicMap['x25519PublicKey'],
      }),
    );
    final digest = await _sha256.hash(canonical);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static List<int> _privateKeyAad(
    Map<String, Object?> publicMap,
    Map<String, Object?> kdf,
  ) {
    return utf8.encode(
      jsonEncode({
        'format': _privateFormat,
        'suite': _suite,
        'cipher': _cipher,
        'privateEncoding': _privateEncoding,
        'publicKey': publicMap,
        'kdf': kdf,
      }),
    );
  }

  static List<int> _backupAad(Map<String, Object?> header) {
    return utf8.encode(
      jsonEncode({
        'format': header['format'],
        'suite': header['suite'],
        'cipher': header['cipher'],
        'recipientFingerprint': header['recipientFingerprint'],
        'mlKemCiphertext': header['mlKemCiphertext'],
        'ephemeralX25519PublicKey': header['ephemeralX25519PublicKey'],
        'createdAt': header['createdAt'],
      }),
    );
  }

  static Future<Uint8List> _combineSecrets(
    List<int> combined,
    List<int> transcript,
  ) async {
    final transcriptHash = await _sha256.hash(transcript);
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(combined),
      nonce: transcriptHash.bytes,
      info: utf8.encode('$_backupFormat/$_suite/content-key'),
    );
    try {
      return Uint8List.fromList(await key.extractBytes());
    } finally {
      key.destroy();
    }
  }

  static Uint8List _concatenateSecrets(List<int> first, List<int> second) {
    final combined = Uint8List(first.length + second.length);
    combined.setAll(0, first);
    combined.setAll(first.length, second);
    return combined;
  }

  static Future<Uint8List> _passwordKeyFromKdf(
    String password,
    Map<String, Object?> kdf,
  ) {
    if (kdf['algorithm'] != _argonAlgorithm ||
        _integer(kdf['parallelism']) != 1 ||
        _integer(kdf['length']) != 32) {
      throw const NazaPostQuantumException(
        'unsupported_kdf',
        'The recovery-key password KDF is unsupported.',
      );
    }
    return _derivePasswordKey(
      password,
      _decodeBase64Field(
        kdf,
        'salt',
        exactLength: 16,
        materialCode: 'unsafe_kdf',
      ),
      _integer(kdf['memoryKiB']),
      _integer(kdf['iterations']),
    );
  }

  static Map<String, Object?> _jsonMap(
    String text,
    String? format, {
    required int maxCharacters,
  }) {
    try {
      if (text.isEmpty || text.length > maxCharacters) {
        throw const FormatException('Recovery JSON size is invalid.');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('Expected JSON map.');
      final map = Map<String, Object?>.from(decoded);
      if (format != null && map['format'] != format) {
        throw const FormatException('Unexpected format.');
      }
      return map;
    } on NazaPostQuantumException {
      rethrow;
    } catch (error) {
      throw NazaPostQuantumException(
        'invalid_encoding',
        'Recovery material is not valid JSON.',
        error,
      );
    }
  }

  static void _validatePassword(String password, NazaPostQuantumPolicy policy) {
    final length = password.runes.length;
    if (length < policy.minimumPasswordCharacters || length > 1024) {
      throw NazaPostQuantumException(
        'weak_password',
        'Use ${policy.minimumPasswordCharacters}-1024 characters for the recovery-key password.',
      );
    }
  }

  static void _validateRecoveryPasswordInput(String password) {
    final length = password.runes.length;
    if (length < 1 || length > 1024) {
      throw const NazaPostQuantumException(
        'invalid_password',
        'The recovery password must contain 1-1024 characters.',
      );
    }
  }

  static void _validatePolicy(NazaPostQuantumPolicy policy) {
    if (policy.argonMemoryKiB < 64 ||
        policy.argonMemoryKiB > _maxArgonMemoryKiB ||
        policy.argonIterations < 1 ||
        policy.argonIterations > _maxArgonIterations ||
        policy.minimumPasswordCharacters < 1 ||
        policy.minimumPasswordCharacters > 1024) {
      throw const NazaPostQuantumException(
        'invalid_crypto_policy',
        'The recovery cryptographic policy is outside supported safety limits.',
      );
    }
  }

  static Uint8List _decodeBase64Field(
    Map<String, Object?> map,
    String field, {
    int? exactLength,
    int? maxLength,
    bool allowEmpty = false,
    required String materialCode,
  }) {
    final encoded = map[field];
    if (encoded is! String || (!allowEmpty && encoded.isEmpty)) {
      throw NazaPostQuantumException(
        materialCode,
        'Recovery material contains an invalid $field field.',
      );
    }
    try {
      final decoded = Uint8List.fromList(base64Decode(encoded));
      if ((exactLength != null && decoded.length != exactLength) ||
          (maxLength != null && decoded.length > maxLength)) {
        _zero(decoded);
        throw const FormatException('Decoded field length is invalid.');
      }
      return decoded;
    } catch (error) {
      if (error is NazaPostQuantumException) rethrow;
      throw NazaPostQuantumException(
        materialCode,
        'Recovery material contains an invalid $field field.',
        error,
      );
    }
  }

  static int _integer(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  static bool _constantTimeText(String a, String b) {
    var difference = a.length ^ b.length;
    final length = math.min(a.length, b.length);
    for (var i = 0; i < length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  static Uint8List _randomBytes(int length) {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static void _zero(List<int>? bytes) {
    if (bytes == null) return;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}

Future<Uint8List> _derivePasswordKey(
  String password,
  Uint8List salt,
  int memoryKiB,
  int iterations,
) async {
  if (salt.length != 16 ||
      memoryKiB < 64 ||
      memoryKiB > _maxArgonMemoryKiB ||
      iterations < 1 ||
      iterations > _maxArgonIterations) {
    throw const NazaPostQuantumException(
      'unsafe_kdf',
      'The recovery-key KDF parameters are unsafe or unsupported.',
    );
  }
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  try {
    final result = await Isolate.run<List<int>>(() async {
      final algorithm = Argon2id(
        parallelism: 1,
        memory: memoryKiB,
        iterations: iterations,
        hashLength: 32,
      );
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(passwordBytes),
        nonce: salt,
      );
      return key.extractBytes();
    });
    return Uint8List.fromList(result);
  } finally {
    for (var i = 0; i < passwordBytes.length; i++) {
      passwordBytes[i] = 0;
    }
  }
}
