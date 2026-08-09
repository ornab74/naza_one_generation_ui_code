import 'dart:async';

import 'package:flutter/material.dart';

import '../memory/local_memory_service.dart';

/// Settings surface for the embedded local memory database.
/// Memory is enabled by default at the service layer; this card gives the user
/// explicit pause/resume and destructive-clear controls plus useful health
/// information without exposing internal prompt content.
final class NazaSmartMemorySettingsCard extends StatefulWidget {
  const NazaSmartMemorySettingsCard({
    super.key,
    required this.service,
  });

  final NazaLocalMemoryService service;

  @override
  State<NazaSmartMemorySettingsCard> createState() =>
      _NazaSmartMemorySettingsCardState();
}

final class _NazaSmartMemorySettingsCardState
    extends State<NazaSmartMemorySettingsCard> {
  StreamSubscription<NazaMemoryServiceSnapshot>? _subscription;
  NazaMemoryServiceSnapshot? _snapshot;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant NazaSmartMemorySettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) _attach();
  }

  void _attach() {
    _subscription?.cancel();
    _subscription = widget.service.updates.listen((value) {
      if (mounted) setState(() => _snapshot = value);
    });
    unawaited(() async {
      try {
        await widget.service.initialize();
        if (!mounted) return;
        setState(() {
          _snapshot = NazaMemoryServiceSnapshot(
            enabled: widget.service.settings.enabled,
            count: widget.service.memoryCount,
            dirty: false,
            mutationEpoch: 0,
          );
        });
      } catch (error) {
        if (mounted) setState(() => _status = 'Memory unavailable: $error');
      }
    }());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final enabled = _snapshot?.enabled ?? widget.service.settings.enabled;
    setState(() {
      _busy = true;
      _status = enabled ? 'Pausing Smart Memory…' : 'Enabling Smart Memory…';
    });
    try {
      await widget.service.setEnabled(!enabled);
      if (mounted) {
        setState(() => _status = !enabled
            ? 'Smart Memory enabled locally.'
            : 'Smart Memory paused. Existing memories remain encrypted.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Memory setting failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Smart Memory?'),
        content: const Text(
          'This deletes the embedded retrieval index. Conversation history is separate and is not deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Memory'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _status = 'Clearing encrypted retrieval memory…';
    });
    try {
      await widget.service.clear();
      if (mounted) setState(() => _status = 'Smart Memory cleared.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Clear failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _snapshot;
    final enabled = snapshot?.enabled ?? widget.service.settings.enabled;
    final settings = widget.service.settings;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        border: Border.all(
          color: enabled
              ? scheme.primary.withValues(alpha: 0.32)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: enabled
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHigh,
                ),
                child: Icon(
                  Icons.hub_outlined,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Smart Memory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      enabled ? 'Embedded hybrid retrieval is active' : 'Paused by you',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: _busy ? null : (_) => unawaited(_toggle()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Local ANN + lexical retrieval ranks memories by semantic relevance, keyword evidence, salience, recency, confidence, reinforcement and thread affinity, then diversifies results with MMR.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricChip(label: '${snapshot?.count ?? widget.service.memoryCount} memories'),
              _MetricChip(label: '${settings.retrievalLimit} recall slots'),
              const _MetricChip(label: '128-D local vectors'),
              const _MetricChip(label: 'Encrypted at rest'),
              const _MetricChip(label: 'No memory server'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_clear()),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear Memory'),
              ),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_status != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

final class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHigh
              .withValues(alpha: 0.72),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      );
}
