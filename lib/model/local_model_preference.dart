import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';

import '../security/secure_database.dart';
import 'model_distribution_manifest.dart';

final class NazaLocalModelSelection {
  const NazaLocalModelSelection({
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.source,
  });

  final String path;
  final String sha256;
  final int bytes;
  final String source;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'naza-local-model-selection-v1',
        'path': path,
        'sha256': sha256,
        'bytes': bytes,
        'source': source,
      };

  static NazaLocalModelSelection? fromJson(Object? raw) {
    if (raw is! Map || raw['schema'] != 'naza-local-model-selection-v1') {
      return null;
    }
    final path = raw['path']?.toString().trim() ?? '';
    final sha = raw['sha256']?.toString().trim().toLowerCase() ?? '';
    final bytes = (raw['bytes'] as num?)?.toInt() ?? -1;
    final source = raw['source']?.toString().trim() ?? 'local-file';
    if (path.isEmpty || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) || bytes <= 0) {
      return null;
    }
    return NazaLocalModelSelection(
      path: path,
      sha256: sha,
      bytes: bytes,
      source: source,
    );
  }
}

/// Stores only the path/identity metadata in the encrypted vault. Model bytes
/// remain public and are not copied into SQLite.
final class NazaLocalModelPreference {
  NazaLocalModelPreference({
    NazaSecureDatabase? database,
    NazaModelDistributionManifest? manifest,
  })  : _database = database ?? NazaSecureDatabase.instance,
        _manifest = manifest ?? NazaModelDistributionManifest.gemma4E2b;

  static const String namespace = 'naza-model-preference-v1';
  static const String key = 'desktop-local-model';

  final NazaSecureDatabase _database;
  final NazaModelDistributionManifest _manifest;

  bool get desktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<NazaLocalModelSelection?> read() async {
    if (!_database.isUnlocked) return null;
    final value = await _database.readJson(namespace, key);
    return NazaLocalModelSelection.fromJson(value);
  }

  Future<void> clear() async {
    if (!_database.isUnlocked) return;
    await _database.delete(namespace, key);
  }

  Future<NazaLocalModelSelection> verifyAndPersist(
    File file, {
    String source = 'local-file',
  }) async {
    final selection = await verify(file, source: source);
    if (!_database.isUnlocked) {
      throw const NazaVaultException(
        'vault_locked',
        'Unlock the encrypted vault before saving a local model preference.',
      );
    }
    await _database.writeJson(namespace, key, selection.toJson());
    return selection;
  }

  Future<NazaLocalModelSelection> verify(
    File file, {
    String source = 'local-file',
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Selected model file does not exist.', file.path);
    }
    final bytes = await file.length();
    if (bytes != _manifest.expectedBytes) {
      throw StateError(
        'Selected model has the wrong size. Expected ${_manifest.expectedBytes} bytes, got $bytes.',
      );
    }
    final digest = (await crypto.sha256.bind(file.openRead()).first)
        .toString()
        .toLowerCase();
    if (!_constantTimeEquals(digest, _manifest.expectedSha256.toLowerCase())) {
      throw StateError(
        'Selected model SHA-256 does not match the trusted Gemma model.',
      );
    }
    return NazaLocalModelSelection(
      path: file.absolute.path,
      sha256: digest,
      bytes: bytes,
      source: source,
    );
  }

  /// Environment override is intentionally preserved for developer/admin use.
  /// It outranks the encrypted GUI preference but must pass the same hash/size
  /// verification before first-run accepts it.
  Future<NazaLocalModelSelection?> verifiedEnvironmentOverride() async {
    if (!desktop) return null;
    final raw = Platform.environment['NAZA_MODEL_PATH']?.trim();
    if (raw == null || raw.isEmpty) return null;
    final root = File(raw);
    final candidates = <File>[
      root,
      File('$raw/${_manifest.modelFileName}'),
      File('$raw/model.litertlm'),
    ];
    for (final candidate in candidates) {
      try {
        return await verify(candidate, source: 'NAZA_MODEL_PATH');
      } catch (_) {}
    }
    return null;
  }

  Future<NazaLocalModelSelection?> verifiedPersistedSelection() async {
    if (!desktop) return null;
    final saved = await read();
    if (saved == null) return null;
    try {
      return await verify(File(saved.path), source: saved.source);
    } catch (_) {
      return null;
    }
  }

  /// Makes a verified desktop selection visible to the existing app model
  /// store. Prefer a link to avoid duplicating a ~2.4 GiB model; fall back to a
  /// byte-for-byte copy when the host cannot create a link (for example a
  /// Windows volume/privilege restriction).
  Future<File> materializeForApp(NazaLocalModelSelection selection) async {
    final source = File(selection.path);
    await verify(source, source: selection.source);
    final support = await getApplicationSupportDirectory();
    final target = File('${support.path}/verified_models/${_manifest.modelFileName}');
    await target.parent.create(recursive: true);

    if (target.absolute.path == source.absolute.path) return target;
    if (await target.exists()) {
      try {
        final existing = await verify(target, source: 'managed-cache');
        if (_constantTimeEquals(existing.sha256, selection.sha256)) return target;
      } catch (_) {}
      await target.delete();
    }
    final link = Link(target.path);
    if (await link.exists()) await link.delete();

    var linked = false;
    if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'cmd',
          <String>['/c', 'mklink', '/H', target.path, source.path],
          runInShell: false,
        );
        linked = result.exitCode == 0 && await target.exists();
      } catch (_) {}
    } else {
      try {
        await link.create(source.absolute.path);
        linked = await link.exists();
      } catch (_) {}
    }

    if (!linked) {
      if (await link.exists()) await link.delete();
      await source.copy(target.path);
    }

    await verify(target, source: linked ? 'managed-link' : 'managed-copy');
    return target;
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }
}
