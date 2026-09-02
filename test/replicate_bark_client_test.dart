import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naza_one/audio/replicate_bark_client.dart';

final class _TestClient extends http.BaseClient {
  _TestClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  test(
    'creates pinned Bark prediction and downloads without leaking token',
    () async {
      const token = 'r8_secret_test_token';
      late http.Request create;
      late http.Request download;
      final client = _TestClient((request) async {
        final value = request as http.Request;
        if (request.url.host == 'api.replicate.com') {
          create = value;
          return _json(<String, Object?>{
            'id': 'prediction_123',
            'status': 'succeeded',
            'output': <String, String>{
              'audio_out':
                  'https://replicate.delivery/pbxt/test-performance/audio.wav',
            },
          });
        }
        download = value;
        return http.StreamedResponse(
          Stream<List<int>>.value(<int>[1, 2, 3, 4]),
          200,
          contentLength: 4,
        );
      });
      final bark = ReplicateBarkClient(client: client);

      final bytes = await bark.generate(
        prompt: 'Hello, and welcome.',
        historyPrompt: 'en_speaker_6',
        textTemperature: 0.67,
        waveformTemperature: 0.63,
        apiToken: token,
        isCancelled: () => false,
      );

      expect(bytes, <int>[1, 2, 3, 4]);
      expect(create.followRedirects, isFalse);
      expect(create.headers['authorization'], 'Bearer $token');
      expect(create.headers['prefer'], 'wait=60');
      expect(create.headers['cancel-after'], '3m');
      final body = jsonDecode(create.body) as Map<String, dynamic>;
      expect(body['version'], ReplicateBarkClient.modelVersion);
      expect((body['input'] as Map)['history_prompt'], 'en_speaker_6');
      expect(create.body, isNot(contains(token)));
      expect(download.followRedirects, isFalse);
      expect(download.headers.containsKey('authorization'), isFalse);
    },
  );

  test('polls a processing prediction and preserves its id boundary', () async {
    var polls = 0;
    var delays = 0;
    final client = _TestClient((request) async {
      if (request.url.host == 'replicate.delivery') {
        return http.StreamedResponse(Stream<List<int>>.value(<int>[7, 8]), 200);
      }
      if (request.method == 'POST') {
        return _json(<String, Object?>{
          'id': 'prediction_456',
          'status': 'processing',
          'output': null,
        });
      }
      polls++;
      expect(request.url.path, '/v1/predictions/prediction_456');
      return _json(<String, Object?>{
        'id': 'prediction_456',
        'status': 'succeeded',
        'output': <String, String>{
          'audio_out': 'https://replicate.delivery/test/audio.wav',
        },
      });
    });
    final bark = ReplicateBarkClient(
      client: client,
      delay: (_) async {
        delays++;
      },
    );

    final result = await bark.generate(
      prompt: 'A short second thought.',
      historyPrompt: 'en_speaker_1',
      textTemperature: 0.7,
      waveformTemperature: 0.7,
      apiToken: 'r8_valid_token',
      isCancelled: () => false,
    );

    expect(result, <int>[7, 8]);
    expect(polls, 1);
    expect(delays, 1);
  });

  test('stop callback cancels an active hosted prediction', () async {
    var checks = 0;
    var cancelCalled = false;
    final client = _TestClient((request) async {
      if (request.url.path.endsWith('/cancel')) {
        cancelCalled = true;
        return _json(<String, Object?>{'status': 'canceled'});
      }
      return _json(<String, Object?>{
        'id': 'prediction_789',
        'status': 'processing',
        'output': null,
      });
    });
    final bark = ReplicateBarkClient(client: client, delay: (_) async {});

    await expectLater(
      bark.generate(
        prompt: 'Please stop after this request starts.',
        historyPrompt: 'en_speaker_6',
        textTemperature: 0.7,
        waveformTemperature: 0.7,
        apiToken: 'r8_valid_token',
        isCancelled: () => checks++ > 0,
      ),
      throwsA(isA<ReplicateBarkCancelledException>()),
    );
    expect(cancelCalled, isTrue);
  });

  test('rejects non-Replicate output hosts before downloading', () async {
    var requestCount = 0;
    final client = _TestClient((request) async {
      requestCount++;
      return _json(<String, Object?>{
        'id': 'prediction_bad',
        'status': 'succeeded',
        'output': <String, String>{
          'audio_out': 'https://attacker.example/voice.wav',
        },
      });
    });
    final bark = ReplicateBarkClient(client: client);

    await expectLater(
      bark.generate(
        prompt: 'Do not follow this output.',
        historyPrompt: 'en_speaker_6',
        textTemperature: 0.7,
        waveformTemperature: 0.7,
        apiToken: 'r8_valid_token',
        isCancelled: () => false,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(requestCount, 1);
  });

  test('rejects declared oversized Bark audio without reading it', () async {
    var bodyListened = false;
    final client = _TestClient((request) async {
      if (request.url.host == 'api.replicate.com') {
        return _json(<String, Object?>{
          'id': 'prediction_big',
          'status': 'succeeded',
          'output': <String, String>{
            'audio_out': 'https://replicate.delivery/test/huge.wav',
          },
        });
      }
      return http.StreamedResponse(
        Stream<List<int>>.multi((controller) {
          bodyListened = true;
          controller.add(<int>[1]);
          controller.close();
        }),
        200,
        contentLength: ReplicateBarkClient.maxAudioBytes + 1,
      );
    });
    final bark = ReplicateBarkClient(client: client);

    await expectLater(
      bark.generate(
        prompt: 'Bound this download.',
        historyPrompt: 'en_speaker_6',
        textTemperature: 0.7,
        waveformTemperature: 0.7,
        apiToken: 'r8_valid_token',
        isCancelled: () => false,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(bodyListened, isFalse);
  });
}

http.StreamedResponse _json(Map<String, Object?> value) {
  final bytes = utf8.encode(jsonEncode(value));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    200,
    contentLength: bytes.length,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
