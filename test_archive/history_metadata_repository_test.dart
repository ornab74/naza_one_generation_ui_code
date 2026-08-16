// LLM-CONTEXT:BEGIN
// FILE: test_archive/history_metadata_repository_test.dart
// ROLE: Owns history metadata repository test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/chat/history_drawer.dart';
import 'package:naza_one/chat/history_metadata_repository.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  late Directory temp;
  late NazaSecureDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('naza-history-meta-');
    database = NazaSecureDatabase.forTesting(temp);
    await database.create(
      password: 'history-test-password',
      passwordRequired: true,
    );
  });

  tearDown(() async {
    await database.lock();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('generated title and pin survive repository recreation', () async {
    final first = NazaHistoryMetadataRepository(database: database);
    await first.ensureThread(
      threadId: 'gpu-thread',
      firstUserText: 'repair the windows gpu runtime please',
      createdAt: DateTime.utc(2026, 8, 8, 20),
      updatedAt: DateTime.utc(2026, 8, 8, 21),
    );
    await first.setGeneratedTitle(
      threadId: 'gpu-thread',
      generatedTitle: 'Windows GPU Runtime Repair',
      fallbackText: 'repair windows gpu runtime',
    );
    await first.setPinned('gpu-thread', true);

    final reopened = NazaHistoryMetadataRepository(database: database);
    final metadata = await reopened.load();
    expect(metadata['gpu-thread']?.title, 'Windows GPU Runtime Repair');
    expect(metadata['gpu-thread']?.pinned, isTrue);
    expect(metadata['gpu-thread']?.titleGenerated, isTrue);
  });

  test('manual rename wins over later model title generation', () async {
    final repo = NazaHistoryMetadataRepository(database: database);
    await repo.ensureThread(
      threadId: 'thread',
      firstUserText: 'initial subject',
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    await repo.rename('thread', 'My Permanent Name');
    await repo.setGeneratedTitle(
      threadId: 'thread',
      generatedTitle: 'Model Replacement Name',
      fallbackText: 'fallback',
    );

    final metadata = await repo.load();
    expect(metadata['thread']?.title, 'My Permanent Name');
    expect(metadata['thread']?.userRenamed, isTrue);
  });

  test('decorate applies encrypted metadata without touching transcript data', () async {
    final repo = NazaHistoryMetadataRepository(database: database);
    await repo.ensureThread(
      threadId: 'one',
      firstUserText: 'first subject',
      createdAt: DateTime.utc(2026, 8, 7),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    await repo.rename('one', 'Renamed Conversation');
    await repo.setPinned('one', true);

    final decorated = await repo.decorate(
      transcriptEntries: <NazaHistoryEntry>[
        NazaHistoryEntry(
          threadId: 'one',
          title: 'Raw Transcript Title',
          preview: 'raw preview remains authoritative',
          createdAt: DateTime.utc(2026, 8, 7),
          updatedAt: DateTime.utc(2026, 8, 8),
          messageCount: 4,
        ),
      ],
    );

    expect(decorated.single.title, 'Renamed Conversation');
    expect(decorated.single.preview, 'raw preview remains authoritative');
    expect(decorated.single.messageCount, 4);
    expect(decorated.single.pinned, isTrue);
  });
}
