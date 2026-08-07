import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'model_manifest.dart';

enum ModelDownloadPhase { checking, downloading, verifying, ready }

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes,
    this.gatewayHost,
  });

  final ModelDownloadPhase phase;
  final int receivedBytes;
  final int? totalBytes;
  final String? gatewayHost;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1);
  }
}

class VerifiedModel {
  const VerifiedModel({
    required this.file,
    required this.sha256,
    required this.bytes,
  });

  final File file;
  final String sha256;
  final int bytes;
}

class SecureModelDownloader {
  SecureModelDownloader({
    HttpClient? httpClient,
    this.connectTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 45),
    this.maximumBytes = 12 * 1024 * 1024 * 1024,
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final Duration connectTimeout;
  final Duration idleTimeout;
  final int maximumBytes;

  Future<VerifiedModel> ensureModel({
    required ModelManifest manifest,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    manifest.validate();
    onProgress(const ModelDownloadProgress(phase: ModelDownloadPhase.checking));

    final directory = await _modelDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}${manifest.fileName}',
    );
    final partial = File('${target.path}.part');

    if (await target.exists()) {
      final verified = await _verifyFile(target, manifest, onProgress);
      if (verified != null) return verified;
      await target.delete();
    }

    if (await partial.exists()) await partial.delete();

    Object? lastError;
    for (final uri in manifest.gatewayUris) {
      try {
        await _downloadToPartial(
          uri: uri,
          partial: partial,
          manifest: manifest,
          onProgress: onProgress,
        );

        final verified = await _verifyFile(partial, manifest, onProgress);
        if (verified == null) {
          throw const ModelDownloadException(
            'The downloaded model failed integrity verification.',
          );
        }

        if (await target.exists()) await target.delete();
        await partial.rename(target.path);

        onProgress(
          ModelDownloadProgress(
            phase: ModelDownloadPhase.ready,
            receivedBytes: verified.bytes,
            totalBytes: verified.bytes,
          ),
        );

        return VerifiedModel(
          file: target,
          sha256: verified.sha256,
          bytes: verified.bytes,
        );
      } catch (error) {
        lastError = error;
        if (await partial.exists()) await partial.delete();
      }
    }

    throw ModelDownloadException(
      'Every approved IPFS gateway failed. Last error: $lastError',
    );
  }

  Future<Directory> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}verified_models',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _downloadToPartial({
    required Uri uri,
    required File partial,
    required ModelManifest manifest,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    if (uri.scheme != 'https' || !manifest.gatewayHosts.contains(uri.host)) {
      throw const ModelDownloadException('Blocked unapproved download source.');
    }

    _httpClient.connectionTimeout = connectTimeout;
    _httpClient.idleTimeout = idleTimeout;

    final request = await _httpClient.getUrl(uri);
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/octet-stream')
      ..set(HttpHeaders.userAgentHeader, 'NazaOne-SecureModelBootstrap/1');

    final response = await request.close();
    if (response.isRedirect) {
      throw const ModelDownloadException(
        'Gateway redirects are blocked to prevent source substitution.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ModelDownloadException(
        'Gateway ${uri.host} returned HTTP ${response.statusCode}.',
      );
    }

    final contentLength =
        response.contentLength >= 0 ? response.contentLength : null;

    if (contentLength != null && contentLength > maximumBytes) {
      throw const ModelDownloadException('Model exceeds the safety size limit.');
    }
    if (manifest.expectedBytes != null &&
        contentLength != null &&
        contentLength != manifest.expectedBytes) {
      throw ModelDownloadException(
        'Gateway length $contentLength does not match expected '
        '${manifest.expectedBytes}.',
      );
    }

    final sink = partial.openWrite(mode: FileMode.writeOnly);
    var received = 0;

    try {
      await for (final chunk in response.timeout(idleTimeout)) {
        received += chunk.length;
        if (received > maximumBytes) {
          throw const ModelDownloadException(
            'Model exceeds the safety size limit.',
          );
        }
        sink.add(chunk);
        onProgress(
          ModelDownloadProgress(
            phase: ModelDownloadPhase.downloading,
            receivedBytes: received,
            totalBytes: contentLength ?? manifest.expectedBytes,
            gatewayHost: uri.host,
          ),
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (received == 0) {
      throw const ModelDownloadException('Gateway returned an empty file.');
    }
    if (contentLength != null && received != contentLength) {
      throw const ModelDownloadException('Downloaded byte count is incomplete.');
    }
    if (manifest.expectedBytes != null && received != manifest.expectedBytes) {
      throw const ModelDownloadException(
        'Downloaded byte count does not match the manifest.',
      );
    }
  }

  Future<VerifiedModel?> _verifyFile(
    File file,
    ModelManifest manifest,
    void Function(ModelDownloadProgress progress) onProgress,
  ) async {
    onProgress(const ModelDownloadProgress(phase: ModelDownloadPhase.verifying));

    final stat = await file.stat();
    if (stat.size <= 0 || stat.size > maximumBytes) return null;
    if (manifest.expectedBytes != null && stat.size != manifest.expectedBytes) {
      return null;
    }

    final digest = await sha256.bind(file.openRead()).first;
    final actual = digest.toString().toLowerCase();
    final expected = manifest.sha256.toLowerCase();

    if (!_constantTimeEquals(actual, expected)) return null;

    return VerifiedModel(file: file, sha256: actual, bytes: stat.size);
  }

  bool _constantTimeEquals(String actual, String expected) {
    final a = utf8.encode(actual);
    final b = utf8.encode(expected);
    if (a.length != b.length) return false;

    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  void close() => _httpClient.close(force: true);
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
