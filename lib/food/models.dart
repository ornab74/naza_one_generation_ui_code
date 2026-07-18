import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum FoodConfidence {
  low,
  medium,
  high;

  String get label => switch (this) {
    FoodConfidence.low => 'Low',
    FoodConfidence.medium => 'Medium',
    FoodConfidence.high => 'High',
  };

  static FoodConfidence parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'high' => FoodConfidence.high,
      'medium' => FoodConfidence.medium,
      _ => FoodConfidence.low,
    };
  }
}

enum FoodAnalysisStatus { complete, partial, failed, cancelled }

final class FoodVisionImage {
  final Uint8List bytes;
  final String name;
  final int width;
  final int height;

  const FoodVisionImage({
    required this.bytes,
    required this.name,
    required this.width,
    required this.height,
  });

  String get dimensions => '$width × $height';

  Map<String, Object?> toJson() => <String, Object?>{
    'bytes': base64Encode(bytes),
    'name': name,
    'width': width,
    'height': height,
  };

  factory FoodVisionImage.fromJson(Map<String, Object?> json) {
    return FoodVisionImage(
      bytes: base64Decode(json['bytes']?.toString() ?? ''),
      name: _bounded(json['name'], 180, fallback: 'food-image.png'),
      width: _int(json['width']).clamp(1, 10000),
      height: _int(json['height']).clamp(1, 10000),
    );
  }
}

final class FridgeItemObservation {
  final String name;
  final String approximateQuantity;
  final String location;
  final List<String> visibleCues;
  final String useWindow;
  final FoodConfidence confidence;

  const FridgeItemObservation({
    required this.name,
    required this.approximateQuantity,
    required this.location,
    required this.visibleCues,
    required this.useWindow,
    required this.confidence,
  });

  factory FridgeItemObservation.fromJson(Map<String, Object?> json) {
    return FridgeItemObservation(
      name: _bounded(json['name'], 120, fallback: 'Unidentified item'),
      approximateQuantity: _bounded(
        json['approximate_quantity'],
        100,
        fallback: 'Quantity unclear',
      ),
      location: _bounded(json['location'], 100, fallback: 'Location unclear'),
      visibleCues: _stringList(
        json['visible_cues'],
        maxItems: 5,
        maxChars: 180,
      ),
      useWindow: _bounded(
        json['use_window'],
        100,
        fallback: 'Verify label and condition',
      ),
      confidence: FoodConfidence.parse(json['confidence']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'approximate_quantity': approximateQuantity,
    'location': location,
    'visible_cues': visibleCues,
    'use_window': useWindow,
    'confidence': confidence.name,
  };
}

final class IngredientSuggestion {
  final String name;
  final String reason;
  final String priority;

  const IngredientSuggestion({
    required this.name,
    required this.reason,
    required this.priority,
  });

  factory IngredientSuggestion.fromJson(Map<String, Object?> json) {
    final rawPriority = json['priority']?.toString().trim().toLowerCase();
    return IngredientSuggestion(
      name: _bounded(json['name'], 120, fallback: 'Ingredient'),
      reason: _bounded(
        json['reason'],
        240,
        fallback: 'Complements visible items',
      ),
      priority: const {'low', 'medium', 'high'}.contains(rawPriority)
          ? rawPriority!
          : 'medium',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'reason': reason,
    'priority': priority,
  };
}

final class RecipeSuggestion {
  final String title;
  final List<String> usesVisibleItems;
  final List<String> missingIngredients;
  final List<String> steps;
  final int estimatedMinutes;
  final String verificationNote;

  const RecipeSuggestion({
    required this.title,
    required this.usesVisibleItems,
    required this.missingIngredients,
    required this.steps,
    required this.estimatedMinutes,
    required this.verificationNote,
  });

  factory RecipeSuggestion.fromJson(Map<String, Object?> json) {
    return RecipeSuggestion(
      title: _bounded(json['title'], 160, fallback: 'Flexible fridge meal'),
      usesVisibleItems: _stringList(
        json['uses_visible_items'],
        maxItems: 12,
        maxChars: 120,
      ),
      missingIngredients: _stringList(
        json['missing_ingredients'],
        maxItems: 10,
        maxChars: 120,
      ),
      steps: _stringList(json['steps'], maxItems: 8, maxChars: 320),
      estimatedMinutes: _int(json['estimated_minutes']).clamp(0, 1440),
      verificationNote: _bounded(
        json['verification_note'],
        260,
        fallback:
            'Verify labels, freshness, allergens, and safe cooking temperatures.',
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'uses_visible_items': usesVisibleItems,
    'missing_ingredients': missingIngredients,
    'steps': steps,
    'estimated_minutes': estimatedMinutes,
    'verification_note': verificationNote,
  };
}

final class FridgeAnalysis {
  final FoodAnalysisStatus status;
  final String summary;
  final List<FridgeItemObservation> items;
  final List<String> useSoon;
  final List<IngredientSuggestion> ingredientSuggestions;
  final List<RecipeSuggestion> recipes;
  final List<String> uncertainties;
  final String rawModelText;

  const FridgeAnalysis({
    required this.status,
    required this.summary,
    required this.items,
    required this.useSoon,
    required this.ingredientSuggestions,
    required this.recipes,
    required this.uncertainties,
    required this.rawModelText,
  });

  factory FridgeAnalysis.fromModelText(String text) {
    try {
      final json = decodeModelJson(text);
      return FridgeAnalysis(
        status: FoodAnalysisStatus.complete,
        summary: _bounded(
          json['summary'],
          700,
          fallback: 'Fridge image analyzed locally.',
        ),
        items: _mapList(
          json['items'],
        ).take(40).map(FridgeItemObservation.fromJson).toList(growable: false),
        useSoon: _stringList(json['use_soon'], maxItems: 12, maxChars: 180),
        ingredientSuggestions: _mapList(
          json['ingredient_suggestions'],
        ).take(16).map(IngredientSuggestion.fromJson).toList(growable: false),
        recipes: _mapList(
          json['recipes'],
        ).take(6).map(RecipeSuggestion.fromJson).toList(growable: false),
        uncertainties: _stringList(
          json['uncertainties'],
          maxItems: 12,
          maxChars: 240,
        ),
        rawModelText: _bounded(text, 30000),
      );
    } catch (error) {
      return FridgeAnalysis(
        status: FoodAnalysisStatus.partial,
        summary:
            'The model returned an answer, but its structured food inventory could not be fully parsed.',
        items: const [],
        useSoon: const [],
        ingredientSuggestions: const [],
        recipes: const [],
        uncertainties: <String>['Structured response error: $error'],
        rawModelText: _bounded(text, 30000),
      );
    }
  }

  factory FridgeAnalysis.failed(Object error, {bool cancelled = false}) {
    return FridgeAnalysis(
      status: cancelled
          ? FoodAnalysisStatus.cancelled
          : FoodAnalysisStatus.failed,
      summary: cancelled
          ? 'Analysis stopped. The encrypted photo can be analyzed again later.'
          : 'The encrypted photo was saved, but local analysis did not complete.',
      items: const [],
      useSoon: const [],
      ingredientSuggestions: const [],
      recipes: const [],
      uncertainties: <String>[error.toString()],
      rawModelText: '',
    );
  }

  factory FridgeAnalysis.fromJson(Map<String, Object?> json) {
    return FridgeAnalysis(
      status:
          _enumByName(FoodAnalysisStatus.values, json['status']) ??
          FoodAnalysisStatus.partial,
      summary: _bounded(json['summary'], 700),
      items: _mapList(
        json['items'],
      ).take(40).map(FridgeItemObservation.fromJson).toList(growable: false),
      useSoon: _stringList(json['use_soon'], maxItems: 12, maxChars: 180),
      ingredientSuggestions: _mapList(
        json['ingredient_suggestions'],
      ).take(16).map(IngredientSuggestion.fromJson).toList(growable: false),
      recipes: _mapList(
        json['recipes'],
      ).take(6).map(RecipeSuggestion.fromJson).toList(growable: false),
      uncertainties: _stringList(
        json['uncertainties'],
        maxItems: 12,
        maxChars: 240,
      ),
      rawModelText: _bounded(json['raw_model_text'], 30000),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'summary': summary,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'use_soon': useSoon,
    'ingredient_suggestions': ingredientSuggestions
        .map((item) => item.toJson())
        .toList(growable: false),
    'recipes': recipes.map((item) => item.toJson()).toList(growable: false),
    'uncertainties': uncertainties,
    'raw_model_text': rawModelText,
  };
}

final class FridgeLog {
  final String id;
  final DateTime capturedAt;
  final FoodVisionImage image;
  final String note;
  final FridgeAnalysis analysis;

  const FridgeLog({
    required this.id,
    required this.capturedAt,
    required this.image,
    required this.note,
    required this.analysis,
  });

  String get dayKey {
    final local = capturedAt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  FridgeLog copyWith({FridgeAnalysis? analysis}) => FridgeLog(
    id: id,
    capturedAt: capturedAt,
    image: image,
    note: note,
    analysis: analysis ?? this.analysis,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-fridge-log-v1',
    'id': id,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'image': image.toJson(),
    'note': note,
    'analysis': analysis.toJson(),
  };

  factory FridgeLog.fromJson(Map<String, Object?> json) => FridgeLog(
    id: _bounded(json['id'], 100, fallback: newFoodId('fridge')),
    capturedAt:
        DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    image: FoodVisionImage.fromJson(_map(json['image'])),
    note: _bounded(json['note'], 1200),
    analysis: FridgeAnalysis.fromJson(_map(json['analysis'])),
  );
}

enum BakeItemKind { pizza, bread, cake, cookies, pastry, casserole, custom }

final class BakeInput {
  final BakeItemKind kind;
  final String itemName;
  final double elapsedMinutes;
  final double plannedMinutes;
  final double? ovenTemperatureF;
  final double? startingTemperatureF;
  final double? probeTemperatureF;
  final double? targetTemperatureF;
  final String notes;

  const BakeInput({
    required this.kind,
    required this.itemName,
    required this.elapsedMinutes,
    required this.plannedMinutes,
    required this.ovenTemperatureF,
    required this.startingTemperatureF,
    required this.probeTemperatureF,
    required this.targetTemperatureF,
    required this.notes,
  });

  bool get hasThermalEvidence =>
      probeTemperatureF != null && targetTemperatureF != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'item_name': itemName,
    'elapsed_minutes': elapsedMinutes,
    'planned_minutes': plannedMinutes,
    'oven_temperature_f': ovenTemperatureF,
    'starting_temperature_f': startingTemperatureF,
    'probe_temperature_f': probeTemperatureF,
    'target_temperature_f': targetTemperatureF,
    'notes': notes,
  };

  factory BakeInput.fromJson(Map<String, Object?> json) => BakeInput(
    kind: _enumByName(BakeItemKind.values, json['kind']) ?? BakeItemKind.custom,
    itemName: _bounded(json['item_name'], 160, fallback: 'Baked item'),
    elapsedMinutes: _double(json['elapsed_minutes']).clamp(0, 10000),
    plannedMinutes: _double(json['planned_minutes']).clamp(0, 10000),
    ovenTemperatureF: _nullableDouble(json['oven_temperature_f']),
    startingTemperatureF: _nullableDouble(json['starting_temperature_f']),
    probeTemperatureF: _nullableDouble(json['probe_temperature_f']),
    targetTemperatureF: _nullableDouble(json['target_temperature_f']),
    notes: _bounded(json['notes'], 1200),
  );
}

final class BakeVisualAssessment {
  final FoodAnalysisStatus status;
  final String itemObserved;
  final double surfaceBrowning;
  final double structureSet;
  final double surfaceDryness;
  final double edgeDevelopment;
  final FoodConfidence confidence;
  final List<String> observations;
  final List<String> limitations;
  final String rawModelText;

  const BakeVisualAssessment({
    required this.status,
    required this.itemObserved,
    required this.surfaceBrowning,
    required this.structureSet,
    required this.surfaceDryness,
    required this.edgeDevelopment,
    required this.confidence,
    required this.observations,
    required this.limitations,
    required this.rawModelText,
  });

  factory BakeVisualAssessment.fromModelText(String text) {
    try {
      final json = decodeModelJson(text);
      return BakeVisualAssessment(
        status: FoodAnalysisStatus.complete,
        itemObserved: _bounded(
          json['item_observed'],
          160,
          fallback: 'Baked item',
        ),
        surfaceBrowning: _percent(json['surface_browning']),
        structureSet: _percent(json['structure_set']),
        surfaceDryness: _percent(json['surface_dryness']),
        edgeDevelopment: _percent(json['edge_development']),
        confidence: FoodConfidence.parse(json['confidence']),
        observations: _stringList(
          json['observations'],
          maxItems: 8,
          maxChars: 220,
        ),
        limitations: _stringList(
          json['limitations'],
          maxItems: 8,
          maxChars: 240,
        ),
        rawModelText: _bounded(text, 30000),
      );
    } catch (error) {
      return BakeVisualAssessment.failed(
        'Structured vision response error: $error',
      ).copyWith(rawModelText: _bounded(text, 30000));
    }
  }

  factory BakeVisualAssessment.failed(Object error, {bool cancelled = false}) {
    return BakeVisualAssessment(
      status: cancelled
          ? FoodAnalysisStatus.cancelled
          : FoodAnalysisStatus.failed,
      itemObserved: 'Unverified baked item',
      surfaceBrowning: 0,
      structureSet: 0,
      surfaceDryness: 0,
      edgeDevelopment: 0,
      confidence: FoodConfidence.low,
      observations: const [],
      limitations: <String>[error.toString()],
      rawModelText: '',
    );
  }

  BakeVisualAssessment copyWith({String? rawModelText}) => BakeVisualAssessment(
    status: status,
    itemObserved: itemObserved,
    surfaceBrowning: surfaceBrowning,
    structureSet: structureSet,
    surfaceDryness: surfaceDryness,
    edgeDevelopment: edgeDevelopment,
    confidence: confidence,
    observations: observations,
    limitations: limitations,
    rawModelText: rawModelText ?? this.rawModelText,
  );

  factory BakeVisualAssessment.fromJson(Map<String, Object?> json) {
    return BakeVisualAssessment(
      status:
          _enumByName(FoodAnalysisStatus.values, json['status']) ??
          FoodAnalysisStatus.partial,
      itemObserved: _bounded(json['item_observed'], 160),
      surfaceBrowning: _percent(json['surface_browning']),
      structureSet: _percent(json['structure_set']),
      surfaceDryness: _percent(json['surface_dryness']),
      edgeDevelopment: _percent(json['edge_development']),
      confidence: FoodConfidence.parse(json['confidence']),
      observations: _stringList(
        json['observations'],
        maxItems: 8,
        maxChars: 220,
      ),
      limitations: _stringList(json['limitations'], maxItems: 8, maxChars: 240),
      rawModelText: _bounded(json['raw_model_text'], 30000),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'item_observed': itemObserved,
    'surface_browning': surfaceBrowning,
    'structure_set': structureSet,
    'surface_dryness': surfaceDryness,
    'edge_development': edgeDevelopment,
    'confidence': confidence.name,
    'observations': observations,
    'limitations': limitations,
    'raw_model_text': rawModelText,
  };
}

enum BakePhase {
  early,
  setting,
  browning,
  nearlyDone,
  estimatedComplete,
  unknown,
}

final class BakeSimulationResult {
  final double estimatedPercent;
  final double lowerBound;
  final double upperBound;
  final double timeSignal;
  final double visualSignal;
  final double? thermalSignal;
  final BakePhase phase;
  final List<String> signals;
  final String safetyMessage;

  const BakeSimulationResult({
    required this.estimatedPercent,
    required this.lowerBound,
    required this.upperBound,
    required this.timeSignal,
    required this.visualSignal,
    required this.thermalSignal,
    required this.phase,
    required this.signals,
    required this.safetyMessage,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'estimated_percent': estimatedPercent,
    'lower_bound': lowerBound,
    'upper_bound': upperBound,
    'time_signal': timeSignal,
    'visual_signal': visualSignal,
    'thermal_signal': thermalSignal,
    'phase': phase.name,
    'signals': signals,
    'safety_message': safetyMessage,
  };

  factory BakeSimulationResult.fromJson(Map<String, Object?> json) {
    return BakeSimulationResult(
      estimatedPercent: _percent(json['estimated_percent']),
      lowerBound: _percent(json['lower_bound']),
      upperBound: _percent(json['upper_bound']),
      timeSignal: _percent(json['time_signal']),
      visualSignal: _percent(json['visual_signal']),
      thermalSignal: _nullableDouble(json['thermal_signal'])?.clamp(0, 100),
      phase: _enumByName(BakePhase.values, json['phase']) ?? BakePhase.unknown,
      signals: _stringList(json['signals'], maxItems: 12, maxChars: 240),
      safetyMessage: _bounded(json['safety_message'], 600),
    );
  }
}

final class BakeLog {
  final String id;
  final DateTime capturedAt;
  final FoodVisionImage image;
  final BakeInput input;
  final BakeVisualAssessment visual;
  final BakeSimulationResult simulation;

  const BakeLog({
    required this.id,
    required this.capturedAt,
    required this.image,
    required this.input,
    required this.visual,
    required this.simulation,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-bake-log-v1',
    'id': id,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'image': image.toJson(),
    'input': input.toJson(),
    'visual': visual.toJson(),
    'simulation': simulation.toJson(),
  };

  factory BakeLog.fromJson(Map<String, Object?> json) => BakeLog(
    id: _bounded(json['id'], 100, fallback: newFoodId('bake')),
    capturedAt:
        DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    image: FoodVisionImage.fromJson(_map(json['image'])),
    input: BakeInput.fromJson(_map(json['input'])),
    visual: BakeVisualAssessment.fromJson(_map(json['visual'])),
    simulation: BakeSimulationResult.fromJson(_map(json['simulation'])),
  );
}

String newFoodId(String prefix) {
  final random = math.Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  return '$prefix-${base64UrlEncode(bytes).replaceAll('=', '')}';
}

Map<String, Object?> decodeModelJson(String raw) {
  var clean = raw.trim();
  clean = clean.replaceFirst(
    RegExp(r'^```(?:json)?\s*', caseSensitive: false),
    '',
  );
  clean = clean.replaceFirst(RegExp(r'\s*```$'), '');
  final start = clean.indexOf('{');
  final end = clean.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object was returned.');
  }
  final decoded = jsonDecode(clean.substring(start, end + 1));
  if (decoded is! Map) {
    throw const FormatException('The response is not an object.');
  }
  return <String, Object?>{
    for (final entry in decoded.entries) entry.key.toString(): entry.value,
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

List<String> _stringList(
  Object? value, {
  required int maxItems,
  required int maxChars,
}) {
  if (value is! List) return const [];
  return value
      .map((item) => _bounded(item, maxChars))
      .where((item) => item.isNotEmpty)
      .take(maxItems)
      .toList(growable: false);
}

String _bounded(Object? value, int maxChars, {String fallback = ''}) {
  final clean = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (clean.isEmpty) return fallback;
  final runes = clean.runes.toList(growable: false);
  if (runes.length <= maxChars) return clean;
  return '${String.fromCharCodes(runes.take(maxChars)).trimRight()}…';
}

int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

double _double(Object? value) => double.tryParse(value?.toString() ?? '') ?? 0;

double? _nullableDouble(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return double.tryParse(value.toString());
}

double _percent(Object? value) => _double(value).clamp(0, 100).toDouble();

T? _enumByName<T extends Enum>(Iterable<T> values, Object? value) {
  final name = value?.toString().trim();
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}
