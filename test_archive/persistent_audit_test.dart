// LLM-CONTEXT:BEGIN
// FILE: test_archive/persistent_audit_test.dart
// ROLE: Owns persistent audit test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/persistent_audit.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  late Directory directory;
  late NazaSecureDatabase vault;
  late NazaMemoryDeviceKeyStore store;
  late List<int> checkpointKey;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('naza-audit-test-');
    store = NazaMemoryDeviceKeyStore();
    checkpointKey = List<int>.generate(32, (index) => index + 1);
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

  NazaPersistentForwardAudit auditFor(String vaultId) {
    return NazaPersistentForwardAudit(
      vault: vault,
      secureStore: store,
      vaultId: vaultId,
      checkpointKey: checkpointKey,
    );
  }

  test('audit survives restart and preserves sequence and tip', () async {
    final vaultId = await _vaultId(vault);
    final first = auditFor(vaultId);
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

    final second = auditFor(vaultId);
    await second.initialize();

    expect(second.sequence, 2);
    expect(second.tip, tip);
    await second.verifyRecent();
  });

  test('tampered audit entry is detected by recent-chain verification', () async {
    final audit = auditFor(await _vaultId(vault));
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
          anyOf('audit_tip_mismatch', 'audit_digest'),
        ),
      ),
    );
  });

  test('tampered sealed checkpoint fails AEAD authentication', () async {
    final vaultId = await _vaultId(vault);
    final audit = auditFor(vaultId);
    await audit.initialize();
    await audit.append(
      event: 'one',
      data: const {'value': 1},
      securityEpoch: 1,
    );
    audit.destroy();

    final storageKey = 'naza-audit-checkpoint-v2-$vaultId';
    final encoded = await store.read(storageKey);
    final envelope = Map<String, Object?>.from(
      jsonDecode(encoded!) as Map,
    );
    final mac = base64Decode(envelope['mac'].toString());
    mac[0] ^= 0x01;
    envelope['mac'] = base64Encode(mac);
    await store.write(storageKey, jsonEncode(envelope));

    final restarted = auditFor(vaultId);
    await expectLater(
      restarted.initialize(),
      throwsA(
        isA<NazaPersistentAuditException>().having(
          (error) => error.code,
          'code',
          'checkpoint_authentication',
        ),
      ),
    );
  });

  test('deleted checkpoint cannot reset existing audit history', () async {
    final vaultId = await _vaultId(vault);
    final audit = auditFor(vaultId);
    await audit.initialize();
    await audit.append(
      event: 'one',
      data: const {'value': 1},
      securityEpoch: 1,
    );
    audit.destroy();

    await store.delete('naza-audit-checkpoint-v2-$vaultId');

    final restarted = auditFor(vaultId);
    await expectLater(
      restarted.initialize(),
      throwsA(
        isA<NazaPersistentAuditException>().having(
          (error) => error.code,
          'code',
          'checkpoint_missing',
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
