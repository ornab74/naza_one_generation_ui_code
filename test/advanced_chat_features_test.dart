import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/chat/history_drawer.dart';
import 'package:naza_one/chat/scroll_follow_controller.dart';
import 'package:naza_one/onboarding/first_run_onboarding.dart';

void main() {
  group('conversation title policy', () {
    test('fallback is compact and useful', () {
      final title = NazaConversationTitlePolicy.fallback(
        'please repair the Windows GPU regression in the local model build',
      );
      expect(title.toLowerCase(), contains('repair'));
      expect(title.split(' ').length, lessThanOrEqualTo(6));
    });

    test('model title is bounded', () {
      final title = NazaConversationTitlePolicy.sanitizeModelTitle(
        'Windows GPU Runtime Repair With A Title That Is Far Too Long',
        'repair windows gpu',
      );
      expect(title.length, lessThanOrEqualTo(72));
      expect(title.split(' ').length, lessThanOrEqualTo(6));
    });
  });

  testWidgets('history drawer filters entries and exposes new chat', (tester) async {
    var newChats = 0;
    final entries = <NazaHistoryEntry>[
      NazaHistoryEntry(
        threadId: 'gpu',
        title: 'Windows GPU Repair',
        preview: 'LiteRT runtime regression',
        createdAt: DateTime(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 8, 21),
        messageCount: 8,
      ),
      NazaHistoryEntry(
        threadId: 'food',
        title: 'Food Scanner',
        preview: 'shelf analysis',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7, 20),
        messageCount: 3,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NazaHistoryDrawer(
          entries: entries,
          activeThreadId: 'gpu',
          onOpenThread: (_) {},
          onNewChat: () => newChats++,
          onClose: () {},
        ),
      ),
    ));

    expect(find.text('Windows GPU Repair'), findsOneWidget);
    expect(find.text('Food Scanner'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gpu');
    await tester.pump();
    expect(find.text('Windows GPU Repair'), findsOneWidget);
    expect(find.text('Food Scanner'), findsNothing);

    await tester.tap(find.text('New'));
    expect(newChats, 1);
  });

  testWidgets('onboarding shows help after verified model', (tester) async {
    final state = ValueNotifier<NazaOnboardingModelState>(
      const NazaOnboardingModelState(phase: NazaOnboardingModelPhase.ready),
    );
    var completed = 0;

    await tester.pumpWidget(MaterialApp(
      home: NazaFirstRunOnboarding(
        modelState: state,
        ensureModel: () async {},
        onComplete: () => completed++,
      ),
    ));
    await tester.pump();

    expect(find.text('You’re ready to chat'), findsOneWidget);
    expect(find.text('Smart Memory is on by default'), findsOneWidget);
    final openChat = find.text('Open Chat');
    await tester.ensureVisible(openChat);
    await tester.pumpAndSettle();
    await tester.tap(openChat);
    await tester.pump();
    expect(completed, 1);
    state.dispose();
  });

  testWidgets('onboarding automatically acquires a missing model once', (tester) async {
    final state = ValueNotifier<NazaOnboardingModelState>(
      const NazaOnboardingModelState(phase: NazaOnboardingModelPhase.missing),
    );
    var calls = 0;

    await tester.pumpWidget(MaterialApp(
      home: NazaFirstRunOnboarding(
        modelState: state,
        ensureModel: () async {
          calls++;
          state.value = const NazaOnboardingModelState(
            phase: NazaOnboardingModelPhase.ready,
          );
        },
        onComplete: () {},
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(find.text('You’re ready to chat'), findsOneWidget);
    state.dispose();
  });

  testWidgets('scroll follow detaches on upward user scroll', (tester) async {
    late NazaChatScrollFollowController follow;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          follow = NazaChatScrollFollowController();
          return SizedBox(
            height: 240,
            child: NotificationListener<ScrollNotification>(
              onNotification: follow.handleNotification,
              child: ListView.builder(
                controller: follow.controller,
                itemCount: 80,
                itemBuilder: (_, index) => SizedBox(height: 40, child: Text('row $index')),
              ),
            ),
          );
        },
      ),
    ));
    await tester.pump();
    await follow.jumpToLatest();
    await tester.pump();
    expect(follow.followTail, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 180));
    await tester.pump();
    expect(follow.followTail, isFalse);
  });
}
