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

extension NazaRemoteProviderX on NazaRemoteProvider {
  String get label => switch (this) {
    NazaRemoteProvider.openAi => 'OpenAI',
    NazaRemoteProvider.anthropic => 'Anthropic',
    NazaRemoteProvider.gemini => 'Google Gemini',
    NazaRemoteProvider.meta => 'Meta',
    NazaRemoteProvider.digitalOcean => 'DigitalOcean Gradient',
    NazaRemoteProvider.custom => 'Custom OpenAI-compatible',
  };

  String get wireName => name;
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
      NazaRemoteProvider.meta => <String>{},
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
    if (provider == NazaRemoteProvider.meta && !allowCustomEndpoint) {
      throw const FormatException(
        'Meta requires an explicitly approved custom HTTPS endpoint.',
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
