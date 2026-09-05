import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('assembly settings are bounded and preserve local Gemma default', () {
    const config = NazaModelAssemblyConfig();
    expect(config.mode, NazaAssemblyMode.localOnly);

    final bounded = config.copyWith(
      mode: NazaAssemblyMode.shardedAssembly,
      profileIds: const <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      chunkCharacters: 999999,
      maxShards: 999,
      entropyThreshold: 9,
    );
    expect(bounded.chunkCharacters, 40000);
    expect(bounded.maxShards, 8);
    expect(bounded.profileIds.length, 8);
    expect(bounded.entropyThreshold, 1);
  });

  test('provider catalog includes advanced model families', () {
    expect(
      NazaModelFeature.foodRecipes.editorialTitle,
      'Pantry-to-Plate Atelier',
    );
    expect(NazaModelFeature.foodRecipes.zone, 'Food Intelligence');
    expect(
      NazaModelFeature.agenticCoding.editorialTitle,
      'Agentic Code Foundry',
    );
    expect(NazaModelFeature.agenticCoding.zone, 'Execution Intelligence');
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.openAi),
      contains('gpt-5.2'),
    );
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.openAi),
      containsAll(<String>['gpt-5.6-luna', 'gpt-5.6-terra', 'gpt-5.6-sol']),
    );
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.anthropic),
      contains('claude-opus-4-1'),
    );
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.gemini),
      contains('gemini-3.1-pro-preview'),
    );
    expect(
      NazaProviderModelCatalog.forProvider(NazaRemoteProvider.meta),
      contains('muse-spark-1.2'),
    );
    final digitalOceanModels = NazaProviderModelCatalog.forProvider(
      NazaRemoteProvider.digitalOcean,
    );
    expect(
      digitalOceanModels,
      containsAll(<String>[
        'kimi-k3',
        'deepseek-v4-pro',
        'openai-gpt-5.6-luna',
        'llama-4-maverick',
        'qwen3.8-max',
        'openai-gpt-oss-120b',
        'gemma-4-31B-it',
        'bge-m3',
        'bge-reranker-v2-m3',
      ]),
    );
    expect(digitalOceanModels.toSet().length, digitalOceanModels.length);
  });

  test(
    'embedding runtime is local-only and fixed to the encrypted index shape',
    () {
      const config = NazaEmbeddingRuntimeConfig();
      expect(config.mode, NazaEmbeddingMode.localOnly);
      expect(config.dimensions, 128);
      expect(
        NazaEmbeddingModelCatalog.forProvider(NazaRemoteProvider.openAi),
        contains('text-embedding-3-large'),
      );
      expect(
        NazaEmbeddingModelCatalog.forProvider(NazaRemoteProvider.gemini),
        contains('gemini-embedding-2'),
      );
    },
  );

  test('malformed embedding settings fail closed to safe bounded defaults', () {
    final config = NazaEmbeddingRuntimeConfig.fromJson(<String, Object?>{
      'mode': 'not-a-mode',
      'dimensions': 'untrusted',
      'remoteBlend': 'untrusted',
      'targets': <Object?>[
        <String, Object?>{
          'profileId': List<String>.filled(101, 'x').join(),
          'model': 'not-used',
        },
      ],
    });
    expect(config.mode, NazaEmbeddingMode.localOnly);
    expect(config.dimensions, 128);
    expect(config.remoteBlend, 0.35);
    expect(config.targets, isEmpty);
  });

  test(
    'Meta Muse official endpoint is accepted without custom endpoint mode',
    () {
      expect(
        () => NazaProviderGateway.validateEndpoint(
          provider: NazaRemoteProvider.meta,
          endpoint: 'https://api.meta.ai/v1/chat/completions',
          allowCustomEndpoint: false,
        ),
        returnsNormally,
      );
    },
  );

  test('strict trust policy defaults to the maximum hybrid profile', () {
    final policy = NazaPqTrustPolicy.maximum();
    expect(policy.requireHybridKem, isTrue);
    expect(policy.minimumKem, 'ML-KEM-1024');
    expect(policy.minimumPqSignature, 'ML-DSA-87');
    expect(policy.allowedClassicalKems, contains('X25519'));
  });
}
