import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  const compiler = NazaSoftwareRealityCompiler();

  test('delays collapse while futures remain nearly degenerate', () {
    var session = compiler.begin(
      intent: 'Fix parser ambiguity.',
      id: 'reality-test',
      now: DateTime.utc(2026, 8, 23),
    );

    session = compiler.assertClaim(
      session,
      const NazaEpistemicClaim(
        id: 'a',
        proposition: 'Lookahead is wrong.',
        impact: 0.9,
      ),
    );
    session = compiler.assertClaim(
      session,
      const NazaEpistemicClaim(
        id: 'b',
        proposition: 'AST normalization is wrong.',
        impact: 0.9,
      ),
    );

    session = compiler.addFuture(
      session,
      const NazaSoftwareFuture(
        id: 'fa',
        label: 'Lookahead',
        thesis: 'Repair lookahead.',
        supportingClaimIds: <String>['a'],
      ),
    );
    session = compiler.addFuture(
      session,
      const NazaSoftwareFuture(
        id: 'fb',
        label: 'AST normalization',
        thesis: 'Repair normalization.',
        supportingClaimIds: <String>['b'],
      ),
    );

    final decision = compiler.collapse(session);
    expect(decision.allowed, isFalse);
    expect(decision.fieldEntropy, greaterThan(0.9));
  });

  test('prioritizes informative permitted experiments', () {
    var session = compiler.begin(
      intent: 'Resolve concurrency defect.',
      id: 'experiment-test',
      now: DateTime.utc(2026, 8, 23),
    );
    session = compiler.assertClaim(
      session,
      const NazaEpistemicClaim(
        id: 'race',
        proposition: 'Two handlers can mutate the same record.',
        impact: 1,
      ),
    );
    session = compiler.addExperiment(
      session,
      const NazaExperiment(
        id: 'trace',
        title: 'Capture ordering',
        discriminatesClaimIds: <String>['race'],
        capability: NazaExperimentCapability.readOnly,
        cost: 0.1,
      ),
    );
    session = compiler.addExperiment(
      session,
      const NazaExperiment(
        id: 'remote',
        title: 'Probe remote production',
        discriminatesClaimIds: <String>['race'],
        capability: NazaExperimentCapability.remoteExecution,
        cost: 0.01,
      ),
    );

    final ranked = compiler.rankExperiments(session);
    expect(ranked, hasLength(1));
    expect(ranked.single.experiment.id, 'trace');
  });

  test('critical invariant proof gates collapse', () {
    var session = compiler.begin(
      intent: 'Harden invoice authorization.',
      id: 'proof-test',
      now: DateTime.utc(2026, 8, 23),
    );

    session = compiler.observe(
      session,
      NazaRealityEvidence.observed(
        id: 'repo',
        kind: NazaEvidenceKind.repository,
        summary: 'Ownership check is missing at canonical boundary.',
        material: 'missing ownership check',
        reliability: 1,
        observedAt: DateTime.utc(2026, 8, 23),
      ),
    );

    session = compiler.assertClaim(
      session,
      const NazaEpistemicClaim(
        id: 'ownership',
        proposition: 'Canonical auth boundary lacks ownership enforcement.',
        priorWeight: 0.95,
        evidenceWeights: <String, double>{'repo': 1},
        impact: 1,
      ),
    );

    session = compiler.addInvariant(
      session,
      const NazaSoftwareInvariant(
        id: 'owner-only',
        statement: 'Users never read another users invoice.',
        severity: NazaInvariantSeverity.critical,
        proofArtifactIds: <String>['proof-owner'],
      ),
    );

    session = compiler.addTransform(
      session,
      const NazaSemanticTransform(
        id: 'auth-boundary',
        intent: 'Move ownership enforcement to canonical auth boundary.',
        affectedPaths: <String>['lib/auth.dart'],
        inverseDescription: 'Restore previous authorization predicate.',
        reversible: true,
        invariantIds: <String>['owner-only'],
      ),
    );

    session = compiler.addFuture(
      session,
      const NazaSoftwareFuture(
        id: 'secure-future',
        label: 'Boundary enforcement',
        thesis: 'Enforce ownership once at the authority boundary.',
        supportingClaimIds: <String>['ownership'],
        transformIds: <String>['auth-boundary'],
        invariantIds: <String>['owner-only'],
        securityScore: 1,
        reversibilityScore: 1,
        complexityCost: 0.05,
      ),
    );

    expect(
      compiler.collapse(session, minimumWeight: 0.5, minimumMargin: 0).allowed,
      isFalse,
    );

    session = compiler.addProof(
      session,
      NazaProofArtifact.fromMaterial(
        id: 'proof-owner',
        kind: NazaProofKind.property,
        summary: 'Cross-owner access rejected.',
        material: 'property passed',
        passed: true,
      ),
    );

    final decision = compiler.collapse(
      session,
      minimumWeight: 0.5,
      minimumMargin: 0,
    );
    expect(decision.allowed, isTrue);

    final patch = compiler.issuePatch(
      session,
      decision: decision,
      unifiedDiff: '+ requireOwner(invoice.ownerId, user.id);',
      rollbackPlan: 'Revert the authorization predicate.',
    );
    expect(patch.digest, hasLength(64));
    expect(patch.proofArtifactIds, contains('proof-owner'));
  });

  test('correlated reasoners do not count as independent confirmation', () {
    var session = compiler.begin(
      intent: 'Review change.',
      id: 'reasoner-test',
      now: DateTime.utc(2026, 8, 23),
    );

    session = compiler.addReasoner(
      session,
      const NazaReasonerTrace(
        id: 'r1',
        provider: 'A',
        model: 'one',
        ancestryDigest: 'same-context',
        claimIds: <String>['x'],
      ),
    );
    session = compiler.addReasoner(
      session,
      const NazaReasonerTrace(
        id: 'r2',
        provider: 'B',
        model: 'two',
        ancestryDigest: 'same-context',
        claimIds: <String>['x'],
      ),
    );

    expect(compiler.independentReasonerCoverage(session), 0.5);
  });

  test('synthetic organization adapts to task surface', () {
    final org = compiler.spawnOrganization(
      'Harden Flutter auth UI and database migration.',
    );
    final ids = org.roles.map((r) => r.id).toSet();
    expect(ids, contains('security-adversary'));
    expect(ids, contains('data-guardian'));
    expect(ids, contains('interaction-critic'));
    expect(ids, contains('breaker'));
  });
}
