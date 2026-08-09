import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model/model_distribution_manifest.dart';

void main() {
  group('Gemma 4 E2B distribution manifest', () {
    final manifest = NazaModelDistributionManifest.gemma4E2b;

    test('pins immutable model identity', () {
      expect(
        manifest.expectedSha256,
        'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
      );
      expect(manifest.revision, '7fa1d78473894f7e736a21d920c3aa80f950c0db');
      expect(manifest.modelFileName, 'gemma-4-E2B-it.litertlm');
    });

    test('has canonical full plane and three replicated part planes', () {
      expect(manifest.fullSources, hasLength(1));
      expect(manifest.fullSources.single.isFullObject, isTrue);
      expect(manifest.parts, hasLength(3));

      for (var index = 0; index < manifest.parts.length; index++) {
        final part = manifest.parts[index];
        expect(part.index, index);
        expect(part.name, contains('part0$index.bin'));
        expect(part.cid, startsWith('bafy'));
        expect(part.sources, hasLength(4));
        expect(
          part.sources.map((source) => source.plane).toSet(),
          containsAll(<NazaDistributionPlane>{
            NazaDistributionPlane.githubReleasePart,
            NazaDistributionPlane.pinataIpfsPart,
            NazaDistributionPlane.publicIpfsPart,
            NazaDistributionPlane.browserIpfsPart,
          }),
        );
      }
    });

    test('all application HTTP sources are HTTPS and uniquely identified', () {
      final sources = <NazaDistributionSource>[
        ...manifest.fullSources,
        for (final part in manifest.parts) ...part.sources,
      ];
      expect(sources.map((source) => source.id).toSet(), hasLength(sources.length));
      for (final source in sources) {
        expect(source.uri.scheme, 'https');
        expect(source.uri.host, isNotEmpty);
        expect(source.uri.userInfo, isEmpty);
        expect(source.uri.fragment, isEmpty);
      }
    });

    test('records both direct DigitalOcean IPFS peer hints separately', () {
      expect(manifest.ipfsPeerHints, hasLength(2));
      for (final peer in manifest.ipfsPeerHints) {
        expect(peer.peerId, startsWith('12D3KooW'));
        expect(peer.tcpMultiaddr, contains('/tcp/4001/p2p/${peer.peerId}'));
        expect(peer.quicMultiaddr, contains('/udp/4001/quic-v1/p2p/${peer.peerId}'));
      }
    });

    test('topology fingerprint is deterministic and layout-sensitive', () {
      final a = manifest.fingerprintFor(
        totalBytes: 900,
        partSizes: const <int>[300, 300, 300],
        chunkBytes: 256,
      );
      final b = manifest.fingerprintFor(
        totalBytes: 900,
        partSizes: const <int>[300, 300, 300],
        chunkBytes: 256,
      );
      final changed = manifest.fingerprintFor(
        totalBytes: 900,
        partSizes: const <int>[250, 350, 300],
        chunkBytes: 256,
      );
      expect(a, b);
      expect(a, isNot(changed));
      expect(a, hasLength(64));
    });
  });
}
