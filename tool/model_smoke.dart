// LLM-CONTEXT:BEGIN
// FILE: tool/model_smoke.dart
// ROLE: Owns model smoke behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:naza_one/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stopwatch = Stopwatch()..start();

  try {
    await NazaVault.instance.prepare();
    await NazaLocalGemma.instance.bootstrapRuntimeOnly();
    final response = await NazaLocalGemma.instance.send(
      'Reply with exactly these two words and nothing else: MODEL READY',
    );
    final runtime = NazaLocalGemma.instance.snapshot.value;

    stdout.writeln(
      'NAZA_MODEL_SMOKE_RESULT=${jsonEncode({'text': response.text, 'route': response.route, 'cancelled': response.cancelled, 'modelLoaded': runtime.modelLoaded, 'usingGpu': runtime.usingGpu, 'phase': runtime.phase, 'elapsedMilliseconds': stopwatch.elapsedMilliseconds})}',
    );

    final failed =
        !runtime.modelLoaded ||
        response.cancelled ||
        response.route == 'model-unavailable' ||
        response.text.startsWith('Local Gemma error:');
    await NazaLocalGemma.instance.close();
    exitCode = failed ? 1 : 0;
  } catch (error, stackTrace) {
    stderr.writeln('NAZA_MODEL_SMOKE_ERROR=$error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
