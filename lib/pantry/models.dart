import 'dart:convert';
import 'dart:math' as math;

enum PantryCategory {
  produce,
  dairy,
  protein,
  grain,
  canned,
  frozen,
  beverage,
  snack,
  household,
  personalCare,
  pet,
  other;

  String get label => switch (this) {
    PantryCategory.produce => 'Produce',
    PantryCategory.dairy => 'Dairy',
    PantryCategory.protein => 'Protein',
    PantryCategory.grain => 'Grains',
    PantryCategory.canned => 'Canned',
    PantryCategory.frozen => 'Frozen',
    PantryCategory.beverage => 'Beverages',
    PantryCategory.snack => 'Snacks',
    PantryCategory.household => 'Household',
    PantryCategory.personalCare => 'Personal care',
    PantryCategory.pet => 'Pet supplies',
    PantryCategory.other => 'Other',
  };

  static PantryCategory parse(Object? value) {
    final normalized = value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    return PantryCategory.values.firstWhere(
      (candidate) =>
          candidate.name.toLowerCase() == normalized ||
          candidate.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') ==
              normalized,
      orElse: () => PantryCategory.other,
    );
  }
}

enum PantryConfidence {
  low,
  medium,
  high;

  static PantryConfidence parse(Object? value) {
    return switch (value.toString().trim().toLowerCase()) {
      'high' => PantryConfidence.high,
      'medium' => PantryConfidence.medium,
      _ => PantryConfidence.low,
    };
  }
}

final class PantryObservation {
  final String name;
  final PantryCategory category;
  final double approximateQuantity;
  final String unit;
  final String location;
  final PantryConfidence confidence;
  final List<String> visibleCues;
  final String labelDetail;

  const PantryObservation({
    required this.name,
    required this.category,
    required this.approximateQuantity,
    required this.unit,
    required this.location,
    required this.confidence,
    required this.visibleCues,
    required this.labelDetail,
  });

  factory PantryObservation.fromJson(Map<String, Object?> json) {
    return PantryObservation(
      name: boundedText(json['name'], 120, fallback: 'Unidentified item'),
      category: PantryCategory.parse(json['category']),
      approximateQuantity: boundedDouble(
        json['approximate_quantity'],
        minimum: 0,
        maximum: 10000,
      ),
      unit: boundedText(json['unit'], 40, fallback: 'item'),
      location: boundedText(json['location'], 100, fallback: 'Unclear'),
      confidence: PantryConfidence.parse(json['confidence']),
      visibleCues: boundedStrings(json['visible_cues'], 8, 180),
      labelDetail: boundedText(json['label_detail'], 240),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'category': category.name,
    'approximate_quantity': approximateQuantity,
    'unit': unit,
    'location': location,
    'confidence': confidence.name,
    'visible_cues': visibleCues,
    'label_detail': labelDetail,
  };
}

final class PantryScanResult {
  final String summary;
  final List<PantryObservation> observations;
  final List<String> uncertainties;
  final String rawModelText;
  final bool parsed;

  const PantryScanResult({
    required this.summary,
    required this.observations,
    required this.uncertainties,
    required this.rawModelText,
    required this.parsed,
  });

  factory PantryScanResult.fromModelText(String text) {
    try {
      final json = decodePantryModelJson(text);
      return PantryScanResult(
        summary: boundedText(
          json['summary'],
          600,
          fallback: 'Pantry image analyzed locally.',
        ),
        observations: mapList(
          json['items'],
        ).take(80).map(PantryObservation.fromJson).toList(growable: false),
        uncertainties: boundedStrings(json['uncertainties'], 16, 240),
        rawModelText: boundedText(text, 30000),
        parsed: true,
      );
    } catch (error) {
      return PantryScanResult(
        summary:
            'The model returned an answer, but its pantry inventory could not be fully parsed.',
        observations: const <PantryObservation>[],
        uncertainties: <String>['Structured response error: $error'],
        rawModelText: boundedText(text, 30000),
        parsed: false,
      );
    }
  }

  factory PantryScanResult.failed(Object error) {
    return PantryScanResult(
      summary: 'Pantry analysis did not complete.',
      observations: const <PantryObservation>[],
      uncertainties: <String>[boundedText(error, 500)],
      rawModelText: '',
      parsed: false,
    );
  }
}

final class PantryItem {
  final String id;
  final String name;
  final PantryCategory category;
  final double quantity;
  final String unit;
  final double targetQuantity;
  final double reorderPoint;
  final double dailyUse;
  final double estimatedUnitPrice;
  final String location;
  final PantryConfidence confidence;
  final bool userVerified;
  final bool autoRestock;
  final DateTime lastSeenAt;
  final String note;

  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.targetQuantity,
    required this.reorderPoint,
    required this.dailyUse,
    required this.estimatedUnitPrice,
    required this.location,
    required this.confidence,
    required this.userVerified,
    required this.autoRestock,
    required this.lastSeenAt,
    required this.note,
  });

  double get daysRemaining =>
      dailyUse <= 0 ? double.infinity : quantity / dailyUse;

  PantryItem copyWith({
    String? name,
    PantryCategory? category,
    double? quantity,
    String? unit,
    double? targetQuantity,
    double? reorderPoint,
    double? dailyUse,
    double? estimatedUnitPrice,
    String? location,
    PantryConfidence? confidence,
    bool? userVerified,
    bool? autoRestock,
    DateTime? lastSeenAt,
    String? note,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      dailyUse: dailyUse ?? this.dailyUse,
      estimatedUnitPrice: estimatedUnitPrice ?? this.estimatedUnitPrice,
      location: location ?? this.location,
      confidence: confidence ?? this.confidence,
      userVerified: userVerified ?? this.userVerified,
      autoRestock: autoRestock ?? this.autoRestock,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      note: note ?? this.note,
    );
  }

  factory PantryItem.fromJson(Map<String, Object?> json) {
    final quantity = boundedDouble(
      json['quantity'],
      minimum: 0,
      maximum: 10000,
    );
    return PantryItem(
      id: boundedText(json['id'], 100, fallback: newPantryId('item')),
      name: boundedText(json['name'], 120, fallback: 'Unnamed item'),
      category: PantryCategory.parse(json['category']),
      quantity: quantity,
      unit: boundedText(json['unit'], 40, fallback: 'item'),
      targetQuantity: boundedDouble(
        json['target_quantity'],
        minimum: 0,
        maximum: 10000,
        fallback: math.max(1, quantity),
      ),
      reorderPoint: boundedDouble(
        json['reorder_point'],
        minimum: 0,
        maximum: 10000,
      ),
      dailyUse: boundedDouble(json['daily_use'], minimum: 0, maximum: 10000),
      estimatedUnitPrice: boundedDouble(
        json['estimated_unit_price'],
        minimum: 0,
        maximum: 100000,
      ),
      location: boundedText(json['location'], 100),
      confidence: PantryConfidence.parse(json['confidence']),
      userVerified: json['user_verified'] == true,
      autoRestock: json['auto_restock'] == true,
      lastSeenAt:
          DateTime.tryParse(json['last_seen_at']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      note: boundedText(json['note'], 500),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'category': category.name,
    'quantity': quantity,
    'unit': unit,
    'target_quantity': targetQuantity,
    'reorder_point': reorderPoint,
    'daily_use': dailyUse,
    'estimated_unit_price': estimatedUnitPrice,
    'location': location,
    'confidence': confidence.name,
    'user_verified': userVerified,
    'auto_restock': autoRestock,
    'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
    'note': note,
  };
}

final class PantryProfile {
  final int scanIntervalDays;
  final int planningHorizonDays;
  final int lowSupplyLeadDays;
  final double orderBudget;
  final List<String> dietaryRules;
  final List<String> excludedItems;
  final List<String> preferredStores;
  final bool allowSubstitutions;
  final bool requireCheckoutApproval;

  const PantryProfile({
    this.scanIntervalDays = 14,
    this.planningHorizonDays = 14,
    this.lowSupplyLeadDays = 3,
    this.orderBudget = 120,
    this.dietaryRules = const <String>[],
    this.excludedItems = const <String>[],
    this.preferredStores = const <String>[],
    this.allowSubstitutions = false,
    this.requireCheckoutApproval = true,
  });

  PantryProfile copyWith({
    int? scanIntervalDays,
    int? planningHorizonDays,
    int? lowSupplyLeadDays,
    double? orderBudget,
    List<String>? dietaryRules,
    List<String>? excludedItems,
    List<String>? preferredStores,
    bool? allowSubstitutions,
    bool? requireCheckoutApproval,
  }) {
    return PantryProfile(
      scanIntervalDays: scanIntervalDays ?? this.scanIntervalDays,
      planningHorizonDays: planningHorizonDays ?? this.planningHorizonDays,
      lowSupplyLeadDays: lowSupplyLeadDays ?? this.lowSupplyLeadDays,
      orderBudget: orderBudget ?? this.orderBudget,
      dietaryRules: dietaryRules ?? this.dietaryRules,
      excludedItems: excludedItems ?? this.excludedItems,
      preferredStores: preferredStores ?? this.preferredStores,
      allowSubstitutions: allowSubstitutions ?? this.allowSubstitutions,
      requireCheckoutApproval:
          requireCheckoutApproval ?? this.requireCheckoutApproval,
    );
  }

  factory PantryProfile.fromJson(Map<String, Object?> json) {
    return PantryProfile(
      scanIntervalDays: boundedInt(
        json['scan_interval_days'],
        minimum: 1,
        maximum: 90,
        fallback: 14,
      ),
      planningHorizonDays: boundedInt(
        json['planning_horizon_days'],
        minimum: 1,
        maximum: 90,
        fallback: 14,
      ),
      lowSupplyLeadDays: boundedInt(
        json['low_supply_lead_days'],
        minimum: 0,
        maximum: 30,
        fallback: 3,
      ),
      orderBudget: boundedDouble(
        json['order_budget'],
        minimum: 0,
        maximum: 100000,
        fallback: 120,
      ),
      dietaryRules: boundedStrings(json['dietary_rules'], 20, 140),
      excludedItems: boundedStrings(json['excluded_items'], 40, 140),
      preferredStores: boundedStrings(json['preferred_stores'], 12, 140),
      allowSubstitutions: json['allow_substitutions'] == true,
      requireCheckoutApproval: json['require_checkout_approval'] != false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'scan_interval_days': scanIntervalDays,
    'planning_horizon_days': planningHorizonDays,
    'low_supply_lead_days': lowSupplyLeadDays,
    'order_budget': orderBudget,
    'dietary_rules': dietaryRules,
    'excluded_items': excludedItems,
    'preferred_stores': preferredStores,
    'allow_substitutions': allowSubstitutions,
    'require_checkout_approval': requireCheckoutApproval,
  };
}

final class PantryState {
  final PantryProfile profile;
  final List<PantryItem> items;
  final DateTime? lastScanAt;
  final DateTime? nextScanAt;
  final String lastScanSummary;
  final List<String> scanUncertainties;

  const PantryState({
    this.profile = const PantryProfile(),
    this.items = const <PantryItem>[],
    this.lastScanAt,
    this.nextScanAt,
    this.lastScanSummary = '',
    this.scanUncertainties = const <String>[],
  });

  PantryState copyWith({
    PantryProfile? profile,
    List<PantryItem>? items,
    DateTime? lastScanAt,
    DateTime? nextScanAt,
    String? lastScanSummary,
    List<String>? scanUncertainties,
  }) {
    return PantryState(
      profile: profile ?? this.profile,
      items: items ?? this.items,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      nextScanAt: nextScanAt ?? this.nextScanAt,
      lastScanSummary: lastScanSummary ?? this.lastScanSummary,
      scanUncertainties: scanUncertainties ?? this.scanUncertainties,
    );
  }

  factory PantryState.fromJson(Map<String, Object?> json) {
    return PantryState(
      profile: PantryProfile.fromJson(objectMap(json['profile'])),
      items: mapList(
        json['items'],
      ).take(400).map(PantryItem.fromJson).toList(growable: false),
      lastScanAt: DateTime.tryParse(
        json['last_scan_at']?.toString() ?? '',
      )?.toUtc(),
      nextScanAt: DateTime.tryParse(
        json['next_scan_at']?.toString() ?? '',
      )?.toUtc(),
      lastScanSummary: boundedText(json['last_scan_summary'], 800),
      scanUncertainties: boundedStrings(json['scan_uncertainties'], 20, 240),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-pantry-state-v1',
    'profile': profile.toJson(),
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'last_scan_at': lastScanAt?.toUtc().toIso8601String(),
    'next_scan_at': nextScanAt?.toUtc().toIso8601String(),
    'last_scan_summary': lastScanSummary,
    'scan_uncertainties': scanUncertainties,
  };
}

enum PantryOrderStatus { draft, approved, handedOff, cancelled }

final class PantryOrderLine {
  final String itemId;
  final String name;
  final PantryCategory category;
  final double quantity;
  final String unit;
  final double estimatedUnitPrice;
  final String reason;
  final int priority;
  final bool selected;
  final bool needsVerification;

  const PantryOrderLine({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitPrice,
    required this.reason,
    required this.priority,
    required this.selected,
    required this.needsVerification,
  });

  double get estimatedTotal => quantity * estimatedUnitPrice;

  PantryOrderLine copyWith({bool? selected, double? quantity}) {
    return PantryOrderLine(
      itemId: itemId,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      estimatedUnitPrice: estimatedUnitPrice,
      reason: reason,
      priority: priority,
      selected: selected ?? this.selected,
      needsVerification: needsVerification,
    );
  }

  factory PantryOrderLine.fromJson(Map<String, Object?> json) {
    return PantryOrderLine(
      itemId: boundedText(json['item_id'], 100),
      name: boundedText(json['name'], 120, fallback: 'Unnamed item'),
      category: PantryCategory.parse(json['category']),
      quantity: boundedDouble(json['quantity'], minimum: 0, maximum: 10000),
      unit: boundedText(json['unit'], 40, fallback: 'item'),
      estimatedUnitPrice: boundedDouble(
        json['estimated_unit_price'],
        minimum: 0,
        maximum: 100000,
      ),
      reason: boundedText(json['reason'], 300),
      priority: boundedInt(json['priority'], minimum: 0, maximum: 100),
      selected: json['selected'] != false,
      needsVerification: json['needs_verification'] != false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'item_id': itemId,
    'name': name,
    'category': category.name,
    'quantity': quantity,
    'unit': unit,
    'estimated_unit_price': estimatedUnitPrice,
    'reason': reason,
    'priority': priority,
    'selected': selected,
    'needs_verification': needsVerification,
  };
}

final class PantryPlanAdvisory {
  final String summary;
  final List<String> dealQueries;
  final List<String> substitutions;
  final List<String> warnings;

  const PantryPlanAdvisory({
    this.summary = '',
    this.dealQueries = const <String>[],
    this.substitutions = const <String>[],
    this.warnings = const <String>[],
  });

  factory PantryPlanAdvisory.fromModelText(String text) {
    try {
      final json = decodePantryModelJson(text);
      return PantryPlanAdvisory(
        summary: boundedText(json['summary'], 700),
        dealQueries: boundedStrings(json['deal_queries'], 16, 180),
        substitutions: boundedStrings(json['substitutions'], 16, 220),
        warnings: boundedStrings(json['warnings'], 16, 220),
      );
    } catch (error) {
      return PantryPlanAdvisory(
        summary: 'The local planning response could not be structured.',
        warnings: <String>['Structured response error: $error'],
      );
    }
  }

  factory PantryPlanAdvisory.fromJson(Map<String, Object?> json) {
    return PantryPlanAdvisory(
      summary: boundedText(json['summary'], 700),
      dealQueries: boundedStrings(json['deal_queries'], 16, 180),
      substitutions: boundedStrings(json['substitutions'], 16, 220),
      warnings: boundedStrings(json['warnings'], 16, 220),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'summary': summary,
    'deal_queries': dealQueries,
    'substitutions': substitutions,
    'warnings': warnings,
  };
}

final class PantryOrderPlan {
  final String id;
  final DateTime createdAt;
  final List<PantryOrderLine> lines;
  final double budgetCap;
  final PantryOrderStatus status;
  final PantryPlanAdvisory advisory;
  final DateTime? approvedAt;
  final DateTime? handedOffAt;

  const PantryOrderPlan({
    required this.id,
    required this.createdAt,
    required this.lines,
    required this.budgetCap,
    this.status = PantryOrderStatus.draft,
    this.advisory = const PantryPlanAdvisory(),
    this.approvedAt,
    this.handedOffAt,
  });

  double get estimatedTotal => lines
      .where((line) => line.selected)
      .fold<double>(0, (total, line) => total + line.estimatedTotal);

  bool get hasUnverifiedLines =>
      lines.any((line) => line.selected && line.needsVerification);

  PantryOrderPlan copyWith({
    List<PantryOrderLine>? lines,
    PantryOrderStatus? status,
    PantryPlanAdvisory? advisory,
    DateTime? approvedAt,
    DateTime? handedOffAt,
  }) {
    return PantryOrderPlan(
      id: id,
      createdAt: createdAt,
      lines: lines ?? this.lines,
      budgetCap: budgetCap,
      status: status ?? this.status,
      advisory: advisory ?? this.advisory,
      approvedAt: approvedAt ?? this.approvedAt,
      handedOffAt: handedOffAt ?? this.handedOffAt,
    );
  }

  factory PantryOrderPlan.fromJson(Map<String, Object?> json) {
    return PantryOrderPlan(
      id: boundedText(json['id'], 100, fallback: newPantryId('order')),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lines: mapList(
        json['lines'],
      ).take(200).map(PantryOrderLine.fromJson).toList(growable: false),
      budgetCap: boundedDouble(json['budget_cap'], minimum: 0, maximum: 100000),
      status:
          enumByName(PantryOrderStatus.values, json['status']) ??
          PantryOrderStatus.draft,
      advisory: PantryPlanAdvisory.fromJson(objectMap(json['advisory'])),
      approvedAt: DateTime.tryParse(
        json['approved_at']?.toString() ?? '',
      )?.toUtc(),
      handedOffAt: DateTime.tryParse(
        json['handed_off_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-pantry-order-v1',
    'id': id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
    'budget_cap': budgetCap,
    'estimated_total': estimatedTotal,
    'status': status.name,
    'advisory': advisory.toJson(),
    'approved_at': approvedAt?.toUtc().toIso8601String(),
    'handed_off_at': handedOffAt?.toUtc().toIso8601String(),
  };
}

Map<String, Object?> decodePantryModelJson(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) throw const FormatException('Empty model response.');
  final withoutFence = trimmed
      .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
  final start = withoutFence.indexOf('{');
  final end = withoutFence.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('No JSON object found.');
  }
  final decoded = jsonDecode(withoutFence.substring(start, end + 1));
  if (decoded is! Map) throw const FormatException('Expected a JSON object.');
  return decoded.map<String, Object?>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

Map<String, Object?> objectMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map<String, Object?>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

List<Map<String, Object?>> mapList(Object? value) {
  if (value is! Iterable) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map(
        (item) => item.map<String, Object?>(
          (key, entryValue) => MapEntry(key.toString(), entryValue),
        ),
      )
      .toList(growable: false);
}

List<String> boundedStrings(Object? value, int maxItems, int maxRunes) {
  if (value is! Iterable) return const <String>[];
  return value
      .take(maxItems)
      .map((item) => boundedText(item, maxRunes))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String boundedText(Object? value, int maxRunes, {String fallback = ''}) {
  final clean = value
      .toString()
      .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty || clean == 'null') return fallback;
  final runes = clean.runes.toList(growable: false);
  return runes.length <= maxRunes
      ? clean
      : '${String.fromCharCodes(runes.take(maxRunes)).trimRight()}…';
}

double boundedDouble(
  Object? value, {
  required double minimum,
  required double maximum,
  double fallback = 0,
}) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.clamp(minimum, maximum).toDouble();
}

int boundedInt(
  Object? value, {
  required int minimum,
  required int maximum,
  int fallback = 0,
}) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null) return fallback;
  return parsed.clamp(minimum, maximum).toInt();
}

T? enumByName<T extends Enum>(Iterable<T> values, Object? value) {
  final name = value?.toString().trim();
  if (name == null || name.isEmpty) return null;
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}

String newPantryId(String prefix) {
  final random = math.Random.secure();
  final suffix = List<int>.generate(
    8,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}-$suffix';
}
