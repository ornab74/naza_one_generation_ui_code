// LLM-CONTEXT:BEGIN
// FILE: lib/memory/chromatic_spatial_models.dart
// ROLE: Defines immutable, bounded value objects for chromatic spatial memory.
// DOMAIN: local-memory
// SECURITY-INVARIANT: Treat observations as untrusted local evidence; keep every field bounded, finite, immutable, and safe to encrypt at rest.
// CHANGE-GUARD: Preserve format versions, strict validation, defensive copies, and fail-closed decoding; run analysis and focused tests after edits.
// DOCS: See /SECURITY.md, /docs/llm-context-schema.md, and /lib/memory/mermaid.md.
// LLM-CONTEXT:END
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Shared hard bounds for persisted Chromatic Spatial Database (CSD) values.
///
/// These are serialization and resource-safety limits, not statements about
/// sensor accuracy. Callers should normally use materially smaller values.
abstract final class CsdModelLimits {
  static const int maxIdCharacters = 160;
  static const int maxLabelCharacters = 240;
  static const int maxEntityCandidates = 8;
  static const int maxEmbeddingDimensions = 256;
  static const int maxPerceptualHashBytes = 64;
  static const int maxAttributes = 24;
  static const int maxMetadataEntries = 32;
  static const int maxMetadataDepth = 4;
  static const int maxMetadataNodes = 256;
  static const int maxMetadataStringCharacters = 2048;
  static const int maxMetadataListItems = 64;
  static const double maxCoordinateMagnitude = 10000000.0;
  static const double maxCovarianceMagnitude = 1000000000000.0;
  static const double maxEmbeddingComponentMagnitude = 1000000.0;
  static const int minHalfLifeMicroseconds = 1000;
  static const int maxHalfLifeMicroseconds =
      36525 * Duration.microsecondsPerDay;
  static const int maxTemporalUncertaintyMicroseconds =
      365 * Duration.microsecondsPerDay;
}

enum CsdObservationKind { presence, absence, move, layout }

enum CsdEntityClass { product, fixture, region, mobile, unknown }

enum CsdSensorType { camera, depth, lidar, barcode, user, import, unknown }

enum CsdQueryProfile { balanced, navigation, recognition, history }

/// The stable channel order in a 12-byte [CsdChromaticAddress].
enum CsdChromaticChannel {
  x,
  y,
  z,
  visualHue,
  visualStructure,
  semantic,
  category,
  geometry,
  temporal,
  region,
  aisle,
  floorShelf,
}

/// A finite, bounded three-dimensional coordinate in meters.
final class CsdVector3 {
  const CsdVector3._(this.x, this.y, this.z);

  factory CsdVector3(double x, double y, double z) {
    return CsdVector3._(
      _boundedDouble(
        x,
        'x',
        -CsdModelLimits.maxCoordinateMagnitude,
        CsdModelLimits.maxCoordinateMagnitude,
      ),
      _boundedDouble(
        y,
        'y',
        -CsdModelLimits.maxCoordinateMagnitude,
        CsdModelLimits.maxCoordinateMagnitude,
      ),
      _boundedDouble(
        z,
        'z',
        -CsdModelLimits.maxCoordinateMagnitude,
        CsdModelLimits.maxCoordinateMagnitude,
      ),
    );
  }

  static const CsdVector3 zero = CsdVector3._(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double distanceTo(CsdVector3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y, 'z': z};

  factory CsdVector3.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdVector3',
    () => CsdVector3(
      _requiredDouble(json, 'x'),
      _requiredDouble(json, 'y'),
      _requiredDouble(json, 'z'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdVector3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'CsdVector3($x, $y, $z)';
}

/// A normalized quaternion with a canonical sign.
///
/// Canonicalization makes `q` and `-q` serialize identically.
final class CsdQuaternion {
  const CsdQuaternion._(this.x, this.y, this.z, this.w);

  factory CsdQuaternion(double x, double y, double z, double w) {
    for (final entry in <MapEntry<String, double>>[
      MapEntry<String, double>('x', x),
      MapEntry<String, double>('y', y),
      MapEntry<String, double>('z', z),
      MapEntry<String, double>('w', w),
    ]) {
      _boundedDouble(
        entry.value,
        entry.key,
        -CsdModelLimits.maxCoordinateMagnitude,
        CsdModelLimits.maxCoordinateMagnitude,
      );
    }
    final normSquared = x * x + y * y + z * z + w * w;
    if (!normSquared.isFinite || normSquared <= 1e-24) {
      throw ArgumentError.value(
        <double>[x, y, z, w],
        'quaternion',
        'Quaternion norm must be finite and non-zero.',
      );
    }
    final inverseNorm = 1.0 / math.sqrt(normSquared);
    var nx = x * inverseNorm;
    var ny = y * inverseNorm;
    var nz = z * inverseNorm;
    var nw = w * inverseNorm;
    final flip =
        nw < 0 ||
        (nw == 0 && nz < 0) ||
        (nw == 0 && nz == 0 && ny < 0) ||
        (nw == 0 && nz == 0 && ny == 0 && nx < 0);
    if (flip) {
      nx = -nx;
      ny = -ny;
      nz = -nz;
      nw = -nw;
    }
    // Erase signed zero so equivalent rotations serialize identically.
    if (nx == 0) nx = 0;
    if (ny == 0) ny = 0;
    if (nz == 0) nz = 0;
    if (nw == 0) nw = 0;
    return CsdQuaternion._(nx, ny, nz, nw);
  }

  static const CsdQuaternion identity = CsdQuaternion._(0, 0, 0, 1);

  final double x;
  final double y;
  final double z;
  final double w;

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'z': z,
    'w': w,
  };

  factory CsdQuaternion.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdQuaternion',
    () => CsdQuaternion(
      _requiredDouble(json, 'x'),
      _requiredDouble(json, 'y'),
      _requiredDouble(json, 'z'),
      _requiredDouble(json, 'w'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdQuaternion &&
      x == other.x &&
      y == other.y &&
      z == other.z &&
      w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}

/// A symmetric, positive-semidefinite 3x3 position covariance matrix.
final class CsdCovariance3 {
  const CsdCovariance3._({
    required this.xx,
    required this.xy,
    required this.xz,
    required this.yy,
    required this.yz,
    required this.zz,
  });

  factory CsdCovariance3({
    required double xx,
    double xy = 0,
    double xz = 0,
    required double yy,
    double yz = 0,
    required double zz,
  }) {
    xx = _boundedDouble(xx, 'xx', 0, CsdModelLimits.maxCovarianceMagnitude);
    xy = _boundedDouble(
      xy,
      'xy',
      -CsdModelLimits.maxCovarianceMagnitude,
      CsdModelLimits.maxCovarianceMagnitude,
    );
    xz = _boundedDouble(
      xz,
      'xz',
      -CsdModelLimits.maxCovarianceMagnitude,
      CsdModelLimits.maxCovarianceMagnitude,
    );
    yy = _boundedDouble(yy, 'yy', 0, CsdModelLimits.maxCovarianceMagnitude);
    yz = _boundedDouble(
      yz,
      'yz',
      -CsdModelLimits.maxCovarianceMagnitude,
      CsdModelLimits.maxCovarianceMagnitude,
    );
    zz = _boundedDouble(zz, 'zz', 0, CsdModelLimits.maxCovarianceMagnitude);

    if (xx <= 0 || yy <= 0 || zz <= 0) {
      throw ArgumentError(
        'Covariance diagonal entries must be greater than zero.',
      );
    }
    final scale2 = math.max(1.0, math.max(xx * yy, math.max(xx * zz, yy * zz)));
    final tolerance2 = scale2 * 1e-12;
    if (xx * yy - xy * xy < -tolerance2 ||
        xx * zz - xz * xz < -tolerance2 ||
        yy * zz - yz * yz < -tolerance2) {
      throw ArgumentError('Covariance matrix is not positive semidefinite.');
    }
    final determinant =
        xx * (yy * zz - yz * yz) -
        xy * (xy * zz - yz * xz) +
        xz * (xy * yz - yy * xz);
    final tolerance3 = math.max(1.0, xx * yy * zz) * 1e-12;
    if (!determinant.isFinite || determinant < -tolerance3) {
      throw ArgumentError('Covariance matrix is not positive semidefinite.');
    }
    return CsdCovariance3._(xx: xx, xy: xy, xz: xz, yy: yy, yz: yz, zz: zz);
  }

  factory CsdCovariance3.isotropic(double variance) =>
      CsdCovariance3(xx: variance, yy: variance, zz: variance);

  final double xx;
  final double xy;
  final double xz;
  final double yy;
  final double yz;
  final double zz;

  double get meanVariance => (xx + yy + zz) / 3.0;
  double get uncertaintyRadius => math.sqrt(meanVariance);

  Map<String, Object?> toJson() => <String, Object?>{
    'xx': xx,
    'xy': xy,
    'xz': xz,
    'yy': yy,
    'yz': yz,
    'zz': zz,
  };

  factory CsdCovariance3.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdCovariance3',
    () => CsdCovariance3(
      xx: _requiredDouble(json, 'xx'),
      xy: _requiredDouble(json, 'xy'),
      xz: _requiredDouble(json, 'xz'),
      yy: _requiredDouble(json, 'yy'),
      yz: _requiredDouble(json, 'yz'),
      zz: _requiredDouble(json, 'zz'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdCovariance3 &&
      xx == other.xx &&
      xy == other.xy &&
      xz == other.xz &&
      yy == other.yy &&
      yz == other.yz &&
      zz == other.zz;

  @override
  int get hashCode => Object.hash(xx, xy, xz, yy, yz, zz);
}

final class CsdPose {
  const CsdPose._({
    required this.position,
    required this.orientation,
    required this.covariance,
  });

  factory CsdPose({
    required CsdVector3 position,
    required CsdQuaternion orientation,
    required CsdCovariance3 covariance,
  }) => CsdPose._(
    position: position,
    orientation: orientation,
    covariance: covariance,
  );

  final CsdVector3 position;
  final CsdQuaternion orientation;
  final CsdCovariance3 covariance;

  Map<String, Object?> toJson() => <String, Object?>{
    'position': position.toJson(),
    'orientation': orientation.toJson(),
    'covariance': covariance.toJson(),
  };

  factory CsdPose.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdPose',
    () => CsdPose(
      position: CsdVector3.fromJson(_requiredMap(json, 'position')),
      orientation: CsdQuaternion.fromJson(_requiredMap(json, 'orientation')),
      covariance: CsdCovariance3.fromJson(_requiredMap(json, 'covariance')),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdPose &&
      position == other.position &&
      orientation == other.orientation &&
      covariance == other.covariance;

  @override
  int get hashCode => Object.hash(position, orientation, covariance);
}

/// A strict physical hierarchy from global tile to shelf-local position.
final class CsdRegionPath {
  CsdRegionPath._({
    required this.globalTile,
    required this.structureId,
    required this.zoneId,
    required this.aisleId,
    required this.bayId,
    required this.shelfId,
    required this.floorLevel,
    required this.localPosition,
  });

  factory CsdRegionPath({
    required String globalTile,
    required String structureId,
    String? zoneId,
    String? aisleId,
    String? bayId,
    String? shelfId,
    int? floorLevel,
    double? localPosition,
  }) {
    final normalizedGlobal = _boundedString(
      globalTile,
      'globalTile',
      CsdModelLimits.maxIdCharacters,
    );
    final normalizedStructure = _boundedString(
      structureId,
      'structureId',
      CsdModelLimits.maxIdCharacters,
    );
    final normalizedZone = _optionalBoundedString(
      zoneId,
      'zoneId',
      CsdModelLimits.maxIdCharacters,
    );
    final normalizedAisle = _optionalBoundedString(
      aisleId,
      'aisleId',
      CsdModelLimits.maxIdCharacters,
    );
    final normalizedBay = _optionalBoundedString(
      bayId,
      'bayId',
      CsdModelLimits.maxIdCharacters,
    );
    final normalizedShelf = _optionalBoundedString(
      shelfId,
      'shelfId',
      CsdModelLimits.maxIdCharacters,
    );
    if (normalizedAisle != null && normalizedZone == null) {
      throw ArgumentError('aisleId requires zoneId.');
    }
    if (normalizedBay != null && normalizedAisle == null) {
      throw ArgumentError('bayId requires aisleId.');
    }
    if (normalizedShelf != null && normalizedBay == null) {
      throw ArgumentError('shelfId requires bayId.');
    }
    if (localPosition != null && normalizedShelf == null) {
      throw ArgumentError('localPosition requires shelfId.');
    }
    if (floorLevel != null && (floorLevel < -32 || floorLevel > 255)) {
      throw RangeError.range(floorLevel, -32, 255, 'floorLevel');
    }
    final checkedPosition = localPosition == null
        ? null
        : _boundedDouble(localPosition, 'localPosition', 0, 1);
    final normalizedPosition = checkedPosition == 0 ? 0.0 : checkedPosition;
    return CsdRegionPath._(
      globalTile: normalizedGlobal,
      structureId: normalizedStructure,
      zoneId: normalizedZone,
      aisleId: normalizedAisle,
      bayId: normalizedBay,
      shelfId: normalizedShelf,
      floorLevel: floorLevel,
      localPosition: normalizedPosition,
    );
  }

  final String globalTile;
  final String structureId;
  final String? zoneId;
  final String? aisleId;
  final String? bayId;
  final String? shelfId;
  final int? floorLevel;
  final double? localPosition;

  int get depth =>
      2 +
      (floorLevel == null ? 0 : 1) +
      (zoneId == null ? 0 : 1) +
      (aisleId == null ? 0 : 1) +
      (bayId == null ? 0 : 1) +
      (shelfId == null ? 0 : 1) +
      (localPosition == null ? 0 : 1);

  String get canonicalKey {
    final parts = <String>[
      'g=${Uri.encodeComponent(globalTile)}',
      's=${Uri.encodeComponent(structureId)}',
      if (floorLevel != null) 'f=$floorLevel',
      if (zoneId != null) 'z=${Uri.encodeComponent(zoneId!)}',
      if (aisleId != null) 'a=${Uri.encodeComponent(aisleId!)}',
      if (bayId != null) 'b=${Uri.encodeComponent(bayId!)}',
      if (shelfId != null) 'h=${Uri.encodeComponent(shelfId!)}',
      if (localPosition != null) 'p=${localPosition!.toString()}',
    ];
    return parts.join('/');
  }

  /// Whether this path is a semantic hierarchy prefix of [candidate].
  bool isPrefixOf(CsdRegionPath candidate) {
    return globalTile == candidate.globalTile &&
        structureId == candidate.structureId &&
        (floorLevel == null || floorLevel == candidate.floorLevel) &&
        (zoneId == null || zoneId == candidate.zoneId) &&
        (aisleId == null || aisleId == candidate.aisleId) &&
        (bayId == null || bayId == candidate.bayId) &&
        (shelfId == null || shelfId == candidate.shelfId) &&
        (localPosition == null || localPosition == candidate.localPosition);
  }

  bool matchesPrefix(CsdRegionPath prefix) => prefix.isPrefixOf(this);

  Map<String, Object?> toJson() => <String, Object?>{
    'globalTile': globalTile,
    'structureId': structureId,
    if (zoneId != null) 'zoneId': zoneId,
    if (aisleId != null) 'aisleId': aisleId,
    if (bayId != null) 'bayId': bayId,
    if (shelfId != null) 'shelfId': shelfId,
    if (floorLevel != null) 'floorLevel': floorLevel,
    if (localPosition != null) 'localPosition': localPosition,
  };

  factory CsdRegionPath.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdRegionPath',
    () => CsdRegionPath(
      globalTile: _requiredString(json, 'globalTile'),
      structureId: _requiredString(json, 'structureId'),
      zoneId: _optionalString(json, 'zoneId'),
      aisleId: _optionalString(json, 'aisleId'),
      bayId: _optionalString(json, 'bayId'),
      shelfId: _optionalString(json, 'shelfId'),
      floorLevel: _optionalInt(json, 'floorLevel'),
      localPosition: _optionalDouble(json, 'localPosition'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdRegionPath &&
      globalTile == other.globalTile &&
      structureId == other.structureId &&
      zoneId == other.zoneId &&
      aisleId == other.aisleId &&
      bayId == other.bayId &&
      shelfId == other.shelfId &&
      floorLevel == other.floorLevel &&
      localPosition == other.localPosition;

  @override
  int get hashCode => Object.hash(
    globalTile,
    structureId,
    zoneId,
    aisleId,
    bayId,
    shelfId,
    floorLevel,
    localPosition,
  );

  @override
  String toString() => canonicalKey;
}

final class CsdEntityCandidate {
  CsdEntityCandidate._({
    required this.entityId,
    required this.probability,
    required this.sku,
    required this.category,
    required this.brand,
    required this.entityClass,
    required this.attributes,
  });

  factory CsdEntityCandidate({
    required String entityId,
    required double probability,
    String? sku,
    String? category,
    String? brand,
    CsdEntityClass entityClass = CsdEntityClass.unknown,
    Map<String, String> attributes = const <String, String>{},
  }) {
    return CsdEntityCandidate._(
      entityId: _boundedString(
        entityId,
        'entityId',
        CsdModelLimits.maxIdCharacters,
      ),
      probability: _boundedDouble(
        probability,
        'probability',
        0,
        1,
        minOpen: true,
      ),
      sku: _optionalBoundedString(sku, 'sku', CsdModelLimits.maxIdCharacters),
      category: _optionalBoundedString(
        category,
        'category',
        CsdModelLimits.maxLabelCharacters,
      ),
      brand: _optionalBoundedString(
        brand,
        'brand',
        CsdModelLimits.maxLabelCharacters,
      ),
      entityClass: entityClass,
      attributes: _freezeStringMap(attributes),
    );
  }

  final String entityId;
  final double probability;
  final String? sku;
  final String? category;
  final String? brand;
  final CsdEntityClass entityClass;
  final Map<String, String> attributes;

  Map<String, Object?> toJson() => <String, Object?>{
    'entityId': entityId,
    'probability': probability,
    if (sku != null) 'sku': sku,
    if (category != null) 'category': category,
    if (brand != null) 'brand': brand,
    'entityClass': entityClass.name,
    if (attributes.isNotEmpty) 'attributes': attributes,
  };

  factory CsdEntityCandidate.fromJson(Map<String, dynamic> json) =>
      _decodeModel(
        'CsdEntityCandidate',
        () => CsdEntityCandidate(
          entityId: _requiredString(json, 'entityId'),
          probability: _requiredDouble(json, 'probability'),
          sku: _optionalString(json, 'sku'),
          category: _optionalString(json, 'category'),
          brand: _optionalString(json, 'brand'),
          entityClass: _requiredEnum(
            json,
            'entityClass',
            CsdEntityClass.values,
          ),
          attributes: _optionalStringMap(json, 'attributes'),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is CsdEntityCandidate &&
      entityId == other.entityId &&
      probability == other.probability &&
      sku == other.sku &&
      category == other.category &&
      brand == other.brand &&
      entityClass == other.entityClass &&
      _deepEquals(attributes, other.attributes);

  @override
  int get hashCode => Object.hash(
    entityId,
    probability,
    sku,
    category,
    brand,
    entityClass,
    _deepHash(attributes),
  );
}

final class CsdConfidence {
  const CsdConfidence._({
    required this.visual,
    required this.location,
    required this.temporal,
    required this.entity,
    required this.global,
  });

  factory CsdConfidence({
    required double visual,
    required double location,
    required double temporal,
    required double entity,
    required double global,
  }) => CsdConfidence._(
    visual: _unitDouble(visual, 'visual'),
    location: _unitDouble(location, 'location'),
    temporal: _unitDouble(temporal, 'temporal'),
    entity: _unitDouble(entity, 'entity'),
    global: _unitDouble(global, 'global'),
  );

  final double visual;
  final double location;
  final double temporal;
  final double entity;
  final double global;

  /// Geometric mean: one unsupported evidence channel cannot be hidden by
  /// several high-confidence channels.
  double get aggregate {
    final product = visual * location * temporal * entity * global;
    return product <= 0 ? 0 : math.pow(product, 0.2).toDouble();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'visual': visual,
    'location': location,
    'temporal': temporal,
    'entity': entity,
    'global': global,
  };

  factory CsdConfidence.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdConfidence',
    () => CsdConfidence(
      visual: _requiredDouble(json, 'visual'),
      location: _requiredDouble(json, 'location'),
      temporal: _requiredDouble(json, 'temporal'),
      entity: _requiredDouble(json, 'entity'),
      global: _requiredDouble(json, 'global'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdConfidence &&
      visual == other.visual &&
      location == other.location &&
      temporal == other.temporal &&
      entity == other.entity &&
      global == other.global;

  @override
  int get hashCode => Object.hash(visual, location, temporal, entity, global);
}

final class CsdProvenance {
  const CsdProvenance._({
    required this.sensorId,
    required this.sensorType,
    required this.sessionId,
    required this.correlationGroup,
    required this.reliability,
    required this.modelVersion,
  });

  factory CsdProvenance({
    required String sensorId,
    required CsdSensorType sensorType,
    required String sessionId,
    required String correlationGroup,
    required double reliability,
    String? modelVersion,
  }) => CsdProvenance._(
    sensorId: _boundedString(
      sensorId,
      'sensorId',
      CsdModelLimits.maxIdCharacters,
    ),
    sensorType: sensorType,
    sessionId: _boundedString(
      sessionId,
      'sessionId',
      CsdModelLimits.maxIdCharacters,
    ),
    correlationGroup: _boundedString(
      correlationGroup,
      'correlationGroup',
      CsdModelLimits.maxIdCharacters,
    ),
    reliability: _unitDouble(reliability, 'reliability'),
    modelVersion: _optionalBoundedString(
      modelVersion,
      'modelVersion',
      CsdModelLimits.maxLabelCharacters,
    ),
  );

  final String sensorId;
  final CsdSensorType sensorType;
  final String sessionId;
  final String correlationGroup;
  final double reliability;
  final String? modelVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'sensorId': sensorId,
    'sensorType': sensorType.name,
    'sessionId': sessionId,
    'correlationGroup': correlationGroup,
    'reliability': reliability,
    if (modelVersion != null) 'modelVersion': modelVersion,
  };

  factory CsdProvenance.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdProvenance',
    () => CsdProvenance(
      sensorId: _requiredString(json, 'sensorId'),
      sensorType: _requiredEnum(json, 'sensorType', CsdSensorType.values),
      sessionId: _requiredString(json, 'sessionId'),
      correlationGroup: _requiredString(json, 'correlationGroup'),
      reliability: _requiredDouble(json, 'reliability'),
      modelVersion: _optionalString(json, 'modelVersion'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is CsdProvenance &&
      sensorId == other.sensorId &&
      sensorType == other.sensorType &&
      sessionId == other.sessionId &&
      correlationGroup == other.correlationGroup &&
      reliability == other.reliability &&
      modelVersion == other.modelVersion;

  @override
  int get hashCode => Object.hash(
    sensorId,
    sensorType,
    sessionId,
    correlationGroup,
    reliability,
    modelVersion,
  );
}

/// An immutable, uncertain observation of physical reality.
final class CsdObservation {
  CsdObservation._({
    required this.id,
    required this.kind,
    required this.entities,
    required this.pose,
    required this.region,
    required this.observedAt,
    required this.temporalUncertainty,
    required this.halfLife,
    required this.confidence,
    required this.provenance,
    required List<double> semanticEmbedding,
    required List<double> visualEmbedding,
    required Uint8List perceptualHash,
    required this.metadata,
  }) : _semanticEmbedding = semanticEmbedding,
       _visualEmbedding = visualEmbedding,
       _perceptualHash = perceptualHash;

  factory CsdObservation({
    required String id,
    required CsdObservationKind kind,
    required List<CsdEntityCandidate> entities,
    required CsdPose pose,
    required CsdRegionPath region,
    required DateTime observedAt,
    Duration temporalUncertainty = Duration.zero,
    required Duration halfLife,
    required CsdConfidence confidence,
    required CsdProvenance provenance,
    List<double> semanticEmbedding = const <double>[],
    List<double> visualEmbedding = const <double>[],
    List<int> perceptualHash = const <int>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    if (entities.isEmpty ||
        entities.length > CsdModelLimits.maxEntityCandidates) {
      throw RangeError.range(
        entities.length,
        1,
        CsdModelLimits.maxEntityCandidates,
        'entities.length',
      );
    }
    final frozenEntities = List<CsdEntityCandidate>.unmodifiable(entities);
    final entityIds = <String>{};
    var probabilityMass = 0.0;
    for (final entity in frozenEntities) {
      if (!entityIds.add(entity.entityId)) {
        throw ArgumentError.value(
          entity.entityId,
          'entities',
          'Entity candidate IDs must be unique.',
        );
      }
      probabilityMass += entity.probability;
    }
    if (probabilityMass > 1.000000001) {
      throw ArgumentError.value(
        probabilityMass,
        'entities',
        'Entity candidate probability mass must not exceed 1.',
      );
    }
    final utcObservedAt = observedAt.toUtc();
    if (utcObservedAt.year < 1970 || utcObservedAt.year > 9999) {
      throw RangeError.range(utcObservedAt.year, 1970, 9999, 'observedAt.year');
    }
    if (temporalUncertainty.isNegative ||
        temporalUncertainty.inMicroseconds >
            CsdModelLimits.maxTemporalUncertaintyMicroseconds) {
      throw RangeError.range(
        temporalUncertainty.inMicroseconds,
        0,
        CsdModelLimits.maxTemporalUncertaintyMicroseconds,
        'temporalUncertainty.inMicroseconds',
      );
    }
    if (halfLife.inMicroseconds < CsdModelLimits.minHalfLifeMicroseconds ||
        halfLife.inMicroseconds > CsdModelLimits.maxHalfLifeMicroseconds) {
      throw RangeError.range(
        halfLife.inMicroseconds,
        CsdModelLimits.minHalfLifeMicroseconds,
        CsdModelLimits.maxHalfLifeMicroseconds,
        'halfLife.inMicroseconds',
      );
    }
    return CsdObservation._(
      id: _boundedString(id, 'id', CsdModelLimits.maxIdCharacters),
      kind: kind,
      entities: frozenEntities,
      pose: pose,
      region: region,
      observedAt: utcObservedAt,
      temporalUncertainty: temporalUncertainty,
      halfLife: halfLife,
      confidence: confidence,
      provenance: provenance,
      semanticEmbedding: _freezeEmbedding(
        semanticEmbedding,
        'semanticEmbedding',
      ),
      visualEmbedding: _freezeEmbedding(visualEmbedding, 'visualEmbedding'),
      perceptualHash: _freezeBytes(
        perceptualHash,
        'perceptualHash',
        CsdModelLimits.maxPerceptualHashBytes,
      ),
      metadata: _freezeMetadata(metadata),
    );
  }

  static const String format = 'naza-csd-observation-v1';

  final String id;
  final CsdObservationKind kind;
  final List<CsdEntityCandidate> entities;
  final CsdPose pose;
  final CsdRegionPath region;
  final DateTime observedAt;
  final Duration temporalUncertainty;
  final Duration halfLife;
  final CsdConfidence confidence;
  final CsdProvenance provenance;
  final List<double> _semanticEmbedding;
  final List<double> _visualEmbedding;
  final Uint8List _perceptualHash;
  final Map<String, Object?> metadata;

  List<double> get semanticEmbedding => _semanticEmbedding;
  List<double> get visualEmbedding => _visualEmbedding;
  Uint8List get perceptualHash => Uint8List.fromList(_perceptualHash);
  double get entityProbabilityMass =>
      entities.fold<double>(0, (sum, entity) => sum + entity.probability);

  CsdEntityCandidate get mostLikelyEntity {
    var best = entities.first;
    for (final candidate in entities.skip(1)) {
      if (candidate.probability > best.probability ||
          (candidate.probability == best.probability &&
              candidate.entityId.compareTo(best.entityId) < 0)) {
        best = candidate;
      }
    }
    return best;
  }

  double freshnessAt(DateTime time) {
    final ageMicros = math.max(
      0,
      time.toUtc().difference(observedAt).inMicroseconds,
    );
    return math.pow(0.5, ageMicros / halfLife.inMicroseconds).toDouble();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'id': id,
    'kind': kind.name,
    'entities': entities
        .map((entity) => entity.toJson())
        .toList(growable: false),
    'pose': pose.toJson(),
    'region': region.toJson(),
    'observedAt': observedAt.toIso8601String(),
    'temporalUncertaintyMicros': temporalUncertainty.inMicroseconds,
    'halfLifeMicros': halfLife.inMicroseconds,
    'confidence': confidence.toJson(),
    'provenance': provenance.toJson(),
    'semanticEmbedding': _semanticEmbedding,
    'visualEmbedding': _visualEmbedding,
    'perceptualHash': _bytesToHex(_perceptualHash),
    'metadata': metadata,
  };

  factory CsdObservation.fromJson(Map<String, dynamic> json) => _decodeModel(
    'CsdObservation',
    () {
      if (json['format'] != format) {
        throw const FormatException('Unsupported CSD observation format.');
      }
      final rawEntities = json['entities'];
      if (rawEntities is! List) {
        throw const FormatException('entities must be a list.');
      }
      if (rawEntities.isEmpty ||
          rawEntities.length > CsdModelLimits.maxEntityCandidates) {
        throw const FormatException('entities has an invalid length.');
      }
      final observedAtValue = json['observedAt'];
      if (observedAtValue is! String) {
        throw const FormatException('observedAt must be an ISO-8601 string.');
      }
      final parsedObservedAt = DateTime.tryParse(observedAtValue);
      if (parsedObservedAt == null || !parsedObservedAt.isUtc) {
        throw const FormatException(
          'observedAt must contain an explicit UTC offset.',
        );
      }
      return CsdObservation(
        id: _requiredString(json, 'id'),
        kind: _requiredEnum(json, 'kind', CsdObservationKind.values),
        entities: rawEntities
            .map((value) {
              if (value is! Map) {
                throw const FormatException('Invalid entity candidate.');
              }
              if (value.length > 16) {
                throw const FormatException(
                  'Entity candidate contains excess data.',
                );
              }
              return CsdEntityCandidate.fromJson(
                Map<String, dynamic>.from(value),
              );
            })
            .toList(growable: false),
        pose: CsdPose.fromJson(_requiredMap(json, 'pose')),
        region: CsdRegionPath.fromJson(_requiredMap(json, 'region')),
        observedAt: parsedObservedAt.toUtc(),
        temporalUncertainty: Duration(
          microseconds: _requiredInt(json, 'temporalUncertaintyMicros'),
        ),
        halfLife: Duration(microseconds: _requiredInt(json, 'halfLifeMicros')),
        confidence: CsdConfidence.fromJson(_requiredMap(json, 'confidence')),
        provenance: CsdProvenance.fromJson(_requiredMap(json, 'provenance')),
        semanticEmbedding: _requiredDoubleList(
          json,
          'semanticEmbedding',
          maximumLength: CsdModelLimits.maxEmbeddingDimensions,
        ),
        visualEmbedding: _requiredDoubleList(
          json,
          'visualEmbedding',
          maximumLength: CsdModelLimits.maxEmbeddingDimensions,
        ),
        perceptualHash: _requiredHexBytes(
          json,
          'perceptualHash',
          maximumBytes: CsdModelLimits.maxPerceptualHashBytes,
        ),
        metadata: _requiredObjectMap(
          json,
          'metadata',
          maximumEntries: CsdModelLimits.maxMetadataEntries,
        ),
      );
    },
  );

  @override
  bool operator ==(Object other) =>
      other is CsdObservation &&
      id == other.id &&
      kind == other.kind &&
      _listEquals(entities, other.entities) &&
      pose == other.pose &&
      region == other.region &&
      observedAt == other.observedAt &&
      temporalUncertainty == other.temporalUncertainty &&
      halfLife == other.halfLife &&
      confidence == other.confidence &&
      provenance == other.provenance &&
      _listEquals(_semanticEmbedding, other._semanticEmbedding) &&
      _listEquals(_visualEmbedding, other._visualEmbedding) &&
      _listEquals(_perceptualHash, other._perceptualHash) &&
      _deepEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    Object.hashAll(entities),
    pose,
    region,
    observedAt,
    temporalUncertainty,
    halfLife,
    confidence,
    provenance,
    Object.hashAll(_semanticEmbedding),
    Object.hashAll(_visualEmbedding),
    Object.hashAll(_perceptualHash),
    _deepHash(metadata),
  );
}

/// A compact 96-bit address in perceptual-spatial state.
final class CsdChromaticAddress implements Comparable<CsdChromaticAddress> {
  CsdChromaticAddress._(this._bytes);

  factory CsdChromaticAddress(List<int> bytes) {
    return CsdChromaticAddress._(
      _freezeBytes(bytes, 'bytes', byteLength, exactLength: byteLength),
    );
  }

  factory CsdChromaticAddress.fromHex(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.length != byteLength * 2 ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(normalized)) {
      throw FormatException(
        'A chromatic address must be exactly ${byteLength * 2} hex characters.',
      );
    }
    return CsdChromaticAddress(_hexToBytes(normalized));
  }

  static const String format = 'naza-csd-chromatic-address-v1';
  static const int byteLength = 12;

  final Uint8List _bytes;

  Uint8List get bytes => Uint8List.fromList(_bytes);
  String get hex => _bytesToHex(_bytes);

  int operator [](CsdChromaticChannel channel) => _bytes[channel.index];

  String prefixHex(int byteCount) {
    if (byteCount < 0 || byteCount > byteLength) {
      throw RangeError.range(byteCount, 0, byteLength, 'byteCount');
    }
    return _bytesToHex(_bytes.sublist(0, byteCount));
  }

  /// Weighted normalized Minkowski distance in the range 0...1.
  ///
  /// Hue is circular, so 0 and 255 remain near one another. Missing dimensions
  /// should be suppressed by setting their query group weight to zero.
  double distanceTo(
    CsdChromaticAddress other, {
    required CsdQueryWeights weights,
    double exponent = 2,
  }) {
    exponent = _boundedDouble(exponent, 'exponent', 1, 4);
    final channels = weights.channelWeights;
    var sum = 0.0;
    for (var index = 0; index < byteLength; index++) {
      final rawDifference = (_bytes[index] - other._bytes[index]).abs();
      final difference = index == CsdChromaticChannel.visualHue.index
          ? math.min(rawDifference, 256 - rawDifference) / 128.0
          : rawDifference / 255.0;
      sum += channels[index] * math.pow(difference, exponent);
    }
    return math.pow(sum, 1.0 / exponent).toDouble().clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'hex': hex,
  };

  factory CsdChromaticAddress.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Unsupported chromatic address format.');
    }
    return CsdChromaticAddress.fromHex(_requiredString(json, 'hex'));
  }

  @override
  int compareTo(CsdChromaticAddress other) {
    for (var index = 0; index < byteLength; index++) {
      final comparison = _bytes[index].compareTo(other._bytes[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is CsdChromaticAddress && _listEquals(_bytes, other._bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => hex;
}

/// Contextual group weights expanded deterministically across 12 channels.
final class CsdQueryWeights {
  CsdQueryWeights._({
    required this.spatial,
    required this.visual,
    required this.semantic,
    required this.geometry,
    required this.temporal,
    required this.hierarchy,
  });

  factory CsdQueryWeights({
    double spatial = 0.24,
    double visual = 0.20,
    double semantic = 0.20,
    double geometry = 0.08,
    double temporal = 0.12,
    double hierarchy = 0.16,
  }) {
    final values = <double>[
      _nonNegativeFinite(spatial, 'spatial'),
      _nonNegativeFinite(visual, 'visual'),
      _nonNegativeFinite(semantic, 'semantic'),
      _nonNegativeFinite(geometry, 'geometry'),
      _nonNegativeFinite(temporal, 'temporal'),
      _nonNegativeFinite(hierarchy, 'hierarchy'),
    ];
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 1e-15) {
      throw ArgumentError('At least one CSD query weight must be positive.');
    }
    final normalization = (total - 1).abs() <= 1e-12 ? 1.0 : total;
    return CsdQueryWeights._(
      spatial: values[0] / normalization,
      visual: values[1] / normalization,
      semantic: values[2] / normalization,
      geometry: values[3] / normalization,
      temporal: values[4] / normalization,
      hierarchy: values[5] / normalization,
    );
  }

  factory CsdQueryWeights.forProfile(CsdQueryProfile profile) =>
      switch (profile) {
        CsdQueryProfile.balanced => CsdQueryWeights(),
        CsdQueryProfile.navigation => CsdQueryWeights(
          spatial: 0.42,
          visual: 0.06,
          semantic: 0.08,
          geometry: 0.09,
          temporal: 0.12,
          hierarchy: 0.23,
        ),
        CsdQueryProfile.recognition => CsdQueryWeights(
          spatial: 0.08,
          visual: 0.36,
          semantic: 0.30,
          geometry: 0.10,
          temporal: 0.04,
          hierarchy: 0.12,
        ),
        CsdQueryProfile.history => CsdQueryWeights(
          spatial: 0.14,
          visual: 0.08,
          semantic: 0.13,
          geometry: 0.05,
          temporal: 0.45,
          hierarchy: 0.15,
        ),
      };

  static const String format = 'naza-csd-query-weights-v1';

  final double spatial;
  final double visual;
  final double semantic;
  final double geometry;
  final double temporal;
  final double hierarchy;

  List<double> get channelWeights => List<double>.unmodifiable(<double>[
    spatial / 3,
    spatial / 3,
    spatial / 3,
    visual / 2,
    visual / 2,
    semantic / 2,
    semantic / 2,
    geometry,
    temporal,
    hierarchy / 3,
    hierarchy / 3,
    hierarchy / 3,
  ]);

  double weightFor(CsdChromaticChannel channel) =>
      channelWeights[channel.index];

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'spatial': spatial,
    'visual': visual,
    'semantic': semantic,
    'geometry': geometry,
    'temporal': temporal,
    'hierarchy': hierarchy,
  };

  factory CsdQueryWeights.fromJson(Map<String, dynamic> json) =>
      _decodeModel('CsdQueryWeights', () {
        if (json['format'] != format) {
          throw const FormatException('Unsupported CSD query-weight format.');
        }
        return CsdQueryWeights(
          spatial: _requiredDouble(json, 'spatial'),
          visual: _requiredDouble(json, 'visual'),
          semantic: _requiredDouble(json, 'semantic'),
          geometry: _requiredDouble(json, 'geometry'),
          temporal: _requiredDouble(json, 'temporal'),
          hierarchy: _requiredDouble(json, 'hierarchy'),
        );
      });

  @override
  bool operator ==(Object other) =>
      other is CsdQueryWeights &&
      spatial == other.spatial &&
      visual == other.visual &&
      semantic == other.semantic &&
      geometry == other.geometry &&
      temporal == other.temporal &&
      hierarchy == other.hierarchy;

  @override
  int get hashCode =>
      Object.hash(spatial, visual, semantic, geometry, temporal, hierarchy);
}

double _boundedDouble(
  double value,
  String name,
  double minimum,
  double maximum, {
  bool minOpen = false,
}) {
  if (!value.isFinite ||
      (minOpen ? value <= minimum : value < minimum) ||
      value > maximum) {
    throw RangeError.value(
      value,
      name,
      'Expected a finite value in ${minOpen ? '(' : '['}$minimum, $maximum].',
    );
  }
  return value;
}

double _unitDouble(double value, String name) =>
    _boundedDouble(value, name, 0, 1);

double _nonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1000000) {
    throw RangeError.range(value, 0, 1000000, name);
  }
  return value;
}

String _boundedString(String value, String name, int maxCharacters) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxCharacters) {
    throw RangeError.range(normalized.length, 1, maxCharacters, '$name.length');
  }
  if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Control characters are not allowed.',
    );
  }
  return normalized;
}

String? _optionalBoundedString(String? value, String name, int maxCharacters) =>
    value == null ? null : _boundedString(value, name, maxCharacters);

Map<String, String> _freezeStringMap(Map<String, String> value) {
  if (value.length > CsdModelLimits.maxAttributes) {
    throw RangeError.range(
      value.length,
      0,
      CsdModelLimits.maxAttributes,
      'attributes.length',
    );
  }
  final sorted = SplayTreeMap<String, String>();
  for (final entry in value.entries) {
    final key = _boundedString(entry.key, 'attribute key', 64);
    final item = _boundedString(
      entry.value,
      'attribute value',
      CsdModelLimits.maxLabelCharacters,
    );
    if (sorted.containsKey(key)) {
      throw ArgumentError.value(
        entry.key,
        'attributes',
        'Attribute keys must remain unique after normalization.',
      );
    }
    sorted[key] = item;
  }
  return Map<String, String>.unmodifiable(sorted);
}

List<double> _freezeEmbedding(List<double> value, String name) {
  if (value.length > CsdModelLimits.maxEmbeddingDimensions) {
    throw RangeError.range(
      value.length,
      0,
      CsdModelLimits.maxEmbeddingDimensions,
      '$name.length',
    );
  }
  final copy = <double>[];
  for (var index = 0; index < value.length; index++) {
    copy.add(
      _boundedDouble(
        value[index],
        '$name[$index]',
        -CsdModelLimits.maxEmbeddingComponentMagnitude,
        CsdModelLimits.maxEmbeddingComponentMagnitude,
      ),
    );
  }
  return List<double>.unmodifiable(copy);
}

Uint8List _freezeBytes(
  List<int> value,
  String name,
  int maximumLength, {
  int? exactLength,
}) {
  if ((exactLength != null && value.length != exactLength) ||
      value.length > maximumLength) {
    throw RangeError.range(
      value.length,
      exactLength ?? 0,
      exactLength ?? maximumLength,
      '$name.length',
    );
  }
  for (var index = 0; index < value.length; index++) {
    final byte = value[index];
    if (byte < 0 || byte > 255) {
      throw RangeError.range(byte, 0, 255, '$name[$index]');
    }
  }
  return Uint8List.fromList(value);
}

Map<String, Object?> _freezeMetadata(Map<String, Object?> value) {
  if (value.length > CsdModelLimits.maxMetadataEntries) {
    throw RangeError.range(
      value.length,
      0,
      CsdModelLimits.maxMetadataEntries,
      'metadata.length',
    );
  }
  final budget = _JsonBudget();
  return _freezeJsonMap(value, 0, budget);
}

Map<String, Object?> _freezeJsonMap(
  Map<String, Object?> value,
  int depth,
  _JsonBudget budget,
) {
  if (depth > CsdModelLimits.maxMetadataDepth) {
    throw ArgumentError('Metadata nesting is too deep.');
  }
  if (value.length > CsdModelLimits.maxMetadataEntries) {
    throw ArgumentError('A metadata map has too many entries.');
  }
  final sorted = SplayTreeMap<String, Object?>();
  for (final entry in value.entries) {
    budget.consume();
    final key = _boundedString(entry.key, 'metadata key', 64);
    if (sorted.containsKey(key)) {
      throw ArgumentError.value(
        entry.key,
        'metadata',
        'Metadata keys must remain unique after normalization.',
      );
    }
    sorted[key] = _freezeJsonValue(entry.value, depth + 1, budget);
  }
  return Map<String, Object?>.unmodifiable(sorted);
}

Object? _freezeJsonValue(Object? value, int depth, _JsonBudget budget) {
  if (depth > CsdModelLimits.maxMetadataDepth) {
    throw ArgumentError('Metadata nesting is too deep.');
  }
  budget.consume();
  if (value == null || value is bool) return value;
  if (value is String) {
    if (value.length > CsdModelLimits.maxMetadataStringCharacters ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(value)) {
      throw ArgumentError('Metadata contains an invalid or oversized string.');
    }
    return value;
  }
  if (value is num) {
    final doubleValue = value.toDouble();
    if (!doubleValue.isFinite || doubleValue.abs() > 1000000000000000) {
      throw ArgumentError('Metadata numbers must be finite and bounded.');
    }
    return value;
  }
  if (value is List) {
    if (value.length > CsdModelLimits.maxMetadataListItems) {
      throw ArgumentError('A metadata list has too many items.');
    }
    return List<Object?>.unmodifiable(
      value.map((item) => _freezeJsonValue(item, depth + 1, budget)),
    );
  }
  if (value is Map) {
    final converted = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('Metadata map keys must be strings.');
      }
      converted[entry.key as String] = entry.value;
    }
    return _freezeJsonMap(converted, depth + 1, budget);
  }
  throw ArgumentError.value(
    value.runtimeType,
    'metadata',
    'Only JSON-compatible metadata is supported.',
  );
}

final class _JsonBudget {
  int _nodes = 0;

  void consume() {
    _nodes++;
    if (_nodes > CsdModelLimits.maxMetadataNodes) {
      throw ArgumentError('Metadata has too many nested values.');
    }
  }
}

T _decodeModel<T>(String modelName, T Function() operation) {
  try {
    return operation();
  } on FormatException {
    rethrow;
  } on RangeError catch (error) {
    throw FormatException('Invalid $modelName: ${error.message}');
  } on ArgumentError catch (error) {
    throw FormatException('Invalid $modelName: ${error.message}');
  } on TypeError catch (error) {
    throw FormatException('Invalid $modelName: $error');
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be a map.');
  if (value.length > CsdModelLimits.maxMetadataEntries) {
    throw FormatException('$key contains excess data.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, Object?> _requiredObjectMap(
  Map<String, dynamic> json,
  String key, {
  required int maximumEntries,
}) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be a map.');
  if (value.length > maximumEntries) {
    throw FormatException('$key has too many entries.');
  }
  return Map<String, Object?>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  final converted = value.toDouble();
  if (!converted.isFinite) throw FormatException('$key must be finite.');
  return converted;
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return _requiredDouble(json, key);
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return _requiredInt(json, key);
}

List<double> _requiredDoubleList(
  Map<String, dynamic> json,
  String key, {
  required int maximumLength,
}) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list.');
  if (value.length > maximumLength) {
    throw FormatException('$key has too many values.');
  }
  return value
      .map((item) {
        if (item is! num || !item.toDouble().isFinite) {
          throw FormatException('$key contains a non-finite number.');
        }
        return item.toDouble();
      })
      .toList(growable: false);
}

Map<String, String> _optionalStringMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const <String, String>{};
  if (value is! Map) throw FormatException('$key must be a map.');
  if (value.length > CsdModelLimits.maxAttributes) {
    throw FormatException('$key has too many entries.');
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw FormatException('$key must contain only string keys and values.');
    }
    result[entry.key as String] = entry.value as String;
  }
  return result;
}

T _requiredEnum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = _requiredString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unsupported $key value: $name.');
}

String _bytesToHex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

List<int> _requiredHexBytes(
  Map<String, dynamic> json,
  String key, {
  required int maximumBytes,
}) {
  final value = _requiredString(json, key);
  if (value.length > maximumBytes * 2) {
    throw FormatException('$key has too many bytes.');
  }
  return _hexToBytes(value);
}

List<int> _hexToBytes(String value) {
  if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(value)) {
    throw const FormatException('Invalid hexadecimal byte string.');
  }
  return List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
    growable: false,
  );
}

bool _listEquals(List<Object?> left, List<Object?> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_deepEquals(left[index], right[index])) return false;
  }
  return true;
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List) {
    return _listEquals(left.cast<Object?>(), right.cast<Object?>());
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_deepHash));
  if (value is Map) {
    final entries = value.entries.toList(growable: false)
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return Object.hashAll(
      entries.map(
        (entry) => Object.hash(_deepHash(entry.key), _deepHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}
