import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model_bootstrap.dart';

void main() {
  test('GitHub release manifest is ordered and pinned', () {
    NazaModelBootstrapManifest.validate();

    final parts = NazaModelBootstrapManifest.githubReleaseParts;
    expect(parts, hasLength(3));
    expect(parts[0].name, endsWith('part00.bin'));
    expect(parts[1].name, endsWith('part01.bin'));
    expect(parts[2].name, endsWith('part02.bin'));
    expect(
      parts.map((part) => part.sha256),
      const [
        'b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995',
        '5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8',
        '00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3',
      ],
    );
    expect(
      NazaModelBootstrapManifest.githubJoinedSize,
      parts.fold<int>(0, (total, part) => total + part.size),
    );
  });

  test('full model pin is the application trust pin', () {
    expect(
      NazaModelBootstrapManifest.fullSha256,
      'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
    );
  });

  test('file integrity verifier accepts exact bytes and rejects tampering', () async {
    final temp = await Directory.systemTemp.createTemp('naza-model-integrity-');
    addTearDown(() => temp.delete(recursive: true));

    final file = File('${temp.path}/part.bin');
    final bytes = List<int>.generate(4096, (index) => index & 0xff);
    await file.writeAsBytes(bytes, flush: true);
    final expected = crypto.sha256.convert(bytes).toString();

    await NazaModelIntegrity.verifyFile(
      file: file,
      expectedSha256: expected,
      expectedSize: bytes.length,
    );

    final tampered = List<int>.from(bytes);
    tampered[tampered.length - 1] ^= 0x01;
    await file.writeAsBytes(tampered, flush: true);

    await expectLater(
      NazaModelIntegrity.verifyFile(
        file: file,
        expectedSha256: expected,
        expectedSize: bytes.length,
      ),
      throwsA(isA<NazaModelIntegrityException>()),
    );
  });
}
