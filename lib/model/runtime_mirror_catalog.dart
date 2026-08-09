import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'model_distribution_manifest.dart';

final class NazaRuntimeMirrorCatalog {
  const NazaRuntimeMirrorCatalog._();

  static const int maxCatalogBytes = 256 * 1024;
  static const Duration defaultTimeout = Duration(seconds: 4);
  static const String _begin = '<!-- NAZA_MIRRORS_V1_BEGIN -->';
  static const String _end = '<!-- NAZA_MIRRORS_V1_END -->';

  /// Fetches and validates the optional GitHub mirror catalog. Any transport,
  /// parsing or validation failure returns [builtIn] unchanged.
  ///
  /// This is intentionally fail-safe: the remote file can add URLs, but cannot
  /// alter the compiled model identity, hashes, sizes, revision or CIDs.
  static Future<NazaModelDistributionManifest> resolve(
    NazaModelDistributionManifest builtIn, {
    Duration timeout = defaultTimeout,
    HttpClient? client,
  }) async {
    final ownedClient = client == null;
    final http = client ??
        (HttpClient()
          ..connectionTimeout = timeout
          ..idleTimeout = timeout
          ..autoUncompress = false);
    try {
      final markdown = await _fetchCatalog(
        http,
        builtIn.runtimeCatalogUri,
        timeout: timeout,
      );
      return parseAndMerge(builtIn, markdown);
    } catch (_) {
      return builtIn;
    } finally {
      if (ownedClient) http.close(force: true);
    }
  }

  static Future<String> _fetchCatalog(
    HttpClient client,
    Uri uri, {
    required Duration timeout,
  }) async {
    _validateCatalogUri(uri);
    final request = await client.getUrl(uri).timeout(timeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    request.headers.set(HttpHeaders.acceptHeader, 'text/plain, text/markdown');
    request.headers.set(HttpHeaders.userAgentHeader, 'NAZA-One/1 mirror-catalog-v1');
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Mirror catalog returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final declared = response.contentLength;
    if (declared > maxCatalogBytes) {
      await response.drain<void>();
      throw const FormatException('Mirror catalog is too large.');
    }

    final bytes = <int>[];
    await for (final frame in response.timeout(timeout)) {
      if (bytes.length + frame.length > maxCatalogBytes) {
        throw const FormatException('Mirror catalog exceeded the size limit.');
      }
      bytes.addAll(frame);
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  static NazaModelDistributionManifest parseAndMerge(
    NazaModelDistributionManifest builtIn,
    String markdown,
  ) {
    final begin = markdown.indexOf(_begin);
    final end = markdown.indexOf(_end);
    if (begin < 0 || end <= begin) {
      throw const FormatException('Mirror catalog markers are missing.');
    }
    final section = markdown.substring(begin + _begin.length, end);
    final fenced = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false)
        .firstMatch(section);
    if (fenced == null) {
      throw const FormatException('Mirror catalog JSON block is missing.');
    }
    final decoded = jsonDecode(fenced.group(1)!);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Mirror catalog root must be an object.');
    }
    _validateIdentity(builtIn, decoded);

    final mergedFull = <NazaDistributionSource>[...builtIn.fullSources];
    final mergedParts = <List<NazaDistributionSource>>[
      for (final part in builtIn.parts) <NazaDistributionSource>[...part.sources],
    ];
    final seen = <String>{
      for (final source in mergedFull) source.uri.toString(),
      for (final sources in mergedParts)
        for (final source in sources) source.uri.toString(),
    };

    final remoteFull = decoded['fullSources'];
    if (remoteFull is List) {
      for (final value in remoteFull.take(24)) {
        final uri = _parseMirrorUri(value);
        if (uri == null || !seen.add(uri.toString())) continue;
        mergedFull.add(NazaDistributionSource(
          id: 'runtime-full-${_stableId(uri)}',
          uri: uri,
          plane: NazaDistributionPlane.runtimeMirror,
          trustWeight: 0.90,
        ));
      }
    }

    final parts = decoded['parts'];
    if (parts is! List || parts.length != builtIn.parts.length) {
      throw const FormatException('Mirror catalog part list is invalid.');
    }
    for (var i = 0; i < builtIn.parts.length; i++) {
      final raw = parts[i];
      if (raw is! Map) {
        throw const FormatException('Mirror catalog part entry is invalid.');
      }
      final expected = builtIn.parts[i];
      if ((raw['index'] as num?)?.toInt() != expected.index ||
          (raw['bytes'] as num?)?.toInt() != expected.expectedBytes ||
          raw['sha256']?.toString().toLowerCase() !=
              expected.expectedSha256.toLowerCase() ||
          raw['cid']?.toString() != expected.cid) {
        throw FormatException('Mirror catalog part $i identity mismatch.');
      }
      final sources = raw['sources'];
      if (sources is! List) continue;
      for (final value in sources.take(32)) {
        final uri = _parseMirrorUri(value);
        if (uri == null || !seen.add(uri.toString())) continue;
        mergedParts[i].add(NazaDistributionSource(
          id: 'runtime-part-$i-${_stableId(uri)}',
          uri: uri,
          plane: NazaDistributionPlane.runtimeMirror,
          partIndex: i,
          trustWeight: 0.88,
        ));
      }
    }

    return builtIn.copyWithSources(
      fullSources: mergedFull,
      partSources: mergedParts,
    );
  }

  static void _validateIdentity(
    NazaModelDistributionManifest builtIn,
    Map<String, dynamic> decoded,
  ) {
    if (decoded['schema'] != 'naza-mirrors-v1' ||
        decoded['modelFileName'] != builtIn.modelFileName ||
        decoded['revision'] != builtIn.revision ||
        (decoded['totalBytes'] as num?)?.toInt() != builtIn.expectedBytes ||
        decoded['sha256']?.toString().toLowerCase() !=
            builtIn.expectedSha256.toLowerCase()) {
      throw const FormatException('Mirror catalog model identity mismatch.');
    }
  }

  static Uri? _parseMirrorUri(Object? value) {
    if (value is! String || value.length > 2048) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !_isAllowedMirrorUri(uri)) return null;
    return uri;
  }

  static bool _isAllowedMirrorUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (_isForbiddenHost(host)) return false;

    if (host == 'github.com' || host == 'huggingface.co' || host == 'ipfs.io') {
      return true;
    }
    if (host.endsWith('.mypinata.cloud')) return true;
    if (host.endsWith('.ipfs.inbrowser.link')) return true;
    return false;
  }

  static bool _isForbiddenHost(String host) {
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return true;
    }
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return false;
    if (ip.type == InternetAddressType.IPv4) {
      final octets = ip.rawAddress;
      final a = octets[0];
      final b = octets[1];
      return a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          a >= 224;
    }
    final raw = ip.rawAddress;
    final loopback = raw.take(15).every((byte) => byte == 0) && raw[15] == 1;
    final uniqueLocal = (raw[0] & 0xFE) == 0xFC;
    final linkLocal = raw[0] == 0xFE && (raw[1] & 0xC0) == 0x80;
    return loopback || uniqueLocal || linkLocal;
  }

  static void _validateCatalogUri(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'raw.githubusercontent.com' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException('Unsafe runtime mirror catalog URL.');
    }
  }

  static String _stableId(Uri uri) {
    // FNV-1a 32-bit is only used for compact source IDs, never for integrity.
    var hash = 0x811c9dc5;
    for (final unit in uri.toString().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
