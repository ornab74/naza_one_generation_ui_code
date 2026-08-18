// LLM-CONTEXT:BEGIN
// FILE: lib/model/local_model_preference.dart
// ROLE: Owns local model preference behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
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
    if (path.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
        bytes <= 0) {
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
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _database = database ?? NazaSecureDatabase.instance,
       _manifest = manifest ?? NazaModelDistributionManifest.gemma4E2b,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  static const String namespace = 'naza-model-preference-v1';
  static const String key = 'desktop-local-model';

  final NazaSecureDatabase _database;
  final NazaModelDistributionManifest _manifest;
  final Future<Directory> Function() _supportDirectoryProvider;

  bool get desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
      throw FileSystemException(
        'Selected model file does not exist.',
        file.path,
      );
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

  /// Copies a verified desktop selection into application-private storage.
  ///
  /// The managed artifact must be a regular snapshot rather than a symbolic or
  /// hard link. External model files can remain writable after selection, and
  /// invoking a platform command interpreter to create links would also turn
  /// the untrusted pathname into command text on Windows.
  Future<File> materializeForApp(NazaLocalModelSelection selection) async {
    final source = File(selection.path);
    await verify(source, source: selection.source);
    final support = await _supportDirectoryProvider();
    final target = File(
      '${support.path}/verified_models/${_manifest.modelFileName}',
    );
    await target.parent.create(recursive: true);

    if (target.absolute.path == source.absolute.path) return target;

    // A v2 managed preference proves this installation previously created a
    // private copy. Legacy preferences retain the external path, forcing one
    // safe copy that also replaces any old symbolic or hard link.
    final saved = await read();
    if (saved?.source == 'managed-private-copy-v2' &&
        saved?.path == target.absolute.path &&
        await target.exists()) {
      try {
        final existing = await verify(target, source: 'managed-cache');
        if (_constantTimeEquals(existing.sha256, selection.sha256))
          return target;
      } catch (_) {}
    }

    final temporary = File(
      '${target.path}.new-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await source.copy(temporary.path);
      await verify(temporary, source: 'managed-copy');
      final targetLink = Link(target.path);
      if (await targetLink.exists()) {
        await targetLink.delete();
      } else if (await target.exists()) {
        await target.delete();
      }
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }

    final managed = await verify(target, source: 'managed-private-copy-v2');
    if (_database.isUnlocked) {
      await _database.writeJson(namespace, key, managed.toJson());
    }
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
