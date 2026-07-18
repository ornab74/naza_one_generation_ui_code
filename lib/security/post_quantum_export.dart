import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pqcrypto/pqcrypto.dart';

const _legacyPublicFormat = 'naza-pq-recovery-public-v1';
const _legacyPrivateFormat = 'naza-pq-recovery-private-v1';
const _legacyBackupFormat = 'naza-pq-backup-v1';
const _legacySuite = 'ML-KEM-768+X25519+HKDF-SHA256+AES-256-GCM';
const _advancedPublicFormat = 'naza-pq-recovery-public-v2';
const _advancedPrivateFormat = 'naza-pq-recovery-private-v2';
const _advancedBackupFormat = 'naza-pq-backup-v2';
const _advancedSuite = 'ML-KEM-1024+X25519+ML-DSA-87+HKDF-SHA512+AES-256-GCM';
const _cipher = 'AES-256-GCM';
const _argonAlgorithm = 'Argon2id-1.3';
const _signatureAlgorithm = 'ML-DSA-87';
const _originAuthenticationFormat = 'naza-pq-backup-origin-v2';
const _originSignatureContext = 'NazaOne/PQBackupOrigin/v2';
const _legacyPrivateEncoding = 'ML-KEM-768-SK||X25519-SK';
const _advancedPrivateEncoding = 'ML-KEM-1024-SK||X25519-SK||ML-DSA-87-SK';
const _maxArgonMemoryKiB = 256 * 1024;
const _maxArgonIterations = 10;
const _advancedMaxArgonMemoryKiB = 128 * 1024;
const _advancedMaxArgonIterations = 6;
const _maxPublicJsonCharacters = 64 * 1024;
const _maxPrivateJsonCharacters = 128 * 1024;
const _maxPrivateClearBytes = 16 * 1024;
const _maxBackupClearBytes = 256 * 1024 * 1024;
const _maxBackupJsonCharacters = 384 * 1024 * 1024;

enum NazaPostQuantumProfile {
  /// Read/write support for recovery packages created before the default-on
  /// maximum profile. New application flows must not select this profile.
  legacyHybrid,

  /// Category-5 ML-KEM with an independent classical X25519 component.
  maximumHybrid,
}

extension NazaPostQuantumProfileInfo on NazaPostQuantumProfile {
  String get wireName => switch (this) {
    NazaPostQuantumProfile.legacyHybrid => 'legacy-hybrid-v1',
    NazaPostQuantumProfile.maximumHybrid => 'maximum-hybrid-v2',
  };

  String get suite => switch (this) {
    NazaPostQuantumProfile.legacyHybrid => _legacySuite,
    NazaPostQuantumProfile.maximumHybrid => _advancedSuite,
  };

  bool get isDefault => this == NazaPostQuantumProfile.maximumHybrid;
}

final class _RecoverySuiteSpec {
  final NazaPostQuantumProfile profile;
  final String publicFormat;
  final String privateFormat;
  final String backupFormat;
  final String suite;
  final String privateEncoding;
  final int saltBytes;
  final String hkdfName;

  const _RecoverySuiteSpec({
    required this.profile,
    required this.publicFormat,
    required this.privateFormat,
    required this.backupFormat,
    required this.suite,
    required this.privateEncoding,
    required this.saltBytes,
    required this.hkdfName,
  });
}

const _legacySpec = _RecoverySuiteSpec(
  profile: NazaPostQuantumProfile.legacyHybrid,
  publicFormat: _legacyPublicFormat,
  privateFormat: _legacyPrivateFormat,
  backupFormat: _legacyBackupFormat,
  suite: _legacySuite,
  privateEncoding: _legacyPrivateEncoding,
  saltBytes: 16,
  hkdfName: 'HKDF-SHA256',
);

const _advancedSpec = _RecoverySuiteSpec(
  profile: NazaPostQuantumProfile.maximumHybrid,
  publicFormat: _advancedPublicFormat,
  privateFormat: _advancedPrivateFormat,
  backupFormat: _advancedBackupFormat,
  suite: _advancedSuite,
  privateEncoding: _advancedPrivateEncoding,
  saltBytes: 32,
  hkdfName: 'HKDF-SHA512',
);

enum _RecoveryMaterialKind { publicKey, privateKey, backup }

final class NazaPostQuantumPolicy {
  final int argonMemoryKiB;
  final int argonIterations;
  final int minimumPasswordCharacters;
  final NazaPostQuantumProfile profile;

  const NazaPostQuantumPolicy({
    this.argonMemoryKiB = 96 * 1024,
    this.argonIterations = 4,
    this.minimumPasswordCharacters = 16,
    this.profile = NazaPostQuantumProfile.maximumHybrid,
  });

  const NazaPostQuantumPolicy.testing({
    this.profile = NazaPostQuantumProfile.maximumHybrid,
  }) : argonMemoryKiB = 64,
       argonIterations = 1,
       minimumPasswordCharacters = 4;
}

final class NazaRecoveryBundle {
  final String publicKeyJson;
  final String encryptedPrivateKeyJson;
  final String fingerprint;
  final NazaPostQuantumProfile profile;
  final String suite;

  const NazaRecoveryBundle({
    required this.publicKeyJson,
    required this.encryptedPrivateKeyJson,
    required this.fingerprint,
    required this.profile,
    required this.suite,
  });
}

final class NazaPostQuantumBundleInfo {
  final NazaPostQuantumProfile profile;
  final String suite;
  final String fingerprint;
  final DateTime? createdAt;

  const NazaPostQuantumBundleInfo({
    required this.profile,
    required this.suite,
    required this.fingerprint,
    required this.createdAt,
  });
}

enum NazaPostQuantumRecoveryStatus {
  actionRequired,
  keyEnrolled,
  ready,
  restored,
}

/// Encrypted-vault metadata for the default post-quantum recovery policy.
/// Only public recipient material is retained; the password-encrypted private
/// recovery kit must be saved outside the live vault.
final class NazaPostQuantumRecoveryState {
  static const format = 'naza-pq-recovery-state-v2';

  final bool policyEnabled;
  final NazaPostQuantumProfile profile;
  final String suite;
  final NazaPostQuantumRecoveryStatus status;
  final String? publicKeyJson;
  final String? fingerprint;
  final DateTime? enrolledAt;
  final DateTime? lastVerifiedAt;

  const NazaPostQuantumRecoveryState({
    required this.policyEnabled,
    required this.profile,
    required this.suite,
    required this.status,
    required this.publicKeyJson,
    required this.fingerprint,
    required this.enrolledAt,
    required this.lastVerifiedAt,
  });

  factory NazaPostQuantumRecoveryState.defaults() {
    return const NazaPostQuantumRecoveryState(
      policyEnabled: true,
      profile: NazaPostQuantumProfile.maximumHybrid,
      suite: _advancedSuite,
      status: NazaPostQuantumRecoveryStatus.actionRequired,
      publicKeyJson: null,
      fingerprint: null,
      enrolledAt: null,
      lastVerifiedAt: null,
    );
  }

  factory NazaPostQuantumRecoveryState.fromJson(Map<String, dynamic> json) {
    final profileName = json['profile']?.toString();
    final profile = NazaPostQuantumProfile.values.firstWhere(
      (value) => value.wireName == profileName,
      orElse: () => NazaPostQuantumProfile.maximumHybrid,
    );
    final statusName = json['status']?.toString();
    final status = NazaPostQuantumRecoveryStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => NazaPostQuantumRecoveryStatus.actionRequired,
    );
    final publicKey = json['publicKeyJson']?.toString();
    final fingerprint = json['fingerprint']?.toString();
    final identityComplete =
        publicKey != null &&
        publicKey.isNotEmpty &&
        fingerprint != null &&
        fingerprint.isNotEmpty;
    final enrolledAt = DateTime.tryParse(json['enrolledAt']?.toString() ?? '');
    final lastVerifiedAt = DateTime.tryParse(
      json['lastVerifiedAt']?.toString() ?? '',
    );
    if (!identityComplete || enrolledAt == null) {
      return NazaPostQuantumRecoveryState.defaults();
    }
    final verificationIsValid =
        lastVerifiedAt != null && !lastVerifiedAt.isBefore(enrolledAt);
    final normalizedStatus = switch (status) {
      NazaPostQuantumRecoveryStatus.ready ||
      NazaPostQuantumRecoveryStatus.restored when !verificationIsValid =>
        NazaPostQuantumRecoveryStatus.keyEnrolled,
      NazaPostQuantumRecoveryStatus.actionRequired =>
        NazaPostQuantumRecoveryStatus.keyEnrolled,
      _ => status,
    };
    return NazaPostQuantumRecoveryState(
      // Missing/legacy settings are deliberately migrated to default-on.
      policyEnabled: true,
      profile: profile,
      suite: profile.suite,
      status: normalizedStatus,
      publicKeyJson: publicKey,
      fingerprint: fingerprint,
      enrolledAt: enrolledAt,
      lastVerifiedAt: verificationIsValid ? lastVerifiedAt : null,
    );
  }

  NazaPostQuantumRecoveryState copyWith({
    NazaPostQuantumRecoveryStatus? status,
    String? publicKeyJson,
    String? fingerprint,
    DateTime? enrolledAt,
    DateTime? lastVerifiedAt,
  }) {
    return NazaPostQuantumRecoveryState(
      policyEnabled: true,
      profile: profile,
      suite: suite,
      status: status ?? this.status,
      publicKeyJson: publicKeyJson ?? this.publicKeyJson,
      fingerprint: fingerprint ?? this.fingerprint,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'policyEnabled': true,
      'profile': profile.wireName,
      'suite': suite,
      'status': status.name,
      if (publicKeyJson != null) 'publicKeyJson': publicKeyJson,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (enrolledAt != null)
        'enrolledAt': enrolledAt!.toUtc().toIso8601String(),
      if (lastVerifiedAt != null)
        'lastVerifiedAt': lastVerifiedAt!.toUtc().toIso8601String(),
    };
  }
}

final class NazaPostQuantumException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NazaPostQuantumException(this.code, this.message, [this.cause]);

  @override
  String toString() => 'NazaPostQuantumException($code): $message';
}

/// Default recovery/export cryptography. It is deliberately isolated from the
/// local vault unlock path: ML-KEM adds meaningful separation only when the
/// recovery package is copied away from the device holding the live vault.
final class NazaPostQuantumExport {
  const NazaPostQuantumExport._();

  static final AesGcm _aes = AesGcm.with256bits();
  static final X25519 _x25519 = X25519();
  static final Sha256 _sha256 = Sha256();
  static final Sha512 _sha512 = Sha512();
  static final KyberKem _legacyMlKem = PqcKem.kyber768;
  static final KyberKem _advancedMlKem = PqcKem.kyber1024;
  static const DilithiumParams _advancedMlDsa = DilithiumParams.mlDsa87;

  static Future<NazaRecoveryBundle> generateRecoveryBundle({
    required String password,
    NazaPostQuantumPolicy policy = const NazaPostQuantumPolicy(),
  }) async {
    _validatePolicy(policy);
    _validatePassword(password, policy);
    final spec = _specForProfile(policy.profile);
    final mlKem = _kemFor(spec);
    SimpleKeyPair? xPair;
    Uint8List? mlPrivate;
    Uint8List? xPrivate;
    Uint8List? mlDsaPublic;
    Uint8List? mlDsaPrivate;
    Uint8List? passwordKey;
    Uint8List? privateClear;
    try {
      final generated = mlKem.generateKeyPair();
      final mlPublic = generated.$1;
      mlPrivate = generated.$2;
      xPair = await _x25519.newKeyPair();
      final xPublic = await xPair.extractPublicKey();
      xPrivate = Uint8List.fromList(await xPair.extractPrivateKeyBytes());
      if (spec.profile.isDefault) {
        final signingPair = await Isolate.run(
          () => MlDsa.generateKeyPair(DilithiumParams.mlDsa87),
        );
        mlDsaPublic = signingPair.$1;
        mlDsaPrivate = signingPair.$2;
      }
      final publicMap = <String, Object?>{
        'format': spec.publicFormat,
        'suite': spec.suite,
        'mlKemPublicKey': base64Encode(mlPublic),
        'x25519PublicKey': base64Encode(xPublic.bytes),
        if (spec.profile.isDefault) ...{
          'profile': spec.profile.wireName,
          'kem': 'ML-KEM-1024',
          'classicalKem': 'X25519',
          'keyDerivation': spec.hkdfName,
          'aead': _cipher,
          'backupAuthentication': _signatureAlgorithm,
          'mlDsaPublicKey': base64Encode(mlDsaPublic!),
          'keyId': base64UrlEncode(_randomBytes(18)).replaceAll('=', ''),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      };
      final fingerprint = await _fingerprint(publicMap, spec);
      publicMap['fingerprint'] = fingerprint;
      final salt = _randomBytes(spec.saltBytes);
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
      privateClear =
          Uint8List(
              mlPrivate.length + xPrivate.length + (mlDsaPrivate?.length ?? 0),
            )
            ..setAll(0, mlPrivate)
            ..setAll(mlPrivate.length, xPrivate);
      if (mlDsaPrivate != null) {
        privateClear.setAll(mlPrivate.length + xPrivate.length, mlDsaPrivate);
      }
      final aad = _privateKeyAad(publicMap, kdf, spec);
      final box = await _aes.encrypt(
        privateClear,
        secretKey: SecretKey(passwordKey),
        aad: aad,
      );
      final privateMap = <String, Object?>{
        'format': spec.privateFormat,
        'suite': spec.suite,
        if (spec.profile.isDefault) 'profile': spec.profile.wireName,
        'privateEncoding': spec.privateEncoding,
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
        profile: spec.profile,
        suite: spec.suite,
      );
    } finally {
      xPair?.destroy();
      _zero(mlPrivate);
      _zero(xPrivate);
      _zero(mlDsaPublic);
      _zero(mlDsaPrivate);
      _zero(passwordKey);
      _zero(privateClear);
    }
  }

  static Future<String> encryptBackup({
    required List<int> clearBytes,
    required String recipientPublicKeyJson,
    String? encryptedPrivateKeyJson,
    String? recoveryPassword,
    String payloadFormat = 'opaque-bytes',
    int? recordCount,
  }) async {
    if (clearBytes.length > _maxBackupClearBytes) {
      throw const NazaPostQuantumException(
        'backup_too_large',
        'The in-memory recovery backup exceeds the supported size limit.',
      );
    }
    if (payloadFormat.trim().isEmpty ||
        payloadFormat.length > 128 ||
        (recordCount != null && (recordCount < 0 || recordCount > 100000))) {
      throw const NazaPostQuantumException(
        'invalid_payload_manifest',
        'The recovery payload manifest is outside supported limits.',
      );
    }
    final parsedPublic = await _parsePublicKey(recipientPublicKeyJson);
    final publicMap = parsedPublic.$1;
    final spec = parsedPublic.$2;
    Uint8List? signingPrivateKey;
    if (spec.profile.isDefault) {
      if (encryptedPrivateKeyJson == null || recoveryPassword == null) {
        throw const NazaPostQuantumException(
          'backup_authorization_required',
          'The maximum recovery profile requires its private key kit and password to authenticate a new backup.',
        );
      }
      signingPrivateKey = await _unlockBackupSigningKey(
        encryptedPrivateKeyJson: encryptedPrivateKeyJson,
        recoveryPassword: recoveryPassword,
        recipientPublicKey: publicMap,
      );
    }
    final mlKem = _kemFor(spec);
    Uint8List? mlPublic;
    Uint8List? xPublic;
    Uint8List? mlCiphertext;
    Uint8List? mlShared;
    SimpleKeyPair? ephemeralPair;
    Uint8List? classicalShared;
    Uint8List? combined;
    Uint8List? contentKey;
    Uint8List? signature;
    try {
      mlPublic = _decodeBase64Field(
        publicMap,
        'mlKemPublicKey',
        exactLength: mlKem.params.publicKeyBytes,
        materialCode: 'invalid_public_key',
      );
      xPublic = _decodeBase64Field(
        publicMap,
        'x25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_public_key',
      );
      final encapsulated = mlKem.encapsulate(mlPublic);
      mlCiphertext = encapsulated.$1;
      mlShared = encapsulated.$2;
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
      if (classicalShared.every((byte) => byte == 0)) {
        throw const NazaPostQuantumException(
          'invalid_public_key',
          'The recovery recipient produced an invalid classical shared secret.',
        );
      }
      final createdAt = DateTime.now().toUtc().toIso8601String();
      final payloadDigest = spec.profile.isDefault
          ? await _sha512.hash(clearBytes)
          : null;
      final header = <String, Object?>{
        'format': spec.backupFormat,
        'suite': spec.suite,
        if (spec.profile.isDefault) 'profile': spec.profile.wireName,
        'cipher': _cipher,
        'recipientFingerprint': publicMap['fingerprint'],
        if (spec.profile.isDefault) 'recipientKeyId': publicMap['keyId'],
        'mlKemCiphertext': base64Encode(mlCiphertext),
        'ephemeralX25519PublicKey': base64Encode(ephemeralPublic.bytes),
        'createdAt': createdAt,
        if (spec.profile.isDefault)
          'payload': <String, Object?>{
            'format': payloadFormat,
            'length': clearBytes.length,
            'sha512': base64UrlEncode(payloadDigest!.bytes).replaceAll('=', ''),
            'recordCount': ?recordCount,
          },
      };
      final aad = _backupAad(header, spec);
      combined = _concatenateSecrets(mlShared, classicalShared);
      contentKey = await _combineSecrets(combined, aad, spec);
      final box = await _aes.encrypt(
        clearBytes,
        secretKey: SecretKey(contentKey),
        aad: aad,
      );
      final encrypted = <String, Object?>{
        ...header,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
        if (spec.profile.isDefault)
          'originAuthentication': <String, Object?>{
            'format': _originAuthenticationFormat,
            'algorithm': _signatureAlgorithm,
            'signerFingerprint': publicMap['fingerprint'],
          },
      };
      if (spec.profile.isDefault) {
        final digest = _backupOriginDigest(encrypted, spec);
        final signingKeyForIsolate = Uint8List.fromList(signingPrivateKey!);
        try {
          final generatedSignature = await Isolate.run(() {
            try {
              return MlDsa.sign(
                signingKeyForIsolate,
                digest,
                DilithiumParams.mlDsa87,
                ctx: Uint8List.fromList(utf8.encode(_originSignatureContext)),
              );
            } finally {
              signingKeyForIsolate.fillRange(0, signingKeyForIsolate.length, 0);
            }
          });
          signature = generatedSignature;
          Uint8List? signaturePublicKey;
          Uint8List? signatureForVerification;
          try {
            signaturePublicKey = _decodeBase64Field(
              publicMap,
              'mlDsaPublicKey',
              exactLength: _advancedMlDsa.publicKeyBytes,
              materialCode: 'invalid_public_key',
            );
            signatureForVerification = Uint8List.fromList(generatedSignature);
            final verified = await Isolate.run(
              () => MlDsa.verify(
                signaturePublicKey!,
                digest,
                signatureForVerification!,
                DilithiumParams.mlDsa87,
                ctx: Uint8List.fromList(utf8.encode(_originSignatureContext)),
              ),
            );
            if (!verified) {
              throw const NazaPostQuantumException(
                'backup_authorization_failed',
                'The recovery key kit cannot authenticate backups for this recovery identity.',
              );
            }
          } finally {
            _zero(signaturePublicKey);
            _zero(signatureForVerification);
          }
          encrypted['originAuthentication'] = <String, Object?>{
            ...Map<String, Object?>.from(
              encrypted['originAuthentication']! as Map,
            ),
            'signature': base64Encode(generatedSignature),
          };
        } finally {
          _zero(digest);
        }
      }
      return const JsonEncoder.withIndent('  ').convert(encrypted);
    } on NazaPostQuantumException {
      rethrow;
    } on ArgumentError catch (error) {
      throw NazaPostQuantumException(
        'invalid_public_key',
        'The recovery public key contains an invalid cryptographic value.',
        error,
      );
    } on StateError catch (error) {
      throw NazaPostQuantumException(
        'invalid_public_key',
        'The recovery public key could not be processed safely.',
        error,
      );
    } finally {
      ephemeralPair?.destroy();
      _zero(mlPublic);
      _zero(xPublic);
      _zero(mlCiphertext);
      _zero(mlShared);
      _zero(classicalShared);
      _zero(combined);
      _zero(contentKey);
      _zero(signingPrivateKey);
      _zero(signature);
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
      null,
      maxCharacters: _maxPrivateJsonCharacters,
    );
    final spec = _specForMaterial(
      privateMap,
      expectedKind: _RecoveryMaterialKind.privateKey,
    );
    final mlKem = _kemFor(spec);
    if (privateMap['format'] != spec.privateFormat ||
        privateMap['suite'] != spec.suite ||
        privateMap['cipher'] != _cipher ||
        privateMap['privateEncoding'] != spec.privateEncoding) {
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
    await _validatePublicMap(publicMap, spec);
    final kdf = Map<String, Object?>.from(kdfRaw);
    final backup = _jsonMap(
      encryptedBackupJson,
      null,
      maxCharacters: _maxBackupJsonCharacters,
    );
    final backupSpec = _specForMaterial(
      backup,
      expectedKind: _RecoveryMaterialKind.backup,
    );
    if (backupSpec.suite != spec.suite ||
        backup['format'] != spec.backupFormat ||
        backup['suite'] != spec.suite ||
        backup['cipher'] != _cipher) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery cryptographic suite is unsupported.',
      );
    }
    final advancedPayload = backup['payload'];
    if (spec.profile.isDefault &&
        (advancedPayload is! Map ||
            _integer(advancedPayload['length']) < 0 ||
            _integer(advancedPayload['length']) > _maxBackupClearBytes ||
            (advancedPayload['format']?.toString().isEmpty ?? true) ||
            (advancedPayload['sha512']?.toString().length ?? 0) != 86)) {
      throw const NazaPostQuantumException(
        'invalid_backup',
        'The advanced recovery payload manifest is malformed.',
      );
    }
    if (backup['recipientFingerprint'] != publicMap['fingerprint']) {
      throw const NazaPostQuantumException(
        'wrong_recipient',
        'This encrypted backup belongs to a different recovery key.',
      );
    }
    if (spec.profile.isDefault &&
        (privateMap['profile'] != spec.profile.wireName ||
            backup['profile'] != spec.profile.wireName ||
            backup['recipientKeyId'] != publicMap['keyId'])) {
      throw const NazaPostQuantumException(
        'wrong_recipient',
        'The advanced backup identity does not match its recovery key.',
      );
    }
    await _verifyBackupOrigin(backup, publicMap, spec);

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
      passwordKey = await _passwordKeyFromKdf(recoveryPassword, kdf, spec);
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
          aad: _privateKeyAad(publicMap, kdf, spec),
        ),
      );
      final mlPrivateLength = mlKem.params.secretKeyBytes;
      final expectedPrivateLength =
          mlPrivateLength +
          32 +
          (spec.profile.isDefault ? _advancedMlDsa.secretKeyBytes : 0);
      if (privateClear.length != expectedPrivateLength) {
        throw const NazaPostQuantumException(
          'invalid_private_key',
          'The encrypted recovery private key has an invalid length.',
        );
      }
      mlPrivate = Uint8List.fromList(
        Uint8List.sublistView(privateClear, 0, mlPrivateLength),
      );
      xPrivate = Uint8List.fromList(
        Uint8List.sublistView(
          privateClear,
          mlPrivateLength,
          mlPrivateLength + 32,
        ),
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
        exactLength: mlKem.params.ciphertextBytes,
        materialCode: 'invalid_backup',
      );
      mlShared = mlKem.decapsulate(mlPrivate, mlCiphertext);
      final ephemeralPublic = _decodeBase64Field(
        backup,
        'ephemeralX25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_backup',
      );
      if (ephemeralPublic.every((byte) => byte == 0)) {
        throw const NazaPostQuantumException(
          'invalid_backup',
          'The recovery backup contains an invalid X25519 public key.',
        );
      }
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
      if (classicalShared.every((byte) => byte == 0)) {
        throw const NazaPostQuantumException(
          'invalid_backup',
          'The recovery backup produced an invalid classical shared secret.',
        );
      }
      final header = <String, Object?>{
        'format': backup['format'],
        'suite': backup['suite'],
        if (spec.profile.isDefault) 'profile': backup['profile'],
        'cipher': backup['cipher'],
        'recipientFingerprint': backup['recipientFingerprint'],
        if (spec.profile.isDefault) 'recipientKeyId': backup['recipientKeyId'],
        'mlKemCiphertext': backup['mlKemCiphertext'],
        'ephemeralX25519PublicKey': backup['ephemeralX25519PublicKey'],
        'createdAt': backup['createdAt'],
        if (spec.profile.isDefault) 'payload': backup['payload'],
      };
      final aad = _backupAad(header, spec);
      combined = _concatenateSecrets(mlShared, classicalShared);
      contentKey = await _combineSecrets(combined, aad, spec);
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
      if (spec.profile.isDefault) {
        final payload = Map<String, Object?>.from(advancedPayload as Map);
        final digest = await _sha512.hash(clear);
        final encodedDigest = base64UrlEncode(digest.bytes).replaceAll('=', '');
        if (clear.length != _integer(payload['length']) ||
            !_constantTimeText(
              encodedDigest,
              payload['sha512']?.toString() ?? '',
            )) {
          throw const NazaPostQuantumException(
            'invalid_backup',
            'The recovered payload does not match its authenticated manifest.',
          );
        }
      }
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
    } on ArgumentError catch (error) {
      throw NazaPostQuantumException(
        'invalid_crypto_material',
        'The recovery material contains an invalid cryptographic value.',
        error,
      );
    } on StateError catch (error) {
      throw NazaPostQuantumException(
        'invalid_crypto_material',
        'The recovery material could not be processed safely.',
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

  static Future<Uint8List> _unlockBackupSigningKey({
    required String encryptedPrivateKeyJson,
    required String recoveryPassword,
    required Map<String, Object?> recipientPublicKey,
  }) async {
    _validateRecoveryPasswordInput(recoveryPassword);
    final privateMap = _jsonMap(
      encryptedPrivateKeyJson,
      null,
      maxCharacters: _maxPrivateJsonCharacters,
    );
    final spec = _specForMaterial(
      privateMap,
      expectedKind: _RecoveryMaterialKind.privateKey,
    );
    if (!spec.profile.isDefault ||
        privateMap['format'] != spec.privateFormat ||
        privateMap['suite'] != spec.suite ||
        privateMap['profile'] != spec.profile.wireName ||
        privateMap['cipher'] != _cipher ||
        privateMap['privateEncoding'] != spec.privateEncoding) {
      throw const NazaPostQuantumException(
        'backup_authorization_failed',
        'The selected recovery key kit cannot authenticate maximum-profile backups.',
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
    final embeddedPublic = Map<String, Object?>.from(publicRaw);
    await _validatePublicMap(embeddedPublic, spec);
    if (!_constantTimeText(
          embeddedPublic['fingerprint']?.toString() ?? '',
          recipientPublicKey['fingerprint']?.toString() ?? '',
        ) ||
        embeddedPublic['keyId'] != recipientPublicKey['keyId']) {
      throw const NazaPostQuantumException(
        'wrong_recipient',
        'The recovery key kit belongs to a different recovery identity.',
      );
    }
    final kdf = Map<String, Object?>.from(kdfRaw);
    Uint8List? passwordKey;
    Uint8List? privateClear;
    try {
      passwordKey = await _passwordKeyFromKdf(recoveryPassword, kdf, spec);
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
          aad: _privateKeyAad(embeddedPublic, kdf, spec),
        ),
      );
      final signingOffset = _advancedMlKem.params.secretKeyBytes + 32;
      if (privateClear.length !=
          signingOffset + _advancedMlDsa.secretKeyBytes) {
        throw const NazaPostQuantumException(
          'invalid_private_key',
          'The encrypted recovery private key has an invalid length.',
        );
      }
      return Uint8List.fromList(
        Uint8List.sublistView(privateClear, signingOffset),
      );
    } on NazaPostQuantumException {
      rethrow;
    } on SecretBoxAuthenticationError catch (error) {
      throw NazaPostQuantumException(
        'authentication_failed',
        'The recovery password is wrong or the recovery key kit was altered.',
        error,
      );
    } on FormatException catch (error) {
      throw NazaPostQuantumException(
        'invalid_encoding',
        'The recovery key kit is not valid JSON/base64.',
        error,
      );
    } on ArgumentError catch (error) {
      throw NazaPostQuantumException(
        'invalid_crypto_material',
        'The recovery key kit contains an invalid cryptographic value.',
        error,
      );
    } on StateError catch (error) {
      throw NazaPostQuantumException(
        'invalid_crypto_material',
        'The recovery key kit could not be processed safely.',
        error,
      );
    } finally {
      _zero(passwordKey);
      _zero(privateClear);
    }
  }

  static Future<void> _verifyBackupOrigin(
    Map<String, Object?> backup,
    Map<String, Object?> publicKey,
    _RecoverySuiteSpec spec,
  ) async {
    if (!spec.profile.isDefault) return;
    final authenticationRaw = backup['originAuthentication'];
    if (authenticationRaw is! Map) {
      throw const NazaPostQuantumException(
        'origin_authentication_failed',
        'The advanced recovery backup is missing its origin signature.',
      );
    }
    final authentication = Map<String, Object?>.from(authenticationRaw);
    if (authentication['format'] != _originAuthenticationFormat ||
        authentication['algorithm'] != _signatureAlgorithm ||
        authentication['signerFingerprint'] != publicKey['fingerprint']) {
      throw const NazaPostQuantumException(
        'origin_authentication_failed',
        'The advanced recovery backup has invalid origin metadata.',
      );
    }
    Uint8List? signature;
    Uint8List? signingPublicKey;
    Uint8List? digest;
    try {
      signature = _decodeBase64Field(
        authentication,
        'signature',
        exactLength: _advancedMlDsa.signatureBytes,
        materialCode: 'origin_authentication_failed',
      );
      signingPublicKey = _decodeBase64Field(
        publicKey,
        'mlDsaPublicKey',
        exactLength: _advancedMlDsa.publicKeyBytes,
        materialCode: 'invalid_public_key',
      );
      digest = _backupOriginDigest(backup, spec);
      final verified = await Isolate.run(
        () => MlDsa.verify(
          signingPublicKey!,
          digest!,
          signature!,
          DilithiumParams.mlDsa87,
          ctx: Uint8List.fromList(utf8.encode(_originSignatureContext)),
        ),
      );
      if (!verified) {
        throw const NazaPostQuantumException(
          'origin_authentication_failed',
          'The recovery backup was not signed by the enrolled recovery identity.',
        );
      }
    } finally {
      _zero(signature);
      _zero(signingPublicKey);
      _zero(digest);
    }
  }

  static Uint8List _backupOriginDigest(
    Map<String, Object?> backup,
    _RecoverySuiteSpec spec,
  ) {
    final cipherText = backup['cipherText'];
    final authenticationRaw = backup['originAuthentication'];
    if (cipherText is! String || authenticationRaw is! Map) {
      throw const NazaPostQuantumException(
        'origin_authentication_failed',
        'The advanced recovery backup cannot be authenticated.',
      );
    }
    final authentication = Map<String, Object?>.from(authenticationRaw);
    final payloadRaw = backup['payload'];
    final payload = payloadRaw is Map
        ? Map<String, Object?>.from(payloadRaw)
        : const <String, Object?>{};
    final prefix = utf8.encode(
      jsonEncode(<String, Object?>{
        'domain': _originAuthenticationFormat,
        'format': backup['format'],
        'suite': backup['suite'],
        'profile': backup['profile'],
        'cipher': backup['cipher'],
        'recipientFingerprint': backup['recipientFingerprint'],
        'recipientKeyId': backup['recipientKeyId'],
        'mlKemCiphertext': backup['mlKemCiphertext'],
        'ephemeralX25519PublicKey': backup['ephemeralX25519PublicKey'],
        'createdAt': backup['createdAt'],
        'payload': <String, Object?>{
          'format': payload['format'],
          'length': payload['length'],
          'sha512': payload['sha512'],
          if (payload.containsKey('recordCount'))
            'recordCount': payload['recordCount'],
        },
        'nonce': backup['nonce'],
        'mac': backup['mac'],
        'originAuthentication': <String, Object?>{
          'format': authentication['format'],
          'algorithm': authentication['algorithm'],
          'signerFingerprint': authentication['signerFingerprint'],
        },
        'cipherTextCharacters': cipherText.length,
        'suiteBinding': spec.suite,
      }),
    );
    final sink = _sha512.toSync().newHashSink();
    sink.add(prefix);
    sink.add(const [0]);
    const chunkCharacters = 64 * 1024;
    for (
      var offset = 0;
      offset < cipherText.length;
      offset += chunkCharacters
    ) {
      final end = math.min(offset + chunkCharacters, cipherText.length);
      // Base64 is ASCII, so code units are its canonical UTF-8 bytes.
      sink.add(cipherText.substring(offset, end).codeUnits);
    }
    sink.close();
    return Uint8List.fromList(sink.hashSync().bytes);
  }

  static Future<(Map<String, Object?>, _RecoverySuiteSpec)> _parsePublicKey(
    String json,
  ) async {
    final map = _jsonMap(json, null, maxCharacters: _maxPublicJsonCharacters);
    final spec = _specForMaterial(
      map,
      expectedKind: _RecoveryMaterialKind.publicKey,
    );
    await _validatePublicMap(map, spec);
    return (map, spec);
  }

  static Future<NazaPostQuantumBundleInfo> inspectPublicKey(
    String publicKeyJson,
  ) async {
    final parsed = await _parsePublicKey(publicKeyJson);
    final map = parsed.$1;
    final spec = parsed.$2;
    return NazaPostQuantumBundleInfo(
      profile: spec.profile,
      suite: spec.suite,
      fingerprint: map['fingerprint']!.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  static Future<void> _validatePublicMap(
    Map<String, Object?> map,
    _RecoverySuiteSpec spec,
  ) async {
    if (map['format'] != spec.publicFormat || map['suite'] != spec.suite) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery public-key suite is unsupported.',
      );
    }
    try {
      if (spec.profile.isDefault) {
        if (map['profile'] != spec.profile.wireName ||
            map['kem'] != 'ML-KEM-1024' ||
            map['classicalKem'] != 'X25519' ||
            map['keyDerivation'] != spec.hkdfName ||
            map['aead'] != _cipher ||
            map['backupAuthentication'] != _signatureAlgorithm ||
            (map['keyId']?.toString().length ?? 0) < 16 ||
            DateTime.tryParse(map['createdAt']?.toString() ?? '') == null) {
          throw const NazaPostQuantumException(
            'invalid_public_key',
            'The advanced recovery public-key metadata is malformed.',
          );
        }
        _decodeBase64Field(
          map,
          'mlDsaPublicKey',
          exactLength: _advancedMlDsa.publicKeyBytes,
          materialCode: 'invalid_public_key',
        );
      }
      final expected = await _fingerprint(map, spec);
      if (!_constantTimeText(expected, map['fingerprint']?.toString() ?? '')) {
        throw const NazaPostQuantumException(
          'public_key_fingerprint',
          'The recovery public-key fingerprint is invalid.',
        );
      }
      final xPublic = _decodeBase64Field(
        map,
        'x25519PublicKey',
        exactLength: 32,
        materialCode: 'invalid_public_key',
      );
      if (xPublic.every((byte) => byte == 0)) {
        throw const NazaPostQuantumException(
          'invalid_public_key',
          'The recovery X25519 public key is invalid.',
        );
      }
      final mlKem = _kemFor(spec);
      final mlPublic = _decodeBase64Field(
        map,
        'mlKemPublicKey',
        exactLength: mlKem.params.publicKeyBytes,
        materialCode: 'invalid_public_key',
      );
      // Validation is performed by encapsulation without using its result.
      final (ciphertext, shared) = mlKem.encapsulate(mlPublic);
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

  static Future<String> _fingerprint(
    Map<String, Object?> publicMap,
    _RecoverySuiteSpec spec,
  ) async {
    final canonical = utf8.encode(
      jsonEncode(
        spec.profile.isDefault
            ? <String, Object?>{
                'format': publicMap['format'],
                'suite': publicMap['suite'],
                'profile': publicMap['profile'],
                'kem': publicMap['kem'],
                'classicalKem': publicMap['classicalKem'],
                'keyDerivation': publicMap['keyDerivation'],
                'aead': publicMap['aead'],
                'backupAuthentication': publicMap['backupAuthentication'],
                'keyId': publicMap['keyId'],
                'createdAt': publicMap['createdAt'],
                'mlKemPublicKey': publicMap['mlKemPublicKey'],
                'x25519PublicKey': publicMap['x25519PublicKey'],
                'mlDsaPublicKey': publicMap['mlDsaPublicKey'],
              }
            : <String, Object?>{
                'format': publicMap['format'],
                'suite': publicMap['suite'],
                'mlKemPublicKey': publicMap['mlKemPublicKey'],
                'x25519PublicKey': publicMap['x25519PublicKey'],
              },
      ),
    );
    final digest = spec.profile.isDefault
        ? await _sha512.hash(canonical)
        : await _sha256.hash(canonical);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static List<int> _privateKeyAad(
    Map<String, Object?> publicMap,
    Map<String, Object?> kdf,
    _RecoverySuiteSpec spec,
  ) {
    return utf8.encode(
      jsonEncode({
        'format': spec.privateFormat,
        'suite': spec.suite,
        if (spec.profile.isDefault) 'profile': spec.profile.wireName,
        'cipher': _cipher,
        'privateEncoding': spec.privateEncoding,
        'publicKey': publicMap,
        'kdf': kdf,
      }),
    );
  }

  static List<int> _backupAad(
    Map<String, Object?> header,
    _RecoverySuiteSpec spec,
  ) {
    return utf8.encode(
      jsonEncode({
        'format': header['format'],
        'suite': header['suite'],
        if (spec.profile.isDefault) 'profile': header['profile'],
        'cipher': header['cipher'],
        'recipientFingerprint': header['recipientFingerprint'],
        if (spec.profile.isDefault) 'recipientKeyId': header['recipientKeyId'],
        'mlKemCiphertext': header['mlKemCiphertext'],
        'ephemeralX25519PublicKey': header['ephemeralX25519PublicKey'],
        'createdAt': header['createdAt'],
        if (spec.profile.isDefault) 'payload': header['payload'],
      }),
    );
  }

  static Future<Uint8List> _combineSecrets(
    List<int> combined,
    List<int> transcript,
    _RecoverySuiteSpec spec,
  ) async {
    final transcriptHash = spec.profile.isDefault
        ? await _sha512.hash(transcript)
        : await _sha256.hash(transcript);
    final hkdf = Hkdf(
      hmac: spec.profile.isDefault ? Hmac.sha512() : Hmac.sha256(),
      outputLength: 32,
    );
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(combined),
      nonce: transcriptHash.bytes,
      info: utf8.encode('${spec.backupFormat}/${spec.suite}/content-key'),
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
    _RecoverySuiteSpec spec,
  ) {
    if (kdf['algorithm'] != _argonAlgorithm ||
        _integer(kdf['parallelism']) != 1 ||
        _integer(kdf['length']) != 32) {
      throw const NazaPostQuantumException(
        'unsupported_kdf',
        'The recovery-key password KDF is unsupported.',
      );
    }
    final memoryKiB = _integer(kdf['memoryKiB']);
    final iterations = _integer(kdf['iterations']);
    if (spec.profile.isDefault &&
        (memoryKiB > _advancedMaxArgonMemoryKiB ||
            iterations > _advancedMaxArgonIterations)) {
      throw const NazaPostQuantumException(
        'unsafe_kdf',
        'The maximum-profile recovery KDF exceeds bounded resource limits.',
      );
    }
    return _derivePasswordKey(
      password,
      _decodeBase64Field(
        kdf,
        'salt',
        exactLength: spec.saltBytes,
        materialCode: 'unsafe_kdf',
      ),
      memoryKiB,
      iterations,
    );
  }

  static _RecoverySuiteSpec _specForProfile(NazaPostQuantumProfile profile) {
    return switch (profile) {
      NazaPostQuantumProfile.legacyHybrid => _legacySpec,
      NazaPostQuantumProfile.maximumHybrid => _advancedSpec,
    };
  }

  static _RecoverySuiteSpec _specForMaterial(
    Map<String, Object?> map, {
    required _RecoveryMaterialKind expectedKind,
  }) {
    final suite = map['suite']?.toString();
    final spec = switch (suite) {
      _legacySuite => _legacySpec,
      _advancedSuite => _advancedSpec,
      _ => throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery cryptographic suite is unsupported.',
      ),
    };
    final expectedFormat = switch (expectedKind) {
      _RecoveryMaterialKind.publicKey => spec.publicFormat,
      _RecoveryMaterialKind.privateKey => spec.privateFormat,
      _RecoveryMaterialKind.backup => spec.backupFormat,
    };
    if (map['format'] != expectedFormat) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'The recovery material format and cryptographic suite do not match.',
      );
    }
    return spec;
  }

  static KyberKem _kemFor(_RecoverySuiteSpec spec) {
    return spec.profile.isDefault ? _advancedMlKem : _legacyMlKem;
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
    final maxMemory = policy.profile.isDefault
        ? _advancedMaxArgonMemoryKiB
        : _maxArgonMemoryKiB;
    final maxIterations = policy.profile.isDefault
        ? _advancedMaxArgonIterations
        : _maxArgonIterations;
    if (policy.argonMemoryKiB < 64 ||
        policy.argonMemoryKiB > maxMemory ||
        policy.argonIterations < 1 ||
        policy.argonIterations > maxIterations ||
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
  if ((salt.length != 16 && salt.length != 32) ||
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
