import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../model/provider_gateway.dart';
import '../security/secure_database.dart';
import 'encrypted_voice_cache.dart';
import 'humanized_speech_planner.dart';
import 'replicate_bark_client.dart';
import 'voice_settings.dart';
import 'wav_composer.dart';

/// Cancellable multi-backend reading surface for books and chat.
///
/// OpenAI remains the fast default. Suno Bark on Replicate is an opt-in
/// alternative. Both share a cheap local performance planner, a bounded
/// request queue, encrypted recall, and the same WAV finishing stage.
final class OpenAiReadingService {
  OpenAiReadingService({
    AudioPlayer? player,
    http.Client? client,
    NazaEncryptedVoiceCache? voiceCache,
    NazaVoiceSettingsStore? settingsStore,
    HumanizedSpeechPlanner? planner,
    NazaWavComposer? composer,
  }) : _player = player ?? AudioPlayer(),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _voiceCache = voiceCache ?? NazaEncryptedVoiceCache.instance,
       _settingsStore = settingsStore ?? NazaVoiceSettingsStore(),
       _planner = planner ?? const HumanizedSpeechPlanner(),
       _composer = composer ?? const NazaWavComposer() {
    _bark = ReplicateBarkClient(client: _client);
    _playerCompletion = _player.onPlayerComplete.listen(
      (_) => unawaited(_handlePlayerComplete()),
      onError: (Object error, StackTrace stackTrace) =>
          unawaited(_handlePlayerError(error, stackTrace)),
    );
  }

  final AudioPlayer _player;
  final http.Client _client;
  final bool _ownsClient;
  final NazaEncryptedVoiceCache _voiceCache;
  final NazaVoiceSettingsStore _settingsStore;
  final HumanizedSpeechPlanner _planner;
  final NazaWavComposer _composer;
  late final ReplicateBarkClient _bark;
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  late final StreamSubscription<void> _playerCompletion;
  bool _cancelled = false;
  Uint8List? _lastWav;
  String? _lastPath;
  String? _lastAudioSha256;
  String? _lastRequestHash;
  bool _lastReadWasCached = false;
  Directory? _playbackDirectory;
  File? _playbackFile;

  static const int _maxResponseBytes = 16 * 1024 * 1024;
  static const int _maxCombinedResponseBytes = NazaWavComposer.maxCombinedBytes;
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const String _playbackDirectoryPrefix = 'naza-one-reading-';
  static const String _playbackFileName = 'reading.wav';
  static Future<void>? _stalePlaybackCleanup;

  Future<Uint8List> read({
    required String text,
    String? voice,
    String model = 'gpt-4o-mini-tts',
    String instructions =
        'Read naturally and warmly, as if speaking to one person nearby. '
        'Use expressive but restrained emphasis and comfortable phrasing.',
    void Function(int total)? onPlanned,
    void Function(int completed, int total)? onProgress,
    int? performanceSeed,
  }) async {
    if (model != 'gpt-4o-mini-tts') {
      throw ArgumentError.value(model, 'model', 'Unsupported speech model.');
    }
    _cancelled = false;
    _lastReadWasCached = false;
    _lastAudioSha256 = null;
    _lastRequestHash = null;
    await _stopPlayerAndCleanup();
    if (!_voiceCache.isUnlocked) {
      throw const NazaVaultException(
        'voice_cache_locked',
        'Unlock the encrypted vault before using Read Aloud.',
      );
    }

    final savedSettings = await _settingsStore.load();
    final settings = voice == null
        ? savedSettings
        : savedSettings.copyWith(openAiVoice: voice);
    settings.validate();
    if (!NazaVoiceSettings.openAiVoices.contains(settings.openAiVoice)) {
      throw ArgumentError.value(
        settings.openAiVoice,
        'voice',
        'Unsupported voice.',
      );
    }
    if (settings.backend == NazaSpeechBackend.replicateBark &&
        settings.replicateApiToken.isEmpty) {
      throw StateError(
        'Add a Replicate API token in Settings → Voice & read aloud.',
      );
    }

    final seed = performanceSeed ?? _stablePerformanceSeed(text, settings);
    final plan = _planner.plan(text: text, settings: settings, seed: seed);
    onPlanned?.call(plan.segmentCount);
    final cacheVoice = settings.backend == NazaSpeechBackend.openAi
        ? 'openai:${settings.openAiVoice}'
        : 'replicate-bark:${settings.barkVoice}';
    final cacheModel = settings.backend == NazaSpeechBackend.openAi
        ? model
        : ReplicateBarkClient.modelVersion;
    final cacheInstructions = _cachePerformanceIdentity(
      text: text,
      baseInstructions: instructions,
      settings: settings,
      seed: seed,
    );
    final cached = await _voiceCache.recall(
      text: text,
      voice: cacheVoice,
      model: cacheModel,
      instructions: cacheInstructions,
      speed: settings.baseSpeed,
    );
    if (cached != null) {
      if (_cancelled) throw const CancelledReadingException();
      _lastWav = Uint8List.fromList(cached.wav);
      _lastAudioSha256 = cached.audioSha256;
      _lastRequestHash = cached.requestHash;
      _lastReadWasCached = true;
      await _playAndRecord(cached);
      return Uint8List.fromList(cached.wav);
    }

    final profile = settings.backend == NazaSpeechBackend.openAi
        ? await _openAiProfile()
        : null;
    if (settings.backend == NazaSpeechBackend.openAi && profile == null) {
      throw StateError(
        'Add an enabled OpenAI profile with an API key in Settings.',
      );
    }
    final wavs = await _renderPlan(
      plan: plan,
      settings: settings,
      profile: profile,
      model: model,
      baseInstructions: instructions,
      onProgress: onProgress,
    );
    if (_cancelled) throw const CancelledReadingException();
    final combined = _composer.compose(wavs: wavs, segments: plan.segments);
    _lastWav = combined;
    _lastPath = null;
    if (_cancelled) throw const CancelledReadingException();
    if (combined.length <= _voiceCache.maximumEntryBytes) {
      final stored = await _voiceCache.store(
        text: text,
        voice: cacheVoice,
        model: cacheModel,
        instructions: cacheInstructions,
        speed: settings.baseSpeed,
        wav: combined,
      );
      _lastAudioSha256 = stored.audioSha256;
      _lastRequestHash = stored.requestHash;
      await _playAndRecord(stored);
    } else {
      _lastAudioSha256 = crypto.sha256.convert(combined).toString();
      await _playWav(combined);
    }
    return combined;
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();
  Stream<void> get onComplete => _completionController.stream;

  Future<void> stop() async {
    _cancelled = true;
    await Future.wait<void>(<Future<void>>[
      _stopPlayerAndCleanup(),
      _bark.cancelActive(),
    ]);
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
  String? get lastAudioSha256 => _lastAudioSha256;
  String? get lastRequestHash => _lastRequestHash;
  bool get lastReadWasCached => _lastReadWasCached;

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

  Future<List<Uint8List>> _renderPlan({
    required NazaSpeechPlan plan,
    required NazaVoiceSettings settings,
    required NazaRemoteModelProfile? profile,
    required String model,
    required String baseInstructions,
    required void Function(int completed, int total)? onProgress,
  }) async {
    final output = List<Uint8List?>.filled(plan.segmentCount, null);
    Object? firstError;
    StackTrace? firstStack;
    var cursor = 0;
    var completed = 0;
    var combinedBytes = 0;
    var abortWorkers = false;

    Future<void> worker() async {
      while (!_cancelled && !abortWorkers) {
        if (cursor >= plan.segmentCount) return;
        final index = cursor++;
        final segment = plan.segments[index];
        try {
          final wav = settings.backend == NazaSpeechBackend.replicateBark
              ? await _bark.generate(
                  prompt: segment.barkPrompt,
                  historyPrompt: settings.barkVoice,
                  textTemperature: segment.barkTextTemperature,
                  waveformTemperature: segment.barkWaveformTemperature,
                  apiToken: settings.replicateApiToken,
                  isCancelled: () => _cancelled || abortWorkers,
                )
              : await _renderOpenAiSegment(
                  segment: segment,
                  profile: profile!,
                  model: model,
                  voice: settings.openAiVoice,
                  baseInstructions: baseInstructions,
                );
          if (_cancelled || abortWorkers) return;
          combinedBytes += wav.length;
          if (combinedBytes > _maxCombinedResponseBytes) {
            throw const FormatException('Combined speech audio is too large.');
          }
          output[index] = wav;
          completed++;
          onProgress?.call(completed, plan.segmentCount);
        } on Object catch (error, stack) {
          firstError ??= error;
          firstStack ??= stack;
          abortWorkers = true;
          return;
        }
      }
    }

    final workerCount = settings.parallelRequests
        .clamp(1, plan.segmentCount)
        .toInt();
    await Future.wait<void>(<Future<void>>[
      for (var i = 0; i < workerCount; i++) worker(),
    ]);
    if (firstError != null) {
      await _bark.cancelActive();
      if (firstError is ReplicateBarkCancelledException && _cancelled) {
        throw const CancelledReadingException();
      }
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    if (_cancelled) throw const CancelledReadingException();
    if (output.any((item) => item == null)) {
      throw StateError('Speech generation ended before every segment.');
    }
    return output.cast<Uint8List>();
  }

  Future<Uint8List> _renderOpenAiSegment({
    required NazaSpeechSegment segment,
    required NazaRemoteModelProfile profile,
    required String model,
    required String voice,
    required String baseInstructions,
  }) async {
    final request =
        http.Request('POST', Uri.https('api.openai.com', '/v1/audio/speech'))
          ..followRedirects = false
          ..headers.addAll(<String, String>{
            'authorization': 'Bearer ${profile.apiKey}',
            'content-type': 'application/json',
            'accept': 'audio/wav',
          })
          ..body = jsonEncode(<String, Object?>{
            'model': model,
            'voice': voice,
            'input': segment.spokenText,
            'instructions': segment.openAiInstructions(baseInstructions),
            'response_format': 'wav',
            'speed': segment.speed,
          });
    final response = await _client.send(request).timeout(_requestTimeout);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw StateError('OpenAI speech redirects are not allowed.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('OpenAI reading failed (${response.statusCode}).');
    }
    if (response.contentLength != null &&
        response.contentLength! > _maxResponseBytes) {
      throw const FormatException('OpenAI WAV response is too large.');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.stream.timeout(_requestTimeout)) {
      if (chunk.length > _maxResponseBytes - length) {
        throw const FormatException('OpenAI WAV response is too large.');
      }
      length += chunk.length;
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static int _stablePerformanceSeed(String text, NazaVoiceSettings settings) {
    final publicSettings = Map<String, Object?>.from(settings.toJson())
      ..remove('replicateApiToken');
    final digest = crypto.sha256
        .convert(utf8.encode(jsonEncode(<Object?>[text, publicSettings])))
        .bytes;
    return ByteData.sublistView(
          Uint8List.fromList(digest),
        ).getUint32(0, Endian.little) &
        0x7fffffff;
  }

  static String _cachePerformanceIdentity({
    required String text,
    required String baseInstructions,
    required NazaVoiceSettings settings,
    required int seed,
  }) {
    final publicSettings = Map<String, Object?>.from(settings.toJson())
      ..remove('replicateApiToken');
    return jsonEncode(<String, Object?>{
      'format': 'naza-human-voice-performance-v2',
      'rawTextSha256': crypto.sha256.convert(utf8.encode(text)).toString(),
      'baseInstructions': baseInstructions,
      'settings': publicSettings,
      'seed': seed,
    });
  }

  Future<void> _playAndRecord(NazaCachedVoice voice) async {
    await _playWav(voice.wav);
    try {
      await _voiceCache.recordPlayback(voice.requestHash);
    } catch (_) {
      await _stopPlayerAndCleanup();
      rethrow;
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    await (_stalePlaybackCleanup ??= _removeStalePlaybackArtifacts());
    await _deletePlaybackArtifact();
    final temporaryRoot = await getTemporaryDirectory();
    final directory = await temporaryRoot.createTemp(_playbackDirectoryPrefix);
    try {
      if (!Platform.isWindows) {
        final stat = await directory.stat();
        if ((stat.mode & 0x3f) != 0) {
          throw const FileSystemException(
            'Private audio playback directory has unsafe permissions.',
          );
        }
      }
      final file = File(
        '${directory.path}${Platform.pathSeparator}$_playbackFileName',
      );
      await file.writeAsBytes(wav, flush: true);
      _playbackDirectory = directory;
      _playbackFile = file;
      await _player.play(DeviceFileSource(file.path, mimeType: 'audio/wav'));
    } catch (_) {
      _playbackDirectory = directory;
      await _deletePlaybackArtifact();
      rethrow;
    }
  }

  Future<void> _handlePlayerComplete() async {
    try {
      await _deletePlaybackArtifact();
      if (!_completionController.isClosed) _completionController.add(null);
    } catch (error, stackTrace) {
      if (!_completionController.isClosed) {
        _completionController.addError(error, stackTrace);
      }
    }
  }

  Future<void> _handlePlayerError(Object error, StackTrace stackTrace) async {
    try {
      await _deletePlaybackArtifact();
    } catch (cleanupError, cleanupStackTrace) {
      if (!_completionController.isClosed) {
        _completionController.addError(cleanupError, cleanupStackTrace);
      }
      return;
    }
    if (!_completionController.isClosed) {
      _completionController.addError(error, stackTrace);
    }
  }

  Future<void> _stopPlayerAndCleanup() async {
    try {
      await _player.stop();
    } finally {
      await _deletePlaybackArtifact();
    }
  }

  Future<void> _deletePlaybackArtifact() async {
    final file = _playbackFile;
    final directory = _playbackDirectory;
    _playbackFile = null;
    _playbackDirectory = null;
    if (file != null &&
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.file) {
      await file.delete();
    }
    if (directory != null &&
        await FileSystemEntity.type(directory.path, followLinks: false) ==
            FileSystemEntityType.directory) {
      await directory.delete();
    }
  }

  static Future<void> _removeStalePlaybackArtifacts() async {
    final temporaryRoot = await getTemporaryDirectory();
    await for (final entity in temporaryRoot.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.startsWith(_playbackDirectoryPrefix) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        continue;
      }
      final file = File(
        '${entity.path}${Platform.pathSeparator}$_playbackFileName',
      );
      if (await FileSystemEntity.type(file.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await file.delete();
      }
      try {
        await Directory(entity.path).delete();
      } on FileSystemException {
        // Never recursively delete an unexpected directory. A non-empty
        // artifact is left untouched instead of following attacker-controlled
        // contents or links.
      }
    }
  }

  Future<void> dispose() async {
    _cancelled = true;
    await _playerCompletion.cancel();
    try {
      await _bark.cancelActive();
      await _player.dispose();
    } finally {
      await _deletePlaybackArtifact();
      if (_ownsClient) _client.close();
      await _completionController.close();
    }
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
  StreamSubscription<void>? _completion;
  bool _busy = false;
  bool _playing = false;
  bool _paused = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reader = OpenAiReadingService();
    _completion = _reader.onComplete.listen(
      (_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _paused = false;
          _status = _encryptedVoiceStatus(_reader, prefix: 'Reading complete');
        });
      },
      // Platform playback errors are also delivered through this stream.
      // Handling them here prevents a failed Linux GStreamer pipeline from
      // escaping as an unhandled asynchronous exception.
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _paused = false;
          _status = _readingFailureMessage(error);
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant NazaReadAloudButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      unawaited(_reader.stop());
      _busy = false;
      _playing = false;
      _paused = false;
      _status = null;
    }
  }

  @override
  void dispose() {
    unawaited(_completion?.cancel());
    unawaited(_reader.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _playing = false;
      _paused = false;
      _status = 'preparing voice';
    });
    try {
      await _reader.read(
        text: widget.text,
        onPlanned: (total) {
          if (mounted) {
            setState(
              () => _status = total == 1
                  ? 'Preparing one natural voice moment…'
                  : 'Preparing $total natural voice moments…',
            );
          }
        },
        onProgress: (done, total) {
          if (mounted) setState(() => _status = 'Voice $done/$total');
        },
      );
      if (mounted) {
        setState(() {
          _playing = true;
          _status = _encryptedVoiceStatus(_reader, prefix: 'Playing');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _playing = false;
          _status = error is CancelledReadingException
              ? 'Reading stopped'
              : _readingFailureMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _playing || _paused;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!active)
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _start,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.record_voice_over_rounded, size: 18),
                label: Text(_busy ? 'Preparing audio…' : 'Read aloud'),
              ),
            if (active)
              FilledButton.tonalIcon(
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
                label: Text(_paused ? 'Play' : 'Pause'),
              ),
            if (_busy || active)
              IconButton(
                tooltip: 'Stop reading',
                onPressed: () async {
                  await _reader.stop();
                  if (mounted) {
                    setState(() {
                      _busy = false;
                      _playing = false;
                      _paused = false;
                      _status = 'Reading stopped';
                    });
                  }
                },
                icon: const Icon(Icons.stop_rounded, size: 18),
              ),
            if (_reader.lastSavedPath != null ||
                (_status?.startsWith('Reading complete') ?? false))
              IconButton(
                tooltip: 'Export decrypted WAV file',
                onPressed: () async {
                  final path = await _reader.saveLastWav();
                  if (mounted) {
                    setState(() => _status = 'Exported plaintext WAV: $path');
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
              ),
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              _status!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

String _readingFailureMessage(Object error) {
  if (error is NazaVaultException) return error.message;
  final message = error.toString().replaceFirst('Bad state: ', '');
  if (Platform.isLinux && message.contains('LinuxAudioError')) {
    return 'Linux audio playback needs the GStreamer good plug-ins. '
        'Install gstreamer1.0-plugins-good, then restart Naza One.';
  }
  return message;
}

String _encryptedVoiceStatus(
  OpenAiReadingService reader, {
  required String prefix,
}) {
  final digest = reader.lastAudioSha256;
  final shortDigest = digest == null || digest.length < 12
      ? 'hash unavailable'
      : 'SHA-256 ${digest.substring(0, 12)}…';
  final source = reader.lastReadWasCached
      ? 'recalled from encrypted vault'
      : 'saved to encrypted vault';
  return '$prefix • $source • $shortDigest';
}
