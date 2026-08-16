// LLM-CONTEXT:BEGIN
// FILE: test/exploration_hub_test.dart
// ROLE: Owns exploration hub test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/naza_exploration_hub.dart';

void main() {
  testWidgets('FindIt requires and forwards explicit location context', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NazaExplorationHub(
            runPrompt:
                ({
                  required systemInstruction,
                  required prompt,
                  imageBytes,
                }) async {
                  submitted = prompt;
                  return 'done';
                },
            pickGardenImage: () async => null,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What should FindIt locate or compare?'),
      'quiet accessible coffee shop',
    );
    await tester.tap(find.textContaining('Run with'));
    await tester.pump();
    expect(find.textContaining('Add a city'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Location or search area'),
      'Brooklyn, NY',
    );
    await tester.tap(find.textContaining('Run with'));
    await tester.pumpAndSettle();
    expect(submitted, contains('Location: Brooklyn, NY'));
  });

  testWidgets('Garden deep link captures and forwards a bounded image', (
    tester,
  ) async {
    Uint8List? submittedImage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NazaExplorationHub(
            initialSection: NazaExplorationSection.garden,
            runPrompt:
                ({
                  required systemInstruction,
                  required prompt,
                  imageBytes,
                }) async {
                  submittedImage = imageBytes;
                  return 'garden result';
                },
            pickGardenImage: () async => NazaExploreImage(
              name: 'leaf.jpg',
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('garden-camera')));
    await tester.pumpAndSettle();
    expect(find.textContaining('leaf.jpg'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Garden details and your request'),
      'Brown edges after moving into full sun',
    );
    await tester.tap(find.textContaining('Run with'));
    await tester.pumpAndSettle();
    expect(submittedImage, <int>[1, 2, 3]);
  });
}
