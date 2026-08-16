// LLM-CONTEXT:BEGIN
// FILE: lib/main.dart
// ROLE: Owns main behavior within the application-core subsystem.
// DOMAIN: application-core
// SECURITY-INVARIANT: Preserve local-first privacy, bounded resource use, and explicit error handling.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:developer' as developer;
import 'dart:io';

export 'app.dart';

import 'package:flutter/widgets.dart';

import 'app.dart' as app;
import 'onboarding/boot_coordinator.dart';
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
