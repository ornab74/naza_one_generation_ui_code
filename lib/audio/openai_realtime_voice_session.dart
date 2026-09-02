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
  int _pcmBytes = 0;

  static const int _maxTextCharacters = 50000;
  static const int _maxEventCharacters = 512 * 1024;
  static const int _maxPcmBytes = 48 * 1024 * 1024;
  static const Set<String> _allowedVoices = {
    'alloy',
    'ash',
    'ballad',
    'coral',
    'echo',
    'marin',
    'sage',
    'shimmer',
    'verse',
  };

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _socket != null;
  bool get paused => _paused;

  Future<void> connect({
    String model = 'gpt-realtime-2.1',
    String voice = 'marin',
    String instructions =
        'Read naturally, warmly, and clearly. Preserve the supplied text exactly; do not summarize.',
  }) async {
    if (model != 'gpt-realtime-2.1') {
      throw ArgumentError.value(model, 'model', 'Unsupported realtime model.');
    }
    if (!_allowedVoices.contains(voice)) {
      throw ArgumentError.value(voice, 'voice', 'Unsupported voice.');
    }
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
    if (value.length > _maxTextCharacters) {
      throw StateError(
        'Realtime speech text exceeds the 50,000 character limit.',
      );
    }
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
    _pcmBytes = 0;
    _events.add({'type': 'session.stopped'});
  }

  Uint8List get pcm16 {
    final bytes = _pcm.takeBytes();
    _pcmBytes = 0;
    return bytes;
  }

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
    if (data is! String || data.length > _maxEventCharacters) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final event = Map<String, dynamic>.from(decoded);
      final type = event['type']?.toString() ?? '';
      final delta = event['delta']?.toString();
      if (type == 'response.output_audio.delta' && delta != null) {
        final bytes = base64Decode(delta);
        if (_pcmBytes + bytes.length > _maxPcmBytes) {
          pause();
          if (!_events.isClosed) {
            _events.addError(
              StateError('Realtime audio exceeded its memory limit.'),
            );
          }
          return;
        }
        _pcm.add(bytes);
        _pcmBytes += bytes.length;
      }
      if (!_events.isClosed) _events.add(event);
    } on FormatException {
      // Ignore malformed remote events while preserving session cleanup.
    }
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
