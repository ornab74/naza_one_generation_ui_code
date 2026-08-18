// LLM-CONTEXT:BEGIN
// FILE: test/runtime_mirror_catalog_test.dart
// ROLE: Owns runtime mirror catalog test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model/model_distribution_manifest.dart';
import 'package:naza_one/model/runtime_mirror_catalog.dart';

void main() {
  final builtIn = NazaModelDistributionManifest.gemma4E2b;

  String catalog({String? fullSource, String? part0Source}) {
    final parts = builtIn.parts;
    return '''
<!-- NAZA_MIRRORS_V1_BEGIN -->
```json
{
  "schema":"naza-mirrors-v1",
  "modelFileName":"${builtIn.modelFileName}",
  "revision":"${builtIn.revision}",
  "totalBytes":${builtIn.expectedBytes},
  "sha256":"${builtIn.expectedSha256}",
  "fullSources":["${fullSource ?? builtIn.fullSources.single.uri}"],
  "parts":[
    {"index":0,"bytes":${parts[0].expectedBytes},"sha256":"${parts[0].expectedSha256}","sources":["${part0Source ?? parts[0].sources.first.uri}"]},
    {"index":1,"bytes":${parts[1].expectedBytes},"sha256":"${parts[1].expectedSha256}","sources":[]},
    {"index":2,"bytes":${parts[2].expectedBytes},"sha256":"${parts[2].expectedSha256}","sources":[]}
  ]
}
```
<!-- NAZA_MIRRORS_V1_END -->
''';
  }

  test('valid catalog can add approved transport without changing identity', () {
    const mirror =
        'https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v2/gemma-4-E2B-it.litertlm.part00.bin';
    final merged = NazaRuntimeMirrorCatalog.parseAndMerge(
      builtIn,
      catalog(part0Source: mirror),
    );
    expect(merged.expectedSha256, builtIn.expectedSha256);
    expect(merged.expectedBytes, builtIn.expectedBytes);
    expect(merged.parts[0].expectedSha256, builtIn.parts[0].expectedSha256);
    expect(
      merged.parts[0].sources.any((source) => source.uri.toString() == mirror),
      isTrue,
    );
  });

  test('removed IPFS gateway families cannot be reintroduced at runtime', () {
    for (final mirror in <String>[
      'https://example.mypinata.cloud/ipfs/example',
      'https://ipfs.io/ipfs/example',
      'https://example.ipfs.inbrowser.link/',
    ]) {
      final merged = NazaRuntimeMirrorCatalog.parseAndMerge(
        builtIn,
        catalog(part0Source: mirror),
      );
      expect(
        merged.parts[0].sources.any(
          (source) => source.uri.toString() == mirror,
        ),
        isFalse,
        reason: mirror,
      );
    }
  });

  test('tampered immutable model identity is rejected', () {
    final tampered = catalog().replaceFirst(
      builtIn.expectedSha256,
      List<String>.filled(64, '0').join(),
    );
    expect(
      () => NazaRuntimeMirrorCatalog.parseAndMerge(builtIn, tampered),
      throwsFormatException,
    );
  });

  test('private and unapproved runtime destinations are ignored', () {
    final privateMerged = NazaRuntimeMirrorCatalog.parseAndMerge(
      builtIn,
      catalog(part0Source: 'https://127.0.0.1/model.bin'),
    );
    expect(
      privateMerged.parts[0].sources.any(
        (source) => source.uri.host == '127.0.0.1',
      ),
      isFalse,
    );

    final arbitraryMerged = NazaRuntimeMirrorCatalog.parseAndMerge(
      builtIn,
      catalog(fullSource: 'https://evil.example/model.bin'),
    );
    expect(
      arbitraryMerged.fullSources.any(
        (source) => source.uri.host == 'evil.example',
      ),
      isFalse,
    );
  });
}
