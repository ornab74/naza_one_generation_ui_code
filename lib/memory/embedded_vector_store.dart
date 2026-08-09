import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// A local-first, dependency-free ANN + hybrid retrieval engine for NAZA One.
///
/// The design deliberately mirrors useful embedded-vector-database concepts
/// (classes, tenants, metadata filters, hybrid vector/keyword search, compact
/// persistence) without requiring a server process or shipping user memory to
/// a network service.
///
/// Search pipeline:
/// 1. deterministic LSH fan-out finds approximate cosine candidates;
/// 2. inverted lexical postings add keyword candidates;
/// 3. int8 vectors provide a cheap first-stage similarity estimate;
/// 4. exact cosine + lexical + temporal/importance signals rerank candidates;
/// 5. maximal marginal relevance (MMR) removes redundant memories.
final class NazaEmbeddedVectorStore {
  NazaEmbeddedVectorStore({
    this.dimensions = 128,
    this.lshTables = 8,
    this.lshBits = 13,
    this.maxRecords = 2400,
    this.maxCandidates = 96,
    int randomSeed = 0x4E415A41,
  }) : assert(dimensions > 0),
       assert(lshTables > 0),
       assert(lshBits > 0 && lshBits <= 24),
       _randomSeed = randomSeed {
    _planes = _makePlanes();
  }

  static const String format = 'naza-embedded-vector-store-v2';
  static const int formatVersion = 2;

  final int dimensions;
  final int lshTables;
  final int lshBits;
  final int maxRecords;
  final int maxCandidates;
  final int _randomSeed;

  late final List<List<Float32List>> _planes;
  final Map<String, NazaVectorRecord> _records = <String, NazaVectorRecord>{};
  final List<Map<int, Set<String>>> _lsh = <Map<int, Set<String>>>[];
  final Map<String, Set<String>> _postings = <String, Set<String>>{};
  final Map<String, int> _documentFrequency = <String, int>{};
  int _mutationEpoch = 0;

  int get length => _records.length;
  int get mutationEpoch => _mutationEpoch;
  Iterable<NazaVectorRecord> get records => _records.values;

  void clear() {
    _records.clear();
    _lsh.clear();
    _postings.clear();
    _documentFrequency.clear();
    _mutationEpoch++;
  }

  /// Insert or merge a memory. Content hashes are used for exact deduplication;
  /// a caller-controlled [id] still permits deterministic updates.
  NazaVectorRecord upsert(NazaVectorRecord incoming) {
    _validateRecord(incoming);
    final existing = _records[incoming.id];
    if (existing != null) _removeFromIndexes(existing);

    final duplicate = _records.values.cast<NazaVectorRecord?>().firstWhere(
      (record) =>
          record != null &&
          record.id != incoming.id &&
          record.tenant == incoming.tenant &&
          record.className == incoming.className &&
          record.contentHash == incoming.contentHash,
      orElse: () => null,
    );

    final record = duplicate == null
        ? incoming
        : duplicate.mergeObservation(incoming);
    if (duplicate != null) {
      _removeFromIndexes(duplicate);
      _records.remove(duplicate.id);
    }

    _records[record.id] = record;
    _addToIndexes(record);
    _mutationEpoch++;
    _pruneIfNeeded();
    return record;
  }

  bool remove(String id) {
    final record = _records.remove(id);
    if (record == null) return false;
    _removeFromIndexes(record);
    _mutationEpoch++;
    return true;
  }

  NazaVectorRecord? operator [](String id) => _records[id];

  List<NazaVectorSearchResult> search(NazaVectorQuery query) {
    if (_records.isEmpty || query.limit <= 0) return const [];
    _validateVector(query.vector);

    final now = query.now ?? DateTime.now().toUtc();
    final tokens = _tokenize(query.text);
    final candidateIds = <String>{};

    _ensureLshTables();
    for (var table = 0; table < lshTables; table++) {
      final signature = _signature(query.vector, table);
      candidateIds.addAll(_lsh[table][signature] ?? const <String>{});

      // Probe one-bit neighbors. This materially improves recall while keeping
      // fan-out bounded and deterministic on low-memory devices.
      for (var bit = 0; bit < lshBits && candidateIds.length < maxCandidates; bit++) {
        final neighbor = signature ^ (1 << bit);
        candidateIds.addAll(_lsh[table][neighbor] ?? const <String>{});
      }
    }

    for (final token in tokens) {
      candidateIds.addAll(_postings[token] ?? const <String>{});
      if (candidateIds.length >= maxCandidates * 2) break;
    }

    // Cold-start / adversarial-hash safety: ANN should never return nothing
    // merely because all buckets missed.
    if (candidateIds.length < math.min(query.limit * 3, 24)) {
      final fallback = _records.values
          .where((r) => _filterRecord(r, query))
          .toList(growable: false)
        ..sort((a, b) => b.salience.compareTo(a.salience));
      candidateIds.addAll(fallback.take(maxCandidates).map((r) => r.id));
    }

    final prefiltered = <_Candidate>[];
    for (final id in candidateIds) {
      final record = _records[id];
      if (record == null || !_filterRecord(record, query)) continue;
      final cheap = _quantizedCosine(query.vector, record.quantizedVector);
      final lexical = _lexicalScore(tokens, record, _records.length);
      final cheapBlend = 0.78 * cheap + 0.22 * lexical;
      if (cheapBlend < query.minimumCandidateScore) continue;
      prefiltered.add(_Candidate(record, cheapBlend, lexical));
    }

    prefiltered.sort((a, b) => b.cheapScore.compareTo(a.cheapScore));
    final rerank = prefiltered.take(maxCandidates).map((candidate) {
      final record = candidate.record;
      final cosine = _cosine(query.vector, record.vector);
      final ageHours = math.max(
        0.0,
        now.difference(record.updatedAt).inMinutes / 60.0,
      );
      final recency = math.exp(-ageHours / math.max(1.0, query.recencyHalfLifeHours / math.ln2));
      final reinforcement = 1.0 - math.exp(-record.reinforcement / 3.0);
      final access = 1.0 - math.exp(-record.accessCount / 7.0);
      final threadAffinity = query.threadId != null && query.threadId == record.threadId ? 1.0 : 0.0;

      final score =
          query.vectorWeight * _unit(cosine) +
          query.lexicalWeight * candidate.lexicalScore +
          query.salienceWeight * _unit(record.salience) +
          query.recencyWeight * recency +
          query.reinforcementWeight * reinforcement +
          query.confidenceWeight * _unit(record.confidence) +
          query.threadAffinityWeight * threadAffinity +
          query.accessWeight * access;

      return NazaVectorSearchResult(
        record: record,
        score: score,
        cosine: cosine,
        lexical: candidate.lexicalScore,
        recency: recency,
        threadAffinity: threadAffinity,
      );
    }).where((r) => r.score >= query.minimumScore).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final diversified = _mmr(
      rerank,
      limit: query.limit,
      lambda: query.mmrLambda,
    );

    for (final result in diversified) {
      final r = result.record;
      _records[r.id] = r.copyWith(
        accessCount: r.accessCount + 1,
        lastAccessedAt: now,
      );
    }
    if (diversified.isNotEmpty) _mutationEpoch++;
    return diversified;
  }

  List<NazaVectorSearchResult> _mmr(
    List<NazaVectorSearchResult> ranked, {
    required int limit,
    required double lambda,
  }) {
    if (ranked.length <= 1) return ranked.take(limit).toList(growable: false);
    final selected = <NazaVectorSearchResult>[];
    final remaining = ranked.toList(growable: true);
    final boundedLambda = lambda.clamp(0.0, 1.0);

    while (selected.length < limit && remaining.isNotEmpty) {
      NazaVectorSearchResult? best;
      double bestMmr = -double.infinity;
      for (final candidate in remaining) {
        var redundancy = 0.0;
        for (final prior in selected) {
          redundancy = math.max(
            redundancy,
            _unit(_cosine(candidate.record.vector, prior.record.vector)),
          );
        }
        final mmr = boundedLambda * candidate.score -
            (1.0 - boundedLambda) * redundancy;
        if (mmr > bestMmr) {
          bestMmr = mmr;
          best = candidate;
        }
      }
      if (best == null) break;
      selected.add(best);
      remaining.remove(best);
    }
    return selected;
  }

  bool _filterRecord(NazaVectorRecord record, NazaVectorQuery query) {
    if (query.tenant != null && record.tenant != query.tenant) return false;
    if (query.className != null && record.className != query.className) return false;
    if (query.kinds.isNotEmpty && !query.kinds.contains(record.kind)) return false;
    if (query.excludeIds.contains(record.id)) return false;
    if (record.confidence < query.minimumConfidence) return false;
    if (query.createdAfter != null && record.createdAt.isBefore(query.createdAfter!)) return false;
    if (query.metadataEquals.isNotEmpty) {
      for (final entry in query.metadataEquals.entries) {
        if (record.metadata[entry.key] != entry.value) return false;
      }
    }
    return true;
  }

  double _lexicalScore(Set<String> queryTokens, NazaVectorRecord record, int documentCount) {
    if (queryTokens.isEmpty || record.tokens.isEmpty) return 0.0;
    var score = 0.0;
    var maxScore = 0.0;
    for (final token in queryTokens) {
      final df = _documentFrequency[token] ?? 0;
      final idf = math.log(1.0 + (documentCount + 0.5) / (df + 0.5));
      maxScore += idf;
      if (record.tokens.contains(token)) score += idf;
    }
    return maxScore <= 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);
  }

  void _addToIndexes(NazaVectorRecord record) {
    _ensureLshTables();
    for (var table = 0; table < lshTables; table++) {
      final signature = _signature(record.vector, table);
      _lsh[table].putIfAbsent(signature, () => <String>{}).add(record.id);
    }
    for (final token in record.tokens) {
      final posting = _postings.putIfAbsent(token, () => <String>{});
      if (posting.add(record.id)) {
        _documentFrequency[token] = (_documentFrequency[token] ?? 0) + 1;
      }
    }
  }

  void _removeFromIndexes(NazaVectorRecord record) {
    if (_lsh.length == lshTables) {
      for (var table = 0; table < lshTables; table++) {
        final signature = _signature(record.vector, table);
        final bucket = _lsh[table][signature];
        bucket?.remove(record.id);
        if (bucket != null && bucket.isEmpty) _lsh[table].remove(signature);
      }
    }
    for (final token in record.tokens) {
      final posting = _postings[token];
      if (posting?.remove(record.id) == true) {
        final next = (_documentFrequency[token] ?? 1) - 1;
        if (next <= 0) {
          _documentFrequency.remove(token);
          _postings.remove(token);
        } else {
          _documentFrequency[token] = next;
        }
      }
    }
  }

  void _ensureLshTables() {
    while (_lsh.length < lshTables) {
      _lsh.add(<int, Set<String>>{});
    }
  }

  int _signature(List<double> vector, int table) {
    var bits = 0;
    final planes = _planes[table];
    for (var bit = 0; bit < lshBits; bit++) {
      var dot = 0.0;
      final plane = planes[bit];
      for (var i = 0; i < dimensions; i++) {
        dot += vector[i] * plane[i];
      }
      if (dot >= 0) bits |= 1 << bit;
    }
    return bits;
  }

  List<List<Float32List>> _makePlanes() {
    final random = math.Random(_randomSeed);
    return List<List<Float32List>>.generate(lshTables, (_) {
      return List<Float32List>.generate(lshBits, (_) {
        final plane = Float32List(dimensions);
        for (var i = 0; i < dimensions; i += 2) {
          // Box-Muller seeded Gaussian projection.
          final u1 = math.max(1e-12, random.nextDouble());
          final u2 = random.nextDouble();
          final radius = math.sqrt(-2.0 * math.log(u1));
          plane[i] = radius * math.cos(2 * math.pi * u2);
          if (i + 1 < dimensions) {
            plane[i + 1] = radius * math.sin(2 * math.pi * u2);
          }
        }
        return plane;
      });
    });
  }

  void _pruneIfNeeded() {
    final excess = _records.length - maxRecords;
    if (excess <= 0) return;
    final now = DateTime.now().toUtc();
    final victims = _records.values.where((r) => !r.pinned).toList(growable: false)
      ..sort((a, b) {
        double keepScore(NazaVectorRecord r) {
          final ageDays = math.max(0.0, now.difference(r.updatedAt).inHours / 24.0);
          final freshness = math.exp(-ageDays / 45.0);
          return 0.42 * r.salience +
              0.23 * r.confidence +
              0.20 * (1 - math.exp(-r.reinforcement / 3.0)) +
              0.15 * freshness;
        }
        return keepScore(a).compareTo(keepScore(b));
      });
    for (final victim in victims.take(excess)) {
      remove(victim.id);
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': format,
        'version': formatVersion,
        'dimensions': dimensions,
        'lshTables': lshTables,
        'lshBits': lshBits,
        'mutationEpoch': _mutationEpoch,
        'records': _records.values.map((r) => r.toJson()).toList(growable: false),
      };

  void restore(Map<String, dynamic> json) {
    final raw = json['records'];
    if (raw is! List) return;
    clear();
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        upsert(NazaVectorRecord.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Corrupt individual records are skipped. The authenticated outer
        // persistence layer remains responsible for tamper detection.
      }
    }
    final epoch = json['mutationEpoch'];
    if (epoch is int && epoch > _mutationEpoch) _mutationEpoch = epoch;
  }

  void _validateRecord(NazaVectorRecord record) => _validateVector(record.vector);

  void _validateVector(List<double> vector) {
    if (vector.length != dimensions) {
      throw ArgumentError('Expected $dimensions dimensions, got ${vector.length}.');
    }
  }

  static Set<String> tokenize(String text) => _tokenize(text);

  static Set<String> _tokenize(String text) {
    final normalized = text.toLowerCase();
    final tokens = <String>{};
    for (final match in RegExp(r"[a-z0-9][a-z0-9_.'/-]{1,}").allMatches(normalized)) {
      final token = match.group(0);
      if (token == null || token.length < 2 || _stopWords.contains(token)) continue;
      tokens.add(token);
      if (tokens.length >= 96) break;
    }
    return tokens;
  }

  static double _cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    var aa = 0.0;
    var bb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      aa += a[i] * a[i];
      bb += b[i] * b[i];
    }
    if (aa <= 1e-18 || bb <= 1e-18) return 0.0;
    return (dot / math.sqrt(aa * bb)).clamp(-1.0, 1.0);
  }

  static double _quantizedCosine(List<double> query, Int8List quantized) {
    var dot = 0.0;
    var qa = 0.0;
    var qb = 0.0;
    for (var i = 0; i < query.length; i++) {
      final b = quantized[i] / 127.0;
      dot += query[i] * b;
      qa += query[i] * query[i];
      qb += b * b;
    }
    if (qa <= 1e-18 || qb <= 1e-18) return 0.0;
    return (dot / math.sqrt(qa * qb)).clamp(-1.0, 1.0);
  }

  static double _unit(double value) => value.clamp(0.0, 1.0);

  static const Set<String> _stopWords = <String>{
    'the', 'and', 'that', 'this', 'with', 'from', 'have', 'for', 'are', 'was',
    'were', 'will', 'would', 'could', 'should', 'you', 'your', 'its', 'into',
    'about', 'then', 'than', 'they', 'them', 'but', 'not', 'can', 'all', 'our',
  };
}

final class NazaVectorRecord {
  NazaVectorRecord({
    required this.id,
    required this.text,
    required List<double> vector,
    required this.createdAt,
    required this.updatedAt,
    this.tenant = 'local-private',
    this.className = 'NazaChatMemory',
    this.kind = NazaMemoryKind.episodic,
    this.threadId,
    this.sourceMessageId,
    this.salience = 0.5,
    this.confidence = 0.7,
    this.reinforcement = 1.0,
    this.accessCount = 0,
    this.lastAccessedAt,
    this.pinned = false,
    Set<String>? tokens,
    Map<String, Object?>? metadata,
    String? contentHash,
  }) : vector = Float32List.fromList(vector),
       quantizedVector = _quantize(vector),
       tokens = UnmodifiableSetView<String>(tokens ?? NazaEmbeddedVectorStore.tokenize(text)),
       metadata = UnmodifiableMapView<String, Object?>(metadata ?? const <String, Object?>{}),
       contentHash = contentHash ?? _stableContentHash(text);

  final String id;
  final String tenant;
  final String className;
  final NazaMemoryKind kind;
  final String? threadId;
  final String? sourceMessageId;
  final String text;
  final Float32List vector;
  final Int8List quantizedVector;
  final Set<String> tokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
  final double salience;
  final double confidence;
  final double reinforcement;
  final int accessCount;
  final bool pinned;
  final Map<String, Object?> metadata;
  final String contentHash;

  NazaVectorRecord mergeObservation(NazaVectorRecord other) {
    final weightA = math.max(1.0, reinforcement);
    final weightB = math.max(1.0, other.reinforcement);
    final merged = List<double>.generate(
      vector.length,
      (i) => (vector[i] * weightA + other.vector[i] * weightB) / (weightA + weightB),
      growable: false,
    );
    return NazaVectorRecord(
      id: id,
      tenant: tenant,
      className: className,
      kind: salience >= other.salience ? kind : other.kind,
      threadId: other.threadId ?? threadId,
      sourceMessageId: other.sourceMessageId ?? sourceMessageId,
      text: other.text.length > text.length ? other.text : text,
      vector: merged,
      createdAt: createdAt.isBefore(other.createdAt) ? createdAt : other.createdAt,
      updatedAt: updatedAt.isAfter(other.updatedAt) ? updatedAt : other.updatedAt,
      lastAccessedAt: lastAccessedAt,
      salience: math.max(salience, other.salience).clamp(0.0, 1.0),
      confidence: math.max(confidence, other.confidence).clamp(0.0, 1.0),
      reinforcement: reinforcement + other.reinforcement,
      accessCount: accessCount + other.accessCount,
      pinned: pinned || other.pinned,
      tokens: <String>{...tokens, ...other.tokens},
      metadata: <String, Object?>{...metadata, ...other.metadata},
      contentHash: contentHash,
    );
  }

  NazaVectorRecord copyWith({
    int? accessCount,
    DateTime? lastAccessedAt,
    double? salience,
    double? confidence,
    double? reinforcement,
    bool? pinned,
  }) => NazaVectorRecord(
        id: id,
        tenant: tenant,
        className: className,
        kind: kind,
        threadId: threadId,
        sourceMessageId: sourceMessageId,
        text: text,
        vector: vector,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        salience: salience ?? this.salience,
        confidence: confidence ?? this.confidence,
        reinforcement: reinforcement ?? this.reinforcement,
        accessCount: accessCount ?? this.accessCount,
        pinned: pinned ?? this.pinned,
        tokens: tokens,
        metadata: metadata,
        contentHash: contentHash,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tenant': tenant,
        'className': className,
        'kind': kind.name,
        'threadId': threadId,
        'sourceMessageId': sourceMessageId,
        'text': text,
        'vector': vector.toList(growable: false),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lastAccessedAt': lastAccessedAt?.toUtc().toIso8601String(),
        'salience': salience,
        'confidence': confidence,
        'reinforcement': reinforcement,
        'accessCount': accessCount,
        'pinned': pinned,
        'tokens': tokens.toList(growable: false),
        'metadata': metadata,
        'contentHash': contentHash,
      };

  factory NazaVectorRecord.fromJson(Map<String, dynamic> json) {
    final vectorRaw = json['vector'];
    if (vectorRaw is! List) throw const FormatException('Missing vector.');
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (created == null || updated == null) throw const FormatException('Invalid record timestamp.');
    final tokenRaw = json['tokens'];
    final metadataRaw = json['metadata'];
    return NazaVectorRecord(
      id: json['id'] as String,
      tenant: json['tenant'] as String? ?? 'local-private',
      className: json['className'] as String? ?? 'NazaChatMemory',
      kind: NazaMemoryKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => NazaMemoryKind.episodic,
      ),
      threadId: json['threadId'] as String?,
      sourceMessageId: json['sourceMessageId'] as String?,
      text: json['text'] as String? ?? '',
      vector: vectorRaw.map((e) => (e as num).toDouble()).toList(growable: false),
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      lastAccessedAt: DateTime.tryParse(json['lastAccessedAt'] as String? ?? '')?.toUtc(),
      salience: (json['salience'] as num?)?.toDouble() ?? 0.5,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      reinforcement: (json['reinforcement'] as num?)?.toDouble() ?? 1.0,
      accessCount: json['accessCount'] as int? ?? 0,
      pinned: json['pinned'] == true,
      tokens: tokenRaw is List ? tokenRaw.whereType<String>().toSet() : null,
      metadata: metadataRaw is Map ? Map<String, Object?>.from(metadataRaw) : null,
      contentHash: json['contentHash'] as String?,
    );
  }

  static Int8List _quantize(List<double> vector) {
    var maxAbs = 0.0;
    for (final value in vector) maxAbs = math.max(maxAbs, value.abs());
    if (maxAbs <= 1e-18) return Int8List(vector.length);
    final scale = 127.0 / maxAbs;
    return Int8List.fromList(vector.map((v) => (v * scale).round().clamp(-127, 127)).toList(growable: false));
  }

  static String _stableContentHash(String text) {
    // FNV-1a 64-bit is not cryptographic; it is used only as a fast local
    // deduplication key. Integrity is provided by the encrypted persistence
    // envelope outside this index.
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(text.trim().toLowerCase())) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

enum NazaMemoryKind { episodic, semantic, preference, task, summary, code, safety }

final class NazaVectorQuery {
  const NazaVectorQuery({
    required this.vector,
    this.text = '',
    this.limit = 12,
    this.tenant,
    this.className,
    this.threadId,
    this.kinds = const <NazaMemoryKind>{},
    this.excludeIds = const <String>{},
    this.metadataEquals = const <String, Object?>{},
    this.createdAfter,
    this.now,
    this.minimumConfidence = 0.0,
    this.minimumCandidateScore = -0.2,
    this.minimumScore = 0.16,
    this.recencyHalfLifeHours = 24 * 30,
    this.mmrLambda = 0.78,
    this.vectorWeight = 0.42,
    this.lexicalWeight = 0.17,
    this.salienceWeight = 0.13,
    this.recencyWeight = 0.08,
    this.reinforcementWeight = 0.06,
    this.confidenceWeight = 0.05,
    this.threadAffinityWeight = 0.05,
    this.accessWeight = 0.04,
  });

  final List<double> vector;
  final String text;
  final int limit;
  final String? tenant;
  final String? className;
  final String? threadId;
  final Set<NazaMemoryKind> kinds;
  final Set<String> excludeIds;
  final Map<String, Object?> metadataEquals;
  final DateTime? createdAfter;
  final DateTime? now;
  final double minimumConfidence;
  final double minimumCandidateScore;
  final double minimumScore;
  final double recencyHalfLifeHours;
  final double mmrLambda;
  final double vectorWeight;
  final double lexicalWeight;
  final double salienceWeight;
  final double recencyWeight;
  final double reinforcementWeight;
  final double confidenceWeight;
  final double threadAffinityWeight;
  final double accessWeight;
}

final class NazaVectorSearchResult {
  const NazaVectorSearchResult({
    required this.record,
    required this.score,
    required this.cosine,
    required this.lexical,
    required this.recency,
    required this.threadAffinity,
  });

  final NazaVectorRecord record;
  final double score;
  final double cosine;
  final double lexical;
  final double recency;
  final double threadAffinity;
}

final class _Candidate {
  const _Candidate(this.record, this.cheapScore, this.lexicalScore);
  final NazaVectorRecord record;
  final double cheapScore;
  final double lexicalScore;
}
