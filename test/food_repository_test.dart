import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/food/models.dart';
import 'package:naza_one/food/repository.dart';

void main() {
  group('MemoryFoodRepository', () {
    test(
      'orders newest first, paginates, and prunes oldest fridge logs',
      () async {
        final repository = MemoryFoodRepository(fridgeLimit: 2, bakeLimit: 2);
        final oldest = _fridgeLog('fridge-oldest', minute: 1);
        final newest = _fridgeLog('fridge-newest', minute: 3);
        final middle = _fridgeLog('fridge-middle', minute: 2);

        await Future.wait(<Future<void>>[
          repository.saveFridgeLog(oldest),
          repository.saveFridgeLog(newest),
          repository.saveFridgeLog(middle),
        ]);

        final retained = await repository.listFridgeLogs();
        expect(retained.map((log) => log.id), <String>[newest.id, middle.id]);
        expect(await repository.getFridgeLog(oldest.id), isNull);
        expect(
          (await repository.listFridgeLogs(limit: 1, offset: 1)).single.id,
          middle.id,
        );
        expect(repository.revision.value, 3);
      },
    );

    test('replaces an existing fridge log without duplicating it', () async {
      final repository = MemoryFoodRepository(fridgeLimit: 3, bakeLimit: 3);
      final first = _fridgeLog(
        'fridge-same',
        minute: 1,
        note: 'first observation',
      );
      final other = _fridgeLog('fridge-other', minute: 2);
      final replacement = _fridgeLog(
        'fridge-same',
        minute: 3,
        note: 'updated observation',
      );

      await repository.saveFridgeLog(first);
      await repository.saveFridgeLog(other);
      await repository.saveFridgeLog(replacement);

      final logs = await repository.listFridgeLogs();
      expect(logs.map((log) => log.id), <String>[replacement.id, other.id]);
      expect(logs.where((log) => log.id == replacement.id), hasLength(1));
      expect(
        (await repository.getFridgeLog(replacement.id))?.note,
        'updated observation',
      );
    });

    test('deletes individual logs and clears both histories', () async {
      final repository = MemoryFoodRepository(fridgeLimit: 3, bakeLimit: 3);
      final fridge = _fridgeLog('fridge-delete', minute: 1);
      final firstBake = _bakeLog('bake-first', minute: 1);
      final secondBake = _bakeLog('bake-second', minute: 2);

      await repository.saveFridgeLog(fridge);
      await repository.saveBakeLog(firstBake);
      await repository.saveBakeLog(secondBake);
      await repository.deleteBakeLog(secondBake.id);

      expect(await repository.getBakeLog(secondBake.id), isNull);
      expect((await repository.listBakeLogs()).map((log) => log.id), <String>[
        firstBake.id,
      ]);

      await repository.deleteFridgeLog(fridge.id);
      expect(await repository.listFridgeLogs(), isEmpty);

      await repository.saveFridgeLog(fridge);
      await repository.saveBakeLog(secondBake);
      await repository.clearAll();

      expect(await repository.listFridgeLogs(), isEmpty);
      expect(await repository.listBakeLogs(), isEmpty);
    });

    test(
      'applies bake retention using capture time rather than save order',
      () async {
        final repository = MemoryFoodRepository(fridgeLimit: 2, bakeLimit: 2);
        final newest = _bakeLog('bake-newest', minute: 3);
        final oldest = _bakeLog('bake-oldest', minute: 1);
        final middle = _bakeLog('bake-middle', minute: 2);

        await repository.saveBakeLog(newest);
        await repository.saveBakeLog(oldest);
        await repository.saveBakeLog(middle);

        expect((await repository.listBakeLogs()).map((log) => log.id), <String>[
          newest.id,
          middle.id,
        ]);
        expect(await repository.getBakeLog(oldest.id), isNull);
      },
    );
  });

  group('food model JSON', () {
    test('FridgeLog round-trips its image and structured suggestions', () {
      final original = FridgeLog(
        id: 'fridge-round-trip',
        capturedAt: DateTime.utc(2026, 7, 15, 9, 30),
        image: _image('fridge.png'),
        note: 'Top shelf and produce drawer',
        analysis: const FridgeAnalysis(
          status: FoodAnalysisStatus.complete,
          summary: 'Vegetables, eggs, and yogurt are visible.',
          items: <FridgeItemObservation>[
            FridgeItemObservation(
              name: 'Eggs',
              approximateQuantity: 'About six',
              location: 'Upper shelf',
              visibleCues: <String>['Closed carton', 'Label partly visible'],
              useWindow: 'Verify carton date',
              confidence: FoodConfidence.high,
            ),
          ],
          useSoon: <String>['Yogurt'],
          ingredientSuggestions: <IngredientSuggestion>[
            IngredientSuggestion(
              name: 'Fresh herbs',
              reason: 'Complements the visible eggs and vegetables',
              priority: 'medium',
            ),
          ],
          recipes: <RecipeSuggestion>[
            RecipeSuggestion(
              title: 'Vegetable omelet',
              usesVisibleItems: <String>['Eggs', 'Vegetables'],
              missingIngredients: <String>['Fresh herbs'],
              steps: <String>['Chop vegetables', 'Cook with beaten eggs'],
              estimatedMinutes: 18,
              verificationNote: 'Verify labels and cook eggs thoroughly.',
            ),
          ],
          uncertainties: <String>['Yogurt date is not readable'],
          rawModelText: '{"summary":"Vegetables, eggs, and yogurt"}',
        ),
      );

      final restored = FridgeLog.fromJson(_jsonRoundTrip(original.toJson()));

      expect(restored.toJson(), equals(original.toJson()));
      expect(restored.image.bytes, orderedEquals(original.image.bytes));
    });

    test('BakeLog round-trips inputs, visual cues, and simulation result', () {
      final original = BakeLog(
        id: 'bake-round-trip',
        capturedAt: DateTime.utc(2026, 7, 15, 10, 45),
        image: _image('cake.png'),
        input: const BakeInput(
          kind: BakeItemKind.cake,
          itemName: 'Chocolate cake',
          elapsedMinutes: 24.5,
          plannedMinutes: 35,
          ovenTemperatureF: 350,
          startingTemperatureF: 68,
          probeTemperatureF: null,
          targetTemperatureF: null,
          notes: 'Center photographed through oven glass',
        ),
        visual: const BakeVisualAssessment(
          status: FoodAnalysisStatus.complete,
          itemObserved: 'Round chocolate cake',
          surfaceBrowning: 58,
          structureSet: 71,
          surfaceDryness: 49,
          edgeDevelopment: 64,
          confidence: FoodConfidence.medium,
          observations: <String>['Edges look set', 'Center remains glossy'],
          limitations: <String>['Internal temperature is unknown'],
          rawModelText: '{"item_observed":"Round chocolate cake"}',
        ),
        simulation: const BakeSimulationResult(
          estimatedPercent: 72.5,
          lowerBound: 52.5,
          upperBound: 92.5,
          timeSignal: 76,
          visualSignal: 69,
          thermalSignal: null,
          phase: BakePhase.browning,
          signals: <String>['Timing model: 76%', 'Visible surface model: 69%'],
          safetyMessage: 'Visual estimate only; verify doneness separately.',
        ),
      );

      final restored = BakeLog.fromJson(_jsonRoundTrip(original.toJson()));

      expect(restored.toJson(), equals(original.toJson()));
      expect(restored.image.bytes, orderedEquals(original.image.bytes));
      expect(restored.input.hasThermalEvidence, isFalse);
    });
  });
}

FridgeLog _fridgeLog(
  String id, {
  required int minute,
  String note = 'daily fridge capture',
}) {
  return FridgeLog(
    id: id,
    capturedAt: DateTime.utc(2026, 7, 15, 12, minute),
    image: _image('$id.png'),
    note: note,
    analysis: const FridgeAnalysis(
      status: FoodAnalysisStatus.complete,
      summary: 'Fridge analysis complete.',
      items: <FridgeItemObservation>[],
      useSoon: <String>[],
      ingredientSuggestions: <IngredientSuggestion>[],
      recipes: <RecipeSuggestion>[],
      uncertainties: <String>[],
      rawModelText: '{}',
    ),
  );
}

BakeLog _bakeLog(String id, {required int minute}) {
  return BakeLog(
    id: id,
    capturedAt: DateTime.utc(2026, 7, 15, 13, minute),
    image: _image('$id.png'),
    input: const BakeInput(
      kind: BakeItemKind.pizza,
      itemName: 'Pizza',
      elapsedMinutes: 8,
      plannedMinutes: 12,
      ovenTemperatureF: 425,
      startingTemperatureF: null,
      probeTemperatureF: null,
      targetTemperatureF: null,
      notes: '',
    ),
    visual: const BakeVisualAssessment(
      status: FoodAnalysisStatus.complete,
      itemObserved: 'Pizza',
      surfaceBrowning: 50,
      structureSet: 60,
      surfaceDryness: 45,
      edgeDevelopment: 55,
      confidence: FoodConfidence.medium,
      observations: <String>['Cheese is melting'],
      limitations: <String>['Center is not visible'],
      rawModelText: '{}',
    ),
    simulation: const BakeSimulationResult(
      estimatedPercent: 65,
      lowerBound: 45,
      upperBound: 85,
      timeSignal: 70,
      visualSignal: 60,
      thermalSignal: null,
      phase: BakePhase.browning,
      signals: <String>['Timing and visual signals combined'],
      safetyMessage: 'Verify doneness separately.',
    ),
  );
}

FoodVisionImage _image(String name) {
  return FoodVisionImage(
    bytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47, name.length]),
    name: name,
    width: 2,
    height: 2,
  );
}

Map<String, Object?> _jsonRoundTrip(Map<String, Object?> value) {
  return Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);
}
