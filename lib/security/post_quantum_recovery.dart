import 'dart:convert';

import 'post_quantum_export.dart';

const _legacyPackageFormat = 'naza-hybrid-recovery-package-v1';
const _keyKitFormat = 'naza-pq-recovery-key-kit-v2';
const _backupArtifactFormat = 'naza-pq-recovery-backup-artifact-v2';
const _maxArtifactCharacters = 384 * 1024 * 1024;
const _maxKeyKitCharacters = 128 * 1024;

final class NazaRecoveryArtifactInfo {
  final NazaPostQuantumProfile profile;
  final String suite;
  final String fingerprint;
  final DateTime? createdAt;
  final bool requiresSeparateKeyKit;

  const NazaRecoveryArtifactInfo({
    required this.profile,
    required this.suite,
    required this.fingerprint,
    required this.createdAt,
    required this.requiresSeparateKeyKit,
  });
}

final class NazaRecoveryRestoreMaterial {
  final String encryptedBackupJson;
  final String encryptedPrivateKeyJson;
  final String publicKeyJson;
  final NazaRecoveryArtifactInfo info;

  const NazaRecoveryRestoreMaterial({
    required this.encryptedBackupJson,
    required this.encryptedPrivateKeyJson,
    required this.publicKeyJson,
    required this.info,
  });
}

final class NazaRecoverySigningMaterial {
  final String encryptedPrivateKeyJson;
  final NazaPostQuantumBundleInfo info;

  const NazaRecoverySigningMaterial({
    required this.encryptedPrivateKeyJson,
    required this.info,
  });
}

/// Versioned outer artifact codec for separated default recovery and legacy
/// one-file restoration. Cryptographic validation remains in
/// [NazaPostQuantumExport]; this layer binds the duplicated manifest fields so
/// UI convenience metadata cannot silently disagree with encrypted material.
final class NazaPostQuantumRecoveryCodec {
  const NazaPostQuantumRecoveryCodec._();

  static String buildKeyKit(NazaRecoveryBundle bundle) {
    if (bundle.profile != NazaPostQuantumProfile.maximumHybrid) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'Separated recovery key kits require the maximum hybrid profile.',
      );
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': _keyKitFormat,
      'profile': bundle.profile.wireName,
      'suite': bundle.suite,
      'fingerprint': bundle.fingerprint,
      'publicKey': _decodeMap(bundle.publicKeyJson),
      'encryptedPrivateKey': _decodeMap(bundle.encryptedPrivateKeyJson),
      'warning':
          'Store this password-encrypted private recovery kit separately from vault backup files.',
    });
  }

  static String buildBackupArtifact({
    required String encryptedBackupJson,
    required NazaPostQuantumBundleInfo recipient,
  }) {
    if (recipient.profile != NazaPostQuantumProfile.maximumHybrid) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'Separated recovery backups require the maximum hybrid profile.',
      );
    }
    final encryptedBackup = _decodeMap(encryptedBackupJson);
    _requireMatch(
      encryptedBackup['suite'],
      recipient.suite,
      'Backup suite does not match its enrolled recipient.',
    );
    _requireMatch(
      encryptedBackup['recipientFingerprint'],
      recipient.fingerprint,
      'Backup fingerprint does not match its enrolled recipient.',
    );
    return const JsonEncoder.withIndent('  ').convert({
      'format': _backupArtifactFormat,
      'profile': recipient.profile.wireName,
      'suite': recipient.suite,
      'fingerprint': recipient.fingerprint,
      'createdAt': encryptedBackup['createdAt'],
      'encryptedBackup': encryptedBackup,
      'warning':
          'This ciphertext requires the separately stored recovery key kit and its password.',
    });
  }

  static Future<NazaRecoveryArtifactInfo> inspectBackupArtifact(
    String artifactJson,
  ) async {
    final artifact = _decodeMap(artifactJson);
    final format = artifact['format'];
    if (format == _backupArtifactFormat) {
      final backup = _requiredMap(artifact, 'encryptedBackup');
      final suite = artifact['suite']?.toString() ?? '';
      final fingerprint = artifact['fingerprint']?.toString() ?? '';
      _requireMatch(backup['suite'], suite, 'Backup suite metadata differs.');
      _requireMatch(
        backup['recipientFingerprint'],
        fingerprint,
        'Backup fingerprint metadata differs.',
      );
      _requireMatch(
        backup['createdAt'],
        artifact['createdAt'],
        'Backup creation-time metadata differs.',
      );
      if (artifact['profile'] !=
              NazaPostQuantumProfile.maximumHybrid.wireName ||
          suite != NazaPostQuantumProfile.maximumHybrid.suite ||
          fingerprint.isEmpty ||
          DateTime.tryParse(artifact['createdAt']?.toString() ?? '') == null) {
        throw const NazaPostQuantumException(
          'unsupported_suite',
          'The separated recovery backup profile is unsupported.',
        );
      }
      return NazaRecoveryArtifactInfo(
        profile: NazaPostQuantumProfile.maximumHybrid,
        suite: suite,
        fingerprint: fingerprint,
        createdAt: DateTime.tryParse(artifact['createdAt']?.toString() ?? ''),
        requiresSeparateKeyKit: true,
      );
    }
    if (format == _legacyPackageFormat) {
      final publicKey = _requiredMap(artifact, 'publicKey');
      final publicInfo = await NazaPostQuantumExport.inspectPublicKey(
        jsonEncode(publicKey),
      );
      _requireMatch(
        artifact['fingerprint'],
        publicInfo.fingerprint,
        'Legacy package fingerprint metadata differs.',
      );
      return NazaRecoveryArtifactInfo(
        profile: publicInfo.profile,
        suite: publicInfo.suite,
        fingerprint: publicInfo.fingerprint,
        createdAt: publicInfo.createdAt,
        requiresSeparateKeyKit: false,
      );
    }
    throw const NazaPostQuantumException(
      'recovery_format',
      'This is not a supported Naza recovery artifact.',
    );
  }

  static Future<NazaRecoveryRestoreMaterial> materialForRestore({
    required String backupArtifactJson,
    String? keyKitJson,
  }) async {
    final artifact = _decodeMap(backupArtifactJson);
    if (artifact['format'] == _legacyPackageFormat) {
      final publicKey = _requiredMap(artifact, 'publicKey');
      final privateKey = _requiredMap(artifact, 'encryptedPrivateKey');
      final backup = _requiredMap(artifact, 'encryptedBackup');
      await _validateBoundKeyMaterial(
        publicKey: publicKey,
        privateKey: privateKey,
        expectedSuite: NazaPostQuantumProfile.legacyHybrid.suite,
        expectedFingerprint: artifact['fingerprint']?.toString() ?? '',
      );
      _requireMatch(
        backup['suite'],
        NazaPostQuantumProfile.legacyHybrid.suite,
        'Legacy backup suite differs from its recovery key.',
      );
      _requireMatch(
        backup['recipientFingerprint'],
        artifact['fingerprint'],
        'Legacy backup recipient differs from its recovery key.',
      );
      final info = await inspectBackupArtifact(backupArtifactJson);
      return NazaRecoveryRestoreMaterial(
        encryptedBackupJson: jsonEncode(backup),
        encryptedPrivateKeyJson: jsonEncode(privateKey),
        publicKeyJson: jsonEncode(publicKey),
        info: info,
      );
    }

    if (artifact['format'] != _backupArtifactFormat) {
      throw const NazaPostQuantumException(
        'recovery_format',
        'This is not a supported Naza recovery backup.',
      );
    }
    if (keyKitJson == null || keyKitJson.trim().isEmpty) {
      throw const NazaPostQuantumException(
        'recovery_key_required',
        'This backup requires its separate post-quantum recovery key kit.',
      );
    }
    final kit = _decodeMap(keyKitJson, maxCharacters: _maxKeyKitCharacters);
    if (kit['format'] != _keyKitFormat) {
      throw const NazaPostQuantumException(
        'recovery_key_format',
        'The selected recovery key kit is unsupported.',
      );
    }
    final publicKey = _requiredMap(kit, 'publicKey');
    final privateKey = _requiredMap(kit, 'encryptedPrivateKey');
    final backup = _requiredMap(artifact, 'encryptedBackup');
    final suite = artifact['suite']?.toString() ?? '';
    final fingerprint = artifact['fingerprint']?.toString() ?? '';
    _requireMatch(
      kit['profile'],
      NazaPostQuantumProfile.maximumHybrid.wireName,
      'Recovery key profile is unsupported.',
    );
    _requireMatch(
      kit['suite'],
      suite,
      'Recovery key and backup suites differ.',
    );
    _requireMatch(
      kit['fingerprint'],
      fingerprint,
      'Recovery key and backup fingerprints differ.',
    );
    await _validateBoundKeyMaterial(
      publicKey: publicKey,
      privateKey: privateKey,
      expectedSuite: suite,
      expectedFingerprint: fingerprint,
    );
    _requireMatch(backup['suite'], suite, 'Encrypted backup suite differs.');
    _requireMatch(
      backup['recipientFingerprint'],
      fingerprint,
      'Encrypted backup recipient differs.',
    );
    final info = await inspectBackupArtifact(backupArtifactJson);
    return NazaRecoveryRestoreMaterial(
      encryptedBackupJson: jsonEncode(backup),
      encryptedPrivateKeyJson: jsonEncode(privateKey),
      publicKeyJson: jsonEncode(publicKey),
      info: info,
    );
  }

  static Future<NazaRecoverySigningMaterial> materialForBackupSigning({
    required String keyKitJson,
    required String enrolledPublicKeyJson,
  }) async {
    final kit = _decodeMap(keyKitJson, maxCharacters: _maxKeyKitCharacters);
    if (kit['format'] != _keyKitFormat ||
        kit['profile'] != NazaPostQuantumProfile.maximumHybrid.wireName ||
        kit['suite'] != NazaPostQuantumProfile.maximumHybrid.suite) {
      throw const NazaPostQuantumException(
        'recovery_key_format',
        'The selected recovery key kit is not a supported maximum-profile kit.',
      );
    }
    final enrolledPublic = _decodeMap(
      enrolledPublicKeyJson,
      maxCharacters: _maxKeyKitCharacters,
    );
    final publicKey = _requiredMap(kit, 'publicKey');
    final privateKey = _requiredMap(kit, 'encryptedPrivateKey');
    final enrolledInfo = await NazaPostQuantumExport.inspectPublicKey(
      jsonEncode(enrolledPublic),
    );
    if (enrolledInfo.profile != NazaPostQuantumProfile.maximumHybrid) {
      throw const NazaPostQuantumException(
        'unsupported_suite',
        'Backup signing requires a maximum-profile recovery identity.',
      );
    }
    _requireMatch(
      kit['fingerprint'],
      enrolledInfo.fingerprint,
      'The recovery key kit belongs to another enrolled identity.',
    );
    if (!_deepEquals(publicKey, enrolledPublic)) {
      throw const NazaPostQuantumException(
        'recovery_manifest_mismatch',
        'The recovery key kit does not match the enrolled public identity.',
      );
    }
    await _validateBoundKeyMaterial(
      publicKey: publicKey,
      privateKey: privateKey,
      expectedSuite: enrolledInfo.suite,
      expectedFingerprint: enrolledInfo.fingerprint,
    );
    return NazaRecoverySigningMaterial(
      encryptedPrivateKeyJson: jsonEncode(privateKey),
      info: enrolledInfo,
    );
  }

  static Future<void> _validateBoundKeyMaterial({
    required Map<String, Object?> publicKey,
    required Map<String, Object?> privateKey,
    required String expectedSuite,
    required String expectedFingerprint,
  }) async {
    final info = await NazaPostQuantumExport.inspectPublicKey(
      jsonEncode(publicKey),
    );
    _requireMatch(info.suite, expectedSuite, 'Recovery key suite differs.');
    _requireMatch(
      info.fingerprint,
      expectedFingerprint,
      'Recovery key fingerprint differs.',
    );
    _requireMatch(
      privateKey['suite'],
      expectedSuite,
      'Encrypted private-key suite differs.',
    );
    final embeddedPublic = privateKey['publicKey'];
    if (embeddedPublic is! Map || !_deepEquals(embeddedPublic, publicKey)) {
      throw const NazaPostQuantumException(
        'recovery_manifest_mismatch',
        'The recovery public key does not match the encrypted private kit.',
      );
    }
  }

  static Map<String, Object?> _decodeMap(
    String text, {
    int maxCharacters = _maxArtifactCharacters,
  }) {
    try {
      if (text.isEmpty || text.length > maxCharacters) {
        throw const FormatException('Recovery artifact size is invalid.');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('Expected JSON map.');
      return Map<String, Object?>.from(decoded);
    } catch (error) {
      if (error is NazaPostQuantumException) rethrow;
      throw NazaPostQuantumException(
        'invalid_encoding',
        'Recovery artifact is not valid bounded JSON.',
        error,
      );
    }
  }

  static Map<String, Object?> _requiredMap(
    Map<String, Object?> parent,
    String key,
  ) {
    final value = parent[key];
    if (value is! Map) {
      throw NazaPostQuantumException(
        'recovery_format',
        'Recovery artifact is missing its $key object.',
      );
    }
    return Map<String, Object?>.from(value);
  }

  static void _requireMatch(Object? actual, Object? expected, String message) {
    if (actual?.toString() != expected?.toString() ||
        actual?.toString().isEmpty == true) {
      throw NazaPostQuantumException('recovery_manifest_mismatch', message);
    }
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (!_deepEquals(a[index], b[index])) return false;
      }
      return true;
    }
    return a == b;
  }
}
