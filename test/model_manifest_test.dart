import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model_bootstrap/model_manifest.dart';

void main() {
  test('production manifest is fully configured from the published IPFS set', () {
    expect(primaryModelManifest.isConfigured, isTrue);
    expect(primaryModelManifest.validate, returnsNormally);
    expect(
      primaryModelManifest.manifestCid,
      'bafybeieddw3q33xyvreaycv3dwiu6o36yvpfkpphtrh2laiflkzf7izjdq',
    );
    expect(primaryModelManifest.expectedParts, hasLength(3));
    expect(
      primaryModelManifest.expectedParts.fold<int>(0, (sum, part) => sum + part.sizeBytes),
      primaryModelManifest.expectedBytes,
    );
  });

  test('default seed profile reproduces the publishing layout', () {
    const profile = ModelSeedProfile();
    expect(profile.validate, returnsNormally);
    expect(
      profile.kuboAddArguments,
      containsAll(<String>[
        '--cid-version=1',
        '--hash=sha2-256',
        '--chunker=size-262144',
        '--raw-leaves=true',
        '--trickle=false',
      ]),
    );
  });

  test('rejects a seed profile without raw leaves', () {
    const profile = ModelSeedProfile(rawLeaves: false);
    expect(profile.validate, throwsA(isA<ModelManifestException>()));
  });

  test('rejects traversal file names', () {
    const manifest = ModelManifest(
      fileName: '../model.bin',
      manifestCid: 'bafybeieddw3q33xyvreaycv3dwiu6o36yvpfkpphtrh2laiflkzf7izjdq',
      manifestSigningKeySha256:
          'fc5d1367b9f18a34b0980ae8605bdbf4da5e6a376346a1706e9417ec8638ecdb',
      sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      expectedBytes: 1,
      expectedParts: <ModelPartManifest>[
        ModelPartManifest(
          index: 0,
          name: 'part.bin',
          sizeBytes: 1,
          sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          cid: 'bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty',
        ),
      ],
    );
    expect(manifest.validate, throwsA(isA<ModelManifestException>()));
  });

  test('rejects non-hex SHA-256 values', () {
    const manifest = ModelManifest(
      fileName: 'model.bin',
      manifestCid: 'bafybeieddw3q33xyvreaycv3dwiu6o36yvpfkpphtrh2laiflkzf7izjdq',
      manifestSigningKeySha256:
          'fc5d1367b9f18a34b0980ae8605bdbf4da5e6a376346a1706e9417ec8638ecdb',
      sha256: 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
      expectedBytes: 1,
      expectedParts: <ModelPartManifest>[
        ModelPartManifest(
          index: 0,
          name: 'part.bin',
          sizeBytes: 1,
          sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          cid: 'bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty',
        ),
      ],
    );
    expect(manifest.validate, throwsA(isA<ModelManifestException>()));
  });
}
