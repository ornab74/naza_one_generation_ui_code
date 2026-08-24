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
  pinataPart,
  runtimeMirror,
}

/// Closed transport policy for compiled sources and their legitimate CDN hops.
/// Model bytes remain hash-verified independently; this policy confines where
/// the downloader is allowed to send probe and range requests.
bool nazaIsApprovedModelTransportUri(Uri uri) {
  if (uri.toString().length > 2048 ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'github.com' ||
      host == 'huggingface.co' ||
      host == 'githubusercontent.com' ||
      host.endsWith('.githubusercontent.com') ||
      host == 'hf.co' ||
      host.endsWith('.hf.co') ||
      host == 'silver-southern-echidna-758.mypinata.cloud';
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
    required this.expectedBytes,
    required this.expectedSha256,
    required this.sources,
  });

  final int index;
  final String name;
  final int expectedBytes;
  final String expectedSha256;
  final List<NazaDistributionSource> sources;

  NazaDistributionPart copyWithSources(List<NazaDistributionSource> value) =>
      NazaDistributionPart(
        index: index,
        name: name,
        expectedBytes: expectedBytes,
        expectedSha256: expectedSha256,
        sources: List<NazaDistributionSource>.unmodifiable(value),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'name': name,
    'expectedBytes': expectedBytes,
    'expectedSha256': expectedSha256.toLowerCase(),
    'sources': sources.map((source) => source.toJson()).toList(),
  };
}

/// Immutable distribution identity plus transport locations for a bundled
/// local model artifact.
///
/// Bytes, hashes, and revision are compiled into the application. Runtime
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
    required this.runtimeCatalogUri,
  });

  final String modelFileName;
  final String expectedSha256;
  final int expectedBytes;
  final String revision;
  final List<NazaDistributionSource> fullSources;
  final List<NazaDistributionPart> parts;
  final Uri runtimeCatalogUri;

  NazaModelDistributionManifest copyWithSources({
    required List<NazaDistributionSource> fullSources,
    required List<List<NazaDistributionSource>> partSources,
  }) {
    if (partSources.length != parts.length) {
      throw ArgumentError(
        'Runtime mirror part-source count does not match manifest.',
      );
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
      runtimeCatalogUri: runtimeCatalogUri,
    );
  }

  static final NazaModelDistributionManifest
  gemma4E2b = NazaModelDistributionManifest(
    modelFileName: 'gemma-4-E2B-it.litertlm',
    expectedSha256:
        'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
    expectedBytes: 2583085056,
    revision: '7fa1d78473894f7e736a21d920c3aa80f950c0db',
    runtimeCatalogUri: Uri.parse(
      'https://raw.githubusercontent.com/ornab74/'
      'naza_one_generation_ui_code/92e3c182ea1ed8209ac57d600b3cb571ae6e4bfd/mirrors.md',
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
        expectedSha256:
            'b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995',
      ),
      _part(
        index: 1,
        expectedSha256:
            '5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8',
      ),
      _part(
        index: 2,
        expectedSha256:
            '00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3',
      ),
    ],
  );

  /// Scanner-only Llama 3 Small artifact imported from
  /// `naza-dart-source.zip`. It is a separate safety/scanner runtime and must
  /// never be routed into Chat.
  static final NazaModelDistributionManifest
  llama3SmallSentinel = NazaModelDistributionManifest(
    modelFileName: 'llama3-small-Q3_K_M.gguf',
    expectedSha256:
        '8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa',
    expectedBytes: 111454016,
    revision: 'naza-sentinel-llama3-small-v1',
    // This catalog is not consumed for the sentinel today. Keeping the
    // field pinned preserves the manifest contract; any attempted merge
    // would fail identity validation and return this built-in manifest.
    runtimeCatalogUri: Uri.parse(
      'https://raw.githubusercontent.com/ornab74/'
      'naza_one_generation_ui_code/92e3c182ea1ed8209ac57d600b3cb571ae6e4bfd/mirrors.md',
    ),
    fullSources: <NazaDistributionSource>[
      NazaDistributionSource(
        id: 'sentinel-github-full',
        uri: Uri.parse(
          'https://github.com/ornab74/naza_one_generation_ui_code/'
          'releases/download/v1/llama3-small-Q3_K_M.gguf',
        ),
        plane: NazaDistributionPlane.canonicalFull,
        trustWeight: 1.25,
      ),
      NazaDistributionSource(
        id: 'sentinel-huggingface-full',
        uri: Uri.parse(
          'https://huggingface.co/tensorblock/llama3-small-GGUF/'
          'resolve/main/llama3-small-Q3_K_M.gguf',
        ),
        plane: NazaDistributionPlane.canonicalFull,
        trustWeight: 1.10,
      ),
      NazaDistributionSource(
        id: 'sentinel-pinata-full',
        uri: Uri.parse(
          'https://silver-southern-echidna-758.mypinata.cloud/ipfs/'
          'bafybeifb3732qilucogsp7d3q4kgqewkyu2lguyhndgzv5jlbkqiptqt5a',
        ),
        plane: NazaDistributionPlane.canonicalFull,
        trustWeight: 1.05,
      ),
    ],
    // The downloader's ordered assembly contract requires a part layout.
    // This 106 MiB artifact is represented as one hash-pinned part while
    // the full-object mirrors above race for every bounded range.
    parts: <NazaDistributionPart>[
      NazaDistributionPart(
        index: 0,
        name: 'llama3-small-Q3_K_M.gguf',
        expectedBytes: 111454016,
        expectedSha256:
            '8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa',
        sources: <NazaDistributionSource>[],
      ),
    ],
  );

  static NazaDistributionPart _part({
    required int index,
    required String expectedSha256,
  }) {
    final suffix = index.toString().padLeft(2, '0');
    final name = 'gemma-4-E2B-it.litertlm.part$suffix.bin';
    return NazaDistributionPart(
      index: index,
      name: name,
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
            'bytes': part.expectedBytes,
            'sha256': part.expectedSha256.toLowerCase(),
          },
      ],
      'chunkBytes': chunkBytes,
    });
    return crypto.sha256.convert(utf8.encode(canonical)).toString();
  }
}
