import 'dart:developer' as developer;
import 'dart:io';

export 'app.dart';

import 'package:flutter/widgets.dart';

import 'app.dart' as app;
import 'onboarding/boot_coordinator.dart';
import 'performance/naza_runtime_shell.dart';
import 'performance/naza_shader_warm_up.dart';
import 'security/secure_database.dart';

bool _environmentFlag(String name) {
  final value = Platform.environment[name]?.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes';
}

Future<void> main() async {
  // Impeller compiles its own pipelines. This Skia-specific warm-up runs on
  // the raster thread before the first frame, so enable it only with the same
  // explicit compatibility flag understood by the native Linux runner.
  if (_environmentFlag('NAZA_FLUTTER_SKIA')) {
    PaintingBinding.shaderWarmUp ??= const NazaShaderWarmUp();
  }
  WidgetsFlutterBinding.ensureInitialized();
  final clock = Stopwatch()..start();
  void log(String message) {
    developer.log(
      '[+${clock.elapsedMilliseconds}ms] $message',
      name: 'NazaBoot',
    );
  }

  log('START main vault inspection');
  try {
    // Normal completed installs take the lightweight runtime path. It keeps
    // the same vault/theme/model state but frame-paces cumulative LLM partials
    // before they reach Flutter text layout, eliminating the dominant build
    // jank shown by DevTools while preserving the complete final response.
    if (await NazaPerformanceRuntime.tryLaunch()) {
      log('launched frame-paced performance runtime');
      return;
    }

    final inspection = await app.NazaVault.instance.inspect();
    log(
      'DONE main vault inspection: access=${inspection.access.name}, '
      'legacyDataPresent=${inspection.legacyDataPresent}',
    );
    if (inspection.access == NazaVaultAccess.setupRequired &&
        inspection.legacyDataPresent) {
      log('legacy vault detected; entering migration vault gate');
      await app.main();
      return;
    }
    log('entering new vault-first boot coordinator');
    await NazaBootCoordinator.launch();
  } catch (error, stackTrace) {
    developer.log(
      '[+${clock.elapsedMilliseconds}ms] FAIL main startup: $error',
      name: 'NazaBoot',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
