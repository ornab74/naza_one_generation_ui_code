// LLM-CONTEXT:BEGIN
// FILE: lib/model/embedding_runtime.dart
// ROLE: Owns local/remote embedding selection and hybrid vector composition.
// DOMAIN: model-runtime / local-memory
// SECURITY-INVARIANT: Local embeddings are the default; remote embedding is
// explicit, bounded, and never persists raw provider responses outside the
// encrypted memory vault.
// CHANGE-GUARD: Keep the in-house fixed-dimension vector index compatible.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../security/secure_database.dart';
import 'provider_gateway.dart';

enum NazaEmbeddingMode { localOnly, remoteOnly, hybridEnsemble }

enum NazaEmbeddingPurpose { query, document }

final class NazaEmbeddingTarget {
  const NazaEmbeddingTarget({required this.profileId, required this.model});

  final String profileId;
  final String model;

  Map<String, Object?> toJson() => <String, Object?>{
    'profileId': profileId,
    'model': model,
  };

  static NazaEmbeddingTarget? fromJson(Object? value) {
    if (value is! Map) return null;
    final profileId = value['profileId']?.toString().trim() ?? '';
    final model = value['model']?.toString().trim() ?? '';
    if (profileId.isEmpty ||
        profileId.length > 100 ||
        model.isEmpty ||
        model.length > 160) {
      return null;
    }
    return NazaEmbeddingTarget(profileId: profileId, model: model);
  }
}

final class NazaEmbeddingRuntimeConfig {
  const NazaEmbeddingRuntimeConfig({
    this.mode = NazaEmbeddingMode.localOnly,
    this.localModel = 'naza-local-hybrid-embedding-v3',
    this.targets = const <NazaEmbeddingTarget>[],
    this.dimensions = 128,
    this.remoteBlend = 0.35,
  });

  // The in-house memory index is already persisted at 128 dimensions. Keep
  // this invariant stable so changing embedding providers never invalidates
  // or silently mixes incompatible stored vectors.
  static const int minDimensions = 128;
  static const int maxDimensions = 128;
  static const int maxTargets = 8;

  final NazaEmbeddingMode mode;
  final String localModel;
  final List<NazaEmbeddingTarget> targets;
  final int dimensions;

  /// Weight of the remote ensemble after it is projected into local index
  /// dimensions. The local vector retains the remaining weight.
  final double remoteBlend;

  NazaEmbeddingRuntimeConfig copyWith({
    NazaEmbeddingMode? mode,
    String? localModel,
    Iterable<NazaEmbeddingTarget>? targets,
    int? dimensions,
    double? remoteBlend,
  }) {
    final boundedDimensions = (dimensions ?? this.dimensions)
        .clamp(minDimensions, maxDimensions)
        .toInt();
    return NazaEmbeddingRuntimeConfig(
      mode: mode ?? this.mode,
      localModel: (localModel ?? this.localModel).trim().isEmpty
          ? this.localModel
          : (localModel ?? this.localModel).trim(),
      targets: List<NazaEmbeddingTarget>.unmodifiable(
        (targets ?? this.targets).take(maxTargets),
      ),
      dimensions: boundedDimensions,
      remoteBlend: (remoteBlend ?? this.remoteBlend).clamp(0.0, 1.0).toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-embedding-runtime-v1',
    'mode': mode.name,
    'localModel': localModel,
    'targets': targets.map((target) => target.toJson()).toList(),
    'dimensions': dimensions,
    'remoteBlend': remoteBlend,
  };

  static NazaEmbeddingRuntimeConfig fromJson(Object? value) {
    if (value is! Map) return const NazaEmbeddingRuntimeConfig();
    final modeName = value['mode']?.toString();
    final mode = NazaEmbeddingMode.values.where(
      (item) => item.name == modeName,
    );
    final rawTargets = value['targets'];
    final targets = rawTargets is List
        ? rawTargets
              .map(NazaEmbeddingTarget.fromJson)
              .whereType<NazaEmbeddingTarget>()
        : const <NazaEmbeddingTarget>[];
    return const NazaEmbeddingRuntimeConfig().copyWith(
      mode: mode.isEmpty ? NazaEmbeddingMode.localOnly : mode.first,
      localModel: value['localModel']?.toString(),
      targets: targets,
      dimensions: _boundedInt(value['dimensions']),
      remoteBlend: _boundedDouble(value['remoteBlend']),
    );
  }

  static int? _boundedInt(Object? value) =>
      value is num && value.isFinite ? value.toInt() : null;

  static double? _boundedDouble(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;
}

final class NazaEmbeddingRuntimeStore {
  NazaEmbeddingRuntimeStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String namespace = 'model-embeddings';
  static const String key = 'runtime-v1';
  final NazaSecureDatabase _database;

  Future<NazaEmbeddingRuntimeConfig> load() async {
    return NazaEmbeddingRuntimeConfig.fromJson(
      await _database.readJson(namespace, key),
    );
  }

  Future<void> save(NazaEmbeddingRuntimeConfig config) =>
      _database.writeJson(namespace, key, config.toJson());
}

final class NazaEmbeddingModelCatalog {
  const NazaEmbeddingModelCatalog._();

  static const Map<NazaRemoteProvider, List<String>> remote =
      <NazaRemoteProvider, List<String>>{
        NazaRemoteProvider.openAi: <String>[
          'text-embedding-3-large',
          'text-embedding-3-small',
          'text-embedding-ada-002',
        ],
        NazaRemoteProvider.gemini: <String>[
          'gemini-embedding-2',
          'gemini-embedding-001',
        ],
        NazaRemoteProvider.digitalOcean: <String>[
          'bge-m3',
          'bge-large-en-v1.5',
          'gte-large',
          'multilingual-e5-large',
          'nomic-embed-text-v1.5',
          'qwen3-embedding-8b',
          'qwen3-embedding-4b',
          'qwen3-embedding-0.6b',
        ],
        NazaRemoteProvider.anthropic: <String>[],
        NazaRemoteProvider.meta: <String>[],
        NazaRemoteProvider.custom: <String>[],
      };

  static List<String> forProvider(NazaRemoteProvider provider) =>
      List<String>.unmodifiable(remote[provider] ?? const <String>[]);
}

final class NazaEmbeddingRuntime {
  NazaEmbeddingRuntime._();

  static final NazaEmbeddingRuntime instance = NazaEmbeddingRuntime._();
  final NazaEmbeddingRuntimeStore _store = NazaEmbeddingRuntimeStore();

  Future<List<double>> embed({
    required String text,
    required List<double> Function(String text) localEmbed,
    NazaEmbeddingPurpose purpose = NazaEmbeddingPurpose.document,
  }) async {
    final config = await _store.load();
    final local = _normalize(localEmbed(text));
    if (config.mode == NazaEmbeddingMode.localOnly || config.targets.isEmpty) {
      return _fit(local, config.dimensions);
    }
    final profiles = await NazaRemoteModelCatalog().load();
    final remote = <List<double>>[];
    final gateway = NazaRemoteEmbeddingGateway();
    try {
      for (final target in config.targets) {
        final matches = profiles.where(
          (profile) => profile.id == target.profileId,
        );
        if (matches.isEmpty || !matches.first.enabled) continue;
        try {
          final vector = await gateway.embed(
            profile: matches.first,
            model: target.model,
            text: text,
            dimensions: config.dimensions,
            purpose: purpose,
          );
          remote.add(_fit(_normalize(vector), config.dimensions));
        } catch (_) {
          // One remote embedding failure must not erase local memory. The
          // ensemble continues with healthy targets and local fallback.
        }
      }
    } finally {
      gateway.close();
    }
    if (remote.isEmpty) return _fit(local, config.dimensions);
    final remoteMean = List<double>.filled(config.dimensions, 0);
    for (final vector in remote) {
      for (var i = 0; i < remoteMean.length; i++) {
        remoteMean[i] += vector[i] / remote.length;
      }
    }
    if (config.mode == NazaEmbeddingMode.remoteOnly)
      return _normalize(remoteMean);
    return _normalize(
      List<double>.generate(
        config.dimensions,
        (i) =>
            local[i] * (1 - config.remoteBlend) +
            remoteMean[i] * config.remoteBlend,
      ),
    );
  }

  Future<NazaEmbeddingRuntimeConfig> loadConfig() => _store.load();
  Future<void> saveConfig(NazaEmbeddingRuntimeConfig config) =>
      _store.save(config);

  static List<double> _fit(List<double> vector, int dimensions) {
    if (vector.length == dimensions) return vector;
    final output = List<double>.filled(dimensions, 0);
    for (var index = 0; index < vector.length; index++) {
      final bucket = index % dimensions;
      final sign = ((index * 1103515245 + 12345) & 1) == 0 ? 1.0 : -1.0;
      output[bucket] += vector[index] * sign;
    }
    return _normalize(output);
  }

  static List<double> _normalize(List<double> input) {
    final output = List<double>.from(input);
    var norm = 0.0;
    for (final value in output) norm += value * value;
    if (norm <= 1e-18) return output;
    final scale = 1 / math.sqrt(norm);
    for (var i = 0; i < output.length; i++) output[i] *= scale;
    return output;
  }
}

final class NazaRemoteEmbeddingGateway {
  NazaRemoteEmbeddingGateway({http.Client? client})
    : _client = client ?? http.Client();

  static const int maxInputCharacters = 12000;
  static const int maxResponseBytes = 4 * 1024 * 1024;
  final http.Client _client;

  Future<List<double>> embed({
    required NazaRemoteModelProfile profile,
    required String model,
    required String text,
    required int dimensions,
    required NazaEmbeddingPurpose purpose,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > maxInputCharacters) {
      throw const FormatException('Embedding input is empty or too large.');
    }
    if (profile.apiKey.trim().isEmpty) {
      throw const FormatException('Embedding provider profile has no API key.');
    }
    if (profile.provider == NazaRemoteProvider.anthropic ||
        profile.provider == NazaRemoteProvider.meta) {
      throw UnsupportedError(
        'This provider has no configured embedding endpoint.',
      );
    }
    final endpoint = _endpoint(profile, model);
    NazaProviderGateway.validateEndpoint(
      provider: profile.provider,
      endpoint: endpoint,
      allowCustomEndpoint: profile.allowCustomEndpoint,
    );
    final headers = <String, String>{'content-type': 'application/json'};
    if (profile.provider == NazaRemoteProvider.gemini) {
      headers['x-goog-api-key'] = profile.apiKey;
    } else {
      headers['authorization'] = 'Bearer ${profile.apiKey}';
    }
    final body = profile.provider == NazaRemoteProvider.gemini
        ? <String, Object?>{
            'model': 'models/$model',
            'content': <String, Object?>{
              'parts': <Object?>[
                <String, String>{'text': clean},
              ],
            },
            'embedContentConfig': <String, Object?>{
              'outputDimensionality': dimensions,
              'taskType': purpose == NazaEmbeddingPurpose.query
                  ? 'RETRIEVAL_QUERY'
                  : 'RETRIEVAL_DOCUMENT',
            },
          }
        : <String, Object?>{
            'model': model,
            'input': clean,
            if (model.startsWith('text-embedding-3')) 'dimensions': dimensions,
          };
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    request.followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Embedding provider returned HTTP ${response.statusCode}.',
      );
    }
    final bytes = await _readBounded(
      response,
    ).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(bytes));
    final values = _extractValues(decoded, profile.provider);
    if (values is! List || values.isEmpty) {
      throw const FormatException('Embedding provider returned no vector.');
    }
    final vector = <double>[];
    for (final value in values) {
      if (value is! num || !value.isFinite) {
        throw const FormatException(
          'Embedding provider returned a non-finite vector.',
        );
      }
      vector.add(value.toDouble());
    }
    if (vector.isEmpty) {
      throw const FormatException('Embedding provider returned no vector.');
    }
    return vector;
  }

  Future<Uint8List> _readBounded(http.StreamedResponse response) async {
    if (response.contentLength != null &&
        response.contentLength! > maxResponseBytes) {
      throw const FormatException(
        'Embedding response exceeds the safety limit.',
      );
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response.stream) {
      if (chunk.length > maxResponseBytes - total) {
        throw const FormatException(
          'Embedding response exceeds the safety limit.',
        );
      }
      total += chunk.length;
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  void close() => _client.close();

  static Object? _extractValues(Object? decoded, NazaRemoteProvider provider) {
    if (decoded is! Map) return null;
    if (provider == NazaRemoteProvider.gemini) {
      final embedding = decoded['embedding'];
      return embedding is Map ? embedding['values'] : null;
    }
    final data = decoded['data'];
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    return (data.first as Map)['embedding'];
  }

  static String _endpoint(NazaRemoteModelProfile profile, String model) {
    if (profile.provider == NazaRemoteProvider.gemini) {
      return 'https://generativelanguage.googleapis.com/v1beta/models/$model:embedContent';
    }
    final endpoint = profile.endpoint.trim();
    if (endpoint.endsWith('/chat/completions')) {
      return endpoint.replaceFirst('/chat/completions', '/embeddings');
    }
    if (endpoint.endsWith('/responses')) {
      return endpoint.replaceFirst('/responses', '/embeddings');
    }
    return endpoint;
  }
}
