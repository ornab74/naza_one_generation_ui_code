import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naza_one/main.dart';

const _profile = NazaRemoteModelProfile(
  id: 'astra-test',
  provider: NazaRemoteProvider.openAi,
  displayName: 'Astra',
  model: 'gpt-6-astra',
  endpoint: 'https://api.openai.com/v1/chat/completions',
  apiKey: 'test-only-api-key',
);

void main() {
  test('Astra leads the OpenAI model picker', () {
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.openAi).first,
      'gpt-6-astra',
    );
  });

  test('old profiles default to Light and saved effort survives reload', () {
    final legacy = _profile.toJson()..remove('reasoningEffort');
    expect(
      NazaRemoteModelProfile.fromJson(legacy)!.reasoningEffort,
      NazaOpenAiReasoningEffort.light,
    );
    for (final effort in NazaOpenAiReasoningEffort.values) {
      final saved = _profile.copyWith(reasoningEffort: effort).toJson();
      expect(NazaRemoteModelProfile.fromJson(saved)!.reasoningEffort, effort);
    }
  });

  for (final effort in NazaOpenAiReasoningEffort.values) {
    test('Astra sends ${effort.label} using its API value', () async {
      final gateway = NazaProviderGateway(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'gpt-6-astra');
          expect(body['reasoning_effort'], effort.wireName);
          expect(body.containsKey('temperature'), isFalse);
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Done'},
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(gateway.close);
      final response = await gateway.send(
        profile: _profile.copyWith(reasoningEffort: effort),
        prompt: 'Hello',
      );
      expect(response.text, 'Done');
    });
  }

  test('other models do not receive Astra reasoning parameters', () async {
    final gateway = NazaProviderGateway(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('reasoning_effort'), isFalse);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Done'},
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(gateway.close);
    await gateway.send(
      profile: _profile.copyWith(model: 'gpt-4.1'),
      prompt: 'Hello',
    );
  });
}
