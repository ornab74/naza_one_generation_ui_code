// LLM-CONTEXT:BEGIN
// FILE: lib/model/model_assembly.dart
// ROLE: Owns opt-in multi-provider chunk assembly policy.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Persist policy in the encrypted vault; never persist
// prompt chunks, model responses, or credentials in this configuration.
// CHANGE-GUARD: Local Gemma remains the default and assembly is opt-in.
// LLM-CONTEXT:END
import 'dart:math' as math;

import 'provider_gateway.dart';
import '../security/secure_database.dart';

enum NazaAssemblyMode { localOnly, singleRemote, shardedAssembly }

final class NazaModelAssemblyConfig {
  const NazaModelAssemblyConfig({
    this.mode = NazaAssemblyMode.localOnly,
    this.profileIds = const <String>[],
    this.chunkCharacters = 12000,
    this.maxShards = 3,
    this.entropyThreshold = 0.35,
  });

  static const int minChunkCharacters = 2000;
  static const int maxChunkCharacters = 40000;
  static const int maxShardsAllowed = 8;
  static const int maxChunksAllowed = 32;

  final NazaAssemblyMode mode;
  final List<String> profileIds;
  final int chunkCharacters;
  final int maxShards;

  /// A normalized disagreement signal between shard outputs. It is a
  /// diagnostic surface for diversity/uncertainty, not a claim of randomness
  /// or a substitute for model confidence.
  final double entropyThreshold;

  NazaModelAssemblyConfig copyWith({
    NazaAssemblyMode? mode,
    Iterable<String>? profileIds,
    int? chunkCharacters,
    int? maxShards,
    double? entropyThreshold,
  }) {
    final boundedShards = (maxShards ?? this.maxShards)
        .clamp(1, maxShardsAllowed)
        .toInt();
    return NazaModelAssemblyConfig(
      mode: mode ?? this.mode,
      profileIds: List<String>.unmodifiable(
        (profileIds ?? this.profileIds)
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .take(boundedShards),
      ),
      chunkCharacters: (chunkCharacters ?? this.chunkCharacters)
          .clamp(minChunkCharacters, maxChunkCharacters)
          .toInt(),
      maxShards: boundedShards,
      entropyThreshold: (entropyThreshold ?? this.entropyThreshold)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'profileIds': profileIds,
    'chunkCharacters': chunkCharacters,
    'maxShards': maxShards,
    'entropyThreshold': entropyThreshold,
  };

  static NazaModelAssemblyConfig fromJson(Object? value) {
    if (value is! Map) return const NazaModelAssemblyConfig();
    final modeName = value['mode']?.toString();
    final mode = NazaAssemblyMode.values.where((item) => item.name == modeName);
    final ids = value['profileIds'];
    final rawIds = ids is List ? ids.whereType<String>() : const <String>[];
    return const NazaModelAssemblyConfig().copyWith(
      mode: mode.isEmpty ? NazaAssemblyMode.localOnly : mode.first,
      profileIds: rawIds,
      chunkCharacters: _boundedInt(value['chunkCharacters'], 12000),
      maxShards: _boundedInt(value['maxShards'], 3),
      entropyThreshold: _boundedDouble(value['entropyThreshold'], 0.35),
    );
  }

  static int _boundedInt(Object? value, int fallback) =>
      value is num ? value.round() : fallback;

  static double _boundedDouble(Object? value, double fallback) =>
      value is num && value.isFinite ? value.toDouble() : fallback;
}

final class NazaModelAssemblyStore {
  NazaModelAssemblyStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String _namespace = 'model-assembly';
  static const String _key = 'assembly-v1';
  final NazaSecureDatabase _database;

  Future<NazaModelAssemblyConfig> load() async {
    final raw = await _database.readJson(_namespace, _key);
    return NazaModelAssemblyConfig.fromJson(raw);
  }

  Future<void> save(NazaModelAssemblyConfig config) =>
      _database.writeJson(_namespace, _key, config.toJson());
}

final class NazaAssemblyResponse {
  const NazaAssemblyResponse({
    required this.text,
    required this.provider,
    required this.model,
    required this.shardCount,
    required this.entropySignal,
    this.shards = const <NazaAssemblyShard>[],
  });

  final String text;
  final String provider;
  final String model;
  final int shardCount;
  final double entropySignal;
  final List<NazaAssemblyShard> shards;
}

final class NazaAssemblyShard {
  const NazaAssemblyShard({
    required this.text,
    required this.provider,
    required this.model,
  });

  final String text;
  final String provider;
  final String model;
}

/// Executes independent prompt chunks across selected profiles, then returns
/// a bounded, labeled assembly. The host may use the entropy signal to ask a
/// final local Gemma pass for synthesis; this coordinator intentionally never
/// logs or persists prompt/response material.
final class NazaShardedModelCoordinator {
  NazaShardedModelCoordinator({NazaProviderGateway? gateway})
    : _gateway = gateway ?? NazaProviderGateway();

  final NazaProviderGateway _gateway;

  Future<NazaAssemblyResponse> assemble({
    required List<NazaRemoteModelProfile> profiles,
    required NazaModelAssemblyConfig config,
    required String prompt,
    String? systemInstruction,
  }) async {
    final cleanProfiles = profiles
        .where((profile) => profile.enabled && profile.apiKey.trim().isNotEmpty)
        .take(config.maxShards)
        .toList(growable: false);
    final minimumProfiles = config.mode == NazaAssemblyMode.shardedAssembly
        ? 2
        : 1;
    if (cleanProfiles.length < minimumProfiles) {
      throw StateError(
        'The assembly policy does not have enough enabled provider profiles.',
      );
    }
    final chunks = _chunk(prompt, config.chunkCharacters);
    final results = await Future.wait(
      List<Future<NazaRemoteModelResponse>>.generate(chunks.length, (index) {
        final profile = cleanProfiles[index % cleanProfiles.length];
        final shardInstruction = [
          if (systemInstruction?.trim().isNotEmpty == true) systemInstruction,
          'You are shard ${index + 1} of ${chunks.length}. Analyze only the supplied chunk.',
          'Return a concise evidence-bearing contribution for an assembly pass.',
        ].join('\n');
        return _gateway.send(
          profile: profile,
          prompt: chunks[index],
          systemInstruction: shardInstruction,
        );
      }),
    );
    final signal = _entropySignal(results.map((item) => item.text));
    final surface = signal >= config.entropyThreshold
        ? '[assembly surface: elevated disagreement ${signal.toStringAsFixed(3)}; local review recommended]'
        : '[assembly surface: convergent disagreement ${signal.toStringAsFixed(3)}]';
    final assembled = [
      surface,
      ...results.asMap().entries.map(
        (entry) =>
            '[shard ${entry.key + 1} · ${entry.value.provider} · ${entry.value.model}]\n${entry.value.text}',
      ),
    ].join('\n\n');
    return NazaAssemblyResponse(
      text: assembled,
      provider: 'sharded assembly',
      model: '${results.length} provider shards',
      shardCount: results.length,
      entropySignal: signal,
      shards: List<NazaAssemblyShard>.unmodifiable(
        results.map(
          (item) => NazaAssemblyShard(
            text: item.text,
            provider: item.provider,
            model: item.model,
          ),
        ),
      ),
    );
  }

  void close() => _gateway.close();

  static List<String> _chunk(String prompt, int size) {
    final clean = prompt.trim();
    if (clean.isEmpty) throw const FormatException('Prompt is empty.');
    final bounded = size
        .clamp(
          NazaModelAssemblyConfig.minChunkCharacters,
          NazaModelAssemblyConfig.maxChunkCharacters,
        )
        .toInt();
    final chunks = <String>[];
    for (var offset = 0; offset < clean.length; offset += bounded) {
      chunks.add(
        clean.substring(offset, math.min(offset + bounded, clean.length)),
      );
      if (chunks.length > NazaModelAssemblyConfig.maxChunksAllowed) {
        throw const FormatException(
          'Prompt exceeds the bounded assembly size.',
        );
      }
    }
    return chunks;
  }

  static double _entropySignal(Iterable<String> values) {
    final tokenSets = values
        .map(
          (text) => text
              .toLowerCase()
              .split(RegExp(r'[^a-z0-9]+'))
              .where((word) => word.length > 3)
              .toSet(),
        )
        .where((tokens) => tokens.isNotEmpty)
        .toList(growable: false);
    if (tokenSets.length < 2) return 0;

    // Pairwise Jaccard disagreement measures the surface between shards:
    // repeated vocabulary converges toward zero, while disjoint evidence
    // moves toward one. This is intentionally a review signal, not a truth
    // score or a substitute for source verification.
    var disagreement = 0.0;
    var comparisons = 0;
    for (var left = 0; left < tokenSets.length; left++) {
      for (var right = left + 1; right < tokenSets.length; right++) {
        final intersection = tokenSets[left].intersection(tokenSets[right]);
        final union = tokenSets[left].union(tokenSets[right]);
        if (union.isEmpty) continue;
        disagreement += 1 - intersection.length / union.length;
        comparisons++;
      }
    }
    final pairwise = comparisons == 0 ? 0.0 : disagreement / comparisons;

    final words = tokenSets.expand((tokens) => tokens).toList(growable: false);
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final total = words.length.toDouble();
    final entropy = counts.values.fold<double>(0, (sum, count) {
      final p = count / total;
      return sum - p * math.log(p) / math.ln2;
    });
    final max = math.log(math.max(2, counts.length)) / math.ln2;
    final lexicalEntropy = max == 0
        ? 0.0
        : (entropy / max).clamp(0.0, 1.0).toDouble();
    return (pairwise * 0.7 + lexicalEntropy * 0.3).clamp(0.0, 1.0).toDouble();
  }
}
