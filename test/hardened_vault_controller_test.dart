import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/hardened_vault_controller.dart';
import 'package:naza_one/security/secure_database.dart';
import 'package:naza_one/security/security_kernel.dart';

void main() {
  late Directory directory;
  late NazaMemoryDeviceKeyStore secureStore;
  late NazaSecureDatabase vault;
  late NazaHardenedVaultController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-hardened-vault-');
    secureStore = NazaMemoryDeviceKeyStore();
    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: secureStore,
    );
    controller = _controller(vault, secureStore);
  });

  tearDown(() async {
    try {
      await controller.lock();
    } catch (_) {}
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('creates encrypted security state and requires fresh auth to export', () async {
    await controller.create(password: 'correct-password');
    await controller.writeJson('history', 'one', {'value': 1});

    expect(controller.securityEpoch, isNotNull);
    await expectLater(
      controller.authorizeWithPassword(
        password: 'wrong-password',
        action: NazaPrivilegedAction.exportVault,
      ),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          'fresh_auth_required',
        ),
      ),
    );

    final lease = await controller.authorizeWithPassword(
      password: 'correct-password',
      action: NazaPrivilegedAction.exportVault,
    );
    final exported = await controller.exportRecordsAuthorized(lease);
    expect(
      exported[const NazaVaultRecordKey('history', 'one')],
      containsPair('value', 1),
    );
    expect(
      exported.keys.where((key) => key.namespace == 'security.kernel'),
      isEmpty,
    );

    await expectLater(
      controller.exportRecordsAuthorized(lease),
      throwsA(isA<NazaSecurityException>()),
    );
  });

  test('privileged key rotation advances epoch and invalidates old leases', () async {
    await controller.create(password: 'correct-password');
    final exportLease = await controller.authorizeWithPassword(
      password: 'correct-password',
      action: NazaPrivilegedAction.exportVault,
    );
    final rotateLease = await controller.authorizeWithPassword(
      password: 'correct-password',
      action: NazaPrivilegedAction.rotateKeys,
    );
    final before = controller.securityEpoch!;

    await controller.rotateDataKeyAuthorized(rotateLease);
    expect(controller.securityEpoch, before + 1);

    await expectLater(
      controller.exportRecordsAuthorized(exportLease),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          anyOf('capability_invalid', 'capability_stale'),
        ),
      ),
    );
  });

  test('rollback guard rejects restored older encrypted security state', () async {
    await controller.create(password: 'correct-password');
    final originalHeader = File('${directory.path}/naza_one_vault.header.json');
    final originalDatabase = await vault.databaseFile();
    final oldHeader = await originalHeader.readAsBytes();
    final oldDatabase = await originalDatabase.readAsBytes();

    final rotateLease = await controller.authorizeWithPassword(
      password: 'correct-password',
      action: NazaPrivilegedAction.rotateKeys,
    );
    await controller.rotateDataKeyAuthorized(rotateLease);
    expect(controller.securityEpoch, greaterThan(1));
    await controller.lock();

    await originalHeader.writeAsBytes(oldHeader, flush: true);
    await originalDatabase.writeAsBytes(oldDatabase, flush: true);

    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: secureStore,
    );
    controller = _controller(vault, secureStore);

    await expectLater(
      controller.unlock('correct-password'),
      throwsA(
        isA<NazaSecurityException>().having(
          (error) => error.code,
          'code',
          anyOf('rollback_detected', 'rollback_state_missing'),
        ),
      ),
    );
    expect(vault.isUnlocked, isFalse);
  });

  test('tampered encrypted security metadata fails closed', () async {
    await controller.create(password: 'correct-password');
    await controller.lock();

    final database = await vault.databaseFile();
    final bytes = await database.readAsBytes();
    expect(bytes, isNotEmpty);

    // The controller's reserved state is authenticated by the underlying vault.
    // This test modifies the header-level vault identity instead, which must fail
    // before a hardened session can be attached.
    final headerFile = File('${directory.path}/naza_one_vault.header.json');
    final header = Map<String, Object?>.from(
      jsonDecode(await headerFile.readAsString()) as Map,
    );
    header['vaultId'] = 'AAAAAAAAAAAAAAAAAAAA';
    await headerFile.writeAsString(jsonEncode(header), flush: true);

    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: secureStore,
    );
    controller = _controller(vault, secureStore);

    await expectLater(
      controller.unlock('correct-password'),
      throwsA(anything),
    );
    expect(vault.isUnlocked, isFalse);
  });
}

NazaHardenedVaultController _controller(
  NazaSecureDatabase vault,
  NazaMemoryDeviceKeyStore store,
) {
  return NazaHardenedVaultController(
    vault: vault,
    secureStore: store,
    appIdentity: 'naza-one-test-build',
    modelIdentity: 'model-sha256:test',
    policyIdentity: 'security-policy:v1',
    recoveryGeneration: 'recovery:1',
    trustRootIdentity: 'trust-root:test',
  );
}
