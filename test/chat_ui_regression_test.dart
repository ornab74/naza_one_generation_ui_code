// LLM-CONTEXT:BEGIN
// FILE: test/chat_ui_regression_test.dart
// ROLE: Owns chat ui regression test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  testWidgets('a streaming partial rebuilds only the active reply', (
    tester,
  ) async {
    final response = Completer<NazaResponse>();
    NazaChatPromptRequest? capturedRequest;

    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        chatPromptSender: (request) {
          capturedRequest = request;
          return response.future;
        },
      ),
    );
    await tester.pump();

    const prompt = 'Keep prior chat rows stable while streaming.';
    await tester.enterText(find.byType(TextField, skipOffstage: true), prompt);
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump();

    expect(capturedRequest, isNotNull);
    expect(
      find.byKey(const ValueKey<String>('model-pending-status')),
      findsOneWidget,
    );

    final homeElement = tester.element(find.byType(NazaStableHome));
    final chatListElement = tester.element(
      find.ancestor(of: find.text(prompt), matching: find.byType(ListView)),
    );
    final userBubbleElement = tester.element(
      find.ancestor(
        of: find.text(prompt),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_StableMessageBubble',
        ),
      ),
    );
    final composerElement = tester.element(
      find.ancestor(
        of: find.byType(TextField, skipOffstage: true),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ComposerBar',
        ),
      ),
    );

    final rebuilt = <Element>{};
    final previousRebuildHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousRebuildHook?.call(element, builtOnce);
      if (builtOnce) rebuilt.add(element);
    };
    try {
      capturedRequest!.onPartial?.call('Only this reply should rebuild.');
      await tester.pump();
    } finally {
      debugOnRebuildDirtyWidget = previousRebuildHook;
    }

    expect(find.text('Only this reply should rebuild.'), findsOneWidget);
    expect(rebuilt, isNot(contains(homeElement)));
    expect(rebuilt, isNot(contains(chatListElement)));
    expect(rebuilt, isNot(contains(userBubbleElement)));
    expect(rebuilt, isNot(contains(composerElement)));

    response.complete(
      NazaResponse(
        text: 'Only this reply rebuilt.',
        score: 1,
        route: 'test-local',
        cancelled: false,
        createdAt: DateTime(2026, 8, 9),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a completed reply exposes and resets manual continuation UI', (
    tester,
  ) async {
    final response = Completer<NazaResponse>();

    await tester.pumpWidget(
      NazaOneApp(
        requireVaultUnlock: false,
        chatPromptSender: (_) => response.future,
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField, skipOffstage: true),
      'Draft a long answer.',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Continue where left off'), findsNothing);
    response.complete(
      NazaResponse(
        text: 'This is the saved answer seam.',
        score: 1,
        route: 'test-local',
        cancelled: false,
        createdAt: DateTime(2026, 8, 9),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('This is the saved answer seam.'), findsOneWidget);
    expect(find.text('Continue where left off'), findsOneWidget);

    await tester.tap(find.byTooltip('Start new thread'));
    await tester.pump();
    expect(find.text('Continue where left off'), findsNothing);
    expect(find.text('This is the saved answer seam.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
