// LLM-CONTEXT:BEGIN
// FILE: test_archive/key_guardian_test.dart
// ROLE: Owns key guardian test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/key_guardian.dart';
import 'package:naza_one/security/secure_database.dart';

void main() {
  test('guardian returns opaque non-exportable handles and stable derivations', () async {
    final store = NazaMemoryDeviceKeyStore();
    final guardian = NazaSecureStoreKeyGuardian(store);
    const vaultId = 'abcdefghijklmnop';

    final handle = await guardian.ensureRoot(
      vaultId: vaultId,
      purpose: NazaGuardianPurpose.capabilityRoot,
    );

    expect(handle.exportable, isFalse);
    expect(handle.protection, NazaGuardianProtection.platformSecureStore);
    expect(handle.id, contains(vaultId));

    final first = await guardian.deriveEphemeralSecret(
      handle: handle,
      label: 'session',
      context: const {'epoch': 7, 'purpose': 'capability'},
    );
    final second = await guardian.deriveEphemeralSecret(
      handle: handle,
      label: 'session',
      context: const {'epoch': 7, 'purpose': 'capability'},
    );
    final different = await guardian.deriveEphemeralSecret(
      handle: handle,
      label: 'session',
      context: const {'epoch': 8, 'purpose': 'capability'},
    );

    expect(first, second);
    expect(first, isNot(different));
    expect(first, hasLength(32));
  });

  test('guardian separates purpose roots', () async {
    final store = NazaMemoryDeviceKeyStore();
    final guardian = NazaSecureStoreKeyGuardian(store);
    const vaultId = 'abcdefghijklmnop';

    final capability = await guardian.ensureRoot(
      vaultId: vaultId,
      purpose: NazaGuardianPurpose.capabilityRoot,
    );
    final audit = await guardian.ensureRoot(
      vaultId: vaultId,
      purpose: NazaGuardianPurpose.auditRoot,
    );

    final capKey = await guardian.deriveEphemeralSecret(
      handle: capability,
      label: 'session',
      context: const {'epoch': 1},
    );
    final auditKey = await guardian.deriveEphemeralSecret(
      handle: audit,
      label: 'session',
      context: const {'epoch': 1},
    );

    expect(capKey, isNot(auditKey));
  });

  test('forged purpose-confusion handle is rejected', () async {
    final store = NazaMemoryDeviceKeyStore();
    final guardian = NazaSecureStoreKeyGuardian(store);
    final capability = await guardian.ensureRoot(
      vaultId: 'abcdefghijklmnop',
      purpose: NazaGuardianPurpose.capabilityRoot,
    );
    final forged = NazaKeyHandle(
      id: capability.id,
      purpose: NazaGuardianPurpose.auditRoot,
      protection: capability.protection,
      exportable: false,
    );

    await expectLater(
      guardian.deriveEphemeralSecret(
        handle: forged,
        label: 'session',
        context: const {'epoch': 1},
      ),
      throwsA(
        isA<NazaKeyGuardianException>().having(
          (error) => error.code,
          'code',
          'invalid_handle',
        ),
      ),
    );
  });

  test('revoked guardian root fails future derivation', () async {
    final store = NazaMemoryDeviceKeyStore();
    final guardian = NazaSecureStoreKeyGuardian(store);
    final handle = await guardian.ensureRoot(
      vaultId: 'abcdefghijklmnop',
      purpose: NazaGuardianPurpose.modelTrustRoot,
    );

    await guardian.revokeRoot(handle);

    await expectLater(
      guardian.deriveEphemeralSecret(
        handle: handle,
        label: 'session',
        context: const {'epoch': 1},
      ),
      throwsA(
        isA<NazaKeyGuardianException>().having(
          (error) => error.code,
          'code',
          'root_missing',
        ),
      ),
    );
  });
}
