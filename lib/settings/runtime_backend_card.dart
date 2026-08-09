import 'package:flutter/material.dart';

import '../model/runtime_profile.dart';

/// Compact diagnostics card for proving which inference backend is active.
/// It deliberately does not infer GPU use from throughput; callers update the
/// telemetry only after model initialization succeeds or falls back.
final class NazaRuntimeBackendCard extends StatefulWidget {
  NazaRuntimeBackendCard({
    super.key,
    NazaRuntimeTelemetry? telemetry,
  }) : telemetry = telemetry ?? NazaRuntimeTelemetry.instance;

  final NazaRuntimeTelemetry telemetry;

  @override
  State<NazaRuntimeBackendCard> createState() => _NazaRuntimeBackendCardState();
}

final class _NazaRuntimeBackendCardState extends State<NazaRuntimeBackendCard> {
  late NazaLiteRtRuntimeProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.telemetry.profile;
    widget.telemetry.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant NazaRuntimeBackendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.telemetry, widget.telemetry)) {
      oldWidget.telemetry.removeListener(_changed);
      _profile = widget.telemetry.profile;
      widget.telemetry.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.telemetry.removeListener(_changed);
    super.dispose();
  }

  void _changed(NazaLiteRtRuntimeProfile value) {
    if (mounted) setState(() => _profile = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeGpu = _profile.gpuConfirmed;
    final fallback = _profile.cpuFallback;
    final stateIcon = activeGpu
        ? Icons.bolt_rounded
        : fallback
            ? Icons.swap_horiz_rounded
            : Icons.memory_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        border: Border.all(
          color: activeGpu
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outlineVariant.withValues(alpha: 0.44),
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
                  color: activeGpu
                      ? scheme.primaryContainer.withValues(alpha: 0.62)
                      : scheme.surfaceContainerHigh,
                ),
                child: Icon(stateIcon, color: activeGpu ? scheme.primary : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Inference Runtime',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile.compactLabel,
                      style: TextStyle(
                        color: activeGpu ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _RuntimeChip(label: _profile.platform),
              _RuntimeChip(label: 'bridge ${_profile.dartBridge}'),
              _RuntimeChip(label: 'native ${_profile.nativeRuntime}'),
              if (_profile.windowsGpuNoCache)
                const _RuntimeChip(label: 'GPU cache :nocache'),
              _RuntimeChip(
                label: 'requested ${_profile.requestedBackend.name.toUpperCase()}',
              ),
              _RuntimeChip(
                label: 'actual ${_profile.actualBackend.name.toUpperCase()}',
              ),
            ],
          ),
          if (_profile.adapter case final adapter?) ...<Widget>[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.developer_board_outlined,
              title: 'Adapter',
              value: adapter,
            ),
          ],
          if (_profile.failureReason case final reason?) ...<Widget>[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.info_outline_rounded,
              title: fallback ? 'Fallback reason' : 'Backend error',
              value: reason,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            activeGpu
                ? 'GPU is confirmed by successful backend initialization telemetry.'
                : fallback
                    ? 'GPU was requested but inference is currently using the CPU fallback.'
                    : 'GPU is not marked active until backend initialization explicitly succeeds.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
          ),
        ],
      ),
    );
  }
}

final class _RuntimeChip extends StatelessWidget {
  const _RuntimeChip({required this.label});
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

final class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      );
}
