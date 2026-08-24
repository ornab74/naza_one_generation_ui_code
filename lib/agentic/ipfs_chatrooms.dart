// LLM-CONTEXT:BEGIN
// FILE: lib/agentic/ipfs_chatrooms.dart
// ROLE: Encrypted human/agent IPFS chatroom contracts, monitor snapshots, and
// adapter boundaries for the agentic coding surface.
// DOMAIN: agentic-coding
// SECURITY-INVARIANT: Chat history stores ciphertext CIDs, authenticated
// digests, and public key references only; it never stores plaintext messages,
// tokens, private keys, cookies, or public RPC credentials.
// CHANGE-GUARD: Human and agent rooms are distinct, public discovery is opt-in,
// Kubo RPC stays private to an adapter, and monitor state is observational.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/sentinel_model_runtime.dart';
import '../security/probabilistic_harm_filter.dart';
import '../security/secure_database.dart';

const String nazaChatHybridSuite =
    'ML-KEM-1024+X25519+ML-DSA-87+HKDF-SHA512+AES-256-GCM';

enum NazaChatRoomKind { human, agent }

extension NazaChatRoomKindX on NazaChatRoomKind {
  String get label => switch (this) {
    NazaChatRoomKind.human => 'Human room',
    NazaChatRoomKind.agent => 'Agent room',
  };
}

enum NazaChatRoomState { active, paused, sealed }

enum NazaIpfsChatLinkState { offline, connecting, online, degraded }

extension NazaIpfsChatLinkStateX on NazaIpfsChatLinkState {
  String get label => switch (this) {
    NazaIpfsChatLinkState.offline => 'Offline',
    NazaIpfsChatLinkState.connecting => 'Connecting',
    NazaIpfsChatLinkState.online => 'Online',
    NazaIpfsChatLinkState.degraded => 'Degraded',
  };
}

@immutable
final class NazaChatRoom {
  const NazaChatRoom({
    required this.id,
    required this.name,
    required this.kind,
    required this.topic,
    required this.peerGroup,
    required this.createdAt,
    this.state = NazaChatRoomState.active,
    this.relayNodeId,
    this.ipnsName,
    this.publicDiscovery = false,
    this.publicExposureApproved = false,
    this.maxMessageBytes = 1024 * 1024,
    this.requiresSignedReceipts = true,
    this.bondSuite = nazaChatHybridSuite,
  });

  final String id;
  final String name;
  final NazaChatRoomKind kind;
  final String topic;
  final String peerGroup;
  final NazaChatRoomState state;
  final String? relayNodeId;
  final String? ipnsName;
  final bool publicDiscovery;
  final bool publicExposureApproved;
  final int maxMessageBytes;
  final bool requiresSignedReceipts;
  final String bondSuite;
  final DateTime createdAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(id)) errors.add('Invalid chatroom identity.');
    if (!_validLabel(name, 120)) errors.add('Chatroom name is invalid.');
    if (!_validTopic(topic)) errors.add('Chatroom topic is invalid.');
    if (!_validLabel(peerGroup, 120)) errors.add('Peer group is invalid.');
    if (relayNodeId != null && !_validId(relayNodeId!)) {
      errors.add('Relay node reference is invalid.');
    }
    if (ipnsName != null && !_validIpnsName(ipnsName!)) {
      errors.add('IPNS name is invalid.');
    }
    if (publicDiscovery && !publicExposureApproved) {
      errors.add(
        'Public chatroom discovery requires explicit exposure approval.',
      );
    }
    if (maxMessageBytes < 1024 || maxMessageBytes > 4 * 1024 * 1024) {
      errors.add('Maximum message size must be 1 KiB–4 MiB.');
    }
    if (bondSuite != nazaChatHybridSuite) {
      errors.add('Unsupported chatroom bond suite.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.name,
    'topic': topic,
    'peerGroup': peerGroup,
    'state': state.name,
    if (relayNodeId != null) 'relayNodeId': relayNodeId,
    if (ipnsName != null) 'ipnsName': ipnsName,
    'publicDiscovery': publicDiscovery,
    'publicExposureApproved': publicExposureApproved,
    'maxMessageBytes': maxMessageBytes,
    'requiresSignedReceipts': requiresSignedReceipts,
    'bondSuite': bondSuite,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static NazaChatRoom? fromJson(Object? value) {
    if (value is! Map) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final kind = _enumByName<NazaChatRoomKind>(
      value['kind']?.toString(),
      NazaChatRoomKind.values,
    );
    final state = _enumByName<NazaChatRoomState>(
      value['state']?.toString(),
      NazaChatRoomState.values,
    );
    if (createdAt == null || kind == null || state == null) return null;
    final room = NazaChatRoom(
      id: value['id']?.toString() ?? '',
      name: value['name']?.toString() ?? '',
      kind: kind,
      topic: value['topic']?.toString() ?? '',
      peerGroup: value['peerGroup']?.toString() ?? '',
      state: state,
      relayNodeId: _nullable(value['relayNodeId']?.toString()),
      ipnsName: _nullable(value['ipnsName']?.toString()),
      publicDiscovery: value['publicDiscovery'] == true,
      publicExposureApproved: value['publicExposureApproved'] == true,
      maxMessageBytes: value['maxMessageBytes'] is num
          ? (value['maxMessageBytes'] as num).round()
          : 1024 * 1024,
      requiresSignedReceipts: value['requiresSignedReceipts'] != false,
      bondSuite: value['bondSuite']?.toString() ?? '',
      createdAt: createdAt.toUtc(),
    );
    return room.validate().isEmpty ? room : null;
  }
}

/// A transport-neutral message envelope. `ciphertextCid` points to encrypted
/// bytes pinned by an adapter; no chat text is ever accepted by this model.
@immutable
final class NazaChatMessageEnvelope {
  const NazaChatMessageEnvelope({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderKind,
    required this.ciphertextCid,
    required this.aadDigest,
    required this.signatureKeyId,
    required this.sequence,
    required this.createdAt,
    this.replyTo,
    this.attachmentCids = const <String>[],
  });

  final String id;
  final String roomId;
  final String senderId;
  final NazaChatRoomKind senderKind;
  final String ciphertextCid;
  final String aadDigest;
  final String signatureKeyId;
  final int sequence;
  final String? replyTo;
  final List<String> attachmentCids;
  final DateTime createdAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(id) || !_validId(roomId) || !_validId(senderId)) {
      errors.add('Message identity is invalid.');
    }
    if (!_validCid(ciphertextCid)) errors.add('Ciphertext CID is invalid.');
    if (!_validDigest(aadDigest)) errors.add('AAD digest is invalid.');
    if (!_validKeyReference(signatureKeyId)) {
      errors.add('Signature key reference is invalid.');
    }
    if (sequence < 0 || sequence > 1000000000) {
      errors.add('Message sequence is invalid.');
    }
    if (replyTo != null && !_validId(replyTo!)) {
      errors.add('Reply reference is invalid.');
    }
    if (attachmentCids.length > 16 ||
        attachmentCids.any((cid) => !_validCid(cid))) {
      errors.add('Attachment CID list is invalid.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'roomId': roomId,
    'senderId': senderId,
    'senderKind': senderKind.name,
    'ciphertextCid': ciphertextCid,
    'aadDigest': aadDigest,
    'signatureKeyId': signatureKeyId,
    'sequence': sequence,
    if (replyTo != null) 'replyTo': replyTo,
    'attachmentCids': attachmentCids,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static NazaChatMessageEnvelope? fromJson(Object? value) {
    if (value is! Map) return null;
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final senderKind = _enumByName<NazaChatRoomKind>(
      value['senderKind']?.toString(),
      NazaChatRoomKind.values,
    );
    if (createdAt == null || senderKind == null) return null;
    final envelope = NazaChatMessageEnvelope(
      id: value['id']?.toString() ?? '',
      roomId: value['roomId']?.toString() ?? '',
      senderId: value['senderId']?.toString() ?? '',
      senderKind: senderKind,
      ciphertextCid: value['ciphertextCid']?.toString() ?? '',
      aadDigest: value['aadDigest']?.toString() ?? '',
      signatureKeyId: value['signatureKeyId']?.toString() ?? '',
      sequence: value['sequence'] is num
          ? (value['sequence'] as num).round()
          : -1,
      replyTo: _nullable(value['replyTo']?.toString()),
      attachmentCids: _strings(value['attachmentCids'], 16),
      createdAt: createdAt.toUtc(),
    );
    return envelope.validate().isEmpty ? envelope : null;
  }
}

@immutable
final class NazaChatRoomMonitorSnapshot {
  const NazaChatRoomMonitorSnapshot({
    required this.roomId,
    required this.linkState,
    required this.observedAt,
    this.connectedPeers = 0,
    this.subscribed = false,
    this.backlog = 0,
    this.droppedMessages = 0,
    this.relayNodeId,
    this.lastSeen,
    this.lastError,
    this.transportVersion = 'ipfs-pubsub-v1',
  });

  final String roomId;
  final NazaIpfsChatLinkState linkState;
  final int connectedPeers;
  final bool subscribed;
  final int backlog;
  final int droppedMessages;
  final String? relayNodeId;
  final DateTime? lastSeen;
  final String? lastError;
  final String transportVersion;
  final DateTime observedAt;

  List<String> validate() {
    final errors = <String>[];
    if (!_validId(roomId)) errors.add('Invalid monitor room reference.');
    if (connectedPeers < 0 || connectedPeers > 100000) {
      errors.add('Peer count is invalid.');
    }
    if (backlog < 0 || backlog > 1000000) errors.add('Backlog is invalid.');
    if (droppedMessages < 0 || droppedMessages > 1000000) {
      errors.add('Dropped-message count is invalid.');
    }
    if (relayNodeId != null && !_validId(relayNodeId!)) {
      errors.add('Monitor relay reference is invalid.');
    }
    if (lastError != null && lastError!.length > 300) {
      errors.add('Monitor error is too long.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'roomId': roomId,
    'linkState': linkState.name,
    'connectedPeers': connectedPeers,
    'subscribed': subscribed,
    'backlog': backlog,
    'droppedMessages': droppedMessages,
    if (relayNodeId != null) 'relayNodeId': relayNodeId,
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
    if (lastError != null) 'lastError': lastError,
    'transportVersion': transportVersion,
    'observedAt': observedAt.toUtc().toIso8601String(),
  };

  static NazaChatRoomMonitorSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    final observedAt = DateTime.tryParse(value['observedAt']?.toString() ?? '');
    final linkState = _enumByName<NazaIpfsChatLinkState>(
      value['linkState']?.toString(),
      NazaIpfsChatLinkState.values,
    );
    if (observedAt == null || linkState == null) return null;
    final monitor = NazaChatRoomMonitorSnapshot(
      roomId: value['roomId']?.toString() ?? '',
      linkState: linkState,
      connectedPeers: value['connectedPeers'] is num
          ? (value['connectedPeers'] as num).round()
          : 0,
      subscribed: value['subscribed'] == true,
      backlog: value['backlog'] is num ? (value['backlog'] as num).round() : 0,
      droppedMessages: value['droppedMessages'] is num
          ? (value['droppedMessages'] as num).round()
          : 0,
      relayNodeId: _nullable(value['relayNodeId']?.toString()),
      lastSeen: DateTime.tryParse(value['lastSeen']?.toString() ?? '')?.toUtc(),
      lastError: _nullable(value['lastError']?.toString()),
      transportVersion: _bounded(
        value['transportVersion']?.toString() ?? 'ipfs-pubsub-v1',
        80,
      ),
      observedAt: observedAt.toUtc(),
    );
    return monitor.validate().isEmpty ? monitor : null;
  }
}

@immutable
final class NazaChatDispatchApproval {
  const NazaChatDispatchApproval({
    required this.approvalId,
    required this.approvedAt,
    required this.expiresAt,
    this.publicExposureApproved = false,
  });

  final String approvalId;
  final DateTime approvedAt;
  final DateTime expiresAt;
  final bool publicExposureApproved;

  bool get isActive => DateTime.now().toUtc().isBefore(expiresAt);
}

/// Kubo is intentionally opt-in. The default settings do not construct a
/// client, start a process, or open a socket. The RPC endpoint is restricted
/// to a loopback address because Kubo RPC is an admin surface, not a public
/// chat endpoint.
@immutable
final class NazaKuboNodeSettings {
  const NazaKuboNodeSettings({
    this.enabled = false,
    this.apiBaseUrl = 'http://127.0.0.1:5001',
    this.gatewayBaseUrl = 'http://127.0.0.1:8080',
    this.binaryPath = 'ipfs',
    this.remoteNodeId,
    // Every IPFS capability is opt-in.  Kubo itself is already disabled by
    // default; keep its server profile and PubSub transport disabled too.
    this.serverProfile = false,
    this.pubSubEnabled = false,
    this.healthCheckSeconds = 30,
  });

  final bool enabled;
  final String apiBaseUrl;
  final String gatewayBaseUrl;
  final String binaryPath;
  final String? remoteNodeId;
  final bool serverProfile;
  final bool pubSubEnabled;
  final int healthCheckSeconds;

  static const NazaKuboNodeSettings defaults = NazaKuboNodeSettings();

  NazaKuboNodeSettings copyWith({
    bool? enabled,
    String? apiBaseUrl,
    String? gatewayBaseUrl,
    String? binaryPath,
    String? remoteNodeId,
    bool clearRemoteNodeId = false,
    bool? serverProfile,
    bool? pubSubEnabled,
    int? healthCheckSeconds,
  }) {
    return NazaKuboNodeSettings(
      enabled: enabled ?? this.enabled,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      gatewayBaseUrl: gatewayBaseUrl ?? this.gatewayBaseUrl,
      binaryPath: binaryPath ?? this.binaryPath,
      remoteNodeId: clearRemoteNodeId
          ? null
          : remoteNodeId ?? this.remoteNodeId,
      serverProfile: serverProfile ?? this.serverProfile,
      pubSubEnabled: pubSubEnabled ?? this.pubSubEnabled,
      healthCheckSeconds: healthCheckSeconds ?? this.healthCheckSeconds,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (!_loopbackEndpoint(apiBaseUrl)) {
      errors.add('Kubo RPC must use a loopback endpoint or an adapter tunnel.');
    }
    if (!_loopbackEndpoint(gatewayBaseUrl)) {
      errors.add(
        'Kubo gateway must use a loopback endpoint or an adapter tunnel.',
      );
    }
    if (binaryPath.trim().isEmpty || binaryPath.length > 512) {
      errors.add('Kubo binary path is invalid.');
    }
    if (remoteNodeId != null && !_validId(remoteNodeId!)) {
      errors.add('Kubo remote node reference is invalid.');
    }
    if (healthCheckSeconds < 5 || healthCheckSeconds > 3600) {
      errors.add('Kubo health interval must be 5–3600 seconds.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-kubo-settings-v1',
    'enabled': enabled,
    'apiBaseUrl': apiBaseUrl,
    'gatewayBaseUrl': gatewayBaseUrl,
    'binaryPath': binaryPath,
    if (remoteNodeId != null) 'remoteNodeId': remoteNodeId,
    'serverProfile': serverProfile,
    'pubSubEnabled': pubSubEnabled,
    'healthCheckSeconds': healthCheckSeconds,
  };

  static NazaKuboNodeSettings fromJson(Object? value) {
    if (value is! Map || value['format'] != 'naza-kubo-settings-v1') {
      return defaults;
    }
    final settings = NazaKuboNodeSettings(
      enabled: value['enabled'] == true,
      apiBaseUrl: value['apiBaseUrl']?.toString() ?? defaults.apiBaseUrl,
      gatewayBaseUrl:
          value['gatewayBaseUrl']?.toString() ?? defaults.gatewayBaseUrl,
      binaryPath: value['binaryPath']?.toString() ?? defaults.binaryPath,
      remoteNodeId: _nullable(value['remoteNodeId']?.toString()),
      // Missing flags must remain disabled.  This prevents an older or
      // hand-written settings blob from enabling an IPFS capability merely
      // by omitting the new field.
      serverProfile: value['serverProfile'] == true,
      pubSubEnabled: value['pubSubEnabled'] == true,
      healthCheckSeconds: value['healthCheckSeconds'] is num
          ? (value['healthCheckSeconds'] as num).round()
          : defaults.healthCheckSeconds,
    );
    return settings.validate().isEmpty ? settings : defaults;
  }
}

final class NazaKuboSettingsStore {
  NazaKuboSettingsStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String _namespace = 'agentic-ipfs-runtime';
  static const String _key = 'kubo-settings-v1';

  final NazaSecureDatabase _database;

  Future<NazaKuboNodeSettings> load() async {
    return NazaKuboNodeSettings.fromJson(
      await _database.readJson(_namespace, _key),
    );
  }

  Future<void> save(NazaKuboNodeSettings settings) async {
    final errors = settings.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    await _database.writeJson(_namespace, _key, settings.toJson());
  }
}

/// Minimal Dart RPC client for an already-running Kubo daemon. It is never
/// created by default and accepts no non-loopback endpoint. Provisioning or
/// starting Kubo remains the responsibility of the local/remote adapter.
final class NazaKuboRpcClient {
  NazaKuboRpcClient({
    required NazaKuboNodeSettings settings,
    NazaHarmGate? harmGate,
  }) : _settings = settings,
       _harmGate = harmGate ?? NazaSentinelGuard.instance.gate,
       _http = HttpClient() {
    if (!settings.enabled) {
      throw StateError('Kubo backend is disabled in settings.');
    }
    final errors = settings.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    _http.connectionTimeout = const Duration(seconds: 8);
  }

  final NazaKuboNodeSettings _settings;
  final NazaHarmGate _harmGate;
  final HttpClient _http;

  Future<Map<String, Object?>> nodeIdentity() => _postJson('/api/v0/id');

  void requirePubSubEnabled() => _requirePubSub();

  Future<List<String>> pubsubPeers(String topic) async {
    _requirePubSub();
    _requireTopic(topic);
    final result = await _postJson('/api/v0/pubsub/peers', <String, String>{
      'arg': topic,
    });
    final values = result['Strings'];
    if (values is! List) return const <String>[];
    return values
        .map((value) => value.toString())
        .take(1000)
        .toList(growable: false);
  }

  Future<void> publishEnvelope(
    String topic,
    NazaChatMessageEnvelope envelope,
  ) async {
    _requirePubSub();
    _requireTopic(topic);
    final errors = envelope.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    final base = Uri.parse(_settings.apiBaseUrl);
    final uri = _rpcUri(base, '/api/v0/pubsub/pub', <String, String>{
      'arg': topic,
    });
    await _harmGate.requireAllowed('ipfs.data.publish');
    final boundary = 'naza${DateTime.now().microsecondsSinceEpoch}';
    final body = utf8.encode(jsonEncode(envelope.toJson()));
    final request = await _http.postUrl(uri);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    request.add(utf8.encode('--$boundary\r\n'));
    request.add(
      utf8.encode(
        'Content-Disposition: form-data; name="file"; filename="envelope.json"\r\n',
      ),
    );
    request.add(utf8.encode('Content-Type: application/json\r\n\r\n'));
    request.add(body);
    request.add(utf8.encode('\r\n--$boundary--\r\n'));
    final response = await request.close();
    final text = await _boundedResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Kubo publish failed (${response.statusCode}): $text',
      );
    }
  }

  Stream<NazaChatMessageEnvelope> subscribe(String topic) async* {
    _requirePubSub();
    _requireTopic(topic);
    final base = Uri.parse(_settings.apiBaseUrl);
    final uri = _rpcUri(base, '/api/v0/pubsub/sub', <String, String>{
      'arg': topic,
    });
    await _harmGate.requireAllowed('ipfs.data.pull');
    final request = await _http.postUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await _boundedResponse(response);
      throw HttpException(
        'Kubo subscribe failed (${response.statusCode}): $text',
      );
    }
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty || line.length > 512 * 1024) continue;
      try {
        final decoded = jsonDecode(line);
        final rawData = decoded is Map ? decoded['data'] : decoded;
        final messageData = rawData is String
            ? jsonDecode(utf8.decode(base64.decode(rawData)))
            : rawData;
        final envelope = NazaChatMessageEnvelope.fromJson(messageData);
        if (envelope != null) yield envelope;
      } on FormatException {
        // Ignore malformed transport frames; the monitor/adapter records the
        // failure separately instead of allowing untrusted data to crash UI.
      } on JsonUnsupportedObjectError {
        // Same fail-closed behavior for malformed frames.
      }
    }
  }

  Future<Map<String, Object?>> _postJson(
    String path, [
    Map<String, String> query = const <String, String>{},
  ]) async {
    final uri = _rpcUri(Uri.parse(_settings.apiBaseUrl), path, query);
    await _harmGate.requireAllowed(_sentinelCommandForPath(path));
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    final response = await request.close();
    final text = await _boundedResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Kubo RPC failed (${response.statusCode}): $text');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map)
      throw const FormatException('Kubo response was not an object.');
    return <String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
  }

  Future<String> _boundedResponse(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException(
          'Kubo response exceeded the bounded limit.',
        );
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  void _requirePubSub() {
    if (!_settings.pubSubEnabled) {
      throw StateError('Kubo PubSub transport is disabled in settings.');
    }
  }

  void _requireTopic(String topic) {
    if (!_validTopic(topic)) throw const FormatException('Invalid chat topic.');
  }

  void close() => _http.close(force: true);

  static String _sentinelCommandForPath(String path) => switch (path) {
    '/api/v0/id' => 'ipfs.node.identity',
    '/api/v0/pubsub/peers' => 'ipfs.pubsub.peers',
    _ => 'ipfs.rpc.request',
  };
}

/// Adapter implementation using the Kubo RPC client. Construction is opt-in;
/// no chatroom calls happen until `connect` is invoked with a fresh approval.
final class NazaKuboChatTransport implements NazaIpfsChatTransport {
  NazaKuboChatTransport({
    required NazaKuboNodeSettings settings,
    NazaHarmGate? harmGate,
  }) : _client = NazaKuboRpcClient(settings: settings, harmGate: harmGate);

  final NazaKuboRpcClient _client;
  final Map<String, NazaChatRoom> _rooms = <String, NazaChatRoom>{};

  @override
  Future<void> connect(
    NazaChatRoom room, {
    required NazaChatDispatchApproval approval,
  }) async {
    _requireApproval(room, approval);
    _client.requirePubSubEnabled();
    if (room.state != NazaChatRoomState.active) {
      throw StateError('Only active chatrooms can connect.');
    }
    await _client.nodeIdentity();
    _rooms[room.id] = room;
  }

  @override
  Future<void> publish(
    NazaChatMessageEnvelope envelope, {
    required NazaChatDispatchApproval approval,
  }) async {
    final room = _rooms[envelope.roomId];
    if (room == null) throw StateError('Chatroom is not connected.');
    _requireApproval(room, approval);
    if (envelope.senderKind != room.kind) {
      throw StateError('Envelope sender kind does not match the room.');
    }
    await _client.publishEnvelope(room.topic, envelope);
  }

  @override
  Stream<NazaChatMessageEnvelope> subscribe(
    String roomId, {
    required NazaChatDispatchApproval approval,
  }) async* {
    final room = _rooms[roomId];
    if (room == null) throw StateError('Chatroom is not connected.');
    _requireApproval(room, approval);
    await for (final envelope in _client.subscribe(room.topic)) {
      _requireApproval(room, approval);
      yield envelope;
    }
  }

  @override
  Future<NazaChatRoomMonitorSnapshot> probe(
    NazaChatRoom room, {
    required NazaChatDispatchApproval approval,
  }) async {
    _requireApproval(room, approval);
    final identity = await _client.nodeIdentity();
    final peers = await _client.pubsubPeers(room.topic);
    return NazaChatRoomMonitorSnapshot(
      roomId: room.id,
      linkState: NazaIpfsChatLinkState.online,
      connectedPeers: peers.length,
      subscribed: _rooms.containsKey(room.id),
      relayNodeId: room.relayNodeId,
      lastSeen: DateTime.now().toUtc(),
      observedAt: DateTime.now().toUtc(),
      transportVersion: 'kubo-rpc-${identity['AgentVersion'] ?? 'unknown'}',
    );
  }

  @override
  Future<void> disconnect(String roomId) async {
    _rooms.remove(roomId);
  }

  void close() => _client.close();

  static void _requireApproval(
    NazaChatRoom room,
    NazaChatDispatchApproval approval,
  ) {
    final now = DateTime.now().toUtc();
    if (!_validId(approval.approvalId) ||
        approval.approvedAt.isAfter(now) ||
        !approval.expiresAt.isAfter(approval.approvedAt) ||
        !approval.isActive) {
      throw StateError('Chat dispatch approval is invalid or expired.');
    }
    if (room.state != NazaChatRoomState.active) {
      throw StateError('Only active chatrooms can dispatch.');
    }
    if (room.publicDiscovery && !approval.publicExposureApproved) {
      throw StateError('Public chatroom exposure was not approved.');
    }
  }
}

/// Implemented by a separately attested node adapter. The default Flutter
/// surface deliberately has no HTTP client for Kubo RPC and no ability to
/// publish messages or expose admin ports.
abstract interface class NazaIpfsChatTransport {
  Future<void> connect(
    NazaChatRoom room, {
    required NazaChatDispatchApproval approval,
  });

  Future<void> publish(
    NazaChatMessageEnvelope envelope, {
    required NazaChatDispatchApproval approval,
  });

  Stream<NazaChatMessageEnvelope> subscribe(
    String roomId, {
    required NazaChatDispatchApproval approval,
  });

  Future<NazaChatRoomMonitorSnapshot> probe(
    NazaChatRoom room, {
    required NazaChatDispatchApproval approval,
  });

  Future<void> disconnect(String roomId);
}

final class NazaIpfsChatRoomStore {
  NazaIpfsChatRoomStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String _namespace = 'agentic-ipfs-chatrooms';
  static const String _roomsKey = 'rooms-v1';
  static const String _messagesKey = 'messages-v1';
  static const String _monitorsKey = 'monitors-v1';
  static const int maxRooms = 64;
  static const int maxMessages = 2000;
  static const int maxMonitors = 64;

  final NazaSecureDatabase _database;

  Future<List<NazaChatRoom>> loadRooms() async {
    final raw = await _database.readJson(_namespace, _roomsKey);
    if (raw is! List) return const <NazaChatRoom>[];
    return List<NazaChatRoom>.unmodifiable(
      raw.map(NazaChatRoom.fromJson).whereType<NazaChatRoom>().take(maxRooms),
    );
  }

  Future<List<NazaChatMessageEnvelope>> loadMessages(String roomId) async {
    final raw = await _database.readJson(_namespace, _messagesKey);
    if (raw is! List) return const <NazaChatMessageEnvelope>[];
    return List<NazaChatMessageEnvelope>.unmodifiable(
      raw
          .map(NazaChatMessageEnvelope.fromJson)
          .whereType<NazaChatMessageEnvelope>()
          .where((message) => message.roomId == roomId)
          .take(maxMessages),
    );
  }

  Future<NazaChatRoomMonitorSnapshot?> loadMonitor(String roomId) async {
    final raw = await _database.readJson(_namespace, _monitorsKey);
    if (raw is! List) return null;
    final matches = raw
        .map(NazaChatRoomMonitorSnapshot.fromJson)
        .whereType<NazaChatRoomMonitorSnapshot>()
        .where((monitor) => monitor.roomId == roomId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> saveRoom(NazaChatRoom room) async {
    _throwIfInvalid(room.validate());
    final current = await loadRooms();
    final next = <NazaChatRoom>[
      ...current.where((item) => item.id != room.id),
      room,
    ];
    final bounded = next.length <= maxRooms
        ? next
        : next.sublist(next.length - maxRooms);
    await _database.writeJson(
      _namespace,
      _roomsKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<void> appendMessage(NazaChatMessageEnvelope message) async {
    _throwIfInvalid(message.validate());
    final rooms = await loadRooms();
    final roomMatches = rooms.where((room) => room.id == message.roomId);
    if (roomMatches.isEmpty ||
        roomMatches.first.state != NazaChatRoomState.active) {
      throw const FormatException('Chatroom is not active.');
    }
    if (roomMatches.first.kind != message.senderKind) {
      throw const FormatException('Message sender kind does not match room.');
    }
    final raw = await _database.readJson(_namespace, _messagesKey);
    final current = raw is List
        ? raw
              .map(NazaChatMessageEnvelope.fromJson)
              .whereType<NazaChatMessageEnvelope>()
              .toList()
        : <NazaChatMessageEnvelope>[];
    final next = <NazaChatMessageEnvelope>[
      ...current.where((item) => item.id != message.id),
      message,
    ];
    final bounded = next.length <= maxMessages
        ? next
        : next.sublist(next.length - maxMessages);
    await _database.writeJson(
      _namespace,
      _messagesKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<void> saveMonitor(NazaChatRoomMonitorSnapshot monitor) async {
    _throwIfInvalid(monitor.validate());
    final raw = await _database.readJson(_namespace, _monitorsKey);
    final current = raw is List
        ? raw
              .map(NazaChatRoomMonitorSnapshot.fromJson)
              .whereType<NazaChatRoomMonitorSnapshot>()
              .toList()
        : <NazaChatRoomMonitorSnapshot>[];
    final next = <NazaChatRoomMonitorSnapshot>[
      ...current.where((item) => item.roomId != monitor.roomId),
      monitor,
    ];
    final bounded = next.length <= maxMonitors
        ? next
        : next.sublist(next.length - maxMonitors);
    await _database.writeJson(
      _namespace,
      _monitorsKey,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  static void _throwIfInvalid(List<String> errors) {
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
  }
}

String _bounded(String value, int max) {
  final clean = value.trim();
  return clean.length <= max ? clean : clean.substring(0, max);
}

String? _nullable(String? value) {
  final clean = value?.trim() ?? '';
  return clean.isEmpty ? null : _bounded(clean, 300);
}

bool _validId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$').hasMatch(value.trim());

bool _validLabel(String value, int max) {
  final clean = value.trim();
  return clean.isNotEmpty && clean.length <= max && !clean.contains('\u0000');
}

bool _validTopic(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 200 &&
      clean.startsWith('naza-chat/v1/') &&
      !clean.contains(' ');
}

bool _validIpnsName(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 128 &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(clean);
}

bool _validCid(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 128 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(clean);
}

bool _validDigest(String value) {
  return RegExp(r'^(?:sha256:)?[a-fA-F0-9]{32,128}$').hasMatch(value.trim());
}

bool _validKeyReference(String value) {
  final clean = value.trim();
  return clean.length >= 8 &&
      clean.length <= 160 &&
      RegExp(r'^[A-Za-z0-9._:+/-]+$').hasMatch(clean);
}

List<String> _strings(Object? value, int max) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .take(max),
  );
}

T? _enumByName<T extends Enum>(String? value, List<T> values) {
  if (value == null) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}

bool _loopbackEndpoint(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  if (uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

Uri _rpcUri(Uri base, String path, Map<String, String> query) {
  final basePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(
    path: '$basePath$path',
    queryParameters: query.isEmpty ? null : query,
  );
}
