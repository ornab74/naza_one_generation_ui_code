import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../model/provider_gateway.dart';

/// GA Realtime voice session boundary.
///
/// This is intentionally separate from request-based WAV generation: Realtime
/// is a live session for low-latency text/audio interaction, while the WAV
/// reader remains the durable export path. Audio deltas are retained so a
/// completed session can be exported by a platform audio sink later.
final class OpenAiRealtimeVoiceSession {
  WebSocket? _socket;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  bool _paused = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _socket != null;
  bool get paused => _paused;

  Future<void> connect({
    String model = 'gpt-realtime-2.1',
    String voice = 'marin',
    String instructions =
        'Read naturally, warmly, and clearly. Preserve the supplied text exactly; do not summarize.',
  }) async {
    await close();
    final profile = await _openAiProfile();
    if (profile == null) {
      throw StateError(
        'Add an enabled OpenAI profile with an API key in Settings.',
      );
    }
    final uri = Uri.parse(
      'wss://api.openai.com/v1/realtime?model=${Uri.encodeQueryComponent(model)}',
    );
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {'Authorization': 'Bearer ${profile.apiKey}'},
    );
    _socket = socket;
    socket.listen(
      (data) => _handle(data),
      onError: (Object error, StackTrace stack) {
        if (!_events.isClosed) _events.addError(error, stack);
      },
      onDone: () => _socket = null,
      cancelOnError: false,
    );
    _send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'instructions': instructions,
        'audio': {
          'output': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'voice': voice,
          },
        },
      },
    });
    _events.add({'type': 'session.connected', 'model': model});
  }

  void speak(String text) {
    final value = text.trim();
    if (value.isEmpty || !connected) return;
    _paused = false;
    _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': value},
        ],
      },
    });
    _send({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio'],
        'audio': {
          'output': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
          },
        },
      },
    });
  }

  void pause() {
    if (!connected) return;
    _paused = true;
    _send({'type': 'response.cancel'});
    _events.add({'type': 'session.paused'});
  }

  void stop() {
    if (!connected) return;
    _send({'type': 'response.cancel'});
    _pcm.clear();
    _events.add({'type': 'session.stopped'});
  }

  Uint8List get pcm16 => _pcm.takeBytes();

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    await socket?.close(WebSocketStatus.normalClosure, 'client closed');
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }

  void _send(Map<String, dynamic> event) => _socket?.add(jsonEncode(event));

  void _handle(Object? data) {
    if (data is! String) return;
    final decoded = jsonDecode(data);
    if (decoded is! Map) return;
    final event = Map<String, dynamic>.from(decoded);
    final type = event['type']?.toString() ?? '';
    final delta = event['delta']?.toString();
    if (type == 'response.output_audio.delta' && delta != null) {
      _pcm.add(base64Decode(delta));
    }
    if (!_events.isClosed) _events.add(event);
  }

  Future<NazaRemoteModelProfile?> _openAiProfile() async {
    final profiles = await NazaRemoteModelCatalog().load();
    for (final profile in profiles) {
      if (profile.provider == NazaRemoteProvider.openAi &&
          profile.enabled &&
          profile.apiKey.trim().isNotEmpty)
        return profile;
    }
    return null;
  }
}
