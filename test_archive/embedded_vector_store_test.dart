// LLM-CONTEXT:BEGIN
// FILE: test_archive/embedded_vector_store_test.dart
// ROLE: Owns embedded vector store test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  List<double> v(double x, double y, {int dimensions = 8}) {
    final out = List<double>.filled(dimensions, 0);
    out[0] = x;
    out[1] = y;
    return out;
  }

  NazaVectorRecord record({
    required String id,
    required String text,
    required List<double> vector,
    String tenant = 'local-private',
    String? threadId,
    double salience = 0.5,
    double confidence = 0.8,
    DateTime? time,
  }) {
    final stamp = time ?? DateTime.utc(2026, 8, 8, 12);
    return NazaVectorRecord(
      id: id,
      tenant: tenant,
      text: text,
      vector: vector,
      threadId: threadId,
      createdAt: stamp,
      updatedAt: stamp,
      salience: salience,
      confidence: confidence,
    );
  }

  group('NazaEmbeddedVectorStore', () {
    test('hybrid search retrieves nearest semantic record', () {
      final store = NazaEmbeddedVectorStore(
        dimensions: 8,
        lshTables: 4,
        lshBits: 6,
      );
      store.upsert(record(id: 'bike', text: 'motorcycle front wheel bearing', vector: v(1, 0)));
      store.upsert(record(id: 'food', text: 'frozen pizza baking time', vector: v(0, 1)));

      final hits = store.search(NazaVectorQuery(
        vector: v(0.98, 0.04),
        text: 'front wheel',
        limit: 2,
        now: DateTime.utc(2026, 8, 8, 12),
      ));

      expect(hits, isNotEmpty);
      expect(hits.first.record.id, 'bike');
      expect(hits.first.cosine, greaterThan(0.9));
    });

    test('lexical inverted index rescues a vector miss', () {
      final store = NazaEmbeddedVectorStore(
        dimensions: 8,
        lshTables: 2,
        lshBits: 5,
      );
      store.upsert(record(
        id: 'rare',
        text: 'dxcompiler windows packaging recovery note',
        vector: v(0, 1),
        salience: 0.9,
      ));
      store.upsert(record(id: 'near', text: 'unrelated generic note', vector: v(1, 0)));

      final hits = store.search(NazaVectorQuery(
        vector: v(1, 0),
        text: 'dxcompiler packaging',
        limit: 2,
        lexicalWeight: 0.55,
        vectorWeight: 0.15,
        salienceWeight: 0.10,
        recencyWeight: 0.05,
        reinforcementWeight: 0.05,
        confidenceWeight: 0.05,
        threadAffinityWeight: 0.03,
        accessWeight: 0.02,
        minimumScore: 0,
        minimumCandidateScore: -1,
        now: DateTime.utc(2026, 8, 8, 12),
      ));

      expect(hits.any((hit) => hit.record.id == 'rare'), isTrue);
      expect(hits.first.record.id, 'rare');
    });

    test('tenant filter prevents cross-tenant retrieval', () {
      final store = NazaEmbeddedVectorStore(dimensions: 8, lshTables: 3, lshBits: 5);
      store.upsert(record(id: 'a', tenant: 'private-a', text: 'secret a', vector: v(1, 0)));
      store.upsert(record(id: 'b', tenant: 'private-b', text: 'secret b', vector: v(1, 0)));

      final hits = store.search(NazaVectorQuery(
        vector: v(1, 0),
        tenant: 'private-a',
        limit: 8,
        minimumScore: 0,
        now: DateTime.utc(2026, 8, 8, 12),
      ));

      expect(hits.map((h) => h.record.id), contains('a'));
      expect(hits.map((h) => h.record.id), isNot(contains('b')));
    });

    test('duplicate content reinforces instead of multiplying records', () {
      final store = NazaEmbeddedVectorStore(dimensions: 8, lshTables: 3, lshBits: 5);
      store.upsert(record(id: 'first', text: 'prefers concise code examples', vector: v(1, 0)));
      store.upsert(record(id: 'second', text: 'prefers concise code examples', vector: v(0.9, 0.1)));

      expect(store.length, 1);
      expect(store.records.single.reinforcement, greaterThan(1));
    });

    test('MMR avoids returning only near-duplicate memories', () {
      final store = NazaEmbeddedVectorStore(dimensions: 8, lshTables: 4, lshBits: 5);
      store.upsert(record(id: 'a1', text: 'windows gpu setup alpha', vector: v(1, 0)));
      store.upsert(record(id: 'a2', text: 'windows gpu setup beta', vector: v(0.999, 0.01)));
      store.upsert(record(id: 'diverse', text: 'windows packaging dependency', vector: v(0.78, 0.62), salience: 0.9));

      final hits = store.search(NazaVectorQuery(
        vector: v(1, 0),
        text: 'windows gpu packaging',
        limit: 2,
        mmrLambda: 0.55,
        minimumScore: 0,
        now: DateTime.utc(2026, 8, 8, 12),
      ));

      expect(hits, hasLength(2));
      expect(hits.map((h) => h.record.id), contains('diverse'));
    });

    test('snapshot round-trip rebuilds search indexes', () {
      final original = NazaEmbeddedVectorStore(dimensions: 8, lshTables: 3, lshBits: 5);
      original.upsert(record(id: 'one', text: 'embedded vector persistence', vector: v(1, 0)));
      original.upsert(record(id: 'two', text: 'other memory', vector: v(0, 1)));

      final restored = NazaEmbeddedVectorStore(dimensions: 8, lshTables: 3, lshBits: 5);
      restored.restore(original.toJson());

      final hits = restored.search(NazaVectorQuery(
        vector: v(1, 0),
        text: 'vector persistence',
        limit: 1,
        minimumScore: 0,
        now: DateTime.utc(2026, 8, 8, 12),
      ));
      expect(restored.length, 2);
      expect(hits.single.record.id, 'one');
    });

    test('bounded pruning retains pinned records', () {
      final store = NazaEmbeddedVectorStore(
        dimensions: 8,
        lshTables: 2,
        lshBits: 4,
        maxRecords: 3,
      );
      final base = DateTime.utc(2026, 1, 1);
      store.upsert(NazaVectorRecord(
        id: 'pinned',
        text: 'critical pinned memory',
        vector: v(1, 0),
        createdAt: base,
        updatedAt: base,
        pinned: true,
        salience: 1,
        confidence: 1,
      ));
      for (var i = 0; i < 5; i++) {
        store.upsert(record(
          id: 'r$i',
          text: 'ordinary memory $i',
          vector: v(0.1 * i, 1),
          time: base.add(Duration(days: i)),
        ));
      }

      expect(store.length, 3);
      expect(store['pinned'], isNotNull);
    });

    test('rejects vectors with the wrong dimensionality', () {
      final store = NazaEmbeddedVectorStore(dimensions: 8);
      expect(
        () => store.upsert(record(id: 'bad', text: 'bad vector', vector: v(1, 0, dimensions: 7))),
        throwsArgumentError,
      );
    });
  });
}
