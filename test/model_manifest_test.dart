import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model_bootstrap/model_manifest.dart';

void main() {
  test('placeholder manifest remains intentionally unconfigured', () {
    expect(primaryModelManifest.isConfigured, isFalse);
  });

  test('rejects traversal file names', () {
    const manifest = ModelManifest(
      fileName: '../model.bin',
      cid: 'QmYwAPJzv5CZsnAzt8auVZRnGiRA7qkLQvEL7i2S6f7b4g',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    expect(manifest.validate, throwsA(isA<ModelManifestException>()));
  });

  test('rejects non-hex SHA-256 values', () {
    const manifest = ModelManifest(
      fileName: 'model.bin',
      cid: 'QmYwAPJzv5CZsnAzt8auVZRnGiRA7qkLQvEL7i2S6f7b4g',
      sha256:
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
    );

    expect(manifest.validate, throwsA(isA<ModelManifestException>()));
  });
}
