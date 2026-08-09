import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

enum NazaDistributionPlane {
  canonicalFull,
  githubReleasePart,
  pinataIpfsPart,
  publicIpfsPart,
  browserIpfsPart,
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

  bool get isFullObject => plane == NazaDistributionPlane.canonicalFull;

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
    required this.sources,
  });

  final int index;
  final String name;
  final String cid;
  final List<NazaDistributionSource> sources;

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'name': name,
        'cid': cid,
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

/// Immutable distribution topology for the bundled Gemma 4 E2B LiteRT-LM
/// model. The HTTPS downloader consumes the gateway/release sources directly.
/// The peer hints are retained as provenance for a future native Bitswap
/// transport; they are deliberately not treated as HTTP endpoints.
final class NazaModelDistributionManifest {
  const NazaModelDistributionManifest({
    required this.modelFileName,
    required this.expectedSha256,
    required this.revision,
    required this.fullSources,
    required this.parts,
    required this.ipfsPeerHints,
  });

  final String modelFileName;
  final String expectedSha256;
  final String revision;
  final List<NazaDistributionSource> fullSources;
  final List<NazaDistributionPart> parts;
  final List<NazaIpfsPeerHint> ipfsPeerHints;

  static final NazaModelDistributionManifest gemma4E2b =
      NazaModelDistributionManifest(
    modelFileName: 'gemma-4-E2B-it.litertlm',
    expectedSha256:
        'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
    revision: '7fa1d78473894f7e736a21d920c3aa80f950c0db',
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
      ),
      _part(
        index: 1,
        cid: 'bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4',
      ),
      _part(
        index: 2,
        cid: 'bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm',
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

  static NazaDistributionPart _part({required int index, required String cid}) {
    final suffix = index.toString().padLeft(2, '0');
    final name = 'gemma-4-E2B-it.litertlm.part$suffix.bin';
    return NazaDistributionPart(
      index: index,
      name: name,
      cid: cid,
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
    final canonical = jsonEncode(<String, Object?>{
      'schema': 'naza-model-distribution-v2',
      'file': modelFileName,
      'sha256': expectedSha256.toLowerCase(),
      'revision': revision,
      'totalBytes': totalBytes,
      'partSizes': partSizes,
      'chunkBytes': chunkBytes,
      'fullSources': fullSources.map((source) => source.toJson()).toList(),
      'parts': parts.map((part) => part.toJson()).toList(),
    });
    return crypto.sha256.convert(utf8.encode(canonical)).toString();
  }
}
