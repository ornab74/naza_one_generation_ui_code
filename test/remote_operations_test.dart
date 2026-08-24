// LLM-CONTEXT:BEGIN
// FILE: test/remote_operations_test.dart
// ROLE: Verifies bounded remote infrastructure, scraping, and IPFS plans.
// SECURITY-INVARIANT: Plans contain no provider credentials and reject unsafe
// URLs, mutable worker images, and implicit public exposure.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/agentic/remote_operations.dart';
import 'package:naza_one/security/probabilistic_harm_filter.dart';
import 'package:naza_one/security/secure_database.dart';

import 'support/harm_test_support.dart';

void main() {
  test('DigitalOcean plan matches create payload without credentials', () {
    const plan = NazaDigitalOceanDropletPlan(
      name: 'agentic-worker',
      region: 'nyc3',
      size: 's-1vcpu-2gb',
      image: 'ubuntu-24-04-x64',
      sshKeyRefs: <String>['289794', 'SHA256:fingerprint'],
      tags: <String>['naza-agentic', 'ephemeral'],
      monitoring: true,
    );
    expect(plan.validate(), isEmpty);
    final payload = plan.toApiPayload();
    expect(payload['name'], 'agentic-worker');
    expect(payload['region'], 'nyc3');
    expect(payload['size'], 's-1vcpu-2gb');
    expect(payload['image'], 'ubuntu-24-04-x64');
    expect(payload['ssh_keys'], <Object?>[289794, 'SHA256:fingerprint']);
    expect(jsonEncode(payload), isNot(contains('token')));
    expect(jsonEncode(payload), isNot(contains('Bearer')));
  });

  test('Chromium scrape requires HTTPS, domain allowlist, and digest pin', () {
    final validImage =
        'ghcr.io/ornab74/scraper-chrome-docker@sha256:${List<String>.filled(64, 'a').join()}';
    final valid = NazaChromiumScrapePlan(
      targetUrl: 'https://docs.example.org/start',
      allowedDomains: const <String>['example.org'],
      workerNodeId: 'do-scraper-1',
      image: validImage,
      maxPages: 12,
    );
    expect(valid.validate(), isEmpty);
    expect(valid.toAdapterPlan()['workerNodeId'], 'do-scraper-1');

    final unsafe = NazaChromiumScrapePlan(
      targetUrl: 'http://example.org/start',
      allowedDomains: const <String>['other.example.org'],
      image: 'ghcr.io/example/chrome:latest',
    );
    expect(
      unsafe.validate(),
      contains('Scraping requires an HTTPS target URL.'),
    );
    expect(
      unsafe.validate(),
      contains('The target host is not in the domain allowlist.'),
    );
    expect(
      unsafe.validate().any((error) => error.contains('immutable image')),
      isTrue,
    );
  });

  test('IPFS public exposure and payload encryption are explicit', () {
    const cid = 'bafybeigdyrzt5examplecid';
    const privatePlan = NazaIpfsPublicationPlan(
      contentCid: cid,
      label: 'private bundle',
      peerIds: <String>['12D3KooWExamplePeer'],
    );
    expect(privatePlan.validate(), isEmpty);

    const implicitPublic = NazaIpfsPublicationPlan(
      contentCid: cid,
      label: 'public bundle',
      publiclyDiscoverable: true,
    );
    expect(
      implicitPublic.validate(),
      contains('Public IPFS discovery requires an explicit exposure approval.'),
    );

    const plaintextPublic = NazaIpfsPublicationPlan(
      contentCid: cid,
      label: 'plaintext public bundle',
      publiclyDiscoverable: true,
      publicExposureApproved: true,
      encryptedPayload: false,
    );
    expect(
      plaintextPublic.validate(),
      contains('Public IPFS content must be encrypted before publication.'),
    );
  });

  test(
    'scrape export requires encrypted output and a relay for DigitalOcean',
    () {
      const local = NazaScrapeExportPlan(
        scrapeRequestId: 'op-scrape-1',
        destination: NazaScrapeExportDestination.localIpfs,
        format: 'jsonl',
        maxBytes: 4096,
      );
      expect(local.validate(), isEmpty);
      expect(jsonEncode(local.toAdapterPlan()), isNot(contains('plaintext')));

      const missingRelay = NazaScrapeExportPlan(
        scrapeRequestId: 'op-scrape-1',
        destination: NazaScrapeExportDestination.digitalOceanIpfs,
        format: 'jsonl',
        maxBytes: 4096,
      );
      expect(
        missingRelay.validate(),
        contains('DigitalOcean IPFS export requires an explicit relay node.'),
      );

      const plaintext = NazaScrapeExportPlan(
        scrapeRequestId: 'op-scrape-1',
        destination: NazaScrapeExportDestination.localIpfs,
        format: 'jsonl',
        encryptedPayload: false,
        maxBytes: 4096,
      );
      expect(
        plaintext.validate(),
        contains('Scrape exports must be encrypted.'),
      );
    },
  );

  test('DigitalOcean node actions are explicit and delete is destructive', () {
    final request = NazaRemoteOperationRequest.digitalOceanAction(
      id: 'op-node-stop',
      dropletId: 'do-scraper-1',
      action: NazaRemoteOperationKind.digitalOceanDropletStop,
      label: 'Scraper worker',
    );
    expect(request.nodeId, 'do-scraper-1');
    expect(request.kind.isDestructive, isFalse);

    final delete = NazaRemoteOperationRequest.digitalOceanAction(
      id: 'op-node-delete',
      dropletId: 'do-scraper-1',
      action: NazaRemoteOperationKind.digitalOceanDropletDelete,
      label: 'Scraper worker',
    );
    expect(delete.kind.isDestructive, isTrue);
    expect(jsonEncode(delete.toJson()), isNot(contains('token')));
  });

  test('remote operation records round-trip through encrypted vault', () async {
    final directory = await Directory.systemTemp.createTemp('naza-remote-ops-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final database = NazaSecureDatabase.forTesting(directory);
    await database.create(password: 'test-password', passwordRequired: true);
    addTearDown(database.lock);
    final store = NazaRemoteOperationsStore(database: database);
    const plan = NazaDigitalOceanDropletPlan(
      name: 'round-trip',
      region: 'nyc3',
      size: 's-1vcpu-1gb',
      image: 'ubuntu-24-04-x64',
    );
    final request = NazaRemoteOperationRequest.digitalOcean(
      id: 'op-round-trip',
      plan: plan,
    );
    await store.append(request);
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.kind, NazaRemoteOperationKind.digitalOceanDroplet);
    expect(loaded.single.droplet!.toApiPayload()['image'], 'ubuntu-24-04-x64');
    expect(jsonEncode(loaded.single.toJson()), isNot(contains('dop_v1_')));
    await store.cancel(request.id);
    expect(
      (await store.load()).single.state,
      NazaRemoteOperationState.cancelled,
    );
    await expectLater(
      store.append(
        request.copyWith(state: NazaRemoteOperationState.dispatched),
      ),
      throwsFormatException,
    );
  });

  test(
    'approval and dispatch each require a fresh sentinel decision',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-harm-gate-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = NazaSecureDatabase.forTesting(directory);
      await database.create(password: 'test-password', passwordRequired: true);
      addTearDown(database.lock);
      final gate = RecordingHarmGate(
        risks: <NazaHarmRisk>[NazaHarmRisk.medium, NazaHarmRisk.low],
      );
      final store = NazaRemoteOperationsStore(
        database: database,
        harmGate: gate,
      );
      final request = NazaRemoteOperationRequest.digitalOceanAction(
        id: 'op-start-gated',
        dropletId: 'droplet-01',
        action: NazaRemoteOperationKind.digitalOceanDropletStart,
        label: 'Start worker',
      );

      await store.append(request);
      await store.update(
        request.copyWith(state: NazaRemoteOperationState.approved),
      );
      await store.update(
        request.copyWith(state: NazaRemoteOperationState.dispatched),
      );

      expect(gate.commands, <String>[
        'digitalocean.droplet.start',
        'digitalocean.droplet.start',
      ]);
      expect(
        (await store.load()).single.state,
        NazaRemoteOperationState.dispatched,
      );
      final audit = await store.loadHarmAudit();
      expect(audit, hasLength(2));
      expect(audit.first['risk'], 'low');
      expect(audit.last['risk'], 'medium');
      expect(jsonEncode(audit), isNot(contains('dop_v1_')));
    },
  );

  test('High sentinel decision preserves awaiting-approval state', () async {
    final directory = await Directory.systemTemp.createTemp('naza-harm-deny-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final database = NazaSecureDatabase.forTesting(directory);
    await database.create(password: 'test-password', passwordRequired: true);
    addTearDown(database.lock);
    final store = NazaRemoteOperationsStore(
      database: database,
      harmGate: RecordingHarmGate(defaultRisk: NazaHarmRisk.high),
    );
    final request = NazaRemoteOperationRequest.ipfsPublish(
      id: 'op-ipfs-denied',
      plan: const NazaIpfsPublicationPlan(
        contentCid: 'bafybeigdyrzt5examplecid',
        label: 'encrypted bundle',
      ),
    );
    await store.append(request);

    await expectLater(
      store.update(request.copyWith(state: NazaRemoteOperationState.approved)),
      throwsA(isA<NazaHarmDeniedException>()),
    );

    expect(
      (await store.load()).single.state,
      NazaRemoteOperationState.awaitingApproval,
    );
    final audit = await store.loadHarmAudit();
    expect(audit.single['risk'], 'high');
    expect(audit.single['toState'], 'approved');
  });

  test('cancellation cannot be overwritten by an in-flight approval', () async {
    final directory = await Directory.systemTemp.createTemp('naza-op-race-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final database = NazaSecureDatabase.forTesting(directory);
    await database.create(password: 'test-password', passwordRequired: true);
    addTearDown(database.lock);
    final store = NazaRemoteOperationsStore(
      database: database,
      harmGate: RecordingHarmGate(delay: const Duration(milliseconds: 30)),
    );
    final request = NazaRemoteOperationRequest.nodeAction(
      id: 'op-race-safe',
      nodeId: 'node-01',
      kind: NazaRemoteOperationKind.nodeStart,
      label: 'Start bounded node',
    );
    await store.append(request);

    final approval = store.update(
      request.copyWith(state: NazaRemoteOperationState.approved),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final cancellation = store.cancel(request.id);
    await Future.wait<void>(<Future<void>>[approval, cancellation]);

    expect(
      (await store.load()).single.state,
      NazaRemoteOperationState.cancelled,
    );
  });
}
