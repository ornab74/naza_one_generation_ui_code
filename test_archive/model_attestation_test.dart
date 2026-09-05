// LLM-CONTEXT:BEGIN
// FILE: test_archive/model_attestation_test.dart
// ROLE: Owns model attestation test behavior within the model-runtime subsystem.
// DOMAIN: model-runtime
// SECURITY-INVARIANT: Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  late Directory directory;
  late NazaSecureDatabase database;
  late NazaModelAttestationStore attestations;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-attestation-');
    database = NazaSecureDatabase.forTesting(directory);
    await database.create(password: 'test-password');
    attestations = NazaModelAttestationStore.forTesting(database);
  });

  tearDown(() async {
    await database.lock();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('hashes an artifact once and then trusts encrypted metadata', () async {
    final model = File('${directory.path}/model.litertlm');
    await model.writeAsString('pinned model bytes', flush: true);
    final expected = sha256.convert(await model.readAsBytes()).toString();
    var hashCalls = 0;

    Future<String> hash() async {
      hashCalls++;
      return sha256.convert(await model.readAsBytes()).toString();
    }

    final first = await attestations.verifyOnce(
      file: model,
      sha256: expected,
      marker: 'release-1',
      computeSha256: hash,
    );
    final second = await attestations.verifyOnce(
      file: model,
      sha256: expected,
      marker: 'release-1',
      computeSha256: hash,
    );

    expect(first.verified, isTrue);
    expect(first.hashComputed, isTrue);
    expect(second.verified, isTrue);
    expect(second.hashComputed, isFalse);
    expect(hashCalls, 1);
  });

  test('keeps independent attestations for different model paths', () async {
    final first = File('${directory.path}/first.litertlm');
    final second = File('${directory.path}/second.litertlm');
    final firstDigest = List<String>.filled(64, 'a').join();
    final secondDigest = List<String>.filled(64, 'b').join();
    await first.writeAsString('first');
    await second.writeAsString('second');

    await attestations.trustFile(
      file: first,
      sha256: firstDigest,
      marker: 'release',
    );
    await attestations.trustFile(
      file: second,
      sha256: secondDigest,
      marker: 'release',
    );

    expect(
      await attestations.isTrustedFile(
        file: first,
        sha256: firstDigest,
        marker: 'release',
      ),
      isTrue,
    );
    expect(
      await attestations.isTrustedFile(
        file: second,
        sha256: secondDigest,
        marker: 'release',
      ),
      isTrue,
    );
  });

  test('invalidates trust when the artifact changes', () async {
    final model = File('${directory.path}/model.litertlm');
    final digest = List<String>.filled(64, 'c').join();
    await model.writeAsString('before', flush: true);
    await attestations.trustFile(
      file: model,
      sha256: digest,
      marker: 'release',
    );

    await Future<void>.delayed(const Duration(milliseconds: 2));
    await model.writeAsString('after!', flush: true);

    expect(
      await attestations.isTrustedFile(
        file: model,
        sha256: digest,
        marker: 'release',
      ),
      isFalse,
    );
  });
}
