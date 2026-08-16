// LLM-CONTEXT:BEGIN
// FILE: lib/model/multiplane_model_downloader.dart
// ROLE: Owns multiplane model downloader behavior within the model-runtime subsystem.
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

typedef NazaDownloadProgress = void Function(NazaDownloadSnapshot snapshot);

enum NazaDownloadStage {
  probing,
  allocating,
  downloading,
  verifying,
  complete,
}

final class NazaDownloadSnapshot {
  const NazaDownloadSnapshot({
    required this.stage,
    required this.receivedBytes,
    required this.totalBytes,
    required this.activeTransfers,
    required this.completedChunks,
    required this.totalChunks,
    required this.bytesPerSecond,
    required this.fastestProvider,
  });

  final NazaDownloadStage stage;
  final int receivedBytes;
  final int totalBytes;
  final int activeTransfers;
  final int completedChunks;
  final int totalChunks;
  final double bytesPerSecond;
  final String? fastestProvider;

  double get fraction => totalBytes <= 0
      ? 0
      : (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble();

  int get percent => (fraction * 100).round().clamp(0, 100);
}

final class NazaDownloadResult {
  const NazaDownloadResult({
    required this.file,
    required this.sha256,
    required this.totalBytes,
    required this.elapsed,
    required this.providerBytes,
  });

  final File file;
  final String sha256;
  final int totalBytes;
  final Duration elapsed;
  final Map<String, int> providerBytes;
}

final class NazaModelDistributionException implements Exception {
  const NazaModelDistributionException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class _PartLayout {
  const _PartLayout({
    required this.partIndex,
    required this.start,
    required this.length,
  });

  final int partIndex;
  final int start;
  final int length;
}

final class _Chunk {
  const _Chunk({
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
  int get fileEndInclusive => fileOffset + length - 1;
  int get partEndInclusive => partOffset + length - 1;
}

final class _ProviderState {
  _ProviderState(this.source)
      : score = source.trustWeight,
        ewmaBps = 0;

  final NazaDistributionSource source;
  double score;
  double ewmaBps;
  int successes = 0;
  int failures = 0;
  int inFlight = 0;
  DateTime? backoffUntil;

  bool get available =>
      backoffUntil == null || DateTime.now().isAfter(backoffUntil!);

  double get effectiveScore {
    final speed = ewmaBps <= 0
        ? 1.0
        : math.log(1 + ewmaBps / (1024 * 1024)) + 1.0;
    final reliability = (successes + 1) / (successes + failures + 1);
    final pressure = 1 / (1 + inFlight * 0.85);
    return score * speed * reliability * pressure;
  }

  void success(int bytes, Duration elapsed) {
    successes++;
    failures = math.max(0, failures - 1);
    final seconds = math.max(elapsed.inMicroseconds / 1000000.0, 0.001);
    final bps = bytes / seconds;
    ewmaBps = ewmaBps == 0 ? bps : ewmaBps * 0.74 + bps * 0.26;
    score = math.min(8.0, score * 1.035 + 0.01);
    backoffUntil = null;
  }

  void failure() {
    failures++;
    score = math.max(0.10, score * 0.62);
    final seconds = math.min(20, 1 << math.min(4, failures - 1));
    backoffUntil = DateTime.now().add(Duration(seconds: seconds));
  }
}

final class _TransferResult {
  const _TransferResult({
    required this.chunk,
    required this.file,
    required this.provider,
    this.error,
    this.stackTrace,
  });

  final _Chunk chunk;
  final File file;
  final _ProviderState? provider;
  final Object? error;
  final StackTrace? stackTrace;

  bool get ok => error == null && provider != null;
}

final class _ResumeJournal {
  const _ResumeJournal({
    required this.fingerprint,
    required this.totalBytes,
    required this.chunkBytes,
    required this.committedPrefixChunks,
  });

  final String fingerprint;
  final int totalBytes;
  final int chunkBytes;
  final int committedPrefixChunks;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'naza-model-download-journal-v2',
        'fingerprint': fingerprint,
        'totalBytes': totalBytes,
        'chunkBytes': chunkBytes,
        'committedPrefixChunks': committedPrefixChunks,
      };

  static _ResumeJournal? decode(String text) {
    try {
      final raw = jsonDecode(text);
      if (raw is! Map || raw['schema'] != 'naza-model-download-journal-v2') {
        return null;
      }
      return _ResumeJournal(
        fingerprint: raw['fingerprint']?.toString() ?? '',
        totalBytes: (raw['totalBytes'] as num?)?.toInt() ?? -1,
        chunkBytes: (raw['chunkBytes'] as num?)?.toInt() ?? -1,
        committedPrefixChunks:
            (raw['committedPrefixChunks'] as num?)?.toInt() ?? -1,
      );
    } catch (_) {
      return null;
    }
  }
}

final class _ResumeState {
  const _ResumeState({
    required this.committedPrefixChunks,
    required this.readyChunkIndexes,
  });

  final int committedPrefixChunks;
  final Set<int> readyChunkIndexes;
}

/// A bounded, resumable, multi-provider HTTPS swarm for immutable model files.
///
/// The scheduler can fetch the same logical bytes from several independent
/// planes (canonical full object, GitHub release parts, Pinata and public IPFS
/// gateways). Chunks arrive out of order, but are committed to the staging file
/// only when the contiguous prefix advances. This gives torrent-like parallel
/// fetching without holding model chunks in RAM and without requiring unsafe
/// random-write reopen semantics.
final class NazaMultiplaneModelDownloader {
  NazaMultiplaneModelDownloader({
    required this.manifest,
    this.chunkBytes = 4 * 1024 * 1024,
    this.minConcurrency = 3,
    this.maxConcurrency = 8,
    this.requestTimeout = const Duration(seconds: 35),
    this.connectionTimeout = const Duration(seconds: 12),
  })  : assert(chunkBytes >= 256 * 1024),
        assert(minConcurrency > 0),
        assert(maxConcurrency >= minConcurrency);

  final NazaModelDistributionManifest manifest;
  final int chunkBytes;
  final int minConcurrency;
  final int maxConcurrency;
  final Duration requestTimeout;
  final Duration connectionTimeout;

  final Map<String, HttpClient> _clients = <String, HttpClient>{};
  final Map<String, _ProviderState> _providers = <String, _ProviderState>{};
  final Map<String, int> _providerBytes = <String, int>{};
  final Map<int, int> _chunkAttempts = <int, int>{};
  bool _closed = false;

  Future<NazaDownloadResult> download({
    required File target,
    NazaDownloadProgress? onProgress,
  }) async {
    if (_closed) {
      throw const NazaModelDistributionException('Downloader is closed.');
    }

    final stopwatch = Stopwatch()..start();
    await target.parent.create(recursive: true);
    final topology = await _probeTopology(onProgress);
    final layouts = topology.layouts;
    final totalBytes = topology.totalBytes;
    if (totalBytes <= 0 || totalBytes > 8 * 1024 * 1024 * 1024) {
      throw NazaModelDistributionException(
        'Invalid model size reported by providers: $totalBytes bytes.',
      );
    }

    final chunks = _buildChunks(layouts);
    final partSizes = layouts.map((layout) => layout.length).toList();
    final fingerprint = manifest.fingerprintFor(
      totalBytes: totalBytes,
      partSizes: partSizes,
      chunkBytes: chunkBytes,
    );
    final staging = File('${target.path}.multiplane.part');
    final journal = File('${staging.path}.json');
    final spool = Directory('${staging.path}.chunks');
    final resume = await _prepareResume(
      staging: staging,
      journal: journal,
      spool: spool,
      fingerprint: fingerprint,
      totalBytes: totalBytes,
      chunks: chunks,
    );

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.allocating,
      receivedBytes: _prefixBytes(chunks, resume.committedPrefixChunks),
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks:
          resume.committedPrefixChunks + resume.readyChunkIndexes.length,
      totalChunks: chunks.length,
      bytesPerSecond: 0,
      fastestProvider: null,
    ));

    await _downloadChunks(
      staging: staging,
      journal: journal,
      spool: spool,
      chunks: chunks,
      layouts: layouts,
      fingerprint: fingerprint,
      totalBytes: totalBytes,
      resume: resume,
      onProgress: onProgress,
    );

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.verifying,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: chunks.length,
      totalChunks: chunks.length,
      bytesPerSecond: totalBytes /
          math.max(0.001, stopwatch.elapsedMilliseconds / 1000),
      fastestProvider: _fastestProvider(),
    ));

    final digest = await _sha256File(staging);
    final expected = manifest.expectedSha256.toLowerCase();
    if (digest != expected) {
      await _discardResume(staging, journal, spool);
      throw NazaModelDistributionException(
        'Final model SHA-256 mismatch. Expected $expected, got $digest.',
      );
    }

    final backup = File('${target.path}.previous');
    if (await backup.exists()) await backup.delete();
    var movedOld = false;
    try {
      if (await target.exists()) {
        await target.rename(backup.path);
        movedOld = true;
      }
      await staging.rename(target.path);
      if (movedOld && await backup.exists()) await backup.delete();
    } catch (_) {
      if (await staging.exists()) await staging.delete();
      if (movedOld && !await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
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
          math.max(0.001, stopwatch.elapsedMilliseconds / 1000),
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

  Future<({List<_PartLayout> layouts, int totalBytes})> _probeTopology(
    NazaDownloadProgress? onProgress,
  ) async {
    onProgress?.call(const NazaDownloadSnapshot(
      stage: NazaDownloadStage.probing,
      receivedBytes: 0,
      totalBytes: 0,
      activeTransfers: 0,
      completedChunks: 0,
      totalChunks: 0,
      bytesPerSecond: 0,
      fastestProvider: null,
    ));

    for (final source in manifest.fullSources) {
      _providers.putIfAbsent(source.id, () => _ProviderState(source));
    }
    for (final part in manifest.parts) {
      for (final source in part.sources) {
        _providers.putIfAbsent(source.id, () => _ProviderState(source));
      }
    }

    final partLengths = <int>[];
    for (final part in manifest.parts) {
      int? found;
      final ordered = List<NazaDistributionSource>.from(part.sources)
        ..sort((a, b) => b.trustWeight.compareTo(a.trustWeight));
      for (final source in ordered) {
        try {
          final length = await _probeLength(source.uri);
          if (length > 0) {
            found = length;
            break;
          }
        } catch (_) {
          _providers[source.id]?.failure();
        }
      }
      if (found == null) {
        throw NazaModelDistributionException(
          'No provider reported a usable size for ${part.name}.',
        );
      }
      partLengths.add(found);
    }

    var offset = 0;
    final layouts = <_PartLayout>[];
    for (var i = 0; i < partLengths.length; i++) {
      layouts.add(_PartLayout(
        partIndex: i,
        start: offset,
        length: partLengths[i],
      ));
      offset += partLengths[i];
    }

    for (final source in manifest.fullSources) {
      try {
        final full = await _probeLength(source.uri);
        if (full > 0 && full != offset) {
          throw NazaModelDistributionException(
            'Distribution topology mismatch: parts total $offset bytes but '
            '${source.id} reports $full bytes.',
          );
        }
        break;
      } on NazaModelDistributionException {
        rethrow;
      } catch (_) {
        _providers[source.id]?.failure();
      }
    }

    return (layouts: layouts, totalBytes: offset);
  }

  Future<int> _probeLength(Uri uri) async {
    _validateUri(uri);
    final client = _clientFor(uri);
    try {
      final request = await client.openUrl('HEAD', uri).timeout(requestTimeout);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close().timeout(requestTimeout);
      try {
        if (response.statusCode >= 200 && response.statusCode < 400) {
          if (response.contentLength > 0) return response.contentLength;
          final raw = response.headers.value(HttpHeaders.contentLengthHeader);
          final parsed = int.tryParse(raw ?? '');
          if (parsed != null && parsed > 0) return parsed;
        }
      } finally {
        await response.drain<void>();
      }
    } catch (_) {}

    final request = await client.getUrl(uri).timeout(requestTimeout);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(requestTimeout);
    try {
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Probe failed with HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      final range = response.headers.value(HttpHeaders.contentRangeHeader);
      if (range != null) {
        final match = RegExp(r'/([0-9]+)$').firstMatch(range.trim());
        final parsed = int.tryParse(match?.group(1) ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
      if (response.statusCode == HttpStatus.ok && response.contentLength > 0) {
        return response.contentLength;
      }
      throw HttpException('Provider did not expose object length.', uri: uri);
    } finally {
      await response.drain<void>();
    }
  }

  List<_Chunk> _buildChunks(List<_PartLayout> layouts) {
    final chunks = <_Chunk>[];
    var index = 0;
    for (final layout in layouts) {
      for (var partOffset = 0;
          partOffset < layout.length;
          partOffset += chunkBytes) {
        final length = math.min(chunkBytes, layout.length - partOffset);
        chunks.add(_Chunk(
          index: index++,
          partIndex: layout.partIndex,
          fileOffset: layout.start + partOffset,
          partOffset: partOffset,
          length: length,
        ));
      }
    }
    return chunks;
  }

  Future<_ResumeState> _prepareResume({
    required File staging,
    required File journal,
    required Directory spool,
    required String fingerprint,
    required int totalBytes,
    required List<_Chunk> chunks,
  }) async {
    await spool.create(recursive: true);
    var committedPrefix = 0;
    var valid = false;

    if (await staging.exists() && await journal.exists()) {
      final decoded = _ResumeJournal.decode(await journal.readAsString());
      if (decoded != null &&
          decoded.fingerprint == fingerprint &&
          decoded.totalBytes == totalBytes &&
          decoded.chunkBytes == chunkBytes &&
          decoded.committedPrefixChunks >= 0 &&
          decoded.committedPrefixChunks <= chunks.length) {
        final expectedLength = _prefixBytes(
          chunks,
          decoded.committedPrefixChunks,
        );
        final actualLength = await staging.length();
        if (actualLength == expectedLength) {
          committedPrefix = decoded.committedPrefixChunks;
          valid = true;
        }
      }
    }

    if (!valid) {
      await _discardResume(staging, journal, spool);
      await staging.create(recursive: true);
      await spool.create(recursive: true);
      committedPrefix = 0;
    }

    final ready = <int>{};
    for (var i = committedPrefix; i < chunks.length; i++) {
      final file = _chunkFile(spool, i);
      if (!await file.exists()) continue;
      if (await file.length() == chunks[i].length) {
        ready.add(i);
      } else {
        await file.delete();
      }
    }

    return _ResumeState(
      committedPrefixChunks: committedPrefix,
      readyChunkIndexes: ready,
    );
  }

  Future<void> _downloadChunks({
    required File staging,
    required File journal,
    required Directory spool,
    required List<_Chunk> chunks,
    required List<_PartLayout> layouts,
    required String fingerprint,
    required int totalBytes,
    required _ResumeState resume,
    required NazaDownloadProgress? onProgress,
  }) async {
    var committedPrefix = resume.committedPrefixChunks;
    final ready = Set<int>.from(resume.readyChunkIndexes);
    final pending = Queue<_Chunk>.from(
      chunks.where(
        (chunk) => chunk.index >= committedPrefix && !ready.contains(chunk.index),
      ),
    );
    final active = <int, Future<_TransferResult>>{};
    var targetConcurrency = math.min(
      maxConcurrency,
      math.max(minConcurrency, 4),
    );
    var networkReceived = _readyBytes(chunks, ready);
    final started = Stopwatch()..start();
    final sink = staging.openWrite(mode: FileMode.writeOnlyAppend);

    Future<void> persist() async {
      final encoded = jsonEncode(_ResumeJournal(
        fingerprint: fingerprint,
        totalBytes: totalBytes,
        chunkBytes: chunkBytes,
        committedPrefixChunks: committedPrefix,
      ).toJson());
      final temp = File('${journal.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(journal.path);
    }

    Future<void> commitContiguous() async {
      var advanced = false;
      while (committedPrefix < chunks.length) {
        final chunk = chunks[committedPrefix];
        final file = _chunkFile(spool, chunk.index);
        if (!ready.contains(chunk.index) || !await file.exists()) break;
        if (await file.length() != chunk.length) {
          ready.remove(chunk.index);
          await file.delete();
          pending.addFirst(chunk);
          break;
        }
        await sink.addStream(file.openRead());
        ready.remove(chunk.index);
        await file.delete();
        committedPrefix++;
        advanced = true;
      }
      if (advanced) {
        await sink.flush();
        await persist();
      }
    }

    int deliveredBytes() =>
        _prefixBytes(chunks, committedPrefix) + _readyBytes(chunks, ready);

    void publish() {
      onProgress?.call(NazaDownloadSnapshot(
        stage: NazaDownloadStage.downloading,
        receivedBytes: deliveredBytes().clamp(0, totalBytes),
        totalBytes: totalBytes,
        activeTransfers: active.length,
        completedChunks: committedPrefix + ready.length,
        totalChunks: chunks.length,
        bytesPerSecond: networkReceived /
            math.max(0.001, started.elapsedMilliseconds / 1000),
        fastestProvider: _fastestProvider(),
      ));
    }

    try {
      await commitContiguous();
      while (committedPrefix < chunks.length) {
        while (active.length < targetConcurrency && pending.isNotEmpty) {
          final chunk = pending.removeFirst();
          active[chunk.index] = _downloadChunkToSpool(
            chunk: chunk,
            layouts: layouts,
            file: _chunkFile(spool, chunk.index),
          );
        }

        if (active.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          for (var i = committedPrefix; i < chunks.length; i++) {
            if (!ready.contains(i) &&
                !active.containsKey(i) &&
                !pending.any((chunk) => chunk.index == i)) {
              pending.add(chunks[i]);
            }
          }
          continue;
        }

        publish();
        final result = await Future.any(active.values);
        active.remove(result.chunk.index);
        if (result.ok) {
          ready.add(result.chunk.index);
          networkReceived += result.chunk.length;
          _providerBytes.update(
            result.provider!.source.id,
            (value) => value + result.chunk.length,
            ifAbsent: () => result.chunk.length,
          );
          _chunkAttempts.remove(result.chunk.index);
          await commitContiguous();
          if ((committedPrefix + ready.length) % 16 == 0 &&
              targetConcurrency < maxConcurrency) {
            targetConcurrency++;
          }
        } else {
          final attempts = _chunkAttempts.update(
            result.chunk.index,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          if (await result.file.exists()) await result.file.delete();
          if (attempts > 3) {
            Error.throwWithStackTrace(
              result.error ??
                  NazaModelDistributionException(
                    'Chunk ${result.chunk.index} exhausted all providers.',
                  ),
              result.stackTrace ?? StackTrace.current,
            );
          }
          pending.addLast(result.chunk);
          targetConcurrency = math.max(minConcurrency, targetConcurrency - 1);
        }
        publish();
      }
      await sink.flush();
      await persist();
    } finally {
      await sink.close();
    }

    final stagingLength = await staging.length();
    if (committedPrefix != chunks.length || stagingLength != totalBytes) {
      throw NazaModelDistributionException(
        'Download assembly incomplete: $committedPrefix/${chunks.length} '
        'chunks, $stagingLength/$totalBytes bytes.',
      );
    }
  }

  Future<_TransferResult> _downloadChunkToSpool({
    required _Chunk chunk,
    required List<_PartLayout> layouts,
    required File file,
  }) async {
    try {
      final provider = await _fetchChunk(chunk, layouts, file);
      return _TransferResult(
        chunk: chunk,
        file: file,
        provider: provider,
      );
    } catch (error, stack) {
      return _TransferResult(
        chunk: chunk,
        file: file,
        provider: null,
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<_ProviderState> _fetchChunk(
    _Chunk chunk,
    List<_PartLayout> layouts,
    File output,
  ) async {
    final candidates = <_ProviderState>[];
    for (final source in manifest.fullSources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }
    for (final source in manifest.parts[chunk.partIndex].sources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }

    if (candidates.isEmpty) {
      final waits = _providers.values
          .map((state) => state.backoffUntil)
          .whereType<DateTime>()
          .map((time) => time.difference(DateTime.now()))
          .where((duration) => duration > Duration.zero)
          .toList();
      if (waits.isNotEmpty) {
        waits.sort();
        await Future<void>.delayed(
          waits.first > const Duration(seconds: 2)
              ? const Duration(seconds: 2)
              : waits.first,
        );
      }
      return _fetchChunk(chunk, layouts, output);
    }

    candidates.sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore));
    Object? lastError;
    for (final provider in candidates.take(math.min(6, candidates.length))) {
      provider.inFlight++;
      final watch = Stopwatch()..start();
      try {
        final absolute = provider.source.isFullObject;
        final start = absolute ? chunk.fileOffset : chunk.partOffset;
        final end = absolute ? chunk.fileEndInclusive : chunk.partEndInclusive;
        await _rangeGetToFile(
          uri: provider.source.uri,
          start: start,
          end: end,
          output: output,
        );
        watch.stop();
        provider.success(chunk.length, watch.elapsed);
        return provider;
      } catch (error) {
        watch.stop();
        lastError = error;
        provider.failure();
        if (await output.exists()) await output.delete();
      } finally {
        provider.inFlight--;
      }
    }

    throw NazaModelDistributionException(
      'All providers failed for chunk ${chunk.index}: $lastError',
    );
  }

  Future<void> _rangeGetToFile({
    required Uri uri,
    required int start,
    required int end,
    required File output,
  }) async {
    _validateUri(uri);
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
      throw HttpException(
        'Range request failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final sink = output.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final frame in response.timeout(requestTimeout)) {
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

  HttpClient _clientFor(Uri uri) {
    final key = '${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : 443}';
    return _clients.putIfAbsent(key, () {
      final client = HttpClient()
        ..connectionTimeout = connectionTimeout
        ..idleTimeout = const Duration(seconds: 20)
        ..maxConnectionsPerHost = 3
        ..autoUncompress = false;
      client.userAgent = 'NAZA-One/1 model-distribution-v2';
      return client;
    });
  }

  static void _validateUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.trim().isEmpty) {
      throw NazaModelDistributionException(
        'Only HTTPS model sources are allowed: $uri',
      );
    }
    if (uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) {
      throw NazaModelDistributionException('Unsafe model source URI: $uri');
    }
  }

  static File _chunkFile(Directory spool, int index) =>
      File('${spool.path}/chunk_${index.toString().padLeft(6, '0')}.bin');

  static int _prefixBytes(List<_Chunk> chunks, int prefixChunks) {
    var total = 0;
    for (var i = 0; i < math.min(prefixChunks, chunks.length); i++) {
      total += chunks[i].length;
    }
    return total;
  }

  static int _readyBytes(List<_Chunk> chunks, Set<int> ready) {
    var total = 0;
    for (final index in ready) {
      if (index >= 0 && index < chunks.length) total += chunks[index].length;
    }
    return total;
  }

  String? _fastestProvider() {
    final states = _providers.values
        .where((state) => state.ewmaBps > 0)
        .toList(growable: false);
    if (states.isEmpty) return null;
    states.sort((a, b) => b.ewmaBps.compareTo(a.ewmaBps));
    return states.first.source.id;
  }

  static Future<String> _sha256File(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  static Future<void> _discardResume(
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
