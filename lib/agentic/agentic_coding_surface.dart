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

import 'agentic_runtime.dart';

typedef NazaAgenticTaskRunner =
    Future<NazaAgenticRunResult> Function(NazaAgenticTaskRequest request);
typedef NazaAgenticImagePicker = Future<NazaAgenticAttachment?> Function();

class NazaAgenticCodingSurface extends StatefulWidget {
  const NazaAgenticCodingSurface({
    super.key,
    required this.runTask,
    this.pickImage,
    this.store,
    this.collector = const NazaRepositoryContextCollector(),
    this.initialConfig,
    this.persistState = true,
  });

  final NazaAgenticTaskRunner runTask;
  final NazaAgenticImagePicker? pickImage;
  final NazaAgenticWorkspaceStore? store;
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

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? NazaAgenticWorkspaceStore();
    _config = widget.initialConfig ?? const NazaAgenticWorkspaceConfig();
    if (widget.persistState) {
      unawaited(_loadConfig());
    } else {
      _loading = false;
      _status = 'Local planning boundary ready';
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
                ],
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

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.selected,
    this.onSelect,
    this.onConfigure,
    this.onRemove,
  });

  final NazaAgenticNodeProfile node;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onConfigure;
  final VoidCallback? onRemove;

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
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

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
