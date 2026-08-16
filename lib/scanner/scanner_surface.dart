// LLM-CONTEXT:BEGIN
// FILE: lib/scanner/scanner_surface.dart
// ROLE: Owns scanner surface behavior within the scanner subsystem.
// DOMAIN: scanner
// SECURITY-INVARIANT: Never fabricate a safety classification when parsing, generation, or evidence is incomplete.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter/material.dart';

/// Shared responsive chrome for Naza scanners.
///
/// Compact/mobile layouts put Start/Stop in the top-right and stack scanner
/// stages vertically. Wide desktop layouts use a continuous two-pane surface
/// so evidence/input can remain visible while results update beside it.
final class NazaScannerSurface extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool started;
  final bool busy;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final Widget primary;
  final Widget secondary;
  final Widget? tray;
  final double wideBreakpoint;

  const NazaScannerSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.started,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.primary,
    required this.secondary,
    this.tray,
    this.wideBreakpoint = 900,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ScannerHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              started: started,
              busy: busy,
              onStart: onStart,
              onStop: onStop,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: wide
                  ? _WideScannerFlow(primary: primary, secondary: secondary)
                  : _CompactScannerFlow(
                      primary: primary,
                      secondary: secondary,
                    ),
            ),
            if (tray != null) ...<Widget>[
              const SizedBox(height: 10),
              NazaScannerTray(child: tray!),
            ],
          ],
        );
      },
    );
  }
}

final class _ScannerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool started;
  final bool busy;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  const _ScannerHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.started,
    required this.busy,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(28),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!started)
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              )
            else if (busy)
              FilledButton.tonalIcon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              )
            else
              const _ReadyPill(),
          ],
        ),
      ),
    );
  }
}

final class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          const Text('Ready', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

final class _WideScannerFlow extends StatelessWidget {
  final Widget primary;
  final Widget secondary;

  const _WideScannerFlow({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 11,
            child: _ScannerPane(
              label: 'Evidence & controls',
              icon: Icons.tune_rounded,
              child: primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 13,
            child: _ScannerPane(
              label: 'Live result',
              icon: Icons.analytics_outlined,
              child: secondary,
            ),
          ),
        ],
      );
}

final class _CompactScannerFlow extends StatelessWidget {
  final Widget primary;
  final Widget secondary;

  const _CompactScannerFlow({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) => ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          _ScannerPane(
            label: 'Evidence & controls',
            icon: Icons.tune_rounded,
            child: primary,
          ),
          const SizedBox(height: 12),
          _ScannerPane(
            label: 'Result',
            icon: Icons.analytics_outlined,
            child: secondary,
          ),
        ],
      );
}

final class _ScannerPane extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _ScannerPane({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 19, color: scheme.primary),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withAlpha(110)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Cleaner secondary tray: collapsed by default, bounded in height, and owned
/// by the current scanner rather than floating as an unrelated app panel.
final class NazaScannerTray extends StatefulWidget {
  final Widget child;
  final String label;
  final IconData icon;

  const NazaScannerTray({
    super.key,
    required this.child,
    this.label = 'Secondary tray',
    this.icon = Icons.layers_outlined,
  });

  @override
  State<NazaScannerTray> createState() => _NazaScannerTrayState();
}

class _NazaScannerTrayState extends State<NazaScannerTray> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(widget.icon, size: 19, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
