import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

/// A first-class software-reality state engine for agentic coding.
///
/// The model is deliberately not the authority. Models, repository scans,
/// tests, traces, people, benchmarks and external systems all contribute
/// evidence to an epistemic graph. Competing software futures remain alive
/// until the collapse policy has enough evidence, invariant proof and
/// reversibility to select one.
enum NazaEvidenceKind {
  repository,
  staticAnalysis,
  test,
  benchmark,
  runtimeTrace,
  specification,
  humanObservation,
  modelContribution,
  externalSource,
}

enum NazaClaimStatus { active, challenged, invalidated }

enum NazaTemporalHorizon { immediate, nextRelease, longTerm }

enum NazaInvariantSeverity { advisory, important, critical }

enum NazaExperimentCapability { readOnly, mutation, network, remoteExecution }

enum NazaProofKind {
  test,
  property,
  staticAnalysis,
  benchmark,
  compatibility,
  threatAnalysis,
  rollback,
  runtimeTrace,
}

final class NazaRealityEvidence {
  const NazaRealityEvidence({
    required this.id,
    required this.kind,
    required this.summary,
    required this.digest,
    required this.reliability,
    required this.observedAt,
    this.source = '',
  });

  final String id;
  final NazaEvidenceKind kind;
  final String summary;
  final String digest;
  final double reliability;
  final DateTime observedAt;
  final String source;

  factory NazaRealityEvidence.observed({
    required String id,
    required NazaEvidenceKind kind,
    required String summary,
    required String material,
    double reliability = 0.8,
    String source = '',
    DateTime? observedAt,
  }) {
    final cleanId = _id(id);
    final boundedMaterial = material.length <= 120000
        ? material
        : material.substring(0, 120000);
    return NazaRealityEvidence(
      id: cleanId,
      kind: kind,
      summary: _text(summary, 1800),
      digest: crypto.sha256.convert(utf8.encode(boundedMaterial)).toString(),
      reliability: _unit(reliability),
      observedAt: (observedAt ?? DateTime.now()).toUtc(),
      source: _text(source, 240),
    );
  }
}

final class NazaEpistemicClaim {
  const NazaEpistemicClaim({
    required this.id,
    required this.proposition,
    this.priorWeight = 0.5,
    this.evidenceWeights = const <String, double>{},
    this.parentClaimIds = const <String>[],
    this.contradictionClaimIds = const <String>[],
    this.impact = 0.5,
    this.status = NazaClaimStatus.active,
  });

  final String id;
  final String proposition;
  final double priorWeight;
  final Map<String, double> evidenceWeights;
  final List<String> parentClaimIds;
  final List<String> contradictionClaimIds;
  final double impact;
  final NazaClaimStatus status;
}

final class NazaSoftwareInvariant {
  const NazaSoftwareInvariant({
    required this.id,
    required this.statement,
    required this.severity,
    this.proofArtifactIds = const <String>[],
  });

  final String id;
  final String statement;
  final NazaInvariantSeverity severity;
  final List<String> proofArtifactIds;
}

final class NazaSemanticTransform {
  const NazaSemanticTransform({
    required this.id,
    required this.intent,
    required this.affectedPaths,
    required this.inverseDescription,
    required this.reversible,
    this.invariantIds = const <String>[],
  });

  final String id;
  final String intent;
  final List<String> affectedPaths;
  final List<String> invariantIds;
  final String inverseDescription;
  final bool reversible;
}

final class NazaSoftwareFuture {
  const NazaSoftwareFuture({
    required this.id,
    required this.label,
    required this.thesis,
    this.supportingClaimIds = const <String>[],
    this.transformIds = const <String>[],
    this.invariantIds = const <String>[],
    this.horizonScores = const <NazaTemporalHorizon, double>{},
    this.securityScore = 0.5,
    this.reversibilityScore = 0.5,
    this.complexityCost = 0.5,
    this.baseWeight = 1,
  });

  final String id;
  final String label;
  final String thesis;
  final List<String> supportingClaimIds;
  final List<String> transformIds;
  final List<String> invariantIds;
  final Map<NazaTemporalHorizon, double> horizonScores;
  final double securityScore;
  final double reversibilityScore;
  final double complexityCost;
  final double baseWeight;
}

final class NazaExperiment {
  const NazaExperiment({
    required this.id,
    required this.title,
    required this.discriminatesClaimIds,
    required this.capability,
    required this.cost,
  });

  final String id;
  final String title;
  final List<String> discriminatesClaimIds;
  final NazaExperimentCapability capability;
  final double cost;
}

final class NazaExperimentPriority {
  const NazaExperimentPriority({
    required this.experiment,
    required this.expectedInformationGain,
    required this.score,
  });

  final NazaExperiment experiment;
  final double expectedInformationGain;
  final double score;
}

final class NazaReasonerTrace {
  const NazaReasonerTrace({
    required this.id,
    required this.provider,
    required this.model,
    required this.ancestryDigest,
    required this.claimIds,
  });

  final String id;
  final String provider;
  final String model;
  final String ancestryDigest;
  final List<String> claimIds;
}

final class NazaAgentTrustProfile {
  const NazaAgentTrustProfile({
    required this.identity,
    this.correct = 0,
    this.incorrect = 0,
  });

  final String identity;
  final int correct;
  final int incorrect;

  double get empiricalReliability => (correct + 1) / (correct + incorrect + 2);

  NazaAgentTrustProfile record(bool survivedVerification) =>
      NazaAgentTrustProfile(
        identity: identity,
        correct: correct + (survivedVerification ? 1 : 0),
        incorrect: incorrect + (survivedVerification ? 0 : 1),
      );
}

final class NazaProofArtifact {
  const NazaProofArtifact({
    required this.id,
    required this.kind,
    required this.summary,
    required this.digest,
    required this.passed,
  });

  final String id;
  final NazaProofKind kind;
  final String summary;
  final String digest;
  final bool passed;

  factory NazaProofArtifact.fromMaterial({
    required String id,
    required NazaProofKind kind,
    required String summary,
    required String material,
    required bool passed,
  }) => NazaProofArtifact(
    id: _id(id),
    kind: kind,
    summary: _text(summary, 1600),
    digest: crypto.sha256.convert(utf8.encode(material)).toString(),
    passed: passed,
  );
}

final class NazaAgentRole {
  const NazaAgentRole({
    required this.id,
    required this.mandate,
    required this.adversarialGoal,
  });

  final String id;
  final String mandate;
  final String adversarialGoal;
}

final class NazaSyntheticOrganization {
  const NazaSyntheticOrganization({required this.id, required this.roles});

  final String id;
  final List<NazaAgentRole> roles;
}

final class NazaToolGenesisRequest {
  const NazaToolGenesisRequest({
    required this.id,
    required this.purpose,
    required this.expectedInformationGain,
  });

  final String id;
  final String purpose;
  final double expectedInformationGain;
}

final class NazaFutureWeight {
  const NazaFutureWeight({
    required this.future,
    required this.rawScore,
    required this.normalizedWeight,
  });

  final NazaSoftwareFuture future;
  final double rawScore;
  final double normalizedWeight;
}

final class NazaCollapseDecision {
  const NazaCollapseDecision({
    required this.allowed,
    required this.selectedFutureId,
    required this.fieldEntropy,
    required this.margin,
    required this.blockers,
    required this.weights,
  });

  final bool allowed;
  final String? selectedFutureId;
  final double fieldEntropy;
  final double margin;
  final List<String> blockers;
  final List<NazaFutureWeight> weights;
}

final class NazaProofCarryingPatch {
  const NazaProofCarryingPatch({
    required this.futureId,
    required this.unifiedDiff,
    required this.rollbackPlan,
    required this.proofArtifactIds,
    required this.unresolvedClaimIds,
    required this.digest,
    required this.reviewRequired,
  });

  final String futureId;
  final String unifiedDiff;
  final String rollbackPlan;
  final List<String> proofArtifactIds;
  final List<String> unresolvedClaimIds;
  final String digest;
  final bool reviewRequired;
}

final class NazaRealitySession {
  const NazaRealitySession({
    required this.id,
    required this.intent,
    required this.repositoryFingerprint,
    required this.createdAt,
    this.evidence = const <String, NazaRealityEvidence>{},
    this.claims = const <String, NazaEpistemicClaim>{},
    this.invariants = const <String, NazaSoftwareInvariant>{},
    this.transforms = const <String, NazaSemanticTransform>{},
    this.futures = const <String, NazaSoftwareFuture>{},
    this.experiments = const <String, NazaExperiment>{},
    this.reasoners = const <NazaReasonerTrace>[],
    this.trust = const <String, NazaAgentTrustProfile>{},
    this.proofs = const <String, NazaProofArtifact>{},
    this.invalidatedEvidence = const <String>{},
  });

  final String id;
  final String intent;
  final String repositoryFingerprint;
  final DateTime createdAt;
  final Map<String, NazaRealityEvidence> evidence;
  final Map<String, NazaEpistemicClaim> claims;
  final Map<String, NazaSoftwareInvariant> invariants;
  final Map<String, NazaSemanticTransform> transforms;
  final Map<String, NazaSoftwareFuture> futures;
  final Map<String, NazaExperiment> experiments;
  final List<NazaReasonerTrace> reasoners;
  final Map<String, NazaAgentTrustProfile> trust;
  final Map<String, NazaProofArtifact> proofs;
  final Set<String> invalidatedEvidence;

  NazaRealitySession copyWith({
    Map<String, NazaRealityEvidence>? evidence,
    Map<String, NazaEpistemicClaim>? claims,
    Map<String, NazaSoftwareInvariant>? invariants,
    Map<String, NazaSemanticTransform>? transforms,
    Map<String, NazaSoftwareFuture>? futures,
    Map<String, NazaExperiment>? experiments,
    List<NazaReasonerTrace>? reasoners,
    Map<String, NazaAgentTrustProfile>? trust,
    Map<String, NazaProofArtifact>? proofs,
    Set<String>? invalidatedEvidence,
  }) => NazaRealitySession(
    id: id,
    intent: intent,
    repositoryFingerprint: repositoryFingerprint,
    createdAt: createdAt,
    evidence: Map<String, NazaRealityEvidence>.unmodifiable(
      evidence ?? this.evidence,
    ),
    claims: Map<String, NazaEpistemicClaim>.unmodifiable(claims ?? this.claims),
    invariants: Map<String, NazaSoftwareInvariant>.unmodifiable(
      invariants ?? this.invariants,
    ),
    transforms: Map<String, NazaSemanticTransform>.unmodifiable(
      transforms ?? this.transforms,
    ),
    futures: Map<String, NazaSoftwareFuture>.unmodifiable(
      futures ?? this.futures,
    ),
    experiments: Map<String, NazaExperiment>.unmodifiable(
      experiments ?? this.experiments,
    ),
    reasoners: List<NazaReasonerTrace>.unmodifiable(
      reasoners ?? this.reasoners,
    ),
    trust: Map<String, NazaAgentTrustProfile>.unmodifiable(trust ?? this.trust),
    proofs: Map<String, NazaProofArtifact>.unmodifiable(proofs ?? this.proofs),
    invalidatedEvidence: Set<String>.unmodifiable(
      invalidatedEvidence ?? this.invalidatedEvidence,
    ),
  );
}

final class NazaSoftwareRealityCompiler {
  const NazaSoftwareRealityCompiler();

  NazaRealitySession begin({
    required String intent,
    String repositoryFingerprint = '',
    String? id,
    DateTime? now,
  }) {
    final clean = _text(intent, 12000);
    if (clean.isEmpty) {
      throw const FormatException('A software intent is required.');
    }
    final created = (now ?? DateTime.now()).toUtc();
    final seed = '$clean|$repositoryFingerprint|${created.toIso8601String()}';
    return NazaRealitySession(
      id: id == null
          ? 'reality-${crypto.sha256.convert(utf8.encode(seed)).toString().substring(0, 16)}'
          : _id(id),
      intent: clean,
      repositoryFingerprint: _text(repositoryFingerprint, 128),
      createdAt: created,
    );
  }

  NazaRealitySession observe(
    NazaRealitySession session,
    NazaRealityEvidence observation,
  ) => session.copyWith(
    evidence: <String, NazaRealityEvidence>{
      ...session.evidence,
      observation.id: observation,
    },
  );

  NazaRealitySession assertClaim(
    NazaRealitySession session,
    NazaEpistemicClaim claim,
  ) => session.copyWith(
    claims: <String, NazaEpistemicClaim>{...session.claims, claim.id: claim},
  );

  NazaRealitySession addInvariant(
    NazaRealitySession session,
    NazaSoftwareInvariant invariant,
  ) => session.copyWith(
    invariants: <String, NazaSoftwareInvariant>{
      ...session.invariants,
      invariant.id: invariant,
    },
  );

  NazaRealitySession addTransform(
    NazaRealitySession session,
    NazaSemanticTransform transform,
  ) => session.copyWith(
    transforms: <String, NazaSemanticTransform>{
      ...session.transforms,
      transform.id: transform,
    },
  );

  NazaRealitySession addFuture(
    NazaRealitySession session,
    NazaSoftwareFuture future,
  ) => session.copyWith(
    futures: <String, NazaSoftwareFuture>{
      ...session.futures,
      future.id: future,
    },
  );

  NazaRealitySession addExperiment(
    NazaRealitySession session,
    NazaExperiment experiment,
  ) => session.copyWith(
    experiments: <String, NazaExperiment>{
      ...session.experiments,
      experiment.id: experiment,
    },
  );

  NazaRealitySession addReasoner(
    NazaRealitySession session,
    NazaReasonerTrace reasoner,
  ) => session.copyWith(
    reasoners: <NazaReasonerTrace>[
      ...session.reasoners,
      reasoner,
    ].take(64).toList(),
  );

  NazaRealitySession addProof(
    NazaRealitySession session,
    NazaProofArtifact proof,
  ) => session.copyWith(
    proofs: <String, NazaProofArtifact>{...session.proofs, proof.id: proof},
  );

  NazaRealitySession recordTrust(
    NazaRealitySession session, {
    required String identity,
    required bool survivedVerification,
  }) {
    final profile =
        session.trust[identity] ?? NazaAgentTrustProfile(identity: identity);
    return session.copyWith(
      trust: <String, NazaAgentTrustProfile>{
        ...session.trust,
        identity: profile.record(survivedVerification),
      },
    );
  }

  double claimWeight(NazaRealitySession session, String claimId) {
    return _claimWeight(session, claimId, <String>{});
  }

  double _claimWeight(
    NazaRealitySession session,
    String claimId,
    Set<String> visiting,
  ) {
    final claim = session.claims[claimId];
    if (claim == null || claim.status == NazaClaimStatus.invalidated) return 0;
    if (!visiting.add(claimId)) return _unit(claim.priorWeight * 0.5);

    var support = 0.0;
    var mass = 0.0;
    for (final entry in claim.evidenceWeights.entries) {
      if (session.invalidatedEvidence.contains(entry.key)) continue;
      final evidence = session.evidence[entry.key];
      if (evidence == null) continue;
      support += entry.value.clamp(-1.0, 1.0) * evidence.reliability;
      mass += evidence.reliability;
    }

    final evidenceSignal = mass == 0 ? 0.0 : support / mass;
    final parents = claim.parentClaimIds
        .map((id) => _claimWeight(session, id, visiting))
        .toList(growable: false);
    final parentSignal = parents.isEmpty
        ? 1.0
        : parents.reduce((a, b) => a + b) / parents.length;

    final contradictions = claim.contradictionClaimIds
        .map((id) => _claimWeight(session, id, visiting))
        .toList(growable: false);
    final contradictionPenalty = contradictions.isEmpty
        ? 0.0
        : contradictions.reduce(math.max) * 0.55;

    visiting.remove(claimId);

    return _unit(
      claim.priorWeight * 0.36 +
          ((evidenceSignal + 1) / 2) * 0.44 +
          parentSignal * 0.20 -
          contradictionPenalty -
          (claim.status == NazaClaimStatus.challenged ? 0.12 : 0),
    );
  }

  List<NazaExperimentPriority> rankExperiments(
    NazaRealitySession session, {
    Set<NazaExperimentCapability> allowedCapabilities =
        const <NazaExperimentCapability>{NazaExperimentCapability.readOnly},
  }) {
    final ranked = <NazaExperimentPriority>[];
    for (final experiment in session.experiments.values) {
      if (!allowedCapabilities.contains(experiment.capability)) continue;
      final claims = experiment.discriminatesClaimIds
          .map((id) => session.claims[id])
          .whereType<NazaEpistemicClaim>()
          .toList(growable: false);
      if (claims.isEmpty) continue;

      final uncertainty =
          claims
              .map((claim) => _binaryEntropy(claimWeight(session, claim.id)))
              .reduce((a, b) => a + b) /
          claims.length;
      final impact =
          claims.map((c) => c.impact).reduce((a, b) => a + b) / claims.length;
      final gain = _unit(uncertainty * (0.4 + impact * 0.6));
      final cost = math.max(0.05, experiment.cost);

      ranked.add(
        NazaExperimentPriority(
          experiment: experiment,
          expectedInformationGain: gain,
          score: _unit(gain / (gain + cost)),
        ),
      );
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return List<NazaExperimentPriority>.unmodifiable(ranked);
  }

  List<NazaFutureWeight> evaluateFutures(NazaRealitySession session) {
    if (session.futures.isEmpty) return const <NazaFutureWeight>[];

    final futures = session.futures.values.toList(growable: false);
    final rawScores = <double>[];

    for (final future in futures) {
      final claimScores = future.supportingClaimIds
          .map((id) => claimWeight(session, id))
          .toList(growable: false);

      final evidenceSupport = claimScores.isEmpty
          ? 0.5
          : claimScores.reduce((a, b) => a + b) / claimScores.length;

      final temporal =
          NazaTemporalHorizon.values
              .map((h) => _unit(future.horizonScores[h] ?? 0.5))
              .reduce((a, b) => a + b) /
          NazaTemporalHorizon.values.length;

      final invariantCoverage = future.invariantIds.isEmpty
          ? 0.5
          : future.invariantIds.where(session.invariants.containsKey).length /
                future.invariantIds.length;

      rawScores.add(
        math.max(
          0.000001,
          (evidenceSupport * 0.34 +
                  temporal * 0.18 +
                  invariantCoverage * 0.16 +
                  _unit(future.securityScore) * 0.14 +
                  _unit(future.reversibilityScore) * 0.12 +
                  (1 - _unit(future.complexityCost)) * 0.06) *
              math.max(0.05, future.baseWeight),
        ),
      );
    }

    const temperature = 0.22;
    final maxScore = rawScores.reduce(math.max);
    final exponentials = rawScores
        .map((score) => math.exp((score - maxScore) / temperature))
        .toList(growable: false);
    final total = exponentials.reduce((a, b) => a + b);

    final weighted = <NazaFutureWeight>[];
    for (var i = 0; i < futures.length; i++) {
      weighted.add(
        NazaFutureWeight(
          future: futures[i],
          rawScore: rawScores[i],
          normalizedWeight: exponentials[i] / total,
        ),
      );
    }
    weighted.sort((a, b) => b.normalizedWeight.compareTo(a.normalizedWeight));
    return List<NazaFutureWeight>.unmodifiable(weighted);
  }

  double fieldEntropy(NazaRealitySession session) {
    final weights = evaluateFutures(session);
    if (weights.length < 2) return 0;
    var entropy = 0.0;
    for (final item in weights) {
      final p = item.normalizedWeight;
      entropy -= p * math.log(p) / math.ln2;
    }
    final maxEntropy = math.log(weights.length) / math.ln2;
    return _unit(entropy / maxEntropy);
  }

  NazaCollapseDecision collapse(
    NazaRealitySession session, {
    double minimumWeight = 0.60,
    double minimumMargin = 0.16,
  }) {
    final weights = evaluateFutures(session);
    if (weights.isEmpty) {
      return const NazaCollapseDecision(
        allowed: false,
        selectedFutureId: null,
        fieldEntropy: 0,
        margin: 0,
        blockers: <String>['No candidate software futures exist.'],
        weights: <NazaFutureWeight>[],
      );
    }

    final winner = weights.first;
    final runnerUp = weights.length > 1 ? weights[1].normalizedWeight : 0.0;
    final margin = winner.normalizedWeight - runnerUp;
    final blockers = <String>[];

    if (winner.normalizedWeight < minimumWeight) {
      blockers.add('No future has enough evidence weight to collapse.');
    }
    if (weights.length > 1 && margin < minimumMargin) {
      blockers.add(
        'Competing futures remain too close; acquire discriminating evidence.',
      );
    }

    for (final claimId in winner.future.supportingClaimIds) {
      final claim = session.claims[claimId];
      if (claim != null &&
          claim.impact >= 0.75 &&
          claimWeight(session, claimId) < 0.58) {
        blockers.add('High-impact claim "$claimId" remains unresolved.');
      }
    }

    for (final invariantId in winner.future.invariantIds) {
      final invariant = session.invariants[invariantId];
      if (invariant == null ||
          invariant.severity != NazaInvariantSeverity.critical) {
        continue;
      }
      final hasPassingProof = invariant.proofArtifactIds
          .map((id) => session.proofs[id])
          .whereType<NazaProofArtifact>()
          .any((proof) => proof.passed);
      if (!hasPassingProof) {
        blockers.add('Critical invariant "$invariantId" has no passing proof.');
      }
    }

    for (final transformId in winner.future.transformIds) {
      final transform = session.transforms[transformId];
      if (transform != null && !transform.reversible) {
        blockers.add(
          'Transform "$transformId" is irreversible under current policy.',
        );
      }
    }

    return NazaCollapseDecision(
      allowed: blockers.isEmpty,
      selectedFutureId: blockers.isEmpty ? winner.future.id : null,
      fieldEntropy: fieldEntropy(session),
      margin: _unit(margin),
      blockers: List<String>.unmodifiable(blockers),
      weights: weights,
    );
  }

  NazaProofCarryingPatch issuePatch(
    NazaRealitySession session, {
    required NazaCollapseDecision decision,
    required String unifiedDiff,
    required String rollbackPlan,
  }) {
    if (!decision.allowed || decision.selectedFutureId == null) {
      throw StateError(
        'The state field has not crossed the collapse boundary.',
      );
    }
    final future = session.futures[decision.selectedFutureId]!;
    final diff = unifiedDiff.trim();
    final rollback = rollbackPlan.trim();

    if (diff.isEmpty) {
      throw const FormatException('A unified diff is required.');
    }
    if (rollback.isEmpty) {
      throw const FormatException('A rollback plan is required.');
    }

    final proofIds = <String>{};
    for (final invariantId in future.invariantIds) {
      proofIds.addAll(
        session.invariants[invariantId]?.proofArtifactIds ?? const <String>[],
      );
    }

    final unresolved = future.supportingClaimIds
        .where((id) => claimWeight(session, id) < 0.68)
        .toList(growable: false);

    final digestMaterial = <String>[
      future.id,
      diff,
      rollback,
      ...proofIds,
      ...unresolved,
    ].join('\n');

    return NazaProofCarryingPatch(
      futureId: future.id,
      unifiedDiff: diff,
      rollbackPlan: rollback,
      proofArtifactIds: List<String>.unmodifiable(proofIds),
      unresolvedClaimIds: List<String>.unmodifiable(unresolved),
      digest: crypto.sha256.convert(utf8.encode(digestMaterial)).toString(),
      reviewRequired: unresolved.isNotEmpty || decision.fieldEntropy > 0.55,
    );
  }

  double independentReasonerCoverage(NazaRealitySession session) {
    if (session.reasoners.isEmpty) return 0;
    final independent = session.reasoners
        .map((r) => r.ancestryDigest)
        .toSet()
        .length;
    return _unit(independent / session.reasoners.length);
  }

  NazaSyntheticOrganization spawnOrganization(String task) {
    final lower = task.toLowerCase();
    final roles = <NazaAgentRole>[
      const NazaAgentRole(
        id: 'builder',
        mandate: 'Construct the smallest coherent candidate future.',
        adversarialGoal: 'Reject unnecessary breadth.',
      ),
      const NazaAgentRole(
        id: 'breaker',
        mandate: 'Search for counterexamples and failure paths.',
        adversarialGoal: 'Disprove optimistic assumptions.',
      ),
      const NazaAgentRole(
        id: 'verifier',
        mandate: 'Demand experiments that discriminate competing futures.',
        adversarialGoal: 'Reject consensus without independent evidence.',
      ),
      const NazaAgentRole(
        id: 'historian',
        mandate: 'Recover why current constraints exist.',
        adversarialGoal: 'Prevent resurrection of previously fixed failures.',
      ),
    ];

    if (_containsAny(lower, const <String>[
      'auth',
      'secret',
      'crypto',
      'security',
      'permission',
    ])) {
      roles.add(
        const NazaAgentRole(
          id: 'security-adversary',
          mandate: 'Trace privilege, trust and attacker-controlled flows.',
          adversarialGoal:
              'Find an exploit path or prove the boundary blocks it.',
        ),
      );
    }

    if (_containsAny(lower, const <String>[
      'database',
      'schema',
      'migration',
      'sql',
      'storage',
    ])) {
      roles.add(
        const NazaAgentRole(
          id: 'data-guardian',
          mandate: 'Protect schema compatibility and durability.',
          adversarialGoal: 'Find data-loss and irreversible migration states.',
        ),
      );
    }

    if (_containsAny(lower, const <String>[
      'flutter',
      'widget',
      'ui',
      'render',
      'accessibility',
    ])) {
      roles.add(
        const NazaAgentRole(
          id: 'interaction-critic',
          mandate: 'Inspect visible behavior and state transitions.',
          adversarialGoal: 'Find UI states the implementation forgot.',
        ),
      );
    }

    return NazaSyntheticOrganization(
      id: 'org-${crypto.sha256.convert(utf8.encode(task)).toString().substring(0, 12)}',
      roles: List<NazaAgentRole>.unmodifiable(roles),
    );
  }

  List<NazaToolGenesisRequest> proposeTools(NazaRealitySession session) {
    final uncertainHighImpact = session.claims.values
        .where((claim) {
          return claim.impact >= 0.65 &&
              _binaryEntropy(claimWeight(session, claim.id)) >= 0.75;
        })
        .toList(growable: false);

    if (uncertainHighImpact.isEmpty) {
      return const <NazaToolGenesisRequest>[];
    }

    final averageGain =
        uncertainHighImpact
            .map((c) => _binaryEntropy(claimWeight(session, c.id)))
            .reduce((a, b) => a + b) /
        uncertainHighImpact.length;

    return <NazaToolGenesisRequest>[
      NazaToolGenesisRequest(
        id: 'causal-probe',
        purpose:
            'Generate a disposable read-only probe for high-impact uncertainty.',
        expectedInformationGain: _unit(averageGain),
      ),
    ];
  }
}

bool _containsAny(String value, Iterable<String> needles) =>
    needles.any(value.contains);

double _binaryEntropy(double p) {
  final q = p.clamp(0.000001, 0.999999).toDouble();
  return _unit(
    -q * math.log(q) / math.ln2 - (1 - q) * math.log(1 - q) / math.ln2,
  );
}

double _unit(double value) =>
    value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0;

String _id(String value) {
  final clean = value.trim();
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,95}$').hasMatch(clean)) {
    throw const FormatException('Identifier is malformed.');
  }
  return clean;
}

String _text(String value, int max) {
  final clean = value.replaceAll(RegExp(r'[\u0000-\u001f]'), ' ').trim();
  if (clean.isEmpty) return '';
  return clean.length <= max ? clean : clean.substring(0, max);
}
