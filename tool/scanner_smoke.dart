import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:naza_one/main.dart';

/// Run through the Linux bundle, which includes the host-compatible CPU ABI:
/// flutter build linux --debug --target tool/scanner_smoke.dart
/// build/linux/x64/debug/bundle/naza_one --enable-software-rendering
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Text('Testing local road and food scanner inference…'),
      ),
    ),
  );
  final runtime = NazaSentinelInferenceRuntime.instance;
  try {
    await runtime.ensureLoaded().timeout(const Duration(seconds: 90));
    const trace = NazaScannerTrace(
      entropy: 'disabled',
      integrity: 'normal',
      multiNode: '0.0',
      defenseCapsule: 'disabled',
      colorwheel: 'disabled',
      chromaticRibbon: '',
      rgbTiming: '',
      nonlocalRibbon: '',
      checksum: '',
      defensePasses: 1,
    );
    for (final domain in ['road-scanner', 'food-water-scanner']) {
      final prompt = domain == 'road-scanner'
          ? NazaScannerPrompts.buildReferenceRoadLlama({
              'location': 'Test road',
              'weather': 'snow and ice',
              'road_surface': 'wet ice',
              'visibility': 'heavy fog',
              'nearby_hazards': 'debris blocking lane',
            }, trace)
          : NazaScannerPrompts.buildReferenceFoodLlama({
              'food_water_type': 'raw chicken',
              'storage_context': 'warm for two days',
              'hazards': 'spoiled smell',
              'container_condition': 'leaking',
            }, trace);
      final result = await NazaSentinelGuard.instance.classifyScanner(
        domain: domain,
        evidence: prompt,
        lState: '',
        defensePasses: 1,
      );
      stdout.writeln(
        'NAZA_SCANNER_SMOKE=${jsonEncode({'domain': domain, 'loaded': runtime.isLoaded, 'sha256': runtime.pinnedSha256, 'risk': result.risk.name, 'rawOutput': result.rawOutput})}',
      );
      if (!result.valid)
        throw StateError('$domain did not produce a classification.');
    }
    await runtime.dispose();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('NAZA_SCANNER_SMOKE_ERROR=$error\n$stack');
    exit(1);
  }
}
