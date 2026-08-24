// LLM-CONTEXT:BEGIN
// FILE: lib/agentic/agentic_coding_surface.dart
// ROLE: Visual GUI for bounded coding-agent orchestration and evidence review.
// DOMAIN: agentic-coding
// SECURITY-INVARIANT: Model output is a proposal until separately approved;
// credentials never enter prompts, logs, receipts, or public node projections.
// CHANGE-GUARD: Keep local-first defaults, responsive layouts, explicit
// capability approvals, and honest labels for diagnostic entropy surfaces.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../model/sentinel_model_runtime.dart';
import '../security/probabilistic_harm_filter.dart';
import 'agentic_runtime.dart';
import 'code_workbench.dart';
import 'collaboration_queue.dart';
import 'ipfs_chatrooms.dart';
import 'remote_operations.dart';

typedef NazaAgenticTaskRunner =
    Future<NazaAgenticRunResult> Function(NazaAgenticTaskRequest request);
typedef NazaAgenticImagePicker = Future<NazaAgenticAttachment?> Function();

class NazaAgenticCodingSurface extends StatefulWidget {
  const NazaAgenticCodingSurface({
    super.key,
    required this.runTask,
    this.pickImage,
    this.store,
    this.operationsStore,
    this.collaborationStore,
    this.chatRoomStore,
    this.kuboSettingsStore,
    this.harmGate,
    this.collector = const NazaRepositoryContextCollector(),
    this.initialConfig,
    this.persistState = true,
  });

  final NazaAgenticTaskRunner runTask;
  final NazaAgenticImagePicker? pickImage;
  final NazaAgenticWorkspaceStore? store;
  final NazaRemoteOperationsStore? operationsStore;
  final NazaCollaborationQueueStore? collaborationStore;
  final NazaIpfsChatRoomStore? chatRoomStore;
  final NazaKuboSettingsStore? kuboSettingsStore;
  final NazaHarmGate? harmGate;
  final NazaRepositoryContextCollector collector;
  final NazaAgenticWorkspaceConfig? initialConfig;
  final bool persistState;

  @override
  State<NazaAgenticCodingSurface> createState() =>
      _NazaAgenticCodingSurfaceState();
}

class _NazaAgenticCodingSurfaceState extends State<NazaAgenticCodingSurface> {
  static const Color _violet = Color(0xFFAA93FF);
  static const Color _cyan = Color(0xFF62D9F7);
  static const Color _mint = Color(0xFF76E3B4);
  static const Color _amber = Color(0xFFFFC66D);
  static const Color _rose = Color(0xFFFF7F9B);
  static const Color _ink = Color(0xFF06100F);
  static const Color _panel = Color(0xFF0D1B19);
  static const Color _border = Color(0xFF29433D);
  static const Color _text = Color(0xFFF0FFF8);
  static const Color _subtext = Color(0xFFA8BDB5);

  late final NazaAgenticWorkspaceStore _store;
  late final NazaRemoteOperationsStore _operationsStore;
  late final NazaCollaborationQueueStore _collaborationStore;
  late final NazaIpfsChatRoomStore _chatRoomStore;
  late final NazaKuboSettingsStore _kuboSettingsStore;
  late final NazaHarmGate _harmGate;
  late NazaAgenticWorkspaceConfig _config;
  final TextEditingController _taskController = TextEditingController(
    text:
        'Inspect the selected architecture, find the highest-leverage improvement, and propose a reversible patch with focused verification.',
  );
  final FocusNode _taskFocus = FocusNode();
  NazaRepositoryContext? _repository;
  NazaAgenticAttachment? _attachment;
  NazaAgenticRunResult? _result;
  bool _loading = true;
  bool _indexing = false;
  bool _running = false;
  bool _proposePatch = true;
  bool _runChecks = false;
  bool _allowNetwork = false;
  bool _mutationApproved = false;
  bool _networkApproved = false;
  String _status = 'Initializing the secure workbench';
  String? _error;
  NazaAgenticPolicyDecision? _lastPolicy;
  final Map<String, String> _nodeStates = <String, String>{};
  List<NazaRemoteOperationRequest> _operations =
      const <NazaRemoteOperationRequest>[];
  List<NazaCollaborationPool> _collaborationPools =
      const <NazaCollaborationPool>[];
  List<NazaQueuedEdit> _queuedEdits = const <NazaQueuedEdit>[];
  List<NazaAgentEnvelope> _agentEnvelopes = const <NazaAgentEnvelope>[];
  List<NazaChatRoom> _chatRooms = const <NazaChatRoom>[];
  final Map<String, NazaChatRoomMonitorSnapshot> _chatMonitors =
      <String, NazaChatRoomMonitorSnapshot>{};
  final Map<String, List<NazaChatMessageEnvelope>> _chatMessages =
      <String, List<NazaChatMessageEnvelope>>{};
  NazaKuboNodeSettings _kuboSettings = NazaKuboNodeSettings.defaults;

  @override
  void initState() {
    super.initState();
    _harmGate = widget.harmGate ?? NazaSentinelGuard.instance.gate;
    _store = widget.store ?? NazaAgenticWorkspaceStore();
    _operationsStore =
        widget.operationsStore ??
        NazaRemoteOperationsStore(harmGate: _harmGate);
    _collaborationStore =
        widget.collaborationStore ?? NazaCollaborationQueueStore();
    _chatRoomStore = widget.chatRoomStore ?? NazaIpfsChatRoomStore();
    _kuboSettingsStore = widget.kuboSettingsStore ?? NazaKuboSettingsStore();
    _config = widget.initialConfig ?? const NazaAgenticWorkspaceConfig();
    if (widget.persistState) {
      unawaited(_loadConfig());
      unawaited(_loadOperations());
      unawaited(_loadCollaboration());
      unawaited(_loadChatRooms());
      unawaited(_loadKuboSettings());
    } else {
      _loading = false;
      _status = 'Local planning boundary ready';
    }
  }

  Future<void> _loadOperations() async {
    try {
      final loaded = await _operationsStore.load();
      if (!mounted) return;
      setState(() => _operations = loaded);
    } catch (_) {
      // A locked vault must not prevent the visual workbench from opening.
      // The UI will label new requests as ephemeral if persistence fails.
    }
  }

  Future<void> _loadCollaboration() async {
    try {
      final pools = await _collaborationStore.loadPools();
      final active = pools.where(
        (pool) => pool.state == NazaCollaborationPoolState.active,
      );
      final pool = active.isEmpty ? null : active.first;
      final edits = pool == null
          ? const <NazaQueuedEdit>[]
          : await _collaborationStore.loadEdits(pool.id);
      final envelopes = pool == null
          ? const <NazaAgentEnvelope>[]
          : await _collaborationStore.loadEnvelopes(pool.id);
      if (!mounted) return;
      setState(() {
        _collaborationPools = pools;
        _queuedEdits = edits;
        _agentEnvelopes = envelopes;
      });
    } catch (_) {
      // A locked vault does not prevent local planning; the panel reports the
      // persistence boundary when a new queue request is staged.
    }
  }

  Future<void> _loadChatRooms() async {
    try {
      final rooms = await _chatRoomStore.loadRooms();
      final monitors = <String, NazaChatRoomMonitorSnapshot>{};
      final messages = <String, List<NazaChatMessageEnvelope>>{};
      for (final room in rooms) {
        final monitor = await _chatRoomStore.loadMonitor(room.id);
        final roomMessages = await _chatRoomStore.loadMessages(room.id);
        if (monitor != null) monitors[room.id] = monitor;
        messages[room.id] = roomMessages;
      }
      if (!mounted) return;
      setState(() {
        _chatRooms = rooms;
        _chatMonitors
          ..clear()
          ..addAll(monitors);
        _chatMessages
          ..clear()
          ..addAll(messages);
      });
    } catch (_) {
      // The surface remains usable while the encrypted vault is locked.
    }
  }

  Future<void> _loadKuboSettings() async {
    try {
      final settings = await _kuboSettingsStore.load();
      if (!mounted) return;
      setState(() => _kuboSettings = settings);
    } catch (_) {
      // Disabled defaults remain safe if the vault is unavailable.
    }
  }

  Future<void> _appendRemoteOperation(
    NazaRemoteOperationRequest request,
  ) async {
    final next = <NazaRemoteOperationRequest>[..._operations, request];
    setState(() {
      _operations = next.length <= NazaRemoteOperationsStore.maxRequests
          ? List<NazaRemoteOperationRequest>.unmodifiable(next)
          : List<NazaRemoteOperationRequest>.unmodifiable(
              next.sublist(next.length - NazaRemoteOperationsStore.maxRequests),
            );
      _error = null;
      _status = '${request.kind.label} request sealed · awaiting approval';
    });
    if (!widget.persistState) return;
    try {
      await _operationsStore.append(request);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _status =
            '${request.kind.label} request staged locally · unlock vault to persist',
      );
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocus.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final loaded = await _store.load();
      if (!mounted) return;
      setState(() {
        _config = loaded;
        _loading = false;
        _status = 'Encrypted workspace policy restored';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Ephemeral local policy · unlock vault to persist';
      });
    }
  }

  Future<void> _persistConfig() async {
    if (!widget.persistState) return;
    try {
      await _store.save(_config);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Policy changed locally · encrypted vault unavailable';
      });
    }
  }

  void _updateConfig(NazaAgenticWorkspaceConfig next) {
    setState(() {
      _config = next;
      _result = null;
      _lastPolicy = null;
      _error = null;
    });
    unawaited(_persistConfig());
  }

  Future<void> _chooseRepository() async {
    if (_indexing || _running) return;
    final selected = await file_selector.getDirectoryPath(
      confirmButtonText: 'Index workspace',
    );
    if (selected == null || selected.trim().isEmpty || !mounted) return;
    setState(() {
      _indexing = true;
      _error = null;
      _status = 'Building a bounded, secret-filtered evidence snapshot';
    });
    try {
      final context = await widget.collector.collect(
        selected,
        maxFiles: _config.maxFiles,
        maxBytes: _config.maxContextBytes,
      );
      if (!mounted) return;
      setState(() {
        _repository = context;
        _indexing = false;
        _status =
            '${context.files.length} files · ${_formatBytes(context.bytes)} · evidence ${context.fingerprint.substring(0, 10)}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _indexing = false;
        _error = 'Workspace indexing failed: $error';
        _status = 'Repository evidence unavailable';
      });
    }
  }

  Future<void> _pickAttachment() async {
    final picker = widget.pickImage;
    if (picker == null || _running) return;
    try {
      final attachment = await picker();
      if (!mounted || attachment == null) return;
      setState(() {
        _attachment = attachment;
        _error = null;
        _status =
            '${attachment.name} · ${attachment.dimensions} · local vision';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not attach image: $error');
    }
  }

  Set<NazaAgenticPermission> _permissionsForRun() => <NazaAgenticPermission>{
    if (_config.modality == NazaAgenticModality.repository)
      NazaAgenticPermission.inspectRepository,
    if (_proposePatch) NazaAgenticPermission.proposePatch,
    if (_runChecks) NazaAgenticPermission.runChecks,
    if (_allowNetwork) NazaAgenticPermission.networkAccess,
    if (_config.activeNode.kind == NazaExecutionTargetKind.remoteSsh)
      NazaAgenticPermission.remoteExecution,
  };

  Future<void> _run() async {
    if (_running) return;
    NazaAgenticTaskRequest request;
    try {
      request = NazaAgenticTaskRequest.validated(
        task: _taskController.text,
        modelMode: _config.modelMode,
        modality: _config.modality,
        node: _config.activeNode,
        permissions: _permissionsForRun(),
        mutationApproved: _mutationApproved,
        networkApproved: _networkApproved,
        memoryEnabled: _config.memoryEnabled,
        repository: _repository,
        attachment: _attachment,
      );
    } catch (error) {
      setState(() => _error = error.toString());
      _taskFocus.requestFocus();
      return;
    }
    final policy = const NazaAgenticPolicyEngine().evaluate(request);
    if (!policy.canRun) {
      setState(() {
        _lastPolicy = policy;
        _error = [...policy.blockers, ...policy.approvals].join(' ');
        _status = policy.requiresApproval
            ? 'Capability approval required'
            : 'Policy gate blocked this run';
      });
      return;
    }
    setState(() {
      _running = true;
      _result = null;
      _lastPolicy = policy;
      _error = null;
      // Approval acknowledgements are single-use even though this release is
      // planning-only. A future execution adapter cannot inherit stale grants.
      _mutationApproved = false;
      _networkApproved = false;
      _status = 'Context → divergence → synthesis → verification';
    });
    try {
      final result = await widget.runTask(request);
      try {
        await _store.appendReceipt(
          NazaAgenticRunReceipt.fromRun(request, result),
        );
      } catch (_) {
        // The completed response remains useful if encrypted receipt storage
        // is temporarily unavailable. No plaintext prompt is written here.
      }
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = result;
        _status = result.weave.reviewRequired
            ? 'Synthesis complete · human review required'
            : 'Synthesis complete · evidence surface convergent';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Agentic synthesis failed: $error';
        _status = 'Run failed closed';
      });
    }
  }

  Future<void> _addRemoteNode() async {
    final name = TextEditingController(text: 'Secure build node');
    final host = TextEditingController();
    final port = TextEditingController(text: '22');
    final user = TextEditingController();
    final hostKey = TextEditingController(text: 'SHA256:');
    final root = TextEditingController(text: '/workspace');
    final key = TextEditingController();
    var trust = 0.70;
    final submitted = await showDialog<NazaAgenticNodeProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Register encrypted SSH node',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The profile and key are separate authenticated vault records. No connection is attempted while saving.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _dialogField(name, 'Node title'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dialogField(host, 'Host or IP')),
                      const SizedBox(width: 10),
                      SizedBox(width: 110, child: _dialogField(port, 'Port')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField(user, 'SSH username'),
                  const SizedBox(height: 10),
                  _dialogField(
                    hostKey,
                    'Pinned SSH host key (SHA256:…)',
                    monospace: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(root, 'Remote workspace root'),
                  const SizedBox(height: 10),
                  _dialogField(
                    key,
                    'OpenSSH / PKCS#8 private key',
                    maxLines: 6,
                    monospace: true,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Initial trust weight · ${(trust * 100).round()}%',
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Slider(
                    value: trust,
                    min: 0.2,
                    max: 1,
                    divisions: 8,
                    activeColor: _cyan,
                    onChanged: (value) => setDialogState(() => trust = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _violet),
              onPressed: () {
                try {
                  final id = 'remote-${DateTime.now().microsecondsSinceEpoch}';
                  final profile = NazaAgenticNodeProfile.createRemote(
                    id: id,
                    name: name.text,
                    host: host.text,
                    port: int.tryParse(port.text) ?? 22,
                    username: user.text,
                    hostKeySha256: hostKey.text,
                    workspaceRoot: root.text,
                    trustWeight: trust,
                    hasCredential: key.text.trim().isNotEmpty,
                  );
                  Navigator.pop(dialogContext, profile);
                } catch (error) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              icon: const Icon(Icons.enhanced_encryption_rounded),
              label: const Text('Seal profile'),
            ),
          ],
        ),
      ),
    );
    try {
      if (submitted != null) {
        if (key.text.trim().isNotEmpty) {
          await _store.saveSshPrivateKey(
            nodeId: submitted.id,
            privateKey: key.text,
          );
        }
        if (!mounted) return;
        final next = _config.copyWith(
          nodes: <NazaAgenticNodeProfile>[..._config.nodes, submitted],
          activeNodeId: submitted.id,
        );
        _updateConfig(next);
        setState(() => _status = 'Remote node sealed in encrypted storage');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not seal remote node: $error');
      }
    } finally {
      name.dispose();
      host.dispose();
      port.dispose();
      user.dispose();
      hostKey.dispose();
      root.dispose();
      key.dispose();
    }
  }

  Future<void> _configureContainer(NazaAgenticNodeProfile node) async {
    final image = TextEditingController(
      text: node.containerImage == 'Configure a signed OCI image'
          ? ''
          : node.containerImage,
    );
    final root = TextEditingController(
      text: node.workspaceRoot.isEmpty ? '/workspace' : node.workspaceRoot,
    );
    var enabled = node.enabled;
    final updated = await showDialog<NazaAgenticNodeProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Rootless container envelope',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This registers policy intent only. The GUI does not claim seccomp, AppArmor, AppContainer, or macOS sandbox enforcement until a verified native adapter reports it.',
                  style: TextStyle(color: _subtext, height: 1.4),
                ),
                const SizedBox(height: 16),
                _dialogField(image, 'Pinned/signed OCI image reference'),
                const SizedBox(height: 10),
                _dialogField(root, 'Mounted workspace path'),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mark adapter configured',
                    style: TextStyle(color: _text),
                  ),
                  subtitle: const Text(
                    'Enable only after a trusted local runtime is installed.',
                    style: TextStyle(color: _subtext),
                  ),
                  value: enabled,
                  activeTrackColor: _mint,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _violet),
              onPressed: () {
                if (image.text.trim().isEmpty || root.text.trim().isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter an image reference and mount path.'),
                    ),
                  );
                  return;
                }
                if (enabled &&
                    !NazaAgenticNodeProfile.isImmutableContainerImage(
                      image.text,
                    )) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enabled containers require image@sha256:<64 hex>.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  node.copyWith(
                    containerImage: image.text,
                    workspaceRoot: root.text,
                    enabled: enabled,
                  ),
                );
              },
              child: const Text('Save envelope'),
            ),
          ],
        ),
      ),
    );
    image.dispose();
    root.dispose();
    if (updated == null || !mounted) return;
    _replaceNode(updated, select: updated.enabled);
  }

  Future<void> _removeRemoteNode(NazaAgenticNodeProfile node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Remove remote node?',
          style: TextStyle(color: _text),
        ),
        content: Text(
          'This removes ${node.name} and its encrypted SSH-key record. This cannot be undone.',
          style: const TextStyle(color: _subtext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep node'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rose),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _requestNodeAction(node, 'delete');
      if (node.hasCredential) await _store.deleteSshPrivateKey(node.id);
      if (!mounted) return;
      _updateConfig(
        _config.copyWith(
          nodes: _config.nodes.where((item) => item.id != node.id),
          activeNodeId: NazaAgenticNodeProfile.localDefault.id,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not remove node: $error');
    }
  }

  Future<void> _requestNodeAction(
    NazaAgenticNodeProfile node,
    String action,
  ) async {
    if (_running) return;
    final kind = switch (action) {
      'start' => NazaRemoteOperationKind.nodeStart,
      'stop' => NazaRemoteOperationKind.nodeStop,
      'delete' => NazaRemoteOperationKind.nodeDelete,
      _ => null,
    };
    if (kind == null) return;
    final request = NazaRemoteOperationRequest.nodeAction(
      id: 'op-${DateTime.now().microsecondsSinceEpoch}',
      nodeId: node.id,
      kind: kind,
      label: node.name,
    );
    setState(() {
      _nodeStates[node.id] = '$action requested · approval boundary';
    });
    await _appendRemoteOperation(request);
  }

  Future<void> _requestEnvironment() async {
    final provider = TextEditingController(text: 'DigitalOcean');
    final name = TextEditingController(text: 'naza-agentic-sandbox');
    final region = TextEditingController(text: 'nyc3');
    final size = TextEditingController(text: 's-1vcpu-2gb');
    final image = TextEditingController(text: 'ubuntu-24-04-x64');
    final sshKeys = TextEditingController();
    final tags = TextEditingController(text: 'naza-agentic,ephemeral');
    final host = TextEditingController();
    var backups = false;
    var publicNetworking = false;
    final request = await showDialog<(NazaDigitalOceanDropletPlan, String?)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Request agentic environment',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(provider, 'Provider adapter (DigitalOcean)'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dialogField(name, 'Droplet name')),
                      const SizedBox(width: 10),
                      Expanded(child: _dialogField(region, 'Region slug')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dialogField(size, 'Size slug')),
                      const SizedBox(width: 10),
                      Expanded(child: _dialogField(image, 'Image slug / ID')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    sshKeys,
                    'SSH key IDs / fingerprints (comma-separated)',
                  ),
                  const SizedBox(height: 10),
                  _dialogField(tags, 'Tags (comma-separated)'),
                  const SizedBox(height: 10),
                  _dialogField(
                    host,
                    'IP / hostname (optional until provisioned)',
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Automated backups',
                      style: TextStyle(color: _text),
                    ),
                    value: backups,
                    activeTrackColor: _mint,
                    onChanged: (value) => setDialogState(() => backups = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Public networking',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'Off by default; turn on only for an approved adapter that needs public ingress/egress.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: publicNetworking,
                    activeTrackColor: _rose,
                    onChanged: (value) =>
                        setDialogState(() => publicNetworking = value),
                  ),
                  const Text(
                    'This creates a sealed DigitalOcean plan only. The API token is resolved by a separate adapter and a fresh approval is required before POST /v2/droplets.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (provider.text.trim().toLowerCase() != 'digitalocean') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Only the DigitalOcean adapter is enabled in this control plane.',
                    ),
                  ),
                );
                return;
              }
              try {
                final plan = NazaDigitalOceanDropletPlan(
                  name: name.text,
                  region: region.text,
                  size: size.text,
                  image: image.text,
                  sshKeyRefs: sshKeys.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(growable: false),
                  tags: tags.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(growable: false),
                  backups: backups,
                  publicNetworking: publicNetworking,
                );
                final errors = plan.validate();
                if (errors.isNotEmpty) throw FormatException(errors.join(' '));
                Navigator.pop(dialogContext, (plan, host.text));
              } catch (error) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text('Seal request'),
          ),
        ],
      ),
    );
    provider.dispose();
    name.dispose();
    region.dispose();
    size.dispose();
    sshKeys.dispose();
    tags.dispose();
    host.dispose();
    image.dispose();
    if (request == null || !mounted) return;
    final operation = NazaRemoteOperationRequest.digitalOcean(
      id: 'op-${DateTime.now().microsecondsSinceEpoch}',
      plan: request.$1,
      host: request.$2,
    );
    await _appendRemoteOperation(operation);
  }

  Future<void> _requestChromiumScrape() async {
    final url = TextEditingController(text: 'https://example.org');
    final domains = TextEditingController(text: 'example.org');
    final workerNode = TextEditingController();
    final image = TextEditingController(
      text: 'ghcr.io/ornab74/scraper-chrome-docker@sha256:',
    );
    final pages = TextEditingController(text: '10');
    final output = TextEditingController(text: 'jsonl');
    final request = await showDialog<NazaChromiumScrapePlan?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Request Chromium scrape worker',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(url, 'HTTPS target URL'),
                const SizedBox(height: 10),
                _dialogField(
                  domains,
                  'Allowed domains (comma-separated; no wildcards)',
                ),
                const SizedBox(height: 10),
                _dialogField(
                  workerNode,
                  'DigitalOcean scraper droplet node ID (optional until assigned)',
                ),
                const SizedBox(height: 10),
                _dialogField(
                  image,
                  'Pinned Chromium image@sha256:<64 hex>',
                  monospace: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _dialogField(pages, 'Max pages')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: output.text,
                        dropdownColor: _panel,
                        style: const TextStyle(color: _text),
                        decoration: const InputDecoration(
                          labelText: 'Output format',
                          labelStyle: TextStyle(color: _subtext),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'jsonl',
                            child: Text('JSONL'),
                          ),
                          DropdownMenuItem(value: 'json', child: Text('JSON')),
                          DropdownMenuItem(
                            value: 'markdown',
                            child: Text('Markdown'),
                          ),
                          DropdownMenuItem(
                            value: 'text',
                            child: Text('Plain text'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) output.text = value;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The worker receives an explicit HTTPS/domain allowlist and robots-respect policy. Cookies and arbitrary commands are excluded. Network capability still requires approval before dispatch.',
                  style: TextStyle(color: _subtext, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final plan = NazaChromiumScrapePlan(
                  targetUrl: url.text,
                  allowedDomains: domains.text
                      .split(',')
                      .map((value) => value.trim().toLowerCase())
                      .where((value) => value.isNotEmpty)
                      .toList(growable: false),
                  workerNodeId: workerNode.text.trim().isEmpty
                      ? null
                      : workerNode.text.trim(),
                  image: image.text,
                  maxPages: int.tryParse(pages.text) ?? 0,
                  outputFormat: output.text.trim().toLowerCase(),
                );
                final errors = plan.validate();
                if (errors.isNotEmpty) throw FormatException(errors.join(' '));
                Navigator.pop(dialogContext, plan);
              } catch (error) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text('Seal scrape request'),
          ),
        ],
      ),
    );
    url.dispose();
    domains.dispose();
    workerNode.dispose();
    image.dispose();
    pages.dispose();
    output.dispose();
    if (request == null || !mounted) return;
    await _appendRemoteOperation(
      NazaRemoteOperationRequest.chromiumScrape(
        id: 'op-${DateTime.now().microsecondsSinceEpoch}',
        plan: request,
      ),
    );
  }

  Future<void> _requestIpfsPublish() async {
    final cid = TextEditingController();
    final label = TextEditingController(
      text: 'Agentic public-information bundle',
    );
    final peers = TextEditingController();
    var publiclyDiscoverable = false;
    var publicExposureApproved = false;
    var encryptedPayload = true;
    final request = await showDialog<NazaIpfsPublicationPlan?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'Request IPFS publication',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    cid,
                    'Existing CID (content is never copied into history)',
                  ),
                  const SizedBox(height: 10),
                  _dialogField(label, 'Publication label'),
                  const SizedBox(height: 10),
                  _dialogField(peers, 'Trusted peer IDs (comma-separated)'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Encrypted payload',
                      style: TextStyle(color: _text),
                    ),
                    value: encryptedPayload,
                    activeTrackColor: _mint,
                    onChanged: (value) =>
                        setDialogState(() => encryptedPayload = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Publicly discoverable',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'Off by default; public exposure cannot be implied by an agent.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: publiclyDiscoverable,
                    activeTrackColor: _rose,
                    onChanged: (value) =>
                        setDialogState(() => publiclyDiscoverable = value),
                  ),
                  if (publiclyDiscoverable)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I approve public IPFS exposure for this CID',
                        style: TextStyle(color: _text, fontSize: 13),
                      ),
                      value: publicExposureApproved,
                      activeColor: _rose,
                      onChanged: (value) => setDialogState(
                        () => publicExposureApproved = value == true,
                      ),
                    ),
                  const Text(
                    'This is a pin/publication request, not an upload. A trusted IPFS adapter must verify the CID and peer policy before any network action.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final plan = NazaIpfsPublicationPlan(
                    contentCid: cid.text,
                    label: label.text,
                    peerIds: peers.text
                        .split(',')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty)
                        .toList(growable: false),
                    publiclyDiscoverable: publiclyDiscoverable,
                    publicExposureApproved: publicExposureApproved,
                    encryptedPayload: encryptedPayload,
                  );
                  final errors = plan.validate();
                  if (errors.isNotEmpty)
                    throw FormatException(errors.join(' '));
                  Navigator.pop(dialogContext, plan);
                } catch (error) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('Seal IPFS request'),
            ),
          ],
        ),
      ),
    );
    cid.dispose();
    label.dispose();
    peers.dispose();
    if (request == null || !mounted) return;
    await _appendRemoteOperation(
      NazaRemoteOperationRequest.ipfsPublish(
        id: 'op-${DateTime.now().microsecondsSinceEpoch}',
        plan: request,
      ),
    );
  }

  Future<void> _requestScrapeExport() async {
    final source = TextEditingController();
    final relay = TextEditingController(text: 'do-ipfs-relay-1');
    final format = TextEditingController(text: 'jsonl');
    final maxBytes = TextEditingController(text: '${64 * 1024 * 1024}');
    var destination = NazaScrapeExportDestination.localIpfs;
    var publiclyDiscoverable = false;
    var publicExposureApproved = false;
    final values =
        await showDialog<
          (
            String,
            NazaScrapeExportDestination,
            String,
            String,
            String,
            bool,
            bool,
          )?
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: _panel,
              title: const Text(
                'Export scrape result to encrypted IPFS',
                style: TextStyle(color: _text, fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(
                        source,
                        'Chromium scrape request ID (for example op-...)',
                        monospace: true,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<NazaScrapeExportDestination>(
                        initialValue: destination,
                        dropdownColor: _panel,
                        style: const TextStyle(color: _text),
                        decoration: const InputDecoration(
                          labelText: 'IPFS destination',
                          labelStyle: TextStyle(color: _subtext),
                        ),
                        items: [
                          for (final item in NazaScrapeExportDestination.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => destination = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (destination ==
                          NazaScrapeExportDestination.digitalOceanIpfs) ...[
                        _dialogField(
                          relay,
                          'DigitalOcean IPFS relay node ID',
                          monospace: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              format,
                              'Format: jsonl/json/markdown/text',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              maxBytes,
                              'Max bytes',
                              monospace: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_rounded, color: _mint),
                        title: Text(
                          'Encrypted payload is mandatory',
                          style: TextStyle(color: _text, fontSize: 13),
                        ),
                        subtitle: Text(
                          'Only the encrypted result CID and adapter references enter the operation history.',
                          style: TextStyle(color: _subtext, fontSize: 11),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Public CID discovery',
                          style: TextStyle(color: _text),
                        ),
                        subtitle: const Text(
                          'Off by default. Public discovery never makes the scraped payload public, but it does expose the encrypted CID.',
                          style: TextStyle(color: _subtext, fontSize: 11),
                        ),
                        value: publiclyDiscoverable,
                        activeTrackColor: _rose,
                        onChanged: (value) =>
                            setDialogState(() => publiclyDiscoverable = value),
                      ),
                      if (publiclyDiscoverable)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I approve public CID discovery',
                            style: TextStyle(color: _text, fontSize: 13),
                          ),
                          value: publicExposureApproved,
                          activeColor: _rose,
                          onChanged: (value) => setDialogState(
                            () => publicExposureApproved = value == true,
                          ),
                        ),
                      const Text(
                        'The export adapter must read the approved scrape artifact, encrypt it, enforce the byte limit, pin it to local Kubo or the selected DigitalOcean relay, and return a CID. No page content is copied into this UI queue.',
                        style: TextStyle(color: _subtext, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    try {
                      final plan = NazaScrapeExportPlan(
                        scrapeRequestId: source.text,
                        destination: destination,
                        format: format.text.trim().toLowerCase(),
                        relayNodeId:
                            destination ==
                                NazaScrapeExportDestination.digitalOceanIpfs
                            ? relay.text.trim()
                            : null,
                        publiclyDiscoverable: publiclyDiscoverable,
                        publicExposureApproved: publicExposureApproved,
                        maxBytes: int.tryParse(maxBytes.text) ?? 0,
                      );
                      final errors = plan.validate();
                      if (errors.isNotEmpty)
                        throw FormatException(errors.join(' '));
                      Navigator.pop(dialogContext, (
                        source.text,
                        destination,
                        format.text.trim().toLowerCase(),
                        destination ==
                                NazaScrapeExportDestination.digitalOceanIpfs
                            ? relay.text.trim()
                            : '',
                        maxBytes.text,
                        publiclyDiscoverable,
                        publicExposureApproved,
                      ));
                    } catch (error) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
                  child: const Text('Seal export request'),
                ),
              ],
            ),
          ),
        );
    source.dispose();
    relay.dispose();
    format.dispose();
    maxBytes.dispose();
    if (values == null || !mounted) return;
    final sourceExists = _operations.any(
      (operation) =>
          operation.id == values.$1 &&
          operation.kind == NazaRemoteOperationKind.chromiumScrape,
    );
    if (!sourceExists) {
      setState(
        () => _error =
            'Export source must be an existing Chromium scrape request in this queue.',
      );
      return;
    }
    final plan = NazaScrapeExportPlan(
      scrapeRequestId: values.$1,
      destination: values.$2,
      format: values.$3,
      relayNodeId: values.$4.trim().isEmpty ? null : values.$4,
      maxBytes: int.tryParse(values.$5) ?? 0,
      publiclyDiscoverable: values.$6,
      publicExposureApproved: values.$7,
    );
    await _appendRemoteOperation(
      NazaRemoteOperationRequest.scrapeExport(
        id: 'op-${DateTime.now().microsecondsSinceEpoch}',
        plan: plan,
      ),
    );
  }

  Future<void> _requestDigitalOceanAction() async {
    final dropletId = TextEditingController();
    final label = TextEditingController(
      text: 'DigitalOcean scraper / IPFS node',
    );
    var action = NazaRemoteOperationKind.digitalOceanDropletStart;
    var deleteConfirmed = false;
    final values = await showDialog<(String, String, NazaRemoteOperationKind, bool)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'Manage DigitalOcean droplet node',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(dropletId, 'Droplet ID', monospace: true),
                const SizedBox(height: 10),
                _dialogField(label, 'Node label'),
                const SizedBox(height: 10),
                DropdownButtonFormField<NazaRemoteOperationKind>(
                  initialValue: action,
                  dropdownColor: _panel,
                  style: const TextStyle(color: _text),
                  decoration: const InputDecoration(
                    labelText: 'Approved action',
                    labelStyle: TextStyle(color: _subtext),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: NazaRemoteOperationKind.digitalOceanDropletStart,
                      child: Text('Start node'),
                    ),
                    DropdownMenuItem(
                      value: NazaRemoteOperationKind.digitalOceanDropletStop,
                      child: Text('Stop node'),
                    ),
                    DropdownMenuItem(
                      value: NazaRemoteOperationKind.digitalOceanDropletDelete,
                      child: Text('Delete node'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => action = value);
                  },
                ),
                if (action == NazaRemoteOperationKind.digitalOceanDropletDelete)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I understand deletion is irreversible',
                      style: TextStyle(color: _text, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'The queue will require a second approval boundary; no DELETE request is made by this UI.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: deleteConfirmed,
                    activeColor: _rose,
                    onChanged: (value) =>
                        setDialogState(() => deleteConfirmed = value == true),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'The operation stores only the droplet reference. Provider credentials and SSH material remain in the encrypted credential boundary and are resolved only by an attested adapter after approval.',
                  style: TextStyle(color: _subtext, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    action == NazaRemoteOperationKind.digitalOceanDropletDelete
                    ? _rose
                    : _cyan,
              ),
              onPressed: () {
                if (action ==
                        NazaRemoteOperationKind.digitalOceanDropletDelete &&
                    !deleteConfirmed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Confirm irreversible deletion first.'),
                    ),
                  );
                  return;
                }
                try {
                  _validNodeReferenceForDialog(dropletId.text);
                  if (label.text.trim().isEmpty) {
                    throw const FormatException('Node label is required.');
                  }
                  Navigator.pop(dialogContext, (
                    dropletId.text.trim(),
                    label.text.trim(),
                    action,
                    deleteConfirmed,
                  ));
                } catch (error) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: Text(
                action == NazaRemoteOperationKind.digitalOceanDropletDelete
                    ? 'Queue delete'
                    : 'Queue action',
              ),
            ),
          ],
        ),
      ),
    );
    dropletId.dispose();
    label.dispose();
    if (values == null || !mounted) return;
    await _appendRemoteOperation(
      NazaRemoteOperationRequest.digitalOceanAction(
        id: 'op-${DateTime.now().microsecondsSinceEpoch}',
        dropletId: values.$1,
        action: values.$3,
        label: values.$2,
      ),
    );
  }

  Future<void> _cancelRemoteOperation(
    NazaRemoteOperationRequest operation,
  ) async {
    final cancelled = operation.copyWith(
      state: NazaRemoteOperationState.cancelled,
    );
    setState(() {
      _operations = List<NazaRemoteOperationRequest>.unmodifiable(
        _operations.map((item) => item.id == operation.id ? cancelled : item),
      );
      _status = '${operation.kind.label} request cancelled locally';
    });
    if (widget.persistState) {
      try {
        await _operationsStore.update(cancelled);
      } catch (_) {
        if (mounted) {
          setState(
            () => _status = 'Cancellation staged locally · vault unavailable',
          );
        }
      }
    }
  }

  Future<void> _approveRemoteOperation(
    NazaRemoteOperationRequest operation,
  ) async {
    final approved = operation.copyWith(
      state: NazaRemoteOperationState.approved,
    );
    try {
      if (widget.persistState) {
        await _operationsStore.update(approved);
      } else {
        await _harmGate.requireAllowed(operation.kind.sentinelCommandName);
      }
      if (!mounted) return;
      setState(() {
        _operations = List<NazaRemoteOperationRequest>.unmodifiable(
          _operations.map((item) => item.id == operation.id ? approved : item),
        );
        _error = null;
        _status =
            '${operation.kind.label} passed harm filter · trusted adapter still required';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is NazaHarmDeniedException
            ? '${operation.kind.label} denied by the core safety sentinel (${error.decision.risk.label}).'
            : '${operation.kind.label} approval failed closed: $error';
        _status = 'Remote operation remains awaiting approval';
      });
    }
  }

  NazaCollaborationPool? get _activeCollaborationPool {
    for (final pool in _collaborationPools) {
      if (pool.state == NazaCollaborationPoolState.active) return pool;
    }
    return null;
  }

  Future<void> _createCollaborationPool() async {
    final name = TextEditingController(text: 'MMO coding pool');
    final fingerprint = TextEditingController(
      text: _repository?.fingerprint ?? '',
    );
    final peers = TextEditingController(text: 'local-only');
    final concurrency = TextEditingController(text: '4');
    final values = await showDialog<(String, String, String, int)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Create cooperative edit pool',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(name, 'Pool name'),
              const SizedBox(height: 10),
              _dialogField(
                fingerprint,
                'Workspace base fingerprint (sha256:…)',
                monospace: true,
              ),
              const SizedBox(height: 10),
              _dialogField(peers, 'IPFS / node peer group label'),
              const SizedBox(height: 10),
              _dialogField(concurrency, 'Max concurrent edit claims'),
              const SizedBox(height: 10),
              const Text(
                'Agents claim relative file sectors against this immutable base. Only encrypted CID references and signed-receipt references move between nodes.',
                style: TextStyle(color: _subtext, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              name.text,
              fingerprint.text,
              peers.text,
              int.tryParse(concurrency.text) ?? 0,
            )),
            child: const Text('Seal pool'),
          ),
        ],
      ),
    );
    name.dispose();
    fingerprint.dispose();
    peers.dispose();
    concurrency.dispose();
    if (values == null || !mounted) return;
    try {
      final pool = NazaCollaborationPool(
        id: 'pool-${DateTime.now().microsecondsSinceEpoch}',
        name: values.$1,
        workspaceFingerprint: values.$2,
        peerGroup: values.$3,
        maxConcurrentEdits: values.$4,
        createdAt: DateTime.now().toUtc(),
      );
      final errors = pool.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(' '));
      if (widget.persistState) await _collaborationStore.savePool(pool);
      setState(() {
        _collaborationPools = <NazaCollaborationPool>[
          ..._collaborationPools,
          pool,
        ];
        _status = 'Cooperative pool sealed · ${pool.bondSuite}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not seal edit pool: $error');
    }
  }

  Future<void> _enqueueCollaborativeEdit() async {
    final pool = _activeCollaborationPool;
    if (pool == null) {
      setState(() => _status = 'Create an active cooperative pool first');
      return;
    }
    final path = TextEditingController();
    final sector = TextEditingController(text: 'whole-file');
    final goal = TextEditingController();
    final base = TextEditingController(text: pool.workspaceFingerprint);
    final dependencies = TextEditingController();
    final values = await showDialog<(String, String, String, String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Queue a cooperative edit',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  path,
                  'Relative file path (no .. or absolute paths)',
                  monospace: true,
                ),
                const SizedBox(height: 10),
                _dialogField(sector, 'File sector / symbol zone'),
                const SizedBox(height: 10),
                _dialogField(goal, 'Bounded edit goal'),
                const SizedBox(height: 10),
                _dialogField(base, 'Base fingerprint', monospace: true),
                const SizedBox(height: 10),
                _dialogField(
                  dependencies,
                  'Dependency edit IDs (comma-separated)',
                ),
                const SizedBox(height: 10),
                const Text(
                  'This queues intent, not source text. The claiming agent must re-check the base fingerprint, produce a signed receipt, and enter review before merge.',
                  style: TextStyle(color: _subtext, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              path.text,
              sector.text,
              goal.text,
              base.text,
              dependencies.text,
            )),
            child: const Text('Queue edit'),
          ),
        ],
      ),
    );
    path.dispose();
    sector.dispose();
    goal.dispose();
    base.dispose();
    dependencies.dispose();
    if (values == null || !mounted) return;
    try {
      final edit = NazaQueuedEdit(
        id: 'edit-${DateTime.now().microsecondsSinceEpoch}',
        poolId: pool.id,
        relativePath: values.$1,
        sector: values.$2,
        goal: values.$3,
        baseFingerprint: values.$4,
        dependencies: values.$5
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        createdAt: DateTime.now().toUtc(),
      );
      final errors = edit.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(' '));
      if (widget.persistState) await _collaborationStore.enqueueEdit(edit);
      setState(() {
        _queuedEdits = <NazaQueuedEdit>[..._queuedEdits, edit];
        _status = 'Edit queued · waiting for an agent claim';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not queue edit: $error');
    }
  }

  Future<void> _postAgentEnvelope() async {
    final pool = _activeCollaborationPool;
    if (pool == null) {
      setState(() => _status = 'Create an active cooperative pool first');
      return;
    }
    final cid = TextEditingController();
    final sender = TextEditingController();
    final signature = TextEditingController();
    final recipient = TextEditingController();
    final editId = TextEditingController();
    final values = await showDialog<(String, String, String, String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Queue encrypted agent handoff',
          style: TextStyle(color: _text, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                cid,
                'Ciphertext CID (message body never stored here)',
              ),
              const SizedBox(height: 10),
              _dialogField(sender, 'Sender bond public-key ID'),
              const SizedBox(height: 10),
              _dialogField(signature, 'Signature public-key ID'),
              const SizedBox(height: 10),
              _dialogField(
                recipient,
                'Recipient bond public-key ID (optional)',
              ),
              const SizedBox(height: 10),
              _dialogField(editId, 'Edit ID (optional)'),
              const SizedBox(height: 10),
              const Text(
                'The node adapter must perform ML-KEM/X25519 envelope encryption and ML-DSA receipt verification. This queue only coordinates references.',
                style: TextStyle(color: _subtext, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              cid.text,
              sender.text,
              signature.text,
              recipient.text,
              editId.text,
            )),
            child: const Text('Queue handoff'),
          ),
        ],
      ),
    );
    cid.dispose();
    sender.dispose();
    signature.dispose();
    recipient.dispose();
    editId.dispose();
    if (values == null || !mounted) return;
    try {
      final envelope = NazaAgentEnvelope(
        id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
        poolId: pool.id,
        kind: NazaAgentEnvelopeKind.handoff,
        senderBondKeyId: values.$2,
        ciphertextCid: values.$1,
        signatureKeyId: values.$3,
        recipientBondKeyId: values.$4.trim().isEmpty ? null : values.$4,
        editId: values.$5.trim().isEmpty ? null : values.$5,
        sequence: _agentEnvelopes.length,
        createdAt: DateTime.now().toUtc(),
      );
      final errors = envelope.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(' '));
      if (widget.persistState) await _collaborationStore.postEnvelope(envelope);
      setState(() {
        _agentEnvelopes = <NazaAgentEnvelope>[..._agentEnvelopes, envelope];
        _status = 'Encrypted handoff reference queued · ${pool.peerGroup}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not queue handoff: $error');
    }
  }

  NazaChatRoom? get _activeChatRoom {
    for (final room in _chatRooms) {
      if (room.state == NazaChatRoomState.active) return room;
    }
    return null;
  }

  Future<void> _createChatRoom() async {
    final name = TextEditingController(text: 'Encrypted human room');
    final topic = TextEditingController(text: 'naza-chat/v1/human-room');
    final peers = TextEditingController(text: 'local-only');
    final relay = TextEditingController();
    var kind = NazaChatRoomKind.human;
    var publicDiscovery = false;
    var publicExposureApproved = false;
    final room = await showDialog<NazaChatRoom?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'Create encrypted IPFS chatroom',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<NazaChatRoomKind>(
                    segments: const [
                      ButtonSegment(
                        value: NazaChatRoomKind.human,
                        label: Text('Human room'),
                        icon: Icon(Icons.people_alt_rounded),
                      ),
                      ButtonSegment(
                        value: NazaChatRoomKind.agent,
                        label: Text('Agent room'),
                        icon: Icon(Icons.smart_toy_rounded),
                      ),
                    ],
                    selected: <NazaChatRoomKind>{kind},
                    onSelectionChanged: (value) =>
                        setDialogState(() => kind = value.first),
                  ),
                  const SizedBox(height: 12),
                  _dialogField(name, 'Room name'),
                  const SizedBox(height: 10),
                  _dialogField(topic, 'IPFS PubSub topic', monospace: true),
                  const SizedBox(height: 10),
                  _dialogField(peers, 'Trusted peer group'),
                  const SizedBox(height: 10),
                  _dialogField(relay, 'DigitalOcean relay node ID (optional)'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Publicly discoverable room',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'Off by default; private rooms still use encrypted IPFS envelopes.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: publicDiscovery,
                    activeTrackColor: _rose,
                    onChanged: (value) => setDialogState(() {
                      publicDiscovery = value;
                      if (!value) publicExposureApproved = false;
                    }),
                  ),
                  if (publicDiscovery)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I approve public room discovery',
                        style: TextStyle(color: _text, fontSize: 13),
                      ),
                      value: publicExposureApproved,
                      activeColor: _rose,
                      onChanged: (value) => setDialogState(
                        () => publicExposureApproved = value == true,
                      ),
                    ),
                  const Text(
                    'Kubo PubSub is transport only: messages are encrypted before publishing, and the Kubo RPC port must remain private to the adapter. IPFS PubSub is not treated as durable history; encrypted CIDs provide replayable history.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final next = NazaChatRoom(
                    id: 'room-${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text,
                    kind: kind,
                    topic: topic.text,
                    peerGroup: peers.text,
                    relayNodeId: relay.text.trim().isEmpty ? null : relay.text,
                    publicDiscovery: publicDiscovery,
                    publicExposureApproved: publicExposureApproved,
                    createdAt: DateTime.now().toUtc(),
                  );
                  final errors = next.validate();
                  if (errors.isNotEmpty)
                    throw FormatException(errors.join(' '));
                  Navigator.pop(dialogContext, next);
                } catch (error) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('Seal chatroom'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    topic.dispose();
    peers.dispose();
    relay.dispose();
    if (room == null || !mounted) return;
    try {
      final monitor = NazaChatRoomMonitorSnapshot(
        roomId: room.id,
        linkState: NazaIpfsChatLinkState.offline,
        observedAt: DateTime.now().toUtc(),
        lastError: 'No IPFS adapter attached; no network probe performed.',
      );
      if (widget.persistState) {
        await _chatRoomStore.saveRoom(room);
        await _chatRoomStore.saveMonitor(monitor);
      }
      setState(() {
        _chatRooms = <NazaChatRoom>[..._chatRooms, room];
        _chatMonitors[room.id] = monitor;
        _chatMessages[room.id] = const <NazaChatMessageEnvelope>[];
        _status = '${room.kind.label} sealed · IPFS adapter pending';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save chatroom: $error');
    }
  }

  Future<void> _queueChatEnvelope() async {
    final room = _activeChatRoom;
    if (room == null) {
      setState(() => _status = 'Create an active human or agent room first');
      return;
    }
    final cid = TextEditingController();
    final sender = TextEditingController();
    final aad = TextEditingController();
    final signature = TextEditingController();
    final replyTo = TextEditingController();
    final attachments = TextEditingController();
    final values =
        await showDialog<(String, String, String, String, String, String)?>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: _panel,
            title: Text(
              'Queue sealed ${room.kind.label.toLowerCase()} envelope',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(cid, 'Encrypted message CID'),
                    const SizedBox(height: 10),
                    _dialogField(
                      sender,
                      'Sender identity / bond public-key ID',
                    ),
                    const SizedBox(height: 10),
                    _dialogField(
                      aad,
                      'AAD digest sha256:<hex>',
                      monospace: true,
                    ),
                    const SizedBox(height: 10),
                    _dialogField(signature, 'Signature public-key ID'),
                    const SizedBox(height: 10),
                    _dialogField(replyTo, 'Reply envelope ID (optional)'),
                    const SizedBox(height: 10),
                    _dialogField(
                      attachments,
                      'Encrypted attachment CIDs (comma-separated)',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Plaintext is intentionally absent from this form. A PQ chat adapter seals the message and pins the ciphertext before this envelope is admitted to room history.',
                      style: TextStyle(color: _subtext, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, (
                  cid.text,
                  sender.text,
                  aad.text,
                  signature.text,
                  replyTo.text,
                  attachments.text,
                )),
                child: const Text('Queue envelope'),
              ),
            ],
          ),
        );
    cid.dispose();
    sender.dispose();
    aad.dispose();
    signature.dispose();
    replyTo.dispose();
    attachments.dispose();
    if (values == null || !mounted) return;
    try {
      final envelope = NazaChatMessageEnvelope(
        id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
        roomId: room.id,
        senderId: values.$2,
        senderKind: room.kind,
        ciphertextCid: values.$1,
        aadDigest: values.$3,
        signatureKeyId: values.$4,
        sequence: _chatMessages[room.id]?.length ?? 0,
        replyTo: values.$5.trim().isEmpty ? null : values.$5,
        attachmentCids: values.$6
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        createdAt: DateTime.now().toUtc(),
      );
      final errors = envelope.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(' '));
      if (widget.persistState) await _chatRoomStore.appendMessage(envelope);
      setState(() {
        final current =
            _chatMessages[room.id] ?? const <NazaChatMessageEnvelope>[];
        _chatMessages[room.id] = <NazaChatMessageEnvelope>[
          ...current,
          envelope,
        ];
        _status = '${room.kind.label} envelope queued · ciphertext only';
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not queue chat envelope: $error');
    }
  }

  Future<void> _recordChatMonitorBoundary(NazaChatRoom room) async {
    final monitor = NazaChatRoomMonitorSnapshot(
      roomId: room.id,
      linkState: NazaIpfsChatLinkState.offline,
      connectedPeers: 0,
      subscribed: false,
      backlog: _chatMessages[room.id]?.length ?? 0,
      relayNodeId: room.relayNodeId,
      observedAt: DateTime.now().toUtc(),
      lastError: 'Adapter probe not installed; no Kubo RPC call was made.',
    );
    if (widget.persistState) {
      try {
        await _chatRoomStore.saveMonitor(monitor);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _chatMonitors[room.id] = monitor;
      _status = '${room.name}: monitor boundary recorded';
    });
  }

  Future<void> _requestIpfsRelay() async {
    final name = TextEditingController(text: 'naza-ipfs-chat-relay');
    final region = TextEditingController(text: 'nyc3');
    final size = TextEditingController(text: 's-2vcpu-4gb');
    final image = TextEditingController(text: 'ubuntu-24-04-x64');
    final peerGroup = TextEditingController(text: 'agentic-mesh');
    var publicNetworking = false;
    final values = await showDialog<(String, String, String, String, String, bool)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'Request DigitalOcean IPFS relay',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(name, 'Droplet name'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _dialogField(region, 'Region')),
                      const SizedBox(width: 10),
                      Expanded(child: _dialogField(size, 'Size')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField(image, 'Base image slug / ID'),
                  const SizedBox(height: 10),
                  _dialogField(peerGroup, 'IPFS peer group tag'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Public swarm networking',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'Off by default. A relay adapter must expose only the swarm path it needs; Kubo RPC stays private.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: publicNetworking,
                    activeTrackColor: _rose,
                    onChanged: (value) =>
                        setDialogState(() => publicNetworking = value),
                  ),
                  const Text(
                    'This queues a DigitalOcean droplet plan with IPFS relay intent. Kubo installation, firewalling, key exchange, and health probes require a separately attested adapter.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                name.text,
                region.text,
                size.text,
                image.text,
                peerGroup.text,
                publicNetworking,
              )),
              child: const Text('Seal relay request'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    region.dispose();
    size.dispose();
    image.dispose();
    peerGroup.dispose();
    if (values == null || !mounted) return;
    try {
      final plan = NazaDigitalOceanDropletPlan(
        name: values.$1,
        region: values.$2,
        size: values.$3,
        image: values.$4,
        publicNetworking: values.$6,
        tags: <String>['naza-ipfs-relay', values.$5],
        workspacePurpose: 'ipfs-relay',
      );
      final errors = plan.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join(' '));
      await _appendRemoteOperation(
        NazaRemoteOperationRequest.digitalOcean(
          id: 'op-${DateTime.now().microsecondsSinceEpoch}',
          plan: plan,
        ),
      );
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not queue IPFS relay: $error');
    }
  }

  Future<void> _setKuboEnabled(bool enabled) async {
    final next = _kuboSettings.copyWith(enabled: enabled);
    final errors = next.validate();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.join(' '));
      return;
    }
    if (widget.persistState) {
      try {
        await _kuboSettingsStore.save(next);
      } catch (error) {
        if (mounted)
          setState(() => _error = 'Could not persist Kubo setting: $error');
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _kuboSettings = next;
      _status = enabled
          ? 'Kubo backend enabled · client starts only on explicit room dispatch'
          : 'Kubo backend disabled · no client or socket loaded';
    });
  }

  Future<void> _configureKubo() async {
    final api = TextEditingController(text: _kuboSettings.apiBaseUrl);
    final gateway = TextEditingController(text: _kuboSettings.gatewayBaseUrl);
    final binary = TextEditingController(text: _kuboSettings.binaryPath);
    final remote = TextEditingController(
      text: _kuboSettings.remoteNodeId ?? '',
    );
    var serverProfile = _kuboSettings.serverProfile;
    var pubSubEnabled = _kuboSettings.pubSubEnabled;
    final values = await showDialog<(String, String, String, String, bool, bool)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'Configure Dart / Kubo backend',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    api,
                    'Kubo RPC endpoint (loopback/tunnel only)',
                    monospace: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    gateway,
                    'Kubo gateway endpoint (loopback/tunnel only)',
                    monospace: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(binary, 'Go/Kubo binary path', monospace: true),
                  const SizedBox(height: 10),
                  _dialogField(remote, 'Remote node ID (optional)'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Use Kubo server profile',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'Recommended for cloud/VPS nodes; the app does not start the daemon.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: serverProfile,
                    activeTrackColor: _mint,
                    onChanged: (value) =>
                        setDialogState(() => serverProfile = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Kubo PubSub transport',
                      style: TextStyle(color: _text),
                    ),
                    subtitle: const Text(
                      'PubSub is experimental; durable history remains encrypted CID storage.',
                      style: TextStyle(color: _subtext, fontSize: 11),
                    ),
                    value: pubSubEnabled,
                    activeTrackColor: _cyan,
                    onChanged: (value) =>
                        setDialogState(() => pubSubEnabled = value),
                  ),
                  const Text(
                    'Strict boundary: Kubo RPC is an administrative API and must not be exposed publicly. Use a loopback endpoint or a separately secured SSH tunnel to a DigitalOcean relay.',
                    style: TextStyle(color: _subtext, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                api.text,
                gateway.text,
                binary.text,
                remote.text,
                serverProfile,
                pubSubEnabled,
              )),
              child: const Text('Save Kubo settings'),
            ),
          ],
        ),
      ),
    );
    api.dispose();
    gateway.dispose();
    binary.dispose();
    remote.dispose();
    if (values == null || !mounted) return;
    final next = _kuboSettings.copyWith(
      apiBaseUrl: values.$1,
      gatewayBaseUrl: values.$2,
      binaryPath: values.$3,
      remoteNodeId: values.$4.trim().isEmpty ? null : values.$4,
      clearRemoteNodeId: values.$4.trim().isEmpty,
      serverProfile: values.$5,
      pubSubEnabled: values.$6,
    );
    final errors = next.validate();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.join(' '));
      return;
    }
    try {
      if (widget.persistState) await _kuboSettingsStore.save(next);
      if (!mounted) return;
      setState(() {
        _kuboSettings = next;
        _status = 'Kubo settings sealed · enabled remains ${next.enabled}';
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not save Kubo settings: $error');
    }
  }

  void _validNodeReferenceForDialog(String value) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$').hasMatch(value.trim())) {
      throw const FormatException('Enter a valid droplet or node ID.');
    }
  }

  void _replaceNode(NazaAgenticNodeProfile replacement, {bool select = false}) {
    _updateConfig(
      _config.copyWith(
        nodes: <NazaAgenticNodeProfile>[
          for (final node in _config.nodes)
            if (node.id == replacement.id) replacement else node,
        ],
        activeNodeId: select ? replacement.id : _config.activeNodeId,
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool monospace = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(
        color: _text,
        fontFamily: monospace ? 'JetBrainsMono' : null,
        fontSize: monospace ? 12 : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _subtext),
        filled: true,
        fillColor: _ink,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cyan),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ink,
      child: Stack(
        children: [
          const Positioned.fill(child: _FoundryBackdrop()),
          SafeArea(
            top: false,
            child: ListView(
              key: const ValueKey<String>('agentic-code-foundry'),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 56),
              children: [
                _buildHero(),
                const SizedBox(height: 16),
                _buildPipeline(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final controls = Column(
                      children: [
                        _buildModelFabric(),
                        const SizedBox(height: 14),
                        _buildTargetFabric(),
                        const SizedBox(height: 14),
                        _buildContextFabric(),
                      ],
                    );
                    final composer = Column(
                      children: [
                        _buildComposer(),
                        const SizedBox(height: 14),
                        _buildCapabilityGate(),
                      ],
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          controls,
                          const SizedBox(height: 14),
                          composer,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 10, child: controls),
                        const SizedBox(width: 14),
                        Expanded(flex: 11, child: composer),
                      ],
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _NoticeCard(
                    icon: Icons.gpp_bad_rounded,
                    color: _rose,
                    title: 'Policy / runtime notice',
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                ],
                if (_lastPolicy?.warnings.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  _NoticeCard(
                    icon: Icons.science_outlined,
                    color: _amber,
                    title: 'Interpretation boundary',
                    message: _lastPolicy!.warnings.join(' '),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  _buildResult(_result!),
                  const SizedBox(height: 18),
                  const NazaCodeWorkbench(),
                ],
                const SizedBox(height: 18),
                _buildRemoteOperations(),
                const SizedBox(height: 18),
                _buildCollaborationQueues(),
                const SizedBox(height: 18),
                _buildIpfsChatrooms(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _violet.withValues(alpha: 0.48)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MicroLabel('EXECUTION INTELLIGENCE / CODE FOUNDRY'),
              const SizedBox(height: 8),
              Text(
                'Agentic Code Foundry',
                style: TextStyle(
                  color: _text,
                  fontSize: compact ? 29 : 38,
                  height: 1,
                  letterSpacing: -1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'A visual, local-first coding control plane for evidence, model assemblies, encrypted memory, and approval-gated execution targets.',
                style: TextStyle(color: _subtext, height: 1.45, fontSize: 14),
              ),
            ],
          );
          final badges = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: const [
              _StatusBadge('LOCAL GEMMA DEFAULT', _mint),
              _StatusBadge('AES-GCM VAULT', _cyan),
              _StatusBadge('ML-KEM-1024 RECOVERY', _violet),
              _StatusBadge('HUMAN APPROVAL', _amber),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), badges],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: title),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: badges),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPipeline() {
    const stages = <(IconData, String, String, Color)>[
      (Icons.radar_rounded, '01', 'CONTEXT', _cyan),
      (Icons.call_split_rounded, '02', 'DIVERGE', _violet),
      (Icons.balance_rounded, '03', 'WEIGH', _amber),
      (Icons.merge_type_rounded, '04', 'SYNTHESIZE', _mint),
      (Icons.verified_rounded, '05', 'VERIFY', _rose),
    ];
    return _FoundryCard(
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stages
              .map(
                (stage) => SizedBox(
                  width: math.max(142, (constraints.maxWidth - 32) / 5),
                  child: _PipelineStage(
                    icon: stage.$1,
                    index: stage.$2,
                    label: stage.$3,
                    color: stage.$4,
                    active: _running || stage.$2 == '01',
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildModelFabric() {
    return _FoundrySection(
      icon: Icons.hub_rounded,
      title: 'Model assembly fabric',
      subtitle: 'Choose one reasoning topology for this coding run.',
      trailing: _loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _cyan),
            )
          : null,
      child: Column(
        children: [
          for (final mode in NazaAgenticModelMode.values)
            _SelectionTile(
              title: mode.label,
              subtitle: mode.description,
              selected: _config.modelMode == mode,
              color: switch (mode) {
                NazaAgenticModelMode.localGemma => _mint,
                NazaAgenticModelMode.routedProvider => _cyan,
                NazaAgenticModelMode.shardedFabric => _violet,
              },
              onTap: _running
                  ? null
                  : () => _updateConfig(_config.copyWith(modelMode: mode)),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetFabric() {
    return _FoundrySection(
      icon: Icons.dns_rounded,
      title: 'Execution envelope lattice',
      subtitle:
          'Profiles describe boundaries. No shell, Docker, or SSH action runs implicitly.',
      trailing: IconButton.filledTonal(
        key: const ValueKey<String>('add-remote-node'),
        tooltip: 'Add encrypted SSH node',
        onPressed: _running ? null : _addRemoteNode,
        icon: const Icon(Icons.add_link_rounded),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _running ? null : _requestEnvironment,
              icon: const Icon(Icons.rocket_launch_rounded, size: 17),
              label: const Text('Request environment'),
            ),
          ),
          for (final node in _config.nodes)
            _NodeTile(
              node: node,
              selected: _config.activeNodeId == node.id,
              onSelect: node.enabled && !_running
                  ? () => _updateConfig(_config.copyWith(activeNodeId: node.id))
                  : null,
              onConfigure: node.kind == NazaExecutionTargetKind.ociContainer
                  ? () => _configureContainer(node)
                  : null,
              onRemove: node.kind == NazaExecutionTargetKind.remoteSsh
                  ? () => _removeRemoteNode(node)
                  : null,
              state: _nodeStates[node.id],
              onStart: () => _requestNodeAction(node, 'start'),
              onStop: () => _requestNodeAction(node, 'stop'),
            ),
        ],
      ),
    );
  }

  Widget _buildContextFabric() {
    return _FoundrySection(
      icon: Icons.layers_rounded,
      title: 'Multimodal context fabric',
      subtitle: 'Only explicitly attached evidence crosses into the model run.',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final modality in NazaAgenticModality.values)
                ChoiceChip(
                  label: Text(modality.label),
                  selected: _config.modality == modality,
                  selectedColor: _cyan.withValues(alpha: 0.22),
                  backgroundColor: _ink,
                  side: BorderSide(
                    color: _config.modality == modality ? _cyan : _border,
                  ),
                  labelStyle: TextStyle(
                    color: _config.modality == modality ? _text : _subtext,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: _running
                      ? null
                      : (_) =>
                            _updateConfig(_config.copyWith(modality: modality)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_config.modality == NazaAgenticModality.repository)
            _EvidenceAction(
              icon: Icons.folder_open_rounded,
              color: _cyan,
              title: _repository == null
                  ? 'Select a repository'
                  : _basename(_repository!.root),
              subtitle: _repository == null
                  ? 'Read-only · no symlinks · key/database filters · bounded bytes'
                  : '${_repository!.files.length} files · ${_formatBytes(_repository!.bytes)} · ${_repository!.excludedEntries} excluded${_repository!.truncated ? ' · bounded' : ''}',
              actionLabel: _indexing ? 'INDEXING' : 'INDEX',
              busy: _indexing,
              onTap: _indexing || _running ? null : _chooseRepository,
            )
          else if (_config.modality == NazaAgenticModality.vision)
            _EvidenceAction(
              icon: Icons.image_search_rounded,
              color: _violet,
              title: _attachment?.name ?? 'Attach one coding image',
              subtitle: _attachment == null
                  ? 'Diagram, screenshot, UI state, or error surface · local vision only'
                  : '${_attachment!.dimensions} · ${_formatBytes(_attachment!.bytes.length)}',
              actionLabel: 'ATTACH',
              onTap: _running ? null : _pickAttachment,
            )
          else
            const _EvidenceAction(
              icon: Icons.short_text_rounded,
              color: _mint,
              title: 'Intent-only context',
              subtitle:
                  'No filesystem or image evidence will be attached to this run.',
              actionLabel: 'PRIVATE',
            ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Encrypted embedding memory',
              style: TextStyle(color: _text, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Retrieve and index through the in-house encrypted vector memory.',
              style: TextStyle(color: _subtext, fontSize: 12),
            ),
            value: _config.memoryEnabled,
            activeTrackColor: _mint,
            onChanged: _running
                ? null
                : (value) =>
                      _updateConfig(_config.copyWith(memoryEnabled: value)),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteOperations() {
    final recent = _operations.reversed.take(6).toList(growable: false);
    final awaiting = _operations
        .where(
          (operation) =>
              operation.state == NazaRemoteOperationState.awaitingApproval,
        )
        .length;
    final approved = _operations
        .where(
          (operation) => operation.state == NazaRemoteOperationState.approved,
        )
        .length;
    final failed = _operations
        .where(
          (operation) => operation.state == NazaRemoteOperationState.failed,
        )
        .length;
    return _FoundrySection(
      icon: Icons.public_rounded,
      title: 'Remote operations control plane',
      subtitle:
          'Compose bounded DigitalOcean, Chromium, and IPFS intents. Every network or mutation action stays queued until a trusted adapter and fresh approval exist.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _StatusBadge('AWAITING $awaiting', _amber),
              _StatusBadge('APPROVED $approved', _mint),
              _StatusBadge('FAILED $failed', failed == 0 ? _subtext : _rose),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey<String>('request-digitalocean-environment'),
                onPressed: _running ? null : _requestEnvironment,
                icon: const Icon(Icons.cloud_queue_rounded, size: 17),
                label: const Text('DigitalOcean droplet'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('request-chromium-scrape'),
                onPressed: _running ? null : _requestChromiumScrape,
                icon: const Icon(Icons.travel_explore_rounded, size: 17),
                label: const Text('Chromium scrape'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('request-ipfs-publish'),
                onPressed: _running ? null : _requestIpfsPublish,
                icon: const Icon(Icons.hub_outlined, size: 17),
                label: const Text('IPFS publish'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('request-scrape-ipfs-export'),
                onPressed: _running ? null : _requestScrapeExport,
                icon: const Icon(Icons.output_rounded, size: 17),
                label: const Text('Scrape → IPFS'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('manage-digitalocean-droplet'),
                onPressed: _running ? null : _requestDigitalOceanAction,
                icon: const Icon(Icons.settings_ethernet_rounded, size: 17),
                label: const Text('Manage DO droplet'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const _EvidenceAction(
              icon: Icons.lock_clock_rounded,
              color: _cyan,
              title: 'No remote requests sealed',
              subtitle:
                  'The queue is empty. Operation history stores plans and references only—not tokens, keys, cookies, commands, or scraped content.',
              actionLabel: 'SEALED',
            )
          else ...[
            const _MicroLabel('RECENT REQUEST QUEUE'),
            const SizedBox(height: 8),
            for (final operation in recent)
              _RemoteOperationTile(
                operation: operation,
                onApprove:
                    operation.state == NazaRemoteOperationState.awaitingApproval
                    ? () => _approveRemoteOperation(operation)
                    : null,
                onCancel:
                    operation.state ==
                            NazaRemoteOperationState.awaitingApproval ||
                        operation.state == NazaRemoteOperationState.approved
                    ? () => _cancelRemoteOperation(operation)
                    : null,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollaborationQueues() {
    final pool = _activeCollaborationPool;
    final edits = _queuedEdits.reversed.take(5).toList(growable: false);
    return _FoundrySection(
      icon: Icons.groups_2_rounded,
      title: 'MMO coding collaboration queues',
      subtitle:
          'Turn a large goal into non-overlapping file-sector claims. Agents exchange encrypted handoff references through the selected node/IPFS peer group and return signed receipts for review.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey<String>('create-collaboration-pool'),
                onPressed: _running ? null : _createCollaborationPool,
                icon: const Icon(Icons.add_chart_rounded, size: 17),
                label: const Text('Create pool'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('queue-collaborative-edit'),
                onPressed: _running ? null : _enqueueCollaborativeEdit,
                icon: const Icon(Icons.playlist_add_rounded, size: 17),
                label: const Text('Queue edit'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('queue-agent-handoff'),
                onPressed: _running ? null : _postAgentEnvelope,
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: const Text('Agent handoff'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pool == null)
            const _EvidenceAction(
              icon: Icons.account_tree_outlined,
              color: _violet,
              title: 'No active collaboration pool',
              subtitle:
                  'Create a pool with a workspace fingerprint before agents can claim edits or exchange envelopes.',
              actionLabel: 'WAITING',
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _violet.withValues(alpha: 0.42)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hub_rounded, color: _violet, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${pool.name} · ${pool.peerGroup} · max ${pool.maxConcurrentEdits} claims · ${pool.bondSuite}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _subtext, fontSize: 11),
                    ),
                  ),
                  _TinyState(pool.state.label, _mint),
                ],
              ),
            ),
            const SizedBox(height: 9),
            if (edits.isEmpty)
              const Text(
                'No edit claims yet. Queue the first bounded file-sector task.',
                style: TextStyle(color: _subtext, fontSize: 11),
              )
            else
              for (final edit in edits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                    tileColor: _ink.withValues(alpha: 0.68),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                      side: const BorderSide(color: _border),
                    ),
                    leading: const Icon(
                      Icons.code_rounded,
                      color: _cyan,
                      size: 19,
                    ),
                    title: Text(
                      '${edit.relativePath} · ${edit.sector}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      edit.goal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _subtext, fontSize: 10),
                    ),
                    trailing: _TinyState(edit.state.label, _cyan),
                  ),
                ),
            Text(
              '${_agentEnvelopes.length} encrypted handoff reference${_agentEnvelopes.length == 1 ? '' : 's'} queued · source payloads remain outside the queue',
              style: const TextStyle(color: _subtext, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIpfsChatrooms() {
    final activeRoom = _activeChatRoom;
    return _FoundrySection(
      icon: Icons.forum_rounded,
      title: 'Encrypted IPFS chatroom monitor',
      subtitle:
          'Human and agent rooms use separate room identities, encrypted CID envelopes, PQ bond references, and observational peer health.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _kuboSettings.enabled ? _mint : _border,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  key: const ValueKey<String>('enable-kubo-backend'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Dart / Go Kubo backend',
                    style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _kuboSettings.enabled
                        ? 'Enabled · client is created only when an approved room dispatches.'
                        : 'Disabled by default · no Kubo client, process, socket, or RPC call is loaded.',
                    style: const TextStyle(color: _subtext, fontSize: 11),
                  ),
                  value: _kuboSettings.enabled,
                  activeTrackColor: _mint,
                  onChanged: _running ? null : _setKuboEnabled,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_kuboSettings.apiBaseUrl} · ${_kuboSettings.pubSubEnabled ? 'PubSub configured' : 'PubSub off'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _subtext,
                          fontSize: 10,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _running ? null : _configureKubo,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Configure'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey<String>('create-ipfs-chatroom'),
                onPressed: _running ? null : _createChatRoom,
                icon: const Icon(Icons.forum_outlined, size: 17),
                label: const Text('Create room'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('queue-ipfs-envelope'),
                onPressed: _running ? null : _queueChatEnvelope,
                icon: const Icon(Icons.lock_rounded, size: 17),
                label: const Text('Queue sealed message'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('request-ipfs-relay'),
                onPressed: _running ? null : _requestIpfsRelay,
                icon: const Icon(Icons.cloud_sync_rounded, size: 17),
                label: const Text('DO relay'),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (_chatRooms.isEmpty)
            const _EvidenceAction(
              icon: Icons.forum_outlined,
              color: _cyan,
              title: 'No chatrooms sealed',
              subtitle:
                  'Create a human or agent room. The monitor begins offline and only an approved Kubo adapter can move it online.',
              actionLabel: 'PRIVATE',
            )
          else
            for (final room in _chatRooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _ink.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        room.kind == NazaChatRoomKind.human
                            ? Icons.people_alt_rounded
                            : Icons.smart_toy_rounded,
                        color: room.kind == NazaChatRoomKind.human
                            ? _cyan
                            : _violet,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${room.name} · ${room.kind.label}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${room.peerGroup} · ${_chatMessages[room.id]?.length ?? 0} ciphertext envelopes · ${room.publicDiscovery ? 'public-approved' : 'private'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _subtext,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TinyState(
                        (_chatMonitors[room.id]?.linkState ??
                                NazaIpfsChatLinkState.offline)
                            .label,
                        _chatMonitors[room.id]?.linkState ==
                                NazaIpfsChatLinkState.online
                            ? _mint
                            : _amber,
                      ),
                      IconButton(
                        tooltip: 'Record adapter monitor boundary',
                        onPressed: _running
                            ? null
                            : () => _recordChatMonitorBoundary(room),
                        icon: const Icon(
                          Icons.monitor_heart_outlined,
                          size: 18,
                        ),
                        color: _subtext,
                      ),
                    ],
                  ),
                ),
              ),
          if (activeRoom != null)
            Text(
              'Active room: ${activeRoom.name} · topic ${activeRoom.topic} · Kubo RPC remains ${_kuboSettings.enabled ? 'opt-in and adapter-gated' : 'disabled'}',
              style: const TextStyle(color: _subtext, fontSize: 10.5),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return _FoundrySection(
      icon: Icons.architecture_rounded,
      title: 'Intent compiler',
      subtitle:
          'Describe the outcome. The model returns evidence, a patch proposal, and checks—not an unverified completion claim.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey<String>('agentic-task-input'),
            controller: _taskController,
            focusNode: _taskFocus,
            enabled: !_running,
            minLines: 7,
            maxLines: 16,
            maxLength: NazaAgenticTaskRequest.maxTaskCharacters,
            style: const TextStyle(color: _text, fontSize: 14, height: 1.45),
            decoration: InputDecoration(
              filled: true,
              fillColor: _ink.withValues(alpha: 0.88),
              hintText:
                  'Example: trace the authentication flow, isolate the race, propose the smallest patch, and define rollback checks…',
              hintStyle: const TextStyle(color: _subtext),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _violet, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey<String>('run-agentic-task'),
              style: FilledButton.styleFrom(
                backgroundColor: _violet,
                foregroundColor: const Color(0xFF100D1D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _running || _indexing ? null : _run,
              icon: _running
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF100D1D),
                      ),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                _running ? 'WEAVING EVIDENCE' : 'COMPILE AGENTIC RUN',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _running ? Icons.sync_rounded : Icons.shield_outlined,
                color: _running ? _cyan : _mint,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: _subtext,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityGate() {
    final remote = _config.activeNode.kind == NazaExecutionTargetKind.remoteSsh;
    return _FoundrySection(
      icon: Icons.policy_rounded,
      title: 'Capability gate',
      subtitle:
          'Model reasoning and host capabilities are separate. Elevated surfaces require a per-run acknowledgement.',
      child: Column(
        children: [
          _CapabilityToggle(
            title: 'Generate a reviewable patch proposal',
            subtitle: 'Produces text/diff only; never writes files.',
            value: _proposePatch,
            color: _mint,
            onChanged: _running
                ? null
                : (value) => setState(() => _proposePatch = value),
          ),
          _CapabilityToggle(
            title: 'Request check execution capability',
            subtitle:
                'Reserved for a future verified adapter; requires mutation approval.',
            value: _runChecks,
            color: _amber,
            onChanged: _running
                ? null
                : (value) => setState(() {
                    _runChecks = value;
                    if (!value) _mutationApproved = false;
                  }),
          ),
          _CapabilityToggle(
            title: 'Request network capability',
            subtitle: remote
                ? 'Required by the selected SSH node; no connection is automatic.'
                : 'Disabled by default for local and container planning.',
            value: _allowNetwork || remote,
            color: _rose,
            onChanged: _running || remote
                ? null
                : (value) => setState(() {
                    _allowNetwork = value;
                    if (!value) _networkApproved = false;
                  }),
          ),
          if (_runChecks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _mutationApproved,
              activeColor: _amber,
              title: const Text(
                'I approve the check capability for this run',
                style: TextStyle(color: _text, fontSize: 13),
              ),
              onChanged: _running
                  ? null
                  : (value) =>
                        setState(() => _mutationApproved = value == true),
            ),
          if (_allowNetwork || remote)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _networkApproved,
              activeColor: _rose,
              title: const Text(
                'I approve network / remote capability for this run',
                style: TextStyle(color: _text, fontSize: 13),
              ),
              onChanged: _running
                  ? null
                  : (value) => setState(() => _networkApproved = value == true),
            ),
          const Divider(color: _border, height: 22),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_clock_rounded, color: _cyan, size: 18),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Strict boundary: this release invokes model synthesis only. Native command/container/SSH adapters must independently attest their sandbox before execution can be enabled.',
                  style: TextStyle(color: _subtext, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult(NazaAgenticRunResult result) {
    return _FoundrySection(
      icon: Icons.account_tree_rounded,
      title: 'Assembly result & evidence telemetry',
      subtitle:
          result.fallbackReason ??
          '${result.contributions.length} contribution${result.contributions.length == 1 ? '' : 's'} · ${result.memoryIndexed ? 'encrypted memory indexed' : 'memory not indexed'}',
      trailing: IconButton(
        tooltip: 'Copy synthesis',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: result.text));
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Synthesis copied')));
          }
        },
        icon: const Icon(Icons.copy_all_rounded, color: _subtext),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final telemetry = _TelemetryGrid(snapshot: result.weave);
              final radar = SizedBox(
                height: 220,
                child: _EntropyRadar(snapshot: result.weave),
              );
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [telemetry, const SizedBox(height: 10), radar],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: telemetry),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: radar),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: MarkdownBody(
              data: result.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: _text, height: 1.5, fontSize: 13.5),
                h1: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
                h2: const TextStyle(
                  color: _mint,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
                h3: const TextStyle(
                  color: _cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                code: const TextStyle(
                  color: Color(0xFFD8FFF0),
                  backgroundColor: Color(0xFF142722),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF081310),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                listBullet: const TextStyle(color: _violet),
                blockquote: const TextStyle(color: _subtext, height: 1.45),
                blockquoteDecoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: _violet, width: 3)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _MicroLabel('PROVENANCE LATTICE'),
          const SizedBox(height: 9),
          for (final entry in result.provenance) _ProvenanceTile(entry: entry),
          const SizedBox(height: 10),
          const Text(
            'Entropy weave values are normalized lexical/disagreement diagnostics. They are not cryptographic entropy, model confidence, correctness, or quantum advantage.',
            style: TextStyle(color: _subtext, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((part) => part.isNotEmpty).last;

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '$bytes B';
  }
}

class _FoundryBackdrop extends StatelessWidget {
  const _FoundryBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _FoundryBackdropPainter()),
    );
  }
}

class _FoundryBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x0D62D9F7)
      ..strokeWidth = 1;
    const step = 72.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x2AAA93FF), Color(0x006210A0)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.84, 80),
              radius: math.min(420, size.width * 0.42),
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.84, 80),
      math.min(420, size.width * 0.42),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FoundryCard extends StatelessWidget {
  const _FoundryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _NazaAgenticCodingSurfaceState._panel.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _NazaAgenticCodingSurfaceState._border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _FoundrySection extends StatelessWidget {
  const _FoundrySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _FoundryCard(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _NazaAgenticCodingSurfaceState._violet.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: _NazaAgenticCodingSurfaceState._violet,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _NazaAgenticCodingSurfaceState._text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _NazaAgenticCodingSurfaceState._subtext,
                          height: 1.35,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }
}

class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _NazaAgenticCodingSurfaceState._cyan,
        fontFamily: 'JetBrainsMono',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStage extends StatelessWidget {
  const _PipelineStage({
    required this.icon,
    required this.index,
    required this.label,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final String index;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Text(
            index,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _NazaAgenticCodingSurfaceState._text,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.12)
            : _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color
                    : _NazaAgenticCodingSurfaceState._border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? color
                      : _NazaAgenticCodingSurfaceState._subtext,
                  size: 19,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _NazaAgenticCodingSurfaceState._text,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _NazaAgenticCodingSurfaceState._subtext,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteOperationTile extends StatelessWidget {
  const _RemoteOperationTile({
    required this.operation,
    this.onApprove,
    this.onCancel,
  });

  final NazaRemoteOperationRequest operation;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final color = switch (operation.kind) {
      NazaRemoteOperationKind.digitalOceanDroplet =>
        _NazaAgenticCodingSurfaceState._cyan,
      NazaRemoteOperationKind.chromiumScrape =>
        _NazaAgenticCodingSurfaceState._violet,
      NazaRemoteOperationKind.ipfsPublish ||
      NazaRemoteOperationKind.ipfsFetch => _NazaAgenticCodingSurfaceState._mint,
      NazaRemoteOperationKind.scrapeExportIpfs =>
        _NazaAgenticCodingSurfaceState._mint,
      NazaRemoteOperationKind.nodeDelete ||
      NazaRemoteOperationKind.digitalOceanDropletDelete =>
        _NazaAgenticCodingSurfaceState._rose,
      NazaRemoteOperationKind.nodeStart ||
      NazaRemoteOperationKind.digitalOceanDropletStart =>
        _NazaAgenticCodingSurfaceState._mint,
      NazaRemoteOperationKind.nodeStop ||
      NazaRemoteOperationKind.digitalOceanDropletStop =>
        _NazaAgenticCodingSurfaceState._amber,
    };
    final detail = switch (operation.kind) {
      NazaRemoteOperationKind.digitalOceanDroplet =>
        '${operation.droplet!.region} · ${operation.droplet!.size} · ${operation.droplet!.image}',
      NazaRemoteOperationKind.chromiumScrape =>
        '${operation.scrape!.targetUrl} · ${operation.scrape!.maxPages} pages · ${operation.scrape!.outputFormat}${operation.scrape!.workerNodeId == null ? '' : ' · worker ${operation.scrape!.workerNodeId}'}',
      NazaRemoteOperationKind.ipfsPublish ||
      NazaRemoteOperationKind.ipfsFetch =>
        '${operation.ipfs!.contentCid} · ${operation.ipfs!.peerIds.length} trusted peers · ${operation.ipfs!.publiclyDiscoverable ? 'public' : 'private'}',
      NazaRemoteOperationKind.scrapeExportIpfs =>
        '${operation.scrapeExport!.destination.label} · source ${operation.scrapeExport!.scrapeRequestId} · ${operation.scrapeExport!.format} · ${_NazaAgenticCodingSurfaceState._formatBytes(operation.scrapeExport!.maxBytes)}',
      NazaRemoteOperationKind.nodeStart ||
      NazaRemoteOperationKind.nodeStop ||
      NazaRemoteOperationKind.nodeDelete ||
      NazaRemoteOperationKind.digitalOceanDropletStart ||
      NazaRemoteOperationKind.digitalOceanDropletStop ||
      NazaRemoteOperationKind.digitalOceanDropletDelete =>
        'node ${operation.nodeId ?? 'unknown'}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Icon(
              switch (operation.kind) {
                NazaRemoteOperationKind.digitalOceanDroplet =>
                  Icons.cloud_queue_rounded,
                NazaRemoteOperationKind.chromiumScrape =>
                  Icons.travel_explore_rounded,
                NazaRemoteOperationKind.ipfsPublish ||
                NazaRemoteOperationKind.ipfsFetch => Icons.hub_outlined,
                NazaRemoteOperationKind.scrapeExportIpfs =>
                  Icons.output_rounded,
                NazaRemoteOperationKind.nodeStart ||
                NazaRemoteOperationKind.digitalOceanDropletStart =>
                  Icons.play_arrow_rounded,
                NazaRemoteOperationKind.nodeStop ||
                NazaRemoteOperationKind.digitalOceanDropletStop =>
                  Icons.stop_rounded,
                NazaRemoteOperationKind.nodeDelete ||
                NazaRemoteOperationKind.digitalOceanDropletDelete =>
                  Icons.delete_forever_rounded,
              },
              color: color,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${operation.kind.label} · ${operation.label}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _NazaAgenticCodingSurfaceState._text,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _TinyState(operation.state.label, color),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _NazaAgenticCodingSurfaceState._subtext,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onApprove != null)
              IconButton(
                tooltip: 'Approve request for trusted adapter',
                onPressed: onApprove,
                icon: const Icon(Icons.verified_rounded, size: 18),
                color: _NazaAgenticCodingSurfaceState._mint,
              ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Cancel request',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: _NazaAgenticCodingSurfaceState._subtext,
              ),
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.selected,
    this.onSelect,
    this.onConfigure,
    this.onRemove,
    this.state,
    this.onStart,
    this.onStop,
  });

  final NazaAgenticNodeProfile node;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onConfigure;
  final VoidCallback? onRemove;
  final String? state;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final color = switch (node.kind) {
      NazaExecutionTargetKind.localWorkspace =>
        _NazaAgenticCodingSurfaceState._mint,
      NazaExecutionTargetKind.ociContainer =>
        _NazaAgenticCodingSurfaceState._violet,
      NazaExecutionTargetKind.remoteSsh => _NazaAgenticCodingSurfaceState._cyan,
    };
    final detail = switch (node.kind) {
      NazaExecutionTargetKind.localWorkspace => node.kind.isolation,
      NazaExecutionTargetKind.ociContainer =>
        '${node.containerImage} · ${node.enabled ? 'adapter declared' : 'not configured'}',
      NazaExecutionTargetKind.remoteSsh =>
        '${node.username}@${node.host}:${node.port} · host key pinned · ${node.hasCredential ? 'key sealed' : 'key missing'}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.11)
            : _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color
                    : _NazaAgenticCodingSurfaceState._border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    switch (node.kind) {
                      NazaExecutionTargetKind.localWorkspace =>
                        Icons.computer_rounded,
                      NazaExecutionTargetKind.ociContainer =>
                        Icons.inventory_2_rounded,
                      NazaExecutionTargetKind.remoteSsh =>
                        Icons.cloud_queue_rounded,
                    },
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              node.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _NazaAgenticCodingSurfaceState._text,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          _TinyState(
                            node.enabled ? 'READY' : 'LOCKED',
                            node.enabled
                                ? _NazaAgenticCodingSurfaceState._mint
                                : _NazaAgenticCodingSurfaceState._amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        state == null ? detail : '$detail · $state',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _NazaAgenticCodingSurfaceState._subtext,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onConfigure != null)
                  IconButton(
                    tooltip: 'Configure envelope',
                    onPressed: onConfigure,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: _NazaAgenticCodingSurfaceState._subtext,
                      size: 19,
                    ),
                  ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove node',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: _NazaAgenticCodingSurfaceState._rose,
                      size: 19,
                    ),
                  ),
                if (onStart != null)
                  IconButton(
                    tooltip: 'Request start',
                    onPressed: onStart,
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: _NazaAgenticCodingSurfaceState._mint,
                      size: 19,
                    ),
                  ),
                if (onStop != null)
                  IconButton(
                    tooltip: 'Request stop',
                    onPressed: onStop,
                    icon: const Icon(
                      Icons.stop_rounded,
                      color: _NazaAgenticCodingSurfaceState._amber,
                      size: 19,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyState extends StatelessWidget {
  const _TinyState(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'JetBrainsMono',
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EvidenceAction extends StatelessWidget {
  const _EvidenceAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _NazaAgenticCodingSurfaceState._text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _NazaAgenticCodingSurfaceState._subtext,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onTap,
            child: busy
                ? SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Text(
                    actionLabel,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityToggle extends StatelessWidget {
  const _CapabilityToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: _NazaAgenticCodingSurfaceState._text,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: _NazaAgenticCodingSurfaceState._subtext,
          fontSize: 11,
        ),
      ),
      value: value,
      activeTrackColor: color,
      onChanged: onChanged,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.onDismiss,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _NazaAgenticCodingSurfaceState._subtext,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss notice',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
              color: color,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _TelemetryGrid extends StatelessWidget {
  const _TelemetryGrid({required this.snapshot});

  final NazaEntropyWeaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, double, Color, String)>[
      (
        'SHARD DISAGREEMENT',
        snapshot.disagreement,
        _NazaAgenticCodingSurfaceState._rose,
        'pairwise evidence distance',
      ),
      (
        'TRUST CONSENSUS',
        snapshot.trustConsensus,
        _NazaAgenticCodingSurfaceState._mint,
        'trust-weighted similarity',
      ),
      (
        'PROVENANCE',
        snapshot.provenanceCoverage,
        _NazaAgenticCodingSurfaceState._cyan,
        'labeled contribution coverage',
      ),
      (
        'LEXICAL ENTROPY',
        snapshot.lexicalEntropy,
        _NazaAgenticCodingSurfaceState._violet,
        'normalized vocabulary spread',
      ),
      (
        'ANOMALY SURFACE',
        snapshot.anomalySurface,
        _NazaAgenticCodingSurfaceState._amber,
        'review pressure composite',
      ),
      (
        'CIRCUIT SWEEP',
        snapshot.circuitMean,
        _NazaAgenticCodingSurfaceState._violet,
        '${snapshot.circuitMin.toStringAsFixed(2)}–${snapshot.circuitMax.toStringAsFixed(2)} classical range',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(150.0, (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricTile(
                    label: metric.$1,
                    value: metric.$2,
                    color: metric.$3,
                    detail: metric.$4,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.detail,
  });

  final String label;
  final double value;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(3),
                style: const TextStyle(
                  color: _NazaAgenticCodingSurfaceState._text,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: value.clamp(0, 1),
              color: color,
              backgroundColor: _NazaAgenticCodingSurfaceState._border,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            style: const TextStyle(
              color: _NazaAgenticCodingSurfaceState._subtext,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntropyRadar extends StatelessWidget {
  const _EntropyRadar({required this.snapshot});

  final NazaEntropyWeaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EntropyRadarPainter(snapshot),
      child: const Center(
        child: Text(
          'EVIDENCE\nWEAVE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _NazaAgenticCodingSurfaceState._subtext,
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _EntropyRadarPainter extends CustomPainter {
  _EntropyRadarPainter(this.snapshot);

  final NazaEntropyWeaveSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.37;
    const axes = 5;
    final gridPaint = Paint()
      ..color = _NazaAgenticCodingSurfaceState._border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawPath(_polygon(center, radius * ring / 4, axes), gridPaint);
    }
    for (var index = 0; index < axes; index++) {
      final point = _point(center, radius, index, axes);
      canvas.drawLine(center, point, gridPaint);
    }
    final values = <double>[
      snapshot.trustConsensus,
      snapshot.provenanceCoverage,
      1 - snapshot.anomalySurface,
      snapshot.circuitMean,
      1 - snapshot.disagreement,
    ];
    final path = Path();
    for (var index = 0; index < axes; index++) {
      final point = _point(
        center,
        radius * values[index].clamp(0.0, 1.0),
        index,
        axes,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _NazaAgenticCodingSurfaceState._violet.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _NazaAgenticCodingSurfaceState._cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    const labels = <String>['TRUST', 'SOURCE', 'STABLE', 'SWEEP', 'AGREE'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < axes; index++) {
      final point = _point(center, radius + 17, index, axes);
      textPainter.text = TextSpan(
        text: labels[index],
        style: const TextStyle(
          color: _NazaAgenticCodingSurfaceState._subtext,
          fontFamily: 'JetBrainsMono',
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        point - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  static Path _polygon(Offset center, double radius, int count) {
    final path = Path();
    for (var index = 0; index < count; index++) {
      final point = _point(center, radius, index, count);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  static Offset _point(Offset center, double radius, int index, int count) {
    final angle = -math.pi / 2 + index * math.pi * 2 / count;
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  @override
  bool shouldRepaint(covariant _EntropyRadarPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot;
}

class _ProvenanceTile extends StatelessWidget {
  const _ProvenanceTile({required this.entry});

  final NazaProvenanceLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _NazaAgenticCodingSurfaceState._ink.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _NazaAgenticCodingSurfaceState._border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.fingerprint_rounded,
              color: _NazaAgenticCodingSurfaceState._cyan,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.provider} · ${entry.model}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _NazaAgenticCodingSurfaceState._text,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.digest} · ${entry.characters} chars · trust ${(entry.trustWeight * 100).round()}%',
                    style: const TextStyle(
                      color: _NazaAgenticCodingSurfaceState._subtext,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
