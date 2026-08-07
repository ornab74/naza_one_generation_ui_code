import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'model_manifest.dart';
import 'secure_model_downloader.dart';

enum ModelSeedState {
  unsupported,
  unavailable,
  configuring,
  attaching,
  starting,
  seeding,
  paused,
  failed,
}

class ModelSeedStatus {
  const ModelSeedStatus({
    required this.state,
    required this.message,
    this.peerCount = 0,
  });

  final ModelSeedState state;
  final String message;
  final int peerCount;

  bool get isActive => state == ModelSeedState.seeding;
}

/// Runs a Kubo IPFS node with intentionally conservative resource limits.
///
/// `dart_ipfs` remains responsible for CID parsing in the manifest. Kubo is
/// used for the actual multi-gigabyte seed because its filestore can reference
/// the already-verified model in place. This avoids making a second full model
/// copy and avoids buffering the entire file in Dart memory.
class LowResourceModelSeeder {
  LowResourceModelSeeder({
    this.enabled = true,
    this.maxConnections = 8,
    this.goMemoryLimit = '256MiB',
    this.executableOverride,
  });

  final bool enabled;
  final int maxConnections;
  final String goMemoryLimit;
  final String? executableOverride;

  Process? _daemon;
  Directory? _repoDirectory;
  ModelSeedStatus _status = const ModelSeedStatus(
    state: ModelSeedState.paused,
    message: 'Seeding has not started.',
  );

  final StreamController<ModelSeedStatus> _statusController =
      StreamController<ModelSeedStatus>.broadcast();

  ModelSeedStatus get status => _status;
  Stream<ModelSeedStatus> get statuses => _statusController.stream;

  bool get _supportsSubprocesses =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  Future<ModelSeedStatus> start({
    required VerifiedModel model,
    required ModelManifest manifest,
  }) async {
    if (!enabled) {
      return _emit(
        const ModelSeedStatus(
          state: ModelSeedState.paused,
          message: 'Low-resource model seeding is disabled.',
        ),
      );
    }

    if (!_supportsSubprocesses) {
      return _emit(
        const ModelSeedStatus(
          state: ModelSeedState.unsupported,
          message:
              'This platform cannot launch the bounded Kubo seed process.',
        ),
      );
    }

    manifest.validate();
    if (!await model.file.exists()) {
      return _emit(
        const ModelSeedStatus(
          state: ModelSeedState.failed,
          message: 'The verified model file no longer exists.',
        ),
      );
    }

    final executable = await _findKuboExecutable();
    if (executable == null) {
      return _emit(
        const ModelSeedStatus(
          state: ModelSeedState.unavailable,
          message:
              'Kubo was not found. The model remains verified but is not being seeded.',
        ),
      );
    }

    try {
      _emit(
        const ModelSeedStatus(
          state: ModelSeedState.configuring,
          message: 'Preparing the low-power IPFS seed repository.',
        ),
      );

      final support = await getApplicationSupportDirectory();
      _repoDirectory = Directory(
        '${support.path}${Platform.pathSeparator}ipfs_seed_repo',
      );
      await _repoDirectory!.create(recursive: true);

      final environment = _environment;
      if (!await File(
        '${_repoDirectory!.path}${Platform.pathSeparator}config',
      ).exists()) {
        await _runChecked(
          executable,
          const <String>['init', '--profile=lowpower'],
          environment,
          timeout: const Duration(seconds: 45),
        );
      } else {
        await _runBestEffort(
          executable,
          const <String>['config', 'profile', 'apply', 'lowpower'],
          environment,
        );
      }

      await _applyBounds(executable, environment);

      _emit(
        const ModelSeedStatus(
          state: ModelSeedState.attaching,
          message: 'Attaching the verified model without duplicating it.',
        ),
      );

      final cid = await _attachModel(
        executable: executable,
        model: model,
        manifest: manifest,
        environment: environment,
      );
      if (cid != manifest.cid) {
        throw ModelSeederException(
          'Local UnixFS CID $cid does not match manifest CID ${manifest.cid}. '
          'Use the exact publishing options documented for this app.',
        );
      }

      _emit(
        const ModelSeedStatus(
          state: ModelSeedState.starting,
          message: 'Starting the bounded IPFS seed process.',
        ),
      );

      _daemon = await Process.start(
        executable,
        const <String>['daemon', '--enable-gc'],
        environment: environment,
        runInShell: false,
        mode: ProcessStartMode.detachedWithStdio,
      );

      unawaited(_watchDaemon(_daemon!));
      return _emit(
        const ModelSeedStatus(
          state: ModelSeedState.seeding,
          message:
              'Seeding at low power: one CPU thread, bounded memory, and at most eight connections.',
        ),
      );
    } catch (error) {
      await stop();
      return _emit(
        ModelSeedStatus(
          state: ModelSeedState.failed,
          message: 'Low-resource seeding could not start: $error',
        ),
      );
    }
  }

  Future<void> stop() async {
    final daemon = _daemon;
    _daemon = null;
    if (daemon != null) {
      daemon.kill(ProcessSignal.sigterm);
      try {
        await daemon.exitCode.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        daemon.kill(ProcessSignal.sigkill);
      }
    }
    _emit(
      const ModelSeedStatus(
        state: ModelSeedState.paused,
        message: 'Model seeding is paused.',
      ),
    );
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  Map<String, String> get _environment => <String, String>{
    ...Platform.environment,
    'IPFS_PATH': _repoDirectory!.path,
    'GOMAXPROCS': '1',
    'GOMEMLIMIT': goMemoryLimit,
    'GOGC': '50',
  };

  Future<String?> _findKuboExecutable() async {
    final override = executableOverride;
    if (override != null && override.isNotEmpty) {
      if (await File(override).exists()) return override;
      return null;
    }

    final candidates = Platform.isWindows
        ? const <String>['ipfs.exe', 'kubo.exe']
        : const <String>['ipfs', 'kubo'];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(
          candidate,
          const <String>['version'],
          runInShell: false,
        ).timeout(const Duration(seconds: 5));
        if (result.exitCode == 0) return candidate;
      } catch (_) {
        // Try the next executable name.
      }
    }
    return null;
  }

  Future<void> _applyBounds(
    String executable,
    Map<String, String> environment,
  ) async {
    final lowWater = maxConnections <= 2 ? 1 : maxConnections ~/ 2;
    final commands = <List<String>>[
      const <String>[
        'config',
        '--json',
        'Experimental.FilestoreEnabled',
        'true',
      ],
      const <String>[
        'config',
        '--json',
        'Experimental.UrlstoreEnabled',
        'false',
      ],
      <String>[
        'config',
        '--json',
        'Swarm.ConnMgr.LowWater',
        '$lowWater',
      ],
      <String>[
        'config',
        '--json',
        'Swarm.ConnMgr.HighWater',
        '$maxConnections',
      ],
      const <String>[
        'config',
        'Swarm.ConnMgr.GracePeriod',
        '2m',
      ],
      const <String>[
        'config',
        '--json',
        'Discovery.MDNS.Enabled',
        'false',
      ],
      const <String>[
        'config',
        '--json',
        'Swarm.DisableBandwidthMetrics',
        'true',
      ],
      const <String>[
        'config',
        '--json',
        'Reprovider.Interval',
        '"12h"',
      ],
    ];

    for (final command in commands) {
      await _runBestEffort(executable, command, environment);
    }
  }

  Future<String> _attachModel({
    required String executable,
    required VerifiedModel model,
    required ModelManifest manifest,
    required Map<String, String> environment,
  }) async {
    final args = <String>[
      'add',
      '--quiet',
      '--pin=true',
      '--nocopy',
      ...manifest.seedProfile.kuboAddArguments,
      model.file.absolute.path,
    ];

    final result = await _runChecked(
      executable,
      args,
      environment,
      timeout: const Duration(minutes: 20),
    );
    final lines = const LineSplitter()
        .convert(result.stdout.toString().trim())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const ModelSeederException('Kubo did not return an IPFS CID.');
    }
    return lines.last.trim().split(RegExp(r'\s+')).first;
  }

  Future<ProcessResult> _runChecked(
    String executable,
    List<String> arguments,
    Map<String, String> environment, {
    required Duration timeout,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      environment: environment,
      runInShell: false,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      throw ModelSeederException(
        '${arguments.join(' ')} failed: ${result.stderr}',
      );
    }
    return result;
  }

  Future<void> _runBestEffort(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) async {
    try {
      await Process.run(
        executable,
        arguments,
        environment: environment,
        runInShell: false,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Configuration keys can vary between Kubo releases. Core safeguards
      // still remain enforced by GOMAXPROCS, GOMEMLIMIT, lowpower profile, and
      // the connection-manager bounds that are supported by stable releases.
    }
  }

  Future<void> _watchDaemon(Process daemon) async {
    await daemon.exitCode;
    if (_daemon == daemon) {
      _daemon = null;
      _emit(
        const ModelSeedStatus(
          state: ModelSeedState.failed,
          message: 'The low-resource IPFS seed process stopped unexpectedly.',
        ),
      );
    }
  }

  ModelSeedStatus _emit(ModelSeedStatus value) {
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
    return value;
  }
}

class ModelSeederException implements Exception {
  const ModelSeederException(this.message);

  final String message;

  @override
  String toString() => message;
}
