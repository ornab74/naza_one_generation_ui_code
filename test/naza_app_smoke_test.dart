// LLM-CONTEXT:BEGIN
// FILE: test/naza_app_smoke_test.dart
// ROLE: Owns naza app smoke test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  testWidgets('attaches and removes a bounded Gemma vision image', (
    tester,
  ) async {
    final image = NazaVisionImage(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      name: 'vision-test.jpg',
      width: 640,
      height: 480,
    );

    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        visionPicker: () async => NazaVisionPickResult.selected(image),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Attach image for Gemma vision'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('vision-test.jpg'), findsOneWidget);
    expect(
      find.text('640 × 480 • processed locally • 1 image max'),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove image'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove image'));
    await tester.pump();
    expect(find.text('vision-test.jpg'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps an attachment when replacement selection is cancelled', (
    tester,
  ) async {
    final image = NazaVisionImage(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
      name: 'keep-me.jpg',
      width: 320,
      height: 240,
    );
    var attempts = 0;
    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        visionPicker: () async {
          attempts++;
          return attempts == 1
              ? NazaVisionPickResult.selected(image)
              : const NazaVisionPickResult.cancelled();
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Attach image for Gemma vision'));
    await tester.pump();
    expect(find.text('keep-me.jpg'), findsOneWidget);

    await tester.tap(find.byTooltip('Attach image for Gemma vision'));
    await tester.pump();
    expect(find.text('keep-me.jpg'), findsOneWidget);
    expect(find.textContaining('image selection cancelled'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reports an unavailable picker instead of cancellation', (
    tester,
  ) async {
    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        visionPicker: () async => const NazaVisionPickResult.unavailable(
          'native picker is not registered',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Attach image for Gemma vision'));
    await tester.pump();

    expect(find.textContaining('image picker unavailable'), findsOneWidget);
    expect(find.textContaining('image selection cancelled'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deduplicates rapid image picker taps', (tester) async {
    final result = Completer<NazaVisionPickResult>();
    var attempts = 0;
    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        visionPicker: () {
          attempts++;
          return result.future;
        },
      ),
    );
    await tester.pump();

    final button = find.byTooltip('Attach image for Gemma vision');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(attempts, 1);

    result.complete(const NazaVisionPickResult.cancelled());
    await tester.pump();
    expect(find.textContaining('image selection cancelled'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders the chat surface and composer', (tester) async {
    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();

    expect(find.text('New Chat'), findsNothing);
    expect(find.textContaining('Naza One is ready'), findsNothing);
    expect(find.textContaining('New private thread ready'), findsNothing);
    final visibleTextFields = find.byType(TextField, skipOffstage: true);
    expect(visibleTextFields, findsOneWidget);
    expect(find.text('Ask anything...'), findsOneWidget);

    await tester.tap(visibleTextFields);
    await tester.pump();
    expect(
      tester.widget<TextField>(visibleTextFields).focusNode!.hasFocus,
      isTrue,
    );

    await tester.enterText(visibleTextFields, 'Visible immediately');
    await tester.pump();
    expect(find.text('Visible immediately'), findsOneWidget);

    await tester.tap(find.byTooltip('Start new thread'));
    await tester.pump();
    expect(find.text('New Chat'), findsNothing);
    expect(find.textContaining('Naza One is ready'), findsNothing);
    expect(find.textContaining('New private thread ready'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('paints a pending turn immediately and delivers the reply', (
    tester,
  ) async {
    final response = Completer<NazaResponse>();
    NazaChatPromptRequest? capturedRequest;
    var sendCount = 0;

    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        chatPromptSender: (request) {
          sendCount++;
          capturedRequest = request;
          return response.future;
        },
      ),
    );
    await tester.pump();

    final composer = find.byType(TextField, skipOffstage: true);
    await tester.enterText(composer, 'Why is the sky blue?');
    final sendButton = find.text('Send');
    await tester.tap(sendButton);
    // Exercise the stale pre-pump button callback too: the synchronous send
    // lease must reject this second submission before either Future completes.
    await tester.tap(sendButton);
    await tester.pump();
    await tester.pump();

    expect(sendCount, 1);
    expect(capturedRequest?.prompt, 'Why is the sky blue?');
    expect(find.text('Why is the sky blue?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('model-pending-status')),
      findsOneWidget,
    );
    expect(find.text('Stop'), findsOneWidget);

    capturedRequest!.onPartial?.call('A streaming local reply.');
    await tester.pump();
    expect(find.text('A streaming local reply.'), findsOneWidget);
    expect(sendCount, 1);

    response.complete(
      NazaResponse(
        text: 'Because shorter blue wavelengths scatter more strongly.',
        score: 1,
        route: 'test-local',
        cancelled: false,
        createdAt: DateTime(2026, 8, 9),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Because shorter blue wavelengths scatter more strongly.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('model-pending-status')),
      findsNothing,
    );
    expect(find.text('Send'), findsOneWidget);
    expect(sendCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Stop is actionable before the sender produces a token', (
    tester,
  ) async {
    final response = Completer<NazaResponse>();
    var cancelCount = 0;

    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        chatPromptSender: (_) => response.future,
        chatPromptCanceller: () {
          cancelCount++;
          if (!response.isCompleted) {
            response.complete(
              NazaResponse(
                text: 'Stopped before the prompt reached the model.',
                score: 0,
                route: 'model-warmup-cancelled',
                cancelled: true,
                createdAt: DateTime(2026, 8, 9),
              ),
            );
          }
          return true;
        },
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField, skipOffstage: true),
      'Please answer locally.',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump();

    expect(cancelCount, 1);
    expect(
      find.text('Stopped before the prompt reached the model.'),
      findsOneWidget,
    );
    expect(find.text('Send'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps scanner text visible when switching panels', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();

    await tester.tap(find.text('Road'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byType(TextField, skipOffstage: true).first,
      'I-95 northbound retention check',
    );
    await tester.pump();

    await tester.tap(find.text('Chat'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Road'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I-95 northbound retention check'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final fridgeNote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Optional note',
      description: 'fridge optional note field',
    );
    expect(fridgeNote, findsOneWidget);
    await tester.enterText(fridgeNote, 'Bottled water retention check');
    await tester.pump();
    expect(
      tester.widget<TextField>(fridgeNote).controller!.text,
      'Bottled water retention check',
    );

    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final reopenedFridgeNote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Optional note',
      description: 'reopened fridge optional note field',
    );
    expect(reopenedFridgeNote, findsOneWidget);
    expect(
      tester.widget<TextField>(reopenedFridgeNote).controller!.text,
      'Bottled water retention check',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Bake Lab workspace inherits the selected app theme', (
    tester,
  ) async {
    final previousTheme = NazaThemeStore.selectedId.value;
    addTearDown(() => NazaThemeStore.selectedId.value = previousTheme);
    NazaThemeStore.selectedId.value = 'synthwave';

    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();
    await tester.tap(find.text('Food'));
    await tester.pump();
    await tester.tap(find.byTooltip('View and configure all features'));
    await tester.pump();
    await tester.tap(find.text('Bake Lab'));
    await tester.pump(const Duration(milliseconds: 300));

    final kitchenContext = tester.element(find.byType(Scaffold).last);
    final kitchenScheme = Theme.of(kitchenContext).colorScheme;
    final selectedTheme = NazaBootThemeCatalog.byId('synthwave');
    expect(kitchenScheme.secondary, selectedTheme.seed);
    expect(kitchenScheme.brightness, selectedTheme.brightness);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings defaults to simple and can reveal advanced controls', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Settings mode'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Rendering / desktop stability'), findsNothing);

    await tester.tap(find.text('Advanced').last);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Advanced Settings'), findsOneWidget);

    await tester.tap(find.text('Simple').last);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Advanced Settings'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the whole simple appearance card opens the theme chooser', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.tap(find.text('Saved securely and applied now'));
    await tester.pump();

    expect(find.text('Rose Dark'), findsOneWidget);
    expect(find.text('Quantum Cyan'), findsWidgets);

    await NazaThemeStore.select('naza-emerald');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('has no retired voice, Convo, or BarkPack surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(requireVaultUnlock: false));
    await tester.pump();

    expect(find.text('Convo'), findsNothing);
    expect(find.textContaining('BarkPack'), findsNothing);
    expect(find.textContaining('voice diagnostics'), findsNothing);
  });
}
