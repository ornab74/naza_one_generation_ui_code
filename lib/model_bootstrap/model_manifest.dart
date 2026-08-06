import 'package:dart_ipfs/dart_ipfs.dart';

/// Immutable, security-sensitive metadata for one downloadable model.
///
/// Replace [cid] and [sha256] only after the final model file has been added to
/// IPFS. Never publish a CID without independently calculating the SHA-256
/// digest of the exact same file.
class ModelManifest {
  const ModelManifest({
    required this.fileName,
    required this.cid,
    required this.sha256,
    this.expectedBytes,
    this.gatewayHosts = const <String>[
      'ipfs.io',
      'cloudflare-ipfs.com',
      'dweb.link',
    ],
  });

  final String fileName;
  final String cid;
  final String sha256;
  final int? expectedBytes;
  final List<String> gatewayHosts;

  bool get isConfigured =>
      cid.isNotEmpty &&
      sha256.isNotEmpty &&
      !cid.startsWith('REPLACE_') &&
      !sha256.startsWith('REPLACE_');

  void validate() {
    if (!isConfigured) {
      throw const ModelManifestException(
        'Model download is not configured yet.',
      );
    }

    if (fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains(r'\') ||
        fileName == '.' ||
        fileName == '..') {
      throw const ModelManifestException('Unsafe model file name.');
    }

    final normalizedHash = sha256.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedHash)) {
      throw const ModelManifestException(
        'SHA-256 must contain exactly 64 hexadecimal characters.',
      );
    }

    try {
      final decoded = CID.decode(cid);
      if (decoded.encode() != cid && !cid.startsWith('Qm')) {
        throw const ModelManifestException('CID is not canonical.');
      }
    } on ModelManifestException {
      rethrow;
    } catch (_) {
      throw const ModelManifestException('Invalid IPFS CID.');
    }

    if (expectedBytes != null && expectedBytes! <= 0) {
      throw const ModelManifestException(
        'Expected model size must be greater than zero.',
      );
    }

    if (gatewayHosts.isEmpty) {
      throw const ModelManifestException('At least one gateway is required.');
    }

    for (final host in gatewayHosts) {
      if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(host) ||
          host.startsWith('.') ||
          host.endsWith('.')) {
        throw ModelManifestException('Unsafe gateway host: $host');
      }
    }
  }

  Iterable<Uri> get gatewayUris sync* {
    validate();
    for (final host in gatewayHosts) {
      yield Uri(
        scheme: 'https',
        host: host,
        pathSegments: <String>['ipfs', cid],
      );
    }
  }
}

class ModelManifestException implements Exception {
  const ModelManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Configure this after uploading the exact model file to IPFS.
///
/// 1. Replace [cid] with the immutable IPFS CID.
/// 2. Replace [sha256] with the independently calculated SHA-256.
/// 3. Set [expectedBytes] to the exact byte count when known.
///
/// Until then, the boot screen safely allows the app to continue without
/// attempting a download.
const primaryModelManifest = ModelManifest(
  fileName: 'gemma-4-E2B-it.litertlm',
  cid: 'REPLACE_WITH_IPFS_CID',
  sha256: 'REPLACE_WITH_64_CHARACTER_SHA256',
  expectedBytes: null,
);
