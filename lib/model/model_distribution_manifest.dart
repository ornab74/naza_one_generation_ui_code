// LLM-CONTEXT:BEGIN
// FILE: lib/model/model_distribution_manifest.dart
// ROLE: Owns model distribution manifest behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

enum NazaDistributionPlane {
  canonicalFull,
  githubReleasePart,
  pinataIpfsPart,
  publicIpfsPart,
  browserIpfsPart,
  runtimeMirror,
}

final class NazaDistributionSource {
  const NazaDistributionSource({
    required this.id,
    required this.uri,
    required this.plane,
    this.partIndex,
    this.trustWeight = 1.0,
  });

  final String id;
  final Uri uri;
  final NazaDistributionPlane plane;
  final int? partIndex;
  final double trustWeight;

  bool get isFullObject => partIndex == null;

  String get originKey {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'uri': uri.toString(),
        'plane': plane.name,
        'partIndex': partIndex,
        'trustWeight': trustWeight,
      };
}

final class NazaDistributionPart {
  const NazaDistributionPart({
    required this.index,
    required this.name,
    required this.cid,
    required this.expectedBytes,
    required this.expectedSha256,
    required this.sources,
  });

  final int index;
  final String name;
  final String cid;
  final int expectedBytes;
  final String expectedSha256;
  final List<NazaDistributionSource> sources;

  NazaDistributionPart copyWithSources(List<NazaDistributionSource> value) =>
      NazaDistributionPart(
        index: index,
        name: name,
        cid: cid,
        expectedBytes: expectedBytes,
        expectedSha256: expectedSha256,
        sources: List<NazaDistributionSource>.unmodifiable(value),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'name': name,
        'cid': cid,
        'expectedBytes': expectedBytes,
        'expectedSha256': expectedSha256.toLowerCase(),
        'sources': sources.map((source) => source.toJson()).toList(),
      };
}

final class NazaIpfsPeerHint {
  const NazaIpfsPeerHint({
    required this.name,
    required this.peerId,
    required this.tcpMultiaddr,
    required this.quicMultiaddr,
  });

  final String name;
  final String peerId;
  final String tcpMultiaddr;
  final String quicMultiaddr;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'peerId': peerId,
        'tcpMultiaddr': tcpMultiaddr,
        'quicMultiaddr': quicMultiaddr,
      };
}

/// Immutable distribution identity plus transport locations for the bundled
/// Gemma 4 E2B LiteRT-LM model.
///
/// Bytes, hashes, revision and CIDs are compiled into the application. Runtime
/// mirror discovery may add HTTPS transport locations but cannot replace any
/// of these immutable identity fields.
final class NazaModelDistributionManifest {
  const NazaModelDistributionManifest({
    required this.modelFileName,
    required this.expectedSha256,
    required this.expectedBytes,
    required this.revision,
    required this.fullSources,
    required this.parts,
    required this.ipfsPeerHints,
    required this.runtimeCatalogUri,
  });

  final String modelFileName;
  final String expectedSha256;
  final int expectedBytes;
  final String revision;
  final List<NazaDistributionSource> fullSources;
  final List<NazaDistributionPart> parts;
  final List<NazaIpfsPeerHint> ipfsPeerHints;
  final Uri runtimeCatalogUri;

  NazaModelDistributionManifest copyWithSources({
    required List<NazaDistributionSource> fullSources,
    required List<List<NazaDistributionSource>> partSources,
  }) {
    if (partSources.length != parts.length) {
      throw ArgumentError('Runtime mirror part-source count does not match manifest.');
    }
    return NazaModelDistributionManifest(
      modelFileName: modelFileName,
      expectedSha256: expectedSha256,
      expectedBytes: expectedBytes,
      revision: revision,
      fullSources: List<NazaDistributionSource>.unmodifiable(fullSources),
      parts: List<NazaDistributionPart>.unmodifiable(<NazaDistributionPart>[
        for (var i = 0; i < parts.length; i++)
          parts[i].copyWithSources(partSources[i]),
      ]),
      ipfsPeerHints: ipfsPeerHints,
      runtimeCatalogUri: runtimeCatalogUri,
    );
  }

  static final NazaModelDistributionManifest gemma4E2b =
      NazaModelDistributionManifest(
    modelFileName: 'gemma-4-E2B-it.litertlm',
    expectedSha256:
        'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
    expectedBytes: 2583085056,
    revision: '7fa1d78473894f7e736a21d920c3aa80f950c0db',
    runtimeCatalogUri: Uri.parse(
      'https://raw.githubusercontent.com/ornab74/'
      'naza_one_generation_ui_code/main/mirrors.md',
    ),
    fullSources: <NazaDistributionSource>[
      NazaDistributionSource(
        id: 'hf-immutable-full',
        uri: Uri.parse(
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
          'resolve/7fa1d78473894f7e736a21d920c3aa80f950c0db/'
          'gemma-4-E2B-it.litertlm',
        ),
        plane: NazaDistributionPlane.canonicalFull,
        trustWeight: 1.35,
      ),
    ],
    parts: <NazaDistributionPart>[
      _part(
        index: 0,
        cid: 'bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty',
        expectedSha256:
            'b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995',
      ),
      _part(
        index: 1,
        cid: 'bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4',
        expectedSha256:
            '5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8',
      ),
      _part(
        index: 2,
        cid: 'bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm',
        expectedSha256:
            '00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3',
      ),
    ],
    ipfsPeerHints: const <NazaIpfsPeerHint>[
      NazaIpfsPeerHint(
        name: 'do-node-1',
        peerId: '12D3KooWCSJHymufeoVskC8kNwS14SPLgApQuNibXWSmtQJENP2d',
        tcpMultiaddr:
            '/ip4/161.35.112.160/tcp/4001/p2p/12D3KooWCSJHymufeoVskC8kNwS14SPLgApQuNibXWSmtQJENP2d',
        quicMultiaddr:
            '/ip4/161.35.112.160/udp/4001/quic-v1/p2p/12D3KooWCSJHymufeoVskC8kNwS14SPLgApQuNibXWSmtQJENP2d',
      ),
      NazaIpfsPeerHint(
        name: 'do-node-2',
        peerId: '12D3KooWA7dr9ocKA2gwhz8mtcCziZvzugbT3gnfSnqSBP2WdST9',
        tcpMultiaddr:
            '/ip4/165.227.17.244/tcp/4001/p2p/12D3KooWA7dr9ocKA2gwhz8mtcCziZvzugbT3gnfSnqSBP2WdST9',
        quicMultiaddr:
            '/ip4/165.227.17.244/udp/4001/quic-v1/p2p/12D3KooWA7dr9ocKA2gwhz8mtcCziZvzugbT3gnfSnqSBP2WdST9',
      ),
    ],
  );

  static NazaDistributionPart _part({
    required int index,
    required String cid,
    required String expectedSha256,
  }) {
    final suffix = index.toString().padLeft(2, '0');
    final name = 'gemma-4-E2B-it.litertlm.part$suffix.bin';
    return NazaDistributionPart(
      index: index,
      name: name,
      cid: cid,
      expectedBytes: 861028352,
      expectedSha256: expectedSha256,
      sources: <NazaDistributionSource>[
        NazaDistributionSource(
          id: 'github-part-$suffix',
          uri: Uri.parse(
            'https://github.com/ornab74/naza_one_generation_ui_code/'
            'releases/download/v1/$name',
          ),
          plane: NazaDistributionPlane.githubReleasePart,
          partIndex: index,
          trustWeight: 1.15,
        ),
        NazaDistributionSource(
          id: 'pinata-part-$suffix',
          uri: Uri.parse(
            'https://silver-southern-echidna-758.mypinata.cloud/ipfs/$cid',
          ),
          plane: NazaDistributionPlane.pinataIpfsPart,
          partIndex: index,
          trustWeight: 1.10,
        ),
        NazaDistributionSource(
          id: 'ipfs-io-part-$suffix',
          uri: Uri.parse('https://ipfs.io/ipfs/$cid'),
          plane: NazaDistributionPlane.publicIpfsPart,
          partIndex: index,
          trustWeight: 1.0,
        ),
        NazaDistributionSource(
          id: 'inbrowser-part-$suffix',
          uri: Uri.parse('https://$cid.ipfs.inbrowser.link/'),
          plane: NazaDistributionPlane.browserIpfsPart,
          partIndex: index,
          trustWeight: 0.95,
        ),
      ],
    );
  }

  String fingerprintFor({
    required int totalBytes,
    required List<int> partSizes,
    required int chunkBytes,
  }) {
    // Transport URLs are deliberately excluded: adding/removing a mirror must
    // never invalidate a safe partial download. Only immutable identity and
    // byte layout participate in resume compatibility.
    final canonical = jsonEncode(<String, Object?>{
      'schema': 'naza-model-distribution-v3',
      'file': modelFileName,
      'sha256': expectedSha256.toLowerCase(),
      'expectedBytes': expectedBytes,
      'revision': revision,
      'totalBytes': totalBytes,
      'partSizes': partSizes,
      'parts': <Map<String, Object?>>[
        for (final part in parts)
          <String, Object?>{
            'index': part.index,
            'cid': part.cid,
            'bytes': part.expectedBytes,
            'sha256': part.expectedSha256.toLowerCase(),
          },
      ],
      'chunkBytes': chunkBytes,
    });
    return crypto.sha256.convert(utf8.encode(canonical)).toString();
  }
}
