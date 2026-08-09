import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model/runtime_profile.dart';

void main() {
  setUp(() => NazaRuntimeTelemetry.instance.reset());

  test('GPU activation is explicit rather than inferred from speed', () {
    final telemetry = NazaRuntimeTelemetry.instance;
    telemetry.beginAttempt(NazaInferenceBackend.gpu);
    expect(telemetry.profile.gpuConfirmed, isFalse);
    expect(telemetry.profile.attemptState, NazaBackendAttemptState.initializing);

    telemetry.markActive(
      NazaInferenceBackend.gpu,
      adapter: 'NVIDIA GeForce RTX test adapter',
    );
    expect(telemetry.profile.gpuConfirmed, isTrue);
    expect(telemetry.profile.cpuFallback, isFalse);
    expect(telemetry.profile.compactLabel, contains('GPU active'));
  });

  test('GPU to CPU fallback is visible with bounded reason', () {
    final telemetry = NazaRuntimeTelemetry.instance;
    telemetry.beginAttempt(NazaInferenceBackend.gpu);
    telemetry.markFallback(
      actualBackend: NazaInferenceBackend.cpu,
      cause: 'WebGPU initialization failed',
    );

    expect(telemetry.profile.gpuConfirmed, isFalse);
    expect(telemetry.profile.cpuFallback, isTrue);
    expect(telemetry.profile.compactLabel, 'CPU fallback');
    expect(telemetry.profile.failureReason, contains('WebGPU'));
  });

  test('profile can be serialized for a diagnostics card', () {
    final telemetry = NazaRuntimeTelemetry.instance;
    telemetry.beginAttempt(NazaInferenceBackend.cpu);
    telemetry.markActive(NazaInferenceBackend.cpu);

    final json = telemetry.profile.toJson();
    expect(json['actualBackend'], 'cpu');
    expect(json['attemptState'], 'active');
    expect(json['gpuConfirmed'], isFalse);
  });
}
