// LLM-CONTEXT:BEGIN
// FILE: test/collaboration_queue_test.dart
// ROLE: Verifies cooperative MMO-coding queue boundaries and encrypted refs.
// SECURITY-INVARIANT: Paths, fingerprints, dependencies, and envelope key/CID
// references are bounded; plaintext source and message bodies are excluded.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/agentic/collaboration_queue.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  const base =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'edit claims are relative, fingerprint-bound, and dependency-bounded',
    () {
      final safe = NazaQueuedEdit(
        id: 'edit-safe',
        poolId: 'pool-safe',
        relativePath: 'lib/feature.dart',
        sector: 'parser symbols',
        goal: 'Add a bounded parser error and focused test.',
        baseFingerprint: base,
        dependencies: <String>['edit-prerequisite'],
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(safe.validate(), isEmpty);

      final unsafe = NazaQueuedEdit(
        id: 'edit-unsafe',
        poolId: 'pool-safe',
        relativePath: '../secrets.env',
        sector: 'whole-file',
        goal: 'Read secret material.',
        baseFingerprint: 'mutable-branch',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(
        unsafe.validate(),
        contains('Edit path must be relative and traversal-safe.'),
      );
      expect(unsafe.validate(), contains('Base fingerprint is invalid.'));
    },
  );

  test('agent envelopes store only encrypted CID and key references', () {
    final envelope = NazaAgentEnvelope(
      id: 'msg-safe',
      poolId: 'pool-safe',
      kind: NazaAgentEnvelopeKind.handoff,
      senderBondKeyId: 'bond-sender-01',
      recipientBondKeyId: 'bond-receiver-01',
      ciphertextCid: 'bafybeigdyrzt5ciphertext',
      signatureKeyId: 'sig-key-01',
      editId: 'edit-safe',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(envelope.validate(), isEmpty);
    final encoded = jsonEncode(envelope.toJson());
    expect(encoded, isNot(contains('plaintext source')));
    expect(encoded, contains('bafybeigdyrzt5ciphertext'));
    expect(encoded, contains('bond-sender-01'));
  });

  test(
    'pool, edit, and handoff references persist in encrypted vault',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-collaboration-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = NazaSecureDatabase.forTesting(directory);
      await database.create(password: 'test-password', passwordRequired: true);
      addTearDown(database.lock);
      final store = NazaCollaborationQueueStore(database: database);
      final pool = NazaCollaborationPool(
        id: 'pool-roundtrip',
        name: 'Round trip',
        workspaceFingerprint: base,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await store.savePool(pool);
      final edit = NazaQueuedEdit(
        id: 'edit-roundtrip',
        poolId: pool.id,
        relativePath: 'lib/main.dart',
        sector: 'app shell',
        goal: 'Improve the shell surface.',
        baseFingerprint: base,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await store.enqueueEdit(edit);
      final envelope = NazaAgentEnvelope(
        id: 'msg-roundtrip',
        poolId: pool.id,
        kind: NazaAgentEnvelopeKind.proposal,
        senderBondKeyId: 'bond-sender-01',
        ciphertextCid: 'bafybeigdyrzt5ciphertext',
        signatureKeyId: 'sig-key-01',
        editId: edit.id,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await store.postEnvelope(envelope);

      expect((await store.loadPools()).single.id, pool.id);
      expect(
        (await store.loadEdits(pool.id)).single.relativePath,
        'lib/main.dart',
      );
      expect(
        (await store.loadEnvelopes(pool.id)).single.ciphertextCid,
        envelope.ciphertextCid,
      );
      for (final entity in await directory.list().toList()) {
        if (entity is! File) continue;
        final raw = String.fromCharCodes(await entity.readAsBytes());
        expect(raw, isNot(contains('Improve the shell surface.')));
      }
    },
  );
}
