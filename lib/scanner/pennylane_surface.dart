// In-house Dart port of the PennyLane scanner surface used by the legacy
// Python application. This deliberately contains no Python or PennyLane FFI.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

final class PennyLaneSurface {
  final double entropicScore;
  final double interferenceScore;
  final double multiNodeScore;
  final String interferenceLevel;
  final String multiNodeLevel;
  final int sampleCount;
  final int nodeCount;
  final String topology;
  final int passes;
  final Map<String, double> vectorScores;
  final String capsule;
  final String systemMetricsText;

  const PennyLaneSurface({
    required this.entropicScore,
    required this.interferenceScore,
    required this.multiNodeScore,
    required this.interferenceLevel,
    required this.multiNodeLevel,
    required this.sampleCount,
    required this.nodeCount,
    required this.topology,
    required this.passes,
    required this.vectorScores,
    required this.capsule,
    required this.systemMetricsText,
  });

  String get entropyText =>
      'entropic_score=${entropicScore.toStringAsFixed(3)} (level=${PennyLaneScanner.level(entropicScore, entropyThreshold: true)})';
  String get integrityText =>
      'local_interference=${interferenceScore.toStringAsFixed(2)} (level=$interferenceLevel, samples=$sampleCount)';
  String get multiNodeText =>
      'multi_node=${multiNodeScore.toStringAsFixed(2)} (level=$multiNodeLevel, nodes=$nodeCount, topology=$topology, passes=$passes)';
  String get capsuleText => 'defense_capsule=$capsule';
}

final class PennyLaneScanner {
  const PennyLaneScanner._();

  static PennyLaneSurface evaluate(
    Map<String, String> input, {
    math.Random? random,
    List<Map<String, double>>? metricReadings,
    int shots = 256,
    int trials = 96,
  }) {
    final rng = random ?? math.Random.secure();
    final readings = metricReadings ?? _hostMetricReadings(1);
    final metrics = resilientMetrics(readings);
    final rgb = metricsToRgb(metrics);
    final entropic = pennylaneEntropicScore(rgb, shots: shots, random: rng);
    final surface = multiNodeInterference(
      input,
      metrics,
      trials: trials,
      random: rng,
    );
    final capsulePayload = jsonEncode({
      'domain': 'naza.scanner.defense-capsule.v1',
      'input': _sortedPublicInput(input),
      'metrics': metrics.map((key, value) => MapEntry(key, _round4(value))),
      'surface': surface,
      'noise': base64Encode(List<int>.generate(24, (_) => rng.nextInt(256))),
    });
    final capsule = sha3Hex(utf8.encode(capsulePayload)).substring(0, 24);
    return PennyLaneSurface(
      entropicScore: entropic,
      interferenceScore: metrics['interference_score'] ?? 0,
      multiNodeScore: surface['score']! as double,
      interferenceLevel: level(metrics['interference_score'] ?? 0),
      multiNodeLevel: surface['level']! as String,
      sampleCount: (metrics['sample_count'] ?? 1).round(),
      nodeCount: surface['node_count']! as int,
      topology: surface['topology']! as String,
      passes: surface['passes']! as int,
      vectorScores: Map<String, double>.from(surface['vector_scores']! as Map),
      capsule: capsule,
      systemMetricsText:
          'sys_metrics: cpu=${(metrics['cpu'] ?? 0).toStringAsFixed(2)},mem=${(metrics['mem'] ?? 0).toStringAsFixed(2)},load=${(metrics['load1'] ?? 0).toStringAsFixed(2)},temp=${(metrics['temp'] ?? 0).toStringAsFixed(2)},proc=${(metrics['proc'] ?? 0).toStringAsFixed(2)}',
    );
  }

  static Map<String, double> resilientMetrics(
    List<Map<String, double>> readings,
  ) {
    final safe = readings.isEmpty ? <Map<String, double>>[const {}] : readings;
    final out = <String, double>{};
    for (final key in const ['cpu', 'mem', 'load1', 'temp', 'proc']) {
      final values = safe.map((r) => r[key] ?? 0).toList();
      out[key] = _median(values);
      out['${key}_spread'] = values.reduce(math.max) - values.reduce(math.min);
    }
    out['proc_count'] = _median(safe.map((r) => r['proc_count'] ?? 0).toList());
    final spread = math.max(
      math.max(out['cpu_spread']!, out['mem_spread']!),
      math.max(out['load1_spread']!, out['temp_spread']!),
    );
    final flatline =
        safe.length > 1 &&
        const ['cpu', 'mem', 'load1'].every((k) => out['${k}_spread']! < .002);
    var pressure = 0.0;
    if (out['cpu']! > .92 || out['mem']! > .92 || out['temp']! > .85)
      pressure += .25;
    if (flatline) pressure += .15;
    out['sample_count'] = safe.length.toDouble();
    out['interference_score'] = _clamp(spread * 2.5 + pressure);
    return out;
  }

  static (double, double, double) metricsToRgb(Map<String, double> metrics) {
    final cpu = metrics['cpu'] ?? .1;
    final mem = metrics['mem'] ?? .1;
    final temp = metrics['temp'] ?? .1;
    final load = metrics['load1'] ?? 0;
    var r = cpu * (1 + load);
    var g = mem * (1 + (metrics['proc'] ?? 0));
    var b = temp * (.5 + cpu * .5);
    final maximum = math.max(1.0, math.max(r, math.max(g, b)));
    r /= maximum;
    g /= maximum;
    b /= maximum;
    return (_clamp(r), _clamp(g), _clamp(b));
  }

  /// State-vector equivalent of the Python PennyLane circuit, including its
  /// finite-shot Pauli-Z measurements.
  static double pennylaneEntropicScore(
    (double, double, double) rgb, {
    int shots = 256,
    math.Random? random,
  }) {
    final rng = random ?? math.Random.secure();
    var state = List<_Complex>.generate(4, (i) => _Complex(i == 0 ? 1 : 0, 0));
    state = _singleQubit(state, 0, _rx(rgb.$1 * math.pi));
    state = _singleQubit(state, 1, _ry(rgb.$2 * math.pi));
    state = [state[0], state[1], state[3], state[2]]; // CNOT 0 -> 1
    state = _singleQubit(state, 1, _rz(rgb.$3 * math.pi));
    state = _singleQubit(state, 0, _rx((rgb.$1 + rgb.$2) * math.pi / 2));
    state = _singleQubit(state, 1, _ry((rgb.$2 + rgb.$3) * math.pi / 2));
    final p0One = state[2].norm2 + state[3].norm2;
    final p1One = state[1].norm2 + state[3].norm2;
    final count0 = _binomial(shots, p0One, rng);
    final count1 = _binomial(shots, p1One, rng);
    final ev0 = 1 - 2 * count0 / shots;
    final ev1 = 1 - 2 * count1 / shots;
    final combined = ((ev0 + 1) / 2) * .6 + ((ev1 + 1) / 2) * .4;
    return _clamp(1 / (1 + math.exp(-6 * (combined - .5))));
  }

  static Map<String, Object> multiNodeInterference(
    Map<String, String> input,
    Map<String, double> metrics, {
    int trials = 96,
    math.Random? random,
  }) {
    final rng = random ?? math.Random.secure();
    final public = _publicInput(input);
    final nodeCount = _parseInt(public['nearby_unknown_device_count'], 0, 12);
    final topology = (public['nearby_device_geometry'] ?? 'none')
        .trim()
        .toLowerCase();
    final topologyPressure = _topologyFactor(topology);
    final activity = _activityFactor(public['handheld_device_activity']);
    final distance = _distancePressure(public['nearest_device_distance']);
    final metric = metrics['interference_score'] ?? 0;
    final node = _clamp(nodeCount / 8);
    final observations = List<double>.generate(
      math.max(16, trials),
      (_) => _clamp(
        node * .25 +
            rng.nextDouble() * topologyPressure * .25 +
            rng.nextDouble() * math.max(activity, node) * .20 +
            rng.nextDouble() * distance * .15 +
            rng.nextDouble() * metric * .15,
      ),
    );
    final score = _clamp(
      _median(observations) * .70 + observations.reduce(math.max) * .30,
    );
    final passes = score >= .70
        ? 5
        : score >= .35
        ? 3
        : 1;
    return {
      'score': score,
      'level': level(score),
      'node_count': nodeCount,
      'topology': topology.isEmpty ? 'none' : topology,
      'passes': passes,
      'vector_scores': <String, double>{
        'timing': _clamp(score * .65 + metric * .35),
        'cache': _clamp(score * .55 + node * .25 + topologyPressure * .20),
        'em_power': _clamp(score * .45 + activity * .35 + distance * .20),
        'acoustic_thermal': _clamp(metric * .65 + activity * .20 + node * .15),
        'sensor_spoofing': _clamp(
          topologyPressure * .35 + node * .25 + metric * .40,
        ),
      },
    };
  }

  static String level(double score, {bool entropyThreshold = false}) {
    if (entropyThreshold)
      return score >= .75
          ? 'high'
          : score >= .45
          ? 'medium'
          : 'low';
    return score >= .70
        ? 'high'
        : score >= .35
        ? 'medium'
        : 'low';
  }

  /// FIPS 202 SHA3-256. This is a digest, not a MAC or password KDF.
  static String sha3Hex(List<int> input) =>
      _hex(SHA3Digest(256).process(Uint8List.fromList(input)));

  static List<Map<String, double>> _hostMetricReadings(int count) =>
      List.generate(count, (_) => _readHostMetrics());

  static Map<String, double> _readHostMetrics() {
    var mem = 0.0;
    var load = 0.0;
    var cpu = 0.0;
    var temp = 0.0;
    var processes = 0;
    try {
      final before = _cpuTicks();
      sleep(const Duration(milliseconds: 100));
      final after = _cpuTicks();
      final totalDelta = after.$1 - before.$1;
      final idleDelta = after.$2 - before.$2;
      if (totalDelta > 0) cpu = _clamp(1 - idleDelta / totalDelta);
      final lines = File('/proc/meminfo').readAsLinesSync();
      double value(String key) => double.parse(
        lines.firstWhere((l) => l.startsWith(key)).split(RegExp(r'\s+'))[1],
      );
      mem = _clamp(1 - value('MemAvailable:') / value('MemTotal:'));
      final cpuCount = Platform.numberOfProcessors.toDouble();
      load = _clamp(
        double.parse(
              File('/proc/loadavg').readAsStringSync().split(' ').first,
            ) /
            cpuCount,
      );
      processes = Directory(
        '/proc',
      ).listSync().where((e) => RegExp(r'/\d+$').hasMatch(e.path)).length;
      final thermal = Directory('/sys/class/thermal');
      if (thermal.existsSync()) {
        final values = thermal
            .listSync()
            .where((e) => e.path.contains('thermal_zone'))
            .map((e) => File('${e.path}/temp'))
            .where((f) => f.existsSync())
            .map((f) => double.tryParse(f.readAsStringSync().trim()))
            .whereType<double>()
            .map((v) => v > 1000 ? v / 1000 : v)
            .toList();
        if (values.isNotEmpty) {
          temp = _clamp(
            (values.reduce((a, b) => a + b) / values.length - 20) / 70,
          );
        }
      }
    } catch (_) {}
    return {
      'cpu': cpu,
      'mem': mem,
      'load1': load,
      'temp': temp,
      'proc': _clamp(processes / 1000),
      'proc_count': processes.toDouble(),
    };
  }

  static (double, double) _cpuTicks() {
    final parts = File('/proc/stat')
        .readAsLinesSync()
        .first
        .trim()
        .split(RegExp(r'\s+'))
        .skip(1)
        .map(double.parse)
        .toList();
    final total = parts.fold<double>(0, (sum, value) => sum + value);
    final idle = parts.length > 4 ? parts[3] + parts[4] : parts[3];
    return (total, idle);
  }

  static Map<String, String> _publicInput(Map<String, String> input) => {
    for (final entry in input.entries)
      if (!entry.key.startsWith('_')) entry.key: _sanitize(entry.value),
  };
  static Map<String, String> _sortedPublicInput(Map<String, String> input) {
    final public = _publicInput(input);
    final keys = public.keys.toList()..sort();
    return {for (final key in keys) key: public[key]!};
  }

  static String _sanitize(String value) => value.replaceAll(
    RegExp(
      r'\b(latino|latina|latinx|hispanic|latin\s+american)\b',
      caseSensitive: false,
    ),
    '[redacted-person-descriptor]',
  );
  static int _parseInt(String? value, int low, int high) =>
      (int.tryParse(RegExp(r'-?\d+').firstMatch(value ?? '')?.group(0) ?? '') ??
              0)
          .clamp(low, high);
  static double _activityFactor(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (const {'high', 'active', 'yes', 'y', 'many'}.contains(s)) return 1;
    if (const {'medium', 'med', 'some'}.contains(s)) return .65;
    if (const {'low', 'few'}.contains(s)) return .35;
    return 0;
  }

  static double _topologyFactor(String s) {
    if (s.contains('surround') || s.contains('circle')) return 1;
    if (s.contains('triangle') || s.contains('triang')) return .85;
    if (s.contains('cluster') || s.contains('group')) return .55;
    if (s.contains('line') || s.contains('single')) return .25;
    return 0;
  }

  static double _distancePressure(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s.isEmpty || const {'unknown', 'none', 'n/a'}.contains(s)) return .35;
    final n =
        double.tryParse(
          RegExp(r'\d+(?:\.\d+)?').firstMatch(s)?.group(0) ?? '',
        ) ??
        3;
    return _clamp((5 - n) / 5);
  }

  static double _median(List<double> values) {
    values.sort();
    final m = values.length ~/ 2;
    return values.length.isOdd ? values[m] : (values[m - 1] + values[m]) / 2;
  }

  static double _clamp(num value) => value.clamp(0.0, 1.0).toDouble();
  static double _round4(double value) => (value * 10000).round() / 10000;
  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  static int _binomial(int n, double p, math.Random rng) {
    var count = 0;
    for (var i = 0; i < n; i++) if (rng.nextDouble() < p) count++;
    return count;
  }

  static List<_Complex> _singleQubit(
    List<_Complex> s,
    int wire,
    List<List<_Complex>> m,
  ) {
    final out = List<_Complex>.filled(4, const _Complex(0, 0));
    final stride = wire == 0 ? 2 : 1;
    for (var base = 0; base < 4; base += stride * 2)
      for (var j = 0; j < stride; j++) {
        final a = base + j, b = a + stride;
        out[a] = m[0][0] * s[a] + m[0][1] * s[b];
        out[b] = m[1][0] * s[a] + m[1][1] * s[b];
      }
    return out;
  }

  static List<List<_Complex>> _rx(double a) {
    final c = math.cos(a / 2), s = math.sin(a / 2);
    return [
      [_Complex(c, 0), _Complex(0, -s)],
      [_Complex(0, -s), _Complex(c, 0)],
    ];
  }

  static List<List<_Complex>> _ry(double a) {
    final c = math.cos(a / 2), s = math.sin(a / 2);
    return [
      [_Complex(c, 0), _Complex(-s, 0)],
      [_Complex(s, 0), _Complex(c, 0)],
    ];
  }

  static List<List<_Complex>> _rz(double a) => [
    [_Complex(math.cos(-a / 2), math.sin(-a / 2)), const _Complex(0, 0)],
    [const _Complex(0, 0), _Complex(math.cos(a / 2), math.sin(a / 2))],
  ];
}

final class _Complex {
  final double r, i;
  const _Complex(this.r, this.i);
  double get norm2 => r * r + i * i;
  _Complex operator +(_Complex o) => _Complex(r + o.r, i + o.i);
  _Complex operator *(_Complex o) =>
      _Complex(r * o.r - i * o.i, r * o.i + i * o.r);
}
