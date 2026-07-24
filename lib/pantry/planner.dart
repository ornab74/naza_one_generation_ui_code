import 'dart:math' as math;

import 'models.dart';

final class PantryPlanner {
  const PantryPlanner._();

  static PantryState mergeScan({
    required PantryState previous,
    required PantryScanResult scan,
    required DateTime capturedAt,
  }) {
    final when = capturedAt.toUtc();
    final byKey = <String, PantryItem>{
      for (final item in previous.items) _key(item.name, item.category): item,
    };

    for (final observation in scan.observations) {
      final key = _key(observation.name, observation.category);
      final prior = byKey[key];
      if (prior == null) {
        final suggestedTarget = math
            .max(1, observation.approximateQuantity)
            .toDouble();
        byKey[key] = PantryItem(
          id: newPantryId('item'),
          name: observation.name,
          category: observation.category,
          quantity: observation.approximateQuantity,
          unit: observation.unit,
          targetQuantity: suggestedTarget,
          reorderPoint: suggestedTarget * 0.25,
          dailyUse: 0,
          estimatedUnitPrice: 0,
          location: observation.location,
          confidence: observation.confidence,
          userVerified: false,
          autoRestock: false,
          lastSeenAt: when,
          note: observation.visibleCues.join(' • '),
        );
        continue;
      }

      byKey[key] = prior.copyWith(
        name: observation.name,
        category: observation.category,
        quantity: observation.approximateQuantity,
        unit: observation.unit,
        location: observation.location,
        confidence: observation.confidence,
        userVerified:
            prior.userVerified &&
            observation.confidence == PantryConfidence.high,
        lastSeenAt: when,
        note: observation.visibleCues.join(' • '),
      );
    }

    final merged = byKey.values.toList(growable: false)
      ..sort((a, b) {
        final category = a.category.index.compareTo(b.category.index);
        return category != 0
            ? category
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return PantryState(
      profile: previous.profile,
      items: List<PantryItem>.unmodifiable(merged),
      lastScanAt: when,
      nextScanAt: when.add(Duration(days: previous.profile.scanIntervalDays)),
      lastScanSummary: scan.summary,
      scanUncertainties: scan.uncertainties,
    );
  }

  static PantryOrderPlan buildOrderPlan({
    required PantryState state,
    required DateTime now,
  }) {
    final excluded = state.profile.excludedItems
        .map(_normalizedName)
        .where((name) => name.isNotEmpty)
        .toSet();
    final lines = <PantryOrderLine>[];

    for (final item in state.items) {
      if (!item.autoRestock || excluded.contains(_normalizedName(item.name))) {
        continue;
      }
      final projectedQuantity = _projectedQuantity(item, now);
      final consumptionTarget =
          item.dailyUse * state.profile.planningHorizonDays;
      final target = math.max(item.targetQuantity, consumptionTarget);
      final deficit = math.max(0, target - projectedQuantity).toDouble();
      final lowByPoint = projectedQuantity <= item.reorderPoint;
      final projectedDaysRemaining = item.dailyUse <= 0
          ? double.infinity
          : projectedQuantity / item.dailyUse;
      final lowByTime =
          item.dailyUse > 0 &&
          projectedDaysRemaining <= state.profile.lowSupplyLeadDays;
      if (deficit <= 0 || (!lowByPoint && !lowByTime)) continue;

      final urgent = projectedQuantity <= 0 || projectedDaysRemaining <= 1;
      final priority = urgent
          ? 100
          : lowByTime
          ? 80
          : 60;
      final reason = item.dailyUse > 0
          ? '${_formatQuantity(projectedQuantity)} ${item.unit} are projected to remain; about '
                '${projectedDaysRemaining.isFinite ? projectedDaysRemaining.toStringAsFixed(1) : 'unknown'} '
                'days at the configured use rate.'
          : '${_formatQuantity(projectedQuantity)} ${item.unit} remain, at or below '
                'the configured reorder point of '
                '${_formatQuantity(item.reorderPoint)}.';
      lines.add(
        PantryOrderLine(
          itemId: item.id,
          name: item.name,
          category: item.category,
          quantity: deficit,
          unit: item.unit,
          estimatedUnitPrice: item.estimatedUnitPrice,
          reason: reason,
          priority: priority,
          selected: true,
          needsVerification:
              !item.userVerified ||
              item.confidence != PantryConfidence.high ||
              item.estimatedUnitPrice <= 0,
        ),
      );
    }

    lines.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0
          ? priority
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    var runningTotal = 0.0;
    final budgeted = <PantryOrderLine>[];
    for (final line in lines) {
      final lineTotal = line.estimatedTotal;
      final knownPrice = line.estimatedUnitPrice > 0;
      final withinBudget =
          !knownPrice ||
          state.profile.orderBudget <= 0 ||
          runningTotal + lineTotal <= state.profile.orderBudget;
      budgeted.add(line.copyWith(selected: withinBudget));
      if (withinBudget && knownPrice) runningTotal += lineTotal;
    }

    return PantryOrderPlan(
      id: newPantryId('order'),
      createdAt: now.toUtc(),
      lines: List<PantryOrderLine>.unmodifiable(budgeted),
      budgetCap: state.profile.orderBudget,
    );
  }

  static PantryState updateItem(PantryState state, PantryItem updated) {
    final items = state.items
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    return state.copyWith(items: List<PantryItem>.unmodifiable(items));
  }

  static String _key(String name, PantryCategory category) =>
      '${category.name}:${_normalizedName(name)}';

  static double _projectedQuantity(PantryItem item, DateTime now) {
    if (item.dailyUse <= 0) return item.quantity;
    final elapsed = now.toUtc().difference(item.lastSeenAt.toUtc());
    if (elapsed.isNegative) return item.quantity;
    final elapsedDays =
        elapsed.inMilliseconds / Duration.millisecondsPerDay.toDouble();
    return math
        .max(0, item.quantity - (item.dailyUse * elapsedDays))
        .toDouble();
  }

  static String _normalizedName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
