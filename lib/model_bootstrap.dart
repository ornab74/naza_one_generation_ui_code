// LLM-CONTEXT:BEGIN
// FILE: lib/model_bootstrap.dart
// ROLE: Owns model bootstrap behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart' as app;

enum NazaModelDownloadSource { automatic, huggingFace, githubRelease }

final class NazaModelPart {
  final String name;
  final Uri uri;
  final int size;
  final String sha256;

  const NazaModelPart({
    required this.name,
    required this.uri,
    required this.size,
    required this.sha256,
  });
}

final class NazaModelBootstrapManifest {
  const NazaModelBootstrapManifest._();

  static final Uri huggingFaceUri = Uri.parse(
    app.NazaAppConfig.modelDownloadUrl,
  );

  static const String fullSha256 =
      'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42';

  static final List<NazaModelPart>
  githubReleaseParts = List<NazaModelPart>.unmodifiable(<NazaModelPart>[
    NazaModelPart(
      name: 'gemma-4-E2B-it.litertlm.part00.bin',
      uri: Uri.parse(
        'https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part00.bin',
      ),
      size: 861028352,
      sha256:
          'b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995',
    ),
    NazaModelPart(
      name: 'gemma-4-E2B-it.litertlm.part01.bin',
      uri: Uri.parse(
        'https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part01.bin',
      ),
      size: 861028352,
      sha256:
          '5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8',
    ),
    NazaModelPart(
      name: 'gemma-4-E2B-it.litertlm.part02.bin',
      uri: Uri.parse(
        'https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part02.bin',
      ),
      size: 861028352,
      sha256:
          '00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3',
    ),
  ]);

  static int get githubJoinedSize =>
      githubReleaseParts.fold<int>(0, (total, part) => total + part.size);

  static void validate() {
    final full = fullSha256.toLowerCase();
    if (full != app.NazaAppConfig.modelSha256.toLowerCase()) {
      throw StateError('Bootstrap model SHA-256 does not match app trust pin.');
    }
    if (!_isSha256(full)) {
      throw StateError('Invalid full model SHA-256 pin.');
    }
    if (githubReleaseParts.isEmpty) {
      throw StateError('GitHub model release has no parts.');
    }
    for (var index = 0; index < githubReleaseParts.length; index++) {
      final part = githubReleaseParts[index];
      final suffix = 'part${index.toString().padLeft(2, '0')}.bin';
      if (!part.name.endsWith(suffix)) {
        throw StateError('GitHub model parts are not in strict join order.');
      }
      if (part.size <= 0 || !_isSha256(part.sha256)) {
        throw StateError('Invalid GitHub model part manifest: ${part.name}.');
      }
      _requireHttps(part.uri, allowedHosts: const {'github.com'});
    }
    _requireHttps(huggingFaceUri, allowedHosts: const {'huggingface.co'});
  }

  static bool _isSha256(String value) =>
      RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

  static void _requireHttps(Uri uri, {required Set<String> allowedHosts}) {
    if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) {
      throw StateError('Untrusted model source URI: $uri');
    }
  }
}

final class NazaModelIntegrityException implements Exception {
  final String message;

  const NazaModelIntegrityException(this.message);

  @override
  String toString() => 'Model integrity failure: $message';
}

final class NazaModelSourceUnavailable implements Exception {
  final Uri uri;
  final String reason;

  const NazaModelSourceUnavailable(this.uri, this.reason);

  @override
  String toString() => 'Model source unavailable (${uri.host}): $reason';
}

final class NazaModelIntegrity {
  const NazaModelIntegrity._();

  static Future<String> sha256File(
    File file, {
    void Function(int bytesRead, int totalBytes)? onProgress,
  }) async {
    final total = await file.length();
    final collector = _DigestCollector();
    final sink = crypto.sha256.startChunkedConversion(collector);
    var read = 0;
    await for (final chunk in file.openRead()) {
      read += chunk.length;
      sink.add(chunk);
      onProgress?.call(read, total);
    }
    sink.close();
    final digest = collector.digest;
    if (digest == null) {
      throw const NazaModelIntegrityException(
        'SHA-256 computation produced no digest.',
      );
    }
    return digest.toString();
  }

  static Future<void> verifyFile({
    required File file,
    required String expectedSha256,
    int? expectedSize,
    void Function(int bytesRead, int totalBytes)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw NazaModelIntegrityException('Missing file: ${file.path}');
    }
    final size = await file.length();
    if (expectedSize != null && size != expectedSize) {
      throw NazaModelIntegrityException(
        'Size mismatch for ${file.path}: expected $expectedSize, got $size.',
      );
    }
    final actual = await sha256File(file, onProgress: onProgress);
    if (!_constantTimeHexEquals(actual, expectedSha256)) {
      throw NazaModelIntegrityException(
        'SHA-256 mismatch for ${file.path}: expected $expectedSha256, got $actual.',
      );
    }
  }

  static bool _constantTimeHexEquals(String a, String b) {
    final left = a.toLowerCase();
    final right = b.toLowerCase();
    if (left.length != right.length) return false;
    var diff = 0;
    for (var index = 0; index < left.length; index++) {
      diff |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return diff == 0;
  }
}

final class _DigestCollector implements Sink<crypto.Digest> {
  crypto.Digest? digest;

  @override
  void add(crypto.Digest data) {
    if (digest != null) {
      throw StateError('Unexpected second SHA-256 digest.');
    }
    digest = data;
  }

  @override
  void close() {}
}

typedef NazaBootstrapProgress =
    void Function(int percent, String phase, String detail);

final class NazaVerifiedModelDownloader {
  static const int _maxModelBytes = 8 * 1024 * 1024 * 1024;
  static const Duration _connectTimeout = Duration(seconds: 25);
  static const Duration _responseTimeout = Duration(seconds: 35);
  static const Duration _idleTimeout = Duration(seconds: 45);

  const NazaVerifiedModelDownloader();

  Future<File> install({
    required NazaModelDownloadSource source,
    required File target,
    NazaBootstrapProgress? onProgress,
  }) async {
    NazaModelBootstrapManifest.validate();
    await target.parent.create(recursive: true);

    switch (source) {
      case NazaModelDownloadSource.huggingFace:
        return _installFromHuggingFace(target, onProgress: onProgress);
      case NazaModelDownloadSource.githubRelease:
        return _installFromGitHubRelease(target, onProgress: onProgress);
      case NazaModelDownloadSource.automatic:
        try {
          return await _installFromHuggingFace(target, onProgress: onProgress);
        } on NazaModelSourceUnavailable catch (error) {
          onProgress?.call(
            1,
            'Hugging Face unavailable — switching to GitHub',
            error.reason,
          );
          return _installFromGitHubRelease(target, onProgress: onProgress);
        }
    }
  }

  Future<File> _installFromHuggingFace(
    File target, {
    NazaBootstrapProgress? onProgress,
  }) async {
    final staging = File('${target.path}.huggingface.download');
    await _deleteIfExists(staging);
    try {
      onProgress?.call(
        2,
        'Downloading from Hugging Face',
        'Pinned model revision',
      );
      await _downloadToFile(
        uri: NazaModelBootstrapManifest.huggingFaceUri,
        destination: staging,
        maxBytes: _maxModelBytes,
        onBytes: (received, total) {
          final percent = total != null && total > 0
              ? _boundedInt(2 + (received * 78 ~/ total), 2, 80)
              : 25;
          onProgress?.call(
            percent,
            'Downloading from Hugging Face',
            _formatTransfer(received, total),
          );
        },
      );

      onProgress?.call(
        82,
        'Verifying complete model SHA-256',
        'Hugging Face download',
      );
      await NazaModelIntegrity.verifyFile(
        file: staging,
        expectedSha256: NazaModelBootstrapManifest.fullSha256,
        onProgress: (read, total) {
          final percent = _boundedInt(
            82 + (read * 15 ~/ (total == 0 ? 1 : total)),
            82,
            97,
          );
          onProgress?.call(
            percent,
            'Verifying complete model SHA-256',
            _formatTransfer(read, total),
          );
        },
      );
      return _promoteVerified(staging, target, onProgress: onProgress);
    } catch (_) {
      await _deleteIfExists(staging);
      rethrow;
    }
  }

  Future<File> _installFromGitHubRelease(
    File target, {
    NazaBootstrapProgress? onProgress,
  }) async {
    final joined = File('${target.path}.github.joining');
    await _deleteIfExists(joined);
    final joinedSink = joined.openWrite(mode: FileMode.writeOnly);
    var joinedBytes = 0;
    var sinkClosed = false;

    try {
      final parts = NazaModelBootstrapManifest.githubReleaseParts;
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        final partFile = File('${target.path}.${part.name}.download');
        await _deleteIfExists(partFile);

        try {
          final base = 2 + (index * 20);
          onProgress?.call(
            base,
            'Downloading GitHub model part ${index + 1}/${parts.length}',
            part.name,
          );
          await _downloadToFile(
            uri: part.uri,
            destination: partFile,
            maxBytes: part.size,
            onBytes: (received, _) {
              final percent = _boundedInt(
                base + (received * 12 ~/ part.size),
                base,
                base + 12,
              );
              onProgress?.call(
                percent,
                'Downloading GitHub model part ${index + 1}/${parts.length}',
                _formatTransfer(received, part.size),
              );
            },
          );

          onProgress?.call(
            base + 13,
            'Checking SHA-256 for part ${index + 1}/${parts.length}',
            part.sha256,
          );
          await NazaModelIntegrity.verifyFile(
            file: partFile,
            expectedSha256: part.sha256,
            expectedSize: part.size,
            onProgress: (read, total) {
              final percent = _boundedInt(
                base + 13 + (read * 4 ~/ (total == 0 ? 1 : total)),
                base + 13,
                base + 17,
              );
              onProgress?.call(
                percent,
                'Checking SHA-256 for part ${index + 1}/${parts.length}',
                _formatTransfer(read, total),
              );
            },
          );

          onProgress?.call(
            base + 18,
            'Joining verified part ${index + 1}/${parts.length}',
            part.name,
          );
          await for (final chunk in partFile.openRead()) {
            joinedSink.add(chunk);
            joinedBytes += chunk.length;
          }
          await joinedSink.flush();
        } finally {
          await _deleteIfExists(partFile);
        }
      }

      await joinedSink.flush();
      await joinedSink.close();
      sinkClosed = true;

      if (joinedBytes != NazaModelBootstrapManifest.githubJoinedSize) {
        throw NazaModelIntegrityException(
          'Joined model size mismatch: expected '
          '${NazaModelBootstrapManifest.githubJoinedSize}, got $joinedBytes.',
        );
      }

      onProgress?.call(
        65,
        'All parts joined — checking complete model SHA-256',
        NazaModelBootstrapManifest.fullSha256,
      );
      await NazaModelIntegrity.verifyFile(
        file: joined,
        expectedSha256: NazaModelBootstrapManifest.fullSha256,
        expectedSize: NazaModelBootstrapManifest.githubJoinedSize,
        onProgress: (read, total) {
          final percent = _boundedInt(
            65 + (read * 32 ~/ (total == 0 ? 1 : total)),
            65,
            97,
          );
          onProgress?.call(
            percent,
            'Checking complete joined model SHA-256',
            _formatTransfer(read, total),
          );
        },
      );
      return _promoteVerified(joined, target, onProgress: onProgress);
    } catch (_) {
      if (!sinkClosed) {
        try {
          await joinedSink.close();
        } catch (_) {}
      }
      await _deleteIfExists(joined);
      rethrow;
    }
  }

  Future<File> _promoteVerified(
    File staging,
    File target, {
    NazaBootstrapProgress? onProgress,
  }) async {
    onProgress?.call(98, 'Promoting verified model', target.path);
    if (await target.exists()) {
      await target.delete();
    }
    final promoted = await staging.rename(target.path);
    onProgress?.call(100, 'Verified model ready', promoted.path);
    return promoted;
  }

  Future<void> _downloadToFile({
    required Uri uri,
    required File destination,
    required int maxBytes,
    required void Function(int received, int? total) onBytes,
  }) async {
    if (uri.scheme != 'https') {
      throw NazaModelIntegrityException('Refusing non-HTTPS model URI: $uri');
    }

    final client = HttpClient()..connectionTimeout = _connectTimeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(uri).timeout(_connectTimeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Naza-One verified-model-bootstrap/1',
      );
      final response = await request.close().timeout(_responseTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NazaModelSourceUnavailable(
          uri,
          'HTTP ${response.statusCode} ${response.reasonPhrase}'.trim(),
        );
      }

      final declared = response.contentLength >= 0
          ? response.contentLength
          : null;
      if (declared != null && declared > maxBytes) {
        throw NazaModelIntegrityException(
          'Source declared $declared bytes, above the allowed $maxBytes bytes.',
        );
      }

      sink = destination.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      await for (final chunk in response.timeout(_idleTimeout)) {
        received += chunk.length;
        if (received > maxBytes) {
          throw const NazaModelIntegrityException(
            'Source exceeded the allowed model size while downloading.',
          );
        }
        sink.add(chunk);
        onBytes(received, declared);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } on SocketException catch (error) {
      throw NazaModelSourceUnavailable(uri, error.message);
    } on HandshakeException catch (error) {
      throw NazaModelSourceUnavailable(uri, error.message);
    } on TimeoutException catch (error) {
      throw NazaModelSourceUnavailable(uri, error.message ?? 'network timeout');
    } on HttpException catch (error) {
      throw NazaModelSourceUnavailable(uri, error.message);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close(force: true);
    }
  }

  static int _boundedInt(int value, int minimum, int maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String _formatTransfer(int received, int? total) {
    String gib(int bytes) => (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
    if (total == null || total <= 0) {
      return '${gib(received)} GiB received';
    }
    return '${gib(received)} / ${gib(total)} GiB';
  }
}

final class NazaModelBootstrap {
  const NazaModelBootstrap._();

  static Future<void> launch() async {
    WidgetsFlutterBinding.ensureInitialized();
    NazaModelBootstrapManifest.validate();
    runApp(const _NazaModelBootstrapApp());
  }
}

final class _NazaModelBootstrapApp extends StatelessWidget {
  const _NazaModelBootstrapApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Naza One · Model Bootstrap',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: app.NazaPalette.inkDeep,
        colorScheme: ColorScheme.fromSeed(
          seedColor: app.NazaPalette.mint,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      home: const _NazaModelBootstrapScreen(),
    );
  }
}

final class _NazaModelBootstrapScreen extends StatefulWidget {
  const _NazaModelBootstrapScreen();

  @override
  State<_NazaModelBootstrapScreen> createState() =>
      _NazaModelBootstrapScreenState();
}

final class _NazaModelBootstrapScreenState
    extends State<_NazaModelBootstrapScreen> {
  NazaModelDownloadSource _source = NazaModelDownloadSource.automatic;
  bool _checking = true;
  bool _busy = false;
  bool _launched = false;
  int _progress = 0;
  String _phase = 'Checking verified model cache';
  String _detail = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_checkExistingModel());
  }

  Future<void> _checkExistingModel() async {
    try {
      final current = await app.NazaSecureModelStore.refresh();
      if (!mounted) return;
      if (current.installed) {
        setState(() {
          _checking = false;
          _progress = 100;
          _phase = current.phase;
          _detail = current.localPath ?? current.cachePath;
        });
        await _launchMainApp();
        return;
      }
      setState(() {
        _checking = false;
        _phase = 'Choose a verified model source';
        _detail =
            'Automatic tries the pinned Hugging Face revision first and uses the GitHub v1 release only when the source is unavailable.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _phase = 'Model cache needs installation';
        _detail = 'Select a source below.';
        _error = error.toString();
      });
    }
  }

  Future<void> _downloadAndLaunch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });

    try {
      final support = await getApplicationSupportDirectory();
      final target = File(
        '${support.path}/verified_models/${app.NazaAppConfig.modelFileName}',
      );
      const downloader = NazaVerifiedModelDownloader();
      await downloader.install(
        source: _source,
        target: target,
        onProgress: (percent, phase, detail) {
          if (!mounted) return;
          setState(() {
            _progress = percent;
            _phase = phase;
            _detail = detail;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _phase = 'Registering model with encrypted attestation';
        _detail =
            'The existing Naza model store is performing its final trust check.';
      });
      final verified = await app.NazaSecureModelStore.refresh();
      if (!verified.installed) {
        throw NazaModelIntegrityException(
          verified.error ??
              'Existing Naza model attestation did not accept the file.',
        );
      }
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _phase = 'Verified model ready';
        _detail = verified.cachePath;
      });
      await _launchMainApp();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
        _phase = error is NazaModelIntegrityException
            ? 'Integrity check failed — model rejected'
            : 'Model download failed';
      });
    }
  }

  Future<void> _launchMainApp() async {
    if (_launched) return;
    _launched = true;
    await app.main();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _checking || _busy;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: app.NazaPalette.panel,
                  border: Border.all(color: app.NazaPalette.border),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.shield_moon_rounded,
                        size: 56,
                        color: app.NazaPalette.mint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verified Model Startup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: app.NazaPalette.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gemma 4 E2B · LiteRT-LM',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: app.NazaPalette.subtext),
                      ),
                      const SizedBox(height: 28),
                      app.NazaProgressBar(
                        value: _busy || _checking ? _progress / 100 : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _phase,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: app.NazaPalette.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _detail,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: app.NazaPalette.subtext),
                      ),
                      const SizedBox(height: 26),
                      SegmentedButton<NazaModelDownloadSource>(
                        segments: const [
                          ButtonSegment(
                            value: NazaModelDownloadSource.automatic,
                            icon: Icon(Icons.auto_awesome_rounded),
                            label: Text('Automatic'),
                          ),
                          ButtonSegment(
                            value: NazaModelDownloadSource.huggingFace,
                            icon: Icon(Icons.cloud_download_rounded),
                            label: Text('Hugging Face'),
                          ),
                          ButtonSegment(
                            value: NazaModelDownloadSource.githubRelease,
                            icon: Icon(Icons.hub_rounded),
                            label: Text('GitHub'),
                          ),
                        ],
                        selected: {_source},
                        onSelectionChanged: locked
                            ? null
                            : (selection) {
                                setState(() => _source = selection.single);
                              },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _sourceDescription(_source),
                        style: TextStyle(
                          color: app.NazaPalette.muted,
                          fontSize: 13,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: app.NazaPalette.danger.withValues(
                              alpha: 0.08,
                            ),
                            border: Border.all(
                              color: app.NazaPalette.danger.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: app.NazaPalette.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: locked ? null : _downloadAndLaunch,
                        icon: Icon(Icons.download_for_offline_rounded),
                        label: Text(
                          _busy
                              ? 'Downloading & verifying…'
                              : 'Download, Verify & Start Naza One',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Security rule: a source outage may trigger fallback; a SHA-256 mismatch never does. Every GitHub part is checked before joining, then the joined model is checked again against the app-pinned full SHA-256.',
                        style: TextStyle(
                          color: app.NazaPalette.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _sourceDescription(NazaModelDownloadSource source) {
    switch (source) {
      case NazaModelDownloadSource.automatic:
        return 'Recommended · pinned Hugging Face first; GitHub v1 fallback only if Hugging Face is unavailable.';
      case NazaModelDownloadSource.huggingFace:
        return 'Pinned Hugging Face revision only · the complete model must match the trusted full SHA-256.';
      case NazaModelDownloadSource.githubRelease:
        return 'GitHub release v1 · verify part00, part01, part02 individually, join in order, then verify the complete model.';
    }
  }
}
