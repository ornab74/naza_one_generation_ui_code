import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/agentic/ipfs_chatrooms.dart';
import 'package:naza_one/security/hardware_passkey.dart';

final class _VerifiedPlatform implements NazaPasskeyPlatform {
  var counter = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NazaVerifiedPasskeyAssertion> verifyWithHardware({
    required NazaPasskeyChallenge challenge,
    required bool requireUserVerification,
  }) async {
    counter++;
    return NazaVerifiedPasskeyAssertion(
      credentialId: 'hardware_credential_01',
      relyingPartyId: challenge.relyingPartyId,
      challengeId: challenge.id,
      signCount: counter,
      userVerified: requireUserVerification,
      assertionDigest: 'a' * 64,
    );
  }
}

void main() {
  test('passkey challenges are hardware verified and single use', () async {
    final gate = NazaPasskeyGate(platform: _VerifiedPlatform());
    final challenge = gate.issue(
      purpose: NazaPasskeyPurpose.ipfsSigning,
      relyingPartyId: 'naza.local',
    );
    final assertion = await gate.authorize(challenge);
    expect(assertion.userVerified, isTrue);
    await expectLater(
      gate.authorize(challenge),
      throwsA(
        isA<NazaPasskeyException>().having(
          (error) => error.code,
          'code',
          'passkey_challenge_rejected',
        ),
      ),
    );
  });

  test('ML-DSA-87 signs the complete IPFS envelope transcript', () async {
    final signer = await NazaIpfsMlDsa87Signer.generate();
    addTearDown(signer.destroy);
    final unsigned = NazaChatMessageEnvelope(
      id: 'message-pq-01',
      roomId: 'room-pq-01',
      senderId: 'sender-pq-01',
      senderKind: NazaChatRoomKind.agent,
      ciphertextCid: 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3',
      aadDigest: 'b' * 64,
      signatureKeyId: 'vault:ml-dsa-87:01',
      sequence: 4,
      createdAt: DateTime.utc(2026, 8, 24),
      passkeyCredentialId: 'hardware_credential_01',
      passkeyAssertionDigest: 'a' * 64,
    );
    final signed = await signer.sign(unsigned);
    expect(signed.hasAdvancedSignature, isTrue);
    expect(await signed.verifyAdvancedSignature(), isTrue);

    final tampered = NazaChatMessageEnvelope(
      id: signed.id,
      roomId: signed.roomId,
      senderId: signed.senderId,
      senderKind: signed.senderKind,
      ciphertextCid: '${signed.ciphertextCid}x',
      aadDigest: signed.aadDigest,
      signatureKeyId: signed.signatureKeyId,
      sequence: signed.sequence,
      createdAt: signed.createdAt,
      passkeyCredentialId: signed.passkeyCredentialId,
      passkeyAssertionDigest: signed.passkeyAssertionDigest,
      mlDsa87PublicKey: signed.mlDsa87PublicKey,
      mlDsa87Signature: signed.mlDsa87Signature,
    );
    expect(await tampered.verifyAdvancedSignature(), isFalse);
  });
}
