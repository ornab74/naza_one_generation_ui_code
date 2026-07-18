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
