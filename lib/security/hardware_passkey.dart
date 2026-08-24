// Hardware-backed authentication contracts and replay-resistant challenges.
// Native adapters must use WebAuthn/FIDO2 APIs (Android Credential Manager,
// iOS AuthenticationServices, Windows WebAuthn, or Linux libfido2).
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

enum NazaPasskeyPurpose { signIn, ipfsSigning, privilegedOperation }

@immutable
final class NazaPasskeyChallenge {
  const NazaPasskeyChallenge({
    required this.id,
    required this.bytes,
    required this.purpose,
    required this.relyingPartyId,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final Uint8List bytes;
  final NazaPasskeyPurpose purpose;
  final String relyingPartyId;
  final DateTime createdAt;
  final DateTime expiresAt;
}

@immutable
final class NazaVerifiedPasskeyAssertion {
  const NazaVerifiedPasskeyAssertion({
    required this.credentialId,
    required this.relyingPartyId,
    required this.challengeId,
    required this.signCount,
    required this.userVerified,
    required this.assertionDigest,
  });

  final String credentialId;
  final String relyingPartyId;
  final String challengeId;
  final int signCount;
  final bool userVerified;
  final String assertionDigest;
}

/// Platform implementations must validate origin/RP binding, the client-data
/// challenge, authenticator flags, credential signature, and user verification
/// before returning this value. Raw assertions are never treated as verified.
abstract interface class NazaPasskeyPlatform {
  Future<bool> isAvailable();

  Future<NazaVerifiedPasskeyAssertion> verifyWithHardware({
    required NazaPasskeyChallenge challenge,
    required bool requireUserVerification,
  });
}

final class NazaUnavailablePasskeyPlatform implements NazaPasskeyPlatform {
  const NazaUnavailablePasskeyPlatform();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<NazaVerifiedPasskeyAssertion> verifyWithHardware({
    required NazaPasskeyChallenge challenge,
    required bool requireUserVerification,
  }) => throw const NazaPasskeyException(
    'passkey_unavailable',
    'A verified platform WebAuthn/FIDO2 adapter is not available.',
  );
}

final class NazaPasskeyGate {
  NazaPasskeyGate({
    required NazaPasskeyPlatform platform,
    this.challengeLifetime = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _platform = platform,
       _clock = clock ?? DateTime.now;

  final NazaPasskeyPlatform _platform;
  final Duration challengeLifetime;
  final DateTime Function() _clock;
  final Map<String, NazaPasskeyChallenge> _pending = {};
  final Map<String, int> _lastCounters = {};
  final Random _random = Random.secure();

  NazaPasskeyChallenge issue({
    required NazaPasskeyPurpose purpose,
    required String relyingPartyId,
  }) {
    final rp = relyingPartyId.trim().toLowerCase();
    if (!_validRp(rp) ||
        challengeLifetime <= Duration.zero ||
        challengeLifetime > const Duration(minutes: 5)) {
      throw const NazaPasskeyException(
        'passkey_policy_invalid',
        'Passkey relying-party or challenge lifetime is invalid.',
      );
    }
    _purgeExpired();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256), growable: false),
    );
    final id = base64UrlEncode(
      crypto.sha256.convert(bytes).bytes,
    ).replaceAll('=', '');
    final now = _clock().toUtc();
    final challenge = NazaPasskeyChallenge(
      id: id,
      bytes: bytes,
      purpose: purpose,
      relyingPartyId: rp,
      createdAt: now,
      expiresAt: now.add(challengeLifetime),
    );
    _pending[id] = challenge;
    return challenge;
  }

  Future<NazaVerifiedPasskeyAssertion> authorize(
    NazaPasskeyChallenge challenge,
  ) async {
    final pending = _pending.remove(challenge.id);
    if (pending == null ||
        !_constantTimeEqual(pending.bytes, challenge.bytes) ||
        !_clock().toUtc().isBefore(pending.expiresAt)) {
      throw const NazaPasskeyException(
        'passkey_challenge_rejected',
        'The hardware-authentication challenge is expired, unknown, or reused.',
      );
    }
    if (!await _platform.isAvailable()) {
      throw const NazaPasskeyException(
        'passkey_unavailable',
        'Hardware-backed authentication is unavailable on this device.',
      );
    }
    final assertion = await _platform.verifyWithHardware(
      challenge: pending,
      requireUserVerification: true,
    );
    if (!assertion.userVerified ||
        assertion.challengeId != pending.id ||
        assertion.relyingPartyId.toLowerCase() != pending.relyingPartyId ||
        assertion.credentialId.isEmpty ||
        assertion.assertionDigest.length != 64) {
      throw const NazaPasskeyException(
        'passkey_assertion_rejected',
        'The hardware assertion failed its binding requirements.',
      );
    }
    final previous = _lastCounters[assertion.credentialId];
    // Zero is permitted for authenticators that do not implement counters.
    if (assertion.signCount != 0 &&
        previous != null &&
        assertion.signCount <= previous) {
      throw const NazaPasskeyException(
        'passkey_clone_suspected',
        'The authenticator counter did not advance.',
      );
    }
    _lastCounters[assertion.credentialId] = assertion.signCount;
    return assertion;
  }

  void _purgeExpired() {
    final now = _clock().toUtc();
    _pending.removeWhere((_, value) => !now.isBefore(value.expiresAt));
  }

  static bool _validRp(String value) =>
      value.length <= 253 &&
      RegExp(
        r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
      ).hasMatch(value);
}

bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    difference |= left[i] ^ right[i];
  }
  return difference == 0;
}

final class NazaPasskeyException implements Exception {
  const NazaPasskeyException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'NazaPasskeyException($code): $message';
}
