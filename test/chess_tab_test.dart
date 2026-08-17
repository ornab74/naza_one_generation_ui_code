import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/chess/chess_tab.dart';

void main() {
  testWidgets('Chess Agent exposes the advanced contract and accepts a legal move', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NazaChessTab()));
    await tester.pumpAndSettle();

    expect(find.text('Chess Agent'), findsOneWidget);
    expect(find.text('Advanced agent desk'), findsOneWidget);
    expect(find.text('Use bounded local game memory'), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);

    final board = tester.getRect(find.byType(GridView).first);
    final tile = board.width / 8;
    Offset square(int index) => Offset(
          board.left + (index % 8) * tile + tile / 2,
          board.top + (index ~/ 8) * tile + tile / 2,
        );

    // e2-e4: a legal pawn double-step whose path is clear.
    await tester.tapAt(square(52));
    await tester.pump();
    await tester.tapAt(square(36));
    await tester.pumpAndSettle();

    expect(find.text('Black to move'), findsOneWidget);
    expect(find.text('e2→e4'), findsOneWidget);
  });
}
