import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../model/provider_gateway.dart';

/// Cancellable OpenAI reading surface for books and chat.
///
/// The service requests WAV directly, keeps the API key in the existing
/// encrypted profile store, and never writes credentials to disk. Long text
/// is split at paragraph/sentence boundaries because the speech endpoint has
/// a bounded input size.
final class OpenAiReadingService {
  OpenAiReadingService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final http.Client _client = http.Client();
  StreamSubscription<void>? _completion;
  bool _cancelled = false;
  Uint8List? _lastWav;
  String? _lastPath;

  Future<Uint8List> read({
    required String text,
    String voice = 'marin',
    String model = 'gpt-4o-mini-tts',
    String instructions =
        'Read naturally and warmly. Use clear pacing, expressive but restrained emphasis, and comfortable pauses between paragraphs.',
    void Function(int completed, int total)? onProgress,
  }) async {
    _cancelled = false;
    await _player.stop();
    final profile = await _openAiProfile();
    if (profile == null) {
      throw StateError(
        'Add an enabled OpenAI profile with an API key in Settings.',
      );
    }
    final chunks = _chunks(text);
    final wavs = <Uint8List>[];
    for (var i = 0; i < chunks.length; i++) {
      if (_cancelled) throw const CancelledReadingException();
      final response = await _client.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer ${profile.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'voice': voice,
          'input': chunks[i],
          'instructions': instructions,
          'response_format': 'wav',
          'speed': 1.0,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('OpenAI reading failed (${response.statusCode}).');
      }
      wavs.add(Uint8List.fromList(response.bodyBytes));
      onProgress?.call(i + 1, chunks.length);
    }
    final combined = _combineWav(wavs);
    _lastWav = combined;
    await _player.play(BytesSource(combined));
    return combined;
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();

  Future<void> stop() async {
    _cancelled = true;
    await _player.stop();
  }

  Future<String> saveLastWav({String fileName = 'naza-reading.wav'}) async {
    final wav = _lastWav;
    if (wav == null || wav.isEmpty)
      throw StateError('No completed reading is available.');
    final directory = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(wav, flush: true);
    _lastPath = file.path;
    return file.path;
  }

  String? get lastSavedPath => _lastPath;

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

  List<String> _chunks(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) throw StateError('There is no text to read.');
    final out = <String>[];
    var cursor = 0;
    while (cursor < normalized.length) {
      final end = (cursor + 3800).clamp(cursor + 1, normalized.length);
      var cut = end;
      final boundary = normalized.lastIndexOf(RegExp(r'[.!?]\s'), end);
      if (boundary > cursor + 1200) cut = boundary + 1;
      out.add(normalized.substring(cursor, cut).trim());
      cursor = cut;
    }
    return out;
  }

  Uint8List _combineWav(List<Uint8List> files) {
    if (files.length == 1) return files.single;
    final first = files.first;
    if (first.length < 44) throw const FormatException('Invalid WAV response.');
    final pcm = <int>[];
    for (final file in files) {
      if (file.length < 44)
        throw const FormatException('Invalid WAV response.');
      pcm.addAll(file.sublist(44));
    }
    final result = Uint8List.fromList([...first.sublist(0, 44), ...pcm]);
    final view = ByteData.sublistView(result);
    view.setUint32(4, result.length - 8, Endian.little);
    view.setUint32(40, pcm.length, Endian.little);
    return result;
  }

  Future<void> dispose() async {
    await _completion?.cancel();
    await _player.dispose();
    _client.close();
  }
}

final class CancelledReadingException implements Exception {
  const CancelledReadingException();
}

final class NazaReadAloudButton extends StatefulWidget {
  const NazaReadAloudButton({super.key, required this.text});

  final String text;

  @override
  State<NazaReadAloudButton> createState() => _NazaReadAloudButtonState();
}

final class _NazaReadAloudButtonState extends State<NazaReadAloudButton> {
  late final OpenAiReadingService _reader;
  bool _busy = false;
  bool _paused = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reader = OpenAiReadingService();
  }

  @override
  void dispose() {
    unawaited(_reader.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _paused = false;
      _status = 'preparing voice';
    });
    try {
      await _reader.read(
        text: widget.text,
        onProgress: (done, total) {
          if (mounted) setState(() => _status = 'voice $done/$total');
        },
      );
      if (mounted) setState(() => _status = 'playing');
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: _busy ? 'Regenerate reading' : 'Read aloud with OpenAI',
          onPressed: _start,
          icon: const Icon(Icons.record_voice_over_rounded, size: 18),
        ),
        if (_busy || _status == 'playing')
          IconButton(
            tooltip: _paused ? 'Resume reading' : 'Pause reading',
            onPressed: () async {
              if (_paused) {
                await _reader.resume();
              } else {
                await _reader.pause();
              }
              if (mounted) setState(() => _paused = !_paused);
            },
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 18,
            ),
          ),
        if (_busy || _status == 'playing')
          IconButton(
            tooltip: 'Stop reading',
            onPressed: () async {
              await _reader.stop();
              if (mounted)
                setState(() {
                  _busy = false;
                  _status = 'stopped';
                });
            },
            icon: const Icon(Icons.stop_rounded, size: 18),
          ),
        if (_status == 'playing' || _status == 'stopped')
          IconButton(
            tooltip: 'Save WAV locally',
            onPressed: () async {
              final path = await _reader.saveLastWav();
              if (mounted) setState(() => _status = 'saved: $path');
            },
            icon: const Icon(Icons.download_rounded, size: 18),
          ),
      ],
    );
  }
}
