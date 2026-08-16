// LLM-CONTEXT:BEGIN
// FILE: lib/security/intent_guard.dart
// ROLE: Owns intent guard behavior within the security subsystem.
// DOMAIN: security
// SECURITY-INVARIANT: Fail closed on malformed, unauthenticated, stale, or unavailable security state.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'security_kernel.dart';

enum NazaTrustClass {
  trustedSystem,
  trustedLocal,
  userAuthored,
  modelGenerated,
  externalUntrusted,
  malformedOrUnknown,
}

enum NazaIntentRisk {
  informational,
  privateRead,
  privateWrite,
  privileged,
  catastrophic,
}

final class NazaContextProvenance {
  final String sourceId;
  final NazaTrustClass trustClass;
  final String sensitivity;
  final int securityEpoch;

  const NazaContextProvenance({
    required this.sourceId,
    required this.trustClass,
    required this.sensitivity,
    required this.securityEpoch,
  });
}

final class NazaProposedIntent {
  final String id;
  final String operation;
  final NazaIntentRisk risk;
  final NazaPrivilegedAction? privilegedAction;
  final String resource;
  final List<NazaContextProvenance> provenance;
  final bool explicitUserRequest;

  const NazaProposedIntent({
    required this.id,
    required this.operation,
    required this.risk,
    required this.privilegedAction,
    required this.resource,
    required this.provenance,
    required this.explicitUserRequest,
  });
}

final class NazaIntentDecision {
  final bool allowed;
  final bool freshAuthorizationRequired;
  final String reason;

  const NazaIntentDecision({
    required this.allowed,
    required this.freshAuthorizationRequired,
    required this.reason,
  });
}

/// Deterministic authority gate for model/retrieval generated intents.
///
/// No LLM output can override these rules. External or model-generated content
/// may inform an answer but cannot elevate itself into authorization.
final class NazaIntentGuard {
  const NazaIntentGuard();

  NazaIntentDecision evaluate({
    required NazaProposedIntent intent,
    required NazaSecurityState state,
  }) {
    if (intent.id.trim().isEmpty || intent.operation.trim().isEmpty) {
      return const NazaIntentDecision(
        allowed: false,
        freshAuthorizationRequired: false,
        reason: 'malformed-intent',
      );
    }
    if (intent.provenance.any((item) => item.securityEpoch != state.epoch)) {
      return const NazaIntentDecision(
        allowed: false,
        freshAuthorizationRequired: false,
        reason: 'stale-provenance',
      );
    }

    final containsHostileAuthority = intent.provenance.any(
      (item) =>
          item.trustClass == NazaTrustClass.externalUntrusted ||
          item.trustClass == NazaTrustClass.malformedOrUnknown,
    );
    final containsModelAuthority = intent.provenance.any(
      (item) => item.trustClass == NazaTrustClass.modelGenerated,
    );

    if (intent.risk == NazaIntentRisk.informational) {
      return const NazaIntentDecision(
        allowed: true,
        freshAuthorizationRequired: false,
        reason: 'informational-only',
      );
    }

    if (!intent.explicitUserRequest &&
        (containsHostileAuthority || containsModelAuthority)) {
      return const NazaIntentDecision(
        allowed: false,
        freshAuthorizationRequired: false,
        reason: 'untrusted-content-cannot-authorize-actions',
      );
    }

    if (intent.risk == NazaIntentRisk.privateRead ||
        intent.risk == NazaIntentRisk.privateWrite) {
      if (!intent.explicitUserRequest) {
        return const NazaIntentDecision(
          allowed: false,
          freshAuthorizationRequired: false,
          reason: 'private-operation-requires-user-intent',
        );
      }
      return const NazaIntentDecision(
        allowed: true,
        freshAuthorizationRequired: false,
        reason: 'explicit-user-private-operation',
      );
    }

    if (intent.privilegedAction == null) {
      return const NazaIntentDecision(
        allowed: false,
        freshAuthorizationRequired: false,
        reason: 'privileged-action-missing',
      );
    }

    if (!intent.explicitUserRequest) {
      return const NazaIntentDecision(
        allowed: false,
        freshAuthorizationRequired: false,
        reason: 'privileged-operation-requires-explicit-user-intent',
      );
    }

    return NazaIntentDecision(
      allowed: false,
      freshAuthorizationRequired: true,
      reason: intent.risk == NazaIntentRisk.catastrophic
          ? 'catastrophic-operation-requires-fresh-authorization'
          : 'privileged-operation-requires-fresh-authorization',
    );
  }

  Future<void> authorizePrivileged({
    required NazaIntentDecision decision,
    required NazaProposedIntent intent,
    required NazaSecurityKernel kernel,
    required NazaCapabilityLease lease,
  }) async {
    if (!decision.freshAuthorizationRequired ||
        intent.privilegedAction == null) {
      throw const NazaIntentGuardException(
        'authorization_not_applicable',
        'This intent is not awaiting privileged authorization.',
      );
    }
    await kernel.consumeLease(
      lease,
      action: intent.privilegedAction!,
      resource: intent.resource,
    );
  }
}

final class NazaIntentGuardException implements Exception {
  final String code;
  final String message;

  const NazaIntentGuardException(this.code, this.message);

  @override
  String toString() => 'NazaIntentGuardException($code): $message';
}
