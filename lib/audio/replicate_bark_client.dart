// LLM-CONTEXT:BEGIN
// FILE: lib/audio/replicate_bark_client.dart
// ROLE: Bounded HTTP adapter for the pinned Suno Bark model on Replicate.
// DOMAIN: audio
// SECURITY-INVARIANT: Tokens only reach api.replicate.com; output downloads only use Replicate delivery hosts.
// CHANGE-GUARD: Preserve redirect rejection, response limits, cancellation, and the pinned model version.
// DOCS: See /docs/llm-context-schema.md and /lib/mermaid.md.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

final class ReplicateBarkClient {
  ReplicateBarkClient({
    required http.Client client,
    Future<void> Function(Duration)? delay,
  }) : _client = client,
       _delay = delay ?? Future<void>.delayed;

  static const String modelVersion =
      'suno-ai/bark:b76242b40d67c76ab6742e987628a2a9ac019e11d56ab96c4e91ce03b79b2787';
  static final Uri _predictionsUri = Uri.https(
    'api.replicate.com',
    '/v1/predictions',
  );
  static const int _maxJsonBytes = 1024 * 1024;
  static const int maxAudioBytes = 16 * 1024 * 1024;
  static const Duration _predictionDeadline = Duration(minutes: 3);

  final http.Client _client;
  final Future<void> Function(Duration) _delay;
  final Map<String, String> _activePredictions = <String, String>{};

  Future<Uint8List> generate({
    required String prompt,
    required String historyPrompt,
    required double textTemperature,
    required double waveformTemperature,
    required String apiToken,
    required bool Function() isCancelled,
  }) async {
    _validateInputs(
      prompt: prompt,
      historyPrompt: historyPrompt,
      textTemperature: textTemperature,
      waveformTemperature: waveformTemperature,
      apiToken: apiToken,
    );
    if (isCancelled()) throw const ReplicateBarkCancelledException();

    final create = http.Request('POST', _predictionsUri)
      ..followRedirects = false
      ..headers.addAll(<String, String>{
        'authorization': 'Bearer $apiToken',
        'content-type': 'application/json',
        'prefer': 'wait=60',
        'cancel-after': '3m',
      })
      ..body = jsonEncode(<String, Object?>{
        'version': modelVersion,
        'input': <String, Object?>{
          'prompt': prompt,
          'history_prompt': historyPrompt,
          'text_temp': textTemperature,
          'waveform_temp': waveformTemperature,
          'output_full': false,
        },
      });
    var prediction = await _sendJson(
      create,
      timeout: const Duration(seconds: 70),
    );
    final id = prediction['id']?.toString() ?? '';
    if (!RegExp(r'^[a-zA-Z0-9_-]{4,100}$').hasMatch(id)) {
      throw const FormatException('Replicate returned no prediction id.');
    }
    _activePredictions[id] = apiToken;
    final timer = Stopwatch()..start();
    try {
      while (true) {
        if (isCancelled()) {
          await _cancel(id, apiToken);
          throw const ReplicateBarkCancelledException();
        }
        final audioUri = _audioUri(prediction['output']);
        if (audioUri != null) {
          return _downloadAudio(audioUri);
        }
        final status = prediction['status']?.toString().toLowerCase() ?? '';
        if (status == 'failed') {
          throw StateError(
            'Bark generation failed${_safeRemoteDetail(prediction['error'])}.',
          );
        }
        if (status == 'canceled' || status == 'cancelled') {
          throw const ReplicateBarkCancelledException();
        }
        if (status == 'succeeded' || status == 'successful') {
          throw const FormatException(
            'Replicate completed without a Bark audio file.',
          );
        }
        if (status != 'starting' && status != 'processing') {
          throw const FormatException('Replicate returned an unknown status.');
        }
        if (timer.elapsed >= _predictionDeadline) {
          await _cancel(id, apiToken);
          throw TimeoutException('Bark generation exceeded three minutes.');
        }
        await _delay(const Duration(milliseconds: 900));
        final poll =
            http.Request(
                'GET',
                Uri.https('api.replicate.com', '/v1/predictions/$id'),
              )
              ..followRedirects = false
              ..headers['authorization'] = 'Bearer $apiToken';
        prediction = await _sendJson(
          poll,
          timeout: const Duration(seconds: 20),
        );
      }
    } finally {
      _activePredictions.remove(id);
    }
  }

  Future<void> cancelActive() async {
    final active = Map<String, String>.from(_activePredictions);
    await Future.wait<void>([
      for (final entry in active.entries) _cancel(entry.key, entry.value),
    ]);
  }

  Future<Map<String, dynamic>> _sendJson(
    http.Request request, {
    required Duration timeout,
  }) async {
    final bytes = await _sendBounded(
      request,
      maxBytes: _maxJsonBytes,
      timeout: timeout,
    );
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map) {
      throw const FormatException('Replicate returned invalid JSON.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Uint8List> _downloadAudio(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !_isDeliveryHost(uri.host)) {
      throw const FormatException('Replicate returned an unsafe audio URL.');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    return _sendBounded(
      request,
      maxBytes: maxAudioBytes,
      timeout: const Duration(seconds: 45),
    );
  }

  Future<Uint8List> _sendBounded(
    http.Request request, {
    required int maxBytes,
    required Duration timeout,
  }) async {
    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw StateError('Replicate redirects are not allowed.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Replicate returned HTTP ${response.statusCode}.');
    }
    if (response.contentLength != null && response.contentLength! > maxBytes) {
      throw const FormatException('Replicate response exceeds its size limit.');
    }
    final output = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      if (chunk.length > maxBytes - total) {
        throw const FormatException(
          'Replicate response exceeds its size limit.',
        );
      }
      total += chunk.length;
      output.add(chunk);
    }
    return output.takeBytes();
  }

  Future<void> _cancel(String id, String token) async {
    try {
      final request =
          http.Request(
              'POST',
              Uri.https('api.replicate.com', '/v1/predictions/$id/cancel'),
            )
            ..followRedirects = false
            ..headers['authorization'] = 'Bearer $token';
      await _sendBounded(
        request,
        maxBytes: _maxJsonBytes,
        timeout: const Duration(seconds: 12),
      );
    } on Object {
      // Best effort: cancellation must not mask the user's stop action.
    }
  }

  static Uri? _audioUri(Object? output) {
    final raw = output is Map ? output['audio_out'] : null;
    if (raw is! String || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  static bool _isDeliveryHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'replicate.delivery' ||
        lower.endsWith('.replicate.delivery');
  }

  static String _safeRemoteDetail(Object? value) {
    if (value == null) return '';
    final cleaned = value
        .toString()
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    final bounded = cleaned.length <= 180 ? cleaned : cleaned.substring(0, 180);
    return ': $bounded';
  }

  static void _validateInputs({
    required String prompt,
    required String historyPrompt,
    required double textTemperature,
    required double waveformTemperature,
    required String apiToken,
  }) {
    if (prompt.trim().isEmpty || prompt.length > 600) {
      throw const FormatException('Bark prompt is empty or too long.');
    }
    if (!RegExp(
      r'^(?:v2/)?(?:en|de|es|fr|hi|it|ja|ko|pl|pt|ru|tr|zh)_speaker_[0-9]{1,2}$',
    ).hasMatch(historyPrompt)) {
      throw const FormatException('Invalid Bark speaker preset.');
    }
    if (!textTemperature.isFinite ||
        textTemperature < 0.35 ||
        textTemperature > 1 ||
        !waveformTemperature.isFinite ||
        waveformTemperature < 0.35 ||
        waveformTemperature > 1) {
      throw const FormatException('Invalid Bark generation temperature.');
    }
    if (apiToken.length < 8 ||
        apiToken.length > 4096 ||
        apiToken.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
      throw const FormatException(
        'Add a valid Replicate API token in Voice settings.',
      );
    }
  }
}

final class ReplicateBarkCancelledException implements Exception {
  const ReplicateBarkCancelledException();
}
