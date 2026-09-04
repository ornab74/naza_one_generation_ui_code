// LLM-CONTEXT:BEGIN
// FILE: lib/memory/chromatic_route_planner.dart
// ROLE: Produces bounded, deterministic multi-entity routes from probabilistic CSD location results.
// DOMAIN: chromatic-spatial-memory
// SECURITY-INVARIANT: Validate and bound every route input before running quadratic planning work.
// CHANGE-GUARD: Preserve one-stop-per-resolved-entity coverage, stable tie-breaking, and bounded 2-opt behavior.
// DOCS: See /docs/llm-context-schema.md and /docs/chromatic-spatial-memory.md.
// LLM-CONTEXT:END
import 'dart:collection';
import 'dart:math' as math;

import 'chromatic_spatial_index.dart';
import 'chromatic_spatial_models.dart';

/// Hard resource limits for deterministic route planning.
abstract final class CsdRouteLimits {
  static const int maxTargets = 256;
  static const int maxHypothesesPerTarget = 32;
  static const int maxTwoOptTargets = 32;
  static const int maxTwoOptPasses = 128;
  static const double maxCostWeight = 1000000;
}

/// Weights applied to route distance and location risk.
///
/// [freshness] scales `1 - hypothesis.freshness`; it can therefore be read as
/// the maximum distance-equivalent cost of a completely stale hypothesis.
final class CsdRouteCostWeights {
  const CsdRouteCostWeights._({
    required this.distance,
    required this.uncertainty,
    required this.freshness,
  });

  factory CsdRouteCostWeights({
    double distance = 1,
    double uncertainty = 1,
    double freshness = 1,
  }) {
    return CsdRouteCostWeights._(
      distance: _checkedWeight(
        distance,
        'distance',
        mustBePositive: true,
      ),
      uncertainty: _checkedWeight(uncertainty, 'uncertainty'),
      freshness: _checkedWeight(freshness, 'freshness'),
    );
  }

  static const CsdRouteCostWeights standard = CsdRouteCostWeights._(
    distance: 1,
    uncertainty: 1,
    freshness: 1,
  );

  final double distance;
  final double uncertainty;
  final double freshness;

  double cost({
    required double distanceMeters,
    required double uncertaintyRadiusMeters,
    required double hypothesisFreshness,
  }) {
    return distance * distanceMeters +
        uncertainty * uncertaintyRadiusMeters +
        freshness * (1 - hypothesisFreshness);
  }

  Map<String, double> toJson() => <String, double>{
    'distance': distance,
    'uncertainty': uncertainty,
    'freshness': freshness,
  };

  @override
  bool operator ==(Object other) =>
      other is CsdRouteCostWeights &&
      distance == other.distance &&
      uncertainty == other.uncertainty &&
      freshness == other.freshness;

  @override
  int get hashCode => Object.hash(distance, uncertainty, freshness);
}

/// Immutable input to [CsdRoutePlanner.plan].
///
/// Results with no hypotheses remain in the request and are reported as
/// unresolved by the resulting plan. Every non-empty result contributes
/// exactly one stop.
final class CsdRouteRequest {
  CsdRouteRequest._({
    required this.startPose,
    required this.entityLocations,
    required this.costWeights,
    required this.enableTwoOpt,
    required this.maxTwoOptPasses,
  });

  factory CsdRouteRequest({
    required CsdPose startPose,
    required Map<String, CsdEntityLocationResult> entityLocations,
    CsdRouteCostWeights costWeights = CsdRouteCostWeights.standard,
    bool enableTwoOpt = true,
    int maxTwoOptPasses = 64,
  }) {
    if (entityLocations.length > CsdRouteLimits.maxTargets) {
      throw RangeError.range(
        entityLocations.length,
        0,
        CsdRouteLimits.maxTargets,
        'entityLocations.length',
      );
    }
    if (maxTwoOptPasses < 1 ||
        maxTwoOptPasses > CsdRouteLimits.maxTwoOptPasses) {
      throw RangeError.range(
        maxTwoOptPasses,
        1,
        CsdRouteLimits.maxTwoOptPasses,
        'maxTwoOptPasses',
      );
    }

    final sorted = SplayTreeMap<String, CsdEntityLocationResult>();
    for (final entry in entityLocations.entries) {
      final entityId = _checkedEntityId(entry.key, 'entityLocations key');
      if (entityId != entry.key) {
        throw ArgumentError.value(
          entry.key,
          'entityLocations key',
          'Entity IDs must already be trimmed.',
        );
      }
      final result = entry.value;
      if (result.entityId != entityId) {
        throw ArgumentError.value(
          result.entityId,
          'entityLocations[$entityId].entityId',
          'The map key and result entity ID must match.',
        );
      }
      _validateResult(result);
      sorted[entityId] = CsdEntityLocationResult(
        entityId: result.entityId,
        hypotheses: List<CsdLocationHypothesis>.unmodifiable(
          result.hypotheses,
        ),
        entropyBits: result.entropyBits,
        observationsConsidered: result.observationsConsidered,
      );
    }

    return CsdRouteRequest._(
      startPose: startPose,
      entityLocations: Map<String, CsdEntityLocationResult>.unmodifiable(
        sorted,
      ),
      costWeights: costWeights,
      enableTwoOpt: enableTwoOpt,
      maxTwoOptPasses: maxTwoOptPasses,
    );
  }

  /// Convenience factory for passing [CsdLocateResponse.results] directly.
  factory CsdRouteRequest.fromResults({
    required CsdPose startPose,
    required Iterable<CsdEntityLocationResult> results,
    CsdRouteCostWeights costWeights = CsdRouteCostWeights.standard,
    bool enableTwoOpt = true,
    int maxTwoOptPasses = 64,
  }) {
    final byEntity = <String, CsdEntityLocationResult>{};
    var count = 0;
    for (final result in results) {
      count++;
      if (count > CsdRouteLimits.maxTargets) {
        throw RangeError.range(
          count,
          0,
          CsdRouteLimits.maxTargets,
          'results.length',
        );
      }
      if (byEntity.containsKey(result.entityId)) {
        throw ArgumentError.value(
          result.entityId,
          'results',
          'Each entity may appear at most once in a route request.',
        );
      }
      byEntity[result.entityId] = result;
    }
    return CsdRouteRequest(
      startPose: startPose,
      entityLocations: byEntity,
      costWeights: costWeights,
      enableTwoOpt: enableTwoOpt,
      maxTwoOptPasses: maxTwoOptPasses,
    );
  }

  final CsdPose startPose;
  final Map<String, CsdEntityLocationResult> entityLocations;
  final CsdRouteCostWeights costWeights;
  final bool enableTwoOpt;
  final int maxTwoOptPasses;
}

enum CsdRouteOptimizationStatus {
  disabled,
  notNeeded,
  targetLimitExceeded,
  locallyOptimal,
  passLimitReached,
}

/// One selected entity hypothesis in final visit order.
final class CsdRouteStop {
  const CsdRouteStop._({
    required this.visitOrder,
    required this.entityId,
    required this.hypothesis,
    required this.legDistanceMeters,
    required this.cumulativeDistanceMeters,
    required this.distanceCost,
    required this.uncertaintyCost,
    required this.freshnessCost,
    required this.incrementalCost,
    required this.cumulativeCost,
  });

  /// One-based visit order, suitable for direct presentation in a UI.
  final int visitOrder;
  final String entityId;
  final CsdLocationHypothesis hypothesis;
  final double legDistanceMeters;
  final double cumulativeDistanceMeters;
  final double distanceCost;
  final double uncertaintyCost;
  final double freshnessCost;
  final double incrementalCost;
  final double cumulativeCost;

  CsdVector3 get position => hypothesis.position;
  CsdRegionPath get region => hypothesis.region;
  double get selectionRiskCost => uncertaintyCost + freshnessCost;

  Map<String, Object?> toJson() => <String, Object?>{
    'visitOrder': visitOrder,
    'entityId': entityId,
    'hypothesis': hypothesis.toJson(),
    'legDistanceMeters': legDistanceMeters,
    'cumulativeDistanceMeters': cumulativeDistanceMeters,
    'distanceCost': distanceCost,
    'uncertaintyCost': uncertaintyCost,
    'freshnessCost': freshnessCost,
    'incrementalCost': incrementalCost,
    'cumulativeCost': cumulativeCost,
  };
}

/// Deterministic route output with enough diagnostics for UI and telemetry.
final class CsdRoutePlan {
  const CsdRoutePlan._({
    required this.startPose,
    required this.costWeights,
    required this.requestedTargetCount,
    required this.stops,
    required this.unresolvedEntityIds,
    required this.greedyDistanceMeters,
    required this.greedyCost,
    required this.totalDistanceMeters,
    required this.totalUncertaintyRadiusMeters,
    required this.totalFreshnessPenalty,
    required this.totalCost,
    required this.optimizationStatus,
    required this.twoOptSearchPasses,
    required this.twoOptImprovements,
  });

  final CsdPose startPose;
  final CsdRouteCostWeights costWeights;
  final int requestedTargetCount;
  final List<CsdRouteStop> stops;
  final List<String> unresolvedEntityIds;
  final double greedyDistanceMeters;
  final double greedyCost;
  final double totalDistanceMeters;
  final double totalUncertaintyRadiusMeters;
  final double totalFreshnessPenalty;
  final double totalCost;
  final CsdRouteOptimizationStatus optimizationStatus;
  final int twoOptSearchPasses;
  final int twoOptImprovements;

  int get resolvedTargetCount => stops.length;
  bool get isComplete => unresolvedEntityIds.isEmpty;
  bool get wasImproved => twoOptImprovements > 0;
  double get distanceSavedMeters =>
      math.max(0, greedyDistanceMeters - totalDistanceMeters);

  List<String> get orderedEntityIds =>
      List<String>.unmodifiable(stops.map((stop) => stop.entityId));

  Map<String, Object?> toJson() => <String, Object?>{
    'startPose': startPose.toJson(),
    'costWeights': costWeights.toJson(),
    'requestedTargetCount': requestedTargetCount,
    'resolvedTargetCount': resolvedTargetCount,
    'unresolvedEntityIds': unresolvedEntityIds,
    'greedyDistanceMeters': greedyDistanceMeters,
    'greedyCost': greedyCost,
    'totalDistanceMeters': totalDistanceMeters,
    'totalUncertaintyRadiusMeters': totalUncertaintyRadiusMeters,
    'totalFreshnessPenalty': totalFreshnessPenalty,
    'totalCost': totalCost,
    'optimizationStatus': optimizationStatus.name,
    'twoOptSearchPasses': twoOptSearchPasses,
    'twoOptImprovements': twoOptImprovements,
    'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
  };
}

/// Plans a bounded open route: the start pose is fixed and no return leg is
/// implied after the final target.
final class CsdRoutePlanner {
  const CsdRoutePlanner();

  CsdRoutePlan plan(CsdRouteRequest request) {
    final unresolved = <String>[];
    final remaining = <_RouteTarget>[];
    for (final entry in request.entityLocations.entries) {
      if (entry.value.hypotheses.isEmpty) {
        unresolved.add(entry.key);
      } else {
        remaining.add(_RouteTarget(entry.key, entry.value.hypotheses));
      }
    }

    final greedy = _greedyRoute(
      start: request.startPose.position,
      targets: remaining,
      weights: request.costWeights,
    );
    final greedyTotals = _measureRoute(
      start: request.startPose.position,
      route: greedy,
      weights: request.costWeights,
    );
    final optimized = _optimizeRoute(
      start: request.startPose.position,
      greedy: greedy,
      enabled: request.enableTwoOpt,
      maxPasses: request.maxTwoOptPasses,
    );

    _verifyCoverage(request, optimized.route, unresolved);
    final stops = _materializeStops(
      start: request.startPose.position,
      route: optimized.route,
      weights: request.costWeights,
    );
    final totals = _measureRoute(
      start: request.startPose.position,
      route: optimized.route,
      weights: request.costWeights,
    );

    return CsdRoutePlan._(
      startPose: request.startPose,
      costWeights: request.costWeights,
      requestedTargetCount: request.entityLocations.length,
      stops: List<CsdRouteStop>.unmodifiable(stops),
      unresolvedEntityIds: List<String>.unmodifiable(unresolved),
      greedyDistanceMeters: greedyTotals.distanceMeters,
      greedyCost: greedyTotals.totalCost,
      totalDistanceMeters: totals.distanceMeters,
      totalUncertaintyRadiusMeters: totals.uncertaintyRadiusMeters,
      totalFreshnessPenalty: totals.freshnessPenalty,
      totalCost: totals.totalCost,
      optimizationStatus: optimized.status,
      twoOptSearchPasses: optimized.searchPasses,
      twoOptImprovements: optimized.improvements,
    );
  }
}

final class _RouteTarget {
  const _RouteTarget(this.entityId, this.hypotheses);

  final String entityId;
  final List<CsdLocationHypothesis> hypotheses;
}

final class _SelectedTarget {
  const _SelectedTarget({
    required this.entityId,
    required this.hypothesis,
    required this.hypothesisIndex,
  });

  final String entityId;
  final CsdLocationHypothesis hypothesis;
  final int hypothesisIndex;
}

final class _Candidate {
  const _Candidate({
    required this.targetIndex,
    required this.hypothesisIndex,
    required this.entityId,
    required this.hypothesis,
    required this.legDistanceMeters,
    required this.selectionCost,
  });

  final int targetIndex;
  final int hypothesisIndex;
  final String entityId;
  final CsdLocationHypothesis hypothesis;
  final double legDistanceMeters;
  final double selectionCost;
}

List<_SelectedTarget> _greedyRoute({
  required CsdVector3 start,
  required List<_RouteTarget> targets,
  required CsdRouteCostWeights weights,
}) {
  final remaining = List<_RouteTarget>.of(targets);
  final route = <_SelectedTarget>[];
  var current = start;

  while (remaining.isNotEmpty) {
    _Candidate? best;
    for (var targetIndex = 0; targetIndex < remaining.length; targetIndex++) {
      final target = remaining[targetIndex];
      for (
        var hypothesisIndex = 0;
        hypothesisIndex < target.hypotheses.length;
        hypothesisIndex++
      ) {
        final hypothesis = target.hypotheses[hypothesisIndex];
        final distance = current.distanceTo(hypothesis.position);
        final candidate = _Candidate(
          targetIndex: targetIndex,
          hypothesisIndex: hypothesisIndex,
          entityId: target.entityId,
          hypothesis: hypothesis,
          legDistanceMeters: distance,
          selectionCost: weights.cost(
            distanceMeters: distance,
            uncertaintyRadiusMeters: hypothesis.uncertaintyRadiusMeters,
            hypothesisFreshness: hypothesis.freshness,
          ),
        );
        if (best == null || _compareCandidates(candidate, best) < 0) {
          best = candidate;
        }
      }
    }

    final selected = best!;
    route.add(
      _SelectedTarget(
        entityId: selected.entityId,
        hypothesis: selected.hypothesis,
        hypothesisIndex: selected.hypothesisIndex,
      ),
    );
    current = selected.hypothesis.position;
    remaining.removeAt(selected.targetIndex);
  }
  return route;
}

int _compareCandidates(_Candidate a, _Candidate b) {
  var compared = a.selectionCost.compareTo(b.selectionCost);
  if (compared != 0) return compared;
  compared = a.legDistanceMeters.compareTo(b.legDistanceMeters);
  if (compared != 0) return compared;
  compared = a.hypothesis.uncertaintyRadiusMeters.compareTo(
    b.hypothesis.uncertaintyRadiusMeters,
  );
  if (compared != 0) return compared;
  compared = b.hypothesis.freshness.compareTo(a.hypothesis.freshness);
  if (compared != 0) return compared;
  compared = b.hypothesis.posteriorProbability.compareTo(
    a.hypothesis.posteriorProbability,
  );
  if (compared != 0) return compared;
  compared = b.hypothesis.confidence.compareTo(a.hypothesis.confidence);
  if (compared != 0) return compared;
  compared = b.hypothesis.score.compareTo(a.hypothesis.score);
  if (compared != 0) return compared;
  compared = b.hypothesis.lastObservedAt.compareTo(
    a.hypothesis.lastObservedAt,
  );
  if (compared != 0) return compared;
  compared = a.entityId.compareTo(b.entityId);
  if (compared != 0) return compared;
  compared = a.hypothesis.region.canonicalKey.compareTo(
    b.hypothesis.region.canonicalKey,
  );
  if (compared != 0) return compared;
  compared = a.hypothesis.position.x.compareTo(b.hypothesis.position.x);
  if (compared != 0) return compared;
  compared = a.hypothesis.position.y.compareTo(b.hypothesis.position.y);
  if (compared != 0) return compared;
  compared = a.hypothesis.position.z.compareTo(b.hypothesis.position.z);
  if (compared != 0) return compared;
  return a.hypothesisIndex.compareTo(b.hypothesisIndex);
}

final class _OptimizationResult {
  const _OptimizationResult({
    required this.route,
    required this.status,
    required this.searchPasses,
    required this.improvements,
  });

  final List<_SelectedTarget> route;
  final CsdRouteOptimizationStatus status;
  final int searchPasses;
  final int improvements;
}

_OptimizationResult _optimizeRoute({
  required CsdVector3 start,
  required List<_SelectedTarget> greedy,
  required bool enabled,
  required int maxPasses,
}) {
  final route = List<_SelectedTarget>.of(greedy);
  if (!enabled) {
    return _OptimizationResult(
      route: route,
      status: CsdRouteOptimizationStatus.disabled,
      searchPasses: 0,
      improvements: 0,
    );
  }
  if (route.length < 2) {
    return _OptimizationResult(
      route: route,
      status: CsdRouteOptimizationStatus.notNeeded,
      searchPasses: 0,
      improvements: 0,
    );
  }
  if (route.length > CsdRouteLimits.maxTwoOptTargets) {
    return _OptimizationResult(
      route: route,
      status: CsdRouteOptimizationStatus.targetLimitExceeded,
      searchPasses: 0,
      improvements: 0,
    );
  }

  var searchPasses = 0;
  var improvements = 0;
  var converged = false;
  for (var pass = 0; pass < maxPasses; pass++) {
    searchPasses++;
    var bestStart = -1;
    var bestEnd = -1;
    var bestDelta = 0.0;

    for (var segmentStart = 0; segmentStart < route.length - 1; segmentStart++) {
      final before = segmentStart == 0
          ? start
          : route[segmentStart - 1].hypothesis.position;
      for (
        var segmentEnd = segmentStart + 1;
        segmentEnd < route.length;
        segmentEnd++
      ) {
        final first = route[segmentStart].hypothesis.position;
        final last = route[segmentEnd].hypothesis.position;
        final after = segmentEnd + 1 < route.length
            ? route[segmentEnd + 1].hypothesis.position
            : null;
        final oldEdges = before.distanceTo(first) +
            (after == null ? 0 : last.distanceTo(after));
        final newEdges = before.distanceTo(last) +
            (after == null ? 0 : first.distanceTo(after));
        if (!_meaningfullyLess(newEdges, oldEdges)) continue;

        final delta = newEdges - oldEdges;
        if (bestStart == -1 || _meaningfullyLess(delta, bestDelta)) {
          bestStart = segmentStart;
          bestEnd = segmentEnd;
          bestDelta = delta;
        }
      }
    }

    if (bestStart == -1) {
      converged = true;
      break;
    }
    _reverseRange(route, bestStart, bestEnd);
    improvements++;
  }

  return _OptimizationResult(
    route: route,
    status: converged
        ? CsdRouteOptimizationStatus.locallyOptimal
        : CsdRouteOptimizationStatus.passLimitReached,
    searchPasses: searchPasses,
    improvements: improvements,
  );
}

void _reverseRange(List<_SelectedTarget> route, int start, int end) {
  while (start < end) {
    final temporary = route[start];
    route[start] = route[end];
    route[end] = temporary;
    start++;
    end--;
  }
}

bool _meaningfullyLess(double candidate, double baseline) {
  final scale = math.max(1.0, math.max(candidate.abs(), baseline.abs()));
  return candidate < baseline - scale * 1e-12;
}

final class _RouteTotals {
  const _RouteTotals({
    required this.distanceMeters,
    required this.uncertaintyRadiusMeters,
    required this.freshnessPenalty,
    required this.totalCost,
  });

  final double distanceMeters;
  final double uncertaintyRadiusMeters;
  final double freshnessPenalty;
  final double totalCost;
}

_RouteTotals _measureRoute({
  required CsdVector3 start,
  required List<_SelectedTarget> route,
  required CsdRouteCostWeights weights,
}) {
  var previous = start;
  var distance = 0.0;
  var uncertainty = 0.0;
  var freshnessPenalty = 0.0;
  for (final target in route) {
    final hypothesis = target.hypothesis;
    distance += previous.distanceTo(hypothesis.position);
    uncertainty += hypothesis.uncertaintyRadiusMeters;
    freshnessPenalty += 1 - hypothesis.freshness;
    previous = hypothesis.position;
  }
  return _RouteTotals(
    distanceMeters: distance,
    uncertaintyRadiusMeters: uncertainty,
    freshnessPenalty: freshnessPenalty,
    totalCost: weights.distance * distance +
        weights.uncertainty * uncertainty +
        weights.freshness * freshnessPenalty,
  );
}

List<CsdRouteStop> _materializeStops({
  required CsdVector3 start,
  required List<_SelectedTarget> route,
  required CsdRouteCostWeights weights,
}) {
  final stops = <CsdRouteStop>[];
  var previous = start;
  var cumulativeDistance = 0.0;
  var cumulativeCost = 0.0;
  for (var index = 0; index < route.length; index++) {
    final target = route[index];
    final hypothesis = target.hypothesis;
    final legDistance = previous.distanceTo(hypothesis.position);
    final distanceCost = weights.distance * legDistance;
    final uncertaintyCost =
        weights.uncertainty * hypothesis.uncertaintyRadiusMeters;
    final freshnessCost = weights.freshness * (1 - hypothesis.freshness);
    final incrementalCost = distanceCost + uncertaintyCost + freshnessCost;
    cumulativeDistance += legDistance;
    cumulativeCost += incrementalCost;
    stops.add(
      CsdRouteStop._(
        visitOrder: index + 1,
        entityId: target.entityId,
        hypothesis: hypothesis,
        legDistanceMeters: legDistance,
        cumulativeDistanceMeters: cumulativeDistance,
        distanceCost: distanceCost,
        uncertaintyCost: uncertaintyCost,
        freshnessCost: freshnessCost,
        incrementalCost: incrementalCost,
        cumulativeCost: cumulativeCost,
      ),
    );
    previous = hypothesis.position;
  }
  return stops;
}

void _verifyCoverage(
  CsdRouteRequest request,
  List<_SelectedTarget> route,
  List<String> unresolved,
) {
  final expectedResolved = <String>{};
  final expectedUnresolved = <String>{};
  for (final entry in request.entityLocations.entries) {
    (entry.value.hypotheses.isEmpty
            ? expectedUnresolved
            : expectedResolved)
        .add(entry.key);
  }
  final visited = <String>{};
  for (final target in route) {
    if (!expectedResolved.contains(target.entityId) ||
        !visited.add(target.entityId)) {
      throw StateError('CSD route coverage invariant failed.');
    }
  }
  if (visited.length != expectedResolved.length ||
      unresolved.length != expectedUnresolved.length ||
      unresolved.any((entityId) => !expectedUnresolved.contains(entityId))) {
    throw StateError('CSD route coverage invariant failed.');
  }
}

void _validateResult(CsdEntityLocationResult result) {
  if (result.hypotheses.length > CsdRouteLimits.maxHypothesesPerTarget) {
    throw RangeError.range(
      result.hypotheses.length,
      0,
      CsdRouteLimits.maxHypothesesPerTarget,
      'entityLocations[${result.entityId}].hypotheses.length',
    );
  }
  for (var index = 0; index < result.hypotheses.length; index++) {
    final hypothesis = result.hypotheses[index];
    if (hypothesis.entityId != result.entityId) {
      throw ArgumentError.value(
        hypothesis.entityId,
        'entityLocations[${result.entityId}].hypotheses[$index].entityId',
        'The hypothesis and result entity IDs must match.',
      );
    }
    _checkedUnitInterval(
      hypothesis.posteriorProbability,
      'hypotheses[$index].posteriorProbability',
    );
    _checkedUnitInterval(
      hypothesis.confidence,
      'hypotheses[$index].confidence',
    );
    _checkedUnitInterval(
      hypothesis.freshness,
      'hypotheses[$index].freshness',
    );
    final uncertainty = hypothesis.uncertaintyRadiusMeters;
    if (!uncertainty.isFinite || uncertainty < 0) {
      throw ArgumentError.value(
        uncertainty,
        'hypotheses[$index].uncertaintyRadiusMeters',
      );
    }
    if (!hypothesis.score.isFinite) {
      throw ArgumentError.value(
        hypothesis.score,
        'hypotheses[$index].score',
      );
    }
  }
}

double _checkedWeight(
  double value,
  String name, {
  bool mustBePositive = false,
}) {
  final invalidMinimum = mustBePositive ? value <= 0 : value < 0;
  if (!value.isFinite ||
      invalidMinimum ||
      value > CsdRouteLimits.maxCostWeight) {
    throw RangeError.range(
      value,
      mustBePositive ? double.minPositive : 0,
      CsdRouteLimits.maxCostWeight,
      name,
    );
  }
  return value == 0 ? 0 : value;
}

double _checkedUnitInterval(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw RangeError.range(value, 0, 1, name);
  }
  return value;
}

String _checkedEntityId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > CsdModelLimits.maxIdCharacters) {
    throw RangeError.range(
      normalized.length,
      1,
      CsdModelLimits.maxIdCharacters,
      '$name.length',
    );
  }
  if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(normalized)) {
    throw ArgumentError.value(value, name, 'Control characters are not allowed.');
  }
  return normalized;
}
