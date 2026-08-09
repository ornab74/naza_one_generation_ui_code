import 'dart:async';

import '../memory/local_memory_service.dart';
import '../onboarding/onboarding_state.dart';
import 'history_drawer.dart';
import 'history_metadata_repository.dart';

/// Thin integration surface for the large app shell.
///
/// `beforePrompt` retrieves local evidence. `afterResponse` records durable
/// memory, persists thread metadata and (once per thread) asks the already
/// loaded local model for a short title. The raw transcript remains owned by
/// the existing history/vault code.
final class NazaAdvancedChatCoordinator {
  NazaAdvancedChatCoordinator({
    NazaLocalMemoryService? memory,
    NazaHistoryMetadataRepository? historyMetadata,
    NazaOnboardingStateStore? onboarding,
    NazaGenerateConversationTitle? generateTitle,
  })  : memory = memory ?? NazaLocalMemoryService(),
        historyMetadata = historyMetadata ?? NazaHistoryMetadataRepository(),
        onboarding = onboarding ?? NazaOnboardingStateStore(),
        _titles = generateTitle == null
            ? null
            : NazaConversationTitleCoordinator(generateTitle: generateTitle);

  final NazaLocalMemoryService memory;
  final NazaHistoryMetadataRepository historyMetadata;
  final NazaOnboardingStateStore onboarding;
  final NazaConversationTitleCoordinator? _titles;

  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= memory.initialize();

  Future<NazaPromptMemoryContext> beforePrompt({
    required String userText,
    required String threadId,
    int maxCharacters = 6200,
  }) async {
    await initialize();
    final block = await memory.buildPromptContext(
      query: userText,
      threadId: threadId,
      maxCharacters: maxCharacters,
    );
    return NazaPromptMemoryContext(
      enabled: memory.settings.enabled,
      promptBlock: block,
      memoryCount: memory.memoryCount,
    );
  }

  Future<NazaPostTurnResult> afterResponse({
    required String threadId,
    required String userText,
    required String assistantText,
    required DateTime timestamp,
    String? userMessageId,
    String? assistantMessageId,
    bool generateConversationTitle = true,
  }) async {
    await initialize();

    final stored = await memory.rememberTurn(
      userText: userText,
      assistantText: assistantText,
      threadId: threadId,
      userMessageId: userMessageId,
      assistantMessageId: assistantMessageId,
      timestamp: timestamp,
    );

    final metadata = await historyMetadata.ensureThread(
      threadId: threadId,
      firstUserText: userText,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    String title = metadata.title;
    final titleCoordinator = _titles;
    if (generateConversationTitle &&
        titleCoordinator != null &&
        !metadata.userRenamed &&
        !metadata.titleGenerated &&
        assistantText.trim().length >= 24) {
      title = await titleCoordinator.titleFor(
        threadId: threadId,
        userText: userText,
        assistantText: assistantText,
      );
      await historyMetadata.setGeneratedTitle(
        threadId: threadId,
        generatedTitle: title,
        fallbackText: userText,
      );
    }

    return NazaPostTurnResult(
      memoriesStored: stored,
      title: title,
      memoryCount: memory.memoryCount,
    );
  }

  Future<void> setMemoryEnabled(bool enabled) async {
    await initialize();
    await memory.setEnabled(enabled);
  }

  Future<void> clearMemory() async {
    await initialize();
    await memory.clear();
  }

  Future<void> flush() async {
    await initialize();
    await memory.flush();
  }

  Future<List<NazaHistoryEntry>> decorateHistory(
    Iterable<NazaHistoryEntry> transcriptEntries,
  ) =>
      historyMetadata.decorate(transcriptEntries: transcriptEntries);

  Future<void> renameThread(String threadId, String title) =>
      historyMetadata.rename(threadId, title);

  Future<void> pinThread(String threadId, bool pinned) =>
      historyMetadata.setPinned(threadId, pinned);

  Future<void> removeThreadMetadata(String threadId) =>
      historyMetadata.remove(threadId);

  Future<bool> shouldShowOnboarding() => onboarding.shouldShow();

  Future<void> completeOnboarding({String? modelDigest}) =>
      onboarding.complete(modelDigest: modelDigest);
}

final class NazaPromptMemoryContext {
  const NazaPromptMemoryContext({
    required this.enabled,
    required this.promptBlock,
    required this.memoryCount,
  });

  final bool enabled;
  final String promptBlock;
  final int memoryCount;

  bool get hasRetrievedMemory => promptBlock.trim().isNotEmpty;
}

final class NazaPostTurnResult {
  const NazaPostTurnResult({
    required this.memoriesStored,
    required this.title,
    required this.memoryCount,
  });

  final int memoriesStored;
  final String title;
  final int memoryCount;
}
