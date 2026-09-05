// LLM-CONTEXT:BEGIN
// FILE: test/ipfs_chatrooms_test.dart
// ROLE: Verifies opt-in Kubo settings, encrypted chatroom envelopes, and
// monitor persistence.
// SECURITY-INVARIANT: Kubo is disabled by default, public RPC endpoints are
// rejected, and plaintext chat content never enters the persisted envelope.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

import 'support/harm_test_support.dart';

void main() {
  const digest =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('Kubo backend is disabled by default and rejects public RPC', () {
    const defaults = NazaKuboNodeSettings.defaults;
    expect(defaults.enabled, isFalse);
    expect(defaults.serverProfile, isFalse);
    expect(defaults.pubSubEnabled, isFalse);
    expect(defaults.apiBaseUrl, 'http://127.0.0.1:5001');
    expect(defaults.validate(), isEmpty);

    final unsafe = defaults.copyWith(
      enabled: true,
      apiBaseUrl: 'https://public.example.test:5001',
    );
    expect(
      unsafe.validate(),
      contains('Kubo RPC must use a loopback endpoint or an adapter tunnel.'),
    );
    expect(() => NazaKuboRpcClient(settings: unsafe), throwsFormatException);
    expect(() => NazaKuboRpcClient(settings: defaults), throwsStateError);

    final credentialInUrl = defaults.copyWith(
      apiBaseUrl: 'http://user:secret@127.0.0.1:5001',
    );
    expect(credentialInUrl.validate(), isNotEmpty);
    expect(
      defaults.copyWith(apiBaseUrl: 'http://localhost:5001').validate(),
      isNotEmpty,
    );
    final configured = defaults.copyWith(remoteNodeId: 'remote-kubo-01');
    expect(configured.remoteNodeId, 'remote-kubo-01');
    expect(configured.copyWith(clearRemoteNodeId: true).remoteNodeId, isNull);
  });

  test('omitted IPFS capability flags stay disabled when loading settings', () {
    final settings = NazaKuboNodeSettings.fromJson(<String, Object?>{
      'format': 'naza-kubo-settings-v1',
      'enabled': false,
      'apiBaseUrl': 'http://127.0.0.1:5001',
      'gatewayBaseUrl': 'http://127.0.0.1:8080',
      'binaryPath': 'ipfs',
      'healthCheckSeconds': 30,
    });

    expect(settings.serverProfile, isFalse);
    expect(settings.pubSubEnabled, isFalse);
  });

  test('Kubo RPC is denied by the sentinel before opening a socket', () async {
    final gate = RecordingHarmGate(defaultRisk: NazaHarmRisk.high);
    final client = NazaKuboRpcClient(
      settings: NazaKuboNodeSettings.defaults.copyWith(enabled: true),
      harmGate: gate,
    );
    addTearDown(client.close);

    await expectLater(
      client.nodeIdentity(),
      throwsA(isA<NazaHarmDeniedException>()),
    );

    expect(gate.commands, <String>['ipfs.node.identity']);
  });

  test('IPFS publish and pull are independently denied before I/O', () async {
    final gate = RecordingHarmGate(defaultRisk: NazaHarmRisk.high);
    final client = NazaKuboRpcClient(
      settings: NazaKuboNodeSettings.defaults.copyWith(
        enabled: true,
        pubSubEnabled: true,
      ),
      harmGate: gate,
    );
    addTearDown(client.close);
    final envelope = NazaChatMessageEnvelope(
      id: 'chat-denied',
      roomId: 'room-denied',
      senderId: 'agent-bond-01',
      senderKind: NazaChatRoomKind.agent,
      ciphertextCid: 'bafybeigdyrzt5ciphertext',
      aadDigest: digest,
      signatureKeyId: 'sig-key-01',
      sequence: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await expectLater(
      client.publishEnvelope('naza-chat/v1/denied-room', envelope),
      throwsA(isA<NazaHarmDeniedException>()),
    );
    await expectLater(
      client.subscribe('naza-chat/v1/denied-room').drain<void>(),
      throwsA(isA<NazaHarmDeniedException>()),
    );

    expect(gate.commands, <String>['ipfs.data.publish', 'ipfs.data.pull']);
  });

  test(
    'a properly ordered fresh dispatch approval reaches the sentinel',
    () async {
      final gate = RecordingHarmGate(defaultRisk: NazaHarmRisk.high);
      final transport = NazaKuboChatTransport(
        settings: NazaKuboNodeSettings.defaults.copyWith(
          enabled: true,
          pubSubEnabled: true,
        ),
        harmGate: gate,
      );
      addTearDown(transport.close);
      final now = DateTime.now().toUtc();
      final room = NazaChatRoom(
        id: 'room-approval',
        name: 'Approval room',
        kind: NazaChatRoomKind.agent,
        topic: 'naza-chat/v1/approval-room',
        peerGroup: 'agent-mesh',
        createdAt: now,
      );

      await expectLater(
        transport.connect(
          room,
          approval: NazaChatDispatchApproval(
            approvalId: 'approval-01',
            approvedAt: now.subtract(const Duration(seconds: 1)),
            expiresAt: now.add(const Duration(minutes: 5)),
          ),
        ),
        throwsA(isA<NazaHarmDeniedException>()),
      );
      expect(gate.commands, <String>['ipfs.node.identity']);
    },
  );

  test(
    'dispatch approvals are short-lived and cannot be minted for hours',
    () async {
      final now = DateTime.now().toUtc();
      final transport = NazaKuboChatTransport(
        settings: NazaKuboNodeSettings.defaults.copyWith(
          enabled: true,
          pubSubEnabled: true,
        ),
        harmGate: RecordingHarmGate(),
      );
      addTearDown(transport.close);
      final room = NazaChatRoom(
        id: 'room-long-approval',
        name: 'Bounded approval',
        kind: NazaChatRoomKind.agent,
        topic: 'naza-chat/v1/bounded-approval',
        peerGroup: 'agent-mesh',
        createdAt: now,
      );

      await expectLater(
        transport.connect(
          room,
          approval: NazaChatDispatchApproval(
            approvalId: 'approval-too-long',
            approvedAt: now,
            expiresAt: now.add(const Duration(hours: 1)),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('human and agent rooms have distinct encrypted transport envelopes', () {
    final human = NazaChatRoom(
      id: 'room-human',
      name: 'Human collaboration',
      kind: NazaChatRoomKind.human,
      topic: 'naza-chat/v1/human-room',
      peerGroup: 'trusted-humans',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final agent = NazaChatRoom(
      id: 'room-agent',
      name: 'Agent coordination',
      kind: NazaChatRoomKind.agent,
      topic: 'naza-chat/v1/agent-room',
      peerGroup: 'agent-mesh',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(human.validate(), isEmpty);
    expect(agent.validate(), isEmpty);

    final envelope = NazaChatMessageEnvelope(
      id: 'chat-envelope',
      roomId: human.id,
      senderId: 'human-bond-01',
      senderKind: NazaChatRoomKind.human,
      ciphertextCid: 'bafybeigdyrzt5ciphertext',
      aadDigest: digest,
      signatureKeyId: 'sig-key-01',
      sequence: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(envelope.validate(), isEmpty);
    expect(jsonEncode(envelope.toJson()), isNot(contains('plaintext chat')));
  });

  test(
    'chatroom, envelope, monitor, and Kubo settings persist in encrypted vault',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-ipfs-chat-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = NazaSecureDatabase.forTesting(directory);
      await database.create(password: 'test-password', passwordRequired: true);
      addTearDown(database.lock);
      final rooms = NazaIpfsChatRoomStore(database: database);
      final kubo = NazaKuboSettingsStore(database: database);
      final room = NazaChatRoom(
        id: 'room-roundtrip',
        name: 'Round trip',
        kind: NazaChatRoomKind.agent,
        topic: 'naza-chat/v1/round-trip',
        peerGroup: 'mesh',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await rooms.saveRoom(room);
      await rooms.appendMessage(
        NazaChatMessageEnvelope(
          id: 'chat-roundtrip',
          roomId: room.id,
          senderId: 'agent-bond-01',
          senderKind: NazaChatRoomKind.agent,
          ciphertextCid: 'bafybeigdyrzt5ciphertext',
          aadDigest: digest,
          signatureKeyId: 'sig-key-01',
          sequence: 1,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await expectLater(
        rooms.appendMessage(
          NazaChatMessageEnvelope(
            id: 'chat-roundtrip',
            roomId: room.id,
            senderId: 'agent-bond-01',
            senderKind: NazaChatRoomKind.agent,
            ciphertextCid: 'bafybeigdifferentciphertext',
            aadDigest: digest,
            signatureKeyId: 'sig-key-01',
            sequence: 1,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        rooms.appendMessage(
          NazaChatMessageEnvelope(
            id: 'chat-sequence-collision',
            roomId: room.id,
            senderId: 'agent-bond-01',
            senderKind: NazaChatRoomKind.agent,
            ciphertextCid: 'bafybeigdifferentciphertext',
            aadDigest: digest,
            signatureKeyId: 'sig-key-01',
            sequence: 1,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        throwsFormatException,
      );
      await rooms.saveMonitor(
        NazaChatRoomMonitorSnapshot(
          roomId: room.id,
          linkState: NazaIpfsChatLinkState.degraded,
          connectedPeers: 2,
          subscribed: true,
          observedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await kubo.save(
        NazaKuboNodeSettings.defaults.copyWith(
          enabled: true,
          pubSubEnabled: true,
          remoteNodeId: 'remote-kubo-01',
        ),
      );

      expect((await rooms.loadRooms()).single.kind, NazaChatRoomKind.agent);
      expect(
        (await rooms.loadMessages(room.id)).single.ciphertextCid,
        'bafybeigdyrzt5ciphertext',
      );
      expect((await rooms.loadMonitor(room.id))!.connectedPeers, 2);
      expect((await kubo.load()).enabled, isTrue);
      for (final entity in await directory.list().toList()) {
        if (entity is! File) continue;
        final raw = String.fromCharCodes(await entity.readAsBytes());
        expect(raw, isNot(contains('plaintext chat')));
      }
    },
  );

  test(
    'message sender kind cannot cross human and agent room boundaries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'naza-ipfs-kind-',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final database = NazaSecureDatabase.forTesting(directory);
      await database.create(password: 'test-password', passwordRequired: true);
      addTearDown(database.lock);
      final rooms = NazaIpfsChatRoomStore(database: database);
      await rooms.saveRoom(
        NazaChatRoom(
          id: 'room-human',
          name: 'Human room',
          kind: NazaChatRoomKind.human,
          topic: 'naza-chat/v1/human-room',
          peerGroup: 'humans',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await expectLater(
        rooms.appendMessage(
          NazaChatMessageEnvelope(
            id: 'chat-agent-cross',
            roomId: 'room-human',
            senderId: 'agent-bond-01',
            senderKind: NazaChatRoomKind.agent,
            ciphertextCid: 'bafybeigdyrzt5ciphertext',
            aadDigest: digest,
            signatureKeyId: 'sig-key-01',
            sequence: 0,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
