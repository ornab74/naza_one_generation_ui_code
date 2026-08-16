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
    {"index":0,"bytes":${parts[0].expectedBytes},"sha256":"${parts[0].expectedSha256}","cid":"${parts[0].cid}","sources":["${part0Source ?? parts[0].sources.first.uri}"]},
    {"index":1,"bytes":${parts[1].expectedBytes},"sha256":"${parts[1].expectedSha256}","cid":"${parts[1].cid}","sources":[]},
    {"index":2,"bytes":${parts[2].expectedBytes},"sha256":"${parts[2].expectedSha256}","cid":"${parts[2].cid}","sources":[]}
  ]
}
```
<!-- NAZA_MIRRORS_V1_END -->
''';
  }

  test('valid catalog can add approved transport without changing identity', () {
    const mirror =
        'https://example.mypinata.cloud/ipfs/bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty';
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
      arbitraryMerged.fullSources.any((source) => source.uri.host == 'evil.example'),
      isFalse,
    );
  });
}
