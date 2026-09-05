// LLM-CONTEXT:BEGIN
// FILE: test/agentic_coding_surface_test.dart
// ROLE: Verifies agentic coding policy, encrypted profiles, bounded evidence,
// entropy diagnostics, and the visual run boundary.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests must prove credentials stay out of public
// projections and repository/model actions remain bounded and approval-gated.
// CHANGE-GUARD: Do not weaken these assertions to accommodate unsafe state.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  group('agentic workspace policy', () {
    test('defaults to local Gemma and an immutable local safety boundary', () {
      const config = NazaAgenticWorkspaceConfig();
      expect(config.modelMode, NazaAgenticModelMode.localGemma);
      expect(config.activeNode.kind, NazaExecutionTargetKind.localWorkspace);
      expect(config.activeNode.enabled, isTrue);
      expect(config.memoryEnabled, isTrue);

      final malformed = NazaAgenticWorkspaceConfig.fromJson(<String, Object?>{
        'modelMode': 'unknown',
        'activeNodeId': 'evil-local',
        'maxContextBytes': 999999999,
        'maxFiles': -1,
        'nodes': <Object?>[
          <String, Object?>{
            'id': 'local-workspace',
            'name': 'weakened',
            'kind': 'localWorkspace',
            'enabled': false,
          },
          <String, Object?>{
            'id': 'evil-local',
            'name': 'replacement',
            'kind': 'remoteSsh',
            'host': 'node.example',
            'username': 'builder',
            // A remote node without a pinned host key is discarded.
          },
        ],
      });
      expect(malformed.modelMode, NazaAgenticModelMode.localGemma);
      expect(malformed.maxContextBytes, 512000);
      expect(malformed.maxFiles, 20);
      expect(malformed.activeNode.id, 'local-workspace');
      expect(malformed.activeNode.name, 'Local read-only workspace');
      expect(malformed.activeNode.enabled, isTrue);
      expect(malformed.nodes.any((node) => node.id == 'evil-local'), isFalse);
    });

    test('remote nodes require host-key pinning and expose no private key', () {
      final node = NazaAgenticNodeProfile.createRemote(
        id: 'build-node',
        name: 'Build Node',
        host: 'build.example.test',
        port: 2222,
        username: 'naza',
        hostKeySha256: 'SHA256:${List<String>.filled(43, 'A').join()}',
        workspaceRoot: '/srv/workspace',
        hasCredential: true,
      );
      final publicJson = jsonEncode(node.toPublicJson());
      expect(publicJson, contains('hostKeySha256'));
      expect(publicJson, isNot(contains('privateKey')));
      expect(publicJson, isNot(contains('BEGIN OPENSSH')));
      expect(
        () => NazaAgenticNodeProfile.createRemote(
          id: 'unpinned-node',
          name: 'Unpinned',
          host: 'build.example.test',
          port: 22,
          username: 'naza',
          hostKeySha256: '',
          workspaceRoot: '/srv/workspace',
        ),
        throwsFormatException,
      );
      expect(
        NazaAgenticNodeProfile.isImmutableContainerImage(
          'registry.example/sandbox@sha256:${List<String>.filled(64, 'a').join()}',
        ),
        isTrue,
      );
      expect(
        NazaAgenticNodeProfile.isImmutableContainerImage(
          'registry.example/sandbox:latest',
        ),
        isFalse,
      );
    });

    test('elevated checks and remote transport require per-run approval', () {
      final base = NazaAgenticTaskRequest.validated(
        task: 'Propose a focused parser patch.',
        modelMode: NazaAgenticModelMode.localGemma,
        modality: NazaAgenticModality.text,
        node: NazaAgenticNodeProfile.localDefault,
        permissions: const <NazaAgenticPermission>{
          NazaAgenticPermission.proposePatch,
        },
        mutationApproved: false,
        networkApproved: false,
        memoryEnabled: true,
      );
      expect(const NazaAgenticPolicyEngine().evaluate(base).canRun, isTrue);

      final checks = NazaAgenticTaskRequest.validated(
        task: base.task,
        modelMode: base.modelMode,
        modality: base.modality,
        node: base.node,
        permissions: const <NazaAgenticPermission>{
          NazaAgenticPermission.runChecks,
        },
        mutationApproved: false,
        networkApproved: false,
        memoryEnabled: true,
      );
      final decision = const NazaAgenticPolicyEngine().evaluate(checks);
      expect(decision.canRun, isFalse);
      expect(decision.requiresApproval, isTrue);
      expect(decision.approvals, isNotEmpty);
    });

    test('frontier-provider routing requires explicit network approval', () {
      final request = NazaAgenticTaskRequest.validated(
        task: 'Review a bounded parser change.',
        modelMode: NazaAgenticModelMode.routedProvider,
        modality: NazaAgenticModality.text,
        node: NazaAgenticNodeProfile.localDefault,
        permissions: const <NazaAgenticPermission>{
          NazaAgenticPermission.proposePatch,
        },
        mutationApproved: false,
        networkApproved: false,
        memoryEnabled: true,
      );

      final denied = const NazaAgenticPolicyEngine().evaluate(request);
      expect(denied.canRun, isFalse);
      expect(denied.requiresApproval, isTrue);

      final approved = const NazaAgenticPolicyEngine().evaluate(
        NazaAgenticTaskRequest.validated(
          task: request.task,
          modelMode: request.modelMode,
          modality: request.modality,
          node: request.node,
          permissions: request.permissions,
          mutationApproved: false,
          networkApproved: true,
          memoryEnabled: true,
        ),
      );
      expect(approved.canRun, isTrue);
    });
  });

  test(
    'SSH key material is encrypted at rest and separated from config',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-agentic-vault-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = NazaSecureDatabase.forTesting(directory);
      await database.create(password: 'test-password', passwordRequired: true);
      addTearDown(database.lock);
      final store = NazaAgenticWorkspaceStore(database: database);
      final keyBody = List<String>.filled(180, 'A').join();
      final privateKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n$keyBody\n-----END OPENSSH PRIVATE KEY-----';
      final node = NazaAgenticNodeProfile.createRemote(
        id: 'encrypted-node',
        name: 'Encrypted Node',
        host: '10.20.30.40',
        port: 22,
        username: 'builder',
        hostKeySha256: 'SHA256:${List<String>.filled(43, 'B').join()}',
        workspaceRoot: '/workspace',
        hasCredential: true,
      );
      await store.save(
        const NazaAgenticWorkspaceConfig().copyWith(
          nodes: <NazaAgenticNodeProfile>[
            NazaAgenticNodeProfile.localDefault,
            node,
          ],
          activeNodeId: node.id,
        ),
      );
      await store.saveSshPrivateKey(nodeId: node.id, privateKey: privateKey);

      expect(await store.hasSshPrivateKey(node.id), isTrue);
      expect(
        await store.withSshPrivateKey(
          node.id,
          (key) async => key == privateKey,
        ),
        isTrue,
      );
      final loaded = await store.load();
      expect(jsonEncode(loaded.toJson()), isNot(contains(keyBody)));

      for (final entity in await directory.list().toList()) {
        if (entity is! File) continue;
        final raw = String.fromCharCodes(await entity.readAsBytes());
        expect(raw, isNot(contains(keyBody)));
        expect(raw, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
      }
    },
  );

  test(
    'repository evidence is bounded, link-safe, and credential-redacted',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-agentic-repo-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      await Directory('${directory.path}/lib').create(recursive: true);
      final obviousSecret = 'sk-${List<String>.filled(30, 'x').join()}';
      await File('${directory.path}/lib/00_main.dart').writeAsString(
        "void main() { print('hello'); }\nconst token = '$obviousSecret';",
      );
      await File('${directory.path}/README.md').writeAsString('Safe overview');
      await File('${directory.path}/.env').writeAsString('PASSWORD=plaintext');
      await File('${directory.path}/id_ed25519').writeAsString(
        '-----BEGIN OPENSSH PRIVATE KEY-----\n${List<String>.filled(200, 'Q').join()}\n-----END OPENSSH PRIVATE KEY-----',
      );
      for (var index = 0; index < 28; index++) {
        await File('${directory.path}/lib/file_$index.dart').writeAsString(
          'String value$index = "${List<String>.filled(1800, 'a').join()}";',
        );
      }
      final outside = await File(
        '${directory.path}-outside.txt',
      ).writeAsString('outside-link-content');
      addTearDown(() async {
        if (await outside.exists()) await outside.delete();
      });
      try {
        await Link('${directory.path}/lib/outside.txt').create(outside.path);
      } on FileSystemException {
        // Some Windows test hosts disallow symlink creation for unprivileged
        // processes. The collector's no-follow behavior is exercised where the
        // platform permits creating this fixture.
      }

      final context = await const NazaRepositoryContextCollector().collect(
        directory.path,
        maxFiles: 20,
        maxBytes: 32000,
      );
      expect(context.files.length, lessThanOrEqualTo(20));
      expect(context.bytes, lessThanOrEqualTo(32000));
      expect(context.context, contains('00_main.dart'));
      expect(context.context, contains('[REDACTED_CREDENTIAL]'));
      expect(context.context, isNot(contains(obviousSecret)));
      expect(context.context, isNot(contains('PASSWORD=plaintext')));
      expect(context.context, isNot(contains('outside-link-content')));
      expect(context.truncated, isTrue);

      final request = NazaAgenticTaskRequest.validated(
        task: 'Review this repository.',
        modelMode: NazaAgenticModelMode.routedProvider,
        modality: NazaAgenticModality.repository,
        node: NazaAgenticNodeProfile.localDefault,
        permissions: const <NazaAgenticPermission>{
          NazaAgenticPermission.inspectRepository,
        },
        mutationApproved: false,
        networkApproved: false,
        memoryEnabled: true,
        repository: context,
      );
      expect(request.buildPrompt(), isNot(contains(directory.path)));
      expect(
        request.buildPrompt(),
        contains(directory.path.split(Platform.pathSeparator).last),
      );
    },
  );

  test(
    'entropy weave is deterministic, bounded, and surfaces disagreement',
    () {
      const weave = NazaEntropyWeave();
      const convergent = <NazaAgenticContribution>[
        NazaAgenticContribution(
          text: 'Parser validates bounded input and returns typed errors.',
          provider: 'A',
          model: 'one',
        ),
        NazaAgenticContribution(
          text: 'Parser validates bounded input and returns typed errors.',
          provider: 'B',
          model: 'two',
        ),
      ];
      const divergent = <NazaAgenticContribution>[
        NazaAgenticContribution(
          text: 'Parser grammar validation bounds typed syntax failures.',
          provider: 'A',
          model: 'one',
        ),
        NazaAgenticContribution(
          text: 'Neural image rendering schedules GPU texture batches.',
          provider: 'B',
          model: 'two',
        ),
      ];
      final first = weave.analyze(divergent, seed: 'task');
      final second = weave.analyze(divergent, seed: 'task');
      final same = weave.analyze(convergent, seed: 'task');
      expect(first.disagreement, greaterThan(same.disagreement));
      expect(first.circuitMean, second.circuitMean);
      expect(first.circuitMin, lessThanOrEqualTo(first.circuitMean));
      expect(first.circuitMax, greaterThanOrEqualTo(first.circuitMean));
      for (final value in <double>[
        first.disagreement,
        first.lexicalEntropy,
        first.trustConsensus,
        first.provenanceCoverage,
        first.anomalySurface,
        first.circuitMean,
        first.circuitMin,
        first.circuitMax,
      ]) {
        expect(value, inInclusiveRange(0, 1));
      }
    },
  );

  testWidgets('visual foundry compiles a local proposal and renders telemetry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NazaAgenticTaskRequest? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NazaAgenticCodingSurface(
            persistState: false,
            initialConfig: const NazaAgenticWorkspaceConfig(
              modality: NazaAgenticModality.text,
            ),
            runTask: (request) async {
              captured = request;
              return NazaAgenticRunResult.fromContributions(
                text:
                    '## Proposed patch\n\nKeep the change bounded and reversible.',
                contributions: const <NazaAgenticContribution>[
                  NazaAgenticContribution(
                    text: 'Keep the change bounded and reversible.',
                    provider: 'Local runtime',
                    model: 'Gemma 4 E2B',
                    trustWeight: 1,
                  ),
                ],
                taskSeed: request.task,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Agentic Code Foundry'), findsOneWidget);
    expect(find.text('Local Gemma'), findsOneWidget);

    final runButton = find.byKey(const ValueKey<String>('run-agentic-task'));
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.modelMode, NazaAgenticModelMode.localGemma);
    expect(captured!.mutationApproved, isFalse);
    expect(find.text('Proposed patch'), findsOneWidget);
    expect(find.text('PROVENANCE LATTICE'), findsOneWidget);
    expect(find.text('SHARD DISAGREEMENT'), findsOneWidget);
  });

  testWidgets('code foundry is a first-class application panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: NazaStableHome(
          initializeServices: false,
          initialPanel: NazaPanel.agenticCoding,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('agentic-code-foundry')),
      findsOneWidget,
    );
    expect(find.text('Agentic Code Foundry'), findsWidgets);
    await tester.tap(find.byTooltip('View and configure all features'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Code Foundry'), findsOneWidget);
    expect(find.text('EXECUTION INTELLIGENCE'), findsOneWidget);
    await tester.tap(find.text('Code Foundry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final foundry = find.byKey(const ValueKey<String>('agentic-code-foundry'));
    final remoteSection = find.descendant(
      of: foundry,
      matching: find.text('Remote operations control plane'),
    );
    await tester.scrollUntilVisible(
      remoteSection,
      520,
      scrollable: find
          .descendant(of: foundry, matching: find.byType(Scrollable))
          .first,
    );
    expect(remoteSection, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('request-scrape-ipfs-export')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('manage-digitalocean-droplet')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('code foundry remains scrollable at compact phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NazaAgenticCodingSurface(
            persistState: false,
            runTask: (request) async => NazaAgenticRunResult.fromContributions(
              text: 'Compact result',
              contributions: const <NazaAgenticContribution>[
                NazaAgenticContribution(
                  text: 'Compact result',
                  provider: 'Local runtime',
                  model: 'Gemma 4 E2B',
                ),
              ],
              taskSeed: request.task,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final runButton = find.byKey(const ValueKey<String>('run-agentic-task'));
    await tester.ensureVisible(runButton);
    await tester.pump();
    expect(runButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
