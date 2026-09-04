// LLM-CONTEXT:BEGIN
// FILE: lib/memory/chromatic_spatial_index.dart
// ROLE: Builds deterministic multi-indexes and probabilistic location beliefs from immutable physical observations.
// DOMAIN: chromatic-spatial-memory
// SECURITY-INVARIANT: Apply hard scope/time/confidence filters before ranking; keep all evidence bounded and local.
// CHANGE-GUARD: Preserve idempotent ingestion, correlation-aware fusion, temporal decay, multimodal history, and deterministic query diagnostics.
// DOCS: See /docs/llm-context-schema.md and /docs/chromatic-spatial-memory.md.
// LLM-CONTEXT:END
import 'dart:collection';
import 'dart:math' as math;

import 'chromatic_encoder.dart';
import 'chromatic_spatial_models.dart';

final class CsdLocateQuery {
  CsdLocateQuery._({
    required this.entityId,
    required this.text,
    required this.regionPrefix,
    required this.near,
    required this.radiusMeters,
    required this.asOf,
    required this.maxAge,
    required this.minimumConfidence,
    required this.limit,
    required this.candidateLimit,
    required this.profile,
    required this.weights,
    required this.semanticEmbedding,
    required this.visualEmbedding,
    required this.chromaticAddress,
  });

  factory CsdLocateQuery({
    String? entityId,
    String text = '',
    CsdRegionPath? regionPrefix,
    CsdVector3? near,
    double? radiusMeters,
    DateTime? asOf,
    Duration? maxAge,
    double minimumConfidence = 0.08,
    int limit = 5,
    int candidateLimit = 256,
    CsdQueryProfile profile = CsdQueryProfile.balanced,
    CsdQueryWeights? weights,
    List<double> semanticEmbedding = const <double>[],
    List<double> visualEmbedding = const <double>[],
    CsdChromaticAddress? chromaticAddress,
  }) {
    final normalizedEntity = entityId?.trim();
    final normalizedText = text.trim();
    if ((normalizedEntity == null || normalizedEntity.isEmpty) &&
        normalizedText.isEmpty &&
        near == null &&
        regionPrefix == null) {
      throw ArgumentError(
        'A CSD locate query needs an entity, text, region, or nearby point.',
      );
    }
    if (normalizedEntity != null &&
        normalizedEntity.length > CsdModelLimits.maxIdCharacters) {
      throw ArgumentError.value(entityId, 'entityId');
    }
    if (normalizedText.length > 512) {
      throw ArgumentError.value(
        text,
        'text',
        'Query text exceeds 512 characters.',
      );
    }
    if (!minimumConfidence.isFinite ||
        minimumConfidence < 0 ||
        minimumConfidence > 1) {
      throw RangeError.range(minimumConfidence, 0, 1, 'minimumConfidence');
    }
    if (limit < 1 || limit > 32) throw RangeError.range(limit, 1, 32, 'limit');
    if (candidateLimit < 8 || candidateLimit > 1024) {
      throw RangeError.range(candidateLimit, 8, 1024, 'candidateLimit');
    }
    if (radiusMeters != null &&
        (!radiusMeters.isFinite ||
            radiusMeters <= 0 ||
            radiusMeters > 100000)) {
      throw RangeError.range(radiusMeters, 0, 100000, 'radiusMeters');
    }
    if (radiusMeters != null && near == null) {
      throw ArgumentError('radiusMeters requires near.');
    }
    if (maxAge != null && (maxAge.isNegative || maxAge == Duration.zero)) {
      throw ArgumentError.value(maxAge, 'maxAge');
    }
    _validateQueryVector(semanticEmbedding, 'semanticEmbedding');
    _validateQueryVector(visualEmbedding, 'visualEmbedding');
    return CsdLocateQuery._(
      entityId: normalizedEntity?.isEmpty == true ? null : normalizedEntity,
      text: normalizedText,
      regionPrefix: regionPrefix,
      near: near,
      radiusMeters: radiusMeters,
      asOf: asOf?.toUtc(),
      maxAge: maxAge,
      minimumConfidence: minimumConfidence,
      limit: limit,
      candidateLimit: candidateLimit,
      profile: profile,
      weights: weights ?? CsdQueryWeights.forProfile(profile),
      semanticEmbedding: List<double>.unmodifiable(semanticEmbedding),
      visualEmbedding: List<double>.unmodifiable(visualEmbedding),
      chromaticAddress: chromaticAddress,
    );
  }

  final String? entityId;
  final String text;
  final CsdRegionPath? regionPrefix;
  final CsdVector3? near;
  final double? radiusMeters;
  final DateTime? asOf;
  final Duration? maxAge;
  final double minimumConfidence;
  final int limit;
  final int candidateLimit;
  final CsdQueryProfile profile;
  final CsdQueryWeights weights;
  final List<double> semanticEmbedding;
  final List<double> visualEmbedding;
  final CsdChromaticAddress? chromaticAddress;

  static void _validateQueryVector(List<double> vector, String label) {
    if (vector.length > CsdModelLimits.maxEmbeddingDimensions) {
      throw RangeError.range(
        vector.length,
        0,
        CsdModelLimits.maxEmbeddingDimensions,
        label,
      );
    }
    if (vector.any((value) => !value.isFinite || value.abs() > 1000000)) {
      throw ArgumentError.value(
        vector,
        label,
        'Vector must be finite and bounded.',
      );
    }
  }
}

final class CsdPlannerDiagnostics {
  const CsdPlannerDiagnostics({
    required this.universe,
    required this.afterHardFilters,
    required this.afterIdentity,
    required this.afterChromatic,
    required this.afterVector,
    required this.fusedHypotheses,
    required this.returnedResults,
    required this.plannerOrder,
    required this.entropyBeforeBits,
    required this.entropyAfterBits,
  });

  final int universe;
  final int afterHardFilters;
  final int afterIdentity;
  final int afterChromatic;
  final int afterVector;
  final int fusedHypotheses;
  final int returnedResults;
  final List<String> plannerOrder;
  final double entropyBeforeBits;
  final double entropyAfterBits;

  int get candidatesAvoided => math.max(0, universe - afterVector);
  double get uncertaintyReductionBits =>
      math.max(0, entropyBeforeBits - entropyAfterBits);

  Map<String, Object?> toJson() => <String, Object?>{
    'universe': universe,
    'afterHardFilters': afterHardFilters,
    'afterIdentity': afterIdentity,
    'afterChromatic': afterChromatic,
    'afterVector': afterVector,
    'fusedHypotheses': fusedHypotheses,
    'returnedResults': returnedResults,
    'plannerOrder': plannerOrder,
    'entropyBeforeBits': entropyBeforeBits,
    'entropyAfterBits': entropyAfterBits,
    'candidatesAvoided': candidatesAvoided,
  };
}

final class CsdScoreBreakdown {
  const CsdScoreBreakdown({
    required this.identity,
    required this.semantic,
    required this.visual,
    required this.spatial,
    required this.hierarchy,
    required this.temporal,
    required this.geometry,
    required this.chromatic,
    required this.confidence,
    required this.total,
  });

  final double identity;
  final double semantic;
  final double visual;
  final double spatial;
  final double hierarchy;
  final double temporal;
  final double geometry;
  final double chromatic;
  final double confidence;
  final double total;

  Map<String, Object?> toJson() => <String, Object?>{
    'identity': identity,
    'semantic': semantic,
    'visual': visual,
    'spatial': spatial,
    'hierarchy': hierarchy,
    'temporal': temporal,
    'geometry': geometry,
    'chromatic': chromatic,
    'confidence': confidence,
    'total': total,
  };
}

final class CsdLocationHypothesis {
  const CsdLocationHypothesis({
    required this.entityId,
    required this.region,
    required this.position,
    required this.covariance,
    required this.posteriorProbability,
    required this.confidence,
    required this.freshness,
    required this.effectiveEvidence,
    required this.evidenceCount,
    required this.independentSourceCount,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.score,
    required this.breakdown,
  });

  final String entityId;
  final CsdRegionPath region;
  final CsdVector3 position;
  final CsdCovariance3 covariance;
  final double posteriorProbability;
  final double confidence;
  final double freshness;
  final double effectiveEvidence;
  final int evidenceCount;
  final int independentSourceCount;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final double score;
  final CsdScoreBreakdown breakdown;

  double get uncertaintyRadiusMeters => covariance.uncertaintyRadius;

  Map<String, Object?> toJson() => <String, Object?>{
    'entityId': entityId,
    'region': region.toJson(),
    'position': position.toJson(),
    'covariance': covariance.toJson(),
    'posteriorProbability': posteriorProbability,
    'confidence': confidence,
    'freshness': freshness,
    'effectiveEvidence': effectiveEvidence,
    'evidenceCount': evidenceCount,
    'independentSourceCount': independentSourceCount,
    'firstObservedAt': firstObservedAt.toUtc().toIso8601String(),
    'lastObservedAt': lastObservedAt.toUtc().toIso8601String(),
    'score': score,
    'breakdown': breakdown.toJson(),
  };
}

final class CsdEntityLocationResult {
  const CsdEntityLocationResult({
    required this.entityId,
    required this.hypotheses,
    required this.entropyBits,
    required this.observationsConsidered,
  });

  final String entityId;
  final List<CsdLocationHypothesis> hypotheses;
  final double entropyBits;
  final int observationsConsidered;

  CsdLocationHypothesis get primary => hypotheses.first;
  List<CsdLocationHypothesis> get alternatives => hypotheses.length <= 1
      ? const <CsdLocationHypothesis>[]
      : List<CsdLocationHypothesis>.unmodifiable(hypotheses.skip(1));
}

final class CsdLocateResponse {
  const CsdLocateResponse({required this.results, required this.diagnostics});

  final List<CsdEntityLocationResult> results;
  final CsdPlannerDiagnostics diagnostics;

  bool get isEmpty => results.isEmpty;
}

final class CsdTracePoint {
  const CsdTracePoint({
    required this.observation,
    required this.entity,
    required this.effectiveConfidence,
    required this.address,
  });

  final CsdObservation observation;
  final CsdEntityCandidate entity;
  final double effectiveConfidence;
  final CsdChromaticAddress address;
}

final class CsdPrediction {
  const CsdPrediction({
    required this.entityId,
    required this.at,
    required this.position,
    required this.region,
    required this.confidence,
    required this.basedOnObservations,
    required this.extrapolated,
  });

  final String entityId;
  final DateTime at;
  final CsdVector3 position;
  final CsdRegionPath region;
  final double confidence;
  final int basedOnObservations;
  final bool extrapolated;
}

/// Deterministic local feature hashing for compact semantic evidence. It never
/// invokes the app's optional remote embedding routes.
final class CsdLocalSemanticEncoder {
  const CsdLocalSemanticEncoder({this.dimensions = 128})
    : assert(
        dimensions > 0 && dimensions <= CsdModelLimits.maxEmbeddingDimensions,
      );

  final int dimensions;

  List<double> encode(String text) {
    final output = List<double>.filled(dimensions, 0);
    final words = RegExp(r"[A-Za-z0-9_'-]+")
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((word) => word.length > 1)
        .take(256)
        .toList(growable: false);
    for (var i = 0; i < words.length; i++) {
      _add(output, 'w:${words[i]}', 1);
      if (i + 1 < words.length) {
        _add(output, 'b:${words[i]}_${words[i + 1]}', 0.66);
      }
      final word = words[i];
      for (var j = 0; j + 2 < word.length && j < 8; j++) {
        _add(output, 'c:${word.substring(j, j + 3)}', 0.18);
      }
    }
    var norm = 0.0;
    for (final value in output) {
      norm += value * value;
    }
    if (norm <= 1e-18) return output;
    final inverse = 1 / math.sqrt(norm);
    for (var i = 0; i < output.length; i++) {
      output[i] *= inverse;
    }
    return List<double>.unmodifiable(output);
  }

  void _add(List<double> output, String feature, double weight) {
    var hash = 0x811C9DC5;
    for (final unit in feature.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    output[hash % output.length] += (hash & 0x80000000) == 0 ? weight : -weight;
  }
}

/// In-memory multi-index and probability-surface engine.
///
/// This class never persists data and is safe to discard on vault lock. Its
/// output is entirely derived from the immutable encrypted event stream.
final class CsdSpatialIndex {
  CsdSpatialIndex({
    CsdChromaticEncoder? encoder,
    CsdLocalSemanticEncoder? semanticEncoder,
    this.maxObservations = 20000,
  }) : encoder = encoder ?? CsdChromaticEncoder(),
       semanticEncoder = semanticEncoder ?? const CsdLocalSemanticEncoder() {
    if (maxObservations < 1 || maxObservations > 100000) {
      throw ArgumentError.value(maxObservations, 'maxObservations');
    }
  }

  final CsdChromaticEncoder encoder;
  final CsdLocalSemanticEncoder semanticEncoder;
  final int maxObservations;

  final Map<String, CsdObservation> _observations = <String, CsdObservation>{};
  final Map<String, CsdChromaticAddress> _addresses =
      <String, CsdChromaticAddress>{};
  final Map<String, Set<String>> _entityIndex = <String, Set<String>>{};
  final Map<String, Set<String>> _tokenIndex = <String, Set<String>>{};
  final Map<String, Set<String>> _structureIndex = <String, Set<String>>{};
  final Map<String, Set<String>> _chromaticIndex = <String, Set<String>>{};

  int get length => _observations.length;
  int get entityCount =>
      _entityIndex.keys.where((key) => key.startsWith('id:')).length;
  int get chromaticBucketCount => _chromaticIndex.length;
  CsdObservation? observationById(String id) => _observations[id];
  Iterable<CsdObservation> get observations =>
      UnmodifiableListView<CsdObservation>(_orderedObservations());

  bool add(CsdObservation observation) {
    final prior = _observations[observation.id];
    if (prior != null) {
      if (prior == observation) return false;
      throw StateError(
        'Observation ID ${observation.id} already identifies different evidence.',
      );
    }
    if (_observations.length >= maxObservations) {
      throw StateError('CSD in-memory observation capacity reached.');
    }
    final address = encoder.encode(observation);
    _observations[observation.id] = observation;
    _addresses[observation.id] = address;
    for (final entity in observation.entities) {
      _post(_entityIndex, 'id:${_normalize(entity.entityId)}', observation.id);
      if (entity.sku != null) {
        _post(_entityIndex, 'sku:${_normalize(entity.sku!)}', observation.id);
      }
      for (final token in _entityTokens(entity)) {
        _post(_tokenIndex, token, observation.id);
      }
    }
    _post(_structureIndex, _structureKey(observation.region), observation.id);
    _post(_chromaticIndex, address.prefixHex(2), observation.id);
    return true;
  }

  int addAll(Iterable<CsdObservation> observations) {
    var added = 0;
    for (final observation in observations) {
      if (add(observation)) added++;
    }
    return added;
  }

  void rebuild(Iterable<CsdObservation> observations) {
    clear();
    final sorted = observations.toList(growable: false)
      ..sort(_compareObservations);
    addAll(sorted);
  }

  void clear() {
    _observations.clear();
    _addresses.clear();
    _entityIndex.clear();
    _tokenIndex.clear();
    _structureIndex.clear();
    _chromaticIndex.clear();
  }

  CsdLocateResponse locate(CsdLocateQuery query, {DateTime? now}) {
    final referenceTime = (query.asOf ?? now ?? DateTime.now()).toUtc();
    final universe = _observations.length;
    var candidateIds = _observations.keys.toSet();
    final plannerOrder = <String>['hard-scope'];

    final structurePosting = query.regionPrefix == null
        ? null
        : _structureIndex[_structureKey(query.regionPrefix!)];
    if (structurePosting != null)
      candidateIds = candidateIds.intersection(structurePosting);
    candidateIds.removeWhere((id) {
      final observation = _observations[id]!;
      if (observation.observedAt.isAfter(referenceTime)) return true;
      if (query.maxAge != null &&
          referenceTime.difference(observation.observedAt) > query.maxAge!) {
        return true;
      }
      if (query.regionPrefix != null &&
          !query.regionPrefix!.isPrefixOf(observation.region)) {
        return true;
      }
      final confidence = _observationConfidence(observation, referenceTime);
      if (confidence < query.minimumConfidence) return true;
      if (query.near != null &&
          query.radiusMeters != null &&
          observation.pose.position.distanceTo(query.near!) >
              query.radiusMeters!) {
        return true;
      }
      return false;
    });
    final afterHard = candidateIds.length;

    final exactPosting = _exactEntityPosting(query.entityId);
    final queryTokens = _tokens(query.text);
    final lexicalPosting = <String>{};
    for (final token in queryTokens) {
      lexicalPosting.addAll(_tokenIndex[token] ?? const <String>{});
    }
    if (exactPosting != null) {
      plannerOrder.add('entity-hash');
      candidateIds = candidateIds.intersection(exactPosting);
    } else if (query.entityId != null) {
      candidateIds.clear();
    } else if (queryTokens.isNotEmpty && lexicalPosting.isNotEmpty) {
      plannerOrder.add('semantic-lexical');
      candidateIds = candidateIds.intersection(lexicalPosting);
    }
    final afterIdentity = candidateIds.length;

    final queryAddress = query.chromaticAddress;
    var candidates = candidateIds
        .map(
          (id) => _IndexedCandidate(
            observation: _observations[id]!,
            address: _addresses[id]!,
          ),
        )
        .toList(growable: false);
    if (queryAddress != null) {
      plannerOrder.add('chromatic-multiprobe');
      final nearbyBuckets = _neighborPrefixes(queryAddress);
      final bucketIds = <String>{};
      for (final bucket in nearbyBuckets) {
        bucketIds.addAll(_chromaticIndex[bucket] ?? const <String>{});
      }
      // Exact/neighbor buckets are a fast preference, not an unsafe hard miss:
      // fallback candidates remain available across quantization boundaries.
      candidates = candidates.toList(growable: false)
        ..sort((a, b) {
          final aNear = bucketIds.contains(a.observation.id) ? 0 : 1;
          final bNear = bucketIds.contains(b.observation.id) ? 0 : 1;
          final byBucket = aNear.compareTo(bNear);
          if (byBucket != 0) return byBucket;
          final ad = a.address.distanceTo(queryAddress, weights: query.weights);
          final bd = b.address.distanceTo(queryAddress, weights: query.weights);
          final byDistance = ad.compareTo(bd);
          return byDistance != 0
              ? byDistance
              : a.observation.id.compareTo(b.observation.id);
        });
    }
    if (candidates.length > query.candidateLimit * 2) {
      candidates = candidates
          .take(query.candidateLimit * 2)
          .toList(growable: false);
    }
    final afterChromatic = candidates.length;

    final querySemantic = query.semanticEmbedding.isNotEmpty
        ? query.semanticEmbedding
        : query.text.isEmpty
        ? const <double>[]
        : semanticEncoder.encode(query.text);
    plannerOrder.add('vector-refine');
    final rankedObservations =
        candidates
            .map((candidate) {
              final identity = _bestIdentityScore(candidate.observation, query);
              final semantic = _semanticScore(
                candidate.observation,
                querySemantic,
                query.text,
              );
              final visual = query.visualEmbedding.isEmpty
                  ? 0.0
                  : _cosine(
                      query.visualEmbedding,
                      candidate.observation.visualEmbedding,
                    );
              final chromatic = queryAddress == null
                  ? 0.0
                  : 1 -
                        candidate.address.distanceTo(
                          queryAddress,
                          weights: query.weights,
                        );
              final freshness = candidate.observation.freshnessAt(
                referenceTime,
              );
              final coarse =
                  0.38 * identity +
                  0.28 * semantic +
                  0.10 * visual +
                  0.08 * chromatic +
                  0.16 * freshness * candidate.observation.confidence.aggregate;
              return _RankedObservation(
                observation: candidate.observation,
                address: candidate.address,
                identity: identity,
                semantic: semantic,
                visual: visual,
                chromatic: chromatic,
                coarse: coarse,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.coarse.compareTo(a.coarse);
            return byScore != 0
                ? byScore
                : a.observation.id.compareTo(b.observation.id);
          });
    final refined = rankedObservations
        .take(query.candidateLimit)
        .toList(growable: false);
    final afterVector = refined.length;

    plannerOrder.add('correlated-belief-fusion');
    final byEntity = <String, List<_RankedObservation>>{};
    for (final ranked in refined) {
      for (final entity in _matchingEntities(ranked.observation, query)) {
        byEntity
            .putIfAbsent(entity.entityId, () => <_RankedObservation>[])
            .add(ranked.withEntity(entity));
      }
    }
    final results = <CsdEntityLocationResult>[];
    var fusedCount = 0;
    for (final entry in byEntity.entries) {
      final result = _fuseEntity(
        entry.key,
        entry.value,
        query: query,
        referenceTime: referenceTime,
      );
      if (result != null) {
        fusedCount += result.hypotheses.length;
        results.add(result);
      }
    }
    results.sort((a, b) {
      final byScore = b.primary.score.compareTo(a.primary.score);
      return byScore != 0 ? byScore : a.entityId.compareTo(b.entityId);
    });
    final returned = results.take(query.limit).toList(growable: false);
    final entropyBefore = _uniformEntropy(universe);
    final entropyAfter = returned.isEmpty
        ? 0.0
        : returned
                  .map((result) => result.entropyBits)
                  .fold<double>(0, (sum, value) => sum + value) /
              returned.length;
    return CsdLocateResponse(
      results: List<CsdEntityLocationResult>.unmodifiable(returned),
      diagnostics: CsdPlannerDiagnostics(
        universe: universe,
        afterHardFilters: afterHard,
        afterIdentity: afterIdentity,
        afterChromatic: afterChromatic,
        afterVector: afterVector,
        fusedHypotheses: fusedCount,
        returnedResults: returned.length,
        plannerOrder: List<String>.unmodifiable(plannerOrder),
        entropyBeforeBits: entropyBefore,
        entropyAfterBits: entropyAfter,
      ),
    );
  }

  List<CsdTracePoint> trace({
    required String entityId,
    DateTime? from,
    DateTime? through,
    CsdRegionPath? regionPrefix,
    int limit = 512,
  }) {
    final normalized = _normalize(entityId);
    if (normalized.isEmpty ||
        normalized.length > CsdModelLimits.maxIdCharacters) {
      throw ArgumentError.value(entityId, 'entityId');
    }
    if (limit < 1 || limit > 4096)
      throw RangeError.range(limit, 1, 4096, 'limit');
    final start = from?.toUtc();
    final end = through?.toUtc();
    if (start != null && end != null && start.isAfter(end)) {
      throw ArgumentError('from must not be after through.');
    }
    final ids = <String>{
      ...?_entityIndex['id:$normalized'],
      ...?_entityIndex['sku:$normalized'],
    };
    final points = <CsdTracePoint>[];
    for (final id in ids) {
      final observation = _observations[id]!;
      if (start != null && observation.observedAt.isBefore(start)) continue;
      if (end != null && observation.observedAt.isAfter(end)) continue;
      if (regionPrefix != null &&
          !regionPrefix.isPrefixOf(observation.region)) {
        continue;
      }
      final entity = observation.entities.firstWhere(
        (candidate) =>
            _normalize(candidate.entityId) == normalized ||
            (candidate.sku != null && _normalize(candidate.sku!) == normalized),
      );
      points.add(
        CsdTracePoint(
          observation: observation,
          entity: entity,
          effectiveConfidence:
              entity.probability *
              observation.confidence.aggregate *
              observation.provenance.reliability,
          address: _addresses[id]!,
        ),
      );
    }
    points.sort((a, b) {
      final byTime = a.observation.observedAt.compareTo(
        b.observation.observedAt,
      );
      return byTime != 0
          ? byTime
          : a.observation.id.compareTo(b.observation.id);
    });
    return List<CsdTracePoint>.unmodifiable(points.take(limit));
  }

  CsdPrediction? predict({
    required String entityId,
    required DateTime at,
    DateTime? now,
  }) {
    final target = at.toUtc();
    final reference = (now ?? DateTime.now()).toUtc();
    final history = trace(entityId: entityId, through: reference, limit: 32)
        .where(
          (point) =>
              point.observation.kind == CsdObservationKind.presence ||
              point.observation.kind == CsdObservationKind.move,
        )
        .toList(growable: false);
    if (history.isEmpty) return null;
    final last = history.last;
    var position = last.observation.pose.position;
    var extrapolated = false;
    if (history.length >= 2 && target.isAfter(last.observation.observedAt)) {
      final previous = history[history.length - 2];
      final dt = last.observation.observedAt
          .difference(previous.observation.observedAt)
          .inMicroseconds;
      final future = target
          .difference(last.observation.observedAt)
          .inMicroseconds;
      // Extrapolation is deliberately bounded to one observation interval and
      // applies only to mobile entities.
      if (dt > 0 &&
          future > 0 &&
          last.entity.entityClass == CsdEntityClass.mobile) {
        final ratio = (future / dt).clamp(0.0, 1.0);
        final a = previous.observation.pose.position;
        final b = last.observation.pose.position;
        position = CsdVector3(
          b.x + (b.x - a.x) * ratio,
          b.y + (b.y - a.y) * ratio,
          b.z + (b.z - a.z) * ratio,
        );
        extrapolated = true;
      }
    }
    final confidence =
        (last.effectiveConfidence *
                last.observation.freshnessAt(target) *
                (extrapolated ? 0.72 : 1.0))
            .clamp(0.0, 0.995);
    return CsdPrediction(
      entityId: last.entity.entityId,
      at: target,
      position: position,
      region: last.observation.region,
      confidence: confidence,
      basedOnObservations: math.min(2, history.length),
      extrapolated: extrapolated,
    );
  }

  CsdEntityLocationResult? _fuseEntity(
    String entityId,
    List<_RankedObservation> ranked, {
    required CsdLocateQuery query,
    required DateTime referenceTime,
  }) {
    final presence = ranked.where(
      (item) =>
          item.observation.kind == CsdObservationKind.presence ||
          item.observation.kind == CsdObservationKind.move,
    );
    final positive = presence.toList(growable: false)
      ..sort((a, b) {
        final ar = _regionCellKey(a.observation.region);
        final br = _regionCellKey(b.observation.region);
        final byRegion = ar.compareTo(br);
        if (byRegion != 0) return byRegion;
        final ap = a.observation.pose.position;
        final bp = b.observation.pose.position;
        final byX = ap.x.compareTo(bp.x);
        if (byX != 0) return byX;
        final byY = ap.y.compareTo(bp.y);
        if (byY != 0) return byY;
        final byZ = ap.z.compareTo(bp.z);
        return byZ != 0 ? byZ : a.observation.id.compareTo(b.observation.id);
      });
    if (positive.isEmpty) return null;

    final groupCounts = <String, int>{};
    for (final item in ranked) {
      final group = item.observation.provenance.correlationGroup;
      groupCounts[group] = (groupCounts[group] ?? 0) + 1;
    }
    final parent = List<int>.generate(positive.length, (index) => index);
    int root(int index) {
      while (parent[index] != index) {
        parent[index] = parent[parent[index]];
        index = parent[index];
      }
      return index;
    }

    void unite(int a, int b) {
      final ra = root(a);
      final rb = root(b);
      if (ra == rb) return;
      if (ra < rb) {
        parent[rb] = ra;
      } else {
        parent[ra] = rb;
      }
    }

    for (var i = 0; i < positive.length; i++) {
      for (var j = i + 1; j < positive.length; j++) {
        final a = positive[i].observation;
        final b = positive[j].observation;
        if (_regionCellKey(a.region) != _regionCellKey(b.region)) continue;
        final uncertainty = math.sqrt(
          a.pose.covariance.meanVariance + b.pose.covariance.meanVariance,
        );
        final threshold = (0.5 + 2.5 * uncertainty).clamp(0.75, 8.0);
        if (a.pose.position.distanceTo(b.pose.position) <= threshold)
          unite(i, j);
      }
    }
    final clusters = <int, List<_RankedObservation>>{};
    for (var i = 0; i < positive.length; i++) {
      clusters
          .putIfAbsent(root(i), () => <_RankedObservation>[])
          .add(positive[i]);
    }
    final raw = <_RawHypothesis>[];
    for (final items in clusters.values) {
      raw.add(
        _buildRawHypothesis(
          entityId,
          items,
          allRanked: ranked,
          groupCounts: groupCounts,
          referenceTime: referenceTime,
        ),
      );
    }
    var massTotal = raw.fold<double>(0, (sum, item) => sum + item.mass);
    if (massTotal <= 1e-15) return null;

    final hypotheses =
        raw
            .map((item) {
              final posterior = item.mass / massTotal;
              final breakdown = _scoreHypothesis(
                item,
                posterior: posterior,
                query: query,
                referenceTime: referenceTime,
              );
              return CsdLocationHypothesis(
                entityId: entityId,
                region: item.region,
                position: item.position,
                covariance: item.covariance,
                posteriorProbability: posterior,
                confidence: item.confidence,
                freshness: item.freshness,
                effectiveEvidence: item.mass,
                evidenceCount: item.items.length,
                independentSourceCount: item.independentSources,
                firstObservedAt: item.firstObservedAt,
                lastObservedAt: item.lastObservedAt,
                score: breakdown.total,
                breakdown: breakdown,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            final byPosterior = b.posteriorProbability.compareTo(
              a.posteriorProbability,
            );
            if (byPosterior != 0) return byPosterior;
            return a.region.canonicalKey.compareTo(b.region.canonicalKey);
          });
    return CsdEntityLocationResult(
      entityId: entityId,
      hypotheses: List<CsdLocationHypothesis>.unmodifiable(hypotheses),
      entropyBits: _entropy(
        hypotheses.map((item) => item.posteriorProbability),
      ),
      observationsConsidered: ranked.length,
    );
  }

  _RawHypothesis _buildRawHypothesis(
    String entityId,
    List<_RankedObservation> items, {
    required List<_RankedObservation> allRanked,
    required Map<String, int> groupCounts,
    required DateTime referenceTime,
  }) {
    final weighted = <(_RankedObservation, double)>[];
    for (final item in items) {
      final observation = item.observation;
      final groupSize =
          groupCounts[observation.provenance.correlationGroup] ?? 1;
      final weight = _positiveWeight(
        item,
        referenceTime,
        redundancy: 1 / math.sqrt(groupSize),
      );
      if (weight > 0) weighted.add((item, weight));
    }
    var mass = weighted.fold<double>(0, (sum, entry) => sum + entry.$2);
    final region = items
        .map((item) => item.observation.region)
        .reduce((a, b) => a.depth >= b.depth ? a : b);
    var x = 0.0;
    var y = 0.0;
    var z = 0.0;
    for (final entry in weighted) {
      x += entry.$1.observation.pose.position.x * entry.$2;
      y += entry.$1.observation.pose.position.y * entry.$2;
      z += entry.$1.observation.pose.position.z * entry.$2;
    }
    final denominator = math.max(1e-15, mass);
    final position = CsdVector3(
      x / denominator,
      y / denominator,
      z / denominator,
    );
    var xx = 0.0;
    var xy = 0.0;
    var xz = 0.0;
    var yy = 0.0;
    var yz = 0.0;
    var zz = 0.0;
    var freshness = 0.0;
    var identity = 0.0;
    var semantic = 0.0;
    var visual = 0.0;
    var chromatic = 0.0;
    final sources = <String>{};
    for (final entry in weighted) {
      final item = entry.$1;
      final weight = entry.$2;
      final observation = item.observation;
      final covariance = observation.pose.covariance;
      final dx = observation.pose.position.x - position.x;
      final dy = observation.pose.position.y - position.y;
      final dz = observation.pose.position.z - position.z;
      xx += weight * (covariance.xx + dx * dx);
      xy += weight * (covariance.xy + dx * dy);
      xz += weight * (covariance.xz + dx * dz);
      yy += weight * (covariance.yy + dy * dy);
      yz += weight * (covariance.yz + dy * dz);
      zz += weight * (covariance.zz + dz * dz);
      freshness += weight * observation.freshnessAt(referenceTime);
      identity += weight * item.identity;
      semantic += weight * item.semantic;
      visual += weight * item.visual;
      chromatic += weight * item.chromatic;
      sources.add(observation.provenance.sensorId);
    }
    final covariance = CsdCovariance3(
      xx: math.max(1e-9, xx / denominator),
      xy: xy / denominator,
      xz: xz / denominator,
      yy: math.max(1e-9, yy / denominator),
      yz: yz / denominator,
      zz: math.max(1e-9, zz / denominator),
    );

    // Negative observations attenuate compatible location cells while the
    // positive evidence and historical event remain intact.
    for (final negative in allRanked.where(
      (item) => item.observation.kind == CsdObservationKind.absence,
    )) {
      if (_regionCellKey(negative.observation.region) !=
          _regionCellKey(region)) {
        continue;
      }
      final groupSize =
          groupCounts[negative.observation.provenance.correlationGroup] ?? 1;
      final weight = _positiveWeight(
        negative,
        referenceTime,
        redundancy: 1 / math.sqrt(groupSize),
      );
      mass *= math.exp(-weight.clamp(0.0, 4.0));
    }
    final diversity = 0.60 + 0.40 * (1 - math.exp(-sources.length / 2));
    final uncertainty = 1 / (1 + covariance.uncertaintyRadius / 8);
    final confidence = ((1 - math.exp(-mass)) * diversity * uncertainty).clamp(
      0.0,
      0.995,
    );
    final orderedTimes =
        items.map((item) => item.observation.observedAt).toList()..sort();
    return _RawHypothesis(
      entityId: entityId,
      region: region,
      position: position,
      covariance: covariance,
      mass: math.max(1e-15, mass),
      confidence: confidence,
      freshness: freshness / denominator,
      independentSources: sources.length,
      firstObservedAt: orderedTimes.first,
      lastObservedAt: orderedTimes.last,
      identity: identity / denominator,
      semantic: semantic / denominator,
      visual: visual / denominator,
      chromatic: chromatic / denominator,
      items: items,
    );
  }

  CsdScoreBreakdown _scoreHypothesis(
    _RawHypothesis item, {
    required double posterior,
    required CsdLocateQuery query,
    required DateTime referenceTime,
  }) {
    final spatial = query.near == null
        ? 0.0
        : 1 / (1 + item.position.distanceTo(query.near!));
    final hierarchy = query.regionPrefix == null
        ? 0.0
        : query.regionPrefix!.isPrefixOf(item.region)
        ? 1.0
        : 0.0;
    final geometry = 1 / (1 + item.covariance.uncertaintyRadius);
    final fields = <(double value, double weight, bool available)>[
      (item.identity, 0.18, query.entityId != null || query.text.isNotEmpty),
      (
        item.semantic,
        query.weights.semantic,
        query.text.isNotEmpty || query.semanticEmbedding.isNotEmpty,
      ),
      (item.visual, query.weights.visual, query.visualEmbedding.isNotEmpty),
      (spatial, query.weights.spatial, query.near != null),
      (hierarchy, query.weights.hierarchy, query.regionPrefix != null),
      (item.freshness, query.weights.temporal, true),
      (geometry, query.weights.geometry, true),
      (item.chromatic, 0.10, query.chromaticAddress != null),
      (item.confidence, 0.16, true),
      (posterior, 0.18, true),
    ];
    var totalWeight = 0.0;
    var total = 0.0;
    for (final field in fields) {
      if (!field.$3 || field.$2 <= 0) continue;
      totalWeight += field.$2;
      total += field.$1.clamp(0.0, 1.0) * field.$2;
    }
    total = totalWeight <= 0 ? 0 : total / totalWeight;
    return CsdScoreBreakdown(
      identity: item.identity.clamp(0.0, 1.0),
      semantic: item.semantic.clamp(0.0, 1.0),
      visual: item.visual.clamp(0.0, 1.0),
      spatial: spatial.clamp(0.0, 1.0),
      hierarchy: hierarchy,
      temporal: item.freshness.clamp(0.0, 1.0),
      geometry: geometry.clamp(0.0, 1.0),
      chromatic: item.chromatic.clamp(0.0, 1.0),
      confidence: item.confidence.clamp(0.0, 1.0),
      total: total.clamp(0.0, 1.0),
    );
  }

  double _positiveWeight(
    _RankedObservation ranked,
    DateTime referenceTime, {
    required double redundancy,
  }) {
    final observation = ranked.observation;
    final entity = ranked.entity ?? observation.mostLikelyEntity;
    return entity.probability *
        observation.confidence.aggregate *
        observation.provenance.reliability *
        observation.freshnessAt(referenceTime) *
        redundancy;
  }

  Iterable<CsdEntityCandidate> _matchingEntities(
    CsdObservation observation,
    CsdLocateQuery query,
  ) sync* {
    final exact = query.entityId == null ? null : _normalize(query.entityId!);
    for (final entity in observation.entities) {
      if (exact != null) {
        if (_normalize(entity.entityId) == exact ||
            (entity.sku != null && _normalize(entity.sku!) == exact)) {
          yield entity;
        }
        continue;
      }
      if (query.text.isEmpty || _identityScore(entity, query.text) > 0) {
        yield entity;
      }
    }
  }

  Set<String>? _exactEntityPosting(String? entityId) {
    if (entityId == null) return null;
    final normalized = _normalize(entityId);
    final ids = <String>{
      ...?_entityIndex['id:$normalized'],
      ...?_entityIndex['sku:$normalized'],
    };
    return ids;
  }

  double _bestIdentityScore(CsdObservation observation, CsdLocateQuery query) {
    var best = 0.0;
    for (final entity in observation.entities) {
      if (query.entityId != null) {
        final expected = _normalize(query.entityId!);
        if (_normalize(entity.entityId) == expected ||
            (entity.sku != null && _normalize(entity.sku!) == expected)) {
          best = math.max(best, entity.probability);
        }
      } else if (query.text.isNotEmpty) {
        best = math.max(
          best,
          _identityScore(entity, query.text) * entity.probability,
        );
      } else {
        best = math.max(best, entity.probability);
      }
    }
    return best;
  }

  double _identityScore(CsdEntityCandidate entity, String query) {
    final wanted = _tokens(query);
    if (wanted.isEmpty) return 0;
    final available = _entityTokens(entity);
    final overlap = wanted.intersection(available).length;
    if (overlap == 0) return 0;
    return (overlap / wanted.length).clamp(0.0, 1.0);
  }

  double _semanticScore(
    CsdObservation observation,
    List<double> queryVector,
    String queryText,
  ) {
    if (queryVector.isEmpty) return 0;
    if (observation.semanticEmbedding.isNotEmpty) {
      return _cosine(queryVector, observation.semanticEmbedding);
    }
    final descriptor = observation.entities.map(_entityDescriptor).join(' ');
    return _cosine(
      queryVector,
      semanticEncoder.encode('$descriptor $queryText'),
    );
  }

  double _observationConfidence(CsdObservation observation, DateTime at) =>
      observation.confidence.aggregate *
      observation.provenance.reliability *
      observation.freshnessAt(at) *
      observation.mostLikelyEntity.probability;

  List<CsdObservation> _orderedObservations() =>
      _observations.values.toList()..sort(_compareObservations);

  static int _compareObservations(CsdObservation a, CsdObservation b) {
    final byTime = a.observedAt.compareTo(b.observedAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  static String _structureKey(CsdRegionPath region) =>
      '${_normalize(region.globalTile)}|${_normalize(region.structureId)}';

  static String _regionCellKey(CsdRegionPath region) => <Object?>[
    region.globalTile,
    region.structureId,
    region.floorLevel,
    region.zoneId,
    region.aisleId,
    region.bayId,
    region.shelfId,
  ].join('|');

  static void _post(
    Map<String, Set<String>> index,
    String key,
    String observationId,
  ) => index.putIfAbsent(key, () => <String>{}).add(observationId);

  static Set<String> _entityTokens(CsdEntityCandidate entity) =>
      _tokens(_entityDescriptor(entity));

  static String _entityDescriptor(CsdEntityCandidate entity) => [
    entity.entityId,
    entity.sku,
    entity.category,
    entity.brand,
    ...entity.attributes.entries.expand((entry) => [entry.key, entry.value]),
  ].whereType<String>().join(' ');

  static Set<String> _tokens(String text) => RegExp(r"[a-z0-9][a-z0-9_'-]{1,}")
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .take(64)
      .toSet();

  static String _normalize(String value) => value.trim().toLowerCase();

  static double _cosine(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) return 0;
    var dot = 0.0;
    var aa = 0.0;
    var bb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      aa += a[i] * a[i];
      bb += b[i] * b[i];
    }
    if (aa <= 1e-18 || bb <= 1e-18) return 0;
    return (dot / math.sqrt(aa * bb)).clamp(0.0, 1.0);
  }

  static Set<String> _neighborPrefixes(CsdChromaticAddress address) {
    final bytes = address.bytes;
    final values = <String>{address.prefixHex(2)};
    for (var index = 0; index < 2; index++) {
      for (final delta in const <int>[-1, 1]) {
        final changed = List<int>.from(bytes);
        changed[index] = (changed[index] + delta).clamp(0, 255);
        values.add(CsdChromaticAddress(changed).prefixHex(2));
      }
    }
    return values;
  }

  static double _entropy(Iterable<double> probabilities) {
    var entropy = 0.0;
    for (final probability in probabilities) {
      if (probability > 0)
        entropy -= probability * (math.log(probability) / math.ln2);
    }
    return entropy;
  }

  static double _uniformEntropy(int count) =>
      count <= 1 ? 0 : math.log(count) / math.ln2;
}

final class _IndexedCandidate {
  const _IndexedCandidate({required this.observation, required this.address});
  final CsdObservation observation;
  final CsdChromaticAddress address;
}

final class _RankedObservation {
  const _RankedObservation({
    required this.observation,
    required this.address,
    required this.identity,
    required this.semantic,
    required this.visual,
    required this.chromatic,
    required this.coarse,
    this.entity,
  });

  final CsdObservation observation;
  final CsdChromaticAddress address;
  final double identity;
  final double semantic;
  final double visual;
  final double chromatic;
  final double coarse;
  final CsdEntityCandidate? entity;

  _RankedObservation withEntity(CsdEntityCandidate value) => _RankedObservation(
    observation: observation,
    address: address,
    identity: identity,
    semantic: semantic,
    visual: visual,
    chromatic: chromatic,
    coarse: coarse,
    entity: value,
  );
}

final class _RawHypothesis {
  const _RawHypothesis({
    required this.entityId,
    required this.region,
    required this.position,
    required this.covariance,
    required this.mass,
    required this.confidence,
    required this.freshness,
    required this.independentSources,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.identity,
    required this.semantic,
    required this.visual,
    required this.chromatic,
    required this.items,
  });

  final String entityId;
  final CsdRegionPath region;
  final CsdVector3 position;
  final CsdCovariance3 covariance;
  final double mass;
  final double confidence;
  final double freshness;
  final int independentSources;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final double identity;
  final double semantic;
  final double visual;
  final double chromatic;
  final List<_RankedObservation> items;
}
