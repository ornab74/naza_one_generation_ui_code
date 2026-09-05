// LLM-CONTEXT:BEGIN
// FILE: test/model_distribution_manifest_test.dart
// ROLE: Owns model distribution manifest test behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

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

    test('uses the repository release as the model source', () {
      expect(manifest.fullSources, hasLength(1));
      expect(manifest.fullSources.single.isFullObject, isTrue);
      expect(manifest.parts, hasLength(3));

      for (var index = 0; index < manifest.parts.length; index++) {
        final part = manifest.parts[index];
        expect(part.index, index);
        expect(part.name, contains('part0$index.bin'));
        expect(part.sources, hasLength(1));
        expect(
          part.sources.first.plane,
          NazaDistributionPlane.githubReleasePart,
        );
        expect(part.sources.first.uri.host, 'github.com');
      }
    });

    test('all application HTTP sources are HTTPS and uniquely identified', () {
      final sources = <NazaDistributionSource>[
        ...manifest.fullSources,
        for (final part in manifest.parts) ...part.sources,
      ];
      expect(
        sources.map((source) => source.id).toSet(),
        hasLength(sources.length),
      );
      for (final source in sources) {
        expect(source.uri.scheme, 'https');
        expect(source.uri.host, isNotEmpty);
        expect(source.uri.userInfo, isEmpty);
        expect(source.uri.fragment, isEmpty);
      }
    });

    test('redirect transport policy is closed to arbitrary destinations', () {
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://release-assets.githubusercontent.com/file'),
        ),
        isTrue,
      );
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://cdn-lfs.hf.co/model'),
        ),
        isTrue,
      );
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://silver-southern-echidna-758.mypinata.cloud/model'),
        ),
        isTrue,
      );
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://another.mypinata.cloud/model'),
        ),
        isFalse,
      );
      expect(
        nazaIsApprovedModelTransportUri(Uri.parse('http://github.com/model')),
        isFalse,
      );
      expect(
        nazaIsApprovedModelTransportUri(Uri.parse('https://localhost/model')),
        isFalse,
      );
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://github.com:8443/model'),
        ),
        isFalse,
      );
      expect(
        nazaIsApprovedModelTransportUri(
          Uri.parse('https://attacker.example/model'),
        ),
        isFalse,
      );
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

  group('Llama 3 Small sentinel distribution manifest', () {
    final manifest = NazaModelDistributionManifest.llama3SmallSentinel;

    test('pins the exact scanner artifact supplied by the source ZIP', () {
      expect(manifest.modelFileName, 'llama3-small-Q3_K_M.gguf');
      expect(manifest.expectedBytes, 111454016);
      expect(
        manifest.expectedSha256,
        '8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa',
      );
      expect(manifest.parts, hasLength(1));
      expect(manifest.parts.single.expectedBytes, manifest.expectedBytes);
      expect(manifest.parts.single.expectedSha256, manifest.expectedSha256);
    });

    test('uses only approved HTTPS mirror transports', () {
      expect(manifest.fullSources, hasLength(3));
      for (final source in manifest.fullSources) {
        expect(source.isFullObject, isTrue);
        expect(nazaIsApprovedModelTransportUri(source.uri), isTrue);
      }
    });
  });
}
