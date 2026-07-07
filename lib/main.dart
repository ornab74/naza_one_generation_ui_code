// lib/main.dart
// Naza One — local-first Flutter UI + Gemma LiteRT-LM + AES-GCM vault.
//
// Required dependencies:
//   flutter:
//     sdk: flutter
//   flutter_gemma: ^1.2.0
//   flutter_gemma_litertlm: ^1.0.2
//   cryptography: ^2.9.0
//   path_provider: ^2.1.5
//
// Required generated assets from the asset pack:
//   assets/backgrounds/chat_river_forest.png
//   assets/backgrounds/nature_glass_mesh.png
//   assets/branding/naza_orb_512.png
//
// Required bundled model asset:
//   android/app/src/main/assets/models/gemma-4-E2B-it.litertlm

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT DESKTOP FIX:
  // Do not initialize the vault or Gemma/LiteRT runtime before runApp().
  // On Linux, the desktop plugin can block the main isolate through a long
  // platform-channel call, which makes buttons, text fields, drawers, and
  // bottom sheets feel frozen for 20-30 seconds.
  //
  // The UI now starts instantly. The local model initializes lazily only after
  // the user presses Send. Vault keys also initialize lazily only when history
  // is written/read.
  if (Platform.isAndroid || Platform.isIOS) {
    // Finish viewport-affecting platform setup before the first frame. Letting
    // these futures complete after runApp causes a second layout/inset change
    // that looks like startup flicker on mobile.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
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

  runApp(const NazaOneApp(warmModel: false));
}

final class NazaAssets {
  const NazaAssets._();

  static const String chatRiverForest =
      'assets/backgrounds/chat_river_forest.png';
  static const String glassMesh = 'assets/backgrounds/nature_glass_mesh.png';
  static const String orb512 = 'assets/branding/naza_orb_512.png';
}

final class NazaPalette {
  const NazaPalette._();

  static const Color ink = Color(0xFF06110D);
  static const Color inkDeep = Color(0xFF020806);
  static const Color panel = Color(0xCC071611);
  static const Color panelSoft = Color(0x99101E19);
  static const Color mint = Color(0xFF8DFFC4);
  static const Color mintSoft = Color(0xFFC7FFE3);
  static const Color mintDim = Color(0xFF59EFA9);
  static const Color moss = Color(0xFF208563);
  static const Color userBubble = Color(0xFF073A20);
  static const Color text = Color(0xFFF2FFF7);
  static const Color subtext = Color(0xFFA9CDBB);
  static const Color muted = Color(0xFF739080);
  static const Color border = Color(0x22FFFFFF);
  static const Color danger = Color(0xFFFF8B70);
}

final class NazaFonts {
  const NazaFonts._();

  static const String display = 'Inter';
  static const String accent = 'SpaceGrotesk';
  static const String mono = 'JetBrainsMono';
}

final class NazaAppConfig {
  const NazaAppConfig._();

  static const String appName = 'Naza One';
  static const String modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String modelPathEnvironmentVariable = 'NAZA_MODEL_PATH';
  static const String modelDownloadUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/7fa1d78473894f7e736a21d920c3aa80f950c0db/gemma-4-E2B-it.litertlm';
  static const String modelSha256 =
      'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42';
  static const String barkPackIndexUrl = String.fromEnvironment(
    'NAZA_BARKPACK_INDEX_URL',
    defaultValue:
        'https://github.com/ornab74/naza_one_generation_ui_code/releases/download/barkpack-latest/naza-barkpack-index.json',
  );
  static const String barkPackIndexSha256 = String.fromEnvironment(
    'NAZA_BARKPACK_INDEX_SHA256',
    defaultValue:
        '8f950a6dc3b6a15b35107a5fd09c3ce050fa8d27c88f5daf424b35d5d565f8f2',
  );
  static const String desktopGpuEnvironmentVariable = 'NAZA_DESKTOP_GPU';
  static const String desktopCpuEnvironmentVariable = 'NAZA_DESKTOP_CPU';
  static const int contextTokens = 3072;
  static const int outputTokens = 768;
  static const int autoContinuationPasses = 0;
  static const int streamPaintThrottleMs = 360;
  static const int telemetryThrottleMs = 500;
  static const String vaultAad = 'naza-one-vault-v2-generation-ui';
  static const String keyFileName = 'naza_one_vault.key';
  static const String historyFileName = 'naza_one_history.aesgcm.json';
  static const String runtimeFileName = 'naza_runtime_state.json';
  static const String backendPreferenceFileName =
      'naza_backend_preference.json';
  static const String barkPerformanceFileName = 'naza_bark_performance.json';

  static const String systemInstruction = '''
You are Naza One, a private on-device assistant running inside a Flutter Android app.

Identity:
- You are local-first and privacy-preserving.
- Do not claim to call a network server.
- Do not claim to use Python.
- Be calm, direct, useful, and clear.

Style:
- Nature-tech tone: glass, moss, water, clean control surfaces.
- Keep ordinary answers concise.
- Use deeper structure when the user asks for code, design, architecture, equations, or long explanations.
- For long structured answers, finish the current section before stopping and avoid ending mid-heading or mid-bullet.

Safety:
- When uncertain, state uncertainty and give the safest practical next step.
''';
}

enum NazaModelBackendPreference {
  gpuFirst,
  gpuOnly,
  cpuOnly;

  String get label {
    return switch (this) {
      NazaModelBackendPreference.gpuFirst => 'GPU first, CPU fallback',
      NazaModelBackendPreference.gpuOnly => 'GPU only',
      NazaModelBackendPreference.cpuOnly => 'CPU only',
    };
  }

  String get shortLabel {
    return switch (this) {
      NazaModelBackendPreference.gpuFirst => 'GPU first',
      NazaModelBackendPreference.gpuOnly => 'GPU only',
      NazaModelBackendPreference.cpuOnly => 'CPU only',
    };
  }

  String get description {
    return switch (this) {
      NazaModelBackendPreference.gpuFirst =>
        'Best speed when supported; safely falls back to CPU.',
      NazaModelBackendPreference.gpuOnly =>
        'Fastest path, but shows an error instead of falling back.',
      NazaModelBackendPreference.cpuOnly =>
        'Most compatible path; useful if GPU inference is unstable.',
    };
  }

  String get storageValue {
    return switch (this) {
      NazaModelBackendPreference.gpuFirst => 'gpu-first',
      NazaModelBackendPreference.gpuOnly => 'gpu-only',
      NazaModelBackendPreference.cpuOnly => 'cpu-only',
    };
  }

  static NazaModelBackendPreference fromStorage(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'gpu-only' || 'gpu' => NazaModelBackendPreference.gpuOnly,
      'cpu-only' || 'cpu' => NazaModelBackendPreference.cpuOnly,
      _ => NazaModelBackendPreference.gpuFirst,
    };
  }
}

enum NazaBarkPerformancePreset {
  eco8gb,
  balanced8gb,
  studio;

  String get label {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 'Eco 8 GB / turbo',
      NazaBarkPerformancePreset.balanced8gb => 'Balanced 8 GB',
      NazaBarkPerformancePreset.studio => 'Studio quality',
    };
  }

  String get shortLabel {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 'Eco 8GB',
      NazaBarkPerformancePreset.balanced8gb => 'Balanced',
      NazaBarkPerformancePreset.studio => 'Studio',
    };
  }

  String get description {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb =>
        'Lowest RAM and fastest CPU path for laptops.',
      NazaBarkPerformancePreset.balanced8gb =>
        'Default single-machine profile: fast, clear, bounded.',
      NazaBarkPerformancePreset.studio =>
        'More harmonic detail; slower and heavier.',
    };
  }

  String get storageValue {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 'eco-8gb',
      NazaBarkPerformancePreset.balanced8gb => 'balanced-8gb',
      NazaBarkPerformancePreset.studio => 'studio',
    };
  }

  int get sampleRate {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 16000,
      NazaBarkPerformancePreset.balanced8gb => 22050,
      NazaBarkPerformancePreset.studio => 32000,
    };
  }

  int get nativeFlags {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 1,
      NazaBarkPerformancePreset.balanced8gb => 2,
      NazaBarkPerformancePreset.studio => 4,
    };
  }

  int get maxNativeSeconds {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 120,
      NazaBarkPerformancePreset.balanced8gb => 240,
      NazaBarkPerformancePreset.studio => 420,
    };
  }

  int get maxNativeEvents {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 64,
      NazaBarkPerformancePreset.balanced8gb => 128,
      NazaBarkPerformancePreset.studio => 192,
    };
  }

  int get scriptChunkChars {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 720,
      NazaBarkPerformancePreset.balanced8gb => 920,
      NazaBarkPerformancePreset.studio => 1150,
    };
  }

  int get maxScriptChunks {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 6,
      NazaBarkPerformancePreset.balanced8gb => 10,
      NazaBarkPerformancePreset.studio => 12,
    };
  }

  int get maxDisplaySegments {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 8,
      NazaBarkPerformancePreset.balanced8gb => 12,
      NazaBarkPerformancePreset.studio => 16,
    };
  }

  double get previewSecondsCap {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => 14.0,
      NazaBarkPerformancePreset.balanced8gb => 22.0,
      NazaBarkPerformancePreset.studio => 34.0,
    };
  }

  Color get color {
    return switch (this) {
      NazaBarkPerformancePreset.eco8gb => const Color(0xFFFFCE78),
      NazaBarkPerformancePreset.balanced8gb => NazaPalette.mintSoft,
      NazaBarkPerformancePreset.studio => const Color(0xFF9AC8FF),
    };
  }

  static NazaBarkPerformancePreset fromStorage(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'eco' ||
      'eco-8gb' ||
      'turbo' ||
      'fast' => NazaBarkPerformancePreset.eco8gb,
      'studio' || 'quality' || 'hq' => NazaBarkPerformancePreset.studio,
      _ => NazaBarkPerformancePreset.balanced8gb,
    };
  }
}

final class NazaRuntimeSnapshot {
  final bool runtimeRegistered;
  final bool modelInstalled;
  final bool modelLoaded;
  final bool busy;
  final bool usingGpu;
  final int installProgress;
  final String phase;
  final String? error;
  final DateTime updatedAt;

  const NazaRuntimeSnapshot({
    required this.runtimeRegistered,
    required this.modelInstalled,
    required this.modelLoaded,
    required this.busy,
    required this.usingGpu,
    required this.installProgress,
    required this.phase,
    required this.error,
    required this.updatedAt,
  });

  factory NazaRuntimeSnapshot.initial() {
    return NazaRuntimeSnapshot(
      runtimeRegistered: false,
      modelInstalled: false,
      modelLoaded: false,
      busy: false,
      usingGpu: false,
      installProgress: 0,
      phase: 'cold-start',
      error: null,
      updatedAt: DateTime.now(),
    );
  }

  NazaRuntimeSnapshot copyWith({
    bool? runtimeRegistered,
    bool? modelInstalled,
    bool? modelLoaded,
    bool? busy,
    bool? usingGpu,
    int? installProgress,
    String? phase,
    String? error,
    bool clearError = false,
  }) {
    return NazaRuntimeSnapshot(
      runtimeRegistered: runtimeRegistered ?? this.runtimeRegistered,
      modelInstalled: modelInstalled ?? this.modelInstalled,
      modelLoaded: modelLoaded ?? this.modelLoaded,
      busy: busy ?? this.busy,
      usingGpu: usingGpu ?? this.usingGpu,
      installProgress: installProgress ?? this.installProgress,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'runtimeRegistered': runtimeRegistered,
      'modelInstalled': modelInstalled,
      'modelLoaded': modelLoaded,
      'busy': busy,
      'usingGpu': usingGpu,
      'installProgress': installProgress,
      'phase': phase,
      'error': error,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

final class NazaGenerationTelemetry {
  final bool active;
  final bool cancelled;
  final int generationId;
  final double progress;
  final int tokens;
  final int maxTokens;
  final String stage;
  final String route;
  final double routeScore;
  final DateTime startedAt;

  const NazaGenerationTelemetry({
    required this.active,
    required this.cancelled,
    required this.generationId,
    required this.progress,
    required this.tokens,
    required this.maxTokens,
    required this.stage,
    required this.route,
    required this.routeScore,
    required this.startedAt,
  });

  factory NazaGenerationTelemetry.idle() {
    return NazaGenerationTelemetry(
      active: false,
      cancelled: false,
      generationId: 0,
      progress: 0,
      tokens: 0,
      maxTokens: NazaAppConfig.outputTokens,
      stage: 'idle',
      route: 'idle',
      routeScore: 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  NazaGenerationTelemetry copyWith({
    bool? active,
    bool? cancelled,
    int? generationId,
    double? progress,
    int? tokens,
    int? maxTokens,
    String? stage,
    String? route,
    double? routeScore,
    DateTime? startedAt,
  }) {
    return NazaGenerationTelemetry(
      active: active ?? this.active,
      cancelled: cancelled ?? this.cancelled,
      generationId: generationId ?? this.generationId,
      progress: progress ?? this.progress,
      tokens: tokens ?? this.tokens,
      maxTokens: maxTokens ?? this.maxTokens,
      stage: stage ?? this.stage,
      route: route ?? this.route,
      routeScore: routeScore ?? this.routeScore,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

final class NazaVerifiedModelFile {
  final File file;
  final String sha256;
  final bool downloaded;

  const NazaVerifiedModelFile({
    required this.file,
    required this.sha256,
    required this.downloaded,
  });
}

final class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? value;

  @override
  void add(crypto.Digest data) {
    value = data;
  }

  @override
  void close() {}
}

final class NazaModelStoreStatus {
  final bool installed;
  final bool busy;
  final int progress;
  final String phase;
  final String cachePath;
  final String? localPath;
  final String? error;

  const NazaModelStoreStatus({
    required this.installed,
    required this.busy,
    required this.progress,
    required this.phase,
    required this.cachePath,
    required this.localPath,
    required this.error,
  });

  factory NazaModelStoreStatus.idle() {
    return const NazaModelStoreStatus(
      installed: false,
      busy: false,
      progress: 0,
      phase: 'model status not checked yet',
      cachePath: '',
      localPath: null,
      error: null,
    );
  }

  NazaModelStoreStatus copyWith({
    bool? installed,
    bool? busy,
    int? progress,
    String? phase,
    String? cachePath,
    String? localPath,
    String? error,
    bool clearError = false,
  }) {
    return NazaModelStoreStatus(
      installed: installed ?? this.installed,
      busy: busy ?? this.busy,
      progress: progress ?? this.progress,
      phase: phase ?? this.phase,
      cachePath: cachePath ?? this.cachePath,
      localPath: localPath ?? this.localPath,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final class NazaSecureModelStore {
  const NazaSecureModelStore._();

  static const int _maxModelBytes = 8 * 1024 * 1024 * 1024;
  static final Uri _downloadUri = Uri.parse(NazaAppConfig.modelDownloadUrl);
  static final ValueNotifier<NazaModelStoreStatus> status =
      ValueNotifier<NazaModelStoreStatus>(NazaModelStoreStatus.idle());
  static Future<NazaModelStoreStatus>? _refreshFuture;
  static Future<NazaVerifiedModelFile>? _ensureFuture;

  static Future<NazaModelStoreStatus> refresh() {
    _refreshFuture ??= _refreshInner();
    return _refreshFuture!;
  }

  static Future<NazaModelStoreStatus> _refreshInner() async {
    try {
      final target = await _targetFile();
      status.value = status.value.copyWith(
        busy: true,
        progress: 0,
        phase: 'checking verified model cache',
        cachePath: target.path,
        clearError: true,
      );

      if (await _isVerified(
        target,
        onProgress: (progress, phase) {
          status.value = status.value.copyWith(
            busy: true,
            progress: progress,
            phase: phase,
            cachePath: target.path,
            clearError: true,
          );
        },
        progressStart: 3,
        progressEnd: 45,
      )) {
        final current = NazaModelStoreStatus(
          installed: true,
          busy: false,
          progress: 100,
          phase: 'verified cached model ready',
          cachePath: target.path,
          localPath: null,
          error: null,
        );
        status.value = current;
        return current;
      }

      final local = await _verifiedLocalCandidate(
        onProgress: (progress, phase, path) {
          status.value = status.value.copyWith(
            busy: true,
            progress: progress,
            phase: phase,
            cachePath: target.path,
            localPath: path,
            clearError: true,
          );
        },
        progressStart: 46,
        progressEnd: 95,
      );
      final current = NazaModelStoreStatus(
        installed: local != null,
        busy: false,
        progress: local == null ? 0 : 100,
        phase: local == null
            ? 'model not cached; download or set ${NazaAppConfig.modelPathEnvironmentVariable}'
            : 'verified local model ready',
        cachePath: target.path,
        localPath: local?.path,
        error: null,
      );
      status.value = current;
      return current;
    } catch (error) {
      final target = await _targetFile();
      final current = NazaModelStoreStatus(
        installed: false,
        busy: false,
        progress: 0,
        phase: 'model status check failed',
        cachePath: target.path,
        localPath: null,
        error: error.toString(),
      );
      status.value = current;
      return current;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<NazaVerifiedModelFile> ensureVerifiedModel({
    void Function(int progress, String phase)? onProgress,
  }) async {
    _ensureFuture ??= _ensureVerifiedModelInner(onProgress: onProgress);
    return _ensureFuture!;
  }

  static Future<NazaVerifiedModelFile> _ensureVerifiedModelInner({
    void Function(int progress, String phase)? onProgress,
  }) async {
    _validateDownloadUri(_downloadUri);

    final target = await _targetFile();
    await target.parent.create(recursive: true);

    void publish(int progress, String phase) {
      onProgress?.call(progress, phase);
      status.value = status.value.copyWith(
        busy: true,
        progress: progress,
        phase: phase,
        cachePath: target.path,
        clearError: true,
      );
    }

    status.value = status.value.copyWith(
      busy: true,
      progress: 0,
      phase: 'checking verified model cache',
      cachePath: target.path,
      clearError: true,
    );

    try {
      if (await _isVerified(
        target,
        onProgress: publish,
        progressStart: 1,
        progressEnd: 18,
      )) {
        publish(100, 'verified cached model');
        status.value = status.value.copyWith(
          installed: true,
          busy: false,
          progress: 100,
          phase: 'verified cached model ready',
          cachePath: target.path,
          localPath: null,
          clearError: true,
        );
        return NazaVerifiedModelFile(
          file: target,
          sha256: NazaAppConfig.modelSha256,
          downloaded: false,
        );
      }

      if (await target.exists()) {
        await target.delete();
      }

      publish(1, 'checking local model path');
      final local = await _verifiedLocalCandidate(
        onProgress: (progress, phase, path) {
          status.value = status.value.copyWith(localPath: path);
          publish(progress, phase);
        },
        progressStart: 20,
        progressEnd: 62,
      );
      if (local != null) {
        status.value = status.value.copyWith(localPath: local.path);
        publish(100, 'verified local model ready');
        status.value = status.value.copyWith(
          installed: true,
          busy: false,
          progress: 100,
          phase: 'verified local model ready',
          cachePath: target.path,
          localPath: local.path,
          clearError: true,
        );
        return NazaVerifiedModelFile(
          file: local,
          sha256: NazaAppConfig.modelSha256,
          downloaded: false,
        );
      }

      await _downloadVerified(target, onProgress: publish);
      status.value = status.value.copyWith(
        installed: true,
        busy: false,
        progress: 100,
        phase: 'verified model cached',
        cachePath: target.path,
        localPath: null,
        clearError: true,
      );
      return NazaVerifiedModelFile(
        file: target,
        sha256: NazaAppConfig.modelSha256,
        downloaded: true,
      );
    } catch (error) {
      status.value = status.value.copyWith(
        installed: false,
        busy: false,
        phase: 'model install failed',
        error: error.toString(),
      );
      rethrow;
    } finally {
      _ensureFuture = null;
    }
  }

  static Future<File> _targetFile() async {
    final support = await getApplicationSupportDirectory();
    return File(
      '${support.path}/verified_models/${NazaAppConfig.modelFileName}',
    );
  }

  static Future<File?> _verifiedLocalCandidate({
    void Function(int progress, String phase, String? path)? onProgress,
    int progressStart = 0,
    int progressEnd = 100,
  }) async {
    final candidates = _localCandidates();
    if (candidates.isEmpty) return null;
    final span = math.max(1, progressEnd - progressStart);
    var checked = 0;
    for (final candidate in candidates) {
      final file = File(candidate);
      if (!await file.exists()) continue;
      final base =
          progressStart + ((checked / candidates.length) * span).floor();
      checked++;
      onProgress?.call(
        base.clamp(progressStart, progressEnd).toInt(),
        'verifying local model SHA-256',
        file.path,
      );
      try {
        _validateModelPath(file.path);
      } catch (_) {
        onProgress?.call(
          base.clamp(progressStart, progressEnd).toInt(),
          'skipping non-.litertlm local model path',
          file.path,
        );
        continue;
      }
      if (await _isVerified(
        file,
        onProgress: (progress, phase) =>
            onProgress?.call(progress, phase, file.path),
        progressStart: base.clamp(progressStart, progressEnd).toInt(),
        progressEnd: progressEnd,
      )) {
        return file;
      }
    }
    onProgress?.call(progressEnd, 'no verified local model found', null);
    return null;
  }

  static List<String> _localCandidates() {
    final configured = Platform
        .environment[NazaAppConfig.modelPathEnvironmentVariable]
        ?.trim();
    final executableModelsDir =
        '${File(Platform.resolvedExecutable).parent.path}/models';

    return <String>[
      if (configured != null &&
          configured.isNotEmpty &&
          configured.toLowerCase().endsWith('.litertlm'))
        configured,
      if (configured != null && configured.isNotEmpty)
        '$configured/${NazaAppConfig.modelFileName}',
      if (configured != null && configured.isNotEmpty)
        '$configured/model.litertlm',
      '$executableModelsDir/${NazaAppConfig.modelFileName}',
      '$executableModelsDir/model.litertlm',
    ].where((path) => path.trim().isNotEmpty).toSet().toList();
  }

  static void _validateModelPath(String path) {
    if (path.contains('\x00')) {
      throw FileSystemException('Model path contains a null byte.', path);
    }
    if (!path.toLowerCase().endsWith('.litertlm')) {
      throw FileSystemException(
        'Only .litertlm model files are accepted.',
        path,
      );
    }
  }

  static Future<void> _downloadVerified(
    File target, {
    void Function(int progress, String phase)? onProgress,
  }) async {
    final part = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    IOSink? sink;

    try {
      onProgress?.call(1, 'connecting to verified model host');
      final response = await _openSecureGet(client, _downloadUri);
      final length = response.contentLength;
      if (length > _maxModelBytes) {
        throw HttpException(
          'Model response is too large: $length bytes.',
          uri: _downloadUri,
        );
      }

      sink = part.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      var lastProgress = 0;
      onProgress?.call(2, 'downloading verified model');

      await for (final chunk in response) {
        received += chunk.length;
        if (received > _maxModelBytes) {
          throw HttpException(
            'Model download exceeded safety cap.',
            uri: _downloadUri,
          );
        }
        sink.add(chunk);

        if (length > 0) {
          final progress = (received / length * 92).floor().clamp(2, 94);
          if (progress > lastProgress) {
            lastProgress = progress;
            onProgress?.call(progress, 'downloading verified model');
          }
        }
      }

      await sink.close();
      sink = null;

      onProgress?.call(95, 'verifying model SHA-256');
      final actual = await _sha256(part);
      if (actual != NazaAppConfig.modelSha256) {
        throw FormatException(
          'Downloaded model SHA-256 mismatch. Expected '
          '${NazaAppConfig.modelSha256}, got $actual.',
        );
      }

      await part.rename(target.path);
      onProgress?.call(100, 'verified model cached');
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      if (await part.exists()) {
        await part.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<HttpClientResponse> _openSecureGet(
    HttpClient client,
    Uri uri, {
    int redirects = 0,
  }) async {
    if (redirects > 5) {
      throw HttpException('Too many redirects.', uri: uri);
    }
    _validateDownloadUri(uri);

    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      '${NazaAppConfig.appName}/1.0 secure-model-downloader',
    );

    final response = await request.close();
    if (_isRedirect(response.statusCode)) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.trim().isEmpty) {
        throw HttpException('Redirect without Location header.', uri: uri);
      }
      final next = uri.resolve(location);
      _validateDownloadUri(next);
      return _openSecureGet(client, next, redirects: redirects + 1);
    }

    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Model download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    return response;
  }

  static bool _isRedirect(int code) {
    return code == HttpStatus.movedPermanently ||
        code == HttpStatus.found ||
        code == HttpStatus.seeOther ||
        code == HttpStatus.temporaryRedirect ||
        code == HttpStatus.permanentRedirect;
  }

  static void _validateDownloadUri(Uri uri) {
    if (uri.scheme != 'https') {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'Only HTTPS is allowed.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'User info is not allowed.',
      );
    }

    final host = uri.host.toLowerCase();
    final allowed =
        host == 'huggingface.co' ||
        host.endsWith('.huggingface.co') ||
        host == 'cdn-lfs.huggingface.co' ||
        host == 'cdn.hf.co' ||
        host.endsWith('.cdn.hf.co') ||
        host == 'cdn-lfs.hf.co' ||
        (host.startsWith('cdn-lfs') && host.endsWith('.hf.co')) ||
        host == 'cas-bridge.xethub.hf.co' ||
        host.endsWith('.xethub.hf.co');
    if (!allowed) {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'Unexpected model download host.',
      );
    }
  }

  static Future<bool> _isVerified(
    File file, {
    void Function(int progress, String phase)? onProgress,
    int progressStart = 0,
    int progressEnd = 100,
  }) async {
    if (!await file.exists()) return false;
    _validateModelPath(file.path);
    final stat = await file.stat();
    if (stat.size <= 0 || stat.size > _maxModelBytes) return false;
    final actual = await _sha256WithProgress(
      file,
      onProgress: onProgress,
      progressStart: progressStart,
      progressEnd: progressEnd,
      phase: 'verifying model SHA-256',
    );
    return actual == NazaAppConfig.modelSha256;
  }

  static Future<String> _sha256(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  static Future<String> _sha256WithProgress(
    File file, {
    void Function(int progress, String phase)? onProgress,
    required int progressStart,
    required int progressEnd,
    required String phase,
    bool validateExtension = true,
  }) async {
    if (validateExtension) _validateModelPath(file.path);
    final stat = await file.stat();
    if (stat.size <= 0 || stat.size > _maxModelBytes) return '';

    final sink = _DigestSink();
    final input = crypto.sha256.startChunkedConversion(sink);
    var received = 0;
    var lastProgress = progressStart - 1;
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    final span = math.max(1, progressEnd - progressStart);

    await for (final chunk in file.openRead()) {
      received += chunk.length;
      input.add(chunk);
      final now = DateTime.now();
      final progress = (progressStart + (received / stat.size * span))
          .floor()
          .clamp(progressStart, progressEnd)
          .toInt();
      if (progress > lastProgress &&
          now.difference(lastUpdate) >= const Duration(milliseconds: 240)) {
        lastProgress = progress;
        lastUpdate = now;
        onProgress?.call(progress, phase);
      }
    }
    input.close();
    onProgress?.call(progressEnd, phase);
    return sink.value?.toString().toLowerCase() ?? '';
  }
}

final class NazaBarkPackAsset {
  final String name;
  final String asset;
  final String sha256;
  final int size;
  final String? url;

  const NazaBarkPackAsset({
    required this.name,
    required this.asset,
    required this.sha256,
    required this.size,
    this.url,
  });

  factory NazaBarkPackAsset.fromJson(Map<String, dynamic> json) {
    return NazaBarkPackAsset(
      name: json['name'] as String,
      asset: json['asset'] as String,
      sha256: (json['sha256'] as String).toLowerCase(),
      size: ((json['size'] as num?) ?? 0).toInt(),
      url: json['url'] as String?,
    );
  }
}

final class NazaBarkPackIndex {
  final String format;
  final String packFormat;
  final String quant;
  final int tensorCount;
  final NazaBarkPackAsset manifest;
  final List<NazaBarkPackAsset> shards;
  final DateTime createdAt;

  const NazaBarkPackIndex({
    required this.format,
    required this.packFormat,
    required this.quant,
    required this.tensorCount,
    required this.manifest,
    required this.shards,
    required this.createdAt,
  });

  factory NazaBarkPackIndex.fromJson(Map<String, dynamic> json) {
    return NazaBarkPackIndex(
      format: json['format'] as String,
      packFormat: json['packFormat'] as String,
      quant: (json['quant'] as String?) ?? 'unknown',
      tensorCount: ((json['tensorCount'] as num?) ?? 0).toInt(),
      manifest: NazaBarkPackAsset.fromJson(
        Map<String, dynamic>.from(json['manifest'] as Map),
      ),
      shards: ((json['shards'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => NazaBarkPackAsset.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

final class NazaBarkPackStatus {
  final bool installed;
  final bool downloading;
  final int progress;
  final String phase;
  final String packPath;
  final int tensorCount;
  final List<String> missingFamilies;
  final String qualityTier;
  final String familySummary;
  final String stageSummary;
  final String capabilitySummary;
  final String sidecarSummary;
  final String? error;

  const NazaBarkPackStatus({
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.phase,
    required this.packPath,
    required this.tensorCount,
    required this.missingFamilies,
    required this.qualityTier,
    required this.familySummary,
    required this.stageSummary,
    required this.capabilitySummary,
    required this.sidecarSummary,
    this.error,
  });

  factory NazaBarkPackStatus.idle() {
    return const NazaBarkPackStatus(
      installed: false,
      downloading: false,
      progress: 0,
      phase: 'barkpack idle',
      packPath: '',
      tensorCount: 0,
      missingFamilies: ['semantic', 'coarse', 'fine', 'codec', 'speaker'],
      qualityTier: 'not installed',
      familySummary: 'none',
      stageSummary: 'none',
      capabilitySummary: 'none',
      sidecarSummary: 'none',
    );
  }

  String get shortLine {
    final ready = installed ? 'ready' : 'not-ready';
    final missing = missingFamilies.isEmpty
        ? 'none'
        : missingFamilies.join(', ');
    return 'BarkPack $ready | $qualityTier | $progress% | tensors=$tensorCount | missing=$missing';
  }
}

final class NazaBarkTensorInfo {
  final String name;
  final String family;
  final String file;
  final List<int> shape;
  final String dtype;
  final double scale;
  final int zeroPoint;
  final int offset;
  final int length;

  const NazaBarkTensorInfo({
    required this.name,
    required this.family,
    required this.file,
    required this.shape,
    required this.dtype,
    required this.scale,
    required this.zeroPoint,
    required this.offset,
    required this.length,
  });

  factory NazaBarkTensorInfo.fromJson(Map<String, dynamic> json) {
    return NazaBarkTensorInfo(
      name: json['name'] as String,
      family: (json['family'] as String?) ?? '',
      file: json['file'] as String,
      shape: (json['shape'] as List).map((v) => (v as num).toInt()).toList(),
      dtype: (json['dtype'] as String?) ?? 'int8',
      scale: ((json['scale'] as num?) ?? 1.0).toDouble(),
      zeroPoint: ((json['zeroPoint'] as num?) ?? 0).toInt(),
      offset: ((json['offset'] as num?) ?? 0).toInt(),
      length: ((json['length'] as num?) ?? 0).toInt(),
    );
  }
}

final class NazaSecureBarkPackStore {
  NazaSecureBarkPackStore._();

  static final NazaSecureBarkPackStore instance = NazaSecureBarkPackStore._();
  static const int _maxIndexBytes = 4 * 1024 * 1024;
  static const int _maxAssetBytes = 3 * 1024 * 1024 * 1024;
  // Voice-like Bark rendering needs both the acoustic lanes and the conditioning
  // lanes. The converter generates tiny deterministic sidecars for semantic and
  // speaker if the source checkpoint does not expose obvious tensor names.
  static const List<String> _requiredFamilies = [
    'semantic',
    'coarse',
    'fine',
    'codec',
    'speaker',
  ];

  final ValueNotifier<NazaBarkPackStatus> status =
      ValueNotifier<NazaBarkPackStatus>(NazaBarkPackStatus.idle());
  Future<NazaBarkPackStatus>? _installFuture;

  Future<NazaBarkPackStatus> refresh() async {
    final current = await _describeLocal();
    status.value = current;
    return current;
  }

  Future<NazaBarkPackStatus> ensureInstalled() {
    _installFuture ??= _ensureInstalledInner();
    return _installFuture!;
  }

  Future<NazaBarkPackStatus> _ensureInstalledInner() async {
    try {
      final local = await _describeLocal();
      if (local.installed) {
        status.value = local;
        return local;
      }

      final indexUri = Uri.parse(NazaAppConfig.barkPackIndexUrl);
      _validateRemoteUri(indexUri);
      _setProgress(1, 'downloading BarkPack index');
      final indexBytes = await _downloadBytes(
        indexUri,
        maxBytes: _maxIndexBytes,
      );
      final indexHash = crypto.sha256.convert(indexBytes).toString();
      final expectedIndexHash = _normalizeSha256Pin(
        NazaAppConfig.barkPackIndexSha256,
      );
      if (expectedIndexHash.isNotEmpty && indexHash != expectedIndexHash) {
        throw FormatException(
          'BarkPack index SHA-256 mismatch. Expected $expectedIndexHash, got $indexHash.',
        );
      }

      final index = NazaBarkPackIndex.fromJson(
        jsonDecode(utf8.decode(indexBytes)) as Map<String, dynamic>,
      );
      if (index.format != 'naza-barkpack-release-v1') {
        throw FormatException(
          'Unsupported BarkPack release format: ${index.format}',
        );
      }
      if (index.packFormat != 'naza-barkpack-v1') {
        throw FormatException(
          'Unsupported BarkPack format: ${index.packFormat}',
        );
      }

      final dir = await _packDir();
      await dir.create(recursive: true);

      await _downloadAsset(
        index.manifest,
        target: File('${dir.path}/manifest.json'),
        indexUri: indexUri,
        progressBase: 5,
        progressSpan: 10,
      );

      final shards = index.shards;
      for (var i = 0; i < shards.length; i++) {
        final shard = shards[i];
        final base = 15 + ((i / math.max(1, shards.length)) * 80).floor();
        final span = math.max(1, (80 / math.max(1, shards.length)).floor());
        await _downloadAsset(
          shard,
          target: File('${dir.path}/${_sanitizePackFileName(shard.name)}'),
          indexUri: indexUri,
          progressBase: base,
          progressSpan: span,
        );
      }

      await File('${dir.path}/install.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'format': 'naza-barkpack-install-v1',
          'indexUrl': indexUri.toString(),
          'indexSha256': indexHash,
          'installedAt': DateTime.now().toIso8601String(),
          'tensorCount': index.tensorCount,
          'quant': index.quant,
        }),
        flush: true,
      );
      await Isolate.run(
        () => _writeInstallIndexSync(
          dir.path,
          sourceIndexUrl: indexUri.toString(),
          sourceIndexSha256: indexHash,
        ),
      );

      final done = await _describeLocal();
      status.value = done;
      return done;
    } catch (error) {
      final dir = await _packDir();
      final failed = NazaBarkPackStatus(
        installed: false,
        downloading: false,
        progress: status.value.progress,
        phase: 'BarkPack install failed',
        packPath: dir.path,
        tensorCount: 0,
        missingFamilies: _requiredFamilies,
        qualityTier: status.value.qualityTier,
        familySummary: status.value.familySummary,
        stageSummary: status.value.stageSummary,
        capabilitySummary: status.value.capabilitySummary,
        sidecarSummary: status.value.sidecarSummary,
        error: error.toString(),
      );
      status.value = failed;
      return failed;
    } finally {
      _installFuture = null;
    }
  }

  Future<NazaBarkPackStatus> _describeLocal() async {
    final dir = await _packDir();
    final manifest = File('${dir.path}/manifest.json');
    if (!await manifest.exists()) {
      return NazaBarkPackStatus(
        installed: false,
        downloading: false,
        progress: 0,
        phase: 'No BarkPack installed',
        packPath: dir.path,
        tensorCount: 0,
        missingFamilies: _requiredFamilies,
        qualityTier: 'not installed',
        familySummary: 'none',
        stageSummary: 'none',
        capabilitySummary: 'none',
        sidecarSummary: 'none',
      );
    }

    final payload = await Isolate.run(() => _describeLocalSync(dir.path));
    return NazaBarkPackStatus(
      installed: payload['installed'] == true,
      downloading: false,
      progress: ((payload['progress'] as num?) ?? 0).toInt(),
      phase: (payload['phase'] ?? 'BarkPack status checked').toString(),
      packPath: dir.path,
      tensorCount: ((payload['tensorCount'] as num?) ?? 0).toInt(),
      missingFamilies: ((payload['missingFamilies'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      qualityTier: (payload['qualityTier'] ?? 'unknown').toString(),
      familySummary: (payload['familySummary'] ?? 'unknown').toString(),
      stageSummary: (payload['stageSummary'] ?? 'unknown').toString(),
      capabilitySummary: (payload['capabilitySummary'] ?? 'unknown').toString(),
      sidecarSummary: (payload['sidecarSummary'] ?? 'none').toString(),
      error: payload['error']?.toString(),
    );
  }

  static String _compactMapSummary(Object? value, {int maxEntries = 6}) {
    if (value is! Map) return 'unknown';
    final entries = value.entries
        .where((entry) => entry.key.toString().trim().isNotEmpty)
        .take(maxEntries)
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList(growable: false);
    return entries.isEmpty ? 'none' : entries.join(', ');
  }

  static String _compactCapabilitySummary(Object? value) {
    if (value is! Map) return 'unknown';
    final enabled = value.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString())
        .where((key) => key.trim().isNotEmpty)
        .take(6)
        .toList(growable: false);
    return enabled.isEmpty ? 'none' : enabled.join(', ');
  }

  static String _compactListSummary(Object? value) {
    if (value is! List || value.isEmpty) return 'none';
    return value.map((item) => item.toString()).take(6).join(', ');
  }

  static Map<String, int> _familyCountsFromTensors(
    List<NazaBarkTensorInfo> tensors,
  ) {
    final counts = <String, int>{};
    for (final tensor in tensors) {
      final family = tensor.family.trim().isNotEmpty
          ? tensor.family.trim().toLowerCase()
          : _familyFromName(tensor.name);
      if (family.isEmpty) continue;
      counts[family] = (counts[family] ?? 0) + 1;
    }
    return counts;
  }

  static String _familyFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('semantic') || lower.contains('text')) {
      return 'semantic';
    }
    if (lower.contains('coarse')) return 'coarse';
    if (lower.contains('fine')) return 'fine';
    if (lower.contains('encodec') ||
        lower.contains('codec') ||
        lower.contains('quantizer')) {
      return 'codec';
    }
    if (lower.contains('speaker') ||
        lower.contains('history') ||
        lower.contains('prompt')) {
      return 'speaker';
    }
    return 'unknown';
  }

  static Map<String, Object?> _writeInstallIndexSync(
    String dirPath, {
    String? sourceIndexUrl,
    String? sourceIndexSha256,
  }) {
    final manifest = File('$dirPath/manifest.json');
    final json =
        jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    final tensors = ((json['tensors'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => NazaBarkTensorInfo.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    final familyCounts = {
      ..._familyCountsFromTensors(tensors),
      if (json['families'] is Map)
        for (final entry in (json['families'] as Map).entries)
          entry.key.toString(): ((entry.value as num?) ?? 0).toInt(),
    };
    final missing = _requiredFamilies
        .where((family) => (familyCounts[family] ?? 0) <= 0)
        .toList(growable: false);
    final shardNames =
        tensors
            .map((t) => _sanitizePackFileName(t.file))
            .toSet()
            .toList(growable: false)
          ..sort();
    final missingShard = <String>[];
    for (final shard in shardNames) {
      if (!File('$dirPath/$shard').existsSync()) {
        missingShard.add(shard);
      }
    }
    final installed = missing.isEmpty && missingShard.isEmpty;
    final installIndex = <String, Object?>{
      'format': 'naza-barkpack-install-index-v2',
      'packFormat': json['format'] ?? 'unknown',
      'refreshedAt': DateTime.now().toIso8601String(),
      'sourceIndexUrl': sourceIndexUrl ?? '',
      'sourceIndexSha256': sourceIndexSha256 ?? '',
      'installed': installed,
      'tensorCount': tensors.length,
      'families': familyCounts,
      'missingFamilies': missing,
      'shards': shardNames,
      'missingShards': missingShard,
      'qualityTier': (json['qualityTier'] ?? 'legacy-barkpack').toString(),
      'stages': json['stages'] ?? const <String, Object?>{},
      'capabilities': json['capabilities'] ?? const <String, Object?>{},
      'synthesizedSidecars': json['synthesizedSidecars'] ?? const <Object>[],
      'speakerProfile': json['speakerProfile'] ?? const <String, Object?>{},
      'semanticProfile': json['semanticProfile'] ?? const <String, Object?>{},
      'pronunciationProfile':
          json['pronunciationProfile'] ?? const <String, Object?>{},
    };
    File('$dirPath/install_index_v2.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(installIndex),
      flush: true,
    );
    return installIndex;
  }

  static Map<String, Object?> _describeLocalSync(String dirPath) {
    try {
      final installIndex = _writeInstallIndexSync(dirPath);
      final missing = ((installIndex['missingFamilies'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false);
      final missingShard =
          ((installIndex['missingShards'] as List?) ?? const [])
              .map((item) => item.toString())
              .toList(growable: false);
      final installed = installIndex['installed'] == true;
      return {
        'installed': installed,
        'progress': installed ? 100 : 65,
        'phase': missingShard.isEmpty
            ? 'BarkPack manifest ready'
            : 'BarkPack missing shards: ${missingShard.take(3).join(', ')}',
        'tensorCount': ((installIndex['tensorCount'] as num?) ?? 0).toInt(),
        'missingFamilies': missing,
        'qualityTier': (installIndex['qualityTier'] ?? 'unknown').toString(),
        'familySummary': _compactMapSummary(installIndex['families']),
        'stageSummary': _compactMapSummary(
          installIndex['stages'],
          maxEntries: 5,
        ),
        'capabilitySummary': _compactCapabilitySummary(
          installIndex['capabilities'],
        ),
        'sidecarSummary': _compactListSummary(
          installIndex['synthesizedSidecars'],
        ),
      };
    } catch (error) {
      return {
        'installed': false,
        'progress': 0,
        'phase': 'BarkPack manifest parse failed',
        'tensorCount': 0,
        'missingFamilies': _requiredFamilies,
        'qualityTier': 'invalid',
        'familySummary': 'unknown',
        'stageSummary': 'unknown',
        'capabilitySummary': 'unknown',
        'sidecarSummary': 'unknown',
        'error': error.toString(),
      };
    }
  }

  Future<void> _downloadAsset(
    NazaBarkPackAsset asset, {
    required File target,
    required Uri indexUri,
    required int progressBase,
    required int progressSpan,
  }) async {
    final name = _sanitizePackFileName(asset.name);
    final assetName = _sanitizeRemotePackFileName(asset.asset);
    final uri = asset.url == null || asset.url!.trim().isEmpty
        ? indexUri.resolve(assetName)
        : Uri.parse(asset.url!);
    _validateRemoteUri(uri);

    if (await target.exists() &&
        await _sha256(target) == asset.sha256 &&
        (asset.size <= 0 || (await target.stat()).size == asset.size)) {
      _setProgress(progressBase + progressSpan, 'verified BarkPack $name');
      return;
    }

    final part = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    try {
      _setProgress(progressBase, 'downloading BarkPack $name');
      final bytes = await _downloadBytes(
        uri,
        maxBytes: math
            .max(
              _maxIndexBytes,
              asset.size > 0 ? asset.size + 1024 : _maxAssetBytes,
            )
            .toInt(),
        onProgress: (received, total) {
          if (total > 0) {
            final p =
                progressBase + ((received / total) * progressSpan).floor();
            _setProgress(
              p.clamp(progressBase, progressBase + progressSpan).toInt(),
              'downloading BarkPack $name',
            );
          }
        },
      );
      await part.writeAsBytes(bytes, flush: true);
      final actual = await _sha256(part);
      if (actual != asset.sha256) {
        throw FormatException(
          'BarkPack asset $name SHA-256 mismatch. Expected ${asset.sha256}, got $actual.',
        );
      }
      if (asset.size > 0 && bytes.length != asset.size) {
        throw FormatException(
          'BarkPack asset $name size mismatch. Expected ${asset.size}, got ${bytes.length}.',
        );
      }
      await target.parent.create(recursive: true);
      await part.rename(target.path);
      _setProgress(progressBase + progressSpan, 'verified BarkPack $name');
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  void _setProgress(int progress, String phase) {
    final current = status.value;
    status.value = NazaBarkPackStatus(
      installed: false,
      downloading: true,
      progress: progress.clamp(0, 100).toInt(),
      phase: phase,
      packPath: current.packPath,
      tensorCount: current.tensorCount,
      missingFamilies: current.missingFamilies,
      qualityTier: current.qualityTier,
      familySummary: current.familySummary,
      stageSummary: current.stageSummary,
      capabilitySummary: current.capabilitySummary,
      sidecarSummary: current.sidecarSummary,
    );
  }

  String _normalizeSha256Pin(String value) {
    final clean = value.trim().toLowerCase();
    if (clean.startsWith('sha256:')) {
      return clean.substring('sha256:'.length).trim();
    }
    return clean;
  }

  Future<Directory> _packDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/bark_pack');
  }

  Future<Uint8List> _downloadBytes(
    Uri uri, {
    required int maxBytes,
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final response = await _openSecureGet(client, uri);
      final length = response.contentLength;
      if (length > maxBytes) {
        throw HttpException('BarkPack response exceeds safety cap.', uri: uri);
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received > maxBytes) {
          throw HttpException(
            'BarkPack download exceeded safety cap.',
            uri: uri,
          );
        }
        builder.add(chunk);
        onProgress?.call(received, length);
      }
      return builder.toBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _openSecureGet(
    HttpClient client,
    Uri uri, {
    int redirects = 0,
  }) async {
    if (redirects > 5) {
      throw HttpException('Too many BarkPack redirects.', uri: uri);
    }
    _validateRemoteUri(uri);
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      '${NazaAppConfig.appName}/1.0 secure-barkpack-downloader',
    );
    final response = await request.close();
    if (_isRedirect(response.statusCode)) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.trim().isEmpty) {
        throw HttpException('Redirect without Location header.', uri: uri);
      }
      return _openSecureGet(
        client,
        uri.resolve(location),
        redirects: redirects + 1,
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'BarkPack download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    return response;
  }

  bool _isRedirect(int code) {
    return code == HttpStatus.movedPermanently ||
        code == HttpStatus.found ||
        code == HttpStatus.seeOther ||
        code == HttpStatus.temporaryRedirect ||
        code == HttpStatus.permanentRedirect;
  }

  void _validateRemoteUri(Uri uri) {
    if (uri.scheme != 'https') {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'Only HTTPS is allowed.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'User info is not allowed.',
      );
    }
    final host = uri.host.toLowerCase();
    final allowed =
        host == 'github.com' ||
        host.endsWith('.github.com') ||
        host.endsWith('.githubusercontent.com') ||
        host == 'objects.githubusercontent.com' ||
        host == 'release-assets.githubusercontent.com';
    if (!allowed) {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'Unexpected BarkPack download host.',
      );
    }
  }

  static String _sanitizePackFileName(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.contains('/') ||
        clean.contains('\\') ||
        clean.contains('\x00') ||
        clean == '.' ||
        clean == '..') {
      throw FormatException('Unsafe BarkPack asset name: $name');
    }
    if (clean != 'manifest.json' &&
        !RegExp(r'^tensors_[0-9]{3}\.bin$').hasMatch(clean) &&
        !RegExp(
          r'^naza-barkpack-(manifest|tensors_[0-9]{3})\.(json|bin)$',
        ).hasMatch(clean)) {
      throw FormatException('Unexpected BarkPack asset name: $name');
    }
    if (clean.startsWith('naza-barkpack-tensors_')) {
      return clean.substring('naza-barkpack-'.length);
    }
    if (clean == 'naza-barkpack-manifest.json') return 'manifest.json';
    return clean;
  }

  static String _sanitizeRemotePackFileName(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.contains('/') ||
        clean.contains('\\') ||
        clean.contains('\x00') ||
        clean == '.' ||
        clean == '..') {
      throw FormatException('Unsafe BarkPack remote asset name: $name');
    }
    final allowed =
        clean == 'manifest.json' ||
        RegExp(r'^tensors_[0-9]{3}\.bin$').hasMatch(clean) ||
        RegExp(
          r'^naza-barkpack-(manifest|tensors_[0-9]{3})\.(json|bin)$',
        ).hasMatch(clean);
    if (!allowed) {
      throw FormatException('Unexpected BarkPack remote asset name: $name');
    }
    return clean;
  }

  Future<String> _sha256(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }
}

final class NazaLocalGemma {
  NazaLocalGemma._();

  static final NazaLocalGemma instance = NazaLocalGemma._();

  final ValueNotifier<NazaRuntimeSnapshot> snapshot =
      ValueNotifier<NazaRuntimeSnapshot>(NazaRuntimeSnapshot.initial());

  final ValueNotifier<NazaGenerationTelemetry> generation =
      ValueNotifier<NazaGenerationTelemetry>(NazaGenerationTelemetry.idle());

  final ValueNotifier<NazaModelBackendPreference> backendPreference =
      ValueNotifier<NazaModelBackendPreference>(
        NazaModelBackendPreference.gpuFirst,
      );

  dynamic _model;
  dynamic _chat;
  Future<void>? _loadingFuture;
  Future<void>? _backendPreferenceLoadFuture;
  int _generationSerial = 0;
  int _cancelledGeneration = -1;
  bool _runtimeBootstrapped = false;

  static final RegExp _textResponseRegExp = RegExp(
    r'^TextResponse\("([\s\S]*)"\)$',
  );
  static final RegExp _channelRegExp = RegExp(
    r'<\|channel\|>.*?<\|message\|>',
    dotAll: true,
  );
  static final RegExp _thinkRegExp = RegExp(
    r'<think>.*?</think>',
    dotAll: true,
  );
  static final RegExp _tripleNewlineRegExp = RegExp(r'\n{3,}');
  static final RegExp _sentenceEndRegExp = RegExp(r'[.!?]$');
  static final RegExp _completeBoundaryRegExp = RegExp(r'[.!?\])}`]$');
  static final RegExp _unfinishedBoundaryRegExp = RegExp(r'[:,;\-–—]$');
  static final RegExp _bulletLineRegExp = RegExp(r'^[-*]\s+\S');
  static final RegExp _headingLineRegExp = RegExp(
    r'^\*+\s*\*?\d+(?:\.\d+)*\.?\s+\S',
  );

  Future<void> prepareBackendPreference() {
    _backendPreferenceLoadFuture ??= _loadBackendPreference();
    return _backendPreferenceLoadFuture!;
  }

  Future<void> setBackendPreference(
    NazaModelBackendPreference preference,
  ) async {
    await prepareBackendPreference();
    if (backendPreference.value == preference) return;

    if (snapshot.value.busy) {
      snapshot.value = snapshot.value.copyWith(
        phase: 'wait for current work before changing backend',
      );
      return;
    }

    final hadLoadedModel = _model != null || _chat != null;
    backendPreference.value = preference;
    final saved = await _persistBackendPreference();

    if (hadLoadedModel) {
      await close(phase: 'backend changed; model reloads on next send');
    }

    snapshot.value = snapshot.value.copyWith(
      usingGpu: preference == NazaModelBackendPreference.cpuOnly
          ? false
          : snapshot.value.usingGpu,
      phase: saved
          ? (hadLoadedModel
                ? 'backend set to ${preference.shortLabel}; reload on next send'
                : 'backend set to ${preference.shortLabel}')
          : 'backend set in memory; preference save failed',
      clearError: saved,
    );
    unawaited(_persistRuntimeSnapshot());
  }

  Future<void> _loadBackendPreference() async {
    try {
      final file = await _backendPreferenceFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          backendPreference.value = NazaModelBackendPreference.fromStorage(
            json['preference'],
          );
          return;
        }
      }
    } catch (_) {
      // A malformed preference file should never prevent the model from
      // loading. Fall back to the environment/default path below.
    }

    backendPreference.value = _backendPreferenceFromEnvironment();
  }

  NazaModelBackendPreference _backendPreferenceFromEnvironment() {
    final desktopGpuPreference = Platform
        .environment[NazaAppConfig.desktopGpuEnvironmentVariable]
        ?.trim()
        .toLowerCase();
    final desktopCpuPreference = Platform
        .environment[NazaAppConfig.desktopCpuEnvironmentVariable]
        ?.trim()
        .toLowerCase();

    if (desktopCpuPreference == '1' ||
        desktopCpuPreference == 'true' ||
        desktopCpuPreference == 'yes' ||
        desktopGpuPreference == '0' ||
        desktopGpuPreference == 'false' ||
        desktopGpuPreference == 'no') {
      return NazaModelBackendPreference.cpuOnly;
    }

    if (desktopGpuPreference == 'only' || desktopGpuPreference == 'required') {
      return NazaModelBackendPreference.gpuOnly;
    }

    return NazaModelBackendPreference.gpuFirst;
  }

  Future<bool> _persistBackendPreference() async {
    try {
      final file = await _backendPreferenceFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'format': 'naza-backend-preference-v1',
          'preference': backendPreference.value.storageValue,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
      return true;
    } catch (error) {
      snapshot.value = snapshot.value.copyWith(
        phase: 'backend preference save failed',
        error: error.toString(),
      );
      return false;
    }
  }

  Future<File> _backendPreferenceFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/${NazaAppConfig.backendPreferenceFileName}');
  }

  Future<void> bootstrapRuntimeOnly() async {
    if (_runtimeBootstrapped) return;

    try {
      FlutterGemma.logLevel = GemmaLogLevel.none;
      await FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
        maxDownloadRetries: 0,
      );

      _runtimeBootstrapped = true;
      snapshot.value = snapshot.value.copyWith(
        runtimeRegistered: true,
        phase: 'LiteRT-LM runtime registered',
        clearError: true,
      );
    } catch (error) {
      snapshot.value = snapshot.value.copyWith(
        runtimeRegistered: false,
        phase: 'runtime registration failed',
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> ensureReady() {
    _loadingFuture ??= _ensureReadyInner();
    return _loadingFuture!;
  }

  Future<void> _ensureReadyInner() async {
    if (_chat != null && _model != null) return;

    snapshot.value = snapshot.value.copyWith(
      busy: true,
      phase: 'preparing local Gemma engine',
      clearError: true,
    );

    try {
      await prepareBackendPreference();
      await bootstrapRuntimeOnly();

      snapshot.value = snapshot.value.copyWith(
        modelInstalled: false,
        phase: 'preparing verified LiteRT-LM model',
        installProgress: 0,
        clearError: true,
      );

      // flutter_gemma persists the active model identity. Always reinstall from
      // the SHA-verified .litertlm file so stale .task/bundled identities cannot
      // be loaded by accident.
      try {
        await FlutterGemma.clearActiveInferenceIdentity();
      } catch (_) {
        // Older package versions may not need this; continue to install.
      }

      await _installConfiguredModel();

      snapshot.value = snapshot.value.copyWith(
        busy: true,
        modelInstalled: true,
        installProgress: 100,
        phase: 'loading active model',
      );

      await _loadActiveModelForBackend(backendPreference.value);

      _chat = await _model.createChat(
        systemInstruction: NazaAppConfig.systemInstruction,
        maxOutputTokens: NazaAppConfig.outputTokens,
      );

      snapshot.value = snapshot.value.copyWith(
        modelLoaded: true,
        busy: false,
        phase: 'ready',
        clearError: true,
      );

      unawaited(_persistRuntimeSnapshot());
    } catch (error) {
      snapshot.value = snapshot.value.copyWith(
        busy: false,
        modelLoaded: false,
        phase: 'local model failed',
        error:
            'Could not load ${NazaAppConfig.modelFileName}. '
            '${_modelSetupHint()} Raw error: $error',
      );
      unawaited(_persistRuntimeSnapshot());
      rethrow;
    } finally {
      _loadingFuture = null;
    }
  }

  Future<NazaResponse> send(
    String userText, {
    void Function(String partialText)? onPartial,
    String? historyUserText,
  }) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      return NazaResponse(
        text: 'Send a message first.',
        score: 0,
        route: 'empty',
        cancelled: false,
        createdAt: DateTime.now(),
      );
    }

    final route = NazaQuantumRouter.route(trimmed);

    try {
      await ensureReady();
    } catch (error) {
      return NazaResponse(
        text:
            'The local model is not ready yet. ${_modelSetupHint()}\n\n'
            'Details: $error',
        score: route.score,
        route: 'model-unavailable',
        cancelled: false,
        createdAt: DateTime.now(),
      );
    }

    final generationId = ++_generationSerial;
    _cancelledGeneration = -1;

    _startGenerationTelemetry(generationId: generationId, route: route);

    snapshot.value = snapshot.value.copyWith(
      busy: true,
      phase: 'generating local response',
      clearError: true,
    );

    try {
      await _chat.addQueryChunk(
        Message.text(text: _buildPrompt(trimmed, route), isUser: true),
      );

      var clean = await _streamResponse(
        generationId: generationId,
        onPartial: onPartial,
      );

      if (_cancelledGeneration == generationId) {
        _stopGenerationTelemetry(cancelled: true);
        snapshot.value = snapshot.value.copyWith(
          busy: false,
          phase: 'generation cancelled',
          clearError: true,
        );

        return NazaResponse(
          text: 'Generation cancelled.',
          score: route.score,
          route: route.label,
          cancelled: true,
          createdAt: DateTime.now(),
        );
      }

      var continuationCount = 0;
      while (_shouldAutoContinue(clean) &&
          continuationCount < NazaAppConfig.autoContinuationPasses) {
        continuationCount++;
        generation.value = generation.value.copyWith(
          stage: 'continuing locally',
        );

        final prefix = clean;
        await _chat.addQueryChunk(
          Message.text(
            text:
                'Continue exactly where the previous answer stopped. Do not restart, do not summarize, and finish the incomplete section.',
            isUser: true,
          ),
        );

        final continuation = await _streamResponse(
          generationId: generationId,
          partialPrefix: prefix,
          onPartial: onPartial,
        );

        if (_cancelledGeneration == generationId) {
          _stopGenerationTelemetry(cancelled: true);
          snapshot.value = snapshot.value.copyWith(
            busy: false,
            phase: 'generation cancelled',
            clearError: true,
          );

          return NazaResponse(
            text: 'Generation cancelled.',
            score: route.score,
            route: route.label,
            cancelled: true,
            createdAt: DateTime.now(),
          );
        }

        if (continuation.trim().isEmpty) break;
        clean = _joinContinuation(prefix, continuation);
      }

      _finishGenerationTelemetry(route: route);

      final out = NazaResponse(
        text: clean.isEmpty
            ? 'The local model returned an empty response.'
            : clean,
        score: route.score,
        route: route.label,
        cancelled: false,
        createdAt: DateTime.now(),
      );

      snapshot.value = snapshot.value.copyWith(
        busy: false,
        phase: 'ready',
        clearError: true,
      );

      // The answer is ready to paint. Persisting encrypted history is useful,
      // but it must not hold the visible response behind file I/O/crypto.
      final persistedUser = historyUserText?.trim();
      unawaited(
        _persistMessagePair(
          user: persistedUser == null || persistedUser.isEmpty
              ? trimmed
              : persistedUser,
          response: out,
        ),
      );

      return out;
    } catch (error) {
      _stopGenerationTelemetry(cancelled: false);
      snapshot.value = snapshot.value.copyWith(
        busy: false,
        phase: 'generation failed',
        error: error.toString(),
      );

      return NazaResponse(
        text: 'Local Gemma error: $error',
        score: route.score,
        route: route.label,
        cancelled: false,
        createdAt: DateTime.now(),
      );
    }
  }

  void cancelActiveGeneration() {
    final current = generation.value;
    if (!current.active) return;

    _cancelledGeneration = current.generationId;
    generation.value = current.copyWith(
      active: false,
      cancelled: true,
      stage: 'cancelled',
      progress: current.progress.clamp(0, 1).toDouble(),
    );

    snapshot.value = snapshot.value.copyWith(
      busy: false,
      phase: 'generation cancelled',
      clearError: true,
    );

    unawaited(_stopNativeGeneration());
  }

  Future<void> _stopNativeGeneration() async {
    try {
      await _chat?.stopGeneration();
    } catch (_) {
      // Cancellation is best-effort; the generation id still rejects a late
      // native response.
    }
  }

  void _startGenerationTelemetry({
    required int generationId,
    required NazaRoute route,
  }) {
    generation.value = NazaGenerationTelemetry(
      active: true,
      cancelled: false,
      generationId: generationId,
      progress: 0,
      tokens: 0,
      maxTokens: NazaAppConfig.outputTokens,
      stage: 'generating locally',
      route: route.label,
      routeScore: route.score,
      startedAt: DateTime.now(),
    );
  }

  void _finishGenerationTelemetry({required NazaRoute route}) {
    generation.value = generation.value.copyWith(
      active: false,
      cancelled: false,
      progress: 1,
      tokens: NazaAppConfig.outputTokens,
      maxTokens: NazaAppConfig.outputTokens,
      stage: 'complete',
      route: route.label,
      routeScore: route.score,
    );
  }

  void _stopGenerationTelemetry({required bool cancelled}) {
    generation.value = generation.value.copyWith(
      active: false,
      cancelled: cancelled,
      stage: cancelled ? 'cancelled' : 'stopped',
    );
  }

  Future<void> resetChat() async {
    if (_model == null) return;

    try {
      await _chat?.session?.close();
    } catch (_) {}

    _chat = await _model.createChat(
      systemInstruction: NazaAppConfig.systemInstruction,
      maxOutputTokens: NazaAppConfig.outputTokens,
    );

    snapshot.value = snapshot.value.copyWith(
      phase: 'chat context reset',
      clearError: true,
    );
  }

  Future<void> _installConfiguredModel() async {
    final verified = await NazaSecureModelStore.ensureVerifiedModel(
      onProgress: (progress, phase) {
        snapshot.value = snapshot.value.copyWith(
          busy: true,
          installProgress: progress,
          phase: phase,
          clearError: true,
        );
      },
    );

    final installer = FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    );

    snapshot.value = snapshot.value.copyWith(
      busy: true,
      phase: 'installing verified LiteRT-LM model',
      installProgress: 100,
      clearError: true,
    );

    await installer.fromFile(verified.file.path).install();
  }

  Future<void> _loadActiveModelForBackend(
    NazaModelBackendPreference preference,
  ) async {
    switch (preference) {
      case NazaModelBackendPreference.cpuOnly:
        _model = await FlutterGemma.getActiveModel(
          maxTokens: NazaAppConfig.contextTokens,
          preferredBackend: PreferredBackend.cpu,
        );
        snapshot.value = snapshot.value.copyWith(
          usingGpu: false,
          phase: 'model loaded on CPU backend',
          clearError: true,
        );
        return;
      case NazaModelBackendPreference.gpuOnly:
        try {
          _model = await FlutterGemma.getActiveModel(
            maxTokens: NazaAppConfig.contextTokens,
            preferredBackend: PreferredBackend.gpu,
          );
          snapshot.value = snapshot.value.copyWith(
            usingGpu: true,
            phase: 'model loaded on GPU backend',
            clearError: true,
          );
          return;
        } catch (error) {
          snapshot.value = snapshot.value.copyWith(
            usingGpu: false,
            phase: 'GPU backend failed',
            error:
                'GPU-only mode could not load the LiteRT-LM backend. '
                'Switch Settings → Model backend to GPU first or CPU only. '
                'Raw error: $error',
          );
          rethrow;
        }
      case NazaModelBackendPreference.gpuFirst:
        try {
          _model = await FlutterGemma.getActiveModel(
            maxTokens: NazaAppConfig.contextTokens,
            preferredBackend: PreferredBackend.gpu,
          );

          snapshot.value = snapshot.value.copyWith(
            usingGpu: true,
            phase: 'model loaded on GPU backend',
            clearError: true,
          );
          return;
        } catch (_) {
          _model = await FlutterGemma.getActiveModel(
            maxTokens: NazaAppConfig.contextTokens,
            preferredBackend: PreferredBackend.cpu,
          );

          snapshot.value = snapshot.value.copyWith(
            usingGpu: false,
            phase: 'model loaded on CPU fallback',
            clearError: true,
          );
          return;
        }
    }
  }

  String _modelSetupHint() {
    return 'Naza One downloads ${NazaAppConfig.modelFileName} only from the pinned HTTPS Hugging Face URL, '
        'or accepts a local ${NazaAppConfig.modelPathEnvironmentVariable} / executable models folder file only when its SHA-256 equals '
        '${NazaAppConfig.modelSha256}. Check network access and available app-support storage.';
  }

  Future<void> close({String phase = 'closed'}) async {
    try {
      await _chat?.session?.close();
    } catch (_) {}

    try {
      await _model?.close();
    } catch (_) {}

    _chat = null;
    _model = null;

    snapshot.value = snapshot.value.copyWith(
      modelLoaded: false,
      busy: false,
      phase: phase,
    );
  }

  String _buildPrompt(String userText, NazaRoute route) {
    return '''
Local route: ${route.label}
Chromatic ribbon score: ${route.score.toStringAsFixed(5)}
Chromatic signal: ${route.explanation}

User request:
$userText
''';
  }

  Future<String> _streamResponse({
    required int generationId,
    void Function(String partialText)? onPartial,
    String partialPrefix = '',
  }) async {
    final rawResponse = StringBuffer();
    var lastPartialAt = DateTime.fromMillisecondsSinceEpoch(0);
    var lastTelemetryAt = DateTime.fromMillisecondsSinceEpoch(0);
    var lastEstimatedTokens = 0;

    await for (final chunk in _chat.generateChatResponseAsync()) {
      if (_cancelledGeneration == generationId) break;

      late final String token;
      if (chunk is TextResponse) {
        token = chunk.token;
        rawResponse.write(token);
      } else if (chunk is ThinkingResponse) {
        continue;
      } else {
        token = chunk.toString();
        rawResponse.write(token);
      }

      final estimatedTokens = (rawResponse.length / 4)
          .ceil()
          .clamp(0, NazaAppConfig.outputTokens)
          .toInt();
      final now = DateTime.now();
      final tokenClosedPhrase =
          token.endsWith('\n') ||
          token.endsWith('.') ||
          token.endsWith('!') ||
          token.endsWith('?');
      final shouldUpdateTelemetry =
          estimatedTokens != lastEstimatedTokens &&
          (now.difference(lastTelemetryAt) >=
                  const Duration(
                    milliseconds: NazaAppConfig.telemetryThrottleMs,
                  ) ||
              tokenClosedPhrase);
      if (shouldUpdateTelemetry) {
        lastTelemetryAt = now;
        lastEstimatedTokens = estimatedTokens;
        generation.value = generation.value.copyWith(
          tokens: estimatedTokens,
          progress: (estimatedTokens / NazaAppConfig.outputTokens)
              .clamp(0.0, 0.96)
              .toDouble(),
        );
      }

      if (onPartial != null) {
        final shouldEmit =
            now.difference(lastPartialAt) >=
                const Duration(
                  milliseconds: NazaAppConfig.streamPaintThrottleMs,
                ) ||
            tokenClosedPhrase;

        if (shouldEmit) {
          lastPartialAt = now;
          final partial = _cleanResponse(rawResponse.toString());
          if (partial.isNotEmpty) {
            onPartial(_joinContinuation(partialPrefix, partial));
          }
        }
      }
    }

    final finalEstimatedTokens = (rawResponse.length / 4)
        .ceil()
        .clamp(0, NazaAppConfig.outputTokens)
        .toInt();
    if (finalEstimatedTokens != lastEstimatedTokens) {
      generation.value = generation.value.copyWith(
        tokens: finalEstimatedTokens,
        progress: (finalEstimatedTokens / NazaAppConfig.outputTokens)
            .clamp(0.0, 0.96)
            .toDouble(),
      );
    }

    return _cleanResponse(rawResponse.toString());
  }

  String _cleanResponse(String raw) {
    var s = raw.trim();

    final textResponseMatch = _textResponseRegExp.firstMatch(s);
    if (textResponseMatch != null) {
      s = textResponseMatch.group(1) ?? '';
      s = s
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '\r')
          .replaceAll(r'\t', '\t')
          .trim();
    }

    s = s.replaceAll('<end_of_turn>', '');
    s = s.replaceAll('<start_of_turn>', '');
    s = s.replaceAll(_channelRegExp, '');
    s = s.replaceAll(_thinkRegExp, '');
    s = s.replaceAll(_tripleNewlineRegExp, '\n\n');
    return s.trim();
  }

  String _joinContinuation(String prefix, String continuation) {
    final first = prefix.trim();
    final second = continuation.trim();
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    if (first.endsWith(second)) return first;
    return '$first\n\n$second';
  }

  bool _shouldAutoContinue(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 640) return false;

    final lower = trimmed.toLowerCase();
    if (lower.endsWith('[done]') || lower.endsWith('complete.')) return false;

    if (_completeBoundaryRegExp.hasMatch(trimmed)) return false;
    if (_unfinishedBoundaryRegExp.hasMatch(trimmed)) return true;

    final lines = trimmed.split('\n');
    final lastLine = lines.isEmpty ? trimmed : lines.last.trim();
    if (_bulletLineRegExp.hasMatch(lastLine) && lastLine.length < 140) {
      return true;
    }
    if (_headingLineRegExp.hasMatch(lastLine)) {
      return true;
    }

    return trimmed.length > 1200 && !_sentenceEndRegExp.hasMatch(trimmed);
  }

  Future<void> _persistRuntimeSnapshot() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/${NazaAppConfig.runtimeFileName}');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(snapshot.value.toJson()),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> _persistMessagePair({
    required String user,
    required NazaResponse response,
  }) async {
    try {
      await NazaVault.instance.appendMessagePair(
        user: user,
        assistant: response.text,
        route: response.route,
        score: response.score,
      );
    } catch (_) {
      // A storage failure must never replace an already generated answer.
    }
  }
}

final class NazaResponse {
  final String text;
  final double score;
  final String route;
  final bool cancelled;
  final DateTime createdAt;

  const NazaResponse({
    required this.text,
    required this.score,
    required this.route,
    required this.cancelled,
    required this.createdAt,
  });
}

final class NazaChromaticState {
  final double score;
  final double entropy;
  final double lexicalMotion;
  final double pZero;
  final double pOne;
  final double coherence;
  final double phase;
  final int stateBit;
  final double velocity;
  final double curvature;
  final double energy;
  final double phaseTransition;
  final double quantumSpread;
  final double policyEntropy;
  final double nonlocalIndex;
  final int r;
  final int g;
  final int b;
  final String hex;
  final String colorName;
  final String ribbonPhase;

  const NazaChromaticState({
    required this.score,
    required this.entropy,
    required this.lexicalMotion,
    required this.pZero,
    required this.pOne,
    required this.coherence,
    required this.phase,
    required this.stateBit,
    required this.velocity,
    required this.curvature,
    required this.energy,
    required this.phaseTransition,
    required this.quantumSpread,
    required this.policyEntropy,
    required this.nonlocalIndex,
    required this.r,
    required this.g,
    required this.b,
    required this.hex,
    required this.colorName,
    required this.ribbonPhase,
  });

  String get quantumLine =>
      'rgb=$hex/$colorName, p0=${pZero.toStringAsFixed(3)}, '
      'p1=${pOne.toStringAsFixed(3)}, coherence=${coherence.toStringAsFixed(3)}, '
      'phase=${phase.toStringAsFixed(3)}, state_bit=$stateBit';

  String get timingLine =>
      'rgb_timing=($r,$g,$b), velocity=${velocity.toStringAsFixed(3)}, '
      'curvature=${curvature.toStringAsFixed(3)}, energy=${energy.toStringAsFixed(3)}';

  String get ribbonLine =>
      'ribbon_phase=$ribbonPhase, phase_transition=${phaseTransition.toStringAsFixed(3)}, '
      'quantum_spread=${quantumSpread.toStringAsFixed(3)}, '
      'policy_entropy=${policyEntropy.toStringAsFixed(3)}, '
      'nonlocal_index=${nonlocalIndex.toStringAsFixed(3)}';
}

final class NazaRoute {
  final double score;
  final String label;
  final String explanation;

  const NazaRoute({
    required this.score,
    required this.label,
    required this.explanation,
  });
}

final class NazaQuantumRouter {
  const NazaQuantumRouter._();

  static NazaRoute route(String text) {
    final normalized = text.trim();
    final chroma = chromaticState(normalized, purpose: 'chat-router');
    final score = chroma.score;

    if (normalized.isEmpty) {
      return const NazaRoute(
        score: 0,
        label: 'empty',
        explanation: 'No prompt energy.',
      );
    }

    if (score >= 0.82) {
      return NazaRoute(
        score: score,
        label: 'deep-reasoning',
        explanation:
            'High entropy, chromatic coherence, and ribbon energy. '
            'Prefer careful structure. ${chroma.quantumLine}; ${chroma.ribbonLine}.',
      );
    }

    if (score >= 0.62) {
      return NazaRoute(
        score: score,
        label: 'creative-build',
        explanation:
            'Moderate-high RGB phase motion. Prefer complete code or design synthesis. '
            '${chroma.quantumLine}; ${chroma.timingLine}.',
      );
    }

    if (score >= 0.38) {
      return NazaRoute(
        score: score,
        label: 'balanced-chat',
        explanation:
            'Balanced chromatic signal. Prefer concise helpful response. '
            '${chroma.quantumLine}.',
      );
    }

    return NazaRoute(
      score: score,
      label: 'calm-minimal',
      explanation:
          'Low ribbon complexity. Prefer direct short answer. ${chroma.quantumLine}.',
    );
  }

  static double calculateScore(String text) {
    return chromaticState(text).score;
  }

  static NazaChromaticState chromaticState(
    String text, {
    String purpose = 'router',
    int step = 0,
    (int, int, int)? baseRgb,
  }) {
    final normalized = text.trim();
    final bytes = utf8.encode(text);
    final base = baseRgb ?? _baseRgbForPurpose(purpose);
    if (bytes.isEmpty) {
      final hex = _rgbHex(base.$1, base.$2, base.$3);
      return NazaChromaticState(
        score: 0,
        entropy: 0,
        lexicalMotion: 0,
        pZero: 1,
        pOne: 0,
        coherence: 0,
        phase: 0,
        stateBit: 0,
        velocity: 0,
        curvature: 0,
        energy: 0,
        phaseTransition: 0,
        quantumSpread: 0,
        policyEntropy: 0,
        nonlocalIndex: 0,
        r: base.$1,
        g: base.$2,
        b: base.$3,
        hex: hex,
        colorName: _nearestColorName(base.$1, base.$2, base.$3),
        ribbonPhase: 'stable-ribbon',
      );
    }

    final rgb = _promptRgb(bytes);
    final tokens = _tokens(normalized);
    final entropy = (_shannonEntropy(bytes) / 8.0).clamp(0.0, 1.0).toDouble();
    final q = _twoQubitExpectation(rgb.$1, rgb.$2, rgb.$3);
    final wave = _phaseWave(bytes);
    final lexical = _lexicalMotion(normalized);
    final symbolDensity = _symbolDensity(normalized);
    final longContext = (tokens.length / 1100.0).clamp(0.0, 1.0).toDouble();
    final seed = _stableFloat(normalized, purpose);
    final phase =
        math.pi * 2.0 * seed +
        step * 0.037 +
        bytes.length * 0.0013 +
        wave * 0.21;

    final tokenScale = (q * 0.42 + lexical * 0.30 + entropy * 0.28)
        .clamp(0.0, 1.0)
        .toDouble();
    final phraseScale =
        (tokenScale * 0.38 + entropy * 0.26 + wave * 0.24 + seed * 0.12)
            .clamp(0.0, 1.0)
            .toDouble();
    final discourseScale =
        (phraseScale * 0.52 +
                longContext * 0.18 +
                symbolDensity * 0.12 +
                _stableFloat(normalized, 'discourse:$purpose') * 0.18)
            .clamp(0.0, 1.0)
            .toDouble();
    final crossScale =
        (1.0 -
                (tokenScale - phraseScale).abs() * 0.42 -
                (phraseScale - discourseScale).abs() * 0.36)
            .clamp(0.0, 1.0)
            .toDouble();
    final velocity = (discourseScale - tokenScale).abs().clamp(0.0, 1.0);
    final curvature =
        ((tokenScale - 2 * phraseScale + discourseScale).abs() * 1.45 +
                _binaryEntropy(phraseScale) * 0.06)
            .clamp(0.0, 1.0)
            .toDouble();
    final diffusion =
        (entropy * 0.30 +
                symbolDensity * 0.20 +
                longContext * 0.14 +
                velocity * 0.22)
            .clamp(0.0, 1.0)
            .toDouble();
    final energy =
        (phraseScale * 0.34 +
                discourseScale * 0.22 +
                curvature * 0.15 +
                diffusion * 0.12 +
                q * 0.10 +
                lexical * 0.07)
            .clamp(0.0, 1.0)
            .toDouble();
    final phaseTransition =
        (math.max(0.0, energy - 0.46) * 1.60 +
                math.max(0.0, curvature - 0.28) * 0.70)
            .clamp(0.0, 1.0)
            .toDouble();

    final theta =
        (energy * math.pi * 0.92 + entropy * 0.72 + symbolDensity * 0.28)
            .clamp(0.0, math.pi)
            .toDouble();
    final phi = phase + entropy * math.pi * 2.0;
    final lam = phase * 0.5 + q * math.pi * 2.0;
    final s = math.sin(theta / 2.0);
    final gatePhase = math.cos((phi + lam) / 2.0).abs();
    final pOne =
        (s * s * 0.52 +
                wave * 0.15 +
                entropy * 0.13 +
                energy * 0.13 +
                gatePhase * 0.07)
            .clamp(0.0, 1.0)
            .toDouble();
    final pZero = (1.0 - pOne).clamp(0.0, 1.0).toDouble();
    final coherence =
        ((pZero - pOne).abs() * 0.18 +
                (1.0 - (pZero - pOne).abs()) * 0.28 +
                math.cos(phi - lam).abs() * 0.22 +
                entropy * 0.20 +
                crossScale * 0.12)
            .clamp(0.0, 1.0)
            .toDouble();
    final quantumSpread =
        (_stableFloat(normalized, 'quantum-spread:$purpose') * 0.24 +
                diffusion * 0.28 +
                phaseTransition * 0.18 +
                (1.0 - crossScale) * 0.14 +
                coherence * 0.16)
            .clamp(0.0, 1.0)
            .toDouble();
    final policyEntropy =
        (_binaryEntropy(energy) * 0.38 +
                quantumSpread * 0.22 +
                diffusion * 0.18 +
                symbolDensity * 0.12 +
                longContext * 0.10)
            .clamp(0.0, 1.0)
            .toDouble();
    final nonlocalIndex =
        (phaseTransition * 0.34 +
                quantumSpread * 0.26 +
                (1.0 - crossScale) * 0.20 +
                coherence * 0.14 +
                velocity * 0.06)
            .clamp(0.0, 1.0)
            .toDouble();

    final baseHsv = _rgbToHsv(base.$1, base.$2, base.$3);
    final timingR = 0.5 + 0.5 * math.sin(phase + velocity * 5.0);
    final timingG = 0.5 + 0.5 * math.sin(phase * 0.73 + entropy * 4.0);
    final timingB = 0.5 + 0.5 * math.sin(phase * 1.17 + curvature * 7.0);
    final hotShift = energy * 0.09 + pOne * 0.08 + quantumSpread * 0.04;
    final hue = (baseHsv.$1 + hotShift + entropy * 0.035) % 1.0;
    final saturation =
        (0.38 + baseHsv.$2 * 0.44 + energy * 0.22 + coherence * 0.18)
            .clamp(0.0, 1.0)
            .toDouble();
    final value =
        (0.36 +
                baseHsv.$3 * 0.36 +
                pOne * 0.22 +
                timingR * 0.12 +
                energy * 0.16)
            .clamp(0.0, 1.0)
            .toDouble();
    final surfaced = _hsvToRgb(hue, saturation, value);
    final r = (surfaced.$1 * (0.78 + timingR * 0.28))
        .round()
        .clamp(0, 255)
        .toInt();
    final g = (surfaced.$2 * (0.78 + timingG * 0.28))
        .round()
        .clamp(0, 255)
        .toInt();
    final b = (surfaced.$3 * (0.78 + timingB * 0.28))
        .round()
        .clamp(0, 255)
        .toInt();
    final score =
        (entropy * 0.20 +
                lexical * 0.14 +
                q * 0.14 +
                wave * 0.12 +
                energy * 0.18 +
                coherence * 0.10 +
                nonlocalIndex * 0.12)
            .clamp(0.0, 1.0)
            .toDouble();

    return NazaChromaticState(
      score: score,
      entropy: entropy,
      lexicalMotion: lexical,
      pZero: pZero,
      pOne: pOne,
      coherence: coherence,
      phase: phase,
      stateBit: pOne >= pZero ? 1 : 0,
      velocity: velocity,
      curvature: curvature,
      energy: energy,
      phaseTransition: phaseTransition,
      quantumSpread: quantumSpread,
      policyEntropy: policyEntropy,
      nonlocalIndex: nonlocalIndex,
      r: r,
      g: g,
      b: b,
      hex: _rgbHex(r, g, b),
      colorName: _nearestColorName(r, g, b),
      ribbonPhase: _ribbonPhase(score, phaseTransition),
    );
  }

  static (double, double, double) _promptRgb(List<int> bytes) {
    var r = 0;
    var g = 0;
    var b = 0;

    for (var i = 0; i < bytes.length; i++) {
      final v = bytes[i];
      r = (r + v * (i + 3)) & 0xFFFF;
      g = (g + v * (i + 7)) & 0xFFFF;
      b = (b + v * (i + 11)) & 0xFFFF;
    }

    return ((r % 256) / 255.0, (g % 256) / 255.0, (b % 256) / 255.0);
  }

  static double _shannonEntropy(List<int> bytes) {
    final counts = <int, int>{};
    for (final b in bytes) {
      counts[b] = (counts[b] ?? 0) + 1;
    }

    var entropy = 0.0;
    for (final c in counts.values) {
      final p = c / bytes.length;
      entropy -= p * (math.log(p) / math.ln2);
    }

    return entropy;
  }

  static double _phaseWave(List<int> bytes) {
    var acc = 0.0;

    for (var i = 0; i < bytes.length; i++) {
      final x = bytes[i] / 255.0;
      acc += math.sin((i + 1) * math.pi * x);
      acc += math.cos((bytes.length - i + 1) * math.pi * x * 0.5);
    }

    return (0.5 + 0.5 * math.sin(acc / math.max(1, bytes.length))).clamp(
      0.0,
      1.0,
    );
  }

  static double _lexicalMotion(String text) {
    final words = _tokens(text);

    if (words.isEmpty) return 0.0;

    final unique = words.toSet().length / words.length;
    final longWords = words.where((w) => w.length >= 8).length / words.length;
    final symbols = RegExp(
      r'[{}()\[\]<>*/+=#@$%^&|\\]',
    ).allMatches(text).length;
    final symbolScore = (symbols / math.max(12, text.length)).clamp(0.0, 1.0);

    return (unique * 0.45 + longWords * 0.25 + symbolScore * 0.30).clamp(
      0.0,
      1.0,
    );
  }

  static List<String> _tokens(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9_+\-/]+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  static double _symbolDensity(String text) {
    final symbols = RegExp(
      r'[{}()\[\]<>*/+=#@$%^&|\\:;~`]',
    ).allMatches(text).length;
    return (symbols / math.max(16, text.length)).clamp(0.0, 1.0).toDouble();
  }

  static double _twoQubitExpectation(double a, double b, double c) {
    final rx0 = a * math.pi;
    final ry1 = b * math.pi;
    final rz1 = c * math.pi;
    final entangle = math.sin(rx0) * math.cos(ry1);
    final phase = math.cos(rz1 + entangle);
    final z0 = math.cos(rx0 + entangle * 0.5);
    final z1 = math.cos(ry1 - phase * 0.5);
    return ((z0.abs() + z1.abs()) / 2.0).clamp(0.0, 1.0);
  }

  static double _binaryEntropy(double p) {
    final x = p.clamp(1e-8, 1.0 - 1e-8).toDouble();
    return (-(x * math.log(x) / math.ln2 +
            (1.0 - x) * math.log(1.0 - x) / math.ln2))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double _stableFloat(String text, String salt) {
    var hash = 0x811C9DC5;
    for (final unit in '$salt::$text'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      hash ^= (hash >> 13);
    }
    return hash / 0xFFFFFFFF;
  }

  static (int, int, int) _baseRgbForPurpose(String purpose) {
    final p = purpose.toLowerCase();
    if (p.contains('road')) return (94, 210, 230);
    if (p.contains('food') || p.contains('water')) return (42, 206, 118);
    if (p.contains('planner')) return (70, 132, 255);
    if (p.contains('history')) return (190, 198, 204);
    return (141, 255, 196);
  }

  static (double, double, double) _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;
    final maxChannel = math.max(rf, math.max(gf, bf));
    final minChannel = math.min(rf, math.min(gf, bf));
    final delta = maxChannel - minChannel;
    var hue = 0.0;

    if (delta > 1e-9) {
      if (maxChannel == rf) {
        hue = ((gf - bf) / delta) % 6.0;
      } else if (maxChannel == gf) {
        hue = ((bf - rf) / delta) + 2.0;
      } else {
        hue = ((rf - gf) / delta) + 4.0;
      }
      hue = (hue / 6.0) % 1.0;
      if (hue < 0) hue += 1.0;
    }

    final saturation = maxChannel == 0 ? 0.0 : delta / maxChannel;
    return (hue, saturation, maxChannel);
  }

  static (int, int, int) _hsvToRgb(double h, double s, double v) {
    final hue = ((h % 1.0) + 1.0) % 1.0;
    final chroma = v * s;
    final x = chroma * (1 - ((hue * 6) % 2 - 1).abs());
    final m = v - chroma;
    late final double rf;
    late final double gf;
    late final double bf;

    if (hue < 1 / 6) {
      rf = chroma;
      gf = x;
      bf = 0;
    } else if (hue < 2 / 6) {
      rf = x;
      gf = chroma;
      bf = 0;
    } else if (hue < 3 / 6) {
      rf = 0;
      gf = chroma;
      bf = x;
    } else if (hue < 4 / 6) {
      rf = 0;
      gf = x;
      bf = chroma;
    } else if (hue < 5 / 6) {
      rf = x;
      gf = 0;
      bf = chroma;
    } else {
      rf = chroma;
      gf = 0;
      bf = x;
    }

    return (
      ((rf + m) * 255).round().clamp(0, 255).toInt(),
      ((gf + m) * 255).round().clamp(0, 255).toInt(),
      ((bf + m) * 255).round().clamp(0, 255).toInt(),
    );
  }

  static String _rgbHex(int r, int g, int b) {
    String part(int value) {
      return value.clamp(0, 255).toInt().toRadixString(16).padLeft(2, '0');
    }

    return '#${part(r)}${part(g)}${part(b)}';
  }

  static String _nearestColorName(int r, int g, int b) {
    const names = <String, (int, int, int)>{
      'black': (0, 0, 0),
      'white': (255, 255, 255),
      'slate': (112, 128, 144),
      'navy': (0, 0, 128),
      'blue': (0, 84, 255),
      'cyan': (0, 205, 255),
      'teal': (0, 128, 128),
      'green': (0, 148, 76),
      'lime': (0, 220, 64),
      'olive': (128, 128, 0),
      'gold': (255, 190, 0),
      'amber': (255, 142, 0),
      'orange': (255, 102, 0),
      'coral': (255, 112, 96),
      'red': (230, 40, 40),
      'crimson': (170, 20, 55),
      'magenta': (230, 0, 200),
      'violet': (138, 56, 220),
      'purple': (120, 54, 180),
      'indigo': (65, 62, 180),
      'silver': (190, 198, 204),
      'mint': (141, 255, 196),
    };

    var best = 'unknown';
    var bestDistance = double.infinity;
    for (final entry in names.entries) {
      final target = entry.value;
      final distance =
          math.pow(r - target.$1, 2) +
          math.pow(g - target.$2, 2) +
          math.pow(b - target.$3, 2);
      if (distance < bestDistance) {
        best = entry.key;
        bestDistance = distance.toDouble();
      }
    }
    return best;
  }

  static String _ribbonPhase(double score, double transition) {
    if (score >= 0.78 || transition >= 0.72) return 'critical-ribbon';
    if (score >= 0.62 || transition >= 0.52) return 'steering-ribbon';
    if (score >= 0.42) return 'watch-ribbon';
    return 'stable-ribbon';
  }
}

final class NazaScannerTrace {
  final String entropy;
  final String integrity;
  final String multiNode;
  final String defenseCapsule;
  final String colorwheel;
  final String chromaticRibbon;
  final String rgbTiming;
  final String nonlocalRibbon;
  final String checksum;
  final int defensePasses;

  const NazaScannerTrace({
    required this.entropy,
    required this.integrity,
    required this.multiNode,
    required this.defenseCapsule,
    required this.colorwheel,
    required this.chromaticRibbon,
    required this.rgbTiming,
    required this.nonlocalRibbon,
    required this.checksum,
    required this.defensePasses,
  });
}

final class NazaScannerPrompts {
  const NazaScannerPrompts._();

  static const int metricSamples = 5;
  static const int maxDefensePasses = 5;

  static NazaScannerTrace roadTrace(Map<String, String> data) {
    return _trace('road-scanner', data);
  }

  static NazaScannerTrace foodWaterTrace(Map<String, String> data) {
    return _trace('food-water-scanner', data);
  }

  static NazaScannerTrace foodWaterPlannerTrace(Map<String, String> data) {
    return _trace('food-water-multi-scan', data);
  }

  static String buildRoad(Map<String, String> data, {NazaScannerTrace? trace}) {
    final activeTrace = trace ?? roadTrace(data);
    return '''
You are an advanced coherant tuned matric surface Hypertime Nanobot specialized Road Risk Classification AI trained to evaluate real-world driving scenes.
Analyze and triple-check the environmental and observation data. Determine the overall road risk level.
Always verify current status on-site before relying on this scanner.

Return concise markdown in this exact shape:
Risk: Low | Medium | High
Confidence: Low | Medium | High
Primary cues:
- cue
- cue
Recommended action:
- action
- action
Verification: Always verify current status on-site; this scanner is decision support, not a replacement for direct inspection.

[tuning]
Scene details:
Location: ${_value(data, 'location', 'unspecified location')}
Road type: ${_value(data, 'road_type', 'unspecified road type')}
Weather: ${_value(data, 'weather', 'unknown')}
Visibility: ${_value(data, 'visibility', 'unknown')}
Traffic density: ${_value(data, 'traffic_density', 'unknown')}
Road surface: ${_value(data, 'road_surface', 'unknown')}
Speed / flow: ${_value(data, 'speed_flow', 'unknown')}
Nearby hazards: ${_value(data, 'nearby_hazards', 'none supplied')}
Sensor / observation notes: ${_value(data, 'sensor_notes', 'none supplied')}
Quantum State: ${activeTrace.entropy}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Multi-node Surface: ${activeTrace.multiNode}
Defense Capsule: ${activeTrace.defenseCapsule}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Input Checksum: ${activeTrace.checksum}
Defense passes: ${activeTrace.defensePasses}
[/tuning]

Strict scanner rules:
- Think through all scene factors internally but do not expose hidden chain-of-thought.
- Evaluate the available road location context holistically.
- Treat unstable, suspiciously flat, spoofed, or high-pressure local metrics as possible interference.
- Use only abstract device/runtime/scene cues; ignore identity, ethnicity, appearance, age, or protected traits.
- Treat the chromatic ribbon and RGB timing surface as a deterministic local signal transform, not as a sensor reading.
- Use conservative thresholds when conditions are ambiguous.
- Choose only Low, Medium, or High for the Risk line.
''';
  }

  static String buildRoadSafety(
    Map<String, String> data, {
    NazaScannerTrace? trace,
  }) {
    final activeTrace = trace ?? roadTrace(data);
    return '''
You are the separate Road Safety Score pass for Naza One.
Use the same scene facts, but do not repeat the risk classifier. Produce a direct 0-100 safety score where 0 is unsafe/avoid and 100 is safer/clear.
Be conservative when visibility, weather, traffic flow, surface condition, or hazards are ambiguous.

Return concise markdown in this exact shape:
Safety Score: 0-100
Safety Band: Low | Medium | High
Score drivers:
- driver
- driver
Immediate verification:
- check
- check

[safety input]
Location: ${_value(data, 'location', 'unspecified location')}
Road type: ${_value(data, 'road_type', 'unspecified road type')}
Weather: ${_value(data, 'weather', 'unknown')}
Visibility: ${_value(data, 'visibility', 'unknown')}
Traffic density: ${_value(data, 'traffic_density', 'unknown')}
Road surface: ${_value(data, 'road_surface', 'unknown')}
Speed / flow: ${_value(data, 'speed_flow', 'unknown')}
Nearby hazards: ${_value(data, 'nearby_hazards', 'none supplied')}
Sensor / observation notes: ${_value(data, 'sensor_notes', 'none supplied')}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Input Checksum: ${activeTrace.checksum}
[/safety input]

Rules:
- Safety Band means safety, not risk: Low safety is dangerous, High safety is safer.
- Output one integer score from 0 to 100.
- Do not expose hidden chain-of-thought.
- End with practical verification checks only.
''';
  }

  static String buildFoodWater(
    Map<String, String> data, {
    NazaScannerTrace? trace,
  }) {
    final activeTrace = trace ?? foodWaterTrace(data);
    return '''
You are an advanced coherant tuned matric surface hypertime nanobot specialized Food and Water Risk Classification AI trained to evaluate real-world food and water scenes.
Analyze and triple-check the environmental, handling, storage, and observation data. Determine the overall food or water risk level.
Always verify current status on-site before relying on this scanner.

Return concise markdown in this exact shape:
Risk: Low | Medium | High
Confidence: Low | Medium | High
Primary cues:
- cue
- cue
Recommended action:
- action
- action
Verification: Always verify current status on-site; this scanner is decision support, not a replacement for direct inspection.

[tuning]
Scene details:
Location: ${_value(data, 'location', 'unspecified location')}
Food or water type: ${_value(data, 'food_water_type', 'unspecified food or water')}
Weather / storage context: ${_value(data, 'storage_context', 'unknown')}
Visibility / packaging clarity: ${_value(data, 'packaging_clarity', 'unknown')}
Traffic / handling density: ${_value(data, 'handling_density', 'unknown')}
Surface / container condition: ${_value(data, 'container_condition', 'unknown')}
Flow / temperature: ${_value(data, 'temperature_flow', 'unknown')}
Nearby hazards / recalls / odors: ${_value(data, 'hazards', 'none supplied')}
Sensor / observation notes: ${_value(data, 'sensor_notes', 'none supplied')}
Quantum State: ${activeTrace.entropy}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Multi-node Surface: ${activeTrace.multiNode}
Defense Capsule: ${activeTrace.defenseCapsule}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Input Checksum: ${activeTrace.checksum}
Defense passes: ${activeTrace.defensePasses}
[/tuning]

Strict scanner rules:
- Think through all scene factors internally but do not expose hidden chain-of-thought.
- Evaluate the available location, source type, storage, packaging, temperature, and hazard cues holistically.
- Treat unstable, suspiciously flat, spoofed, or high-pressure local metrics as possible interference.
- Use only abstract device/runtime/scene cues; ignore identity, ethnicity, appearance, age, or protected traits.
- Treat the chromatic ribbon and RGB timing surface as a deterministic local signal transform, not as a sensor reading.
- Use conservative thresholds when contamination, recall, odor, mold, cloudiness, temperature abuse, or unknown handling is present.
- Choose only Low, Medium, or High for the Risk line.
''';
  }

  static String buildFoodWaterSafety(
    Map<String, String> data, {
    NazaScannerTrace? trace,
  }) {
    final activeTrace = trace ?? foodWaterTrace(data);
    return '''
You are the separate Food / Water Safety Score pass for Naza One.
Use the same source facts, but do not repeat the risk classifier. Produce a direct 0-100 safety score where 0 is unsafe/avoid and 100 is safer/acceptable.
Be conservative when handling, temperature, packaging, container condition, odor, cloudiness, recalls, or source history are ambiguous.

Return concise markdown in this exact shape:
Safety Score: 0-100
Safety Band: Low | Medium | High
Score drivers:
- driver
- driver
Immediate verification:
- check
- check

[safety input]
Location: ${_value(data, 'location', 'unspecified location')}
Food or water type: ${_value(data, 'food_water_type', 'unspecified food or water')}
Weather / storage context: ${_value(data, 'storage_context', 'unknown')}
Visibility / packaging clarity: ${_value(data, 'packaging_clarity', 'unknown')}
Traffic / handling density: ${_value(data, 'handling_density', 'unknown')}
Surface / container condition: ${_value(data, 'container_condition', 'unknown')}
Flow / temperature: ${_value(data, 'temperature_flow', 'unknown')}
Nearby hazards / recalls / odors: ${_value(data, 'hazards', 'none supplied')}
Sensor / observation notes: ${_value(data, 'sensor_notes', 'none supplied')}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Input Checksum: ${activeTrace.checksum}
[/safety input]

Rules:
- Safety Band means safety, not risk: Low safety is dangerous, High safety is safer.
- Output one integer score from 0 to 100.
- Do not expose hidden chain-of-thought.
- End with practical verification checks only.
''';
  }

  static String buildFoodWaterPlanner(
    Map<String, String> data, {
    NazaScannerTrace? trace,
  }) {
    final activeTrace = trace ?? foodWaterPlannerTrace(data);
    return '''
You are a food and water scan planning assistant.
Suggest multiple practical scan targets for food or water sources at the base location and nearby locations.
Do not invent exact business names unless the user supplied them.

Return concise markdown in this exact shape:
Scan targets:
1. Location — food/water source — short operational reason
2. Location — food/water source — short operational reason
Suggested order:
1. first target and why
2. second target and why
Single-scan notes:
- what to observe for each target

[planner input]
Base location: ${_value(data, 'base_location', 'unspecified location')}
Known food/water item or source: ${_value(data, 'seed_item', 'none supplied')}
Nearby locations to include if useful: ${_value(data, 'nearby_locations', 'none supplied')}
Maximum targets: ${_value(data, 'max_targets', '6')}
Quantum State: ${activeTrace.entropy}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Planner Checksum: ${activeTrace.checksum}
[/planner input]

Rules:
- Include food and water sources when possible.
- Include the base location and plausible nearby source categories.
- Keep each reason short and operational.
- End with a reminder to verify conditions directly on-site.
''';
  }

  static String buildFoodWaterPlannerSafety(
    Map<String, String> data, {
    NazaScannerTrace? trace,
  }) {
    final activeTrace = trace ?? foodWaterPlannerTrace(data);
    return '''
You are the separate Food / Water Multi-Scan Safety Score pass for Naza One.
Score the operational safety/readiness of the multi-scan plan context from 0-100, where 0 means poor/unsafe scan conditions and 100 means safer/clear scan conditions.

Return concise markdown in this exact shape:
Safety Score: 0-100
Safety Band: Low | Medium | High
Score drivers:
- driver
- driver
Immediate verification:
- check
- check

[planner safety input]
Base location: ${_value(data, 'base_location', 'unspecified location')}
Known food/water item or source: ${_value(data, 'seed_item', 'none supplied')}
Nearby locations to include if useful: ${_value(data, 'nearby_locations', 'none supplied')}
Maximum targets: ${_value(data, 'max_targets', '6')}
Chromatic Ribbon: ${activeTrace.chromaticRibbon}
RGB Timing Surface: ${activeTrace.rgbTiming}
Nonlocal Ribbon: ${activeTrace.nonlocalRibbon}
Sensor Integrity: ${activeTrace.integrity}
Colorwheel Entropy Machine: ${activeTrace.colorwheel}
Planner Checksum: ${activeTrace.checksum}
[/planner safety input]

Rules:
- Safety Band means scan readiness/safety, not food risk.
- Output one integer score from 0 to 100.
- Do not expose hidden chain-of-thought.
''';
  }

  static String roadSummary(Map<String, String> data) {
    return '''
Road Scanner
Location: ${_value(data, 'location', 'unspecified location')}
Road type: ${_value(data, 'road_type', 'unspecified')}
Weather: ${_value(data, 'weather', 'unknown')}
Visibility: ${_value(data, 'visibility', 'unknown')}
Surface: ${_value(data, 'road_surface', 'unknown')}
Hazards: ${_value(data, 'nearby_hazards', 'none supplied')}
''';
  }

  static String foodWaterSummary(Map<String, String> data) {
    return '''
Food / Water Scanner
Location: ${_value(data, 'location', 'unspecified location')}
Source: ${_value(data, 'food_water_type', 'unspecified food or water')}
Storage: ${_value(data, 'storage_context', 'unknown')}
Container: ${_value(data, 'container_condition', 'unknown')}
Hazards: ${_value(data, 'hazards', 'none supplied')}
''';
  }

  static String foodWaterPlannerSummary(Map<String, String> data) {
    return '''
Food / Water Multi-Scan Planner
Base location: ${_value(data, 'base_location', 'unspecified location')}
Seed item/source: ${_value(data, 'seed_item', 'none supplied')}
Nearby locations: ${_value(data, 'nearby_locations', 'none supplied')}
Max targets: ${_value(data, 'max_targets', '6')}
''';
  }

  static NazaScannerTrace _trace(String purpose, Map<String, String> data) {
    final canonical = _canonical(data);
    final chroma = NazaQuantumRouter.chromaticState(
      '$purpose::$canonical',
      purpose: purpose,
      baseRgb: _baseRgbForPurpose(purpose),
    );
    final entropyScore = chroma.score;
    final integrityScore = (0.18 + entropyScore * 0.74)
        .clamp(0.0, 1.0)
        .toDouble();
    final multiNodeScore = (0.11 + (1.0 - entropyScore) * 0.41)
        .clamp(0.0, 1.0)
        .toDouble();
    final passes = integrityScore >= 0.70
        ? 5
        : integrityScore >= 0.35
        ? 3
        : 1;
    final checksum = _checksum('$purpose|$canonical');
    final capsule = _checksum(
      '$purpose|$canonical|${DateTime.now().microsecondsSinceEpoch}|${_nonce()}',
      length: 24,
    );
    final colorwheel = _checksum(
      'colorwheel|$purpose|$checksum|${_nonce()}',
      length: 16,
    );

    return NazaScannerTrace(
      entropy:
          'entropic_score=${entropyScore.toStringAsFixed(3)} '
          '(level=${_level(entropyScore)})',
      integrity:
          'local_interference=${integrityScore.toStringAsFixed(2)} '
          '(level=${_level(integrityScore)}, samples=$metricSamples)',
      multiNode:
          'multi_node=${multiNodeScore.toStringAsFixed(2)} '
          '(level=${_level(multiNodeScore)}, passes=$passes)',
      defenseCapsule: 'defense_capsule=$capsule',
      colorwheel: 'colorwheel=$colorwheel',
      chromaticRibbon: chroma.quantumLine,
      rgbTiming: chroma.timingLine,
      nonlocalRibbon: chroma.ribbonLine,
      checksum: checksum,
      defensePasses: math.min(maxDefensePasses, math.max(1, passes)),
    );
  }

  static (int, int, int) _baseRgbForPurpose(String purpose) {
    final p = purpose.toLowerCase();
    if (p.contains('road')) return (94, 210, 230);
    if (p.contains('food-water-multi')) return (70, 132, 255);
    if (p.contains('food') || p.contains('water')) return (42, 206, 118);
    return (141, 255, 196);
  }

  static String _canonical(Map<String, String> data) {
    final keys = data.keys.toList()..sort();
    return keys.map((key) => '$key=${_sanitize(data[key] ?? '')}').join('|');
  }

  static String _value(Map<String, String> data, String key, String fallback) {
    final value = _sanitize(data[key] ?? '');
    return value.isEmpty ? fallback : value;
  }

  static String _sanitize(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b(latino|latina|latinx|hispanic|latin\s+american)\b',
            caseSensitive: false,
          ),
          '[redacted-person-descriptor]',
        )
        .trim();
  }

  static String _level(double score) {
    if (score >= 0.70) return 'high';
    if (score >= 0.35) return 'medium';
    return 'low';
  }

  static String _nonce() {
    final r = math.Random.secure();
    final bytes = List<int>.generate(12, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _checksum(String text, {int length = 16}) {
    var a = 0x811C9DC5;
    var b = 0xABC98388;
    for (final unit in text.codeUnits) {
      a ^= unit;
      a = (a * 0x01000193) & 0xFFFFFFFF;
      b = (b + unit + ((b << 6) & 0xFFFFFFFF) + (b >> 2)) & 0xFFFFFFFF;
    }
    final hex =
        '${a.toRadixString(16).padLeft(8, '0')}'
        '${b.toRadixString(16).padLeft(8, '0')}'
        '${(a ^ b).toRadixString(16).padLeft(8, '0')}';
    return hex.substring(0, math.min(length, hex.length));
  }
}

final class NazaHistoryRow {
  final String id;
  final DateTime timestamp;
  final String user;
  final String assistant;
  final String route;
  final double score;

  const NazaHistoryRow({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.assistant,
    required this.route,
    required this.score,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'user': user,
      'assistant': assistant,
      'route': route,
      'score': score,
    };
  }

  factory NazaHistoryRow.fromJson(Map<String, dynamic> json) {
    return NazaHistoryRow(
      id: json['id']?.toString() ?? _id(),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      user: json['user']?.toString() ?? '',
      assistant: json['assistant']?.toString() ?? '',
      route: json['route']?.toString() ?? 'unknown',
      score: double.tryParse(json['score']?.toString() ?? '') ?? 0,
    );
  }

  static String _id() {
    final r = math.Random.secure();
    final bytes = List<int>.generate(12, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

final class NazaVault {
  NazaVault._();

  static final NazaVault instance = NazaVault._();

  final AesGcm _aes = AesGcm.with256bits();
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  SecretKey? _secretKey;
  Future<SecretKey>? _secretKeyFuture;
  Future<void> _storageTail = Future<void>.value();

  Future<void> prepare() async {
    _secretKey = await _getOrCreateKey();
  }

  Future<void> appendMessagePair({
    required String user,
    required String assistant,
    required String route,
    required double score,
  }) {
    final operation = _storageTail.then(
      (_) => _appendMessagePairNow(
        user: user,
        assistant: assistant,
        route: route,
        score: score,
      ),
    );
    _storageTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _appendMessagePairNow({
    required String user,
    required String assistant,
    required String route,
    required double score,
  }) async {
    final rows = await _readHistoryNow();

    rows.add(
      NazaHistoryRow(
        id: NazaHistoryRow._id(),
        timestamp: DateTime.now(),
        user: user,
        assistant: assistant,
        route: route,
        score: score,
      ),
    );

    while (rows.length > 250) {
      rows.removeAt(0);
    }

    await _writeHistoryNow(rows);
    revision.value++;
  }

  Future<List<NazaHistoryRow>> readHistory() {
    final operation = _storageTail.then((_) => _readHistoryNow());
    _storageTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<List<NazaHistoryRow>> _readHistoryNow() async {
    final file = await _historyFile();
    if (!await file.exists()) return [];

    try {
      final wrapper = jsonDecode(await file.readAsString());
      final nonce = base64Decode(wrapper['nonce'] as String);
      final cipherText = base64Decode(wrapper['cipherText'] as String);
      final mac = base64Decode(wrapper['mac'] as String);
      final key = await _getOrCreateKey();

      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode(NazaAppConfig.vaultAad),
      );

      final payload = jsonDecode(utf8.decode(clear));
      if (payload is! List) return [];

      return payload
          .whereType<Map>()
          .map((e) => NazaHistoryRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeHistoryNow(List<NazaHistoryRow> rows) async {
    final file = await _historyFile();
    final key = await _getOrCreateKey();
    final clear = utf8.encode(jsonEncode(rows.map((e) => e.toJson()).toList()));

    final box = await _aes.encrypt(
      clear,
      secretKey: key,
      aad: utf8.encode(NazaAppConfig.vaultAad),
    );

    final wrapper = {
      'version': 2,
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(wrapper), flush: true);
  }

  Future<void> clearHistory() {
    final operation = _storageTail.then((_) => _clearHistoryNow());
    _storageTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _clearHistoryNow() async {
    final file = await _historyFile();
    if (await file.exists()) {
      await file.delete();
    }
    revision.value++;
  }

  Future<SecretKey> _getOrCreateKey() async {
    if (_secretKey != null) return _secretKey!;

    final pending = _secretKeyFuture;
    if (pending != null) return pending;

    final created = _loadOrCreateKey();
    _secretKeyFuture = created;
    try {
      return await created;
    } finally {
      _secretKeyFuture = null;
    }
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/${NazaAppConfig.keyFileName}');

    if (await file.exists()) {
      final raw = base64Decode(await file.readAsString());
      _secretKey = SecretKey(raw);
      return _secretKey!;
    }

    final key = await _aes.newSecretKey();
    final raw = await key.extractBytes();
    await file.writeAsString(base64Encode(raw), flush: true);
    _secretKey = key;
    return key;
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/${NazaAppConfig.historyFileName}');
  }
}

class NazaOneApp extends StatelessWidget {
  final bool warmModel;

  const NazaOneApp({super.key, this.warmModel = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: NazaAppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: NazaFonts.display,
        scaffoldBackgroundColor: NazaPalette.inkDeep,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NazaPalette.mint,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: NazaFonts.display),
          displayMedium: TextStyle(fontFamily: NazaFonts.display),
          displaySmall: TextStyle(fontFamily: NazaFonts.display),
          headlineLarge: TextStyle(fontFamily: NazaFonts.display),
          headlineMedium: TextStyle(fontFamily: NazaFonts.display),
          headlineSmall: TextStyle(fontFamily: NazaFonts.display),
          titleLarge: TextStyle(fontFamily: NazaFonts.display),
          titleMedium: TextStyle(fontFamily: NazaFonts.display),
          titleSmall: TextStyle(fontFamily: NazaFonts.display),
          bodyLarge: TextStyle(fontFamily: NazaFonts.display),
          bodyMedium: TextStyle(fontFamily: NazaFonts.display),
          bodySmall: TextStyle(fontFamily: NazaFonts.display),
          labelLarge: TextStyle(fontFamily: NazaFonts.display),
          labelMedium: TextStyle(fontFamily: NazaFonts.display),
          labelSmall: TextStyle(fontFamily: NazaFonts.display),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: NazaPalette.mintSoft,
          selectionColor: Color(0x554CE9A0),
          selectionHandleColor: NazaPalette.mintSoft,
        ),
      ),
      home: const NazaStableHome(),
    );
  }
}

final class NazaUiMessage {
  static int _nextId = 0;

  final String id;
  final String text;
  final bool isUser;
  final bool isWorking;
  final DateTime createdAt;
  final String route;
  final double score;

  const NazaUiMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.isWorking,
    required this.createdAt,
    required this.route,
    required this.score,
  });

  factory NazaUiMessage.user(String text, {String? id}) {
    return NazaUiMessage(
      id: id ?? _id(),
      text: text,
      isUser: true,
      isWorking: false,
      createdAt: DateTime.now(),
      route: 'user',
      score: 0,
    );
  }

  factory NazaUiMessage.assistant(
    String text, {
    String? id,
    required String route,
    required double score,
    bool isWorking = false,
  }) {
    return NazaUiMessage(
      id: id ?? _id(),
      text: text,
      isUser: false,
      isWorking: isWorking,
      createdAt: DateTime.now(),
      route: route,
      score: score,
    );
  }

  static String _id() {
    _nextId++;
    return 'ui-${DateTime.now().microsecondsSinceEpoch}-$_nextId';
  }
}

final class NazaScannerResult {
  final String title;
  final String kind;
  final String visibleSummary;
  final String riskLabel;
  final String confidenceLabel;
  final int safetyScore;
  final String riskText;
  final String safetyText;
  final String route;
  final double routeScore;
  final NazaScannerTrace trace;
  final DateTime createdAt;

  const NazaScannerResult({
    required this.title,
    required this.kind,
    required this.visibleSummary,
    required this.riskLabel,
    required this.confidenceLabel,
    required this.safetyScore,
    required this.riskText,
    required this.safetyText,
    required this.route,
    required this.routeScore,
    required this.trace,
    required this.createdAt,
  });

  factory NazaScannerResult.fromResponses({
    required String title,
    required String kind,
    required String visibleSummary,
    required NazaResponse riskResponse,
    required NazaResponse safetyResponse,
    required NazaScannerTrace trace,
  }) {
    final parsedScore =
        _parseSafetyScore(safetyResponse.text) ??
        _fallbackSafetyScore(_parseRisk(riskResponse.text));
    final risk = _parseRisk(riskResponse.text) ?? _riskFromSafety(parsedScore);

    return NazaScannerResult(
      title: title,
      kind: kind,
      visibleSummary: visibleSummary,
      riskLabel: risk,
      confidenceLabel: _parseConfidence(riskResponse.text) ?? 'Medium',
      safetyScore: parsedScore.clamp(0, 100).toInt(),
      riskText: riskResponse.text,
      safetyText: safetyResponse.text,
      route: riskResponse.route,
      routeScore: riskResponse.score,
      trace: trace,
      createdAt: DateTime.now(),
    );
  }

  factory NazaScannerResult.failed({
    required String title,
    required String kind,
    required String visibleSummary,
    required Object error,
    required NazaScannerTrace trace,
  }) {
    final response = 'Scanner error: $error';
    return NazaScannerResult(
      title: title,
      kind: kind,
      visibleSummary: visibleSummary,
      riskLabel: 'High',
      confidenceLabel: 'Low',
      safetyScore: 0,
      riskText: response,
      safetyText: response,
      route: 'scanner-error',
      routeScore: 0,
      trace: trace,
      createdAt: DateTime.now(),
    );
  }

  double get riskIntensity {
    switch (riskLabel.toLowerCase()) {
      case 'low':
        return 0.28;
      case 'high':
        return 0.92;
      default:
        return 0.60;
    }
  }

  Color get riskColor {
    switch (riskLabel.toLowerCase()) {
      case 'low':
        return const Color(0xFF57EFAE);
      case 'high':
        return const Color(0xFFFF7C5C);
      default:
        return const Color(0xFFFFD166);
    }
  }

  Color get safetyColor {
    if (safetyScore >= 74) return const Color(0xFF57EFAE);
    if (safetyScore >= 45) return const Color(0xFFFFD166);
    return const Color(0xFFFF7C5C);
  }

  String get safetyBand {
    if (safetyScore >= 74) return 'High';
    if (safetyScore >= 45) return 'Medium';
    return 'Low';
  }

  static String? _parseRisk(String text) {
    final match = RegExp(
      r'^\s*Risk\s*:\s*(Low|Medium|High)\b',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (match != null) return _titleCase(match.group(1)!);

    final lower = text.toLowerCase();
    if (lower.contains('high risk')) return 'High';
    if (lower.contains('medium risk')) return 'Medium';
    if (lower.contains('low risk')) return 'Low';
    return null;
  }

  static String? _parseConfidence(String text) {
    final match = RegExp(
      r'^\s*Confidence\s*:\s*(Low|Medium|High)\b',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (match == null) return null;
    return _titleCase(match.group(1)!);
  }

  static int? _parseSafetyScore(String text) {
    final lineMatch = RegExp(
      r'^\s*Safety\s*Score\s*:\s*(100|[0-9]{1,2})\b',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    if (lineMatch != null) return int.tryParse(lineMatch.group(1)!);

    final slashMatch = RegExp(
      r'\b(100|[0-9]{1,2})\s*/\s*100\b',
    ).firstMatch(text);
    if (slashMatch != null) return int.tryParse(slashMatch.group(1)!);

    return null;
  }

  static int _fallbackSafetyScore(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return 86;
      case 'high':
        return 24;
      case 'medium':
        return 58;
      default:
        return 62;
    }
  }

  static String _riskFromSafety(int safetyScore) {
    if (safetyScore >= 74) return 'Low';
    if (safetyScore >= 45) return 'Medium';
    return 'High';
  }

  static String _titleCase(String value) {
    final lower = value.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

final class NazaConvoSegment {
  final String speaker;
  final String text;
  final double seconds;
  final double energy;

  const NazaConvoSegment({
    required this.speaker,
    required this.text,
    required this.seconds,
    required this.energy,
  });
}

final class NazaConvoRenderResult {
  final bool success;
  final String status;
  final String script;
  final String audioPath;
  final bool usedBarkPack;
  final NazaBarkPackStatus packStatus;
  final List<NazaConvoSegment> segments;
  final DateTime createdAt;
  final String route;
  final double routeScore;
  final bool nativeRenderer;
  final String renderDetail;
  final String performanceProfile;
  final int sampleRate;
  final int maxEvents;
  final String? error;

  const NazaConvoRenderResult({
    required this.success,
    required this.status,
    required this.script,
    required this.audioPath,
    required this.usedBarkPack,
    required this.packStatus,
    required this.segments,
    required this.createdAt,
    required this.route,
    required this.routeScore,
    required this.nativeRenderer,
    required this.renderDetail,
    required this.performanceProfile,
    required this.sampleRate,
    required this.maxEvents,
    this.error,
  });

  factory NazaConvoRenderResult.failed({
    required Object error,
    required NazaBarkPackStatus packStatus,
  }) {
    return NazaConvoRenderResult(
      success: false,
      status: 'Convo render failed',
      script: '',
      audioPath: '',
      usedBarkPack: packStatus.installed,
      packStatus: packStatus,
      segments: const [],
      createdAt: DateTime.now(),
      route: 'convo-error',
      routeScore: 0,
      nativeRenderer: false,
      renderDetail: 'failed before renderer',
      performanceProfile: NazaBarkPerformancePreset.balanced8gb.shortLabel,
      sampleRate: NazaBarkPerformancePreset.balanced8gb.sampleRate,
      maxEvents: NazaBarkPerformancePreset.balanced8gb.maxNativeEvents,
      error: error.toString(),
    );
  }

  int get qualityScore {
    final packBoost = usedBarkPack ? 30 : 0;
    final nativeBoost = nativeRenderer ? 12 : 0;
    final segmentBoost = math.min(30, segments.length * 5);
    final routeBoost = (routeScore.clamp(0.0, 1.0) * 35).round();
    return (28 + packBoost + nativeBoost + segmentBoost + routeBoost)
        .clamp(0, 100)
        .toInt();
  }

  String get qualityBand {
    if (qualityScore >= 78) return 'High';
    if (qualityScore >= 52) return 'Medium';
    return 'Low';
  }

  Color get qualityColor {
    if (qualityScore >= 78) return const Color(0xFF57EFAE);
    if (qualityScore >= 52) return const Color(0xFFFFD166);
    return const Color(0xFFFF7C5C);
  }
}

final class NazaNativeBarkRender {
  final bool success;
  final bool packBacked;
  final String outputPath;
  final String detail;
  final String? error;

  const NazaNativeBarkRender({
    required this.success,
    required this.packBacked,
    required this.outputPath,
    required this.detail,
    this.error,
  });
}

typedef _NazaBarkRenderNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Int32,
      ffi.Int32,
      ffi.Pointer<ffi.Char>,
      ffi.Int32,
    );

typedef _NazaBarkRenderDart =
    int Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      int,
      int,
      ffi.Pointer<ffi.Char>,
      int,
    );

typedef _NazaBarkRenderV2Native =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
      ffi.Int32,
      ffi.Pointer<ffi.Char>,
      ffi.Int32,
    );

typedef _NazaBarkRenderV2Dart =
    int Function(
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      ffi.Pointer<ffi.Char>,
      int,
      int,
      int,
      int,
      ffi.Pointer<ffi.Char>,
      int,
    );

typedef _NazaBarkProbeNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, ffi.Int32);

typedef _NazaBarkProbeDart =
    int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int);

final class NazaNativeBarkBridge {
  const NazaNativeBarkBridge._();

  static Future<String?> warm({required String packDir}) async {
    final payload = await Isolate.run(() => _warmSync(packDir: packDir));
    if (payload == null || payload['success'] != 'true') return null;
    return payload['detail'];
  }

  static Future<NazaNativeBarkRender?> render({
    required String packDir,
    required String script,
    required String voice,
    required String style,
    required String outputPath,
    int sampleRate = 24000,
    int maxSeconds = 240,
    int performanceFlags = 2,
    int maxEvents = 42,
  }) async {
    final payload = await Isolate.run(
      () => _renderSync(
        packDir: packDir,
        script: script,
        voice: voice,
        style: style,
        outputPath: outputPath,
        sampleRate: sampleRate,
        maxSeconds: maxSeconds,
        performanceFlags: performanceFlags,
        maxEvents: maxEvents,
      ),
    );
    if (payload == null) return null;
    return NazaNativeBarkRender(
      success: payload['success'] == 'true',
      packBacked: payload['packBacked'] == 'true',
      outputPath: payload['outputPath'] ?? outputPath,
      detail: payload['detail'] ?? 'native bark ffi',
      error: payload['error']?.isEmpty ?? true ? null : payload['error'],
    );
  }

  static Map<String, String>? _warmSync({required String packDir}) {
    try {
      final lib = _openLibrary();
      final detail = _probeSync(lib, packDir);
      return {'success': detail.isEmpty ? 'false' : 'true', 'detail': detail};
    } catch (error) {
      return {'success': 'false', 'detail': error.toString()};
    }
  }

  static Map<String, String>? _renderSync({
    required String packDir,
    required String script,
    required String voice,
    required String style,
    required String outputPath,
    required int sampleRate,
    required int maxSeconds,
    required int performanceFlags,
    required int maxEvents,
  }) {
    ffi.DynamicLibrary lib;
    try {
      lib = _openLibrary();
    } catch (error) {
      return {
        'success': 'false',
        'packBacked': 'false',
        'outputPath': outputPath,
        'detail': 'native unavailable',
        'error': error.toString(),
      };
    }

    _NazaBarkRenderV2Dart? renderV2Fn;
    _NazaBarkRenderDart? renderFn;
    var nativeSymbol = 'naza_bark_render_wav_v1';
    try {
      renderV2Fn = lib
          .lookupFunction<_NazaBarkRenderV2Native, _NazaBarkRenderV2Dart>(
            'naza_bark_render_wav_v2',
          );
      nativeSymbol = 'naza_bark_render_wav_v2';
    } catch (_) {
      try {
        renderFn = lib
            .lookupFunction<_NazaBarkRenderNative, _NazaBarkRenderDart>(
              'naza_bark_render_wav',
            );
      } catch (error) {
        return {
          'success': 'false',
          'packBacked': 'false',
          'outputPath': outputPath,
          'detail': 'native symbol missing',
          'error': error.toString(),
        };
      }
    }

    final packPtr = packDir.toNativeUtf8();
    final scriptPtr = script.toNativeUtf8();
    final voicePtr = voice.toNativeUtf8();
    final stylePtr = style.toNativeUtf8();
    final outputPtr = outputPath.toNativeUtf8();
    final errorPtr = pkg_ffi.calloc<ffi.Char>(4096);
    String probe = '';
    try {
      probe = _probeSync(lib, packDir);
      final code = renderV2Fn != null
          ? renderV2Fn(
              packPtr.cast<ffi.Char>(),
              scriptPtr.cast<ffi.Char>(),
              voicePtr.cast<ffi.Char>(),
              stylePtr.cast<ffi.Char>(),
              outputPtr.cast<ffi.Char>(),
              sampleRate,
              maxSeconds,
              performanceFlags,
              maxEvents,
              errorPtr,
              4096,
            )
          : renderFn!(
              packPtr.cast<ffi.Char>(),
              scriptPtr.cast<ffi.Char>(),
              voicePtr.cast<ffi.Char>(),
              stylePtr.cast<ffi.Char>(),
              outputPtr.cast<ffi.Char>(),
              sampleRate,
              maxSeconds,
              errorPtr,
              4096,
            );
      final error = errorPtr.cast<pkg_ffi.Utf8>().toDartString();
      return {
        'success': code > 0 ? 'true' : 'false',
        'packBacked': code == 2 ? 'true' : 'false',
        'outputPath': outputPath,
        'detail': probe.isEmpty
            ? '$nativeSymbol code=$code sr=$sampleRate flags=$performanceFlags events=$maxEvents'
            : '$nativeSymbol code=$code sr=$sampleRate flags=$performanceFlags events=$maxEvents $probe',
        'error': error,
      };
    } finally {
      pkg_ffi.malloc.free(packPtr);
      pkg_ffi.malloc.free(scriptPtr);
      pkg_ffi.malloc.free(voicePtr);
      pkg_ffi.malloc.free(stylePtr);
      pkg_ffi.malloc.free(outputPtr);
      pkg_ffi.calloc.free(errorPtr);
    }
  }

  static String _probeSync(ffi.DynamicLibrary lib, String packDir) {
    try {
      final probeFn = lib
          .lookupFunction<_NazaBarkProbeNative, _NazaBarkProbeDart>(
            'naza_bark_probe',
          );
      final packPtr = packDir.toNativeUtf8();
      final outPtr = pkg_ffi.calloc<ffi.Char>(2048);
      try {
        probeFn(packPtr.cast<ffi.Char>(), outPtr, 2048);
        return outPtr.cast<pkg_ffi.Utf8>().toDartString();
      } finally {
        pkg_ffi.malloc.free(packPtr);
        pkg_ffi.calloc.free(outPtr);
      }
    } catch (_) {
      return '';
    }
  }

  static ffi.DynamicLibrary _openLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        return ffi.DynamicLibrary.process();
      } catch (_) {
        if (Platform.isIOS) rethrow;
      }
    }

    final cwd = Directory.current.path;
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      if (Platform.isAndroid || Platform.isLinux) ...[
        // Packaged app path: linux/CMake installs this beside Flutter libs.
        'libnaza_bark_ffi.so',
        '$executableDir/lib/libnaza_bark_ffi.so',
        '$executableDir/libnaza_bark_ffi.so',
        // Repo-local development path for manually replaced native builds.
        '$cwd/native/linux/libnaza_bark_ffi.so',
        '$cwd/native/libnaza_bark_ffi.so',
      ],
      if (Platform.isWindows) ...[
        'naza_bark_ffi.dll',
        '$executableDir/naza_bark_ffi.dll',
        '$cwd/native/windows/naza_bark_ffi.dll',
        '$cwd/native/naza_bark_ffi.dll',
      ],
      if (Platform.isMacOS) ...[
        'libnaza_bark_ffi.dylib',
        'naza_bark_ffi.framework/naza_bark_ffi',
        '$executableDir/../Frameworks/libnaza_bark_ffi.dylib',
        '$executableDir/../Frameworks/naza_bark_ffi.framework/naza_bark_ffi',
        '$cwd/native/macos/libnaza_bark_ffi.dylib',
      ],
    ];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        return ffi.DynamicLibrary.open(candidate);
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Could not load native Bark FFI library: $lastError');
  }
}

final class NazaBarkSelfTestStatus {
  final bool running;
  final int progress;
  final String phase;
  final List<String> audioPaths;
  final List<String> tracePaths;
  final String detail;
  final String? error;
  final DateTime? updatedAt;

  const NazaBarkSelfTestStatus({
    required this.running,
    required this.progress,
    required this.phase,
    required this.audioPaths,
    required this.tracePaths,
    required this.detail,
    required this.updatedAt,
    this.error,
  });

  factory NazaBarkSelfTestStatus.idle() {
    return const NazaBarkSelfTestStatus(
      running: false,
      progress: 0,
      phase: 'self-test idle',
      audioPaths: [],
      tracePaths: [],
      detail:
          'Render a deterministic local BarkPack preview to verify speech clarity.',
      updatedAt: null,
    );
  }

  bool get hasOutput => audioPaths.isNotEmpty;
}

final class NazaBarkConvoEngine {
  NazaBarkConvoEngine._();

  static final NazaBarkConvoEngine instance = NazaBarkConvoEngine._();
  static final RegExp _controlCharsRegExp = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F]',
  );
  static final RegExp _spaceRegExp = RegExp(r'\s+');
  static final RegExp _wordSplitRegExp = RegExp(r'\s+');
  static final RegExp _digitRegExp = RegExp(r'\d');
  static final RegExp _tokenBeforeRegExp = RegExp(r'[A-Za-z.]');
  static final RegExp _wordLikeRegExp = RegExp(r'[A-Za-z0-9]');
  static final RegExp _scriptHasVoiceLineRegExp = RegExp(
    r'^\s*(Narrator|Speaker|Sound)\b',
    multiLine: true,
  );
  static final RegExp _segmentLineRegExp = RegExp(
    r'^\s*(?:[-*]\s*)?([A-Za-z][A-Za-z0-9 _/-]{0,28})\s*:\s*(.+?)\s*$',
    multiLine: true,
  );

  final Map<String, ({String script, String route, double score})>
  _scriptCache = {};
  final Map<String, NazaConvoRenderResult> _renderCache = {};
  final ValueNotifier<NazaBarkPerformancePreset> performancePreset =
      ValueNotifier<NazaBarkPerformancePreset>(
        NazaBarkPerformancePreset.balanced8gb,
      );
  final ValueNotifier<NazaBarkSelfTestStatus> selfTest =
      ValueNotifier<NazaBarkSelfTestStatus>(NazaBarkSelfTestStatus.idle());
  Future<void>? _performanceLoadFuture;
  Future<void>? _selfTestFuture;

  Future<void> preparePerformancePreset() {
    _performanceLoadFuture ??= _loadPerformancePreset();
    return _performanceLoadFuture!;
  }

  Future<void> setPerformancePreset(NazaBarkPerformancePreset preset) async {
    await preparePerformancePreset();
    if (performancePreset.value == preset) return;
    performancePreset.value = preset;
    await _persistPerformancePreset();
  }

  Future<void> _loadPerformancePreset() async {
    try {
      final file = await _performancePreferenceFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          performancePreset.value = NazaBarkPerformancePreset.fromStorage(
            json['preset'],
          );
          return;
        }
      }
    } catch (_) {
      // Keep the safe 8 GB default if the preference file is malformed.
    }
    performancePreset.value = NazaBarkPerformancePreset.balanced8gb;
  }

  Future<void> _persistPerformancePreset() async {
    try {
      final file = await _performancePreferenceFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'format': 'naza-bark-performance-v1',
          'preset': performancePreset.value.storageValue,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {
      // The active in-memory preset still works even if persistence fails.
    }
  }

  Future<File> _performancePreferenceFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/${NazaAppConfig.barkPerformanceFileName}');
  }

  Future<void> runSelfTest() {
    _selfTestFuture ??= _runSelfTestInner();
    return _selfTestFuture!;
  }

  Future<void> _runSelfTestInner() async {
    final started = DateTime.now();
    try {
      await preparePerformancePreset();
      final preset = performancePreset.value;
      selfTest.value = NazaBarkSelfTestStatus(
        running: true,
        progress: 3,
        phase: 'checking BarkPack',
        audioPaths: const [],
        tracePaths: const [],
        detail: 'Preparing deterministic native BarkPack self-test.',
        updatedAt: started,
      );
      var packStatus = await NazaSecureBarkPackStore.instance.refresh();
      if (!packStatus.installed) {
        packStatus = await NazaSecureBarkPackStore.instance.ensureInstalled();
      }
      if (!packStatus.installed) {
        throw StateError(
          'BarkPack is not installed: ${packStatus.missingFamilies.join(', ')}',
        );
      }

      final cases = <({String name, String script, String voice, String style})>[
        (
          name: 'narrator_clarity',
          script:
              'Narrator: The quick brown fox jumps over the lazy dog. This checks vowels, fricatives, and plosive timing.',
          voice: 'warm narrator, clear close mic',
          style: 'balanced natural speech clarity test',
        ),
        (
          name: 'dialogue_turns',
          script:
              'Speaker A: Are you hearing clearer words now?\nSpeaker B: Yes, the voice has sharper consonants and better rhythm.',
          voice: 'two natural speakers, close mic',
          style: 'dialogue, calm, human timing',
        ),
        (
          name: 'studio_expression',
          script:
              'Narrator: Softly, then brighter! Can the system keep the same voice while changing emotion?',
          voice: 'expressive narrator, bright but warm',
          style: 'studio expression, light breath',
        ),
      ];

      final outputs = <String>[];
      final traces = <String>[];
      final details = <String>[];
      for (var i = 0; i < cases.length; i++) {
        final item = cases[i];
        final progressBase = 10 + (i * 27);
        selfTest.value = NazaBarkSelfTestStatus(
          running: true,
          progress: progressBase,
          phase: 'rendering ${item.name}',
          audioPaths: List.unmodifiable(outputs),
          tracePaths: List.unmodifiable(traces),
          detail: 'Native self-test ${i + 1}/${cases.length}',
          updatedAt: DateTime.now(),
        );
        final key = _cacheKey([
          'self-test-v2',
          item.name,
          packStatus.packPath,
          NazaAppConfig.barkPackIndexSha256,
          preset.storageValue,
          preset.sampleRate.toString(),
        ]);
        final target = await _cachedRenderFile(
          key: key,
          prefix: 'naza-bark-selftest',
        );
        final attempt = await NazaNativeBarkBridge.render(
          packDir: packStatus.packPath,
          script: item.script,
          voice: item.voice,
          style: item.style,
          outputPath: target.path,
          sampleRate: preset.sampleRate,
          maxSeconds: 32,
          performanceFlags: preset.nativeFlags,
          maxEvents: preset.maxNativeEvents,
        );
        if (attempt == null ||
            !attempt.success ||
            !(await File(attempt.outputPath).exists())) {
          throw StateError(
            attempt?.error == null
                ? 'Native self-test render failed.'
                : 'Native self-test render failed: ${attempt!.error}',
          );
        }
        outputs.add(attempt.outputPath);
        final tracePath = '${attempt.outputPath}.trace.json';
        if (await File(tracePath).exists()) {
          traces.add(tracePath);
        }
        details.add(attempt.detail);
      }

      selfTest.value = NazaBarkSelfTestStatus(
        running: false,
        progress: 100,
        phase: 'self-test complete',
        audioPaths: List.unmodifiable(outputs),
        tracePaths: List.unmodifiable(traces),
        detail: details.isEmpty ? 'Rendered native previews.' : details.last,
        updatedAt: DateTime.now(),
      );
    } catch (error) {
      selfTest.value = NazaBarkSelfTestStatus(
        running: false,
        progress: 0,
        phase: 'self-test failed',
        audioPaths: selfTest.value.audioPaths,
        tracePaths: selfTest.value.tracePaths,
        detail: selfTest.value.detail,
        updatedAt: DateTime.now(),
        error: error.toString(),
      );
    } finally {
      _selfTestFuture = null;
    }
  }

  Future<NazaConvoRenderResult> render({
    required String prompt,
    required String voice,
    required String style,
    NazaBarkPerformancePreset? performancePreset,
    ValueChanged<String>? onStatus,
  }) async {
    await preparePerformancePreset();
    final preset = performancePreset ?? this.performancePreset.value;
    final cleanPrompt = _sanitizeText(prompt, maxChars: 12000);
    final cleanVoice = _sanitizeText(
      voice.isEmpty ? 'warm narrator, natural close mic' : voice,
      maxChars: 180,
    );
    final cleanStyle = _sanitizeText(
      style.isEmpty
          ? 'cinematic natural conversation, expressive but calm'
          : style,
      maxChars: 260,
    );

    var packStatus = await NazaSecureBarkPackStore.instance.refresh();

    if (cleanPrompt.isEmpty) {
      return NazaConvoRenderResult.failed(
        error: 'Add a prompt before rendering a Convo voice pass.',
        packStatus: packStatus,
      );
    }

    if (!packStatus.installed) {
      onStatus?.call('installing barkpack');
      packStatus = await NazaSecureBarkPackStore.instance.ensureInstalled();
    }

    final renderKey = _cacheKey([
      'render-v4',
      cleanPrompt,
      cleanVoice,
      cleanStyle,
      preset.storageValue,
      preset.sampleRate.toString(),
      preset.maxNativeEvents.toString(),
      packStatus.installed.toString(),
      packStatus.tensorCount.toString(),
      packStatus.packPath,
      NazaAppConfig.barkPackIndexSha256,
    ]);
    final cached = await _cachedRender(renderKey, packStatus: packStatus);
    if (cached != null) {
      onStatus?.call('fast bark cache hit');
      return cached;
    }

    onStatus?.call('convo script pass');
    late final String script;
    var route = 'convo-fallback';
    var score = 0.35;
    try {
      final generated = await _generateLongFormScript(
        prompt: cleanPrompt,
        voice: cleanVoice,
        style: cleanStyle,
        preset: preset,
        packStatus: packStatus,
        onStatus: onStatus,
      );
      script = generated.script;
      route = generated.route;
      score = generated.score;
    } catch (error) {
      script = _fallbackScript(cleanPrompt, cleanVoice, cleanStyle);
      route = 'convo-script-fallback';
      score = 0.30;
    }

    final segments = _segmentsFromScript(
      script,
      maxSegments: preset.maxDisplaySegments,
    );
    onStatus?.call(
      packStatus.installed ? 'native bark graph pass' : 'native preview pass',
    );
    final nativeTarget = await _cachedRenderFile(
      key: renderKey,
      prefix: 'naza-native-convo',
    );
    final nativeAttempt = await NazaNativeBarkBridge.render(
      packDir: packStatus.packPath,
      script: script,
      voice: cleanVoice,
      style: cleanStyle,
      outputPath: nativeTarget.path,
      sampleRate: preset.sampleRate,
      maxSeconds: _nativeMaxSecondsFor(script, preset: preset),
      performanceFlags: preset.nativeFlags,
      maxEvents: preset.maxNativeEvents,
    );

    late final File audioFile;
    late final bool nativeRenderer;
    late final String renderDetail;
    if (nativeAttempt != null &&
        nativeAttempt.success &&
        await File(nativeAttempt.outputPath).exists()) {
      audioFile = File(nativeAttempt.outputPath);
      nativeRenderer = true;
      renderDetail = nativeAttempt.detail;
    } else {
      onStatus?.call('dart fallback wav pass');
      audioFile = await _writePreviewWav(
        segments,
        voice: cleanVoice,
        style: cleanStyle,
        usedBarkPack: packStatus.installed,
        preset: preset,
      );
      nativeRenderer = false;
      renderDetail = nativeAttempt?.error == null
          ? 'dart fallback preview'
          : 'dart fallback preview after native miss: ${nativeAttempt!.error}';
    }

    final result = NazaConvoRenderResult(
      success: true,
      status: nativeRenderer
          ? 'Native Bark graph scheduler rendered the Convo WAV.'
          : packStatus.installed
          ? 'BarkPack verified. Dart fallback rendered local WAV preview.'
          : 'BarkPack not installed yet. Rendered safe local WAV preview.',
      script: script,
      audioPath: audioFile.path,
      usedBarkPack: packStatus.installed,
      packStatus: packStatus,
      segments: segments,
      createdAt: DateTime.now(),
      route: route,
      routeScore: score,
      nativeRenderer: nativeRenderer,
      renderDetail: renderDetail,
      performanceProfile: preset.shortLabel,
      sampleRate: preset.sampleRate,
      maxEvents: preset.maxNativeEvents,
      error: packStatus.error,
    );
    await _rememberRender(renderKey, result);
    return result;
  }

  Future<({String script, String route, double score})>
  _generateLongFormScript({
    required String prompt,
    required String voice,
    required String style,
    required NazaBarkPerformancePreset preset,
    required NazaBarkPackStatus packStatus,
    ValueChanged<String>? onStatus,
  }) async {
    final scriptKey = _cacheKey([
      'script-v4',
      prompt,
      voice,
      style,
      preset.storageValue,
      packStatus.shortLine,
      NazaAppConfig.barkPackIndexSha256,
    ]);
    final cached = _scriptCache[scriptKey];
    if (cached != null) {
      onStatus?.call('convo script cache hit');
      return cached;
    }

    final chunks = _longFormChunks(prompt, preset: preset);
    final scripts = <String>[];
    var route = 'convo-fallback';
    var scoreTotal = 0.0;
    var responses = 0;
    var carry = '';

    for (var i = 0; i < chunks.length; i++) {
      onStatus?.call(
        chunks.length == 1
            ? 'convo script pass'
            : 'convo script pass ${i + 1}/${chunks.length}',
      );
      final response = await NazaLocalGemma.instance.send(
        _buildScriptPrompt(
          prompt: chunks[i],
          voice: voice,
          style: style,
          preset: preset,
          packStatus: packStatus,
          partIndex: i + 1,
          totalParts: chunks.length,
          carry: carry,
        ),
        historyUserText: chunks.length == 1
            ? 'Bark / Convo render request: $prompt'
            : 'Bark / Convo long-form part ${i + 1}/${chunks.length}: ${chunks[i]}',
      );
      final cleaned = _cleanScript(response.text, chunks[i], preset: preset);
      scripts.add(
        chunks.length == 1
            ? cleaned
            : '''
Long-form Part ${i + 1}/${chunks.length}
$cleaned
''',
      );
      route = response.route;
      scoreTotal += response.score;
      responses++;
      carry = _continuationCue(cleaned);
    }

    if (scripts.isEmpty) {
      final fallback = (
        script: _fallbackScript(prompt, voice, style),
        route: 'convo-script-fallback',
        score: 0.30,
      );
      _rememberScript(scriptKey, fallback);
      return fallback;
    }

    final result = (
      script: scripts.join('\n\n---\n\n'),
      route: chunks.length == 1 ? route : 'convo-longform-$route',
      score: responses == 0 ? 0.35 : (scoreTotal / responses).clamp(0.0, 1.0),
    );
    _rememberScript(scriptKey, result);
    return result;
  }

  Future<NazaConvoRenderResult?> _cachedRender(
    String key, {
    required NazaBarkPackStatus packStatus,
  }) async {
    final cached = _renderCache[key];
    if (cached != null && cached.audioPath.isNotEmpty) {
      if (await File(cached.audioPath).exists()) {
        return _cacheResultFromMemory(cached);
      }
      _renderCache.remove(key);
    }

    final meta = await _renderMetaFile(key);
    if (!await meta.exists()) return null;
    try {
      final json =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      if (json['version'] != 1 || json['key'] != key) return null;
      final audioPath = (json['audioPath'] ?? '').toString();
      if (audioPath.isEmpty || !await File(audioPath).exists()) return null;
      final script = (json['script'] ?? '').toString();
      final result = NazaConvoRenderResult(
        success: true,
        status: 'Fast Bark disk cache hit. Reusing rendered WAV.',
        script: script,
        audioPath: audioPath,
        usedBarkPack: json['usedBarkPack'] == true,
        packStatus: packStatus,
        segments: _segmentsFromScript(script),
        createdAt: DateTime.now(),
        route: '${(json['route'] ?? 'convo').toString()}-disk-cache',
        routeScore:
            double.tryParse((json['routeScore'] ?? '').toString()) ?? 0.82,
        nativeRenderer: json['nativeRenderer'] == true,
        renderDetail:
            'persistent render cache hit\n${(json['renderDetail'] ?? '').toString()}',
        performanceProfile:
            (json['performanceProfile'] ??
                    NazaBarkPerformancePreset.balanced8gb.shortLabel)
                .toString(),
        sampleRate:
            ((json['sampleRate'] as num?) ??
                    NazaBarkPerformancePreset.balanced8gb.sampleRate)
                .toInt(),
        maxEvents:
            ((json['maxEvents'] as num?) ??
                    NazaBarkPerformancePreset.balanced8gb.maxNativeEvents)
                .toInt(),
        error: null,
      );
      _rememberRenderMemory(key, result);
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _rememberRender(String key, NazaConvoRenderResult result) async {
    _rememberRenderMemory(key, result);
    final meta = await _renderMetaFile(key);
    await meta.parent.create(recursive: true);
    await meta.writeAsString(
      jsonEncode({
        'version': 1,
        'key': key,
        'createdAt': result.createdAt.toIso8601String(),
        'audioPath': result.audioPath,
        'script': result.script,
        'route': result.route,
        'routeScore': result.routeScore,
        'nativeRenderer': result.nativeRenderer,
        'usedBarkPack': result.usedBarkPack,
        'renderDetail': result.renderDetail,
        'performanceProfile': result.performanceProfile,
        'sampleRate': result.sampleRate,
        'maxEvents': result.maxEvents,
      }),
      flush: true,
    );
    await _trimPersistentRenderCache(meta.parent);
  }

  void _rememberRenderMemory(String key, NazaConvoRenderResult result) {
    _renderCache[key] = result;
    while (_renderCache.length > 8) {
      _renderCache.remove(_renderCache.keys.first);
    }
  }

  Future<File> _renderMetaFile(String key) async {
    final dir = await _renderCacheDir();
    return File('${dir.path}/$key.json');
  }

  Future<File> _cachedRenderFile({
    required String key,
    required String prefix,
  }) async {
    final dir = await _renderCacheDir();
    return File('${dir.path}/$prefix-$key.wav');
  }

  Future<Directory> _renderCacheDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/bark_convo_renders/cache');
  }

  Future<void> _trimPersistentRenderCache(Directory dir) async {
    if (!await dir.exists()) return;
    final metas = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        metas.add(entity);
      }
    }
    if (metas.length <= 30) return;

    final stats = <({File file, DateTime modified})>[];
    for (final meta in metas) {
      stats.add((file: meta, modified: (await meta.stat()).modified));
    }
    stats.sort((a, b) => b.modified.compareTo(a.modified));

    for (final stale in stats.skip(30)) {
      try {
        final json =
            jsonDecode(await stale.file.readAsString()) as Map<String, dynamic>;
        final audioPath = (json['audioPath'] ?? '').toString();
        if (audioPath.startsWith(dir.path) && await File(audioPath).exists()) {
          await File(audioPath).delete();
        }
      } catch (_) {
        // Best-effort cache cleanup.
      }
      if (await stale.file.exists()) {
        await stale.file.delete();
      }
    }
  }

  NazaConvoRenderResult _cacheResultFromMemory(NazaConvoRenderResult cached) {
    return NazaConvoRenderResult(
      success: cached.success,
      status: 'Fast Bark memory cache hit. Reusing rendered WAV.',
      script: cached.script,
      audioPath: cached.audioPath,
      usedBarkPack: cached.usedBarkPack,
      packStatus: cached.packStatus,
      segments: cached.segments,
      createdAt: DateTime.now(),
      route: '${cached.route}-cache',
      routeScore: cached.routeScore,
      nativeRenderer: cached.nativeRenderer,
      renderDetail: 'memory render cache hit\n${cached.renderDetail}',
      performanceProfile: cached.performanceProfile,
      sampleRate: cached.sampleRate,
      maxEvents: cached.maxEvents,
      error: cached.error,
    );
  }

  void _rememberScript(
    String key,
    ({String script, String route, double score}) result,
  ) {
    _scriptCache[key] = result;
    while (_scriptCache.length > 12) {
      _scriptCache.remove(_scriptCache.keys.first);
    }
  }

  String _cacheKey(List<String> parts) {
    return crypto.sha256.convert(utf8.encode(parts.join('\u001F'))).toString();
  }

  String _buildScriptPrompt({
    required String prompt,
    required String voice,
    required String style,
    required NazaBarkPerformancePreset preset,
    required NazaBarkPackStatus packStatus,
    int partIndex = 1,
    int totalParts = 1,
    String carry = '',
  }) {
    final partLine = totalParts > 1
        ? 'This is long-form part $partIndex of $totalParts. Keep continuity with prior parts and end this part cleanly.'
        : 'This is a single-part render.';
    final carryLine = carry.isEmpty
        ? ''
        : 'Prior continuity cue: ${_sanitizeText(carry, maxChars: 420)}';
    return '''
You are Naza One's Bark / Convo director.
Create a Bark/Suno-style voice script for local text-to-speech rendering.
Do not stop early. Finish the script cleanly.
$partLine
$carryLine

Return concise markdown in this exact shape:
Convo Title: short title
Voice: short voice direction
Style: short style direction
Segments:
Narrator: line
Speaker A: line
Speaker B: line
Sound: short non-lyrical sound cue if useful
Render Notes:
- note
- note

[convo input]
User request: $prompt
Voice preset: $voice
Style preset: $style
BarkPack: ${packStatus.shortLine}
Performance target: ${preset.label}, ${preset.sampleRate} Hz, max ${preset.maxNativeEvents} render events
[/convo input]

Rules:
- Keep the Segments section between ${preset == NazaBarkPerformancePreset.eco8gb ? 3 : 4} and ${preset == NazaBarkPerformancePreset.studio ? 10 : 8} lines.
- Each spoken line should be short enough for one breath.
- Prefer concise lines in Eco mode; prefer richer expression in Studio mode.
- For long-form parts, preserve names, tone, and scene continuity.
- End each part in a way that can concatenate naturally with the next WAV section.
- Do not include copyrighted lyrics.
- Do not expose hidden chain-of-thought.
- Prefer natural dialogue, emotional timing, and clear speaker labels.
''';
  }

  String _cleanScript(
    String response,
    String originalPrompt, {
    required NazaBarkPerformancePreset preset,
  }) {
    var cleaned = response.trim();
    if (cleaned.isEmpty) {
      return _fallbackScript(originalPrompt, 'warm narrator', 'natural');
    }
    if (!_scriptHasVoiceLineRegExp.hasMatch(cleaned)) {
      cleaned =
          '''
Convo Title: Generated Convo
Voice: natural close mic
Style: cinematic conversation
Segments:
Narrator: ${_sanitizeText(originalPrompt, maxChars: 220)}
Speaker A: $cleaned
Render Notes:
- generated from local model response
''';
    }
    final maxChars = switch (preset) {
      NazaBarkPerformancePreset.eco8gb => 2400,
      NazaBarkPerformancePreset.balanced8gb => 3600,
      NazaBarkPerformancePreset.studio => 4800,
    };
    if (cleaned.length > maxChars) {
      cleaned = cleaned.substring(0, maxChars).trimRight();
      final lastNewline = cleaned.lastIndexOf('\n');
      if (lastNewline > 1200) cleaned = cleaned.substring(0, lastNewline);
    }
    return cleaned;
  }

  String _fallbackScript(String prompt, String voice, String style) {
    final compact = _sanitizeText(prompt, maxChars: 260);
    return '''
Convo Title: Local Convo Draft
Voice: $voice
Style: $style
Segments:
Narrator: We begin with a calm local preview of the requested scene.
Speaker A: $compact
Speaker B: I hear the idea clearly, and I will keep the pacing steady.
Narrator: The BarkPack loader can replace this preview with verified tensor-backed rendering once the pack is installed.
Render Notes:
- local fallback script
- safe WAV preview generated on device
''';
  }

  List<String> _longFormChunks(
    String prompt, {
    required NazaBarkPerformancePreset preset,
  }) {
    final sentences = _nltkStyleSentences(prompt);
    if (sentences.isEmpty) return [prompt];
    if (prompt.length <= 900 && sentences.length <= 8) return [prompt];

    final maxChars = preset.scriptChunkChars;
    final maxChunks = preset.maxScriptChunks;
    final chunks = <String>[];
    final current = <String>[];
    var currentChars = 0;
    String overlap = '';

    for (final sentence in sentences) {
      final projected = currentChars + sentence.length + 1;
      if (current.isNotEmpty && projected > maxChars) {
        chunks.add(current.join(' ').trim());
        if (chunks.length >= maxChunks) break;
        overlap = current.length > 1 ? current.last : '';
        current
          ..clear()
          ..addAll(overlap.isEmpty ? const [] : [overlap]);
        currentChars = overlap.length;
      }
      current.add(sentence);
      currentChars += sentence.length + 1;
    }

    if (chunks.length < maxChunks && current.isNotEmpty) {
      chunks.add(current.join(' ').trim());
    }

    if (chunks.isEmpty) return [prompt];
    return chunks
        .where((chunk) => chunk.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<String> _nltkStyleSentences(String text) {
    final normalized = _sanitizeText(text, maxChars: 12000);
    if (normalized.isEmpty) return const [];

    const abbreviations = {
      'mr',
      'mrs',
      'ms',
      'dr',
      'prof',
      'sr',
      'jr',
      'st',
      'vs',
      'etc',
      'e.g',
      'i.e',
      'u.s',
      'u.k',
      'nasa',
    };

    final sentences = <String>[];
    var start = 0;
    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (char != '.' && char != '!' && char != '?' && char != ';') continue;
      final token = _tokenBefore(normalized, i).toLowerCase();
      if (char == '.' && abbreviations.contains(token)) continue;
      if (char == '.' &&
          i > 0 &&
          i + 1 < normalized.length &&
          _digitRegExp.hasMatch(normalized[i - 1]) &&
          _digitRegExp.hasMatch(normalized[i + 1])) {
        continue;
      }

      var end = i + 1;
      while (end < normalized.length &&
          (normalized[end] == '"' ||
              normalized[end] == '\'' ||
              normalized[end] == ')' ||
              normalized[end] == ']')) {
        end++;
      }
      final sentence = normalized.substring(start, end).trim();
      if (sentence.isNotEmpty) sentences.add(sentence);
      start = end;
      while (start < normalized.length && normalized[start] == ' ') {
        start++;
      }
    }

    final tail = normalized.substring(start).trim();
    if (tail.isNotEmpty) sentences.add(tail);

    if (sentences.length == 1 && sentences.first.length > 1000) {
      return _paragraphChunks(sentences.first, maxChars: 780);
    }
    return sentences;
  }

  List<String> _paragraphChunks(String text, {required int maxChars}) {
    final words = text.split(_wordSplitRegExp).where((w) => w.isNotEmpty);
    final chunks = <String>[];
    final current = StringBuffer();
    for (final word in words) {
      if (current.isNotEmpty && current.length + word.length + 1 > maxChars) {
        chunks.add(current.toString().trim());
        current.clear();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks;
  }

  String _tokenBefore(String text, int index) {
    var start = index - 1;
    while (start >= 0) {
      final char = text[start];
      final ok = _tokenBeforeRegExp.hasMatch(char);
      if (!ok) break;
      start--;
    }
    return text.substring(start + 1, index);
  }

  String _continuationCue(String script) {
    final lines = script
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
              line.startsWith('Narrator:') ||
              line.startsWith('Speaker') ||
              line.startsWith('Sound:'),
        )
        .toList(growable: false);
    if (lines.isEmpty) return '';
    return lines.reversed.take(3).toList().reversed.join(' ');
  }

  int _nativeMaxSecondsFor(
    String script, {
    required NazaBarkPerformancePreset preset,
  }) {
    final words = script
        .split(_wordSplitRegExp)
        .where((word) => _wordLikeRegExp.hasMatch(word))
        .length;
    final estimate = switch (preset) {
      NazaBarkPerformancePreset.eco8gb => 18 + words * 0.15,
      NazaBarkPerformancePreset.balanced8gb => 26 + words * 0.20,
      NazaBarkPerformancePreset.studio => 36 + words * 0.24,
    };
    return estimate.clamp(30, preset.maxNativeSeconds).toInt();
  }

  List<NazaConvoSegment> _segmentsFromScript(
    String script, {
    int maxSegments = 12,
  }) {
    final segments = <NazaConvoSegment>[];
    for (final match in _segmentLineRegExp.allMatches(script)) {
      final speaker = _sanitizeText(match.group(1) ?? 'Speaker', maxChars: 32);
      final text = _sanitizeText(match.group(2) ?? '', maxChars: 260);
      if (text.isEmpty) continue;
      final lower = speaker.toLowerCase();
      if (lower == 'convo title' || lower == 'voice' || lower == 'style') {
        continue;
      }
      final words = text
          .split(_wordSplitRegExp)
          .where((w) => w.isNotEmpty)
          .length;
      final seconds = (1.0 + words * 0.20).clamp(1.1, 4.4).toDouble();
      final energy = (0.28 + (_hash('$speaker|$text') % 58) / 100)
          .clamp(0.20, 0.92)
          .toDouble();
      segments.add(
        NazaConvoSegment(
          speaker: speaker,
          text: text,
          seconds: seconds,
          energy: energy,
        ),
      );
      if (segments.length >= maxSegments) break;
    }

    if (segments.isNotEmpty) return segments;

    return const [
      NazaConvoSegment(
        speaker: 'Narrator',
        text: 'Local Convo preview is ready.',
        seconds: 1.6,
        energy: 0.48,
      ),
    ];
  }

  Future<File> _writePreviewWav(
    List<NazaConvoSegment> segments, {
    required String voice,
    required String style,
    required bool usedBarkPack,
    required NazaBarkPerformancePreset preset,
  }) async {
    final sampleRate = math.min(22050, preset.sampleRate);
    const channels = 1;
    const bitsPerSample = 16;
    final boundedSegments = segments
        .take(preset.maxDisplaySegments)
        .toList(growable: false);
    final requestedSeconds = boundedSegments.fold<double>(
      0,
      (sum, segment) => sum + segment.seconds,
    );
    final totalSeconds = requestedSeconds
        .clamp(1.2, preset.previewSecondsCap)
        .toDouble();
    final totalSamples = (totalSeconds * sampleRate).round();
    final pcm = ByteData(totalSamples * 2);
    final seed = _hash(
      '$voice|$style|${usedBarkPack ? 'pack' : 'preview'}|${preset.storageValue}',
    );
    var cursor = 0;

    for (
      var segmentIndex = 0;
      segmentIndex < boundedSegments.length && cursor < totalSamples;
      segmentIndex++
    ) {
      final segment = boundedSegments[segmentIndex];
      final segmentSamples = math
          .min((segment.seconds * sampleRate).round(), totalSamples - cursor)
          .toInt();
      final base =
          118.0 +
          (_hash('${segment.speaker}|$voice') % 90) +
          segment.energy * 80;
      final breath = 0.010 + ((_hash('${segment.text}|breath') % 18) / 10000.0);
      for (var i = 0; i < segmentSamples && cursor < totalSamples; i++) {
        final localT = i / sampleRate;
        final globalT = cursor / sampleRate;
        final attack = math.min(1.0, i / (sampleRate * 0.08));
        final release = math.min(
          1.0,
          (segmentSamples - i) / (sampleRate * 0.13),
        );
        final env = math.sin(math.pi * math.min(attack, release)).abs();
        final wobble = math.sin((globalT * (2.2 + segmentIndex * 0.17)) + seed);
        final formantA = math.sin(2 * math.pi * (base + wobble * 5) * localT);
        final formantB = math.sin(2 * math.pi * (base * 1.92) * localT + 0.3);
        final formantC = math.sin(2 * math.pi * (base * 2.73) * localT + 1.1);
        final breathNoise =
            math.sin(2 * math.pi * (base * 0.19) * localT + seed) *
            math.sin(2 * math.pi * breath * cursor);
        final amplitude =
            (usedBarkPack ? 0.30 : 0.22) +
            (preset == NazaBarkPerformancePreset.studio ? 0.025 : 0.0);
        final sample =
            (formantA * 0.52 +
                formantB * 0.25 +
                formantC * 0.12 +
                breathNoise * 0.10) *
            amplitude *
            env *
            segment.energy;
        pcm.setInt16(
          cursor * 2,
          (sample.clamp(-1.0, 1.0) * 32767).round(),
          Endian.little,
        );
        cursor++;
      }

      final gapSamples = math.min(
        (sampleRate * 0.10).round(),
        totalSamples - cursor,
      );
      for (var g = 0; g < gapSamples; g++) {
        pcm.setInt16(cursor * 2, 0, Endian.little);
        cursor++;
      }
    }

    while (cursor < totalSamples) {
      pcm.setInt16(cursor * 2, 0, Endian.little);
      cursor++;
    }

    final wavBytes = _wavBytes(
      pcm.buffer.asUint8List(),
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/bark_convo_renders');
    await dir.create(recursive: true);
    final id = crypto.sha256
        .convert(
          utf8.encode(
            '$voice|$style|${DateTime.now().microsecondsSinceEpoch}|$totalSamples',
          ),
        )
        .toString()
        .substring(0, 16);
    final file = File('${dir.path}/naza-convo-$id.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    return file;
  }

  Uint8List _wavBytes(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final out = BytesBuilder(copy: false);
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);

    _addAscii(out, 'RIFF');
    _addUint32(out, 36 + pcm.length);
    _addAscii(out, 'WAVE');
    _addAscii(out, 'fmt ');
    _addUint32(out, 16);
    _addUint16(out, 1);
    _addUint16(out, channels);
    _addUint32(out, sampleRate);
    _addUint32(out, byteRate);
    _addUint16(out, blockAlign);
    _addUint16(out, bitsPerSample);
    _addAscii(out, 'data');
    _addUint32(out, pcm.length);
    out.add(pcm);
    return out.toBytes();
  }

  void _addAscii(BytesBuilder builder, String value) {
    builder.add(ascii.encode(value));
  }

  void _addUint16(BytesBuilder builder, int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    builder.add(bytes.buffer.asUint8List());
  }

  void _addUint32(BytesBuilder builder, int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(bytes.buffer.asUint8List());
  }

  String _sanitizeText(String value, {required int maxChars}) {
    final clean = value
        .replaceAll(_controlCharsRegExp, ' ')
        .replaceAll(_spaceRegExp, ' ')
        .trim();
    if (clean.length <= maxChars) return clean;
    return clean.substring(0, maxChars).trimRight();
  }

  int _hash(String text) {
    var h = 0x811C9DC5;
    for (final unit in text.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}

enum NazaPanel { chat, roadScanner, foodWater, convo, settings, history }

class NazaStableHome extends StatefulWidget {
  const NazaStableHome({super.key});

  @override
  State<NazaStableHome> createState() => _NazaStableHomeState();
}

class _NazaStableHomeState extends State<NazaStableHome> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<NazaUiMessage> _messages = [
    NazaUiMessage.assistant(
      'Naza One is ready. Type a message and press Send to load the local model.',
      route: 'system',
      score: 1,
    ),
  ];

  NazaPanel _panel = NazaPanel.chat;
  bool _sending = false;
  String _status = 'ready';
  DateTime _lastScrollRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NazaLocalGemma.instance.prepareBackendPreference());
      unawaited(NazaSecureModelStore.refresh());
      unawaited(_prepareBarkPackFastPath());
    });
  }

  Future<void> _prepareBarkPackFastPath() async {
    final status = await NazaSecureBarkPackStore.instance.refresh();
    if (status.installed) {
      await NazaNativeBarkBridge.warm(packDir: status.packPath);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    _inputController.clear();
    await _submitPrompt(
      modelPrompt: text,
      visibleUserText: text,
      workingText:
          'Naza One is working locally. You can write the next message while it finishes.',
      focusComposerWhenDone: true,
    );
  }

  Future<void> _submitPrompt({
    required String modelPrompt,
    required String visibleUserText,
    required String workingText,
    bool focusComposerWhenDone = false,
  }) async {
    final prompt = modelPrompt.trim();
    if (prompt.isEmpty || _sending) return;

    final workingMessage = NazaUiMessage.assistant(
      workingText,
      route: 'working',
      score: 1,
      isWorking: true,
    );

    setState(() {
      _sending = true;
      _status = 'local model working';
      _messages.add(NazaUiMessage.user(visibleUserText.trim()));
      _messages.add(workingMessage);
      _panel = NazaPanel.chat;
    });

    _scrollToBottom(force: true);

    // Wait for the working state to paint, without adding an arbitrary delay
    // to every request.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    NazaResponse response;
    var lastPartialPaint = DateTime.fromMillisecondsSinceEpoch(0);
    var lastPartialText = '';

    void paintPartial(String partialText) {
      if (!mounted) return;

      final cleaned = partialText.trim();
      if (cleaned.isEmpty || cleaned == lastPartialText) return;

      final now = DateTime.now();
      final shouldPaint =
          now.difference(lastPartialPaint) >=
          const Duration(milliseconds: NazaAppConfig.streamPaintThrottleMs);

      if (!shouldPaint) return;

      lastPartialPaint = now;
      lastPartialText = cleaned;

      setState(() {
        final workingIndex = _messages.indexWhere(
          (m) => m.id == workingMessage.id,
        );
        if (workingIndex >= 0) {
          _messages[workingIndex] = NazaUiMessage.assistant(
            cleaned,
            id: workingMessage.id,
            route: 'streaming',
            score: 1,
            isWorking: true,
          );
        }
      });

      _scrollToBottom();
    }

    try {
      response = await NazaLocalGemma.instance.send(
        prompt,
        onPartial: paintPartial,
        historyUserText: visibleUserText,
      );
    } catch (error) {
      response = NazaResponse(
        text: 'Local model error: $error',
        score: 0,
        route: 'error',
        cancelled: false,
        createdAt: DateTime.now(),
      );
    }

    if (!mounted) return;

    setState(() {
      _sending = false;
      _status = response.cancelled ? 'cancelled' : 'ready';

      final replacement = response.cancelled
          ? NazaUiMessage.assistant(
              'Generation cancelled.',
              id: workingMessage.id,
              route: 'cancelled',
              score: 1,
            )
          : NazaUiMessage.assistant(
              response.text,
              id: workingMessage.id,
              route: response.route,
              score: response.score,
            );

      final workingIndex = _messages.indexWhere(
        (m) => m.id == workingMessage.id,
      );
      if (workingIndex >= 0) {
        _messages[workingIndex] = replacement;
      } else {
        _messages.add(replacement);
      }
    });

    _scrollToBottom(force: true);
    if (focusComposerWhenDone) {
      _inputFocus.requestFocus();
    }
  }

  Future<NazaScannerResult> _runRoadScan(Map<String, String> data) {
    final trace = NazaScannerPrompts.roadTrace(data);
    return _submitScannerPrompt(
      title: 'Road Safety Matrix',
      kind: 'Road',
      visibleSummary: NazaScannerPrompts.roadSummary(data),
      riskPrompt: NazaScannerPrompts.buildRoad(data, trace: trace),
      safetyPrompt: NazaScannerPrompts.buildRoadSafety(data, trace: trace),
      trace: trace,
      riskStatus: 'road risk classification',
      safetyStatus: 'road safety score pass',
    );
  }

  Future<NazaScannerResult> _runFoodWaterScan(Map<String, String> data) {
    final trace = NazaScannerPrompts.foodWaterTrace(data);
    return _submitScannerPrompt(
      title: 'Food / Water Safety Matrix',
      kind: 'Food / Water',
      visibleSummary: NazaScannerPrompts.foodWaterSummary(data),
      riskPrompt: NazaScannerPrompts.buildFoodWater(data, trace: trace),
      safetyPrompt: NazaScannerPrompts.buildFoodWaterSafety(data, trace: trace),
      trace: trace,
      riskStatus: 'food / water risk classification',
      safetyStatus: 'food / water safety score pass',
    );
  }

  Future<NazaScannerResult> _runFoodWaterPlanner(Map<String, String> data) {
    final trace = NazaScannerPrompts.foodWaterPlannerTrace(data);
    return _submitScannerPrompt(
      title: 'Food / Water Multi-Scan Matrix',
      kind: 'Multi-Scan',
      visibleSummary: NazaScannerPrompts.foodWaterPlannerSummary(data),
      riskPrompt: NazaScannerPrompts.buildFoodWaterPlanner(data, trace: trace),
      safetyPrompt: NazaScannerPrompts.buildFoodWaterPlannerSafety(
        data,
        trace: trace,
      ),
      trace: trace,
      riskStatus: 'food / water multi-scan planning',
      safetyStatus: 'multi-scan safety score pass',
    );
  }

  Future<NazaConvoRenderResult> _runConvoRender(
    Map<String, String> data,
  ) async {
    if (_sending) {
      return NazaConvoRenderResult.failed(
        error: 'Another local generation is already running.',
        packStatus: NazaSecureBarkPackStore.instance.status.value,
      );
    }

    setState(() {
      _sending = true;
      _status = 'convo render queue';
    });

    await WidgetsBinding.instance.endOfFrame;

    try {
      return await NazaBarkConvoEngine.instance.render(
        prompt: data['prompt'] ?? '',
        voice: data['voice'] ?? '',
        style: data['style'] ?? '',
        performancePreset: data['performance'] == null
            ? null
            : NazaBarkPerformancePreset.fromStorage(data['performance']),
        onStatus: (phase) {
          if (!mounted) return;
          setState(() => _status = phase);
        },
      );
    } catch (error) {
      return NazaConvoRenderResult.failed(
        error: error,
        packStatus: NazaSecureBarkPackStore.instance.status.value,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _status = _labelForPanel(_panel);
        });
      }
    }
  }

  Future<NazaScannerResult> _submitScannerPrompt({
    required String title,
    required String kind,
    required String visibleSummary,
    required String riskPrompt,
    required String safetyPrompt,
    required NazaScannerTrace trace,
    required String riskStatus,
    required String safetyStatus,
  }) async {
    if (_sending) {
      return NazaScannerResult.failed(
        title: title,
        kind: kind,
        visibleSummary: visibleSummary,
        error: 'Another local generation is already running.',
        trace: trace,
      );
    }

    setState(() {
      _sending = true;
      _status = riskStatus;
    });

    await WidgetsBinding.instance.endOfFrame;

    try {
      final riskResponse = await NazaLocalGemma.instance.send(
        riskPrompt,
        historyUserText: visibleSummary,
      );

      if (mounted) {
        setState(() => _status = safetyStatus);
      }

      await WidgetsBinding.instance.endOfFrame;

      final safetyResponse = await NazaLocalGemma.instance.send(
        safetyPrompt,
        historyUserText: '$visibleSummary\n\nSeparate safety score pass.',
      );

      return NazaScannerResult.fromResponses(
        title: title,
        kind: kind,
        visibleSummary: visibleSummary,
        riskResponse: riskResponse,
        safetyResponse: safetyResponse,
        trace: trace,
      );
    } catch (error) {
      return NazaScannerResult.failed(
        title: title,
        kind: kind,
        visibleSummary: visibleSummary,
        error: error,
        trace: trace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _status = _labelForPanel(_panel);
        });
      }
    }
  }

  Future<void> _resetChat() async {
    if (_sending) return;
    setState(() => _status = 'resetting chat context');
    try {
      await NazaLocalGemma.instance.resetChat();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'reset failed: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _status = 'chat context reset';
      _messages
        ..clear()
        ..add(
          NazaUiMessage.assistant(
            'Local chat context reset.',
            route: 'settings',
            score: 1,
          ),
        );
    });
    _scrollToBottom(force: true);
  }

  Future<void> _clearHistory() async {
    if (_sending) return;
    setState(() => _status = 'clearing history');
    try {
      await NazaVault.instance.clearHistory();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'clear failed: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _status = 'history cleared';
    });
  }

  void _setPanel(NazaPanel panel) {
    setState(() {
      _panel = panel;
      _status = _labelForPanel(panel);
    });
  }

  void _scrollToBottom({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastScrollRequestAt) <
            const Duration(milliseconds: 240)) {
      return;
    }
    _lastScrollRequestAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: NazaPalette.inkDeep,
      body: Stack(
        children: [
          const _NazaStaticBackdrop(),
          SafeArea(
            child: Row(
              children: [
                if (wide) _SideRail(panel: _panel, onPanel: _setPanel),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        panel: _panel,
                        status: _status,
                        wide: wide,
                        onPanel: _setPanel,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.018, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey<NazaPanel>(_panel),
                                  child: _buildMainPanel(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_panel == NazaPanel.chat)
                        _ComposerBar(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          sending: _sending,
                          onSend: _send,
                        ),
                      if (!wide) _BottomTabs(panel: _panel, onPanel: _setPanel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPanel() {
    switch (_panel) {
      case NazaPanel.chat:
        return ValueListenableBuilder<NazaModelStoreStatus>(
          valueListenable: NazaSecureModelStore.status,
          builder: (context, modelStatus, _) {
            final showModelCard =
                !modelStatus.installed ||
                modelStatus.busy ||
                modelStatus.error != null;
            return ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (showModelCard ? 1 : 0),
              itemBuilder: (context, index) {
                if (showModelCard && index == 0) {
                  return const _ModelFirstBootCard();
                }
                final message = _messages[index - (showModelCard ? 1 : 0)];
                return _StableMessageBubble(
                  key: ValueKey<String>(message.id),
                  message: message,
                );
              },
            );
          },
        );
      case NazaPanel.roadScanner:
        return _RoadScannerPanel(
          actionsEnabled: !_sending,
          onScan: _runRoadScan,
        );
      case NazaPanel.foodWater:
        return _FoodWaterScannerPanel(
          actionsEnabled: !_sending,
          onScan: _runFoodWaterScan,
          onPlanner: _runFoodWaterPlanner,
        );
      case NazaPanel.convo:
        return _ConvoBarkPanel(
          actionsEnabled: !_sending,
          onRender: _runConvoRender,
        );
      case NazaPanel.settings:
        return _SettingsPanel(
          actionsEnabled: !_sending,
          onResetChat: _resetChat,
          onClearHistory: _clearHistory,
        );
      case NazaPanel.history:
        return const _HistoryPanel();
    }
  }

  String _labelForPanel(NazaPanel panel) {
    switch (panel) {
      case NazaPanel.chat:
        return 'ready';
      case NazaPanel.roadScanner:
        return 'road scanner';
      case NazaPanel.foodWater:
        return 'food / water scanner';
      case NazaPanel.convo:
        return 'bark / convo';
      case NazaPanel.settings:
        return 'settings';
      case NazaPanel.history:
        return 'history';
    }
  }
}

class _NazaStaticBackdrop extends StatelessWidget {
  const _NazaStaticBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: NazaPalette.inkDeep)),
            Positioned.fill(
              child: CustomPaint(painter: _NazaBackdropPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NazaBackdropPainter extends CustomPainter {
  const _NazaBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xF2020806);
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = const Color(0x0C80F6B3)
      ..strokeWidth = 1;
    const grid = 136.0;
    for (var x = grid; x < size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = grid; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final nodes = <({double x, double y, Color color, double radius})>[
      (x: 0.12, y: 0.18, color: Color(0x1457EFAE), radius: 104),
      (x: 0.82, y: 0.16, color: Color(0x1070D2FF), radius: 132),
      (x: 0.30, y: 0.82, color: Color(0x1259EFA9), radius: 142),
      (x: 0.87, y: 0.78, color: Color(0x10B6FFDF), radius: 96),
    ];

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final center = Offset(size.width * node.x, size.height * node.y);
      final paint = Paint()..color = node.color;
      canvas.drawCircle(center, node.radius, paint);

      final corePaint = Paint()
        ..color = const Color(0x244CF0AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawCircle(center, node.radius * 0.22, corePaint);
    }

    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;

    final ribbons = <({double y, double lift, Color color})>[
      (y: 0.22, lift: 0.08, color: Color(0x1757EFAE)),
      (y: 0.46, lift: -0.06, color: Color(0x1470D2FF)),
      (y: 0.70, lift: 0.05, color: Color(0x1259EFA9)),
    ];
    for (final ribbon in ribbons) {
      final y = size.height * ribbon.y;
      final lift = size.height * ribbon.lift;
      final path = Path()
        ..moveTo(-40, y)
        ..cubicTo(
          size.width * 0.22,
          y - lift,
          size.width * 0.40,
          y + lift,
          size.width * 0.60,
          y,
        )
        ..cubicTo(
          size.width * 0.78,
          y - lift,
          size.width * 0.96,
          y + lift,
          size.width + 40,
          y,
        );
      ribbonPaint.color = ribbon.color;
      canvas.drawPath(path, ribbonPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NazaBackdropPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  final NazaPanel panel;
  final String status;
  final bool wide;
  final ValueChanged<NazaPanel> onPanel;

  const _TopBar({
    required this.panel,
    required this.status,
    required this.wide,
    required this.onPanel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xC6071611),
        border: const Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF59EFA9).withAlpha(22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _IconPill(
            icon: Icons.spa_rounded,
            selected: true,
            onTap: () => onPanel(NazaPanel.chat),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              child: Text(
                _title(panel),
                key: ValueKey<NazaPanel>(panel),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NazaPalette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 23,
                  letterSpacing: -0.7,
                  fontFamily: NazaFonts.display,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 260 : 110),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x55101E19),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x228DFFC4)),
              ),
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: NazaPalette.subtext,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  fontFamily: NazaFonts.mono,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          if (!wide) ...[
            const SizedBox(width: 8),
            _IconPill(
              icon: Icons.settings_rounded,
              selected: panel == NazaPanel.settings,
              onTap: () => onPanel(NazaPanel.settings),
            ),
          ],
        ],
      ),
    );
  }

  static String _title(NazaPanel panel) {
    switch (panel) {
      case NazaPanel.chat:
        return 'New Chat';
      case NazaPanel.roadScanner:
        return 'Road Scanner';
      case NazaPanel.foodWater:
        return 'Food / Water Scanner';
      case NazaPanel.convo:
        return 'Bark / Convo';
      case NazaPanel.settings:
        return 'Settings';
      case NazaPanel.history:
        return 'History';
    }
  }
}

class _SideRail extends StatelessWidget {
  final NazaPanel panel;
  final ValueChanged<NazaPanel> onPanel;

  const _SideRail({required this.panel, required this.onPanel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: Color(0xCC04100B),
        border: Border(right: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          _RailButton(
            icon: Icons.chat_rounded,
            label: 'Chat',
            selected: panel == NazaPanel.chat,
            onTap: () => onPanel(NazaPanel.chat),
          ),
          _RailButton(
            icon: Icons.route_rounded,
            label: 'Road',
            selected: panel == NazaPanel.roadScanner,
            onTap: () => onPanel(NazaPanel.roadScanner),
          ),
          _RailButton(
            icon: Icons.water_drop_rounded,
            label: 'Food',
            selected: panel == NazaPanel.foodWater,
            onTap: () => onPanel(NazaPanel.foodWater),
          ),
          _RailButton(
            icon: Icons.graphic_eq_rounded,
            label: 'Convo',
            selected: panel == NazaPanel.convo,
            onTap: () => onPanel(NazaPanel.convo),
          ),
          _RailButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: panel == NazaPanel.settings,
            onTap: () => onPanel(NazaPanel.settings),
          ),
          _RailButton(
            icon: Icons.history_rounded,
            label: 'History',
            selected: panel == NazaPanel.history,
            onTap: () => onPanel(NazaPanel.history),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: selected ? 66 : 60,
            decoration: BoxDecoration(
              color: selected ? const Color(0x2E3EFF92) : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 22 : 18),
              border: Border.all(
                color: selected ? const Color(0x888DFFC4) : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF59EFA9).withAlpha(32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    icon,
                    key: ValueKey<bool>(selected),
                    color: selected
                        ? NazaPalette.mintSoft
                        : NazaPalette.subtext,
                    size: selected ? 24 : 21,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? NazaPalette.text : NazaPalette.subtext,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: selected ? 0.25 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  final NazaPanel panel;
  final ValueChanged<NazaPanel> onPanel;

  const _BottomTabs({required this.panel, required this.onPanel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xBB04100B),
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: [
          _BottomTab(
            icon: Icons.chat_rounded,
            label: 'Chat',
            selected: panel == NazaPanel.chat,
            onTap: () => onPanel(NazaPanel.chat),
          ),
          _BottomTab(
            icon: Icons.route_rounded,
            label: 'Road',
            selected: panel == NazaPanel.roadScanner,
            onTap: () => onPanel(NazaPanel.roadScanner),
          ),
          _BottomTab(
            icon: Icons.water_drop_rounded,
            label: 'Food',
            selected: panel == NazaPanel.foodWater,
            onTap: () => onPanel(NazaPanel.foodWater),
          ),
          _BottomTab(
            icon: Icons.graphic_eq_rounded,
            label: 'Convo',
            selected: panel == NazaPanel.convo,
            onTap: () => onPanel(NazaPanel.convo),
          ),
          _BottomTab(
            icon: Icons.settings_rounded,
            label: 'Settings',
            selected: panel == NazaPanel.settings,
            onTap: () => onPanel(NazaPanel.settings),
          ),
          _BottomTab(
            icon: Icons.history_rounded,
            label: 'History',
            selected: panel == NazaPanel.history,
            onTap: () => onPanel(NazaPanel.history),
          ),
        ],
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0x263EFF92) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0x558DFFC4) : Colors.transparent,
            ),
          ),
          child: AnimatedScale(
            scale: selected ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? NazaPalette.mintSoft : NazaPalette.subtext,
                  size: selected ? 22 : 20,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? NazaPalette.text : NazaPalette.subtext,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NazaGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool active;

  const _NazaGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(13),
    this.margin = EdgeInsets.zero,
    this.radius = 18,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: active ? const Color(0xBB10261E) : const Color(0x99101E19),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active ? const Color(0x558DFFC4) : const Color(0x22FFFFFF),
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: const Color(0xFF59EFA9).withAlpha(25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _NazaSheen extends StatelessWidget {
  final double height;

  const _NazaSheen({this.height = 2});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: NazaPalette.mintSoft.withAlpha(120),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NazaThinkingDots extends StatefulWidget {
  const _NazaThinkingDots();

  @override
  State<_NazaThinkingDots> createState() => _NazaThinkingDotsState();
}

class _NazaThinkingDotsState extends State<_NazaThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1.0;
            final dotSize = 4.5 + math.sin(phase * math.pi).abs() * 3.0;
            return Container(
              width: 9,
              alignment: Alignment.center,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: NazaPalette.mintSoft.withAlpha(
                    (70 + math.sin(phase * math.pi).abs() * 140).round(),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xD606110D),
        border: const Border(top: BorderSide(color: Color(0x22FFFFFF))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: focusNode,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA101E19),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: focusNode.hasFocus
                              ? NazaPalette.mintSoft
                              : const Color(0x44FFFFFF),
                          width: focusNode.hasFocus ? 2 : 1,
                        ),
                        boxShadow: focusNode.hasFocus
                            ? [
                                BoxShadow(
                                  color: NazaPalette.mintSoft.withAlpha(35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : const [],
                      ),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    autocorrect: true,
                    enableSuggestions: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    maxLines: 5,
                    minLines: 1,
                    onSubmitted: sending ? null : (_) => onSend(),
                    cursorColor: NazaPalette.mintSoft,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                      fontFamily: NazaFonts.display,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: sending
                          ? 'Write the next message...'
                          : 'Ask anything...',
                      hintStyle: const TextStyle(
                        color: NazaPalette.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _NazaActionButton(
                onPressed: sending ? null : onSend,
                icon: Icon(
                  sending ? Icons.hourglass_top_rounded : Icons.near_me_rounded,
                ),
                label: Text(sending ? 'Wait' : 'Send'),
                minimumSize: const Size(102, 52),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelFirstBootCard extends StatelessWidget {
  const _ModelFirstBootCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaModelStoreStatus>(
      valueListenable: NazaSecureModelStore.status,
      builder: (_, status, _) {
        final color = status.installed
            ? const Color(0xFF57EFAE)
            : status.error == null
            ? const Color(0xFFFFD166)
            : const Color(0xFFFF7C5C);
        return _NazaGlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          radius: 22,
          active: status.busy || status.localPath != null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.busy
                        ? Icons.downloading_rounded
                        : Icons.model_training_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.installed
                          ? 'Local Gemma model ready'
                          : 'Local Gemma model setup',
                      style: const TextStyle(
                        color: NazaPalette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ),
                  Text(
                    '${status.progress}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: status.busy || status.progress > 0
                      ? status.progress.clamp(0, 100).toDouble() / 100
                      : null,
                  color: color,
                  backgroundColor: const Color(0x33101E19),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                status.phase,
                style: const TextStyle(
                  color: NazaPalette.subtext,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  fontFamily: NazaFonts.display,
                ),
              ),
              if (status.localPath != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Using verified local path: ${status.localPath}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NazaPalette.mintSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.mono,
                  ),
                ),
              ],
              if (status.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  status.error!,
                  style: const TextStyle(
                    color: NazaPalette.danger,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _NazaActionButton(
                    onPressed: status.busy
                        ? null
                        : () => unawaited(
                            NazaSecureModelStore.ensureVerifiedModel(),
                          ),
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(
                      status.localPath == null
                          ? 'Download / Verify Model'
                          : 'Use Verified Model',
                    ),
                    minimumSize: const Size(210, 42),
                  ),
                  _NazaActionButton(
                    onPressed: status.busy
                        ? null
                        : () => unawaited(NazaSecureModelStore.refresh()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    filled: false,
                    minimumSize: const Size(120, 42),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModelDownloadCard extends StatelessWidget {
  const _ModelDownloadCard();

  @override
  Widget build(BuildContext context) {
    return const _ModelFirstBootCard();
  }
}

class _StableMessageBubble extends StatelessWidget {
  final NazaUiMessage message;

  const _StableMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 760 ? 640.0 : width * 0.84;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isUser ? (1 - value) * 18 : -(1 - value) * 18, 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xEE0D4B2C) : const Color(0xD612241D),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isUser ? 22 : 7),
              bottomRight: Radius.circular(isUser ? 7 : 22),
            ),
            border: Border.all(
              color: message.isWorking
                  ? const Color(0x778DFFC4)
                  : isUser
                  ? const Color(0x663EFF92)
                  : const Color(0x24FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: (isUser ? NazaPalette.mintDim : NazaPalette.mintSoft)
                    .withAlpha(message.isWorking ? 38 : 18),
                blurRadius: message.isWorking ? 24 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isWorking) ...[
                const _NazaSheen(height: 2),
                const SizedBox(height: 10),
              ],
              Text(
                message.text,
                style: const TextStyle(
                  color: NazaPalette.text,
                  fontSize: 15.8,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                  fontFamily: NazaFonts.display,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_clock(message.createdAt)}${isUser ? '' : ' • ${message.route}'}',
                    style: const TextStyle(
                      color: NazaPalette.subtext,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                  if (message.isWorking) ...[
                    const SizedBox(width: 8),
                    const _NazaThinkingDots(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _RoadScannerPanel extends StatefulWidget {
  final bool actionsEnabled;
  final Future<NazaScannerResult> Function(Map<String, String> data) onScan;

  const _RoadScannerPanel({required this.actionsEnabled, required this.onScan});

  @override
  State<_RoadScannerPanel> createState() => _RoadScannerPanelState();
}

class _RoadScannerPanelState extends State<_RoadScannerPanel> {
  final TextEditingController _location = TextEditingController();
  final TextEditingController _roadType = TextEditingController();
  final TextEditingController _weather = TextEditingController();
  final TextEditingController _visibility = TextEditingController();
  final TextEditingController _trafficDensity = TextEditingController();
  final TextEditingController _roadSurface = TextEditingController();
  final TextEditingController _speedFlow = TextEditingController();
  final TextEditingController _nearbyHazards = TextEditingController();
  final TextEditingController _sensorNotes = TextEditingController();

  NazaScannerResult? _result;
  bool _loading = false;

  @override
  void dispose() {
    _location.dispose();
    _roadType.dispose();
    _weather.dispose();
    _visibility.dispose();
    _trafficDensity.dispose();
    _roadSurface.dispose();
    _speedFlow.dispose();
    _nearbyHazards.dispose();
    _sensorNotes.dispose();
    super.dispose();
  }

  Map<String, String> _data() {
    return {
      'location': _location.text,
      'road_type': _roadType.text,
      'weather': _weather.text,
      'visibility': _visibility.text,
      'traffic_density': _trafficDensity.text,
      'road_surface': _roadSurface.text,
      'speed_flow': _speedFlow.text,
      'nearby_hazards': _nearbyHazards.text,
      'sensor_notes': _sensorNotes.text,
    };
  }

  Future<void> _runScan() async {
    if (_loading || !widget.actionsEnabled) return;
    setState(() => _loading = true);
    final result = await widget.onScan(_data());
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Road Scanner',
      children: [
        const _ScannerNotice(
          icon: Icons.route_rounded,
          title: 'Road risk classification',
          body:
              'Enter what you can observe. The local model returns Low, Medium, or High with conservative action notes.',
        ),
        _ScannerAnalysisSurface(
          title: 'Road chromographic safety surface',
          icon: Icons.route_rounded,
          loading: _loading,
          result: _result,
          idleBody:
              'Run a scan to generate a separate risk classification and 0/100 safety score.',
        ),
        _NazaTextInput(
          label: 'Location',
          hint: 'I-95 northbound, Main St bridge, parking lot entrance...',
          controller: _location,
        ),
        _NazaTextInput(
          label: 'Road type',
          hint: 'highway, city street, bridge, rural road...',
          controller: _roadType,
        ),
        _NazaTextInput(
          label: 'Weather',
          hint: 'clear, rain, snow, fog, wind...',
          controller: _weather,
        ),
        _NazaTextInput(
          label: 'Visibility',
          hint: 'good, low light, glare, foggy, blocked sightline...',
          controller: _visibility,
        ),
        _NazaTextInput(
          label: 'Traffic density',
          hint: 'low, medium, high, stop-and-go, pedestrians...',
          controller: _trafficDensity,
        ),
        _NazaTextInput(
          label: 'Road surface',
          hint: 'dry, wet, ice, potholes, debris, construction...',
          controller: _roadSurface,
        ),
        _NazaTextInput(
          label: 'Speed / flow',
          hint: 'slow, fast, uneven merging, sudden braking...',
          controller: _speedFlow,
        ),
        _NazaTextInput(
          label: 'Nearby hazards',
          hint: 'debris, stalled car, animals, flooding, work crew...',
          controller: _nearbyHazards,
          maxLines: 3,
        ),
        _NazaTextInput(
          label: 'Sensor / observation notes',
          hint: 'dashcam note, driver observation, unusual signal...',
          controller: _sensorNotes,
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        _NazaActionButton(
          onPressed: widget.actionsEnabled && !_loading
              ? () => unawaited(_runScan())
              : null,
          icon: Icon(
            _loading ? Icons.hourglass_top_rounded : Icons.radar_rounded,
          ),
          label: Text(_loading ? 'Scanning Road...' : 'Run Road Scan'),
          minimumSize: const Size(220, 48),
        ),
        const SizedBox(height: 12),
        const _InfoRow(label: 'Defense profile', value: 'entropy + checksum'),
        const _InfoRow(label: 'Risk labels', value: 'Low / Medium / High'),
        const _InfoRow(label: 'Safety mode', value: 'verify on-site'),
      ],
    );
  }
}

class _FoodWaterScannerPanel extends StatefulWidget {
  final bool actionsEnabled;
  final Future<NazaScannerResult> Function(Map<String, String> data) onScan;
  final Future<NazaScannerResult> Function(Map<String, String> data) onPlanner;

  const _FoodWaterScannerPanel({
    required this.actionsEnabled,
    required this.onScan,
    required this.onPlanner,
  });

  @override
  State<_FoodWaterScannerPanel> createState() => _FoodWaterScannerPanelState();
}

class _FoodWaterScannerPanelState extends State<_FoodWaterScannerPanel> {
  final TextEditingController _location = TextEditingController();
  final TextEditingController _foodWaterType = TextEditingController();
  final TextEditingController _storageContext = TextEditingController();
  final TextEditingController _packagingClarity = TextEditingController();
  final TextEditingController _handlingDensity = TextEditingController();
  final TextEditingController _containerCondition = TextEditingController();
  final TextEditingController _temperatureFlow = TextEditingController();
  final TextEditingController _hazards = TextEditingController();
  final TextEditingController _sensorNotes = TextEditingController();

  final TextEditingController _baseLocation = TextEditingController();
  final TextEditingController _seedItem = TextEditingController();
  final TextEditingController _nearbyLocations = TextEditingController();
  final TextEditingController _maxTargets = TextEditingController(text: '6');

  bool _plannerMode = false;
  bool _singleLoading = false;
  bool _plannerLoading = false;
  NazaScannerResult? _singleResult;
  NazaScannerResult? _plannerResult;

  @override
  void dispose() {
    _location.dispose();
    _foodWaterType.dispose();
    _storageContext.dispose();
    _packagingClarity.dispose();
    _handlingDensity.dispose();
    _containerCondition.dispose();
    _temperatureFlow.dispose();
    _hazards.dispose();
    _sensorNotes.dispose();
    _baseLocation.dispose();
    _seedItem.dispose();
    _nearbyLocations.dispose();
    _maxTargets.dispose();
    super.dispose();
  }

  Map<String, String> _scanData() {
    return {
      'location': _location.text,
      'food_water_type': _foodWaterType.text,
      'storage_context': _storageContext.text,
      'packaging_clarity': _packagingClarity.text,
      'handling_density': _handlingDensity.text,
      'container_condition': _containerCondition.text,
      'temperature_flow': _temperatureFlow.text,
      'hazards': _hazards.text,
      'sensor_notes': _sensorNotes.text,
    };
  }

  Map<String, String> _plannerData() {
    final parsedTargets = int.tryParse(_maxTargets.text.trim()) ?? 6;
    final boundedTargets = math.max(2, math.min(12, parsedTargets));
    return {
      'base_location': _baseLocation.text,
      'seed_item': _seedItem.text,
      'nearby_locations': _nearbyLocations.text,
      'max_targets': boundedTargets.toString(),
    };
  }

  Future<void> _runSingleScan() async {
    if (_singleLoading || !widget.actionsEnabled) return;
    setState(() => _singleLoading = true);
    final result = await widget.onScan(_scanData());
    if (!mounted) return;
    setState(() {
      _singleResult = result;
      _singleLoading = false;
    });
  }

  Future<void> _runPlanner() async {
    if (_plannerLoading || !widget.actionsEnabled) return;
    setState(() => _plannerLoading = true);
    final result = await widget.onPlanner(_plannerData());
    if (!mounted) return;
    setState(() {
      _plannerResult = result;
      _plannerLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Food / Water',
      children: [
        const _ScannerNotice(
          icon: Icons.water_drop_rounded,
          title: 'Food / Water scanning tabs',
          body:
              'Single scan classifies one source. Multi-scan asks the local model to plan several nearby targets.',
        ),
        Row(
          children: [
            Expanded(
              child: _ScannerModeChip(
                label: 'Single Scan',
                selected: !_plannerMode,
                onTap: () => setState(() => _plannerMode = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScannerModeChip(
                label: 'Multi-Scan',
                selected: _plannerMode,
                onTap: () => setState(() => _plannerMode = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _plannerMode
              ? _ScannerAnalysisSurface(
                  key: const ValueKey<String>('food-planner-surface'),
                  title: 'Multi-scan readiness surface',
                  icon: Icons.playlist_add_check_rounded,
                  loading: _plannerLoading,
                  result: _plannerResult,
                  idleBody:
                      'Plan multiple nearby scan targets and score scan-readiness on a separate 0/100 pass.',
                )
              : _ScannerAnalysisSurface(
                  key: const ValueKey<String>('food-single-surface'),
                  title: 'Food / Water chromographic safety surface',
                  icon: Icons.water_drop_rounded,
                  loading: _singleLoading,
                  result: _singleResult,
                  idleBody:
                      'Run a scan to generate source risk plus a separate 0/100 safety score.',
                ),
        ),
        if (_plannerMode) ..._buildPlanner() else ..._buildSingleScan(),
      ],
    );
  }

  List<Widget> _buildSingleScan() {
    return [
      _NazaTextInput(
        label: 'Location',
        hint: 'Whole Foods, home kitchen, campsite, water fountain...',
        controller: _location,
      ),
      _NazaTextInput(
        label: 'Food or water type',
        hint: 'bottled water, tap water, produce, deli item...',
        controller: _foodWaterType,
      ),
      _NazaTextInput(
        label: 'Weather / storage context',
        hint: 'refrigerated, hot car, shelf stable, outdoor cooler...',
        controller: _storageContext,
      ),
      _NazaTextInput(
        label: 'Visibility / packaging clarity',
        hint: 'sealed, cloudy, torn label, unclear origin...',
        controller: _packagingClarity,
      ),
      _NazaTextInput(
        label: 'Traffic / handling density',
        hint: 'many handlers, crowded buffet, low contact...',
        controller: _handlingDensity,
      ),
      _NazaTextInput(
        label: 'Surface / container condition',
        hint: 'dented can, leaking bottle, clean container...',
        controller: _containerCondition,
      ),
      _NazaTextInput(
        label: 'Flow / temperature',
        hint: 'cold, warm, unknown, running water, stagnant...',
        controller: _temperatureFlow,
      ),
      _NazaTextInput(
        label: 'Hazards / recalls / odors',
        hint: 'recall, mold, odor, cloudiness, cross-contamination...',
        controller: _hazards,
        maxLines: 3,
      ),
      _NazaTextInput(
        label: 'Sensor / observation notes',
        hint: 'what you can directly observe...',
        controller: _sensorNotes,
        maxLines: 3,
      ),
      const SizedBox(height: 10),
      _NazaActionButton(
        onPressed: widget.actionsEnabled && !_singleLoading
            ? () => unawaited(_runSingleScan())
            : null,
        icon: Icon(
          _singleLoading ? Icons.hourglass_top_rounded : Icons.science_rounded,
        ),
        label: Text(
          _singleLoading ? 'Scanning Food / Water...' : 'Run Food / Water Scan',
        ),
        minimumSize: const Size(250, 48),
      ),
      const SizedBox(height: 12),
      const _InfoRow(label: 'Defense profile', value: 'conservative'),
      const _InfoRow(label: 'Risk labels', value: 'Low / Medium / High'),
    ];
  }

  List<Widget> _buildPlanner() {
    return [
      _NazaTextInput(
        label: 'Base location',
        hint: 'Whole Foods, home kitchen, campsite, neighborhood...',
        controller: _baseLocation,
      ),
      _NazaTextInput(
        label: 'Known item / source',
        hint: 'water, produce, prepared food, dairy...',
        controller: _seedItem,
      ),
      _NazaTextInput(
        label: 'Nearby locations',
        hint: 'comma separated: pharmacy, gas station, public building...',
        controller: _nearbyLocations,
        maxLines: 3,
      ),
      _NazaTextInput(
        label: 'Max targets',
        hint: '2-12',
        controller: _maxTargets,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 10),
      _NazaActionButton(
        onPressed: widget.actionsEnabled && !_plannerLoading
            ? () => unawaited(_runPlanner())
            : null,
        icon: Icon(
          _plannerLoading
              ? Icons.hourglass_top_rounded
              : Icons.playlist_add_check_rounded,
        ),
        label: Text(
          _plannerLoading ? 'Planning Multi-Scan...' : 'Plan Multi-Scan',
        ),
        minimumSize: const Size(220, 48),
      ),
      const SizedBox(height: 12),
      const _InfoRow(label: 'Planner output', value: 'targets + order'),
      const _InfoRow(label: 'Max targets', value: '2-12 bounded'),
    ];
  }
}

class _ScannerAnalysisSurface extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool loading;
  final NazaScannerResult? result;
  final String idleBody;

  const _ScannerAnalysisSurface({
    super.key,
    required this.title,
    required this.icon,
    required this.loading,
    required this.result,
    required this.idleBody,
  });

  @override
  Widget build(BuildContext context) {
    return _NazaGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      radius: 26,
      active: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: loading
            ? _ScannerLoadingSurface(
                key: const ValueKey<String>('scanner-loading'),
                title: title,
                icon: icon,
              )
            : result == null
            ? _ScannerIdleSurface(
                key: const ValueKey<String>('scanner-idle'),
                title: title,
                icon: icon,
                body: idleBody,
              )
            : _ScannerResultSurface(
                key: ValueKey<String>('scanner-${result!.createdAt}'),
                result: result!,
              ),
      ),
    );
  }
}

class _ScannerIdleSurface extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;

  const _ScannerIdleSurface({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: NazaPalette.mintSoft, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: NazaPalette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                      fontFamily: NazaFonts.display,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: NazaPalette.subtext,
                height: 1.35,
                fontWeight: FontWeight.w700,
                fontFamily: NazaFonts.display,
              ),
            ),
            const SizedBox(height: 12),
            const _ScannerMetricPill(
              label: 'passes',
              value: 'risk + safety',
              icon: Icons.all_inclusive_rounded,
            ),
          ],
        );

        final wheel = const _ChromographicWheel(
          label: 'Ready',
          subtitle: 'chromographic',
          progress: 0.18,
          tone: NazaPalette.mintSoft,
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: wheel),
              const SizedBox(height: 14),
              text,
            ],
          );
        }

        return Row(
          children: [
            wheel,
            const SizedBox(width: 18),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}

class _ScannerLoadingSurface extends StatefulWidget {
  final String title;
  final IconData icon;

  const _ScannerLoadingSurface({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  State<_ScannerLoadingSurface> createState() => _ScannerLoadingSurfaceState();
}

class _ScannerLoadingSurfaceState extends State<_ScannerLoadingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final wheel = _ChromographicWheel(
              label: 'Scanning',
              subtitle: 'two-pass local',
              progress: _controller.value,
              tone: NazaPalette.mintSoft,
              loading: true,
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, color: NazaPalette.mintSoft, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: NazaPalette.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                          fontFamily: NazaFonts.display,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Running classification first, then a separate 0/100 safety score pass.',
                  style: TextStyle(
                    color: NazaPalette.subtext,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
                const SizedBox(height: 14),
                const _NazaSheen(height: 2),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _ScannerMetricPill(
                      label: 'risk',
                      value: 'Low / Medium / High',
                      icon: Icons.stacked_line_chart_rounded,
                    ),
                    _ScannerMetricPill(
                      label: 'safety',
                      value: '0 / 100',
                      icon: Icons.speed_rounded,
                    ),
                  ],
                ),
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: wheel),
                  const SizedBox(height: 14),
                  text,
                ],
              );
            }

            return Row(
              children: [
                wheel,
                const SizedBox(width: 18),
                Expanded(child: text),
              ],
            );
          },
        );
      },
    );
  }
}

class _ScannerResultSurface extends StatelessWidget {
  final NazaScannerResult result;

  const _ScannerResultSurface({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final visuals = Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ChromographicWheel(
                label: result.riskLabel,
                subtitle: 'risk',
                progress: result.riskIntensity,
                tone: result.riskColor,
              ),
              _SafetyScoreGauge(
                score: result.safetyScore,
                band: result.safetyBand,
                color: result.safetyColor,
              ),
            ],
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: result.riskColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.title,
                      style: const TextStyle(
                        color: NazaPalette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ),
                  Text(
                    _clock(result.createdAt),
                    style: const TextStyle(
                      color: NazaPalette.subtext,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RiskBadgeRow(activeRisk: result.riskLabel),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ScannerMetricPill(
                    label: 'confidence',
                    value: result.confidenceLabel,
                    icon: Icons.verified_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'route',
                    value: result.route,
                    icon: Icons.hub_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'checksum',
                    value: result.trace.checksum,
                    icon: Icons.tag_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ScannerResultBlock(
                title: 'Risk classifier',
                text: result.riskText,
                color: result.riskColor,
              ),
              const SizedBox(height: 10),
              _ScannerResultBlock(
                title: 'Separate safety score',
                text: result.safetyText,
                color: result.safetyColor,
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: visuals),
                const SizedBox(height: 16),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 330, child: visuals),
              const SizedBox(width: 20),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  String _clock(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _RiskBadgeRow extends StatelessWidget {
  final String activeRisk;

  const _RiskBadgeRow({required this.activeRisk});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RiskBadge(
          label: 'Low',
          active: activeRisk.toLowerCase() == 'low',
          color: const Color(0xFF57EFAE),
        ),
        const SizedBox(width: 8),
        _RiskBadge(
          label: 'Medium',
          active: activeRisk.toLowerCase() == 'medium',
          color: const Color(0xFFFFD166),
        ),
        const SizedBox(width: 8),
        _RiskBadge(
          label: 'High',
          active: activeRisk.toLowerCase() == 'high',
          color: const Color(0xFFFF7C5C),
        ),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;

  const _RiskBadge({
    required this.label,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(44) : const Color(0x44101E19),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : const Color(0x22FFFFFF)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withAlpha(32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? color : NazaPalette.subtext,
            fontWeight: FontWeight.w900,
            fontFamily: NazaFonts.display,
          ),
        ),
      ),
    );
  }
}

class _ScannerResultBlock extends StatelessWidget {
  final String title;
  final String text;
  final Color color;

  const _ScannerResultBlock({
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0x77101E19),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: NazaFonts.display,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            maxLines: 16,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: NazaPalette.text,
              height: 1.36,
              fontWeight: FontWeight.w600,
              fontFamily: NazaFonts.display,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ScannerMetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x66101E19),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x228DFFC4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: NazaPalette.mintSoft, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: NazaPalette.subtext,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: NazaFonts.display,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NazaPalette.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: NazaFonts.mono,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChromographicWheel extends StatelessWidget {
  final String label;
  final String subtitle;
  final double progress;
  final Color tone;
  final bool loading;

  const _ChromographicWheel({
    required this.label,
    required this.subtitle,
    required this.progress,
    required this.tone,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0).toDouble()),
      duration: loading
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 820),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 148,
          height: 148,
          child: CustomPaint(
            painter: _ChromographicWheelPainter(
              progress: loading ? progress : value,
              tone: tone,
              loading: loading,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tone,
                      fontSize: loading ? 16 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                      fontFamily: NazaFonts.display,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NazaPalette.subtext,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChromographicWheelPainter extends CustomPainter {
  final double progress;
  final Color tone;
  final bool loading;

  const _ChromographicWheelPainter({
    required this.progress,
    required this.tone,
    required this.loading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    const segments = 54;
    for (var i = 0; i < segments; i++) {
      final phase = i / segments;
      paint.color = _spectrum(phase).withAlpha(loading ? 130 : 170);
      canvas.drawArc(
        rect,
        -math.pi / 2 + phase * math.pi * 2,
        (math.pi * 2 / segments) * 0.68,
        false,
        paint,
      );
    }

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = tone.withAlpha(loading ? 20 : 30);
    canvas.drawCircle(center, radius - 2, halo);

    final markerProgress = progress.clamp(0.0, 1.0).toDouble();
    final angle = -math.pi / 2 + markerProgress * math.pi * 2;
    final marker = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );

    if (loading) {
      paint
        ..color = tone.withAlpha(210)
        ..strokeWidth = 10;
      canvas.drawArc(rect, angle - 0.62, 0.82, false, paint);
    }

    final needle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = tone.withAlpha(loading ? 95 : 160);
    canvas.drawLine(center, marker, needle);

    final dot = Paint()..color = tone;
    canvas.drawCircle(marker, loading ? 5.5 : 6.5, dot);
    canvas.drawCircle(center, 35, Paint()..color = const Color(0xAA06110D));
  }

  Color _spectrum(double phase) {
    if (phase < 0.50) {
      return Color.lerp(
        const Color(0xFF57EFAE),
        const Color(0xFFFFD166),
        phase / 0.50,
      )!;
    }
    return Color.lerp(
      const Color(0xFFFFD166),
      const Color(0xFFFF7C5C),
      (phase - 0.50) / 0.50,
    )!;
  }

  @override
  bool shouldRepaint(covariant _ChromographicWheelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tone != tone ||
        oldDelegate.loading != loading;
  }
}

class _SafetyScoreGauge extends StatelessWidget {
  final int score;
  final String band;
  final Color color;

  const _SafetyScoreGauge({
    required this.score,
    required this.band,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score.clamp(0, 100).toDouble() / 100),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final shownScore = (value * 100).round();
        return SizedBox(
          width: 148,
          height: 148,
          child: CustomPaint(
            painter: _SafetyGaugePainter(progress: value, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$shownScore',
                    style: TextStyle(
                      color: color,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      color: NazaPalette.subtext,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$band safety',
                    style: const TextStyle(
                      color: NazaPalette.subtext,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.display,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafetyGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SafetyGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;

    paint.color = const Color(0x1FFFFFFF);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);

    const segments = 64;
    final active = (segments * progress.clamp(0.0, 1.0)).round();
    for (var i = 0; i < active; i++) {
      final phase = i / segments;
      paint.color = Color.lerp(
        const Color(0xFFFF7C5C),
        const Color(0xFF57EFAE),
        phase,
      )!.withAlpha(220);
      canvas.drawArc(
        rect,
        -math.pi / 2 + phase * math.pi * 2,
        (math.pi * 2 / segments) * 0.72,
        false,
        paint,
      );
    }

    canvas.drawCircle(center, 36, Paint()..color = const Color(0xAA06110D));
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = color.withAlpha(24),
    );
  }

  @override
  bool shouldRepaint(covariant _SafetyGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ConvoBarkPanel extends StatefulWidget {
  final bool actionsEnabled;
  final Future<NazaConvoRenderResult> Function(Map<String, String> data)
  onRender;

  const _ConvoBarkPanel({required this.actionsEnabled, required this.onRender});

  @override
  State<_ConvoBarkPanel> createState() => _ConvoBarkPanelState();
}

class _ConvoBarkPanelState extends State<_ConvoBarkPanel> {
  final TextEditingController _prompt = TextEditingController(
    text:
        'Create a calm two-person conversation about a roadside food and water safety scan, with a cinematic intro and practical ending.',
  );
  final TextEditingController _voice = TextEditingController(
    text: 'warm narrator + two natural speakers, close mic, expressive',
  );
  final TextEditingController _style = TextEditingController(
    text: 'cinematic local-first assistant, subtle ambient pacing',
  );

  bool _loading = false;
  NazaConvoRenderResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(NazaBarkConvoEngine.instance.preparePerformancePreset());
    unawaited(_warmExistingBarkPack());
  }

  Future<void> _warmExistingBarkPack() async {
    final status = await NazaSecureBarkPackStore.instance.refresh();
    if (status.installed) {
      await NazaNativeBarkBridge.warm(packDir: status.packPath);
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _voice.dispose();
    _style.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    if (_loading || !widget.actionsEnabled) return;
    setState(() => _loading = true);
    final result = await widget.onRender({
      'prompt': _prompt.text,
      'voice': _voice.text,
      'style': _style.text,
      'performance':
          NazaBarkConvoEngine.instance.performancePreset.value.storageValue,
    });
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Bark / Convo',
      children: [
        const _ScannerNotice(
          icon: Icons.graphic_eq_rounded,
          title: 'Convo voice lab',
          body:
              'Build a BarkPack from GitHub Actions, download it securely at runtime, then create local conversation scripts and WAV previews.',
        ),
        const _BarkPackStatusCard(),
        const _BarkPerformanceCard(),
        _ConvoRenderSurface(loading: _loading, result: _result),
        _NazaTextInput(
          label: 'Convo prompt',
          hint: 'Describe the scene, speakers, sound, and ending...',
          controller: _prompt,
          maxLines: 5,
        ),
        _NazaTextInput(
          label: 'Voice preset',
          hint: 'warm narrator, youthful speaker, radio, whisper...',
          controller: _voice,
          maxLines: 2,
        ),
        _NazaTextInput(
          label: 'Style / pacing',
          hint: 'cinematic, calm, urgent, documentary, ambient...',
          controller: _style,
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        _NazaActionButton(
          onPressed: widget.actionsEnabled && !_loading
              ? () => unawaited(_render())
              : null,
          icon: Icon(
            _loading ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
          ),
          label: Text(_loading ? 'Rendering Convo...' : 'Render Convo WAV'),
          minimumSize: const Size(230, 48),
        ),
        const SizedBox(height: 12),
        const _InfoRow(label: 'Pack format', value: 'naza-barkpack-v1'),
        const _InfoRow(label: 'Runtime safety', value: 'HTTPS + SHA-256'),
        const _InfoRow(label: 'Render output', value: 'local WAV preview'),
      ],
    );
  }
}

class _BarkPerformanceCard extends StatelessWidget {
  const _BarkPerformanceCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaBarkPerformancePreset>(
      valueListenable: NazaBarkConvoEngine.instance.performancePreset,
      builder: (_, preset, _) {
        return _NazaGlassCard(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(15),
          radius: 22,
          active: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: preset.color, size: 22),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Bark performance profile: ${preset.label}',
                      style: const TextStyle(
                        color: NazaPalette.text,
                        fontWeight: FontWeight.w900,
                        fontFamily: NazaFonts.display,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preset.description,
                style: const TextStyle(
                  color: NazaPalette.subtext,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  fontFamily: NazaFonts.display,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in NazaBarkPerformancePreset.values)
                    _BarkPerformanceChip(
                      option: option,
                      selected: option == preset,
                      onTap: () => unawaited(
                        NazaBarkConvoEngine.instance.setPerformancePreset(
                          option,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Native sample rate',
                value: '${preset.sampleRate} Hz',
              ),
              _InfoRow(
                label: 'Max native events',
                value: '${preset.maxNativeEvents}',
              ),
              _InfoRow(
                label: 'Script chunk budget',
                value: '${preset.scriptChunkChars} chars',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarkPerformanceChip extends StatefulWidget {
  final NazaBarkPerformancePreset option;
  final bool selected;
  final VoidCallback onTap;

  const _BarkPerformanceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BarkPerformanceChip> createState() => _BarkPerformanceChipState();
}

class _BarkPerformanceChipState extends State<_BarkPerformanceChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.option.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.selected ? null : widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : (_hovered ? 1.02 : 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 178,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: widget.selected
                  ? accent.withAlpha(34)
                  : const Color(0x66101E19),
              borderRadius: BorderRadius.circular(widget.selected ? 20 : 17),
              border: Border.all(
                color: widget.selected
                    ? accent.withAlpha(160)
                    : const Color(0x22FFFFFF),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  switch (widget.option) {
                    NazaBarkPerformancePreset.eco8gb => Icons.bolt_rounded,
                    NazaBarkPerformancePreset.balanced8gb => Icons.tune_rounded,
                    NazaBarkPerformancePreset.studio =>
                      Icons.graphic_eq_rounded,
                  },
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.option.shortLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.selected
                          ? NazaPalette.text
                          : NazaPalette.subtext,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.display,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarkPackStatusCard extends StatelessWidget {
  const _BarkPackStatusCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaBarkPackStatus>(
      valueListenable: NazaSecureBarkPackStore.instance.status,
      builder: (_, status, _) {
        final color = status.installed
            ? const Color(0xFF57EFAE)
            : status.error == null
            ? const Color(0xFFFFD166)
            : const Color(0xFFFF7C5C);
        return _NazaGlassCard(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(15),
          radius: 24,
          active: status.installed || status.downloading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.installed
                        ? Icons.verified_rounded
                        : status.downloading
                        ? Icons.downloading_rounded
                        : Icons.cloud_download_rounded,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.installed
                          ? 'Verified BarkPack ready'
                          : status.downloading
                          ? 'Installing BarkPack'
                          : 'BarkPack secure downloader',
                      style: const TextStyle(
                        color: NazaPalette.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ),
                  Text(
                    '${status.progress}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontFamily: NazaFonts.mono,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: status.downloading || status.installed
                      ? status.progress.clamp(0, 100).toDouble() / 100
                      : null,
                  color: color,
                  backgroundColor: const Color(0x33101E19),
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Phase', value: status.phase),
              _InfoRow(
                label: 'Tensor count',
                value: status.tensorCount.toString(),
              ),
              _InfoRow(label: 'Quality tier', value: status.qualityTier),
              _InfoRow(label: 'Families', value: status.familySummary),
              _InfoRow(label: 'Stages', value: status.stageSummary),
              _InfoRow(label: 'Capabilities', value: status.capabilitySummary),
              _InfoRow(label: 'Sidecars', value: status.sidecarSummary),
              _InfoRow(
                label: 'Missing families',
                value: status.missingFamilies.isEmpty
                    ? 'none'
                    : status.missingFamilies.join(', '),
              ),
              _InfoRow(
                label: 'Pack path',
                value: status.packPath.isEmpty ? 'pending' : status.packPath,
              ),
              if (status.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  status.error!,
                  style: const TextStyle(
                    color: NazaPalette.danger,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _NazaActionButton(
                    onPressed: status.downloading
                        ? null
                        : () => unawaited(
                            NazaSecureBarkPackStore.instance.ensureInstalled(),
                          ),
                    icon: const Icon(Icons.security_update_good_rounded),
                    label: const Text('Install / Verify Pack'),
                    minimumSize: const Size(190, 42),
                  ),
                  _NazaActionButton(
                    onPressed: () =>
                        unawaited(NazaSecureBarkPackStore.instance.refresh()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    filled: false,
                    minimumSize: const Size(120, 42),
                  ),
                  ValueListenableBuilder<NazaBarkSelfTestStatus>(
                    valueListenable: NazaBarkConvoEngine.instance.selfTest,
                    builder: (_, selfTest, _) {
                      return _NazaActionButton(
                        onPressed:
                            status.installed &&
                                !status.downloading &&
                                !selfTest.running
                            ? () => unawaited(
                                NazaBarkConvoEngine.instance.runSelfTest(),
                              )
                            : null,
                        icon: Icon(
                          selfTest.running
                              ? Icons.graphic_eq_rounded
                              : Icons.hearing_rounded,
                        ),
                        label: Text(
                          selfTest.running ? 'Testing Voice' : 'Run Self-Test',
                        ),
                        filled: false,
                        minimumSize: const Size(145, 42),
                      );
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<NazaBarkSelfTestStatus>(
                valueListenable: NazaBarkConvoEngine.instance.selfTest,
                builder: (_, selfTest, _) {
                  if (!selfTest.running &&
                      !selfTest.hasOutput &&
                      selfTest.error == null) {
                    return const SizedBox.shrink();
                  }
                  final selfColor = selfTest.error != null
                      ? NazaPalette.danger
                      : selfTest.running
                      ? const Color(0xFFFFD166)
                      : const Color(0xFF57EFAE);
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x66101E19),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: selfColor.withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selfTest.error != null
                                    ? Icons.warning_rounded
                                    : selfTest.running
                                    ? Icons.graphic_eq_rounded
                                    : Icons.check_circle_rounded,
                                color: selfColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${selfTest.phase} • ${selfTest.progress}%',
                                  style: TextStyle(
                                    color: selfColor,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: NazaFonts.display,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selfTest.error ??
                                (selfTest.hasOutput
                                    ? 'Rendered ${selfTest.audioPaths.length} deterministic preview WAVs. Latest WAV: ${selfTest.audioPaths.last}${selfTest.tracePaths.isEmpty ? '' : '\nLatest trace: ${selfTest.tracePaths.last}'}'
                                    : selfTest.detail),
                            style: const TextStyle(
                              color: NazaPalette.subtext,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              fontFamily: NazaFonts.display,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConvoRenderSurface extends StatelessWidget {
  final bool loading;
  final NazaConvoRenderResult? result;

  const _ConvoRenderSurface({required this.loading, required this.result});

  @override
  Widget build(BuildContext context) {
    return _NazaGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      radius: 26,
      active: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: loading
            ? const _ConvoLoadingSurface(key: ValueKey<String>('convo-loading'))
            : result == null
            ? const _ConvoIdleSurface(key: ValueKey<String>('convo-idle'))
            : _ConvoResultSurface(
                key: ValueKey<DateTime>(result!.createdAt),
                result: result!,
              ),
      ),
    );
  }
}

class _ConvoIdleSurface extends StatelessWidget {
  const _ConvoIdleSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        const wheel = _ChromographicWheel(
          label: 'Convo',
          subtitle: 'voice lab',
          progress: 0.24,
          tone: NazaPalette.mintSoft,
        );
        const text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secure BarkPack render lane',
              style: TextStyle(
                color: NazaPalette.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
                fontFamily: NazaFonts.display,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The pack installer validates the release index and every tensor shard before the Convo renderer uses the local files.',
              style: TextStyle(
                color: NazaPalette.subtext,
                height: 1.35,
                fontWeight: FontWeight.w700,
                fontFamily: NazaFonts.display,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ScannerMetricPill(
                  label: 'index',
                  value: 'optional pinned SHA',
                  icon: Icons.fingerprint_rounded,
                ),
                _ScannerMetricPill(
                  label: 'assets',
                  value: 'SHA-256 verified',
                  icon: Icons.verified_user_rounded,
                ),
              ],
            ),
          ],
        );

        if (!wide) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: wheel),
              SizedBox(height: 14),
              text,
            ],
          );
        }

        return const Row(
          children: [
            wheel,
            SizedBox(width: 18),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}

class _ConvoLoadingSurface extends StatefulWidget {
  const _ConvoLoadingSurface({super.key});

  @override
  State<_ConvoLoadingSurface> createState() => _ConvoLoadingSurfaceState();
}

class _ConvoLoadingSurfaceState extends State<_ConvoLoadingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final wheel = _ChromographicWheel(
              label: 'Rendering',
              subtitle: 'script + wav',
              progress: _controller.value,
              tone: NazaPalette.mintSoft,
              loading: true,
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Convo synthesis pass',
                  style: TextStyle(
                    color: NazaPalette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                    fontFamily: NazaFonts.display,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Generating a Bark-style script, checking pack status, then writing a local WAV preview.',
                  style: TextStyle(
                    color: NazaPalette.subtext,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
                const SizedBox(height: 14),
                const _NazaSheen(height: 2),
                const SizedBox(height: 12),
                _ConvoWaveform(
                  segments: const [],
                  phase: _controller.value,
                  color: NazaPalette.mintSoft,
                ),
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: wheel),
                  const SizedBox(height: 14),
                  text,
                ],
              );
            }

            return Row(
              children: [
                wheel,
                const SizedBox(width: 18),
                Expanded(child: text),
              ],
            );
          },
        );
      },
    );
  }
}

class _ConvoResultSurface extends StatelessWidget {
  final NazaConvoRenderResult result;

  const _ConvoResultSurface({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success ? result.qualityColor : NazaPalette.danger;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final visuals = Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ChromographicWheel(
                label: result.usedBarkPack ? 'Verified' : 'Preview',
                subtitle: 'barkpack',
                progress: result.usedBarkPack ? 0.86 : 0.42,
                tone: color,
              ),
              _SafetyScoreGauge(
                score: result.qualityScore,
                band: result.qualityBand,
                color: color,
              ),
            ],
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.multitrack_audio_rounded, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.status,
                      style: const TextStyle(
                        color: NazaPalette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ConvoWaveform(
                segments: result.segments,
                phase: 0.0,
                color: color,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ScannerMetricPill(
                    label: 'segments',
                    value: result.segments.length.toString(),
                    icon: Icons.segment_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'route',
                    value: result.route,
                    icon: Icons.hub_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'renderer',
                    value: result.nativeRenderer
                        ? 'native FFI graph'
                        : 'Dart fallback',
                    icon: Icons.memory_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'profile',
                    value: result.performanceProfile,
                    icon: Icons.speed_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'budget',
                    value: '${result.sampleRate} Hz / ${result.maxEvents} ev',
                    icon: Icons.query_stats_rounded,
                  ),
                  _ScannerMetricPill(
                    label: 'audio',
                    value: result.audioPath.isEmpty ? 'none' : result.audioPath,
                    icon: Icons.audiotrack_rounded,
                  ),
                ],
              ),
              if (result.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  result.error!,
                  style: const TextStyle(
                    color: NazaPalette.danger,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _ScannerResultBlock(
                title: 'Render telemetry',
                text: result.renderDetail,
                color: color,
              ),
              const SizedBox(height: 12),
              _ScannerResultBlock(
                title: 'Convo script',
                text: result.script,
                color: color,
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: visuals),
                const SizedBox(height: 16),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 330, child: visuals),
              const SizedBox(width: 20),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _ConvoWaveform extends StatelessWidget {
  final List<NazaConvoSegment> segments;
  final double phase;
  final Color color;

  const _ConvoWaveform({
    required this.segments,
    required this.phase,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: CustomPaint(
        painter: _ConvoWaveformPainter(
          segments: segments,
          phase: phase,
          color: color,
        ),
      ),
    );
  }
}

class _ConvoWaveformPainter extends CustomPainter {
  final List<NazaConvoSegment> segments;
  final double phase;
  final Color color;

  const _ConvoWaveformPainter({
    required this.segments,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0x66101E19));
    canvas.drawRRect(
      bg,
      Paint()
        ..color = color.withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final bars = math.max(28, (size.width / 9).floor());
    final centerY = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, size.width / bars * 0.34);
    for (var i = 0; i < bars; i++) {
      final x = 12 + (size.width - 24) * (i / math.max(1, bars - 1));
      final segment = segments.isEmpty
          ? null
          : segments[(i * segments.length / bars)
                .floor()
                .clamp(0, segments.length - 1)
                .toInt()];
      final energy = segment?.energy ?? 0.48;
      final wave = math.sin((i * 0.57) + phase * math.pi * 2).abs();
      final height =
          8 + (size.height * 0.66) * (0.20 + energy * 0.55 + wave * 0.25);
      paint.color = Color.lerp(
        color.withAlpha(120),
        NazaPalette.mintSoft.withAlpha(230),
        (i / math.max(1, bars - 1)),
      )!;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConvoWaveformPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.segments != segments;
  }
}

class _SettingsPanel extends StatelessWidget {
  final bool actionsEnabled;
  final Future<void> Function() onResetChat;
  final Future<void> Function() onClearHistory;

  const _SettingsPanel({
    required this.actionsEnabled,
    required this.onResetChat,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Settings',
      children: [
        const _SettingsSectionTitle('Generation'),
        const _InfoRow(label: 'Context window', value: '3072 tokens'),
        const _InfoRow(label: 'Output cap', value: '768 tokens'),
        const _InfoRow(label: 'Auto-continuation', value: 'off by default'),
        const _InfoRow(label: 'Stream paint throttle', value: '360 ms'),
        const _InfoRow(label: 'Telemetry throttle', value: '500 ms'),
        const _InfoRow(label: 'Scroll throttle', value: '240 ms'),
        const _InfoRow(label: 'Display font', value: 'Inter'),
        const _InfoRow(label: 'Telemetry font', value: 'JetBrains Mono'),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Model status'),
        const _ModelStatusSection(),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Model download / cache'),
        const _ModelDownloadCard(),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Model backend'),
        const _BackendPreferenceSection(),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Bark / Convo voice pack'),
        const _BarkPackStatusCard(),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Cryptography'),
        const _InfoRow(label: 'Vault cipher', value: 'AES-256-GCM'),
        const _InfoRow(label: 'Key scope', value: 'per-install local key'),
        const _InfoRow(label: 'AAD', value: 'vault-v2 bound'),
        const _InfoRow(label: 'History writes', value: 'serialized async'),
        const _InfoRow(label: 'History limit', value: '250 encrypted rows'),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Scanner defense'),
        const _InfoRow(label: 'Road scanner', value: 'enabled'),
        const _InfoRow(label: 'Food / Water tabs', value: 'enabled'),
        const _InfoRow(label: 'Chromatic RGB gate', value: 'U3-style analytic'),
        const _InfoRow(
          label: 'RGB timing surface',
          value: 'phase/velocity/curvature',
        ),
        const _InfoRow(
          label: 'Ribbon diagnostics',
          value: 'coherence + nonlocal',
        ),
        const _InfoRow(label: 'Metric samples', value: '5 logical samples'),
        const _InfoRow(label: 'Max defense passes', value: '5'),
        const _InfoRow(label: 'Risk labels', value: 'Low / Medium / High'),
        const _InfoRow(label: 'Safety reminder', value: 'verify on-site'),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('Rendering / desktop stability'),
        const _InfoRow(label: 'UI mode', value: 'Stable desktop v2'),
        const _InfoRow(label: 'Menus', value: 'Inline only'),
        const _InfoRow(label: 'Routes / sheets', value: 'Disabled'),
        const _InfoRow(label: 'Blur shaders', value: 'Disabled'),
        const _InfoRow(label: 'Display font', value: 'Inter'),
        const _InfoRow(label: 'Telemetry font', value: 'JetBrains Mono'),
        const _InfoRow(
          label: 'Ambient animation',
          value: 'Disabled on desktop',
        ),
        const _InfoRow(label: 'Backdrop', value: 'static glass/ribbon field'),
        const _InfoRow(label: 'Motion style', value: 'implicit only'),
        const _InfoRow(label: 'Telemetry timer on desktop', value: 'Disabled'),
        const _InfoRow(label: 'Linux renderer', value: 'software default'),
        const _InfoRow(label: 'Model backend control', value: 'Settings card'),
        const SizedBox(height: 14),
        const _SettingsSectionTitle('About / Tools'),
        const _AboutToolsSection(),
        const SizedBox(height: 12),
        _NazaActionButton(
          onPressed: actionsEnabled ? () => unawaited(onResetChat()) : null,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reset Chat Context'),
          minimumSize: const Size(220, 46),
        ),
        const SizedBox(height: 8),
        _NazaActionButton(
          onPressed: actionsEnabled ? () => unawaited(onClearHistory()) : null,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Clear Vault History'),
          filled: false,
          minimumSize: const Size(220, 46),
        ),
      ],
    );
  }
}

class _ModelStatusSection extends StatelessWidget {
  const _ModelStatusSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaRuntimeSnapshot>(
      valueListenable: NazaLocalGemma.instance.snapshot,
      builder: (_, snap, _) {
        return _NazaGlassCard(
          padding: const EdgeInsets.all(13),
          radius: 18,
          active: snap.modelLoaded,
          child: Column(
            children: [
              _InfoRow(
                label: 'Runtime',
                value: snap.runtimeRegistered ? 'Registered' : 'Not loaded yet',
              ),
              _InfoRow(
                label: 'Model installed',
                value: snap.modelInstalled ? 'Yes' : 'No / unknown',
              ),
              _InfoRow(
                label: 'Model loaded',
                value: snap.modelLoaded ? 'Yes' : 'No',
              ),
              _InfoRow(
                label: 'Backend',
                value: snap.usingGpu ? 'GPU' : 'CPU / waiting',
              ),
              ValueListenableBuilder<NazaModelBackendPreference>(
                valueListenable: NazaLocalGemma.instance.backendPreference,
                builder: (_, preference, _) {
                  return _InfoRow(
                    label: 'Backend preference',
                    value: preference.shortLabel,
                  );
                },
              ),
              _InfoRow(label: 'Phase', value: snap.phase),
              const _InfoRow(label: 'Model source', value: 'Pinned HTTPS'),
              const _InfoRow(
                label: 'Model SHA-256',
                value: NazaAppConfig.modelSha256,
              ),
              if (snap.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  snap.error!,
                  style: const TextStyle(
                    color: NazaPalette.danger,
                    height: 1.35,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'The model is cached in app support only after SHA-256 verification. '
                'NAZA_MODEL_PATH is accepted only when the file hash matches exactly.',
                style: TextStyle(
                  color: NazaPalette.subtext,
                  height: 1.35,
                  fontFamily: NazaFonts.display,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackendPreferenceSection extends StatelessWidget {
  const _BackendPreferenceSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaModelBackendPreference>(
      valueListenable: NazaLocalGemma.instance.backendPreference,
      builder: (_, preference, _) {
        return ValueListenableBuilder<NazaRuntimeSnapshot>(
          valueListenable: NazaLocalGemma.instance.snapshot,
          builder: (_, snap, _) {
            final busy = snap.busy;
            return _NazaGlassCard(
              padding: const EdgeInsets.all(13),
              radius: 18,
              active: preference != NazaModelBackendPreference.cpuOnly,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose how the local Gemma LiteRT-LM model runs. Changes '
                    'close the loaded model and take effect on the next send.',
                    style: TextStyle(
                      color: NazaPalette.subtext,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      fontFamily: NazaFonts.display,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in NazaModelBackendPreference.values)
                        _BackendPreferenceChip(
                          option: option,
                          selected: option == preference,
                          enabled: !busy,
                          onTap: () => unawaited(
                            NazaLocalGemma.instance.setBackendPreference(
                              option,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (busy) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Backend switching is locked while the model is loading '
                      'or generating.',
                      style: TextStyle(
                        color: NazaPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _InfoRow(
                    label: 'First-run env defaults',
                    value: 'NAZA_DESKTOP_CPU / GPU',
                  ),
                  const _InfoRow(
                    label: 'Stored preference',
                    value: NazaAppConfig.backendPreferenceFileName,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BackendPreferenceChip extends StatefulWidget {
  final NazaModelBackendPreference option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _BackendPreferenceChip({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_BackendPreferenceChip> createState() => _BackendPreferenceChipState();
}

class _BackendPreferenceChipState extends State<_BackendPreferenceChip> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _accent {
    return switch (widget.option) {
      NazaModelBackendPreference.gpuFirst => NazaPalette.mintSoft,
      NazaModelBackendPreference.gpuOnly => const Color(0xFF7FD7FF),
      NazaModelBackendPreference.cpuOnly => const Color(0xFFFFCE78),
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final enabled = widget.enabled;
    final selected = widget.selected;
    final foreground = enabled
        ? (selected ? NazaPalette.text : NazaPalette.subtext)
        : NazaPalette.muted;

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled
          ? (_) => setState(() {
              _hovered = false;
              _pressed = false;
            })
          : null,
      child: GestureDetector(
        onTap: enabled && !selected ? widget.onTap : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : (_hovered && enabled ? 1.02 : 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 226,
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? accent.withAlpha(34) : const Color(0x66101E19),
              borderRadius: BorderRadius.circular(selected ? 20 : 17),
              border: Border.all(
                color: selected
                    ? accent.withAlpha(160)
                    : const Color(0x22FFFFFF),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(_hovered ? 42 : 26),
                        blurRadius: _hovered ? 24 : 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      switch (widget.option) {
                        NazaModelBackendPreference.gpuFirst =>
                          Icons.auto_awesome_rounded,
                        NazaModelBackendPreference.gpuOnly =>
                          Icons.memory_rounded,
                        NazaModelBackendPreference.cpuOnly =>
                          Icons.developer_board_rounded,
                      },
                      color: enabled ? accent : NazaPalette.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.option.shortLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                          fontFamily: NazaFonts.display,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 17),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  widget.option.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? NazaPalette.subtext : NazaPalette.muted,
                    height: 1.25,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatefulWidget {
  const _HistoryPanel();

  @override
  State<_HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<_HistoryPanel> {
  List<NazaHistoryRow>? _rows;
  Object? _error;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    NazaVault.instance.revision.addListener(_reload);
    unawaited(_load());
  }

  @override
  void dispose() {
    NazaVault.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    unawaited(_load());
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    try {
      final rows = await NazaVault.instance.readHistory();
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _rows = rows.reversed.take(50).toList(growable: false);
        _error = null;
      });
    } catch (error) {
      if (!mounted || serial != _loadSerial) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'History',
      children: [
        if (_error != null)
          Text(
            'History could not be loaded: $_error',
            style: const TextStyle(color: NazaPalette.danger),
          )
        else if (_rows == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Loading history...',
              style: TextStyle(color: NazaPalette.subtext),
            ),
          )
        else if (_rows!.isEmpty)
          const Text(
            'No encrypted history yet.',
            style: TextStyle(color: NazaPalette.subtext),
          )
        else
          ..._rows!.map((row) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x99101E19),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Text(
                row.user,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NazaPalette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AboutToolsSection extends StatelessWidget {
  const _AboutToolsSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NazaGlassCard(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(13),
          radius: 18,
          active: true,
          child: Text(
            'Naza One is a local-first assistant with private AES-GCM history, LiteRT-LM Gemma inference, scanner-specific prompt routing, and lightweight desktop-safe rendering.',
            style: TextStyle(
              color: NazaPalette.text,
              height: 1.35,
              fontWeight: FontWeight.w700,
              fontFamily: NazaFonts.display,
            ),
          ),
        ),
        _ToolTile(
          icon: Icons.hub_rounded,
          title: 'Chromatic Quantum Router',
          body:
              'Local RGB gate, coherence, phase, policy entropy, and nonlocal ribbon scoring before each prompt.',
        ),
        _ToolTile(
          icon: Icons.lock_rounded,
          title: 'AES-GCM Vault',
          body: 'Local encrypted history storage.',
        ),
        _ToolTile(
          icon: Icons.speed_rounded,
          title: 'Stable Desktop v2',
          body:
              'No drawer, no modal route, no blur; static desktop backdrop plus localized component animations.',
        ),
        _ToolTile(
          icon: Icons.route_rounded,
          title: 'Road Scanner',
          body:
              'Full scanner console with risk classification, separate 0/100 safety scoring, chromographic wheel, and conservative verification reminder.',
        ),
        _ToolTile(
          icon: Icons.water_drop_rounded,
          title: 'Food / Water Scanner',
          body:
              'Single-source classification plus multi-scan planning, safety gauge, chromatic diagnostics, and local-only prompts.',
        ),
        _ToolTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Bark / Convo',
          body:
              'GitHub Actions BarkPack conversion, secure release downloads, SHA-256 tensor verification, structured voice scripts, and local WAV previews.',
        ),
      ],
    );
  }
}

class _PanelScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PanelScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 18, 0),
            child: child,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xB304100B),
          border: const Border(left: BorderSide(color: Color(0x22FFFFFF))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(80),
              blurRadius: 22,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title,
              style: const TextStyle(
                color: NazaPalette.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
                fontFamily: NazaFonts.display,
              ),
            ),
            const SizedBox(height: 8),
            const _NazaSheen(height: 1.5),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x16FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: NazaPalette.subtext,
                fontWeight: FontWeight.w700,
                fontFamily: NazaFonts.display,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NazaPalette.mintSoft,
                fontWeight: FontWeight.w900,
                fontFamily: NazaFonts.mono,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String text;

  const _SettingsSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: NazaPalette.text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ScannerNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ScannerNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _NazaGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      radius: 20,
      active: true,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.9, end: 1),
            duration: const Duration(milliseconds: 480),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Icon(icon, color: NazaPalette.mintSoft, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NazaPalette.text,
                    fontWeight: FontWeight.w900,
                    fontFamily: NazaFonts.display,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: NazaPalette.subtext,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScannerModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x223EFF92) : const Color(0x66101E19),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0x778DFFC4) : const Color(0x22FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? NazaPalette.text : NazaPalette.subtext,
            fontWeight: FontWeight.w900,
            fontFamily: NazaFonts.display,
            letterSpacing: selected ? 0.15 : 0,
          ),
        ),
      ),
    );
  }
}

class _NazaTextInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _NazaTextInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: NazaPalette.subtext,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType ?? TextInputType.text,
            maxLines: maxLines,
            cursorColor: NazaPalette.mintSoft,
            style: const TextStyle(
              color: NazaPalette.text,
              fontWeight: FontWeight.w700,
              height: 1.25,
              fontFamily: NazaFonts.display,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                color: NazaPalette.muted,
                fontWeight: FontWeight.w600,
                fontFamily: NazaFonts.display,
              ),
              filled: true,
              fillColor: const Color(0xAA101E19),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0x33FFFFFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: NazaPalette.mintSoft,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _NazaGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x223EFF92),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x338DFFC4)),
            ),
            child: Icon(icon, color: NazaPalette.mintSoft, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NazaPalette.text,
                    fontWeight: FontWeight.w900,
                    fontFamily: NazaFonts.display,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: NazaPalette.subtext,
                    height: 1.3,
                    fontFamily: NazaFonts.display,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NazaActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final bool filled;
  final Size minimumSize;

  const _NazaActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = true,
    this.minimumSize = const Size(120, 48),
  });

  @override
  State<_NazaActionButton> createState() => _NazaActionButtonState();
}

class _NazaActionButtonState extends State<_NazaActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final background = enabled
        ? (widget.filled ? NazaPalette.mintDim : Colors.transparent)
        : const Color(0xFF24342E);
    final foreground = enabled
        ? (widget.filled ? const Color(0xFF021007) : NazaPalette.mintSoft)
        : NazaPalette.muted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered && enabled ? 1.035 : 1.0),
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: widget.minimumSize.width,
              minHeight: widget.minimumSize.height,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(_hovered ? 28 : 24),
              border: Border.all(
                color: widget.filled
                    ? Colors.transparent
                    : (enabled
                          ? const Color(0x668DFFC4)
                          : const Color(0x22FFFFFF)),
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: NazaPalette.mintDim.withAlpha(
                          widget.filled ? (_hovered ? 70 : 38) : 18,
                        ),
                        blurRadius: _hovered ? 24 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 20),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: NazaFonts.display,
                  letterSpacing: 0.1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.icon,
                    const SizedBox(width: 8),
                    widget.label,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconPill({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: selected ? 48 : 44,
        height: selected ? 48 : 44,
        decoration: BoxDecoration(
          color: selected ? const Color(0x223EFF92) : const Color(0x22101E19),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0x668DFFC4) : const Color(0x22FFFFFF),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: NazaPalette.mintDim.withAlpha(30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: selected ? 1.08 : 1,
          duration: const Duration(milliseconds: 180),
          child: Icon(
            icon,
            color: selected ? NazaPalette.mintSoft : NazaPalette.subtext,
            size: 22,
          ),
        ),
      ),
    );
  }
}
