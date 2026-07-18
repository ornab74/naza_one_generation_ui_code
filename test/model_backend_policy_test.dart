import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  group('Naza desktop backend policy', () {
    test('skips automatic GPU startup on Linux without a GPU device', () {
      expect(
        nazaResolveBackendPreference(
          requested: NazaModelBackendPreference.gpuFirst,
          isLinux: true,
          hasLinuxGpuDevice: false,
        ),
        NazaModelBackendPreference.cpuOnly,
      );
    });

    test('keeps automatic GPU startup when a Linux GPU is exposed', () {
      expect(
        nazaResolveBackendPreference(
          requested: NazaModelBackendPreference.gpuFirst,
          isLinux: true,
          hasLinuxGpuDevice: true,
        ),
        NazaModelBackendPreference.gpuFirst,
      );
    });

    test('does not reinterpret an explicit GPU-only preference', () {
      expect(
        nazaResolveBackendPreference(
          requested: NazaModelBackendPreference.gpuOnly,
          isLinux: true,
          hasLinuxGpuDevice: false,
        ),
        NazaModelBackendPreference.gpuOnly,
      );
    });

    test('does not apply the Linux device policy to other platforms', () {
      expect(
        nazaResolveBackendPreference(
          requested: NazaModelBackendPreference.gpuFirst,
          isLinux: false,
          hasLinuxGpuDevice: false,
        ),
        NazaModelBackendPreference.gpuFirst,
      );
    });
  });

  group('model failure classification', () {
    test('repairs only missing active-model identity metadata', () {
      expect(
        nazaIsActiveModelIdentityError(
          StateError('No active inference model set. Install one first.'),
        ),
        isTrue,
      );
      expect(
        nazaIsActiveModelIdentityError(
          Exception('Active model is no longer installed'),
        ),
        isTrue,
      );
      expect(
        nazaIsActiveModelIdentityError(Exception('Model file paths not found')),
        isTrue,
      );
    });

    test('does not treat an engine failure as corrupt registration', () {
      const engineFailure =
          'Exception: Failed to create engine. Model may be invalid';
      expect(nazaIsActiveModelIdentityError(Exception(engineFailure)), isFalse);
      expect(
        nazaIsNativeEngineInitializationError(Exception(engineFailure)),
        isTrue,
      );
    });
  });

  group('loaded backend enforcement', () {
    test('rejects a CPU fallback for a GPU-only request', () {
      expect(
        nazaBackendSatisfiesRequirement(
          requireGpu: true,
          activeBackend: PreferredBackend.cpu,
        ),
        isFalse,
      );
    });

    test('accepts GPU for a GPU-only request', () {
      expect(
        nazaBackendSatisfiesRequirement(
          requireGpu: true,
          activeBackend: PreferredBackend.gpu,
        ),
        isTrue,
      );
    });

    test('accepts CPU when fallback is allowed', () {
      expect(
        nazaBackendSatisfiesRequirement(
          requireGpu: false,
          activeBackend: PreferredBackend.cpu,
        ),
        isTrue,
      );
    });
  });
}
