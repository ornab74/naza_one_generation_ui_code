import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
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

    expect(find.text('Bark / Convo'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Live audio chat'),
      420,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Live audio chat'), findsOneWidget);
    expect(find.text('Start Live Chat'), findsOneWidget);
    expect(find.text('Stop Audio'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
