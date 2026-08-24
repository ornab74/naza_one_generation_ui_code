// LLM-CONTEXT:BEGIN
// FILE: lib/model/provider_gateway.dart
// ROLE: Secure boundary for user-selected remote model providers.
// SECURITY-INVARIANT: API credentials are encrypted in the vault, never logged,
// and are sent only to validated HTTPS origins with bounded request/response IO.
// CHANGE-GUARD: Keep provider parsing fail-closed and preserve local Gemma as
// the default when no remote profile is explicitly selected.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../security/secure_database.dart';

enum NazaRemoteProvider {
  openAi,
  anthropic,
  gemini,
  meta,
  digitalOcean,
  custom,
}

enum NazaModelFeature {
  chat,
  roadScanner,
  foodScanner,
  foodRecipes,
  foodShelf,
  foodBake,
  healthToday,
  healthMedications,
  healthDental,
  healthExercise,
  healthRecovery,
  healthIntelligence,
  garden,
  gardenPlantId,
  gardenMushroomId,
  gardenLog,
  walking,
  findIt,
  drive,
  predict,
  heartFlow,
  chess,
  bookForge,
  knowledgeVault,
  memoryObservatory,
  projects,
  workflowBuilder,
  agenticCoding,
}

extension NazaModelFeatureX on NazaModelFeature {
  String get label => switch (this) {
    NazaModelFeature.chat => 'Chat',
    NazaModelFeature.roadScanner => 'Road Scanner',
    NazaModelFeature.foodScanner => 'Food / Water Scanner',
    NazaModelFeature.foodRecipes => 'Food Recipes',
    NazaModelFeature.foodShelf => 'Food Shelf',
    NazaModelFeature.foodBake => 'Bake Lab',
    NazaModelFeature.healthToday => 'Health Today',
    NazaModelFeature.healthMedications => 'Medications',
    NazaModelFeature.healthDental => 'Dental',
    NazaModelFeature.healthExercise => 'Exercise',
    NazaModelFeature.healthRecovery => 'Recovery',
    NazaModelFeature.healthIntelligence => 'Health Intelligence',
    NazaModelFeature.garden => 'Garden',
    NazaModelFeature.gardenPlantId => 'Plant ID',
    NazaModelFeature.gardenMushroomId => 'Mushroom ID',
    NazaModelFeature.gardenLog => 'Garden Log',
    NazaModelFeature.walking => 'Walking',
    NazaModelFeature.findIt => 'Find It',
    NazaModelFeature.drive => 'Drive',
    NazaModelFeature.predict => 'Predict',
    NazaModelFeature.heartFlow => 'Heart Flow',
    NazaModelFeature.chess => 'Chess Agent',
    NazaModelFeature.bookForge => 'BookForge',
    NazaModelFeature.knowledgeVault => 'Knowledge Vault',
    NazaModelFeature.memoryObservatory => 'Memory Observatory',
    NazaModelFeature.projects => 'Projects',
    NazaModelFeature.workflowBuilder => 'Workflow Builder',
    NazaModelFeature.agenticCoding => 'Code Foundry',
  };

  String get editorialTitle => switch (this) {
    NazaModelFeature.chat => 'Private Conversation Atelier',
    NazaModelFeature.roadScanner => 'Roadway Risk Observatory',
    NazaModelFeature.foodScanner => 'Kitchen Provenance Scanner',
    NazaModelFeature.foodRecipes => 'Pantry-to-Plate Atelier',
    NazaModelFeature.foodShelf => 'Pantry Inventory Ledger',
    NazaModelFeature.foodBake => 'Thermal Craft Bench',
    NazaModelFeature.healthToday => 'Personal Health Studio',
    NazaModelFeature.healthMedications => 'Medication Stewardship Desk',
    NazaModelFeature.healthDental => 'Oral Wellness Studio',
    NazaModelFeature.healthExercise => 'Adaptive Movement Lab',
    NazaModelFeature.healthRecovery => 'Resilience & Recovery Studio',
    NazaModelFeature.healthIntelligence => 'Care Signal Synthesis Lab',
    NazaModelFeature.garden => 'Living Garden Observatory',
    NazaModelFeature.gardenPlantId => 'Botanical Signal Desk',
    NazaModelFeature.gardenMushroomId => 'Fungal Safety Atlas',
    NazaModelFeature.gardenLog => 'Living Systems Field Log',
    NazaModelFeature.walking => 'Walking Rhythm Observatory',
    NazaModelFeature.findIt => 'Local Discovery Atlas',
    NazaModelFeature.drive => 'Route & Stop Strategy Desk',
    NazaModelFeature.predict => 'Scenario Forecasting Studio',
    NazaModelFeature.heartFlow => 'Recovery & Readiness Compass',
    NazaModelFeature.chess => 'Tactical Boardroom',
    NazaModelFeature.bookForge => 'Long-Form Narrative Foundry',
    NazaModelFeature.knowledgeVault => 'Evidence Provenance Vault',
    NazaModelFeature.memoryObservatory => 'Context Allocation Observatory',
    NazaModelFeature.projects => 'Project Constellation Studio',
    NazaModelFeature.workflowBuilder => 'Approval Logic Foundry',
    NazaModelFeature.agenticCoding => 'Agentic Code Foundry',
  };

  String get zone => switch (this) {
    NazaModelFeature.chat => 'Core Intelligence',
    NazaModelFeature.roadScanner ||
    NazaModelFeature.drive => 'Mobility Intelligence',
    NazaModelFeature.foodScanner ||
    NazaModelFeature.foodRecipes ||
    NazaModelFeature.foodShelf ||
    NazaModelFeature.foodBake => 'Food Intelligence',
    NazaModelFeature.healthToday ||
    NazaModelFeature.healthMedications ||
    NazaModelFeature.healthDental ||
    NazaModelFeature.healthIntelligence => 'Care Intelligence',
    NazaModelFeature.healthExercise ||
    NazaModelFeature.walking => 'Movement Intelligence',
    NazaModelFeature.healthRecovery ||
    NazaModelFeature.heartFlow => 'Recovery Intelligence',
    NazaModelFeature.garden ||
    NazaModelFeature.gardenPlantId ||
    NazaModelFeature.gardenMushroomId ||
    NazaModelFeature.gardenLog => 'Nature Intelligence',
    NazaModelFeature.findIt => 'Place Intelligence',
    NazaModelFeature.predict => 'Futures Intelligence',
    NazaModelFeature.chess => 'Game Intelligence',
    NazaModelFeature.bookForge => 'Literary Intelligence',
    NazaModelFeature.knowledgeVault => 'Knowledge Intelligence',
    NazaModelFeature.memoryObservatory => 'Memory Intelligence',
    NazaModelFeature.projects => 'Work Intelligence',
    NazaModelFeature.workflowBuilder => 'Workflow Intelligence',
    NazaModelFeature.agenticCoding => 'Execution Intelligence',
  };
}

final class NazaModelRoutingConfig {
  const NazaModelRoutingConfig({
    this.defaultProfileId,
    this.featureProfiles = const {},
  });

  final String? defaultProfileId;
  final Map<NazaModelFeature, String> featureProfiles;

  String? profileFor(NazaModelFeature feature) =>
      featureProfiles[feature] ?? defaultProfileId;
}

final class NazaModelRoutingStore {
  static const String localProfileId = 'local-gemma';
  static const String _namespace = 'remote-model-providers';
  static const String _key = 'routing-v1';

  NazaModelRoutingStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  final NazaSecureDatabase _database;

  Future<NazaModelRoutingConfig> load() async {
    final raw = await _database.readJson(_namespace, _key);
    if (raw is! Map) return const NazaModelRoutingConfig();
    final defaultId = raw['defaultProfileId']?.toString().trim();
    final routes = <NazaModelFeature, String>{};
    final storedRoutes = raw['featureProfiles'];
    if (storedRoutes is Map) {
      for (final feature in NazaModelFeature.values) {
        final id = storedRoutes[feature.name]?.toString().trim();
        if (id != null && id.isNotEmpty) routes[feature] = id;
      }
      // Preserve settings created by the earlier grouped routing UI.
      const legacy = <String, NazaModelFeature>{
        'health': NazaModelFeature.healthToday,
        'food': NazaModelFeature.foodScanner,
        'road': NazaModelFeature.roadScanner,
        'games': NazaModelFeature.chess,
        'writing': NazaModelFeature.bookForge,
        'intelligence': NazaModelFeature.knowledgeVault,
      };
      for (final entry in legacy.entries) {
        if (routes.containsKey(entry.value)) continue;
        final id = storedRoutes[entry.key]?.toString().trim();
        if (id != null && id.isNotEmpty) routes[entry.value] = id;
      }
    }
    return NazaModelRoutingConfig(
      defaultProfileId: defaultId?.isNotEmpty == true ? defaultId : null,
      featureProfiles: Map.unmodifiable(routes),
    );
  }

  Future<void> save(NazaModelRoutingConfig config) =>
      _database.writeJson(_namespace, _key, <String, Object?>{
        'defaultProfileId': config.defaultProfileId,
        'featureProfiles': <String, String>{
          for (final entry in config.featureProfiles.entries)
            entry.key.name: entry.value,
        },
      });
}

extension NazaRemoteProviderX on NazaRemoteProvider {
  String get label => switch (this) {
    NazaRemoteProvider.openAi => 'OpenAI',
    NazaRemoteProvider.anthropic => 'Anthropic',
    NazaRemoteProvider.gemini => 'Google Gemini',
    NazaRemoteProvider.meta => 'Meta Muse',
    NazaRemoteProvider.digitalOcean => 'DigitalOcean Gradient',
    NazaRemoteProvider.custom => 'Custom OpenAI-compatible',
  };

  String get wireName => name;
}

/// Curated model identifiers surfaced by the settings picker. Availability is
/// still account/region dependent, so users can always enter a custom model
/// identifier and the provider remains the final authority.
final class NazaProviderModelCatalog {
  const NazaProviderModelCatalog._();

  static const Map<NazaRemoteProvider, List<String>> _models =
      <NazaRemoteProvider, List<String>>{
        NazaRemoteProvider.openAi: <String>[
          'gpt-5.6-sol',
          'gpt-5.6-terra',
          'gpt-5.6-luna',
          'gpt-5.2',
          'gpt-5.1',
          'gpt-5',
          'gpt-5-mini',
          'gpt-5-nano',
          'gpt-5.1-codex',
          'gpt-5.1-codex-max',
          'gpt-5-codex',
          'gpt-5.1-codex-mini',
          'o3',
          'o3-pro',
          'o4-mini',
          'o3-deep-research',
          'o4-mini-deep-research',
          'gpt-4.1',
          'gpt-4.1-mini',
          'gpt-4.1-nano',
          'gpt-realtime',
          'gpt-realtime-mini',
          'gpt-audio',
          'gpt-audio-mini',
          'gpt-4o-mini-tts',
          'gpt-4o-mini-tts-2025-12-15',
          'gpt-realtime-2.1',
          'gpt-realtime-translate',
          'gpt-live-transcribe',
          'gpt-image-1',
          'gpt-oss-120b',
          'gpt-oss-20b',
        ],
        NazaRemoteProvider.anthropic: <String>[
          'claude-opus-4-1',
          'claude-opus-4-0',
          'claude-sonnet-4-0',
          'claude-3-7-sonnet-latest',
          'claude-3-5-sonnet-latest',
          'claude-3-5-haiku-latest',
          'claude-3-haiku-20240307',
        ],
        NazaRemoteProvider.gemini: <String>[
          'gemini-3.7-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash',
          'gemini-3.5-flash-lite',
          'gemini-3.1-flash-lite',
          'gemini-3.1-pro-preview',
          'gemini-3-flash-preview',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-3.1-flash-image',
          'gemini-3-pro-image',
          'gemini-2.5-flash-native-audio-preview-12-2025',
          'gemini-2.5-flash-preview-tts',
          'veo-3.1-generate-preview',
          'deep-research-preview-04-2026',
          'gemini-embedding-2-preview',
          'gemini-embedding-001',
        ],
        NazaRemoteProvider.meta: <String>[
          'muse-spark-1.2',
          'muse-spark-1.1',
          'llama-4-maverick',
          'llama-4-scout',
        ],
        NazaRemoteProvider.digitalOcean: <String>[
          // Keep legacy/custom identifiers for backwards-compatible saved
          // profiles, then include the current DigitalOcean catalog.
          'kimi-k3',
          'kimi-k2.6',
          'kimi-k2.5',
          'llama-3.3-70b-instruct',
          'llama-3.1-70b-instruct',
          'qwen2.5-72b-instruct',
          'deepseek-r1',
          'deepseek-v4-pro',
          'anthropic-claude-fable-5',
          'anthropic-claude-haiku-4.5',
          'anthropic-claude-opus-5',
          'anthropic-claude-opus-4.8',
          'anthropic-claude-opus-4.7',
          'anthropic-claude-opus-4.6',
          'anthropic-claude-opus-4.5',
          'anthropic-claude-5-sonnet',
          'anthropic-claude-4.6-sonnet',
          'anthropic-claude-4.5-sonnet',
          'arcee-trinity-large-thinking',
          'fal-ai/fast-sdxl',
          'fal-ai/flux/schnell',
          'fal-ai/stable-audio-25/text-to-audio',
          'fal-ai/elevenlabs/tts/multilingual-v2',
          'openai-gpt-5.6-sol',
          'openai-gpt-5.6-terra',
          'openai-gpt-5.6-luna',
          'openai-gpt-5.5',
          'openai-gpt-5.4',
          'openai-gpt-5.4-mini',
          'openai-gpt-5.4-nano',
          'openai-gpt-5.4-pro',
          'openai-gpt-5.3-codex',
          'openai-gpt-5.2',
          'openai-gpt-5.2-pro',
          'openai-gpt-5',
          'openai-gpt-5-mini',
          'openai-gpt-5-nano',
          'openai-gpt-4.1',
          'openai-gpt-4o',
          'openai-gpt-4o-mini',
          'openai-o1',
          'openai-o3',
          'openai-o3-mini',
          'openai-gpt-image-1',
          'openai-gpt-image-1.5',
          'openai-gpt-image-2',
          'qwen3.8-max',
          'qwen-2.5-14b-instruct',
          'qwen3.5-397b-a17b',
          'qwen3-tts-voicedesign',
          'wan2-2-t2v-a14b',
          'deepseek-v4-pro-0813',
          'deepseek-v4-flash-0731',
          'deepseek-4-flash',
          'deepseek-3.2',
          'deepseek-v3',
          'gemma-4-31B-it',
          'minimax-m2.5',
          'llama3-8b-instruct',
          'llama-4-maverick',
          'ministral-3-8b-instruct-2512',
          'mistral-3-14B',
          'mistral-7b-instruct-v0.3',
          'nemotron-3-ultra-550b',
          'nvidia-nemotron-3-super-120b',
          'nemotron-3-nano-30b',
          'nemotron-3-nano-omni',
          'nemotron-nano-12b-v2-vl',
          'openai-gpt-oss-120b',
          'openai-gpt-oss-20b',
          'stable-diffusion-3.5-large',
          'mimo-v2.5-pro',
          'glm-5.2',
          'glm-5.1',
          'glm-5',
          'gte-large-en-v1.5',
          'qwen3-embedding-0.6b',
          'bge-m3',
          'e5-large-multilingual',
          'e5-large-v2',
          'all-MiniLM-L6-v2',
          'multi-qa-mpnet-base-dot-v1',
          'bge-reranker-v2-m3',
        ],
        NazaRemoteProvider.custom: <String>[],
      };

  static List<String> forProvider(NazaRemoteProvider provider) =>
      List<String>.unmodifiable(_models[provider] ?? const <String>[]);
}

final class NazaRemoteModelProfile {
  final String id;
  final NazaRemoteProvider provider;
  final String displayName;
  final String model;
  final String endpoint;
  final String apiKey;
  final bool enabled;
  final bool allowCustomEndpoint;

  const NazaRemoteModelProfile({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.model,
    required this.endpoint,
    required this.apiKey,
    this.enabled = true,
    this.allowCustomEndpoint = false,
  });

  NazaRemoteModelProfile copyWith({
    String? displayName,
    String? model,
    String? endpoint,
    String? apiKey,
    bool? enabled,
    bool? allowCustomEndpoint,
  }) => NazaRemoteModelProfile(
    id: id,
    provider: provider,
    displayName: displayName ?? this.displayName,
    model: model ?? this.model,
    endpoint: endpoint ?? this.endpoint,
    apiKey: apiKey ?? this.apiKey,
    enabled: enabled ?? this.enabled,
    allowCustomEndpoint: allowCustomEndpoint ?? this.allowCustomEndpoint,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'provider': provider.wireName,
    'displayName': displayName,
    'model': model,
    'endpoint': endpoint,
    // This object is written only through NazaSecureDatabase.
    'apiKey': apiKey,
    'enabled': enabled,
    'allowCustomEndpoint': allowCustomEndpoint,
  };

  static NazaRemoteModelProfile? fromJson(Object? value) {
    if (value is! Map) return null;
    final providerName = value['provider']?.toString();
    final provider = NazaRemoteProvider.values.where(
      (p) => p.name == providerName,
    );
    final id = value['id']?.toString().trim() ?? '';
    final model = value['model']?.toString().trim() ?? '';
    final endpoint = value['endpoint']?.toString().trim() ?? '';
    if (id.isEmpty || model.isEmpty || endpoint.isEmpty || provider.isEmpty)
      return null;
    return NazaRemoteModelProfile(
      id: id,
      provider: provider.first,
      displayName: value['displayName']?.toString().trim().isNotEmpty == true
          ? value['displayName'].toString().trim()
          : model,
      model: model,
      endpoint: endpoint,
      apiKey: value['apiKey']?.toString() ?? '',
      enabled: value['enabled'] != false,
      allowCustomEndpoint: value['allowCustomEndpoint'] == true,
    );
  }
}

final class NazaRemoteModelCatalog {
  static const int maxProfiles = 32;
  static const int maxModelIdLength = 160;
  static const String _namespace = 'remote-model-providers';
  static const String _key = 'profiles-v1';

  NazaRemoteModelCatalog({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;
  final NazaSecureDatabase _database;

  Future<List<NazaRemoteModelProfile>> load() async {
    final raw = await _database.readJson(_namespace, _key);
    if (raw is! List) return <NazaRemoteModelProfile>[];
    return raw
        .map(NazaRemoteModelProfile.fromJson)
        .whereType<NazaRemoteModelProfile>()
        .take(maxProfiles)
        .toList(growable: false);
  }

  Future<void> save(Iterable<NazaRemoteModelProfile> profiles) async {
    final bounded = profiles
        .take(maxProfiles)
        .map((profile) {
          _validateProfile(profile);
          return profile.toJson();
        })
        .toList(growable: false);
    await _database.writeJson(_namespace, _key, bounded);
  }

  Future<void> upsert(NazaRemoteModelProfile profile) async {
    final profiles = await load();
    final next = <NazaRemoteModelProfile>[
      for (final item in profiles)
        if (item.id != profile.id) item,
      profile,
    ];
    await save(next);
  }

  Future<void> remove(String id) async {
    final profiles = await load();
    await save(profiles.where((profile) => profile.id != id));
  }

  static void _validateProfile(NazaRemoteModelProfile profile) {
    if (profile.id.trim().isEmpty || profile.id.length > 100) {
      throw const FormatException('Invalid remote model profile id.');
    }
    if (profile.model.trim().isEmpty ||
        profile.model.length > maxModelIdLength) {
      throw const FormatException('Invalid remote model identifier.');
    }
    if (profile.apiKey.trim().isEmpty) {
      throw const FormatException('Remote model profile has no API key.');
    }
    NazaProviderGateway.validateEndpoint(
      provider: profile.provider,
      endpoint: profile.endpoint,
      allowCustomEndpoint: profile.allowCustomEndpoint,
    );
  }
}

final class NazaRemoteModelResponse {
  final String text;
  final String provider;
  final String model;
  const NazaRemoteModelResponse({
    required this.text,
    required this.provider,
    required this.model,
  });
}

/// One bounded adapter for all supported remote request shapes.
final class NazaProviderGateway {
  NazaProviderGateway({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  static const int maxPromptCharacters = 120000;
  static const int maxResponseBytes = 8 * 1024 * 1024;

  Future<NazaRemoteModelResponse> send({
    required NazaRemoteModelProfile profile,
    required String prompt,
    String? systemInstruction,
  }) async {
    NazaRemoteModelCatalog._validateProfile(profile);
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty || cleanPrompt.length > maxPromptCharacters) {
      throw const FormatException(
        'Prompt is empty or exceeds the remote limit.',
      );
    }
    final uri = Uri.parse(profile.endpoint);
    final headers = <String, String>{'content-type': 'application/json'};
    final body = switch (profile.provider) {
      NazaRemoteProvider.anthropic => _anthropicBody(
        profile,
        cleanPrompt,
        systemInstruction,
      ),
      NazaRemoteProvider.gemini => _geminiBody(
        profile,
        cleanPrompt,
        systemInstruction,
      ),
      _ => _openAiBody(profile, cleanPrompt, systemInstruction),
    };
    if (profile.provider == NazaRemoteProvider.gemini) {
      headers['x-goog-api-key'] = profile.apiKey;
    } else if (profile.provider == NazaRemoteProvider.anthropic) {
      headers['x-api-key'] = profile.apiKey;
      headers['anthropic-version'] = '2023-06-01';
    } else {
      headers['authorization'] = 'Bearer ${profile.apiKey}';
    }
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final responseBytes = await _sendBounded(
      request,
    ).timeout(const Duration(seconds: 45));
    final decoded = jsonDecode(
      utf8.decode(responseBytes, allowMalformed: false),
    );
    final text = _extractText(profile.provider, decoded).trim();
    if (text.isEmpty)
      throw const FormatException('Remote provider returned no text.');
    return NazaRemoteModelResponse(
      text: text,
      provider: profile.provider.label,
      model: profile.model,
    );
  }

  static void validateEndpoint({
    required NazaRemoteProvider provider,
    required String endpoint,
    required bool allowCustomEndpoint,
  }) {
    if (allowCustomEndpoint && provider != NazaRemoteProvider.custom) {
      throw const FormatException(
        'Only the Custom provider may use a custom endpoint.',
      );
    }
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException(
        'Remote model endpoints must use HTTPS without embedded credentials.',
      );
    }
    final allowed = switch (provider) {
      NazaRemoteProvider.openAi => <String>{'api.openai.com'},
      NazaRemoteProvider.anthropic => <String>{'api.anthropic.com'},
      NazaRemoteProvider.gemini => <String>{
        'generativelanguage.googleapis.com',
      },
      NazaRemoteProvider.digitalOcean => <String>{
        'inference.do-ai.run',
        'api.digitalocean.com',
      },
      NazaRemoteProvider.meta => <String>{'api.meta.ai'},
      NazaRemoteProvider.custom => <String>{},
    };
    if (!allowCustomEndpoint && !allowed.contains(uri.host.toLowerCase())) {
      throw const FormatException(
        'This provider requires its official HTTPS origin.',
      );
    }
    if (!allowCustomEndpoint && uri.hasPort && uri.port != 443) {
      throw const FormatException(
        'Official provider endpoints must use HTTPS port 443.',
      );
    }
  }

  Future<Uint8List> _sendBounded(http.Request request) async {
    final response = await _client.send(request);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw HttpException(
        'Remote provider redirects are not allowed (HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Remote provider returned HTTP ${response.statusCode}.',
      );
    }
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maxResponseBytes) {
      throw const FormatException('Remote response exceeds the safety limit.');
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response.stream) {
      if (chunk.length > maxResponseBytes - total) {
        throw const FormatException(
          'Remote response exceeds the safety limit.',
        );
      }
      total += chunk.length;
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  void close() => _client.close();

  static Map<String, Object?> _openAiBody(
    NazaRemoteModelProfile p,
    String prompt,
    String? system,
  ) => <String, Object?>{
    'model': p.model,
    'messages': <Object?>[
      if (system?.trim().isNotEmpty == true)
        <String, String>{'role': 'system', 'content': system!.trim()},
      <String, String>{'role': 'user', 'content': prompt},
    ],
  };

  static Map<String, Object?> _anthropicBody(
    NazaRemoteModelProfile p,
    String prompt,
    String? system,
  ) => <String, Object?>{
    'model': p.model,
    'max_tokens': 4096,
    if (system?.trim().isNotEmpty == true) 'system': system!.trim(),
    'messages': <Object?>[
      <String, String>{'role': 'user', 'content': prompt},
    ],
  };

  static Map<String, Object?> _geminiBody(
    NazaRemoteModelProfile p,
    String prompt,
    String? system,
  ) => <String, Object?>{
    'contents': <Object?>[
      <String, Object?>{
        'role': 'user',
        'parts': <Object?>[
          <String, String>{'text': '${system ?? ''}\n$prompt'},
        ],
      },
    ],
  };

  static String _extractText(NazaRemoteProvider provider, Object? value) {
    if (value is! Map) return '';
    if (provider == NazaRemoteProvider.anthropic) {
      final content = value['content'];
      if (content is List && content.isNotEmpty && content.first is Map)
        return (content.first as Map)['text']?.toString() ?? '';
    }
    if (provider == NazaRemoteProvider.gemini) {
      final candidates = value['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final parts = (candidates.first as Map?)?['content'];
        if (parts is Map && parts['parts'] is List)
          return (parts['parts'] as List)
              .map((part) => (part as Map?)?['text'] ?? '')
              .join();
      }
    }
    final choices = value['choices'];
    if (choices is List && choices.isNotEmpty)
      return ((choices.first as Map?)?['message'] as Map?)?['content']
              ?.toString() ??
          '';
    return '';
  }
}
