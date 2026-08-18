// LLM-CONTEXT:BEGIN
// FILE: lib/onboarding/boot_coordinator.dart
// ROLE: Owns boot coordinator behavior within the onboarding subsystem.
// DOMAIN: onboarding
// SECURITY-INVARIANT: Complete vault establishment and artifact verification before entering private application surfaces.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart' as app;
import '../model/local_model_preference.dart';
import '../model/model_distribution_manifest.dart';
import '../model/multiplane_model_downloader.dart';
import '../model/pausable_model_downloader.dart';
import '../model/runtime_mirror_catalog.dart';
import '../security/secure_database.dart';
import 'boot_theme_catalog.dart';

enum _BootStage { loading, security, model, guide, themes, preparing, home }

final class NazaBootDiagnostics {
  NazaBootDiagnostics._();

  static final Stopwatch _clock = Stopwatch()..start();

  static void log(String message) {
    developer.log(
      '[+${_clock.elapsedMilliseconds}ms] $message',
      name: 'NazaBoot',
    );
  }

  static void failure(String step, Object error, StackTrace stackTrace) {
    developer.log(
      '[+${_clock.elapsedMilliseconds}ms] FAIL $step: $error',
      name: 'NazaBoot',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Naza's vault-first startup coordinator.
///
/// First-run order is intentionally explicit:
/// 1. establish encrypted storage (passwordless secure-storage mode by default),
/// 2. obtain/verify the model,
/// 3. optional AI/product guide,
/// 4. theme selection,
/// 5. open Chat; native AI loading begins only when the user sends a prompt.
final class NazaBootCoordinator extends StatefulWidget {
  const NazaBootCoordinator({super.key});

  static Future<void> launch() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Color(0xFF020806),
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
    runApp(const NazaBootCoordinator());
  }

  @override
  State<NazaBootCoordinator> createState() => _NazaBootCoordinatorState();
}

final class _NazaBootCoordinatorState extends State<NazaBootCoordinator> {
  static const String _onboardingNamespace = 'naza-first-run-v3';
  static const String _onboardingCompleteKey = 'complete';

  final NazaSecureDatabase _vault = NazaSecureDatabase.instance;
  final NazaLocalModelPreference _localPreference = NazaLocalModelPreference();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _unlockPassword = TextEditingController();
  final PageController _guideController = PageController();

  _BootStage _stage = _BootStage.loading;
  // Headless Linux sessions commonly have no unlocked Secret Service. Use
  // explicit password protection by default so first launch is reliable.
  bool _requirePassword = Platform.isLinux;
  bool _existingPasswordVault = false;
  bool _busy = false;
  bool _useLocalModel = false;
  bool _downloadPaused = false;
  bool _modelReady = false;
  String? _error;
  String _status = 'Preparing private local storage…';
  String _themeId = NazaBootThemeCatalog.defaultId;
  int _guidePage = 0;
  NazaDownloadSnapshot? _download;
  NazaDownloadSnapshot? _pendingDownload;
  NazaTransferController? _transferControl;
  NazaPausableModelDownloader? _activeDownloader;
  Timer? _downloadPaintTimer;
  DateTime _lastDownloadPaint = DateTime.fromMillisecondsSinceEpoch(0);
  String? _cachedThemeId;
  ThemeData? _cachedTheme;

  NazaBootTheme get _theme => NazaBootThemeCatalog.byId(_themeId);
  ThemeData get _themeData {
    if (_cachedThemeId != _themeId || _cachedTheme == null) {
      _cachedThemeId = _themeId;
      _cachedTheme = _theme.build();
    }
    return _cachedTheme!;
  }

  bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<T> _trace<T>(String step, Future<T> Function() operation) async {
    final timer = Stopwatch()..start();
    NazaBootDiagnostics.log('START $step');
    try {
      final result = await operation();
      NazaBootDiagnostics.log('DONE $step in ${timer.elapsedMilliseconds}ms');
      return result;
    } catch (error, stackTrace) {
      NazaBootDiagnostics.failure(
        '$step after ${timer.elapsedMilliseconds}ms',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    NazaBootDiagnostics.log('coordinator initialized');
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    _unlockPassword.dispose();
    _guideController.dispose();
    _downloadPaintTimer?.cancel();
    _transferControl?.cancel();
    unawaited(_activeDownloader?.close());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final inspection = await _trace('vault inspection', _vault.inspect);
      NazaBootDiagnostics.log(
        'vault inspection result: access=${inspection.access.name}, '
        'passwordRequired=${inspection.passwordRequired}, '
        'legacyDataPresent=${inspection.legacyDataPresent}',
      );
      if (!mounted) return;
      switch (inspection.access) {
        case NazaVaultAccess.setupRequired:
          setState(() {
            _stage = _BootStage.security;
            _existingPasswordVault = false;
            _requirePassword =
                false; // UX default: encrypted, no boot password.
            _status = 'Choose how Naza One unlocks on this device.';
          });
          return;
        case NazaVaultAccess.locked:
          if (inspection.passwordRequired) {
            setState(() {
              _stage = _BootStage.security;
              _existingPasswordVault = true;
              _requirePassword = true;
              _status = 'Unlock your encrypted Naza One vault.';
            });
            return;
          }
          await _trace('device-key vault unlock', _vault.unlockWithDeviceKey);
          await _trace(
            'post-unlock startup handoff',
            () => _afterVaultUnlocked(),
          );
          return;
        case NazaVaultAccess.unlocked:
          await _trace(
            'already-unlocked startup handoff',
            () => _afterVaultUnlocked(),
          );
          return;
      }
    } catch (error, stackTrace) {
      NazaBootDiagnostics.failure('bootstrap', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _stage = _BootStage.security;
        _error = '$error';
        _status = 'Encrypted storage needs attention.';
      });
    }
  }

  Future<void> _createVault() async {
    if (_busy) return;
    if (Platform.isLinux) _requirePassword = true;
    final password = _password.text;
    if (_requirePassword) {
      if (password.length < 12) {
        setState(
          () => _error = 'Use at least 12 characters for the boot password.',
        );
        return;
      }
      if (password != _confirmPassword.text) {
        setState(() => _error = 'The two passwords do not match.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = _requirePassword
          ? 'Deriving encrypted vault keys…'
          : 'Creating encrypted vault + protected device unlock key…';
    });
    try {
      await _trace(
        'vault creation',
        () => _vault.create(
          password: _requirePassword ? password : '',
          passwordRequired: _requirePassword,
        ),
      );
      await _trace(
        'post-create startup handoff',
        () => _afterVaultUnlocked(firstRun: true),
      );
    } catch (error, stackTrace) {
      NazaBootDiagnostics.failure('create vault flow', error, stackTrace);
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockVault() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Authenticating encrypted vault…';
    });
    try {
      await _trace(
        'password vault unlock',
        () => _vault.unlock(_unlockPassword.text),
      );
      await _trace(
        'post-password-unlock startup handoff',
        () => _afterVaultUnlocked(),
      );
    } catch (error, stackTrace) {
      NazaBootDiagnostics.failure('password unlock flow', error, stackTrace);
      if (mounted) setState(() => _error = 'Unlock failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterVaultUnlocked({bool firstRun = false}) async {
    await _trace<void>('read saved theme', app.NazaThemeStore.load);
    final savedThemeId = app.NazaThemeStore.selectedId.value;
    final completeRaw = await _trace(
      'read onboarding completion marker',
      () => _vault.readJson(_onboardingNamespace, _onboardingCompleteKey),
    );
    final complete = completeRaw is Map && completeRaw['complete'] == true;

    if (!mounted) return;
    setState(() {
      _themeId = NazaBootThemeCatalog.byId(savedThemeId).id;
      _stage = _BootStage.loading;
      _status = 'Checking trusted local model…';
      _error = null;
    });

    // Check the managed cache first. Re-validating a persisted Windows local
    // model preference here can hash a multi-gigabyte file before the model
    // store gets a chance to use its existing attestation.
    var modelStatus = await _trace(
      'managed model cache refresh',
      app.NazaSecureModelStore.refresh,
    );
    NazaBootDiagnostics.log(
      'managed model cache refresh result: installed=${modelStatus.installed}, '
      'phase=${modelStatus.phase}',
    );
    if (!modelStatus.installed) {
      if (mounted) {
        setState(() => _status = 'Verifying selected local model…');
      }
      await _trace(
        'restore preferred local model',
        _restorePreferredLocalModel,
      );
      modelStatus = await _trace(
        'managed model cache refresh after local restore',
        app.NazaSecureModelStore.refresh,
      );
      NazaBootDiagnostics.log(
        'post-restore model cache result: installed=${modelStatus.installed}, '
        'phase=${modelStatus.phase}',
      );
    }
    _modelReady = modelStatus.installed;

    if (!mounted) return;
    if (complete && _modelReady && !firstRun) {
      // _unlockVault keeps the coordinator busy while authenticating. Allow
      // the authenticated startup handoff to take ownership of that same
      // busy state; otherwise _prepareAndEnterChat would return immediately
      // and leave the coordinator on the loading screen forever.
      await _trace(
        'authenticated automatic chat handoff',
        () => _prepareAndEnterChat(markComplete: false, allowBusyHandoff: true),
      );
      return;
    }
    setState(() {
      _stage = _BootStage.model;
      _status = _modelReady
          ? 'Verified model is ready.'
          : 'Choose how to install the verified local AI model.';
    });
  }

  Future<void> _restorePreferredLocalModel() async {
    if (!_desktop) {
      NazaBootDiagnostics.log(
        'skip local preference restore: non-desktop platform',
      );
      return;
    }
    try {
      final env = await _trace(
        'verify NAZA_MODEL_PATH override',
        _localPreference.verifiedEnvironmentOverride,
      );
      if (env != null) {
        NazaBootDiagnostics.log('verified environment model override found');
        await _trace(
          'materialize environment model into managed cache',
          () => _localPreference.materializeForApp(env),
        );
        return;
      }
      final persisted = await _trace(
        'verify persisted local model selection',
        _localPreference.verifiedPersistedSelection,
      );
      if (persisted != null) {
        NazaBootDiagnostics.log(
          'verified persisted local model selection found',
        );
        await _trace(
          'materialize persisted model into managed cache',
          () => _localPreference.materializeForApp(persisted),
        );
      } else {
        NazaBootDiagnostics.log('no verified local model preference found');
      }
    } catch (error, stackTrace) {
      // Model screen will expose the managed-cache state and allow recovery.
      NazaBootDiagnostics.failure(
        'restore preferred local model (falling back to model screen)',
        error,
        stackTrace,
      );
    }
  }

  Future<File> _managedModelTarget() async {
    final support = await getApplicationSupportDirectory();
    return File(
      '${support.path}/verified_models/${NazaModelDistributionManifest.gemma4E2b.modelFileName}',
    );
  }

  Future<void> _startDownload() async {
    if (_busy || _modelReady) {
      if (_modelReady) _goToGuide();
      return;
    }
    _downloadPaintTimer?.cancel();
    _downloadPaintTimer = null;
    setState(() {
      _busy = true;
      _error = null;
      _download = null;
      _pendingDownload = null;
      _downloadPaused = false;
      _status = 'Loading signed-in-app mirror identity…';
    });

    final control = NazaTransferController();
    _transferControl = control;
    try {
      final manifest = await NazaRuntimeMirrorCatalog.resolve(
        NazaModelDistributionManifest.gemma4E2b,
      );
      final downloader = NazaPausableModelDownloader(
        manifest: manifest,
        control: control,
      );
      _activeDownloader = downloader;
      final target = await _managedModelTarget();
      await downloader.download(
        target: target,
        onProgress: _publishDownloadProgress,
      );
      await downloader.close();
      _activeDownloader = null;
      final refreshed = await app.NazaSecureModelStore.refresh();
      if (!refreshed.installed) {
        throw StateError(
          'Downloaded model passed transport verification but app trust refresh did not accept it.',
        );
      }
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _downloadPaused = false;
        _status = 'Verified model ready.';
      });
      _goToGuide();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _status =
              'Model download paused by an error. Completed chunks are kept for resume.';
        });
      }
    } finally {
      if (_activeDownloader != null) {
        await _activeDownloader!.close();
        _activeDownloader = null;
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _publishDownloadProgress(NazaDownloadSnapshot snapshot) {
    if (!mounted) return;
    final priorStage = (_pendingDownload ?? _download)?.stage;
    _pendingDownload = snapshot;
    _download = snapshot;
    if (!_downloadPaused || snapshot.stage == NazaDownloadStage.complete) {
      _status = switch (snapshot.stage) {
        NazaDownloadStage.probing => 'Preparing approved mirrors…',
        NazaDownloadStage.allocating => 'Resuming secure chunk spool…',
        NazaDownloadStage.downloading =>
          'Downloading from multiple verified transports…',
        NazaDownloadStage.verifying =>
          'Checking part hashes + final model SHA-256…',
        NazaDownloadStage.complete => 'Verified local model installed.',
      };
    }

    final now = DateTime.now();
    final stageChanged = priorStage != snapshot.stage;
    final terminal = snapshot.stage == NazaDownloadStage.complete;
    final sincePaint = now.difference(_lastDownloadPaint);
    if (stageChanged ||
        terminal ||
        sincePaint >= const Duration(milliseconds: 250)) {
      _downloadPaintTimer?.cancel();
      _downloadPaintTimer = null;
      _lastDownloadPaint = now;
      setState(() {});
      return;
    }

    _downloadPaintTimer ??= Timer(
      const Duration(milliseconds: 250) - sincePaint,
      () {
        _downloadPaintTimer = null;
        if (!mounted) return;
        _lastDownloadPaint = DateTime.now();
        setState(() {});
      },
    );
  }

  void _pauseDownload() {
    final control = _transferControl;
    if (control == null || control.isPaused || control.isCancelled) return;
    control.pause();
    setState(() {
      _downloadPaused = true;
      _status =
          'Paused — in-memory sockets are back-pressured and completed chunks stay on disk.';
    });
  }

  void _resumeDownload() {
    final control = _transferControl;
    if (control == null || !control.isPaused || control.isCancelled) return;
    control.resume();
    setState(() {
      _downloadPaused = false;
      _status = 'Resuming multi-source model transfer…';
    });
  }

  Future<void> _chooseLocalModel() async {
    if (!_desktop || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Choose the trusted Gemma .litertlm file…';
    });
    try {
      const group = XTypeGroup(
        label: 'LiteRT-LM model',
        extensions: <String>['litertlm'],
      );
      final selected = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[group],
      );
      if (selected == null) {
        if (mounted)
          setState(() => _status = 'Local model selection cancelled.');
        return;
      }
      if (mounted)
        setState(
          () => _status = 'Hashing selected model — this can take a moment…',
        );
      final preference = await _localPreference.verifyAndPersist(
        File(selected.path),
      );
      if (mounted)
        setState(
          () => _status =
              'Model hash matched. Linking into the managed verified cache…',
        );
      await _localPreference.materializeForApp(preference);
      final refreshed = await app.NazaSecureModelStore.refresh();
      if (!refreshed.installed) {
        throw StateError(
          'Verified local model could not be activated by the app model store.',
        );
      }
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status =
            'Verified local model selected and encrypted preference saved.';
      });
      _goToGuide();
    } catch (error) {
      if (mounted) setState(() => _error = 'Local model rejected: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToGuide() {
    if (!mounted) return;
    setState(() {
      _stage = _BootStage.guide;
      _guidePage = 0;
      _error = null;
    });
  }

  void _goToThemes() {
    setState(() {
      _stage = _BootStage.themes;
      _error = null;
    });
  }

  Future<void> _saveTheme(String id) async {
    final theme = NazaBootThemeCatalog.byId(id);
    setState(() => _themeId = theme.id);
    await app.NazaThemeStore.select(theme.id);
  }

  Future<void> _prepareAndEnterChat({
    bool markComplete = true,
    bool allowBusyHandoff = false,
  }) async {
    if (_busy && !allowBusyHandoff) return;
    setState(() {
      _busy = true;
      _stage = _BootStage.preparing;
      _error = null;
      _status = 'Loading local AI runtime…';
    });
    try {
      if (markComplete) {
        await _trace(
          'write onboarding completion marker',
          () => _vault.writeJson(
            _onboardingNamespace,
            _onboardingCompleteKey,
            <String, Object?>{
              'schema': 'naza-first-run-v3',
              'complete': true,
              'completedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        );
      }
      // Enter the workspace immediately. Loading a multi-gigabyte native model
      // and constructing a LiteRT conversation can take well over a minute on
      // a memory-constrained CPU device; blocking the entire app here made the
      // boot progress appear frozen. These idempotent preparations continue in
      // the background, and the first send awaits the same operations.
      unawaited(app.NazaLocalGemma.instance.prepareBackendPreference());
      unawaited(app.NazaSecureModelStore.refresh());
      if (!mounted) return;
      setState(() {
        _stage = _BootStage.home;
        _busy = false;
        _status = 'Ready';
      });
    } catch (error, stackTrace) {
      NazaBootDiagnostics.failure('chat handoff', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _BootStage.model;
        _error = 'AI runtime did not become ready: $error';
        _status =
            'Model is installed, but runtime initialization needs attention.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeData;
    if (_stage == _BootStage.home) {
      return ValueListenableBuilder<String>(
        valueListenable: app.NazaThemeStore.selectedId,
        builder: (_, themeId, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Naza One',
            theme: NazaBootThemeCatalog.byId(themeId).build(),
            home: const app.NazaStableHome(),
          );
        },
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Naza One · First Run',
      theme: theme,
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _BootBackdrop(theme: _theme)),
            SafeArea(
              // The boot route is short-lived. A cross-fade here creates an
              // opacity layer during the same first frames in which Skia is
              // compiling the shell shaders, so stage changes stay direct.
              child: switch (_stage) {
                _BootStage.loading => _loadingScreen(),
                _BootStage.security => _securityScreen(),
                _BootStage.model => _modelScreen(),
                _BootStage.guide => _guideScreen(),
                _BootStage.themes => _themeScreen(),
                _BootStage.preparing => _preparingScreen(),
                _BootStage.home => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell({
    required String eyebrow,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    final scheme = _themeData.colorScheme;
    return Center(
      key: ValueKey<String>('boot-${_stage.name}'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: scheme.surface.withValues(alpha: 0.90),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: _themeData.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                child,
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 18),
                  _messageCard(
                    Icons.error_outline_rounded,
                    _error!,
                    scheme.error,
                  ),
                ],
                if (footer != null) ...<Widget>[
                  const SizedBox(height: 22),
                  footer,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingScreen() => _shell(
    eyebrow: 'Naza One',
    title: 'Private AI, preparing locally',
    subtitle: _status,
    child: ValueListenableBuilder<app.NazaModelStoreStatus>(
      valueListenable: app.NazaSecureModelStore.status,
      builder: (_, modelStatus, _) {
        final measuredProgress = modelStatus.busy && modelStatus.progress > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            app.NazaProgressBar(
              value: modelStatus.installed
                  ? 1
                  : measuredProgress
                  ? modelStatus.progress.clamp(0, 100) / 100
                  : modelStatus.busy
                  ? null
                  : 0,
            ),
            if (modelStatus.busy) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                modelStatus.phase,
                style: TextStyle(
                  color: _themeData.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _securityScreen() {
    if (_existingPasswordVault) {
      return _shell(
        eyebrow: '1 · Security',
        title: 'Unlock your encrypted vault',
        subtitle: 'This vault was configured to require a password at startup.',
        child: Column(
          children: <Widget>[
            TextField(
              controller: _unlockPassword,
              obscureText: true,
              enabled: !_busy,
              onSubmitted: (_) => unawaited(_unlockVault()),
              decoration: const InputDecoration(
                labelText: 'Vault password',
                prefixIcon: Icon(Icons.password_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _unlockVault,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock'),
              ),
            ),
          ],
        ),
      );
    }

    return _shell(
      eyebrow: '1 · Security',
      title: 'Encrypted from the first launch',
      subtitle: Platform.isLinux
          ? 'Your vault is always encrypted. Linux uses a startup password because this session has no unlocked desktop keyring.'
          : 'Your vault is always encrypted. For the smoothest experience, Naza One defaults to a protected device unlock key. A startup password is optional.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _messageCard(
            Icons.shield_outlined,
            _requirePassword
                ? 'Password mode: Argon2id derives the key-encryption key. You will enter this password on future app starts.'
                : 'Default mode: a random unlock secret is stored in the operating system secure credential store. Your SQLite records remain AES-256-GCM encrypted.',
            _themeData.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _requirePassword,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Require a password every time Naza One starts',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                Platform.isLinux
                    ? 'Linux requires a startup password when no desktop keyring is available.'
                    : 'Opt in for a stronger interactive startup gate. Leave unchecked for secure-storage unlock with no password prompt.',
              ),
              onChanged: _busy || Platform.isLinux
                  ? null
                  : (value) => setState(() {
                      _requirePassword = value ?? false;
                      _error = null;
                    }),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            child: !_requirePassword
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: _password,
                          obscureText: true,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Create password · 12+ characters',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPassword,
                          obscureText: true,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      footer: Row(
        children: <Widget>[
          Expanded(child: Text(_status, style: _themeData.textTheme.bodySmall)),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _createVault,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _requirePassword ? 'Create encrypted vault' : 'Continue securely',
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelScreen() {
    final snapshot = _download;
    final verifying = snapshot?.stage == NazaDownloadStage.verifying;
    final complete = snapshot?.stage == NazaDownloadStage.complete;
    final measuredDownload =
        snapshot != null &&
        (snapshot.stage == NazaDownloadStage.allocating ||
            snapshot.stage == NazaDownloadStage.downloading) &&
        snapshot.receivedBytes > 0;
    final double? progressValue = _modelReady
        ? 1
        : complete
        ? 1
        : verifying
        ? null
        : measuredDownload
        ? snapshot.fraction
        : _busy
        ? null
        : 0;
    final scheme = _themeData.colorScheme;
    return _shell(
      eyebrow: '2 · Local AI model',
      title: 'Verified multi-source model setup',
      subtitle:
          'Naza can fetch 4 MiB chunks from approved HTTPS model hosts, resume completed chunks after interruption, and verify every model part plus the final SHA-256 before use.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      _modelReady ? Icons.verified_rounded : Icons.hub_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (snapshot != null &&
                        !verifying &&
                        (complete || measuredDownload))
                      Text(
                        '${snapshot.percent}%',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: app.NazaProgressBar(value: progressValue),
                ),
                const SizedBox(height: 10),
                if (snapshot != null)
                  Wrap(
                    spacing: 14,
                    runSpacing: 7,
                    children: <Widget>[
                      _metric('Received', _formatBytes(snapshot.receivedBytes)),
                      _metric('Total', _formatBytes(snapshot.totalBytes)),
                      _metric('Streams', '${snapshot.activeTransfers}'),
                      _metric(
                        'Chunks',
                        '${snapshot.completedChunks}/${snapshot.totalChunks}',
                      ),
                      _metric(
                        'Speed',
                        '${_formatBytes(snapshot.bytesPerSecond.round())}/s',
                      ),
                      _metric('Fastest', snapshot.fastestProvider ?? 'probing'),
                    ],
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (!_modelReady && !_busy)
                      FilledButton.icon(
                        onPressed: _useLocalModel
                            ? _chooseLocalModel
                            : _startDownload,
                        icon: Icon(
                          _useLocalModel
                              ? Icons.folder_open_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          _useLocalModel
                              ? 'Select & verify model'
                              : 'Download verified model',
                        ),
                      ),
                    if (_busy && _transferControl != null && !_downloadPaused)
                      OutlinedButton.icon(
                        onPressed: _pauseDownload,
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text('Pause'),
                      ),
                    if (_busy && _transferControl != null && _downloadPaused)
                      FilledButton.icon(
                        onPressed: _resumeDownload,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Resume'),
                      ),
                    if (_modelReady)
                      FilledButton.icon(
                        onPressed: _goToGuide,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continue'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_desktop) ...<Widget>[
            const SizedBox(height: 16),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _useLocalModel,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Use a local .litertlm model file instead',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Opens the native file picker. The path is saved inside the encrypted vault only after exact size + SHA-256 verification.',
                ),
                onChanged: _busy || _modelReady
                    ? null
                    : (value) =>
                          setState(() => _useLocalModel = value ?? false),
              ),
            ),
            _messageCard(
              Icons.terminal_rounded,
              'Developer override remains supported: NAZA_MODEL_PATH=/absolute/path/to/gemma-4-E2B-it.litertlm. The same trusted model hash is still required.',
              scheme.secondary,
            ),
          ],
          const SizedBox(height: 14),
          _messageCard(
            Icons.verified_user_outlined,
            'Transport location is not trust. Mirror URLs may change, but model filename, immutable revision, sizes, part hashes, and the final SHA-256 are pinned in the app.',
            scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _guideScreen() {
    final pages = _guidePages();
    return _shell(
      eyebrow: '3 · Quick guide',
      title: 'Get more out of your private AI',
      subtitle:
          'A short local guide to prompting and the main Naza One tools. Skip it any time.',
      child: SizedBox(
        height: 390,
        child: PageView.builder(
          controller: _guideController,
          itemCount: pages.length,
          onPageChanged: (value) => setState(() => _guidePage = value),
          itemBuilder: (context, index) => pages[index],
        ),
      ),
      footer: Row(
        children: <Widget>[
          TextButton(onPressed: _goToThemes, child: const Text('Skip guide')),
          const Spacer(),
          Text('${_guidePage + 1} / ${pages.length}'),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              if (_guidePage >= pages.length - 1) {
                _goToThemes();
              } else {
                _guideController.nextPage(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            icon: Icon(
              _guidePage >= pages.length - 1
                  ? Icons.palette_outlined
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              _guidePage >= pages.length - 1 ? 'Choose theme' : 'Next',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _guidePages() => <Widget>[
    _GuidePage(
      icon: Icons.psychology_alt_rounded,
      title: 'Prompt like you are briefing a collaborator',
      body:
          'Say what outcome you want, provide the important context, and specify format or constraints. You can iterate naturally; you do not need special command syntax.',
      examples: const <String>[
        '“Explain this error, then give me the smallest safe patch.”',
        '“Draft a friendly email under 150 words and preserve these three facts.”',
      ],
    ),
    _GuidePage(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Chat + private memory',
      body:
          'Chat runs on the local model. Smart Memory can retain useful context in the encrypted vault and retrieve relevant history as evidence. You can pause or clear memory in Settings.',
      examples: const <String>[
        'Use History to reopen, search, pin, rename or delete conversations.',
      ],
    ),
    _GuidePage(
      icon: Icons.image_outlined,
      title: 'Vision',
      body:
          'Attach or capture an image when a visual question matters. Naza bounds and normalizes image input locally before inference. Ask about visible details, structure, text, UI, food, or troubleshooting evidence.',
      examples: const <String>[
        'Visual appearance is evidence, not proof of hidden properties or microbiological safety.',
      ],
    ),
    _GuidePage(
      icon: Icons.route_outlined,
      title: 'Road scanner',
      body:
          'The road/safety scanner turns observations you provide into structured risk-support output. It separates observed evidence from inference and avoids pretending software transforms are physical sensors.',
      examples: const <String>[
        'Use real inspection and emergency guidance when stakes are high.',
      ],
    ),
    _GuidePage(
      icon: Icons.kitchen_outlined,
      title: 'Fridge + food intelligence',
      body:
          'Food tools can analyze selected fridge or bake images, maintain encrypted food history, compare shelf observations, and help reason about recipes and storage.',
      examples: const <String>[
        'For doneness or food safety, pair AI guidance with temperature, dates, storage history and direct inspection.',
      ],
    ),
    _GuidePage(
      icon: Icons.shield_outlined,
      title: 'Local-first security',
      body:
          'User state is encrypted at rest. Model artifacts are integrity-verified. The model is not an authorization authority: privileged security operations remain under deterministic application policy.',
      examples: const <String>[
        'You can opt into a startup password later from security settings.',
      ],
    ),
  ];

  Widget _themeScreen() {
    return _shell(
      eyebrow: '4 · Theme',
      title: 'Make Naza One yours',
      subtitle:
          'Pick a visual system. Your choice is saved inside the encrypted vault and applied immediately.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 820
              ? 4
              : constraints.maxWidth >= 580
              ? 3
              : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 1.25,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: NazaBootThemeCatalog.all.length,
            itemBuilder: (context, index) {
              final option = NazaBootThemeCatalog.all[index];
              final selected = option.id == _themeId;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => unawaited(_saveTheme(option.id)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Color.alphaBlend(
                      option.seed.withValues(
                        alpha: option.brightness == Brightness.dark
                            ? 0.22
                            : 0.14,
                      ),
                      Theme.of(context).colorScheme.surface,
                    ),
                    border: Border.all(
                      color: selected
                          ? option.seed
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _themeDot(option.seed),
                          const SizedBox(width: 5),
                          _themeDot(option.accent),
                          const Spacer(),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: option.seed,
                              size: 20,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        option.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      footer: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Selected: ${_theme.label}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _prepareAndEnterChat,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Open Chat'),
          ),
        ],
      ),
    );
  }

  Widget _preparingScreen() => _shell(
    eyebrow: '5 · Ready',
    title: 'Opening your private workspace',
    subtitle: _status,
    child: Column(
      children: <Widget>[
        const app.NazaProgressBar(value: 1),
        const SizedBox(height: 18),
        _messageCard(
          Icons.memory_rounded,
          'Chat opens now. The local model loads on your first message, with its live stage shown beside the pending reply.',
          _themeData.colorScheme.primary,
        ),
      ],
    ),
  );

  Widget _messageCard(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );

  Widget _metric(String label, String value) => Chip(
    avatar: const Icon(Icons.bolt_rounded, size: 15),
    label: Text('$label · $value'),
  );

  Widget _themeDot(Color color) => Container(
    width: 15,
    height: 15,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  static String _formatBytes(int bytes) {
    const units = <String>['B', 'KiB', 'MiB', 'GiB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit >= 2 ? 1 : 0)} ${units[unit]}';
  }
}

final class _GuidePage extends StatelessWidget {
  const _GuidePage({
    required this.icon,
    required this.title,
    required this.body,
    required this.examples,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: scheme.primary.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: scheme.primary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 14),
            for (final example in examples)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: scheme.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(example, style: const TextStyle(height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _BootBackdrop extends StatelessWidget {
  const _BootBackdrop({required this.theme});
  final NazaBootTheme theme;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final base = dark ? const Color(0xFF020504) : const Color(0xFFF8FAF9);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.seed.withValues(alpha: dark ? 0.10 : 0.05),
          base,
        ),
      ),
      // Keep the first frame a single opaque fill. The steady-state shell
      // supplies its own lightweight background after boot.
      child: const SizedBox.expand(),
    );
  }
}
