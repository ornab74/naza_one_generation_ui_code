// LLM-CONTEXT:BEGIN
// FILE: test/provider_gateway_security_test.dart
// ROLE: Verifies remote provider egress and bounded-response controls.
// DOMAIN: verification
// SECURITY-INVARIANT: Credentials never follow redirects and responses never materialize beyond the byte cap.
// CHANGE-GUARD: Preserve official-origin validation and both declared and streamed size-limit coverage.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naza_one/main.dart';

final class _TestClient extends http.BaseClient {
  _TestClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

const _profile = NazaRemoteModelProfile(
  id: 'test-profile',
  provider: NazaRemoteProvider.openAi,
  displayName: 'Test',
  model: 'test-model',
  endpoint: 'https://api.openai.com/v1/chat/completions',
  apiKey: 'secret-test-key',
);

void main() {
  test(
    'declared oversized response is rejected before body buffering',
    () async {
      var bodyListened = false;
      late http.BaseRequest captured;
      final client = _TestClient((request) async {
        captured = request;
        return http.StreamedResponse(
          Stream<List<int>>.multi((controller) {
            bodyListened = true;
            controller.add(<int>[1]);
            controller.close();
          }),
          200,
          contentLength: NazaProviderGateway.maxResponseBytes + 1,
        );
      });
      final gateway = NazaProviderGateway(client: client);
      addTearDown(gateway.close);

      await expectLater(
        gateway.send(profile: _profile, prompt: 'hello'),
        throwsA(isA<FormatException>()),
      );
      expect(captured.followRedirects, isFalse);
      expect(bodyListened, isFalse);
    },
  );

  test(
    'chunked response is stopped when accumulated bytes exceed cap',
    () async {
      final oneMiB = Uint8List(1024 * 1024);
      final client = _TestClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable(List<List<int>>.filled(9, oneMiB)),
          200,
        ),
      );
      final gateway = NazaProviderGateway(client: client);
      addTearDown(gateway.close);

      await expectLater(
        gateway.send(profile: _profile, prompt: 'hello'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('provider redirects are rejected and never followed', () async {
    late http.BaseRequest captured;
    final client = _TestClient((request) async {
      captured = request;
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        307,
        headers: const <String, String>{
          'location': 'https://attacker.example/collect',
        },
      );
    });
    final gateway = NazaProviderGateway(client: client);
    addTearDown(gateway.close);

    await expectLater(
      gateway.send(profile: _profile, prompt: 'hello'),
      throwsA(isA<Exception>()),
    );
    expect(captured.followRedirects, isFalse);
  });

  test('official provider origin rejects alternate TLS ports', () {
    expect(
      () => NazaProviderGateway.validateEndpoint(
        provider: NazaRemoteProvider.openAi,
        endpoint: 'https://api.openai.com:8443/v1/chat/completions',
        allowCustomEndpoint: false,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('provider endpoints reject query-string credentials', () {
    expect(
      () => NazaProviderGateway.validateEndpoint(
        provider: NazaRemoteProvider.custom,
        endpoint: 'https://models.example/v1/chat?api_key=secret',
        allowCustomEndpoint: true,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('provider boundary sanitizes outbound and inbound model text', () async {
    late http.BaseRequest captured;
    final client = _TestClient((request) async {
      captured = request;
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, String>{
                    'content': 'safe\u0000\u202Eresponse secret-test-key',
                  },
                },
              ],
            }),
          ),
        ),
        200,
      );
    });
    final gateway = NazaProviderGateway(client: client);
    addTearDown(gateway.close);

    final response = await gateway.send(
      profile: _profile,
      prompt:
          'hello\u0000 api_key=sk-abcdefghijklmnopqrstuvwxyz123456 secret-test-key',
    );

    final requestBody = (captured as http.Request).body;
    expect(requestBody, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
    expect(requestBody, isNot(contains(r'\u0000')));
    expect(response.text, 'saferesponse [REDACTED_CONFIGURED_SECRET]');
  });
}
