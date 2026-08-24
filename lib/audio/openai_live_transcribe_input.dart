import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../model/provider_gateway.dart';

final class OpenAiLiveTranscribeInput {
  OpenAiLiveTranscribeInput({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  WebSocket? _socket;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  final StringBuffer _transcript = StringBuffer();

  static Future<bool> isConfigured() async {
    try {
      final profiles = await NazaRemoteModelCatalog().load();
      return profiles.any(
        (profile) =>
            profile.provider == NazaRemoteProvider.openAi &&
            profile.enabled &&
            profile.apiKey.trim().isNotEmpty,
      );
    } catch (_) {
      // Locked vault, first boot, or unavailable settings means the control
      // must remain hidden rather than surfacing an error from every field.
      return false;
    }
  }

  Future<void> start({required ValueChanged<String> onText}) async {
    await stop();
    final profiles = await NazaRemoteModelCatalog().load();
    final profile = profiles.where(
      (candidate) =>
          candidate.provider == NazaRemoteProvider.openAi &&
          candidate.enabled &&
          candidate.apiKey.trim().isNotEmpty,
    );
    if (profile.isEmpty)
      throw StateError('Configure OpenAI transcription in Settings first.');
    final socket = await WebSocket.connect(
      'wss://api.openai.com/v1/realtime?model=gpt-live-transcribe',
      headers: {'Authorization': 'Bearer ${profile.first.apiKey}'},
    );
    _socket = socket;
    _socketSubscription = socket.listen((data) {
      if (data is! String) return;
      final event = jsonDecode(data);
      if (event is! Map) return;
      final type = event['type']?.toString() ?? '';
      final delta = event['delta']?.toString() ?? '';
      if ((type.contains('transcription') || type.contains('text')) &&
          delta.isNotEmpty) {
        _transcript.write(delta);
        onText(_transcript.toString());
      }
    });
    socket.add(
      jsonEncode({
        'type': 'session.update',
        'session': {
          'type': 'realtime',
          'audio': {
            'input': {
              'format': {'type': 'audio/pcm', 'rate': 24000},
              'transcription': {'model': 'gpt-live-transcribe'},
            },
          },
        },
      }),
    );
    if (!await _recorder.hasPermission()) {
      await stop();
      throw StateError('Microphone permission was not granted.');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
      ),
    );
    _audioSubscription = stream.listen((bytes) {
      if (_socket != null && bytes.isNotEmpty) {
        _socket!.add(
          jsonEncode({
            'type': 'input_audio_buffer.append',
            'audio': base64Encode(bytes),
          }),
        );
      }
    });
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _recorder.stop();
    _socket?.add(jsonEncode({'type': 'input_audio_buffer.commit'}));
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close(WebSocketStatus.normalClosure, 'input stopped');
    _socket = null;
    _transcript.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}

final class NazaVoiceInputButton extends StatefulWidget {
  const NazaVoiceInputButton({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<NazaVoiceInputButton> createState() => _NazaVoiceInputButtonState();
}

final class _NazaVoiceInputButtonState extends State<NazaVoiceInputButton> {
  late final OpenAiLiveTranscribeInput _input;
  bool _configured = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _input = OpenAiLiveTranscribeInput();
    unawaited(_loadAvailability());
  }

  Future<void> _loadAvailability() async {
    final configured = await OpenAiLiveTranscribeInput.isConfigured();
    if (mounted) setState(() => _configured = configured);
  }

  @override
  void dispose() {
    unawaited(_input.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_configured) return;
    if (_recording) {
      await _input.stop();
      if (mounted) setState(() => _recording = false);
      return;
    }
    try {
      setState(() => _recording = true);
      await _input.start(
        onText: (text) {
          final existing = widget.controller.text.trimRight();
          widget.controller.text = existing.isEmpty ? text : '$existing $text';
          widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length,
          );
        },
      );
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_configured) return const SizedBox.shrink();
    return IconButton(
      tooltip: _recording ? 'Stop live transcription' : 'Dictate with OpenAI',
      onPressed: _toggle,
      color: _recording ? Colors.redAccent : null,
      icon: Icon(
        _recording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
      ),
    );
  }
}
