import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  testWidgets('renders the chat surface and composer', (tester) async {
    await tester.pumpWidget(const NazaOneApp(warmModel: false));
    await tester.pump();

    expect(find.text('New Chat'), findsOneWidget);
    expect(find.textContaining('Naza One is ready'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask anything...'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'Visible immediately');
    await tester.pump();
    expect(find.text('Visible immediately'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
