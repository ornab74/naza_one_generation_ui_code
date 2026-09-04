// LLM-CONTEXT:BEGIN
// FILE: lib/memory/chromatic_encoder.dart
// ROLE: Deterministically maps bounded physical observations into compact 12-byte chromatic addresses.
// DOMAIN: local-memory
// SECURITY-INVARIANT: Encoding is local-only, deterministic, allocation-bounded, and never treats a chromatic bucket as authoritative identity or location.
// CHANGE-GUARD: Preserve channel order and serialized configuration compatibility; exact query reranking must remain responsible for final results.
// DOCS: See /SECURITY.md, /docs/llm-context-schema.md, and /lib/memory/mermaid.md.
// LLM-CONTEXT:END
import 'dart:math' as math;

import 'chromatic_spatial_models.dart';

/// A deterministic coarse encoder for progressive candidate collapse.
///
/// The address is deliberately an acceleration hint rather than stored truth.
/// Hierarchy constraints and exact probabilistic reranking must be applied
/// after bucket lookup. Fixed random projections are used instead of a model,
/// keeping the encoder available before local inference is loaded.
final class CsdChromaticEncoder {
  const CsdChromaticEncoder._({
    required this.spatialOrigin,
    required this.spatialExtent,
    required this.temporalEpoch,
    required this.temporalBucket,
  });

  factory CsdChromaticEncoder({
    CsdVector3 spatialOrigin = CsdVector3.zero,
    CsdVector3? spatialExtent,
    DateTime? temporalEpoch,
    Duration temporalBucket = const Duration(days: 30),
  }) {
    final extent = spatialExtent ?? CsdVector3(250, 250, 30);
    for (final entry in <MapEntry<String, double>>[
      MapEntry<String, double>('spatialExtent.x', extent.x),
      MapEntry<String, double>('spatialExtent.y', extent.y),
      MapEntry<String, double>('spatialExtent.z', extent.z),
    ]) {
      if (!entry.value.isFinite ||
          entry.value <= 1e-6 ||
          entry.value > CsdModelLimits.maxCoordinateMagnitude) {
        throw RangeError.value(
          entry.value,
          entry.key,
          'Expected a finite value in (0.000001, ${CsdModelLimits.maxCoordinateMagnitude}].',
        );
      }
    }
    const maximumTemporalBucket = Duration(days: 365);
    const minimumTemporalBucket = Duration(minutes: 1);
    if (temporalBucket < minimumTemporalBucket ||
        temporalBucket > maximumTemporalBucket) {
      throw RangeError.range(
        temporalBucket.inMicroseconds,
        minimumTemporalBucket.inMicroseconds,
        maximumTemporalBucket.inMicroseconds,
        'temporalBucket.inMicroseconds',
      );
    }
    final epoch = (temporalEpoch ?? DateTime.utc(2020)).toUtc();
    if (epoch.year < 1970 || epoch.year > 9999) {
      throw RangeError.range(epoch.year, 1970, 9999, 'temporalEpoch.year');
    }
    return CsdChromaticEncoder._(
      spatialOrigin: spatialOrigin,
      spatialExtent: extent,
      temporalEpoch: epoch,
      temporalBucket: temporalBucket,
    );
  }

  static const String format = 'naza-csd-chromatic-encoder-v1';

  final CsdVector3 spatialOrigin;
  final CsdVector3 spatialExtent;
  final DateTime temporalEpoch;
  final Duration temporalBucket;

  /// Encodes the stable channel order documented by [CsdChromaticChannel].
  CsdChromaticAddress encode(CsdObservation observation) {
    final visualHash = observation.perceptualHash;
    final likelyEntity = observation.mostLikelyEntity;
    final bytes = List<int>.filled(CsdChromaticAddress.byteLength, 0);

    bytes[CsdChromaticChannel.x.index] = _quantizeSpatial(
      observation.pose.position.x,
      spatialOrigin.x,
      spatialExtent.x,
    );
    bytes[CsdChromaticChannel.y.index] = _quantizeSpatial(
      observation.pose.position.y,
      spatialOrigin.y,
      spatialExtent.y,
    );
    bytes[CsdChromaticChannel.z.index] = _quantizeSpatial(
      observation.pose.position.z,
      spatialOrigin.z,
      spatialExtent.z,
    );
    bytes[CsdChromaticChannel.visualHue.index] = visualHash.isNotEmpty
        ? visualHash[0]
        : _projectToByte(observation.visualEmbedding, 0x56495331);
    bytes[CsdChromaticChannel.visualStructure.index] = visualHash.length > 1
        ? visualHash[1]
        : _projectToByte(observation.visualEmbedding, 0x56495332);
    bytes[CsdChromaticChannel.semantic.index] = _projectToByte(
      observation.semanticEmbedding,
      0x53454d31,
    );
    bytes[CsdChromaticChannel.category.index] = likelyEntity.category == null
        ? _projectToByte(observation.semanticEmbedding, 0x53454d32)
        : _stableByte('category:${likelyEntity.category!.toLowerCase()}');
    bytes[CsdChromaticChannel.geometry.index] = _geometryByte(observation);
    bytes[CsdChromaticChannel.temporal.index] = _temporalByte(
      observation.observedAt,
    );
    bytes[CsdChromaticChannel.region.index] = _regionByte(observation.region);
    bytes[CsdChromaticChannel.aisle.index] = _ordinalOrHash(
      observation.region.aisleId,
      fallback: 128,
    );
    bytes[CsdChromaticChannel.floorShelf.index] = _floorShelfByte(
      observation.region,
    );
    return CsdChromaticAddress(bytes);
  }

  /// Computes contextual address distance with either a named profile or
  /// explicit normalized group weights.
  double distance(
    CsdChromaticAddress left,
    CsdChromaticAddress right, {
    CsdQueryProfile profile = CsdQueryProfile.balanced,
    CsdQueryWeights? weights,
    double exponent = 2,
  }) => left.distanceTo(
    right,
    weights: weights ?? CsdQueryWeights.forProfile(profile),
    exponent: exponent,
  );

  /// Produces bounded, deterministic single-channel probes around an address.
  ///
  /// This mitigates quantization-edge misses without creating the exponential
  /// Cartesian fan-out of every neighboring 12-dimensional cell.
  List<CsdChromaticAddress> neighboringAddresses(
    CsdChromaticAddress address, {
    Set<CsdChromaticChannel> channels = const <CsdChromaticChannel>{
      CsdChromaticChannel.x,
      CsdChromaticChannel.y,
      CsdChromaticChannel.z,
    },
    int radius = 1,
  }) {
    if (radius < 1 || radius > 8) {
      throw RangeError.range(radius, 1, 8, 'radius');
    }
    final orderedChannels = channels.toList(growable: false)
      ..sort((left, right) => left.index.compareTo(right.index));
    final result = <CsdChromaticAddress>[address];
    final source = address.bytes;
    for (final channel in orderedChannels) {
      for (var delta = 1; delta <= radius; delta++) {
        final lower = source[channel.index] - delta;
        if (lower >= 0) {
          final bytes = source.toList(growable: false);
          bytes[channel.index] = lower;
          result.add(CsdChromaticAddress(bytes));
        }
        final upper = source[channel.index] + delta;
        if (upper <= 255) {
          final bytes = source.toList(growable: false);
          bytes[channel.index] = upper;
          result.add(CsdChromaticAddress(bytes));
        }
      }
    }
    return List<CsdChromaticAddress>.unmodifiable(result);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'spatialOrigin': spatialOrigin.toJson(),
    'spatialExtent': spatialExtent.toJson(),
    'temporalEpoch': temporalEpoch.toIso8601String(),
    'temporalBucketMicros': temporalBucket.inMicroseconds,
  };

  factory CsdChromaticEncoder.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Unsupported CSD chromatic encoder format.');
    }
    final origin = json['spatialOrigin'];
    final extent = json['spatialExtent'];
    final epochValue = json['temporalEpoch'];
    final bucketValue = json['temporalBucketMicros'];
    if (origin is! Map || extent is! Map) {
      throw const FormatException('Encoder spatial bounds must be maps.');
    }
    if (origin.length > 8 || extent.length > 8) {
      throw const FormatException(
        'Encoder spatial bounds contain excess data.',
      );
    }
    if (epochValue is! String) {
      throw const FormatException('temporalEpoch must be an ISO-8601 string.');
    }
    final epoch = DateTime.tryParse(epochValue);
    if (epoch == null || !epoch.isUtc) {
      throw const FormatException(
        'temporalEpoch must contain an explicit UTC offset.',
      );
    }
    if (bucketValue is! int) {
      throw const FormatException('temporalBucketMicros must be an integer.');
    }
    try {
      return CsdChromaticEncoder(
        spatialOrigin: CsdVector3.fromJson(Map<String, dynamic>.from(origin)),
        spatialExtent: CsdVector3.fromJson(Map<String, dynamic>.from(extent)),
        temporalEpoch: epoch,
        temporalBucket: Duration(microseconds: bucketValue),
      );
    } on FormatException {
      rethrow;
    } on RangeError catch (error) {
      throw FormatException('Invalid CSD chromatic encoder: ${error.message}');
    } on ArgumentError catch (error) {
      throw FormatException('Invalid CSD chromatic encoder: ${error.message}');
    }
  }

  int _quantizeSpatial(double value, double origin, double extent) {
    final normalized = ((value - origin) / extent).clamp(0.0, 1.0);
    return (normalized * 255).round();
  }

  int _temporalByte(DateTime timestamp) {
    final differenceMicros = timestamp
        .toUtc()
        .difference(temporalEpoch)
        .inMicroseconds;
    if (differenceMicros <= 0) return 0;
    return (differenceMicros ~/ temporalBucket.inMicroseconds).clamp(0, 255);
  }

  static int _geometryByte(CsdObservation observation) {
    final entityClass = observation.mostLikelyEntity.entityClass.index.clamp(
      0,
      7,
    );
    final radius = observation.pose.covariance.uncertaintyRadius;
    final logScaled = ((math.log(radius + 1e-9) / math.ln10 + 6) / 12).clamp(
      0.0,
      1.0,
    );
    final uncertainty = (logScaled * 31).round();
    return ((entityClass << 5) | uncertainty).clamp(0, 255);
  }

  static int _regionByte(CsdRegionPath region) {
    if (region.zoneId != null) {
      return _ordinalOrHash(region.zoneId, fallback: 128);
    }
    return _stableByte(
      'region:${region.globalTile.toLowerCase()}/${region.structureId.toLowerCase()}',
    );
  }

  static int _floorShelfByte(CsdRegionPath region) {
    final floor = ((region.floorLevel ?? 0) + 4).clamp(0, 15);
    final shelf = _lowNibble(region.shelfId);
    return (floor << 4) | shelf;
  }

  static int _lowNibble(String? value) {
    if (value == null) return 0;
    final numeric = _lastInteger(value);
    return numeric == null ? _stableByte(value) & 0x0f : numeric.clamp(0, 15);
  }

  static int _ordinalOrHash(String? value, {required int fallback}) {
    if (value == null) return fallback;
    final numeric = _lastInteger(value);
    return numeric == null
        ? _stableByte(value.toLowerCase())
        : numeric.clamp(0, 255);
  }

  static int? _lastInteger(String value) {
    final matches = RegExp(r'-?\d+').allMatches(value).toList(growable: false);
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(0)!);
  }

  static int _stableByte(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    return ((hash >> 24) ^ (hash >> 16) ^ (hash >> 8) ^ hash) & 0xff;
  }

  static int _projectToByte(List<double> vector, int seed) {
    if (vector.isEmpty) return 128;
    var dot = 0.0;
    var vectorNormSquared = 0.0;
    var state = seed & 0xffffffff;
    for (var index = 0; index < vector.length; index++) {
      state = _xorshift32((state + index + 0x9e3779b9) & 0xffffffff);
      final coefficient = (state & 1) == 0 ? -1.0 : 1.0;
      dot += vector[index] * coefficient;
      vectorNormSquared += vector[index] * vector[index];
    }
    if (vectorNormSquared <= 1e-24) return 128;
    final cosine = (dot / math.sqrt(vectorNormSquared * vector.length)).clamp(
      -1.0,
      1.0,
    );
    return ((cosine + 1) * 127.5).round().clamp(0, 255);
  }

  static int _xorshift32(int value) {
    var state = value & 0xffffffff;
    state ^= (state << 13) & 0xffffffff;
    state ^= state >> 17;
    state ^= (state << 5) & 0xffffffff;
    return state & 0xffffffff;
  }

  @override
  bool operator ==(Object other) =>
      other is CsdChromaticEncoder &&
      spatialOrigin == other.spatialOrigin &&
      spatialExtent == other.spatialExtent &&
      temporalEpoch == other.temporalEpoch &&
      temporalBucket == other.temporalBucket;

  @override
  int get hashCode =>
      Object.hash(spatialOrigin, spatialExtent, temporalEpoch, temporalBucket);
}
