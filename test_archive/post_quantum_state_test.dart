import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/post_quantum_export.dart';

void main() {
  test('post-quantum recovery policy is default-on and action-required', () {
    final state = NazaPostQuantumRecoveryState.defaults();

    expect(state.policyEnabled, isTrue);
    expect(state.profile, NazaPostQuantumProfile.maximumHybrid);
    expect(state.suite, contains('ML-KEM-1024'));
    expect(state.status, NazaPostQuantumRecoveryStatus.actionRequired);
    expect(state.publicKeyJson, isNull);
  });

  test('missing or disabled legacy policy migrates to enabled fail-closed', () {
    final state = NazaPostQuantumRecoveryState.fromJson({
      'policyEnabled': false,
      'status': 'ready',
    });

    expect(state.policyEnabled, isTrue);
    expect(state.profile, NazaPostQuantumProfile.maximumHybrid);
    expect(state.status, NazaPostQuantumRecoveryStatus.actionRequired);
  });

  test('verified enrollment state survives encrypted JSON round-trip', () {
    final verifiedAt = DateTime.utc(2026, 7, 18, 12, 30);
    final state = NazaPostQuantumRecoveryState(
      policyEnabled: true,
      profile: NazaPostQuantumProfile.maximumHybrid,
      suite: NazaPostQuantumProfile.maximumHybrid.suite,
      status: NazaPostQuantumRecoveryStatus.ready,
      publicKeyJson: '{"format":"public"}',
      fingerprint: 'fingerprint-value',
      enrolledAt: verifiedAt.subtract(const Duration(hours: 1)),
      lastVerifiedAt: verifiedAt,
    );

    final decoded = NazaPostQuantumRecoveryState.fromJson(state.toJson());

    expect(decoded.policyEnabled, isTrue);
    expect(decoded.status, NazaPostQuantumRecoveryStatus.ready);
    expect(decoded.fingerprint, 'fingerprint-value');
    expect(decoded.lastVerifiedAt, verifiedAt);
  });

  test('ready status without verification time fails closed to enrolled', () {
    final enrolledAt = DateTime.utc(2026, 7, 18, 12);
    final decoded = NazaPostQuantumRecoveryState.fromJson({
      'profile': NazaPostQuantumProfile.maximumHybrid.wireName,
      'status': NazaPostQuantumRecoveryStatus.ready.name,
      'publicKeyJson': '{"format":"public"}',
      'fingerprint': 'fingerprint-value',
      'enrolledAt': enrolledAt.toIso8601String(),
    });

    expect(decoded.status, NazaPostQuantumRecoveryStatus.keyEnrolled);
    expect(decoded.lastVerifiedAt, isNull);
  });

  test('identity without enrollment time is discarded', () {
    final decoded = NazaPostQuantumRecoveryState.fromJson({
      'profile': NazaPostQuantumProfile.maximumHybrid.wireName,
      'status': NazaPostQuantumRecoveryStatus.restored.name,
      'publicKeyJson': '{"format":"public"}',
      'fingerprint': 'fingerprint-value',
      'lastVerifiedAt': DateTime.utc(2026, 7, 18).toIso8601String(),
    });

    expect(decoded.status, NazaPostQuantumRecoveryStatus.actionRequired);
    expect(decoded.publicKeyJson, isNull);
    expect(decoded.fingerprint, isNull);
  });
}
