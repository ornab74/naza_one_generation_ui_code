// LLM-CONTEXT:BEGIN
// FILE: lib/model/pausable_model_downloader.dart
// ROLE: Owns pausable model downloader behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

import 'model_distribution_manifest.dart';
import 'multiplane_model_downloader.dart';

/// Cooperative transfer control for the first-run model downloader.
///
/// Pausing applies back-pressure inside active HTTP response streams and also
/// prevents new chunks from being scheduled. Complete chunks remain on disk,
/// so app/process restarts can resume without discarding finished work.
final class NazaTransferController {
  bool _paused = false;
  bool _cancelled = false;
  Completer<void>? _resumeGate;

  bool get isPaused => _paused;
  bool get isCancelled => _cancelled;

  void pause() {
    if (_cancelled || _paused) return;
    _paused = true;
    _resumeGate = Completer<void>();
  }

  void resume() {
    if (_cancelled || !_paused) return;
    _paused = false;
    final gate = _resumeGate;
    _resumeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _paused = false;
    final gate = _resumeGate;
    _resumeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> checkpoint() async {
    while (_paused && !_cancelled) {
      final gate = _resumeGate;
      if (gate == null) return;
      await gate.future;
    }
    if (_cancelled) {
      throw const NazaModelDistributionException('Download cancelled by user.');
    }
  }
}

final class _PausableChunk {
  const _PausableChunk({
    required this.index,
    required this.partIndex,
    required this.fileOffset,
    required this.partOffset,
    required this.length,
  });

  final int index;
  final int partIndex;
  final int fileOffset;
  final int partOffset;
  final int length;

  int get fileEnd => fileOffset + length - 1;
  int get partEnd => partOffset + length - 1;
}

final class _ProviderScore {
  _ProviderScore(this.source) : score = source.trustWeight;

  final NazaDistributionSource source;
  double score;
  double bps = 0;
  int failures = 0;
  int inFlight = 0;
  DateTime? retryAfter;

  bool get available =>
      retryAfter == null || DateTime.now().isAfter(retryAfter!);

  double get effectiveScore {
    final speed = bps <= 0
        ? 1.0
        : 1.0 + math.log(1.0 + bps / (1024 * 1024));
    final pressure = 1.0 / (1.0 + inFlight * 0.8);
    final reliability = 1.0 / (1.0 + failures * 0.45);
    return score * speed * pressure * reliability;
  }

  void success(int bytes, Duration elapsed) {
    final seconds = math.max(0.001, elapsed.inMicroseconds / 1000000.0);
    final current = bytes / seconds;
    bps = bps == 0 ? current : bps * 0.72 + current * 0.28;
    failures = math.max(0, failures - 1);
    score = math.min(8.0, score * 1.025 + 0.01);
    retryAfter = null;
  }

  void failure() {
    failures++;
    score = math.max(0.10, score * 0.68);
    retryAfter = DateTime.now().add(
      Duration(seconds: math.min(12, 1 << math.min(3, failures - 1))),
    );
  }
}

final class _ChunkTransfer {
  const _ChunkTransfer({
    required this.chunk,
    required this.file,
    this.provider,
    this.error,
    this.stackTrace,
  });

  final _PausableChunk chunk;
  final File file;
  final _ProviderScore? provider;
  final Object? error;
  final StackTrace? stackTrace;

  bool get ok => provider != null && error == null;
}

/// First-run model transfer engine.
///
/// Unlike the legacy bootstrap downloader this class consumes the immutable
/// multi-plane manifest directly. It needs no provider-reported topology:
/// exact part sizes and hashes are already compiled into the application.
/// Chunks are fetched concurrently from GitHub/IPFS gateway replicas or from
/// the immutable full-object source, written to a bounded spool, committed in
/// order, and retained across restarts through a compact journal.
final class NazaPausableModelDownloader {
  NazaPausableModelDownloader({
    required this.manifest,
    required this.control,
    this.chunkBytes = 4 * 1024 * 1024,
    this.concurrency = 5,
    this.requestTimeout = const Duration(seconds: 40),
    this.connectionTimeout = const Duration(seconds: 15),
  })  : assert(chunkBytes >= 256 * 1024),
        assert(concurrency >= 1 && concurrency <= 12);

  final NazaModelDistributionManifest manifest;
  final NazaTransferController control;
  final int chunkBytes;
  final int concurrency;
  final Duration requestTimeout;
  final Duration connectionTimeout;

  final Map<String, HttpClient> _clients = <String, HttpClient>{};
  final Map<String, _ProviderScore> _providers = <String, _ProviderScore>{};
  final Map<String, int> _providerBytes = <String, int>{};
  final Map<int, int> _attempts = <int, int>{};
  bool _closed = false;

  Future<NazaDownloadResult> download({
    required File target,
    NazaDownloadProgress? onProgress,
  }) async {
    if (_closed) {
      throw const NazaModelDistributionException('Downloader is closed.');
    }
    await control.checkpoint();
    await target.parent.create(recursive: true);

    _seedProviders();
    final chunks = _buildChunks();
    final totalBytes = manifest.expectedBytes;
    final staging = File('${target.path}.onboarding.part');
    final journal = File('${staging.path}.json');
    final spool = Directory('${staging.path}.chunks');
    final stopwatch = Stopwatch()..start();

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.probing,
      receivedBytes: 0,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: 0,
      totalChunks: chunks.length,
      bytesPerSecond: 0,
      fastestProvider: null,
    ));

    final committed = await _prepareResume(
      staging: staging,
      journal: journal,
      spool: spool,
      chunks: chunks,
    );

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.allocating,
      receivedBytes: _prefixBytes(chunks, committed),
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: committed,
      totalChunks: chunks.length,
      bytesPerSecond: 0,
      fastestProvider: _fastestProvider(),
    ));

    await _runTransfers(
      staging: staging,
      journal: journal,
      spool: spool,
      chunks: chunks,
      initialCommitted: committed,
      onProgress: onProgress,
      stopwatch: stopwatch,
    );

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.verifying,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: chunks.length,
      totalChunks: chunks.length,
      bytesPerSecond: totalBytes /
          math.max(0.001, stopwatch.elapsedMilliseconds / 1000.0),
      fastestProvider: _fastestProvider(),
    ));

    await _verifyParts(staging, journal, spool);
    final digest = await _sha256Range(staging, 0, totalBytes);
    if (digest.toLowerCase() != manifest.expectedSha256.toLowerCase()) {
      await _discard(staging, journal, spool);
      throw NazaModelDistributionException(
        'Final model SHA-256 mismatch. Expected ${manifest.expectedSha256}, got $digest.',
      );
    }

    final previous = File('${target.path}.previous');
    if (await previous.exists()) await previous.delete();
    var backedUp = false;
    try {
      if (await target.exists()) {
        await target.rename(previous.path);
        backedUp = true;
      }
      await staging.rename(target.path);
      if (backedUp && await previous.exists()) await previous.delete();
    } catch (_) {
      if (await target.exists()) await target.delete();
      if (backedUp && await previous.exists()) await previous.rename(target.path);
      rethrow;
    }
    if (await journal.exists()) await journal.delete();
    if (await spool.exists()) await spool.delete(recursive: true);
    stopwatch.stop();

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.complete,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: chunks.length,
      totalChunks: chunks.length,
      bytesPerSecond: totalBytes /
          math.max(0.001, stopwatch.elapsedMilliseconds / 1000.0),
      fastestProvider: _fastestProvider(),
    ));

    return NazaDownloadResult(
      file: target,
      sha256: digest,
      totalBytes: totalBytes,
      elapsed: stopwatch.elapsed,
      providerBytes: Map<String, int>.unmodifiable(_providerBytes),
    );
  }

  void _seedProviders() {
    for (final source in manifest.fullSources) {
      _providers.putIfAbsent(source.id, () => _ProviderScore(source));
    }
    for (final part in manifest.parts) {
      for (final source in part.sources) {
        _providers.putIfAbsent(source.id, () => _ProviderScore(source));
      }
    }
  }

  List<_PausableChunk> _buildChunks() {
    final chunks = <_PausableChunk>[];
    var index = 0;
    var fileOffset = 0;
    for (final part in manifest.parts) {
      for (var partOffset = 0;
          partOffset < part.expectedBytes;
          partOffset += chunkBytes) {
        final length = math.min(chunkBytes, part.expectedBytes - partOffset);
        chunks.add(_PausableChunk(
          index: index++,
          partIndex: part.index,
          fileOffset: fileOffset + partOffset,
          partOffset: partOffset,
          length: length,
        ));
      }
      fileOffset += part.expectedBytes;
    }
    if (fileOffset != manifest.expectedBytes) {
      throw NazaModelDistributionException(
        'Compiled model topology is inconsistent: parts=$fileOffset total=${manifest.expectedBytes}.',
      );
    }
    return chunks;
  }

  Future<int> _prepareResume({
    required File staging,
    required File journal,
    required Directory spool,
    required List<_PausableChunk> chunks,
  }) async {
    await spool.create(recursive: true);
    final fingerprint = manifest.fingerprintFor(
      totalBytes: manifest.expectedBytes,
      partSizes: manifest.parts.map((part) => part.expectedBytes).toList(),
      chunkBytes: chunkBytes,
    );

    var committed = 0;
    var valid = false;
    if (await staging.exists() && await journal.exists()) {
      try {
        final raw = jsonDecode(await journal.readAsString());
        if (raw is Map &&
            raw['schema'] == 'naza-onboarding-download-v1' &&
            raw['fingerprint'] == fingerprint &&
            raw['chunkBytes'] == chunkBytes &&
            raw['totalBytes'] == manifest.expectedBytes) {
          final candidate = (raw['committedChunks'] as num?)?.toInt() ?? -1;
          if (candidate >= 0 && candidate <= chunks.length) {
            final expectedLength = _prefixBytes(chunks, candidate);
            if (await staging.length() == expectedLength) {
              committed = candidate;
              valid = true;
            }
          }
        }
      } catch (_) {}
    }

    if (!valid) {
      await _discard(staging, journal, spool);
      await staging.create(recursive: true);
      await spool.create(recursive: true);
      committed = 0;
    }

    // Keep only exact complete chunk files; malformed partials are discarded.
    for (var i = committed; i < chunks.length; i++) {
      final file = _chunkFile(spool, i);
      if (await file.exists() && await file.length() != chunks[i].length) {
        await file.delete();
      }
    }
    return committed;
  }

  Future<void> _runTransfers({
    required File staging,
    required File journal,
    required Directory spool,
    required List<_PausableChunk> chunks,
    required int initialCommitted,
    required NazaDownloadProgress? onProgress,
    required Stopwatch stopwatch,
  }) async {
    var committed = initialCommitted;
    final ready = <int>{};
    for (var i = committed; i < chunks.length; i++) {
      final file = _chunkFile(spool, i);
      if (await file.exists() && await file.length() == chunks[i].length) {
        ready.add(i);
      }
    }

    final pending = Queue<_PausableChunk>.from(
      chunks.where((chunk) => chunk.index >= committed && !ready.contains(chunk.index)),
    );
    final active = <int, Future<_ChunkTransfer>>{};
    final sink = staging.openWrite(mode: FileMode.writeOnlyAppend);

    Future<void> persist() async {
      final fingerprint = manifest.fingerprintFor(
        totalBytes: manifest.expectedBytes,
        partSizes: manifest.parts.map((part) => part.expectedBytes).toList(),
        chunkBytes: chunkBytes,
      );
      final temp = File('${journal.path}.tmp');
      await temp.writeAsString(jsonEncode(<String, Object?>{
        'schema': 'naza-onboarding-download-v1',
        'fingerprint': fingerprint,
        'chunkBytes': chunkBytes,
        'totalBytes': manifest.expectedBytes,
        'committedChunks': committed,
      }), flush: true);
      if (await journal.exists()) await journal.delete();
      await temp.rename(journal.path);
    }

    Future<void> commitReady() async {
      var changed = false;
      while (committed < chunks.length) {
        final file = _chunkFile(spool, committed);
        if (!ready.contains(committed) || !await file.exists()) break;
        final chunk = chunks[committed];
        if (await file.length() != chunk.length) {
          ready.remove(committed);
          await file.delete();
          pending.addFirst(chunk);
          break;
        }
        await sink.addStream(file.openRead());
        await file.delete();
        ready.remove(committed);
        committed++;
        changed = true;
      }
      if (changed) {
        await sink.flush();
        await persist();
      }
    }

    void publish() {
      final completedBytes =
          _prefixBytes(chunks, committed) + _readyBytes(chunks, ready);
      onProgress?.call(NazaDownloadSnapshot(
        stage: NazaDownloadStage.downloading,
        receivedBytes: completedBytes.clamp(0, manifest.expectedBytes),
        totalBytes: manifest.expectedBytes,
        activeTransfers: active.length,
        completedChunks: committed + ready.length,
        totalChunks: chunks.length,
        bytesPerSecond: _providerBytes.values.fold<int>(0, (a, b) => a + b) /
            math.max(0.001, stopwatch.elapsedMilliseconds / 1000.0),
        fastestProvider: _fastestProvider(),
      ));
    }

    try {
      await commitReady();
      while (committed < chunks.length) {
        await control.checkpoint();
        while (!control.isPaused &&
            active.length < concurrency &&
            pending.isNotEmpty) {
          final chunk = pending.removeFirst();
          active[chunk.index] = _downloadChunk(chunk, _chunkFile(spool, chunk.index));
        }

        if (active.isEmpty) {
          if (pending.isEmpty) {
            for (var i = committed; i < chunks.length; i++) {
              if (!ready.contains(i)) pending.add(chunks[i]);
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }

        publish();
        final result = await Future.any(active.values);
        active.remove(result.chunk.index);
        if (result.ok) {
          ready.add(result.chunk.index);
          _attempts.remove(result.chunk.index);
          _providerBytes.update(
            result.provider!.source.id,
            (value) => value + result.chunk.length,
            ifAbsent: () => result.chunk.length,
          );
          await commitReady();
        } else {
          if (await result.file.exists()) await result.file.delete();
          final attempts = _attempts.update(
            result.chunk.index,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          if (attempts >= 5) {
            Error.throwWithStackTrace(
              result.error ?? const NazaModelDistributionException('Chunk transfer failed.'),
              result.stackTrace ?? StackTrace.current,
            );
          }
          pending.addLast(result.chunk);
        }
        publish();
      }
      await sink.flush();
      await persist();
    } finally {
      await sink.close();
    }

    if (committed != chunks.length || await staging.length() != manifest.expectedBytes) {
      throw NazaModelDistributionException(
        'Download assembly incomplete: $committed/${chunks.length} chunks, '
        '${await staging.length()}/${manifest.expectedBytes} bytes.',
      );
    }
  }

  Future<_ChunkTransfer> _downloadChunk(
    _PausableChunk chunk,
    File output,
  ) async {
    try {
      final provider = await _fetchChunk(chunk, output);
      return _ChunkTransfer(chunk: chunk, file: output, provider: provider);
    } catch (error, stackTrace) {
      return _ChunkTransfer(
        chunk: chunk,
        file: output,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<_ProviderScore> _fetchChunk(
    _PausableChunk chunk,
    File output,
  ) async {
    await control.checkpoint();
    final candidates = <_ProviderScore>[];
    for (final source in manifest.parts[chunk.partIndex].sources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }
    for (final source in manifest.fullSources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }

    if (candidates.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await control.checkpoint();
      return _fetchChunk(chunk, output);
    }
    candidates.sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore));

    Object? lastError;
    for (final provider in candidates.take(math.min(6, candidates.length))) {
      provider.inFlight++;
      final watch = Stopwatch()..start();
      try {
        final full = provider.source.isFullObject;
        final start = full ? chunk.fileOffset : chunk.partOffset;
        final end = full ? chunk.fileEnd : chunk.partEnd;
        await _rangeGet(provider.source.uri, start, end, output);
        watch.stop();
        provider.success(chunk.length, watch.elapsed);
        return provider;
      } catch (error) {
        lastError = error;
        provider.failure();
        if (await output.exists()) await output.delete();
      } finally {
        provider.inFlight--;
      }
    }
    throw NazaModelDistributionException(
      'All approved providers failed for chunk ${chunk.index}: $lastError',
    );
  }

  Future<void> _rangeGet(Uri uri, int start, int end, File output) async {
    _validateUri(uri);
    await control.checkpoint();
    final request = await _clientFor(uri).getUrl(uri).timeout(requestTimeout);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(requestTimeout);
    final expected = end - start + 1;
    if (response.statusCode != HttpStatus.partialContent &&
        !(start == 0 &&
            response.statusCode == HttpStatus.ok &&
            response.contentLength == expected)) {
      await response.drain<void>();
      throw HttpException('Range request failed with HTTP ${response.statusCode}.', uri: uri);
    }

    final sink = output.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final frame in response.timeout(requestTimeout)) {
        await control.checkpoint();
        received += frame.length;
        if (received > expected) {
          throw NazaModelDistributionException(
            'Provider exceeded requested range ($received > $expected).',
          );
        }
        sink.add(frame);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != expected || await output.length() != expected) {
      throw NazaModelDistributionException(
        'Provider ended range at $received of $expected bytes.',
      );
    }
  }

  Future<void> _verifyParts(File staging, File journal, Directory spool) async {
    var offset = 0;
    for (final part in manifest.parts) {
      await control.checkpoint();
      final digest = await _sha256Range(staging, offset, part.expectedBytes);
      if (digest.toLowerCase() != part.expectedSha256.toLowerCase()) {
        // A corrupt completed assembly must not remain resumable. Otherwise
        // the journal can claim all chunks are present and repeat the same
        // failure forever on every subsequent launch.
        await _discard(staging, journal, spool);
        throw NazaModelDistributionException(
          'Part ${part.index} SHA-256 mismatch. Expected ${part.expectedSha256}, got $digest.',
        );
      }
      offset += part.expectedBytes;
    }
  }

  static Future<String> _sha256Range(File file, int start, int length) async {
    final digest = await crypto.sha256.bind(file.openRead(start, start + length)).first;
    return digest.toString().toLowerCase();
  }

  HttpClient _clientFor(Uri uri) {
    final key = '${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : 443}';
    return _clients.putIfAbsent(key, () {
      final client = HttpClient()
        ..connectionTimeout = connectionTimeout
        ..idleTimeout = const Duration(seconds: 25)
        ..maxConnectionsPerHost = 3
        ..autoUncompress = false;
      client.userAgent = 'NAZA-One/1 onboarding-swarm-v1';
      return client;
    });
  }

  static void _validateUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.trim().isEmpty) {
      throw NazaModelDistributionException('Only HTTPS model sources are allowed: $uri');
    }
    if (uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) {
      throw NazaModelDistributionException('Unsafe model source URI: $uri');
    }
  }

  String? _fastestProvider() {
    final values = _providers.values.where((provider) => provider.bps > 0).toList();
    if (values.isEmpty) return null;
    values.sort((a, b) => b.bps.compareTo(a.bps));
    return values.first.source.id;
  }

  static File _chunkFile(Directory spool, int index) =>
      File('${spool.path}/chunk_${index.toString().padLeft(6, '0')}.bin');

  static int _prefixBytes(List<_PausableChunk> chunks, int count) {
    var total = 0;
    for (var i = 0; i < math.min(count, chunks.length); i++) {
      total += chunks[i].length;
    }
    return total;
  }

  static int _readyBytes(List<_PausableChunk> chunks, Set<int> ready) {
    var total = 0;
    for (final index in ready) {
      if (index >= 0 && index < chunks.length) total += chunks[index].length;
    }
    return total;
  }

  static Future<void> _discard(
    File staging,
    File journal,
    Directory spool,
  ) async {
    if (await staging.exists()) await staging.delete();
    if (await journal.exists()) await journal.delete();
    if (await spool.exists()) await spool.delete(recursive: true);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final client in _clients.values) {
      client.close(force: true);
    }
    _clients.clear();
  }
}
