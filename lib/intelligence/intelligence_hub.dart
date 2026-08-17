// LLM-CONTEXT:BEGIN
// FILE: lib/intelligence/intelligence_hub.dart
// ROLE: Project-scoped offline intelligence surfaces: Knowledge Vault,
// Memory Observatory, Projects, and constrained Workflow Builder.
// SECURITY-INVARIANT: User files remain local; persisted records contain only
// bounded text/metadata; workflows are proposals and never execute silently.
// CHANGE-GUARD: File paths are never persisted as executable instructions;
// imported bytes are bounded before decoding; all durable state uses the
// encrypted vault; action approval is explicit and deterministic.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../security/secure_database.dart';

enum NazaIntelligenceWorkspace { knowledge, observatory, projects, workflows }

final class NazaObservedMemory {
  final String id;
  final String text;
  final String role;
  final String route;
  final double importance;
  final int accessCount;
  final DateTime createdAt;

  const NazaObservedMemory({
    required this.id,
    required this.text,
    required this.role,
    required this.route,
    required this.importance,
    required this.accessCount,
    required this.createdAt,
  });
}

typedef NazaMemoryInspector = Future<List<NazaObservedMemory>> Function();
typedef NazaMemoryForgetter = Future<void> Function(String id);
typedef NazaKnowledgeIndexer =
    Future<void> Function({
      required String projectId,
      required String documentName,
      required String text,
    });

final class NazaIntelligenceProject {
  final String id;
  final String name;
  final String description;
  final DateTime updatedAt;

  const NazaIntelligenceProject({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NazaIntelligenceProject.fromJson(Map<String, dynamic> json) =>
      NazaIntelligenceProject(
        id:
            json['id']?.toString() ??
            'project-${DateTime.now().microsecondsSinceEpoch}',
        name: _bounded(json['name']?.toString() ?? 'Untitled project', 80),
        description: _bounded(json['description']?.toString() ?? '', 400),
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
      );
}

final class NazaKnowledgeDocument {
  final String id;
  final String projectId;
  final String name;
  final String type;
  final int bytes;
  final String sha256;
  final String text;
  final DateTime importedAt;

  const NazaKnowledgeDocument({
    required this.id,
    required this.projectId,
    required this.name,
    required this.type,
    required this.bytes,
    required this.sha256,
    required this.text,
    required this.importedAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'name': name,
    'type': type,
    'bytes': bytes,
    'sha256': sha256,
    'text': text,
    'importedAt': importedAt.toIso8601String(),
  };

  factory NazaKnowledgeDocument.fromJson(Map<String, dynamic> json) =>
      NazaKnowledgeDocument(
        id: json['id']?.toString() ?? '',
        projectId: json['projectId']?.toString() ?? 'default',
        name: _bounded(json['name']?.toString() ?? 'document', 160),
        type: _bounded(json['type']?.toString() ?? 'text', 32),
        bytes: ((json['bytes'] as num?) ?? 0)
            .clamp(0, NazaIntelligenceStore.maxDocumentBytes)
            .toInt(),
        sha256: _bounded(json['sha256']?.toString() ?? '', 64),
        text: _bounded(
          json['text']?.toString() ?? '',
          NazaIntelligenceStore.maxDocumentText,
        ),
        importedAt:
            DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
      );
}

final class NazaWorkflowProposal {
  final String id;
  final String projectId;
  final String title;
  final String instruction;
  final bool approved;

  const NazaWorkflowProposal({
    required this.id,
    required this.projectId,
    required this.title,
    required this.instruction,
    this.approved = false,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'title': title,
    'instruction': instruction,
    'approved': approved,
  };

  factory NazaWorkflowProposal.fromJson(Map<String, dynamic> json) =>
      NazaWorkflowProposal(
        id: json['id']?.toString() ?? '',
        projectId: json['projectId']?.toString() ?? 'default',
        title: _bounded(json['title']?.toString() ?? 'Workflow', 100),
        instruction: _bounded(json['instruction']?.toString() ?? '', 500),
        approved: json['approved'] == true,
      );

  NazaWorkflowProposal copyWith({bool? approved}) => NazaWorkflowProposal(
    id: id,
    projectId: projectId,
    title: title,
    instruction: instruction,
    approved: approved ?? this.approved,
  );
}

final class NazaIntelligenceStore {
  static const String _namespace = 'naza-intelligence-v1';
  static const String _key = 'workspace';
  static const int maxDocumentBytes = 12 * 1024 * 1024;
  static const int maxDocumentText = 160000;
  static const int maxDocuments = 500;
  static const int maxProjects = 50;

  final NazaSecureDatabase database;
  List<NazaIntelligenceProject> projects = const [];
  List<NazaKnowledgeDocument> documents = const [];
  List<NazaWorkflowProposal> workflows = const [];

  NazaIntelligenceStore({NazaSecureDatabase? database})
    : database = database ?? NazaSecureDatabase.instance;

  Future<void> load() async {
    final raw = await database.readJson(_namespace, _key);
    if (raw is! Map) return;
    final value = Map<String, dynamic>.from(raw);
    projects = ((value['projects'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              NazaIntelligenceProject.fromJson(Map<String, dynamic>.from(item)),
        )
        .take(maxProjects)
        .toList(growable: false);
    documents = ((value['documents'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              NazaKnowledgeDocument.fromJson(Map<String, dynamic>.from(item)),
        )
        .take(maxDocuments)
        .toList(growable: false);
    workflows = ((value['workflows'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              NazaWorkflowProposal.fromJson(Map<String, dynamic>.from(item)),
        )
        .take(100)
        .toList(growable: false);
  }

  Future<void> save() => database.writeJson(_namespace, _key, <String, Object?>{
    'format': 'naza-intelligence-v1',
    'projects': projects.map((item) => item.toJson()).toList(growable: false),
    'documents': documents.map((item) => item.toJson()).toList(growable: false),
    'workflows': workflows.map((item) => item.toJson()).toList(growable: false),
  });

  Future<void> addProject(String name, String description) async {
    if (projects.length >= maxProjects)
      throw StateError('Project limit reached.');
    final clean = _bounded(name.trim(), 80);
    if (clean.isEmpty) throw const FormatException('Project name is required.');
    projects = <NazaIntelligenceProject>[
      ...projects,
      NazaIntelligenceProject(
        id: 'project-${DateTime.now().microsecondsSinceEpoch}',
        name: clean,
        description: _bounded(description.trim(), 400),
        updatedAt: DateTime.now().toUtc(),
      ),
    ];
    await save();
  }

  Future<List<NazaKnowledgeDocument>> importFiles(
    String projectId,
    List<PlatformFile> files,
  ) async {
    final additions = <NazaKnowledgeDocument>[];
    for (final picked in files.take(20)) {
      final path = picked.path;
      if (path == null) continue;
      final file = File(path);
      final size = await file.length();
      if (size > maxDocumentBytes)
        throw StateError('${picked.name} exceeds the 12 MB limit.');
      final bytes = await _readBounded(file, maxDocumentBytes);
      final text = _bounded(
        utf8.decode(bytes, allowMalformed: true),
        maxDocumentText,
      );
      additions.add(
        NazaKnowledgeDocument(
          id: 'doc-${sha256.convert(bytes).toString()}',
          projectId: projectId,
          name: _bounded(picked.name, 160),
          type: _extension(picked.name),
          bytes: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          text: text,
          importedAt: DateTime.now().toUtc(),
        ),
      );
    }
    final byId = <String, NazaKnowledgeDocument>{
      for (final item in documents) item.id: item,
    };
    for (final item in additions) byId[item.id] = item;
    documents = byId.values.take(maxDocuments).toList(growable: false);
    await save();
    return additions;
  }

  Future<void> addWorkflow(
    String projectId,
    String title,
    String instruction,
  ) async {
    workflows = <NazaWorkflowProposal>[
      ...workflows,
      NazaWorkflowProposal(
        id: 'workflow-${DateTime.now().microsecondsSinceEpoch}',
        projectId: projectId,
        title: _bounded(title.trim(), 100),
        instruction: _bounded(instruction.trim(), 500),
      ),
    ].take(100).toList(growable: false);
    await save();
  }

  Future<void> setApproved(String id, bool value) async {
    workflows = workflows
        .map((item) => item.id == id ? item.copyWith(approved: value) : item)
        .toList(growable: false);
    await save();
  }
}

final class NazaIntelligenceHub extends StatefulWidget {
  final NazaIntelligenceWorkspace initialWorkspace;
  final NazaMemoryInspector? inspectMemory;
  final NazaMemoryForgetter? forgetMemory;
  final NazaKnowledgeIndexer? indexKnowledge;
  const NazaIntelligenceHub({
    super.key,
    this.initialWorkspace = NazaIntelligenceWorkspace.knowledge,
    this.inspectMemory,
    this.forgetMemory,
    this.indexKnowledge,
  });
  @override
  State<NazaIntelligenceHub> createState() => _NazaIntelligenceHubState();
}

class _NazaIntelligenceHubState extends State<NazaIntelligenceHub> {
  final NazaIntelligenceStore _store = NazaIntelligenceStore();
  late NazaIntelligenceWorkspace _workspace;
  bool _loading = true;
  String? _loadError;
  bool _memoryLoading = false;
  List<NazaObservedMemory> _memories = const [];
  String _projectId = 'default';
  String? _message;

  @override
  void initState() {
    super.initState();
    _workspace = widget.initialWorkspace;
    _load();
  }

  Future<void> _load() async {
    try {
      await _store.load();
      await _refreshMemories();
    } catch (error) {
      // A locked vault or unavailable secure store must degrade to a visible
      // recovery state; it must never escape an async init callback and take
      // down the Flutter isolate.
      _loadError = 'Intelligence storage is unavailable: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshMemories() async {
    final inspect = widget.inspectMemory;
    if (inspect == null) return;
    if (mounted) setState(() => _memoryLoading = true);
    try {
      final memories = await inspect();
      if (mounted) setState(() => _memories = memories);
    } finally {
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  Future<void> _forgetMemory(NazaObservedMemory memory) async {
    final forget = widget.forgetMemory;
    if (forget == null) return;
    await forget(memory.id);
    await _refreshMemories();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: false,
        type: FileType.any,
      );
      if (result == null) return;
      final imported = await _store.importFiles(_projectId, result.files);
      final index = widget.indexKnowledge;
      if (index != null) {
        for (final document in imported) {
          await index(
            projectId: _projectId,
            documentName: document.name,
            text: document.text,
          );
        }
      }
      if (mounted)
        setState(
          () => _message =
              'Imported ${result.files.length} file(s) into the encrypted vault.',
        );
    } catch (error) {
      if (mounted) setState(() => _message = 'Import blocked: $error');
    }
  }

  Future<void> _newProject() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New private project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _store.addProject(name.text, description.text);
      if (mounted) setState(() => _projectId = _store.projects.last.id);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _newWorkflow() async {
    final title = TextEditingController();
    final instruction = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New workflow proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Workflow name'),
            ),
            TextField(
              controller: instruction,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What should it propose?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save proposal'),
          ),
        ],
      ),
    );
    if (ok == true &&
        title.text.trim().isNotEmpty &&
        instruction.text.trim().isNotEmpty) {
      await _store.addWorkflow(_projectId, title.text, instruction.text);
      if (mounted)
        setState(
          () => _message =
              'Workflow saved as a proposal; approval is still required.',
        );
    }
    title.dispose();
    instruction.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Knowledge Vault unavailable',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      _load();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry securely'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Naza Intelligence')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<NazaIntelligenceWorkspace>(
              segments: const [
                ButtonSegment(
                  value: NazaIntelligenceWorkspace.knowledge,
                  label: Text('Knowledge Vault'),
                  icon: Icon(Icons.folder_special_rounded),
                ),
                ButtonSegment(
                  value: NazaIntelligenceWorkspace.observatory,
                  label: Text('Memory Observatory'),
                  icon: Icon(Icons.hub_rounded),
                ),
                ButtonSegment(
                  value: NazaIntelligenceWorkspace.projects,
                  label: Text('Projects'),
                  icon: Icon(Icons.workspaces_rounded),
                ),
                ButtonSegment(
                  value: NazaIntelligenceWorkspace.workflows,
                  label: Text('Workflows'),
                  icon: Icon(Icons.account_tree_rounded),
                ),
              ],
              selected: {_workspace},
              onSelectionChanged: (value) =>
                  setState(() => _workspace = value.first),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_message!, style: TextStyle(color: scheme.primary)),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() => switch (_workspace) {
    NazaIntelligenceWorkspace.knowledge => _knowledge(),
    NazaIntelligenceWorkspace.observatory => _observatory(),
    NazaIntelligenceWorkspace.projects => _projects(),
    NazaIntelligenceWorkspace.workflows => _workflows(),
  };

  Widget _projectPicker() => DropdownButton<String>(
    value: _store.projects.any((item) => item.id == _projectId)
        ? _projectId
        : null,
    hint: const Text('Default workspace'),
    items: _store.projects
        .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
        .toList(),
    onChanged: (value) => setState(() => _projectId = value ?? 'default'),
  );

  Widget _knowledge() {
    final docs = _store.documents
        .where((item) => item.projectId == _projectId)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Local evidence, indexed by project',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _projectPicker(),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No documents yet. Import bounded local text, Markdown, CSV, receipts, or manuals.',
              ),
            ),
          ),
        ...docs.map(
          (doc) => Card(
            child: ListTile(
              leading: const Icon(Icons.description_rounded),
              title: Text(doc.name),
              subtitle: Text(
                '${doc.type} · ${doc.bytes} bytes · ${doc.sha256.substring(0, 12)}…',
              ),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(doc.name),
                  content: SingleChildScrollView(child: Text(doc.text)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _observatory() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Explainable local context',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Card(
        child: ListTile(
          leading: Icon(Icons.lock_rounded),
          title: Text('Encrypted at rest'),
          subtitle: Text(
            'Knowledge documents, project boundaries, and workflow proposals use the secure vault.',
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.source_rounded),
          title: Text('Evidence provenance'),
          subtitle: Text(
            '${_store.documents.length} imported documents · ${_store.projects.length} projects · ${_store.workflows.length} workflow proposals',
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.visibility_rounded),
          title: const Text('Memory boundary'),
          subtitle: const Text(
            'Current requests outrank retrieved context. Imported files are evidence, never executable instructions.',
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Remembered evidence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_memoryLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            onPressed: _refreshMemories,
            tooltip: 'Refresh memory',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      if (_memories.isEmpty)
        const Card(
          child: ListTile(
            title: Text('No inspectable memories yet'),
            subtitle: Text(
              'As local memory grows, its bounded evidence and provenance will appear here.',
            ),
          ),
        ),
      ..._memories.map(
        (memory) => Card(
          child: ListTile(
            title: Text(
              memory.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${memory.role} · ${memory.route} · importance ${(memory.importance * 100).round()}% · accessed ${memory.accessCount}×',
            ),
            trailing: widget.forgetMemory == null
                ? null
                : IconButton(
                    tooltip: 'Forget this memory',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _forgetMemory(memory),
                  ),
          ),
        ),
      ),
    ],
  );

  Widget _projects() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Isolated workspaces',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.icon(
            onPressed: _newProject,
            icon: const Icon(Icons.add),
            label: const Text('New project'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ..._store.projects.map(
        (item) => Card(
          child: ListTile(
            selected: item.id == _projectId,
            leading: const Icon(Icons.workspaces_rounded),
            title: Text(item.name),
            subtitle: Text(
              item.description.isEmpty ? 'No description' : item.description,
            ),
            onTap: () => setState(() {
              _projectId = item.id;
              _workspace = NazaIntelligenceWorkspace.knowledge;
            }),
          ),
        ),
      ),
    ],
  );

  Widget _workflows() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Approval-gated local workflows',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.icon(
            onPressed: _newWorkflow,
            icon: const Icon(Icons.add),
            label: const Text('New proposal'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'The model may propose an action; deterministic code and you authorize it.',
      ),
      const SizedBox(height: 12),
      ..._store.workflows
          .where((item) => item.projectId == _projectId)
          .map(
            (item) => Card(
              child: SwitchListTile(
                title: Text(item.title),
                subtitle: Text(
                  '${item.instruction}\n${item.approved ? 'Approved for review' : 'Proposal only'}',
                ),
                value: item.approved,
                onChanged: (value) =>
                    _store.setApproved(item.id, value).then((_) {
                      if (mounted) setState(() {});
                    }),
              ),
            ),
          ),
    ],
  );
}

String _bounded(String value, int max) =>
    value.length <= max ? value : value.substring(0, max);
String _extension(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : 'text';
Future<List<int>> _readBounded(File file, int max) async {
  final output = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in file.openRead(0, max + 1)) {
    total += chunk.length;
    if (total > max) throw StateError('File exceeds the configured limit.');
    output.add(chunk);
  }
  return output.takeBytes();
}
