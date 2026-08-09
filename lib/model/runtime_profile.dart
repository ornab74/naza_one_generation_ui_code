import 'dart:io';

/// Runtime/backend telemetry that lets the UI distinguish a real GPU session
/// from an automatic CPU fallback. This is intentionally independent of
/// flutter_gemma APIs so it works with both the modern bridge and the Windows
/// compatibility bridge.
enum NazaInferenceBackend { unknown, cpu, gpu, npu }

enum NazaBackendAttemptState {
  idle,
  initializing,
  active,
  failed,
  fellBack,
}

final class NazaLiteRtRuntimeProfile {
  const NazaLiteRtRuntimeProfile({
    required this.platform,
    required this.dartBridge,
    required this.nativeRuntime,
    required this.windowsGpuNoCache,
    required this.requestedBackend,
    required this.actualBackend,
    required this.attemptState,
    this.adapter,
    this.failureReason,
  });

  final String platform;
  final String dartBridge;
  final String nativeRuntime;
  final bool windowsGpuNoCache;
  final NazaInferenceBackend requestedBackend;
  final NazaInferenceBackend actualBackend;
  final NazaBackendAttemptState attemptState;
  final String? adapter;
  final String? failureReason;

  bool get isWindowsCompatibilityRuntime =>
      platform == 'windows' &&
      dartBridge == '1.0.2' &&
      nativeRuntime == '0.13.1-a' &&
      windowsGpuNoCache;

  bool get gpuConfirmed =>
      actualBackend == NazaInferenceBackend.gpu &&
      attemptState == NazaBackendAttemptState.active;

  bool get cpuFallback =>
      requestedBackend == NazaInferenceBackend.gpu &&
      actualBackend == NazaInferenceBackend.cpu &&
      attemptState == NazaBackendAttemptState.fellBack;

  String get compactLabel {
    if (gpuConfirmed) {
      final adapterName = adapter?.trim();
      return adapterName == null || adapterName.isEmpty
          ? 'GPU active'
          : 'GPU active · $adapterName';
    }
    if (cpuFallback) return 'CPU fallback';
    if (attemptState == NazaBackendAttemptState.initializing) {
      return '${requestedBackend.name.toUpperCase()} initializing';
    }
    if (attemptState == NazaBackendAttemptState.failed) {
      return '${requestedBackend.name.toUpperCase()} failed';
    }
    return actualBackend == NazaInferenceBackend.unknown
        ? 'Backend not initialized'
        : '${actualBackend.name.toUpperCase()} active';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'platform': platform,
        'dartBridge': dartBridge,
        'nativeRuntime': nativeRuntime,
        'windowsGpuNoCache': windowsGpuNoCache,
        'requestedBackend': requestedBackend.name,
        'actualBackend': actualBackend.name,
        'attemptState': attemptState.name,
        'adapter': adapter,
        'failureReason': failureReason,
        'gpuConfirmed': gpuConfirmed,
        'cpuFallback': cpuFallback,
      };
}

/// Mutable session tracker. Model initialization calls [beginAttempt], then
/// [markActive], [markFallback], or [markFailed]. The UI can listen to this
/// without inferring backend state from token speed.
final class NazaRuntimeTelemetry {
  NazaRuntimeTelemetry._();

  static final NazaRuntimeTelemetry instance = NazaRuntimeTelemetry._();

  static const String modernDartBridge = '1.3.1';
  static const String windowsDartBridge = '1.0.2';
  static const String windowsNativeRuntime = '0.13.1-a';

  NazaLiteRtRuntimeProfile _profile = _initialProfile();
  final List<void Function(NazaLiteRtRuntimeProfile)> _listeners =
      <void Function(NazaLiteRtRuntimeProfile)>[];

  NazaLiteRtRuntimeProfile get profile => _profile;

  void addListener(void Function(NazaLiteRtRuntimeProfile) listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(void Function(NazaLiteRtRuntimeProfile) listener) {
    _listeners.remove(listener);
  }

  void beginAttempt(NazaInferenceBackend backend) {
    _set(
      _copy(
        requestedBackend: backend,
        actualBackend: NazaInferenceBackend.unknown,
        attemptState: NazaBackendAttemptState.initializing,
        adapter: null,
        failureReason: null,
      ),
    );
  }

  void markActive(
    NazaInferenceBackend backend, {
    String? adapter,
  }) {
    _set(
      _copy(
        actualBackend: backend,
        attemptState: NazaBackendAttemptState.active,
        adapter: adapter,
        failureReason: null,
      ),
    );
  }

  void markFallback({
    required NazaInferenceBackend actualBackend,
    required Object cause,
    String? adapter,
  }) {
    _set(
      _copy(
        actualBackend: actualBackend,
        attemptState: NazaBackendAttemptState.fellBack,
        adapter: adapter,
        failureReason: _sanitizeFailure(cause),
      ),
    );
  }

  void markFailed(Object cause) {
    _set(
      _copy(
        actualBackend: NazaInferenceBackend.unknown,
        attemptState: NazaBackendAttemptState.failed,
        failureReason: _sanitizeFailure(cause),
      ),
    );
  }

  void reset() => _set(_initialProfile());

  void _set(NazaLiteRtRuntimeProfile value) {
    _profile = value;
    for (final listener
        in List<void Function(NazaLiteRtRuntimeProfile)>.from(_listeners)) {
      listener(value);
    }
  }

  NazaLiteRtRuntimeProfile _copy({
    NazaInferenceBackend? requestedBackend,
    NazaInferenceBackend? actualBackend,
    NazaBackendAttemptState? attemptState,
    String? adapter,
    String? failureReason,
  }) =>
      NazaLiteRtRuntimeProfile(
        platform: _profile.platform,
        dartBridge: _profile.dartBridge,
        nativeRuntime: _profile.nativeRuntime,
        windowsGpuNoCache: _profile.windowsGpuNoCache,
        requestedBackend: requestedBackend ?? _profile.requestedBackend,
        actualBackend: actualBackend ?? _profile.actualBackend,
        attemptState: attemptState ?? _profile.attemptState,
        adapter: adapter,
        failureReason: failureReason,
      );

  static NazaLiteRtRuntimeProfile _initialProfile() {
    final windows = Platform.isWindows;
    return NazaLiteRtRuntimeProfile(
      platform: Platform.operatingSystem,
      dartBridge: windows ? windowsDartBridge : modernDartBridge,
      nativeRuntime: windows ? windowsNativeRuntime : 'modern',
      windowsGpuNoCache: windows,
      requestedBackend: NazaInferenceBackend.unknown,
      actualBackend: NazaInferenceBackend.unknown,
      attemptState: NazaBackendAttemptState.idle,
    );
  }

  static String _sanitizeFailure(Object error) {
    var value = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Avoid surfacing huge native stack traces or paths in the UI telemetry.
    if (value.length > 320) value = '${value.substring(0, 317)}...';
    return value;
  }
}
