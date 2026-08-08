import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import 'model_manifest.dart';

enum ModelDownloadPhase {
  checking,
  fetchingManifest,
  verifyingManifest,
  downloading,
  reassembling,
  verifying,
  ready,
}

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes,
    this.gatewayHost,
    this.partIndex,
    this.partCount,
  });

  final ModelDownloadPhase phase;
  final int receivedBytes;
  final int? totalBytes;
  final String? gatewayHost;
  final int? partIndex;
  final int? partCount;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1);
  }
}

class VerifiedModelPart {
  const VerifiedModelPart({required this.file, required this.manifest});
  final File file;
  final ModelPartManifest manifest;
}

class VerifiedModel {
  const VerifiedModel({
    required this.file,
    required this.sha256,
    required this.bytes,
    required this.parts,
    required this.manifestDirectory,
  });

  final File file;
  final String sha256;
  final int bytes;
  final List<VerifiedModelPart> parts;
  final Directory manifestDirectory;
}

class SecureModelDownloader {
  SecureModelDownloader({
    HttpClient? httpClient,
    this.connectTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 45),
    this.maximumBytes = 12 * 1024 * 1024 * 1024,
    this.maximumManifestFileBytes = 2 * 1024 * 1024,
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final Duration connectTimeout;
  final Duration idleTimeout;
  final int maximumBytes;
  final int maximumManifestFileBytes;

  Future<VerifiedModel> ensureModel({
    required ModelManifest manifest,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    manifest.validate();
    onProgress(const ModelDownloadProgress(phase: ModelDownloadPhase.checking));

    final directory = await _modelDirectory();
    final target = File('${directory.path}${Platform.pathSeparator}${manifest.fileName}');
    final partial = File('${target.path}.part');
    final partsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}parts_${manifest.manifestCid}',
    );
    final manifestDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}manifest_${manifest.manifestCid}',
    );

    final signedParts = await _loadAndVerifySignedManifest(
      manifest: manifest,
      manifestDirectory: manifestDirectory,
      onProgress: onProgress,
    );

    if (await target.exists()) {
      final ok = await _verifyWholeModel(target, manifest, onProgress);
      if (ok) {
        final cachedParts = await _collectVerifiedCachedParts(partsDirectory, signedParts);
        return VerifiedModel(
          file: target,
          sha256: manifest.sha256,
          bytes: manifest.expectedBytes,
          parts: cachedParts,
          manifestDirectory: manifestDirectory,
        );
      }
      await target.delete();
    }

    if (await partial.exists()) await partial.delete();
    await partsDirectory.create(recursive: true);

    final verifiedParts = <VerifiedModelPart>[];
    var completedBytes = 0;
    for (final part in signedParts) {
      final partFile = File('${partsDirectory.path}${Platform.pathSeparator}${part.name}');
      if (!await _verifyPartFile(partFile, part)) {
        if (await partFile.exists()) await partFile.delete();
        await _downloadPart(
          manifest: manifest,
          part: part,
          destination: partFile,
          completedBytes: completedBytes,
          onProgress: onProgress,
        );
        if (!await _verifyPartFile(partFile, part)) {
          if (await partFile.exists()) await partFile.delete();
          throw ModelDownloadException('Part ${part.index} failed SHA-256 verification.');
        }
      }
      verifiedParts.add(VerifiedModelPart(file: partFile, manifest: part));
      completedBytes += part.sizeBytes;
    }

    await _reassemble(verifiedParts, partial, manifest, onProgress);
    if (!await _verifyWholeModel(partial, manifest, onProgress)) {
      if (await partial.exists()) await partial.delete();
      throw const ModelDownloadException('Reassembled model failed final integrity verification.');
    }

    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    onProgress(ModelDownloadProgress(
      phase: ModelDownloadPhase.ready,
      receivedBytes: manifest.expectedBytes,
      totalBytes: manifest.expectedBytes,
    ));

    return VerifiedModel(
      file: target,
      sha256: manifest.sha256,
      bytes: manifest.expectedBytes,
      parts: verifiedParts,
      manifestDirectory: manifestDirectory,
    );
  }

  Future<Directory> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}verified_models');
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<ModelPartManifest>> _loadAndVerifySignedManifest({
    required ModelManifest manifest,
    required Directory manifestDirectory,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    if (await manifestDirectory.exists()) {
      try {
        return await _verifyManifestDirectory(manifest, manifestDirectory, onProgress);
      } catch (_) {
        await manifestDirectory.delete(recursive: true);
      }
    }

    const names = <String>[
      'model-manifest.json',
      'model-manifest.sig',
      'manifest-public-key.pem',
      'public-key.sha256',
    ];
    Object? lastError;
    for (final host in manifest.gatewayHosts) {
      try {
        await manifestDirectory.create(recursive: true);
        onProgress(ModelDownloadProgress(
          phase: ModelDownloadPhase.fetchingManifest,
          gatewayHost: host,
        ));
        for (final name in names) {
          final uri = Uri(
            scheme: 'https',
            host: host,
            pathSegments: <String>['ipfs', manifest.manifestCid, name],
          );
          await _downloadSingleFile(
            uri: uri,
            destination: File('${manifestDirectory.path}${Platform.pathSeparator}$name'),
            allowedHost: host,
            maxBytes: maximumManifestFileBytes,
          );
        }
        return await _verifyManifestDirectory(manifest, manifestDirectory, onProgress);
      } catch (error) {
        lastError = error;
        if (await manifestDirectory.exists()) {
          await manifestDirectory.delete(recursive: true);
        }
      }
    }
    throw ModelDownloadException(
      'Every approved gateway failed to provide the signed manifest. Last error: $lastError',
    );
  }

  Future<List<ModelPartManifest>> _verifyManifestDirectory(
    ModelManifest manifest,
    Directory directory,
    void Function(ModelDownloadProgress progress) onProgress,
  ) async {
    onProgress(const ModelDownloadProgress(phase: ModelDownloadPhase.verifyingManifest));

    final jsonFile = File('${directory.path}${Platform.pathSeparator}model-manifest.json');
    final sigFile = File('${directory.path}${Platform.pathSeparator}model-manifest.sig');
    final keyFile = File('${directory.path}${Platform.pathSeparator}manifest-public-key.pem');
    final keyHashFile = File('${directory.path}${Platform.pathSeparator}public-key.sha256');
    for (final file in <File>[jsonFile, sigFile, keyFile, keyHashFile]) {
      if (!await file.exists() || await file.length() > maximumManifestFileBytes) {
        throw const ModelDownloadException('Signed manifest bundle is incomplete or oversized.');
      }
    }

    final manifestBytes = await jsonFile.readAsBytes();
    final signatureBytes = await sigFile.readAsBytes();
    if (signatureBytes.length != 64) {
      throw const ModelDownloadException('Manifest Ed25519 signature has an invalid length.');
    }

    final der = _pemSubjectPublicKeyInfo(await keyFile.readAsString());
    final fingerprint = sha256.convert(der).toString().toLowerCase();
    final publishedFingerprint =
        (await keyHashFile.readAsString()).trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (!_constantTimeEquals(fingerprint, manifest.manifestSigningKeySha256.toLowerCase()) ||
        !_constantTimeEquals(fingerprint, publishedFingerprint)) {
      throw const ModelDownloadException('Manifest public-key fingerprint mismatch.');
    }

    final publicKey = SimplePublicKey(
      _ed25519PublicKeyFromSpki(der),
      type: KeyPairType.ed25519,
    );
    final verified = await Ed25519().verify(
      manifestBytes,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!verified) {
      throw const ModelDownloadException('Manifest Ed25519 signature verification failed.');
    }

    final decoded = jsonDecode(utf8.decode(manifestBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 'naza-model-manifest-v1') {
      throw const ModelDownloadException('Unsupported signed model manifest.');
    }
    final model = decoded['model'];
    final distribution = decoded['distribution'];
    if (model is! Map<String, dynamic> || distribution is! Map<String, dynamic>) {
      throw const ModelDownloadException('Signed manifest structure is invalid.');
    }
    if (model['filename'] != manifest.fileName ||
        model['sha256']?.toString().toLowerCase() != manifest.sha256.toLowerCase() ||
        model['size_bytes'] != manifest.expectedBytes ||
        distribution['transport'] != 'ipfs' ||
        distribution['reassembly'] != 'concatenate-in-index-order') {
      throw const ModelDownloadException('Signed manifest does not match the app-pinned model identity.');
    }

    final rawParts = distribution['parts'];
    if (rawParts is! List || distribution['part_count'] != rawParts.length) {
      throw const ModelDownloadException('Signed manifest part list is invalid.');
    }
    final parts = <ModelPartManifest>[];
    for (final raw in rawParts) {
      if (raw is! Map<String, dynamic> ||
          raw['index'] is! int ||
          raw['name'] is! String ||
          raw['size_bytes'] is! int ||
          raw['sha256'] is! String ||
          raw['cid'] is! String) {
        throw const ModelDownloadException('Signed manifest contains an invalid part record.');
      }
      parts.add(ModelPartManifest(
        index: raw['index'] as int,
        name: raw['name'] as String,
        sizeBytes: raw['size_bytes'] as int,
        sha256: raw['sha256'] as String,
        cid: raw['cid'] as String,
      ));
    }

    if (parts.length != manifest.expectedParts.length) {
      throw const ModelDownloadException('Signed manifest differs from the app-pinned part list.');
    }
    for (var i = 0; i < parts.length; i++) {
      final a = parts[i];
      final b = manifest.expectedParts[i];
      a.validate();
      if (a.index != b.index ||
          a.name != b.name ||
          a.sizeBytes != b.sizeBytes ||
          a.sha256.toLowerCase() != b.sha256.toLowerCase() ||
          a.cid != b.cid) {
        throw ModelDownloadException('Signed manifest part $i differs from the app-pinned distribution.');
      }
    }
    return parts;
  }

  Uint8List _pemSubjectPublicKeyInfo(String pem) {
    const begin = '-----BEGIN PUBLIC KEY-----';
    const end = '-----END PUBLIC KEY-----';
    final start = pem.indexOf(begin);
    final finish = pem.indexOf(end);
    if (start < 0 || finish <= start) {
      throw const ModelDownloadException('Manifest public key is not valid PEM.');
    }
    try {
      return Uint8List.fromList(base64Decode(
        pem.substring(start + begin.length, finish).replaceAll(RegExp(r'\s+'), ''),
      ));
    } catch (_) {
      throw const ModelDownloadException('Manifest public key PEM is malformed.');
    }
  }

  Uint8List _ed25519PublicKeyFromSpki(Uint8List der) {
    const prefix = <int>[0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00];
    if (der.length != prefix.length + 32) {
      throw const ModelDownloadException('Manifest public key is not an Ed25519 SPKI key.');
    }
    for (var i = 0; i < prefix.length; i++) {
      if (der[i] != prefix[i]) {
        throw const ModelDownloadException('Manifest public key algorithm is not Ed25519.');
      }
    }
    return Uint8List.fromList(der.sublist(prefix.length));
  }

  Future<List<VerifiedModelPart>> _collectVerifiedCachedParts(
    Directory directory,
    List<ModelPartManifest> parts,
  ) async {
    if (!await directory.exists()) return const <VerifiedModelPart>[];
    final result = <VerifiedModelPart>[];
    for (final part in parts) {
      final file = File('${directory.path}${Platform.pathSeparator}${part.name}');
      if (!await _verifyPartFile(file, part)) return const <VerifiedModelPart>[];
      result.add(VerifiedModelPart(file: file, manifest: part));
    }
    return result;
  }

  Future<void> _downloadPart({
    required ModelManifest manifest,
    required ModelPartManifest part,
    required File destination,
    required int completedBytes,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    Object? lastError;
    for (final uri in manifest.gatewayUrisForCid(part.cid)) {
      try {
        final partial = File('${destination.path}.part');
        if (await partial.exists()) await partial.delete();
        await _downloadSingleFile(
          uri: uri,
          destination: partial,
          allowedHost: uri.host,
          maxBytes: part.sizeBytes,
          exactBytes: part.sizeBytes,
          onChunk: (received) => onProgress(ModelDownloadProgress(
            phase: ModelDownloadPhase.downloading,
            receivedBytes: completedBytes + received,
            totalBytes: manifest.expectedBytes,
            gatewayHost: uri.host,
            partIndex: part.index + 1,
            partCount: manifest.expectedParts.length,
          )),
        );
        await partial.rename(destination.path);
        return;
      } catch (error) {
        lastError = error;
        final partial = File('${destination.path}.part');
        if (await partial.exists()) await partial.delete();
      }
    }
    throw ModelDownloadException('All approved gateways failed for part ${part.index}. Last error: $lastError');
  }

  Future<void> _downloadSingleFile({
    required Uri uri,
    required File destination,
    required String allowedHost,
    required int maxBytes,
    int? exactBytes,
    void Function(int received)? onChunk,
  }) async {
    if (uri.scheme != 'https' || uri.host != allowedHost) {
      throw const ModelDownloadException('Blocked unapproved download source.');
    }
    _httpClient.connectionTimeout = connectTimeout;
    _httpClient.idleTimeout = idleTimeout;
    final request = await _httpClient.getUrl(uri);
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/octet-stream')
      ..set(HttpHeaders.userAgentHeader, 'NazaOne-SecureIPFSBootstrap/2');
    final response = await request.close();
    if (response.isRedirect) {
      throw const ModelDownloadException('Gateway redirects are blocked.');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ModelDownloadException('Gateway ${uri.host} returned HTTP ${response.statusCode}.');
    }

    final contentLength = response.contentLength >= 0 ? response.contentLength : null;
    if (contentLength != null && contentLength > maxBytes) {
      throw const ModelDownloadException('Gateway object exceeds its safety size limit.');
    }
    if (exactBytes != null && contentLength != null && contentLength != exactBytes) {
      throw const ModelDownloadException('Gateway object length differs from the signed manifest.');
    }

    await destination.parent.create(recursive: true);
    final sink = destination.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final chunk in response.timeout(idleTimeout)) {
        received += chunk.length;
        if (received > maxBytes) {
          throw const ModelDownloadException('Gateway object exceeds its safety size limit.');
        }
        sink.add(chunk);
        onChunk?.call(received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received == 0 ||
        (contentLength != null && received != contentLength) ||
        (exactBytes != null && received != exactBytes)) {
      throw const ModelDownloadException('Downloaded object byte count is invalid.');
    }
  }

  Future<bool> _verifyPartFile(File file, ModelPartManifest part) async {
    if (!await file.exists()) return false;
    if (await file.length() != part.sizeBytes) return false;
    final actual = (await sha256.bind(file.openRead()).first).toString().toLowerCase();
    return _constantTimeEquals(actual, part.sha256.toLowerCase());
  }

  Future<void> _reassemble(
    List<VerifiedModelPart> parts,
    File partial,
    ModelManifest manifest,
    void Function(ModelDownloadProgress progress) onProgress,
  ) async {
    if (await partial.exists()) await partial.delete();
    final sink = partial.openWrite(mode: FileMode.writeOnly);
    var written = 0;
    try {
      for (final part in parts) {
        await for (final chunk in part.file.openRead()) {
          written += chunk.length;
          if (written > manifest.expectedBytes || written > maximumBytes) {
            throw const ModelDownloadException('Reassembled model exceeds expected size.');
          }
          sink.add(chunk);
          onProgress(ModelDownloadProgress(
            phase: ModelDownloadPhase.reassembling,
            receivedBytes: written,
            totalBytes: manifest.expectedBytes,
            partIndex: part.manifest.index + 1,
            partCount: parts.length,
          ));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (written != manifest.expectedBytes) {
      throw const ModelDownloadException('Reassembled byte count is invalid.');
    }
  }

  Future<bool> _verifyWholeModel(
    File file,
    ModelManifest manifest,
    void Function(ModelDownloadProgress progress) onProgress,
  ) async {
    if (!await file.exists()) return false;
    onProgress(const ModelDownloadProgress(phase: ModelDownloadPhase.verifying));
    if (await file.length() != manifest.expectedBytes) return false;
    final actual = (await sha256.bind(file.openRead()).first).toString().toLowerCase();
    return _constantTimeEquals(actual, manifest.sha256.toLowerCase());
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
