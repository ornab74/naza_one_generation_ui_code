import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  late Directory directory;
  late List<int> keyBytes;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-legacy-');
    keyBytes = List<int>.generate(32, (index) => index + 1);
    await File(
      '${directory.path}/${NazaAppConfig.keyFileName}',
    ).writeAsString(base64Encode(keyBytes), flush: true);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'authenticates legacy records before allowing explicit cleanup',
    () async {
      final rows = [
        {
          'id': 'legacy-1',
          'timestamp': DateTime.utc(2026).toIso8601String(),
          'user': 'old prompt',
          'assistant': 'old answer',
          'route': 'legacy',
          'score': 0.5,
        },
      ];
      final history = File(
        '${directory.path}/${NazaAppConfig.historyFileName}',
      );
      await _writeLegacy(history, rows, NazaAppConfig.vaultAad, keyBytes);

      final migration = await NazaLegacyVaultMigrator.readAll(
        directory: directory,
      );

      expect(
        migration.records[const NazaVaultRecordKey('history', 'rows')],
        rows,
      );
      expect(await history.exists(), isTrue);
      expect(
        await File('${directory.path}/${NazaAppConfig.keyFileName}').exists(),
        isTrue,
      );

      await migration.commitCleanup();
      expect(await history.exists(), isFalse);
      expect(
        await File('${directory.path}/${NazaAppConfig.keyFileName}').exists(),
        isFalse,
      );
    },
  );

  test('fails closed when a legacy ciphertext is tampered', () async {
    final history = File('${directory.path}/${NazaAppConfig.historyFileName}');
    await _writeLegacy(
      history,
      const <Object?>[],
      NazaAppConfig.vaultAad,
      keyBytes,
    );
    final wrapper = jsonDecode(await history.readAsString()) as Map;
    final ciphertext = base64Decode(wrapper['cipherText'] as String);
    ciphertext[0] ^= 0x01;
    wrapper['cipherText'] = base64Encode(ciphertext);
    await history.writeAsString(jsonEncode(wrapper), flush: true);

    await expectLater(
      NazaLegacyVaultMigrator.readAll(directory: directory),
      throwsA(
        isA<NazaVaultException>().having(
          (error) => error.code,
          'code',
          'legacy_authentication',
        ),
      ),
    );

    expect(await history.exists(), isTrue);
    expect(
      await File('${directory.path}/${NazaAppConfig.keyFileName}').exists(),
      isTrue,
    );
  });
}

Future<void> _writeLegacy(
  File file,
  Object? value,
  String aad,
  List<int> keyBytes,
) async {
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(value)),
    secretKey: SecretKey(keyBytes),
    aad: utf8.encode(aad),
  );
  await file.writeAsString(
    jsonEncode({
      'version': 2,
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    }),
    flush: true,
  );
}
