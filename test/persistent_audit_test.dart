import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/persistent_audit.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  late Directory directory;
  late NazaSecureDatabase vault;
  late NazaMemoryDeviceKeyStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-audit-test-');
    store = NazaMemoryDeviceKeyStore();
    vault = NazaSecureDatabase.forTesting(
      directory,
      deviceKeyStore: store,
    );
    await vault.create(password: 'audit-password');
  });

  tearDown(() async {
    await vault.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('audit survives restart and preserves sequence and tip', () async {
    final first = NazaPersistentForwardAudit(
      vault: vault,
      secureStore: store,
      vaultId: await _vaultId(vault),
    );
    await first.initialize();
    await first.append(
      event: 'one',
      data: const {'value': 1},
      securityEpoch: 1,
    );
    await first.append(
      event: 'two',
      data: const {'value': 2},
      securityEpoch: 1,
    );
    final tip = first.tip;
    first.destroy();

    final second = NazaPersistentForwardAudit(
      vault: vault,
      secureStore: store,
      vaultId: await _vaultId(vault),
    );
    await second.initialize();

    expect(second.sequence, 2);
    expect(second.tip, tip);
    await second.verifyRecent();
  });

  test('tampered audit entry is detected by recent-chain verification', () async {
    final audit = NazaPersistentForwardAudit(
      vault: vault,
      secureStore: store,
      vaultId: await _vaultId(vault),
    );
    await audit.initialize();
    await audit.append(
      event: 'one',
      data: const {'value': 1},
      securityEpoch: 1,
    );

    final raw = await vault.readJson(
      'security.audit',
      '00000000000000000001',
    ) as Map;
    final tampered = Map<String, Object?>.from(raw)
      ..['digest'] = 'attacker-controlled';
    await vault.writeJson(
      'security.audit',
      '00000000000000000001',
      tampered,
    );

    await expectLater(
      audit.verifyRecent(),
      throwsA(
        isA<NazaPersistentAuditException>().having(
          (error) => error.code,
          'code',
          'audit_tip_mismatch',
        ),
      ),
    );
  });
}

Future<String> _vaultId(NazaSecureDatabase vault) async {
  final file = await vault.databaseFile();
  final header = File('${file.parent.path}/naza_one_vault.header.json');
  final text = await header.readAsString();
  final match = RegExp(r'"vaultId"\s*:\s*"([A-Za-z0-9_-]+)"').firstMatch(text);
  return match!.group(1)!;
}
