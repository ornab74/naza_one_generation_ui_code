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
        warmModel: false,
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
        warmModel: false,
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
        warmModel: false,
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
        warmModel: false,
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
    await tester.pumpWidget(const NazaOneApp(warmModel: false));
    await tester.pump();

    expect(find.text('New Chat'), findsOneWidget);
    expect(find.textContaining('Naza One is ready'), findsOneWidget);
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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps scanner text visible when switching panels', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(warmModel: false));
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byType(TextField, skipOffstage: true).first,
      'Bottled water retention check',
    );
    await tester.pump();

    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Food'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bottled water retention check'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders live audio chat controls on the Convo tab', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(warmModel: false));
    await tester.pump();

    final convoNav = find.ancestor(
      of: find.text('Convo'),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(convoNav.first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Convo'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Live audio chat'),
      420,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Live audio chat'), findsOneWidget);
    expect(find.text('Start Live Chat'), findsOneWidget);
    expect(find.text('Stop Audio'), findsOneWidget);
    expect(find.textContaining('BarkPack'), findsNothing);
    expect(find.text('Render Convo WAV'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps BarkPack installation and tests in Settings', (
    tester,
  ) async {
    await tester.pumpWidget(const NazaOneApp(warmModel: false));
    await tester.pump();

    final convoNav = find.ancestor(
      of: find.text('Convo'),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(convoNav.first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Install / Verify Pack'), findsNothing);
    expect(find.text('Run Self-Test'), findsNothing);
    expect(find.text('Voice Setup'), findsNothing);
    expect(find.textContaining('BarkPack'), findsNothing);

    final settingsNav = find.ancestor(
      of: find.text('Settings'),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(settingsNav.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('BarkPack setup and testing'),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Android voice diagnostics'), findsOneWidget);
    expect(find.text('BarkPack setup and testing'), findsOneWidget);
    expect(find.text('Install / Verify Pack'), findsOneWidget);
    expect(find.text('Run Self-Test'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
