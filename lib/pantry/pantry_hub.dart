import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../food/models.dart';
import '../food/photo_picker.dart';
import 'doordash_cli.dart';
import 'models.dart';
import 'planner.dart';
import 'repository.dart';

typedef PantryImageAnalyzer =
    Future<PantryScanResult> Function(
      FoodVisionImage image,
      String zone,
      String note,
      List<PantryItem> priorItems,
    );
typedef PantryAdvisoryGenerator =
    Future<PantryPlanAdvisory> Function(
      PantryState state,
      PantryOrderPlan plan,
    );

class PantryAutopilotHub extends StatefulWidget {
  final PantryRepository repository;
  final FoodPhotoPicker photoPicker;
  final PantryImageAnalyzer analyzeImage;
  final PantryAdvisoryGenerator generateAdvisory;
  final DoorDashOrderingGateway orderingGateway;
  final VoidCallback onCancel;

  const PantryAutopilotHub({
    super.key,
    required this.repository,
    required this.photoPicker,
    required this.analyzeImage,
    required this.generateAdvisory,
    required this.orderingGateway,
    required this.onCancel,
  });

  @override
  State<PantryAutopilotHub> createState() => _PantryAutopilotHubState();
}

class _PantryAutopilotHubState extends State<PantryAutopilotHub>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _zone = TextEditingController(
    text: 'Pantry / cupboard',
  );
  final TextEditingController _note = TextEditingController();
  PantryState _state = const PantryState();
  List<PantryOrderPlan> _history = const <PantryOrderPlan>[];
  PantryOrderPlan? _plan;
  FoodVisionImage? _image;
  DoorDashCliProbe? _probe;
  bool _busy = false;
  bool _loading = true;
  String _status = 'Opening encrypted pantry';
  String? _error;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    widget.repository.revision.addListener(_onRevision);
    unawaited(_load());
    unawaited(_probeCli());
  }

  @override
  void didUpdateWidget(covariant PantryAutopilotHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      oldWidget.repository.revision.removeListener(_onRevision);
      widget.repository.revision.addListener(_onRevision);
      unawaited(_load());
    }
    if (!identical(oldWidget.orderingGateway, widget.orderingGateway)) {
      unawaited(_probeCli());
    }
  }

  @override
  void dispose() {
    _operation++;
    widget.repository.revision.removeListener(_onRevision);
    _tabs.dispose();
    _zone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (!_busy) unawaited(_load());
  }

  Future<void> _load() async {
    final token = ++_operation;
    if (mounted) {
      setState(() {
        _loading = true;
        _status = 'Opening encrypted pantry';
      });
    }
    try {
      final values = await Future.wait<Object>([
        widget.repository.loadState(),
        widget.repository.listOrderPlans(),
      ]);
      if (!mounted || token != _operation) return;
      final history = List<PantryOrderPlan>.from(
        values[1] as List<PantryOrderPlan>,
      );
      setState(() {
        _state = values[0] as PantryState;
        _history = history;
        _plan = history.isEmpty ? null : history.first;
        _loading = false;
        _status = 'Pantry autopilot ready';
        _error = null;
      });
    } catch (error) {
      _finishError(token, 'Encrypted pantry could not be opened: $error');
    }
  }

  Future<void> _probeCli() async {
    try {
      final probe = await widget.orderingGateway.probe();
      if (!mounted) return;
      setState(() => _probe = probe);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _probe = DoorDashCliProbe(
          platformSupported: false,
          installed: false,
          detail: 'DoorDash CLI capability check failed: $error',
        ),
      );
    }
  }

  int _start(String status) {
    final token = ++_operation;
    setState(() {
      _busy = true;
      _status = status;
      _error = null;
    });
    return token;
  }

  bool _current(int token) => mounted && token == _operation;

  void _finish(int token, String status) {
    if (!_current(token)) return;
    setState(() {
      _busy = false;
      _loading = false;
      _status = status;
    });
  }

  void _finishError(int token, Object error) {
    if (!_current(token)) return;
    setState(() {
      _busy = false;
      _loading = false;
      _status = 'Needs attention';
      _error = error.toString();
    });
  }

  void _cancel() {
    if (!_busy) return;
    _operation++;
    try {
      widget.onCancel();
    } catch (_) {}
    setState(() {
      _busy = false;
      _status = 'Pantry task stopped';
      _error = null;
    });
  }

  Future<void> _pick(FoodPhotoSource source) async {
    if (_busy) return;
    final token = _start('Opening ${source.name}');
    try {
      final result = await widget.photoPicker.pick(source);
      if (!_current(token)) return;
      if (result.outcome == FoodPhotoPickOutcome.selected &&
          result.image != null) {
        setState(() {
          _image = result.image;
          _busy = false;
          _status = 'Supply photo ready';
        });
        return;
      }
      if (result.outcome == FoodPhotoPickOutcome.cancelled) {
        _finish(token, 'Photo selection cancelled');
        return;
      }
      _finishError(
        token,
        result.message ?? 'The supply photo could not be prepared.',
      );
    } catch (error) {
      _finishError(token, 'Photo selection failed: $error');
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (_busy || image == null) return;
    final token = _start('Mapping pantry with local Gemma');
    try {
      final scan = await widget.analyzeImage(
        image,
        _zone.text.trim(),
        _note.text.trim(),
        _state.items,
      );
      if (!_current(token)) return;
      if (!scan.parsed) {
        _finishError(
          token,
          scan.uncertainties.isEmpty
              ? 'The pantry scan could not be structured.'
              : scan.uncertainties.join('\n'),
        );
        return;
      }
      final merged = PantryPlanner.mergeScan(
        previous: _state,
        scan: scan,
        capturedAt: DateTime.now(),
      );
      await widget.repository.saveState(merged);
      if (!_current(token)) return;
      setState(() {
        _state = merged;
        _image = null;
        _busy = false;
        _status = '${scan.observations.length} observations encrypted';
      });
      _tabs.animateTo(1);
    } catch (error) {
      _finishError(token, 'Pantry analysis or encrypted save failed: $error');
    }
  }

  Future<void> _saveProfile(PantryProfile profile) async {
    final token = _start('Saving pantry policy');
    try {
      final nextScan = _state.lastScanAt?.add(
        Duration(days: profile.scanIntervalDays),
      );
      final updated = PantryState(
        profile: profile,
        items: _state.items,
        lastScanAt: _state.lastScanAt,
        nextScanAt: nextScan,
        lastScanSummary: _state.lastScanSummary,
        scanUncertainties: _state.scanUncertainties,
      );
      await widget.repository.saveState(updated);
      if (!_current(token)) return;
      setState(() {
        _state = updated;
        _busy = false;
        _status = 'Pantry policy saved';
      });
    } catch (error) {
      _finishError(token, 'Pantry policy could not be saved: $error');
    }
  }

  Future<void> _saveItem(PantryItem item) async {
    final token = _start('Saving inventory adjustment');
    try {
      final exists = _state.items.any((entry) => entry.id == item.id);
      final updated = exists
          ? PantryPlanner.updateItem(_state, item)
          : _state.copyWith(
              items: List<PantryItem>.unmodifiable(<PantryItem>[
                ..._state.items,
                item,
              ]),
            );
      await widget.repository.saveState(updated);
      if (!_current(token)) return;
      setState(() {
        _state = updated;
        _busy = false;
        _status = 'Inventory adjustment encrypted';
      });
    } catch (error) {
      _finishError(token, 'Inventory adjustment failed: $error');
    }
  }

  Future<void> _deleteItem(PantryItem item) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${item.name}?'),
        content: const Text(
          'This removes the item from the encrypted inventory and future replenishment plans. Existing plan history is retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep item'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = _start('Removing inventory item');
    try {
      final updated = _state.copyWith(
        items: List<PantryItem>.unmodifiable(
          _state.items.where((entry) => entry.id != item.id),
        ),
      );
      await widget.repository.saveState(updated);
      if (!_current(token)) return;
      setState(() {
        _state = updated;
        _busy = false;
        _status = '${item.name} removed';
      });
    } catch (error) {
      _finishError(token, 'Inventory item could not be removed: $error');
    }
  }

  Future<void> _buildPlan() async {
    if (_busy) return;
    final token = _start('Computing replenishment plan');
    try {
      final plan = PantryPlanner.buildOrderPlan(
        state: _state,
        now: DateTime.now(),
      );
      await widget.repository.saveOrderPlan(plan);
      if (!_current(token)) return;
      setState(() {
        _plan = plan;
        _history = <PantryOrderPlan>[
          plan,
          ..._history.where((entry) => entry.id != plan.id),
        ];
        _busy = false;
        _status = plan.lines.isEmpty
            ? 'Nothing meets the reorder policy'
            : '${plan.lines.length} replenishment candidates ready';
      });
      _tabs.animateTo(2);
    } catch (error) {
      _finishError(token, 'Replenishment planning failed: $error');
    }
  }

  Future<void> _toggleLine(PantryOrderLine line, bool selected) async {
    final plan = _plan;
    if (_busy || plan == null || plan.status != PantryOrderStatus.draft) return;
    final token = _start('Updating order selection');
    final updated = plan.copyWith(
      lines: plan.lines
          .map(
            (entry) => entry.itemId == line.itemId
                ? entry.copyWith(selected: selected)
                : entry,
          )
          .toList(growable: false),
    );
    try {
      await widget.repository.saveOrderPlan(updated);
      if (!_current(token)) return;
      setState(() {
        _plan = updated;
        _busy = false;
        _status = 'Order selection updated';
      });
    } catch (error) {
      _finishError(token, 'Order selection could not be saved: $error');
    }
  }

  Future<void> _generateAdvice() async {
    final plan = _plan;
    if (_busy || plan == null || plan.lines.isEmpty) return;
    final token = _start('Gemma is organizing the order');
    try {
      final advisory = await widget.generateAdvisory(_state, plan);
      if (!_current(token)) return;
      final updated = plan.copyWith(advisory: advisory);
      await widget.repository.saveOrderPlan(updated);
      if (!_current(token)) return;
      setState(() {
        _plan = updated;
        _busy = false;
        _status = 'Local order strategy ready';
      });
    } catch (error) {
      _finishError(token, 'Local order advice failed: $error');
    }
  }

  Future<void> _approve() async {
    final plan = _plan;
    if (_busy || plan == null || plan.status != PantryOrderStatus.draft) return;
    if (!plan.lines.any((line) => line.selected)) {
      setState(() => _error = 'Select at least one order line first.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve this plan?'),
        content: Text(
          'This records approval for the selected replenishment brief. It does not place an order.\n\n'
          'Estimated subtotal: \$${plan.estimatedTotal.toStringAsFixed(2)}\n'
          'Budget cap: \$${plan.budgetCap.toStringAsFixed(2)}\n\n'
          'Live item availability, package size, substitutions, taxes, fees, tip, address, and final total still require review immediately before DoorDash checkout.'
          '${plan.hasUnverifiedLines ? '\n\nSome photo observations or price estimates are unverified.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve brief'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final token = _start('Recording order approval');
    final updated = plan.copyWith(
      status: PantryOrderStatus.approved,
      approvedAt: DateTime.now().toUtc(),
    );
    try {
      await widget.repository.saveOrderPlan(updated);
      if (!_current(token)) return;
      setState(() {
        _plan = updated;
        _busy = false;
        _status = 'Plan approved for DoorDash handoff';
      });
    } catch (error) {
      _finishError(token, 'Order approval could not be saved: $error');
    }
  }

  Future<void> _copyHandoff() async {
    final plan = _plan;
    if (_busy || plan == null) return;
    final token = _start('Preparing approved DoorDash handoff');
    try {
      final handoff = widget.orderingGateway.createApprovedHandoff(plan);
      await Clipboard.setData(ClipboardData(text: handoff.agentBrief));
      final updated = plan.copyWith(
        status: PantryOrderStatus.handedOff,
        handedOffAt: DateTime.now().toUtc(),
      );
      await widget.repository.saveOrderPlan(updated);
      if (!_current(token)) return;
      setState(() {
        _plan = updated;
        _busy = false;
        _status = 'Approved DoorDash agent brief copied';
        _error = null;
      });
    } catch (error) {
      _finishError(token, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _Header(
          status: _status,
          busy: _busy,
          onCancel: _cancel,
          onPolicy: _busy ? null : () => _showPolicyDialog(),
        ),
        if (_error != null)
          Material(
            color: const Color(0x33FF806E),
            child: ListTile(
              leading: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF927B),
              ),
              title: Text(_error!),
              trailing: IconButton(
                onPressed: () => setState(() => _error = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Material(
          color: const Color(0xFF071710),
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Capture'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
              Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Order'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_captureTab(), _inventoryTab(), _orderTab()],
          ),
        ),
      ],
    );
  }

  Widget _captureTab() {
    final due = _state.nextScanAt;
    final overdue = due != null && DateTime.now().isAfter(due);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              label: 'Tracked',
              value: '${_state.items.length}',
              icon: Icons.inventory_2_outlined,
            ),
            _Metric(
              label: 'Scan cadence',
              value: '${_state.profile.scanIntervalDays} days',
              icon: Icons.event_repeat_rounded,
            ),
            _Metric(
              label: overdue ? 'Scan overdue' : 'Next scan',
              value: due == null ? 'Not scheduled' : _date(due),
              icon: overdue
                  ? Icons.notification_important_outlined
                  : Icons.schedule_rounded,
              warning: overdue,
            ),
            _Metric(
              label: 'Order budget',
              value: '\$${_state.profile.orderBudget.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Biweekly supply scan',
          subtitle:
              'Take one clear photo per shelf or cupboard. Gemma observes visible food, paper goods, cleaning supplies, personal care, and pet supplies locally.',
          child: Column(
            children: [
              TextField(
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                  hintText: 'Upper pantry, under-sink supplies, hall closet…',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Optional context',
                  hintText:
                      'Only visible evidence is treated as inventory. Add context you will verify.',
                ),
              ),
              const SizedBox(height: 12),
              if (_image != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(_image!.name),
                  subtitle: Text(
                    '${_image!.width} × ${_image!.height} • local vision input',
                  ),
                  trailing: IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _image = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => unawaited(_pick(FoodPhotoSource.camera)),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => unawaited(_pick(FoodPhotoSource.gallery)),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose photo'),
                  ),
                  FilledButton.icon(
                    key: const Key('pantry-analyze-photo'),
                    onPressed: _busy || _image == null
                        ? null
                        : () => unawaited(_analyze()),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Analyze & merge'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_state.lastScanSummary.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Latest observation',
            subtitle: _state.lastScanAt == null
                ? ''
                : 'Captured ${_dateTime(_state.lastScanAt!)}',
            child: Text(_state.lastScanSummary),
          ),
        ],
        if (_state.scanUncertainties.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'Verify next',
            subtitle:
                'A photo cannot prove hidden quantity, freshness, package contents, or absence.',
            child: Column(
              children: _state.scanUncertainties
                  .map(
                    (warning) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.visibility_outlined, size: 20),
                      title: Text(warning),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _inventoryTab() {
    final items = <PantryItem>[..._state.items]
      ..sort((a, b) {
        final category = a.category.index.compareTo(b.category.index);
        return category != 0
            ? category
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Inventory policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _showItemDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('pantry-build-order'),
              onPressed: _busy || items.isEmpty
                  ? null
                  : () => unawaited(_buildPlan()),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Build order'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Photo observations start with auto-restock off. Verify quantities, targets, use rates, and price estimates before enabling them.',
          style: TextStyle(color: Color(0xFFA7CDBA)),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const _Empty(
            icon: Icons.shelves,
            title: 'No pantry inventory yet',
            body: 'Capture a cupboard or supply-closet photo to begin.',
          )
        else
          ...items.map(
            (item) => Card(
              child: ListTile(
                onTap: _busy ? null : () => _showItemDialog(item),
                leading: CircleAvatar(
                  backgroundColor: _categoryColor(item.category).withAlpha(35),
                  child: Icon(
                    _categoryIcon(item.category),
                    color: _categoryColor(item.category),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (item.autoRestock)
                      const Icon(
                        Icons.autorenew_rounded,
                        size: 18,
                        color: Color(0xFF74F5B3),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${_quantity(item.quantity)} ${item.unit} • target '
                  '${_quantity(item.targetQuantity)} • reorder at '
                  '${_quantity(item.reorderPoint)}\n'
                  '${item.category.label} • ${item.userVerified ? 'verified' : '${item.confidence.name} confidence'}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderTab() {
    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Panel(
          title: 'DoorDash agent bridge',
          subtitle:
              'The public beta has no published stable command grammar. Naza probes only help/version and exports an approved JSON brief instead of guessing checkout commands.',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _probe?.installed == true
                    ? Icons.terminal_rounded
                    : Icons.terminal_outlined,
                color: _probe?.installed == true
                    ? const Color(0xFF74F5B3)
                    : const Color(0xFFFFCF70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _probe?.detail ?? 'Checking DoorDash CLI availability…',
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => unawaited(_probeCli()),
                tooltip: 'Check again',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (plan == null)
          _Empty(
            icon: Icons.shopping_basket_outlined,
            title: 'No replenishment plan',
            body:
                'Configure inventory targets and build a plan. The engine only proposes enabled items at their reorder thresholds.',
            action: FilledButton.icon(
              onPressed: _busy || _state.items.isEmpty
                  ? null
                  : () => unawaited(_buildPlan()),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Build plan'),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.lines.where((line) => line.selected).length} selected • '
                      '\$${plan.estimatedTotal.toStringAsFixed(2)} estimated',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Budget \$${plan.budgetCap.toStringAsFixed(2)} • ${plan.status.name}',
                      style: const TextStyle(color: Color(0xFFA7CDBA)),
                    ),
                  ],
                ),
              ),
              if (plan.status == PantryOrderStatus.draft)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => unawaited(_buildPlan()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Rebuild'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (plan.lines.isEmpty)
            const _Empty(
              icon: Icons.check_circle_outline_rounded,
              title: 'Supply levels look covered',
              body:
                  'No enabled item is currently at its reorder point or lead-time threshold.',
            )
          else
            ...plan.lines.map(
              (line) => Card(
                child: CheckboxListTile(
                  value: line.selected,
                  onChanged: _busy || plan.status != PantryOrderStatus.draft
                      ? null
                      : (value) => unawaited(_toggleLine(line, value ?? false)),
                  secondary: Icon(_categoryIcon(line.category)),
                  title: Text(
                    '${line.name} • ${_quantity(line.quantity)} ${line.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${line.reason}\n'
                    '${line.estimatedUnitPrice > 0 ? '\$${line.estimatedTotal.toStringAsFixed(2)} estimated' : 'Live price required'}'
                    '${line.needsVerification ? ' • verify' : ''}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          if (plan.advisory.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Panel(
              title: 'Local Gemma strategy',
              subtitle: plan.advisory.summary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...plan.advisory.dealQueries.map(
                    (query) => _Bullet(icon: Icons.search_rounded, text: query),
                  ),
                  ...plan.advisory.substitutions.map(
                    (substitution) => _Bullet(
                      icon: Icons.swap_horiz_rounded,
                      text: substitution,
                    ),
                  ),
                  ...plan.advisory.warnings.map(
                    (warning) => _Bullet(
                      icon: Icons.warning_amber_rounded,
                      text: warning,
                      warning: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _busy || plan.lines.isEmpty
                    ? null
                    : () => unawaited(_generateAdvice()),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Optimize locally'),
              ),
              if (plan.status == PantryOrderStatus.draft)
                FilledButton.icon(
                  key: const Key('pantry-approve-order'),
                  onPressed: _busy ? null : () => unawaited(_approve()),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review & approve'),
                ),
              if (plan.status == PantryOrderStatus.approved)
                FilledButton.icon(
                  key: const Key('pantry-copy-doordash-handoff'),
                  onPressed: _busy ? null : () => unawaited(_copyHandoff()),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy DoorDash brief'),
                ),
              if (plan.status == PantryOrderStatus.handedOff)
                const Chip(
                  avatar: Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Handoff copied'),
                ),
            ],
          ),
        ],
        if (_history.length > 1) ...[
          const SizedBox(height: 18),
          const Text(
            'Recent encrypted plans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          ..._history
              .skip(1)
              .take(8)
              .map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry.lines.length} candidates • \$${entry.estimatedTotal.toStringAsFixed(2)}',
                  ),
                  subtitle: Text(_dateTime(entry.createdAt)),
                  trailing: Text(entry.status.name),
                  onTap: () => setState(() => _plan = entry),
                ),
              ),
        ],
      ],
    );
  }

  Future<void> _showPolicyDialog() async {
    final interval = TextEditingController(
      text: _state.profile.scanIntervalDays.toString(),
    );
    final horizon = TextEditingController(
      text: _state.profile.planningHorizonDays.toString(),
    );
    final lead = TextEditingController(
      text: _state.profile.lowSupplyLeadDays.toString(),
    );
    final budget = TextEditingController(
      text: _state.profile.orderBudget.toStringAsFixed(2),
    );
    final stores = TextEditingController(
      text: _state.profile.preferredStores.join(', '),
    );
    final rules = TextEditingController(
      text: _state.profile.dietaryRules.join(', '),
    );
    var substitutions = _state.profile.allowSubstitutions;
    final result = await showDialog<PantryProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Pantry policy'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Photo interval (days)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: horizon,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Planning horizon (days)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lead,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low-supply lead time (days)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: budget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Order budget cap',
                      prefixText: '\$',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stores,
                    decoration: const InputDecoration(
                      labelText: 'Preferred stores, comma separated',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rules,
                    decoration: const InputDecoration(
                      labelText: 'Dietary rules, comma separated',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: substitutions,
                    onChanged: (value) =>
                        setLocalState(() => substitutions = value),
                    title: const Text('Allow optional substitutions'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_outline_rounded),
                    title: Text('Checkout approval is always required'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedInterval = int.tryParse(interval.text);
                final parsedHorizon = int.tryParse(horizon.text);
                final parsedLead = int.tryParse(lead.text);
                final parsedBudget = double.tryParse(budget.text);
                if (parsedInterval == null ||
                    parsedHorizon == null ||
                    parsedLead == null ||
                    parsedBudget == null ||
                    parsedInterval < 1 ||
                    parsedHorizon < 1 ||
                    parsedLead < 0 ||
                    parsedBudget < 0) {
                  return;
                }
                Navigator.pop(
                  context,
                  _state.profile.copyWith(
                    scanIntervalDays: parsedInterval.clamp(1, 90).toInt(),
                    planningHorizonDays: parsedHorizon.clamp(1, 90).toInt(),
                    lowSupplyLeadDays: parsedLead.clamp(0, 30).toInt(),
                    orderBudget: parsedBudget.clamp(0, 100000).toDouble(),
                    preferredStores: _csv(stores.text),
                    dietaryRules: _csv(rules.text),
                    allowSubstitutions: substitutions,
                    requireCheckoutApproval: true,
                  ),
                );
              },
              child: const Text('Save policy'),
            ),
          ],
        ),
      ),
    );
    interval.dispose();
    horizon.dispose();
    lead.dispose();
    budget.dispose();
    stores.dispose();
    rules.dispose();
    if (result != null) await _saveProfile(result);
  }

  Future<void> _showItemDialog([PantryItem? source]) async {
    final item = source;
    final name = TextEditingController(text: item?.name ?? '');
    final quantity = TextEditingController(
      text: item == null ? '0' : _quantity(item.quantity),
    );
    final unit = TextEditingController(text: item?.unit ?? 'item');
    final target = TextEditingController(
      text: item == null ? '1' : _quantity(item.targetQuantity),
    );
    final reorder = TextEditingController(
      text: item == null ? '0' : _quantity(item.reorderPoint),
    );
    final dailyUse = TextEditingController(
      text: item == null ? '0' : _quantity(item.dailyUse),
    );
    final price = TextEditingController(
      text: item == null ? '0' : item.estimatedUnitPrice.toStringAsFixed(2),
    );
    var category = item?.category ?? PantryCategory.other;
    var verified = item?.userVerified ?? true;
    var autoRestock = item?.autoRestock ?? true;
    final result = await showDialog<PantryItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(item == null ? 'Add supply item' : 'Edit supply item'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PantryCategory>(
                    value: category,
                    items: PantryCategory.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => category = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Current quantity',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: target,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Target quantity',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: reorder,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Reorder point',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dailyUse,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Estimated use / day',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Estimated unit price',
                            prefixText: '\$',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: verified,
                    onChanged: (value) => setLocalState(() => verified = value),
                    title: const Text('I verified this item and quantity'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoRestock,
                    onChanged: (value) =>
                        setLocalState(() => autoRestock = value),
                    title: const Text('Include in replenishment planning'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_deleteItem(item));
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final itemName = name.text.trim();
                final current = double.tryParse(quantity.text);
                final desired = double.tryParse(target.text);
                final threshold = double.tryParse(reorder.text);
                final use = double.tryParse(dailyUse.text);
                final estimate = double.tryParse(price.text);
                if (itemName.isEmpty ||
                    current == null ||
                    desired == null ||
                    threshold == null ||
                    use == null ||
                    estimate == null ||
                    <double>[
                      current,
                      desired,
                      threshold,
                      use,
                      estimate,
                    ].any((value) => !value.isFinite || value < 0)) {
                  return;
                }
                Navigator.pop(
                  context,
                  PantryItem(
                    id: item?.id ?? newPantryId('item'),
                    name: itemName,
                    category: category,
                    quantity: current,
                    unit: unit.text.trim().isEmpty ? 'item' : unit.text.trim(),
                    targetQuantity: desired,
                    reorderPoint: threshold,
                    dailyUse: use,
                    estimatedUnitPrice: estimate,
                    location: item?.location ?? 'Manual entry',
                    confidence: verified
                        ? PantryConfidence.high
                        : item?.confidence ?? PantryConfidence.low,
                    userVerified: verified,
                    autoRestock: autoRestock,
                    lastSeenAt: item?.lastSeenAt ?? DateTime.now().toUtc(),
                    note: item?.note ?? 'Manual entry',
                  ),
                );
              },
              child: const Text('Save item'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    quantity.dispose();
    unit.dispose();
    target.dispose();
    reorder.dispose();
    dailyUse.dispose();
    price.dispose();
    if (result != null) await _saveItem(result);
  }

  static List<String> _csv(String value) => value
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .take(20)
      .toList(growable: false);

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} '
        '${local.hour}:$minute';
  }

  static IconData _categoryIcon(PantryCategory category) => switch (category) {
    PantryCategory.produce => Icons.eco_outlined,
    PantryCategory.dairy => Icons.local_drink_outlined,
    PantryCategory.protein => Icons.egg_alt_outlined,
    PantryCategory.grain => Icons.bakery_dining_outlined,
    PantryCategory.canned => Icons.soup_kitchen_outlined,
    PantryCategory.frozen => Icons.ac_unit_rounded,
    PantryCategory.beverage => Icons.local_cafe_outlined,
    PantryCategory.snack => Icons.cookie_outlined,
    PantryCategory.household => Icons.cleaning_services_outlined,
    PantryCategory.personalCare => Icons.spa_outlined,
    PantryCategory.pet => Icons.pets_outlined,
    PantryCategory.other => Icons.category_outlined,
  };

  static Color _categoryColor(PantryCategory category) => switch (category) {
    PantryCategory.household ||
    PantryCategory.personalCare => const Color(0xFF7FD7FF),
    PantryCategory.pet => const Color(0xFFFFCF70),
    _ => const Color(0xFF74F5B3),
  };
}

class _Header extends StatelessWidget {
  final String status;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback? onPolicy;

  const _Header({
    required this.status,
    required this.busy,
    required this.onCancel,
    required this.onPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF06130E),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0x3374F5B3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.auto_awesome_motion_rounded,
                color: Color(0xFFC5FFE2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pantry Autopilot',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA7CDBA),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPolicy,
              tooltip: 'Pantry policy',
              icon: const Icon(Icons.tune_rounded),
            ),
            if (busy)
              FilledButton.tonalIcon(
                onPressed: onCancel,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFFFCF70) : const Color(0xFF74F5B3);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFA7CDBA),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x334DCA91)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFFA7CDBA))),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF74F5B3)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA7CDBA)),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;

  const _Bullet({required this.icon, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: warning ? const Color(0xFFFFCF70) : const Color(0xFF74F5B3),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
