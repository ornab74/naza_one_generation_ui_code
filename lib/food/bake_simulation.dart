import 'dart:math' as math;

import 'models.dart';

/// Combines independent timing, visual, and optional probe-temperature
/// signals. It estimates process completion, never microbiological safety.
final class BakeSimulationEngine {
  const BakeSimulationEngine._();

  static BakeSimulationResult estimate({
    required BakeInput input,
    required BakeVisualAssessment visual,
  }) {
    final profile = _profiles[input.kind] ?? _profiles[BakeItemKind.custom]!;
    final ratio = input.plannedMinutes <= 0
        ? 0.0
        : (input.elapsedMinutes / input.plannedMinutes).clamp(0.0, 1.35);
    final timeSignal = _timeCurve(ratio, profile.timeCurve).clamp(0.0, 100.0);

    final visualSignal = _visualSignal(profile, visual);
    final thermalSignal = _thermalSignal(input);

    final confidenceWeight = switch (visual.confidence) {
      FoodConfidence.high => 1.0,
      FoodConfidence.medium => 0.78,
      FoodConfidence.low => 0.52,
    };
    final visualWeight = 0.48 * confidenceWeight;
    final thermalWeight = thermalSignal == null ? 0.0 : 0.34;
    final timeWeight = math.max(0.18, 1.0 - visualWeight - thermalWeight);
    final totalWeight = visualWeight + thermalWeight + timeWeight;
    final estimated =
        (visualSignal * visualWeight +
            (thermalSignal ?? 0) * thermalWeight +
            timeSignal * timeWeight) /
        totalWeight;

    var uncertainty = switch (visual.confidence) {
      FoodConfidence.high => 8.0,
      FoodConfidence.medium => 13.0,
      FoodConfidence.low => 19.0,
    };
    if (thermalSignal == null) uncertainty += 7;
    if (input.plannedMinutes <= 0) uncertainty += 9;
    if (visual.status != FoodAnalysisStatus.complete) uncertainty += 10;
    if (input.kind == BakeItemKind.custom) uncertainty += 4;
    uncertainty = uncertainty.clamp(7.0, 34.0);

    final bounded = estimated.clamp(0.0, 100.0).toDouble();
    final lower = (bounded - uncertainty).clamp(0.0, 100.0).toDouble();
    final upper = (bounded + uncertainty).clamp(0.0, 100.0).toDouble();
    final phase = switch (bounded) {
      < 28 => BakePhase.early,
      < 58 => BakePhase.setting,
      < 82 => BakePhase.browning,
      < 96 => BakePhase.nearlyDone,
      _ => BakePhase.estimatedComplete,
    };

    return BakeSimulationResult(
      estimatedPercent: _round1(bounded),
      lowerBound: _round1(lower),
      upperBound: _round1(upper),
      timeSignal: _round1(timeSignal),
      visualSignal: _round1(visualSignal),
      thermalSignal: thermalSignal == null ? null : _round1(thermalSignal),
      phase: phase,
      signals: <String>[
        'Timing model: ${timeSignal.toStringAsFixed(0)}%',
        'Visible surface model: ${visualSignal.toStringAsFixed(0)}%',
        if (thermalSignal != null)
          'User-entered probe model: ${thermalSignal.toStringAsFixed(0)}%'
        else
          'No probe-temperature signal was supplied',
        'Estimated interval: ${lower.toStringAsFixed(0)}–${upper.toStringAsFixed(0)}%',
      ],
      safetyMessage:
          'This is a visual/process estimate, not proof that the center is cooked or food-safe. Follow the recipe or manufacturer guidance and verify doneness with an appropriate thermometer or physical test before eating.',
    );
  }

  static double _timeCurve(double ratio, double curve) {
    if (ratio <= 0) return 0;
    final normalized = (1 - math.exp(-curve * ratio)) / (1 - math.exp(-curve));
    return normalized * 100;
  }

  static double _visualSignal(
    _BakeProfile profile,
    BakeVisualAssessment visual,
  ) {
    final browning = _normalizedVisual(
      visual.surfaceBrowning,
      profile.targetBrowning,
    );
    final structure = _normalizedVisual(
      visual.structureSet,
      profile.targetStructure,
    );
    final dryness = _normalizedVisual(
      visual.surfaceDryness,
      profile.targetDryness,
    );
    final edges = _normalizedVisual(
      visual.edgeDevelopment,
      profile.targetEdges,
    );
    return (browning * profile.browningWeight +
            structure * profile.structureWeight +
            dryness * profile.drynessWeight +
            edges * profile.edgeWeight)
        .clamp(0.0, 100.0);
  }

  static double _normalizedVisual(double observed, double target) {
    if (target <= 0) return observed.clamp(0.0, 100.0);
    return (observed / target * 100).clamp(0.0, 100.0);
  }

  static double? _thermalSignal(BakeInput input) {
    final probe = input.probeTemperatureF;
    final target = input.targetTemperatureF;
    if (probe == null || target == null || target <= 0) return null;
    final start = input.startingTemperatureF ?? math.min(70.0, target - 20);
    final span = target - start;
    if (span <= 1) return null;
    return ((probe - start) / span * 100).clamp(0.0, 100.0).toDouble();
  }

  static double _round1(double value) => (value * 10).roundToDouble() / 10;

  static const Map<BakeItemKind, _BakeProfile> _profiles = {
    BakeItemKind.pizza: _BakeProfile(
      timeCurve: 2.3,
      targetBrowning: 72,
      targetStructure: 78,
      targetDryness: 62,
      targetEdges: 75,
      browningWeight: 0.31,
      structureWeight: 0.30,
      drynessWeight: 0.15,
      edgeWeight: 0.24,
    ),
    BakeItemKind.bread: _BakeProfile(
      timeCurve: 1.8,
      targetBrowning: 75,
      targetStructure: 86,
      targetDryness: 65,
      targetEdges: 72,
      browningWeight: 0.24,
      structureWeight: 0.42,
      drynessWeight: 0.20,
      edgeWeight: 0.14,
    ),
    BakeItemKind.cake: _BakeProfile(
      timeCurve: 1.55,
      targetBrowning: 48,
      targetStructure: 90,
      targetDryness: 48,
      targetEdges: 62,
      browningWeight: 0.13,
      structureWeight: 0.54,
      drynessWeight: 0.18,
      edgeWeight: 0.15,
    ),
    BakeItemKind.cookies: _BakeProfile(
      timeCurve: 2.55,
      targetBrowning: 60,
      targetStructure: 66,
      targetDryness: 60,
      targetEdges: 78,
      browningWeight: 0.29,
      structureWeight: 0.20,
      drynessWeight: 0.18,
      edgeWeight: 0.33,
    ),
    BakeItemKind.pastry: _BakeProfile(
      timeCurve: 2.0,
      targetBrowning: 76,
      targetStructure: 74,
      targetDryness: 68,
      targetEdges: 78,
      browningWeight: 0.31,
      structureWeight: 0.27,
      drynessWeight: 0.18,
      edgeWeight: 0.24,
    ),
    BakeItemKind.casserole: _BakeProfile(
      timeCurve: 1.45,
      targetBrowning: 54,
      targetStructure: 82,
      targetDryness: 45,
      targetEdges: 58,
      browningWeight: 0.18,
      structureWeight: 0.49,
      drynessWeight: 0.18,
      edgeWeight: 0.15,
    ),
    BakeItemKind.custom: _BakeProfile(
      timeCurve: 1.7,
      targetBrowning: 65,
      targetStructure: 80,
      targetDryness: 60,
      targetEdges: 68,
      browningWeight: 0.24,
      structureWeight: 0.38,
      drynessWeight: 0.20,
      edgeWeight: 0.18,
    ),
  };
}

final class _BakeProfile {
  final double timeCurve;
  final double targetBrowning;
  final double targetStructure;
  final double targetDryness;
  final double targetEdges;
  final double browningWeight;
  final double structureWeight;
  final double drynessWeight;
  final double edgeWeight;

  const _BakeProfile({
    required this.timeCurve,
    required this.targetBrowning,
    required this.targetStructure,
    required this.targetDryness,
    required this.targetEdges,
    required this.browningWeight,
    required this.structureWeight,
    required this.drynessWeight,
    required this.edgeWeight,
  });
}
