import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test(
    'materialization creates a private regular snapshot without a shell',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'naza-model-snapshot-',
      );
      addTearDown(() => root.delete(recursive: true));
      final support = Directory('${root.path}/support');
      final marker = File('${root.path}/command-executed');
      final source = File('${root.path}/valid&touch-command-executed.litertlm');
      final bytes = List<int>.generate(4096, (index) => index & 0xff);
      await source.writeAsBytes(bytes, flush: true);
      final digest = crypto.sha256.convert(bytes).toString();
      final manifest = NazaModelDistributionManifest(
        modelFileName: 'trusted-model.litertlm',
        expectedSha256: digest,
        expectedBytes: bytes.length,
        revision: 'test-revision',
        fullSources: const <NazaDistributionSource>[],
        parts: const <NazaDistributionPart>[],
        runtimeCatalogUri: Uri.parse('https://raw.githubusercontent.com/test'),
      );
      final database = NazaSecureDatabase.forTesting(
        Directory('${root.path}/vault'),
      );
      final preference = NazaLocalModelPreference(
        database: database,
        manifest: manifest,
        supportDirectoryProvider: () async => support,
      );
      final selection = await preference.verify(source);

      final managed = await preference.materializeForApp(selection);

      expect(await managed.readAsBytes(), bytes);
      expect(await Link(managed.path).exists(), isFalse);
      expect(await marker.exists(), isFalse);

      await source.writeAsBytes(List<int>.filled(bytes.length, 7), flush: true);
      expect(await managed.readAsBytes(), bytes);
    },
  );
}
