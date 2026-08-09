import 'dart:async';
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
  int get endExclusive => start + length;
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
    final speed = ewmaBps <= 0 ? 1.0 : math.log(1 + ewmaBps / 1048576.0) + 1.0;
    final reliability = (successes + 1) / (successes + failures + 1);
    final pressure = 1 / (1 + inFlight * 0.75);
    return score * speed * reliability * pressure;
  }

  void success(int bytes, Duration elapsed) {
    successes++;
    failures = math.max(0, failures - 1);
    final seconds = math.max(elapsed.inMicroseconds / 1000000.0, 0.001);
    final bps = bytes / seconds;
    ewmaBps = ewmaBps == 0 ? bps : ewmaBps * 0.72 + bps * 0.28;
    score = math.min(8.0, score * 1.04 + 0.01);
    backoffUntil = null;
  }

  void failure() {
    failures++;
    score = math.max(0.10, score * 0.62);
    final seconds = math.min(20, 1 << math.min(4, failures - 1));
    backoffUntil = DateTime.now().add(Duration(seconds: seconds));
  }
}

final class _ResumeJournal {
  const _ResumeJournal({
    required this.fingerprint,
    required this.totalBytes,
    required this.chunkBytes,
    required this.completed,
  });

  final String fingerprint;
  final int totalBytes;
  final int chunkBytes;
  final Set<int> completed;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'naza-model-download-journal-v1',
        'fingerprint': fingerprint,
        'totalBytes': totalBytes,
        'chunkBytes': chunkBytes,
        'completed': completed.toList()..sort(),
      };

  static _ResumeJournal? decode(String text) {
    try {
      final raw = jsonDecode(text);
      if (raw is! Map || raw['schema'] != 'naza-model-download-journal-v1') {
        return null;
      }
      final completedRaw = raw['completed'];
      if (completedRaw is! List) return null;
      return _ResumeJournal(
        fingerprint: raw['fingerprint']?.toString() ?? '',
        totalBytes: (raw['totalBytes'] as num?)?.toInt() ?? -1,
        chunkBytes: (raw['chunkBytes'] as num?)?.toInt() ?? -1,
        completed: completedRaw
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 0)
            .toSet(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Multi-plane, multi-provider downloader optimized for very large immutable
/// model files. It behaves like a conservative HTTPS swarm:
///
/// * full-object HTTP range source + independently hosted part replicas;
/// * bounded adaptive concurrency rather than unbounded socket fan-out;
/// * per-provider EWMA throughput/reliability scoring;
/// * random-access chunk writes, so chunks complete out of order;
/// * resumable chunk journal;
/// * provider backoff and immediate failover;
/// * end-to-end SHA-256 verification before atomic promotion.
///
/// It intentionally avoids retaining model chunks in memory. Each transfer
/// buffers at most one network frame plus an optional small response list.
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
    final partLayouts = topology.layouts;
    final totalBytes = topology.totalBytes;
    if (totalBytes <= 0 || totalBytes > 8 * 1024 * 1024 * 1024) {
      throw NazaModelDistributionException(
        'Invalid model size reported by distribution sources: $totalBytes.',
      );
    }

    final partSizes = partLayouts.map((layout) => layout.length).toList();
    final fingerprint = manifest.fingerprintFor(
      totalBytes: totalBytes,
      partSizes: partSizes,
      chunkBytes: chunkBytes,
    );
    final staging = File('${target.path}.multiplane.part');
    final journalFile = File('${staging.path}.json');
    final chunks = _buildChunks(partLayouts);
    final completed = await _prepareResume(
      staging: staging,
      journalFile: journalFile,
      fingerprint: fingerprint,
      totalBytes: totalBytes,
      chunks: chunks,
    );

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.allocating,
      receivedBytes: _completedBytes(chunks, completed),
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: completed.length,
      totalChunks: chunks.length,
      bytesPerSecond: 0,
      fastestProvider: null,
    ));

    final random = await staging.open(mode: FileMode.write);
    try {
      await random.truncate(totalBytes);
      await _downloadChunks(
        random: random,
        chunks: chunks,
        completed: completed,
        layouts: partLayouts,
        journalFile: journalFile,
        fingerprint: fingerprint,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );
      await random.flush();
    } finally {
      await random.close();
    }

    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.verifying,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: chunks.length,
      totalChunks: chunks.length,
      bytesPerSecond: totalBytes / math.max(0.001, stopwatch.elapsedMilliseconds / 1000),
      fastestProvider: _fastestProvider(),
    ));

    final digest = await _sha256File(staging);
    final expected = manifest.expectedSha256.toLowerCase();
    if (digest != expected) {
      await staging.delete().catchError((_) => staging);
      await journalFile.delete().catchError((_) => journalFile);
      throw NazaModelDistributionException(
        'Final model SHA-256 mismatch. Expected $expected, got $digest.',
      );
    }

    if (await target.exists()) await target.delete();
    await staging.rename(target.path);
    if (await journalFile.exists()) await journalFile.delete();
    stopwatch.stop();
    onProgress?.call(NazaDownloadSnapshot(
      stage: NazaDownloadStage.complete,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      activeTransfers: 0,
      completedChunks: chunks.length,
      totalChunks: chunks.length,
      bytesPerSecond: totalBytes / math.max(0.001, stopwatch.elapsedMilliseconds / 1000),
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
    for (var index = 0; index < partLengths.length; index++) {
      layouts.add(_PartLayout(
        partIndex: index,
        start: offset,
        length: partLengths[index],
      ));
      offset += partLengths[index];
    }

    // The canonical source is independently probed as an integrity/topology
    // cross-check. If it is temporarily unavailable, the replicated part plane
    // can still proceed; final SHA-256 remains authoritative.
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
    final request = await client.openUrl('HEAD', uri).timeout(requestTimeout);
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close().timeout(requestTimeout);
    try {
      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (response.contentLength > 0) return response.contentLength;
        final header = response.headers.value(HttpHeaders.contentLengthHeader);
        final parsed = int.tryParse(header ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
    } finally {
      await response.drain<void>();
    }

    // Some gateways reject HEAD. A one-byte range request gives total size in
    // Content-Range without downloading the object.
    final rangeRequest = await client.getUrl(uri).timeout(requestTimeout);
    rangeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final rangeResponse = await rangeRequest.close().timeout(requestTimeout);
    try {
      if (rangeResponse.statusCode != HttpStatus.partialContent &&
          rangeResponse.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Probe failed with HTTP ${rangeResponse.statusCode}.',
          uri: uri,
        );
      }
      final contentRange = rangeResponse.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        final match = RegExp(r'/([0-9]+)$').firstMatch(contentRange.trim());
        final total = int.tryParse(match?.group(1) ?? '');
        if (total != null && total > 0) return total;
      }
      if (rangeResponse.statusCode == HttpStatus.ok && rangeResponse.contentLength > 0) {
        return rangeResponse.contentLength;
      }
      throw HttpException('Provider did not expose object length.', uri: uri);
    } finally {
      await rangeResponse.drain<void>();
    }
  }

  List<_Chunk> _buildChunks(List<_PartLayout> layouts) {
    final chunks = <_Chunk>[];
    var index = 0;
    for (final layout in layouts) {
      for (var partOffset = 0; partOffset < layout.length; partOffset += chunkBytes) {
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

  Future<Set<int>> _prepareResume({
    required File staging,
    required File journalFile,
    required String fingerprint,
    required int totalBytes,
    required List<_Chunk> chunks,
  }) async {
    if (!await staging.exists() || !await journalFile.exists()) {
      if (await staging.exists()) await staging.delete();
      if (await journalFile.exists()) await journalFile.delete();
      await staging.create(recursive: true);
      return <int>{};
    }
    final journal = _ResumeJournal.decode(await journalFile.readAsString());
    final length = await staging.length();
    if (journal == null ||
        journal.fingerprint != fingerprint ||
        journal.totalBytes != totalBytes ||
        journal.chunkBytes != chunkBytes ||
        length != totalBytes) {
      await staging.delete();
      await journalFile.delete();
      await staging.create(recursive: true);
      return <int>{};
    }
    return journal.completed.where((index) => index < chunks.length).toSet();
  }

  Future<void> _downloadChunks({
    required RandomAccessFile random,
    required List<_Chunk> chunks,
    required Set<int> completed,
    required List<_PartLayout> layouts,
    required File journalFile,
    required String fingerprint,
    required int totalBytes,
    required NazaDownloadProgress? onProgress,
  }) async {
    final pending = <_Chunk>[
      for (final chunk in chunks)
        if (!completed.contains(chunk.index)) chunk,
    ];
    var received = _completedBytes(chunks, completed);
    var active = 0;
    var targetConcurrency = math.min(maxConcurrency, math.max(minConcurrency, 4));
    final started = Stopwatch()..start();
    var journalDirty = 0;
    final writeLock = _AsyncLock();
    final queueLock = _AsyncLock();
    Object? fatal;
    StackTrace? fatalStack;

    void publish() {
      onProgress?.call(NazaDownloadSnapshot(
        stage: NazaDownloadStage.downloading,
        receivedBytes: received,
        totalBytes: totalBytes,
        activeTransfers: active,
        completedChunks: completed.length,
        totalChunks: chunks.length,
        bytesPerSecond: received / math.max(0.001, started.elapsedMilliseconds / 1000),
        fastestProvider: _fastestProvider(),
      ));
    }

    Future<void> saveJournal({bool force = false}) async {
      if (!force && journalDirty < 8) return;
      journalDirty = 0;
      final journal = _ResumeJournal(
        fingerprint: fingerprint,
        totalBytes: totalBytes,
        chunkBytes: chunkBytes,
        completed: Set<int>.from(completed),
      );
      final temp = File('${journalFile.path}.tmp');
      await temp.writeAsString(jsonEncode(journal.toJson()), flush: true);
      if (await journalFile.exists()) await journalFile.delete();
      await temp.rename(journalFile.path);
    }

    Future<void> worker() async {
      while (fatal == null) {
        _Chunk? chunk;
        await queueLock.run(() async {
          if (pending.isNotEmpty) chunk = pending.removeAt(0);
        });
        if (chunk == null) return;
        active++;
        publish();
        try {
          final transfer = await _fetchChunk(chunk!, layouts);
          await writeLock.run(() async {
            await random.setPosition(chunk!.fileOffset);
            await random.writeFrom(transfer.bytes);
          });
          completed.add(chunk!.index);
          received += chunk!.length;
          _providerBytes.update(
            transfer.provider.source.id,
            (value) => value + chunk!.length,
            ifAbsent: () => chunk!.length,
          );
          journalDirty++;
          await saveJournal();
          // Increase cautiously after successful work. This saturates healthy
          // links without allowing a large phone/desktop socket explosion.
          if (completed.length % 12 == 0 && targetConcurrency < maxConcurrency) {
            targetConcurrency++;
          }
        } catch (error, stack) {
          // Requeue transient chunks. _fetchChunk tries all suitable providers
          // first, so reaching this point means the current topology is not
          // making progress. Keep one bounded retry round before failing.
          final attempts = _chunkAttempts.update(
            chunk!.index,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          if (attempts <= 2) {
            await queueLock.run(() async => pending.add(chunk!));
            targetConcurrency = math.max(minConcurrency, targetConcurrency - 1);
          } else {
            fatal = error;
            fatalStack = stack;
          }
        } finally {
          active--;
          publish();
        }
      }
    }

    final workers = <Future<void>>[];
    // Spawn maxConcurrency lightweight workers. A worker waits for a permit
    // before network I/O; targetConcurrency is adjusted while the run proceeds.
    final gate = _AdaptiveGate(() => targetConcurrency);
    for (var i = 0; i < maxConcurrency; i++) {
      workers.add(() async {
        while (fatal == null) {
          if (pending.isEmpty) return;
          await gate.enter(active);
          await worker();
          return;
        }
      }());
    }
    await Future.wait(workers);
    await saveJournal(force: true);
    if (fatal != null) {
      Error.throwWithStackTrace(fatal!, fatalStack ?? StackTrace.current);
    }
    if (completed.length != chunks.length) {
      throw NazaModelDistributionException(
        'Download ended with ${completed.length}/${chunks.length} chunks complete.',
      );
    }
  }

  final Map<int, int> _chunkAttempts = <int, int>{};

  Future<({List<int> bytes, _ProviderState provider})> _fetchChunk(
    _Chunk chunk,
    List<_PartLayout> layouts,
  ) async {
    final candidates = <_ProviderState>[];
    // Canonical full-object source can satisfy every chunk by absolute range.
    for (final source in manifest.fullSources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }
    // Part mirrors satisfy the same chunk by part-relative range.
    final part = manifest.parts[chunk.partIndex];
    for (final source in part.sources) {
      final state = _providers[source.id]!;
      if (state.available) candidates.add(state);
    }
    if (candidates.isEmpty) {
      final soonest = _providers.values
          .map((state) => state.backoffUntil)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (best, value) =>
              best == null || value.isBefore(best) ? value : best);
      if (soonest != null) {
        final wait = soonest.difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      return _fetchChunk(chunk, layouts);
    }
    candidates.sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore));

    Object? lastError;
    for (final provider in candidates.take(math.min(5, candidates.length))) {
      provider.inFlight++;
      final watch = Stopwatch()..start();
      try {
        final absolute = provider.source.isFullObject;
        final start = absolute ? chunk.fileOffset : chunk.partOffset;
        final end = absolute ? chunk.fileEndInclusive : chunk.partEndInclusive;
        final bytes = await _rangeGet(provider.source.uri, start, end);
        if (bytes.length != chunk.length) {
          throw NazaModelDistributionException(
            '${provider.source.id} returned ${bytes.length} bytes for a '
            '${chunk.length}-byte chunk.',
          );
        }
        watch.stop();
        provider.success(bytes.length, watch.elapsed);
        return (bytes: bytes, provider: provider);
      } catch (error) {
        watch.stop();
        lastError = error;
        provider.failure();
      } finally {
        provider.inFlight--;
      }
    }
    throw NazaModelDistributionException(
      'All providers failed for chunk ${chunk.index}: $lastError',
    );
  }

  Future<List<int>> _rangeGet(Uri uri, int start, int end) async {
    _validateUri(uri);
    final request = await _clientFor(uri).getUrl(uri).timeout(requestTimeout);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(requestTimeout);
    if (response.statusCode != HttpStatus.partialContent &&
        !(start == 0 && response.statusCode == HttpStatus.ok)) {
      await response.drain<void>();
      throw HttpException(
        'Range request failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final expected = end - start + 1;
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final frame in response.timeout(requestTimeout)) {
      received += frame.length;
      if (received > expected) {
        throw NazaModelDistributionException(
          'Provider exceeded requested range ($received > $expected).',
        );
      }
      builder.add(frame);
    }
    if (received != expected) {
      throw NazaModelDistributionException(
        'Provider ended range at $received of $expected bytes.',
      );
    }
    return builder.takeBytes();
  }

  HttpClient _clientFor(Uri uri) {
    final key = '${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : 443}';
    return _clients.putIfAbsent(key, () {
      final client = HttpClient()
        ..connectionTimeout = connectionTimeout
        ..idleTimeout = const Duration(seconds: 20)
        ..maxConnectionsPerHost = 4
        ..autoUncompress = false;
      client.userAgent = 'NAZA-One/1 model-distribution-v2';
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

  static int _completedBytes(List<_Chunk> chunks, Set<int> completed) => chunks
      .where((chunk) => completed.contains(chunk.index))
      .fold<int>(0, (sum, chunk) => sum + chunk.length);

  String? _fastestProvider() {
    final states = _providers.values.where((state) => state.ewmaBps > 0).toList();
    if (states.isEmpty) return null;
    states.sort((a, b) => b.ewmaBps.compareTo(a.ewmaBps));
    return states.first.source.id;
  }

  static Future<String> _sha256File(File file) async {
    final sink = crypto.AccumulatorSink<crypto.Digest>();
    final input = crypto.sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    if (sink.events.length != 1) {
      throw const NazaModelDistributionException('SHA-256 finalization failed.');
    }
    return sink.events.single.toString().toLowerCase();
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

final class _AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}

final class _AdaptiveGate {
  const _AdaptiveGate(this.limit);
  final int Function() limit;

  Future<void> enter(int active) async {
    while (active >= limit()) {
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }
}
