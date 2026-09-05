// LLM-CONTEXT:BEGIN
// FILE: test_archive/advanced_chat_coordinator_test.dart
// ROLE: Owns advanced chat coordinator test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  late Directory temp;
  late NazaSecureDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('naza-chat-coordinator-');
    database = NazaSecureDatabase.forTesting(temp);
    await database.create(
      password: 'coordinator-test-password',
      passwordRequired: true,
    );
  });

  tearDown(() async {
    await database.lock();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('completed turn becomes retrievable memory and generated title', () async {
    var titleCalls = 0;
    final coordinator = NazaAdvancedChatCoordinator(
      memory: NazaLocalMemoryService(database: database),
      historyMetadata: NazaHistoryMetadataRepository(database: database),
      onboarding: NazaOnboardingStateStore(database: database),
      generateTitle: ({required userText, required assistantText}) async {
        titleCalls++;
        return 'Windows GPU Compatibility';
      },
    );

    final result = await coordinator.afterResponse(
      threadId: 'thread-1',
      userText: 'I prefer private local Windows GPU inference for this project.',
      assistantText: 'The project will prioritize local GPU inference and retain a safe CPU fallback.',
      timestamp: DateTime.utc(2026, 8, 8, 22),
    );

    expect(result.memoriesStored, greaterThan(0));
    expect(result.title, 'Windows GPU Compatibility');
    expect(titleCalls, 1);

    final context = await coordinator.beforePrompt(
      userText: 'What inference setup do I prefer?',
      threadId: 'thread-1',
    );
    expect(context.enabled, isTrue);
    expect(context.hasRetrievedMemory, isTrue);
    expect(context.promptBlock.toLowerCase(), contains('local'));
  });

  test('memory disable switch is honored through coordinator', () async {
    final coordinator = NazaAdvancedChatCoordinator(
      memory: NazaLocalMemoryService(database: database),
      historyMetadata: NazaHistoryMetadataRepository(database: database),
      onboarding: NazaOnboardingStateStore(database: database),
    );
    await coordinator.setMemoryEnabled(false);

    final result = await coordinator.afterResponse(
      threadId: 'disabled',
      userText: 'Remember a persistent preference while disabled.',
      assistantText: 'This must not enter vector memory.',
      timestamp: DateTime.utc(2026, 8, 8),
    );
    expect(result.memoriesStored, 0);

    final context = await coordinator.beforePrompt(
      userText: 'persistent preference',
      threadId: 'disabled',
    );
    expect(context.enabled, isFalse);
    expect(context.hasRetrievedMemory, isFalse);
  });

  test('onboarding state is delegated to encrypted versioned store', () async {
    final coordinator = NazaAdvancedChatCoordinator(
      memory: NazaLocalMemoryService(database: database),
      historyMetadata: NazaHistoryMetadataRepository(database: database),
      onboarding: NazaOnboardingStateStore(database: database),
    );

    expect(await coordinator.shouldShowOnboarding(), isTrue);
    await coordinator.completeOnboarding(modelDigest: 'sha256:test');
    expect(await coordinator.shouldShowOnboarding(), isFalse);
  });
}
