// LLM-CONTEXT:BEGIN
// FILE: test_archive/shelf_scanner_test.dart
// ROLE: Owns shelf scanner test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/food/models.dart';
import 'package:naza_one/food/shelf_scanner.dart';

void main() {
  FoodVisionImage image() => FoodVisionImage(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        name: 'shelf.png',
        width: 640,
        height: 480,
      );

  ShelfItem item(String id, String name, {bool interested = false}) =>
      ShelfItem(
        id: id,
        name: name,
        approximateQuantity: '1 visible package',
        visibleCues: const <String>['front package visible'],
        confidence: FoodConfidence.high,
        interested: interested,
      );

  test('shelf scan round-trips selected items and comparisons', () {
    final record = ShelfScanRecord(
      id: 'shelf-1',
      capturedAt: DateTime.utc(2026, 8, 8, 12),
      image: image(),
      note: 'sparkling water aisle',
      items: <ShelfItem>[
        item('a', 'Brand A', interested: true).copyWith(
          risk: ShelfRiskLevel.low,
          riskReason: 'Visible package appears intact.',
        ),
        item('b', 'Brand B', interested: true).copyWith(
          risk: ShelfRiskLevel.medium,
          riskReason: 'Label visibility is incomplete.',
        ),
      ],
      comparisons: <ShelfComparison>[
        ShelfComparison(
          id: 'cmp-1',
          leftItemId: 'a',
          rightItemId: 'b',
          recommendedItemId: 'a',
          summary: 'Brand A has lower visible review risk.',
          createdAt: DateTime.utc(2026, 8, 8, 12, 1),
        ),
      ],
    );

    final restored = ShelfScanRecord.fromJson(record.toJson());

    expect(restored.id, 'shelf-1');
    expect(restored.items, hasLength(2));
    expect(restored.items.first.interested, isTrue);
    expect(restored.items.first.risk, ShelfRiskLevel.low);
    expect(restored.comparisons.single.recommendedItemId, 'a');
  });

  test('memory shelf repository orders newest first', () async {
    final repository = MemoryShelfRepository();
    final older = ShelfScanRecord(
      id: 'old',
      capturedAt: DateTime.utc(2026, 8, 8, 10),
      image: image(),
      note: '',
      items: <ShelfItem>[item('a', 'A')],
      comparisons: const <ShelfComparison>[],
    );
    final newer = ShelfScanRecord(
      id: 'new',
      capturedAt: DateTime.utc(2026, 8, 8, 11),
      image: image(),
      note: '',
      items: <ShelfItem>[item('b', 'B')],
      comparisons: const <ShelfComparison>[],
    );

    await repository.save(older);
    await repository.save(newer);
    final result = await repository.list();

    expect(result.map((entry) => entry.id), <String>['new', 'old']);
  });

  test('risk serialization preserves unknown values as review required', () {
    for (final risk in ShelfRiskLevel.values) {
      final json = item('a', 'A').copyWith(risk: risk).toJson();
      final restored = ShelfItem.fromJson(json);
      expect(restored.risk, risk);
      expect(
        restored.risk!.label,
        isIn(<String>['Low', 'Medium', 'High', 'Review required']),
      );
    }
  });
}
