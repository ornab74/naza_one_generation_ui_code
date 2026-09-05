import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('SHA3-256 matches the FIPS 202 empty-message vector', () {
    expect(
      PennyLaneScanner.sha3Hex(utf8.encode('')),
      'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a',
    );
  });

  test('ports the PennyLane two-qubit circuit and sigmoid mapping', () {
    final score = PennyLaneScanner.pennylaneEntropicScore((
      0,
      0,
      0,
    ), random: math.Random(1));
    expect(score, closeTo(1 / (1 + math.exp(-3)), 1e-12));
  });

  test('uses Python resilient-metric median, spread, and pressure rules', () {
    final metrics = PennyLaneScanner.resilientMetrics([
      {'cpu': .10, 'mem': .20, 'load1': .10, 'temp': .30, 'proc': .10},
      {'cpu': .30, 'mem': .40, 'load1': .20, 'temp': .50, 'proc': .20},
      {'cpu': .20, 'mem': .30, 'load1': .15, 'temp': .40, 'proc': .15},
    ]);
    expect(metrics['cpu'], .20);
    expect(metrics['mem_spread'], closeTo(.20, 1e-12));
    expect(metrics['interference_score'], closeTo(.50, 1e-12));
  });

  test('ports multi-node thresholds and exposes the complete surface text', () {
    final result = PennyLaneScanner.evaluate(
      {
        'nearby_unknown_device_count': '8',
        'nearby_device_geometry': 'surrounding circle',
        'handheld_device_activity': 'high',
        'nearest_device_distance': '1 meter',
      },
      random: math.Random(4),
      metricReadings: List.generate(
        5,
        (_) => {'cpu': .2, 'mem': .3, 'load1': .1, 'temp': .2, 'proc': .1},
      ),
    );
    expect(result.multiNodeText, contains('nodes=8'));
    expect(result.multiNodeText, contains('topology=surrounding circle'));
    expect(
      result.vectorScores.keys,
      containsAll(<String>{
        'timing',
        'cache',
        'em_power',
        'acoustic_thermal',
        'sensor_spoofing',
      }),
    );
    expect(result.capsule, hasLength(24));
    expect(result.passes, anyOf(1, 3, 5));
  });
}
