import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum NazaOnboardingModelPhase {
  checking,
  missing,
  downloading,
  verifying,
  ready,
  failed,
}

final class NazaOnboardingModelState {
  const NazaOnboardingModelState({
    required this.phase,
    this.progress,
    this.message = '',
    this.localPath,
    this.bytesReceived,
    this.totalBytes,
  });

  final NazaOnboardingModelPhase phase;
  final double? progress;
  final String message;
  final String? localPath;
  final int? bytesReceived;
  final int? totalBytes;

  bool get ready => phase == NazaOnboardingModelPhase.ready;
  bool get busy => phase == NazaOnboardingModelPhase.checking ||
      phase == NazaOnboardingModelPhase.downloading ||
      phase == NazaOnboardingModelPhase.verifying;
}

typedef NazaEnsureModel = Future<void> Function();
typedef NazaChooseLocalModel = Future<void> Function();

/// First-run model acquisition + compact guide. The caller owns persistence of
/// the completed flag so this gate is shown once and future launches go Chat.
final class NazaFirstRunOnboarding extends StatefulWidget {
  const NazaFirstRunOnboarding({
    super.key,
    required this.modelState,
    required this.ensureModel,
    required this.onComplete,
    this.chooseLocalModel,
    this.autoStartDownload = true,
    this.modelName = 'Gemma 4 E2B',
  });

  final ValueListenable<NazaOnboardingModelState> modelState;
  final NazaEnsureModel ensureModel;
  final NazaChooseLocalModel? chooseLocalModel;
  final FutureOr<void> Function() onComplete;
  final bool autoStartDownload;
  final String modelName;

  @override
  State<NazaFirstRunOnboarding> createState() => _NazaFirstRunOnboardingState();
}

final class _NazaFirstRunOnboardingState extends State<NazaFirstRunOnboarding> {
  bool _autoAttempted = false;
  bool _showHelp = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.modelState.addListener(_modelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
  }

  @override
  void didUpdateWidget(covariant NazaFirstRunOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.modelState, widget.modelState)) {
      oldWidget.modelState.removeListener(_modelChanged);
      widget.modelState.addListener(_modelChanged);
    }
  }

  @override
  void dispose() {
    widget.modelState.removeListener(_modelChanged);
    super.dispose();
  }

  void _modelChanged() {
    if (!mounted) return;
    if (widget.modelState.value.ready && !_showHelp) {
      setState(() => _showHelp = true);
    }
  }

  void _maybeAutoStart() {
    if (!mounted || _autoAttempted || !widget.autoStartDownload) return;
    final state = widget.modelState.value;
    if (state.ready) {
      setState(() => _showHelp = true);
      return;
    }
    if (state.phase == NazaOnboardingModelPhase.missing ||
        state.phase == NazaOnboardingModelPhase.failed) {
      _autoAttempted = true;
      unawaited(_ensure());
    }
  }

  Future<void> _ensure() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.ensureModel();
      if (mounted && widget.modelState.value.ready) {
        setState(() => _showHelp = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseLocal() async {
    final choose = widget.chooseLocalModel;
    if (_busy || choose == null) return;
    setState(() => _busy = true);
    try {
      await choose();
      if (mounted && widget.modelState.value.ready) {
        setState(() => _showHelp = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaOnboardingModelState>(
      valueListenable: widget.modelState,
      builder: (context, state, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _showHelp && state.ready
                  ? _HelpCard(
                      key: const ValueKey<String>('help'),
                      modelName: widget.modelName,
                      onComplete: widget.onComplete,
                    )
                  : _ModelSetupCard(
                      key: const ValueKey<String>('model'),
                      modelName: widget.modelName,
                      state: state,
                      actionBusy: _busy,
                      onEnsure: _ensure,
                      onChooseLocal: widget.chooseLocalModel == null ? null : _chooseLocal,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ModelSetupCard extends StatelessWidget {
  const _ModelSetupCard({
    super.key,
    required this.modelName,
    required this.state,
    required this.actionBusy,
    required this.onEnsure,
    this.onChooseLocal,
  });

  final String modelName;
  final NazaOnboardingModelState state;
  final bool actionBusy;
  final Future<void> Function() onEnsure;
  final Future<void> Function()? onChooseLocal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progress(state);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            scheme.surface.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 46,
            spreadRadius: -18,
            color: scheme.primary.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _StatusOrb(ready: state.ready),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Private model setup',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$modelName runs locally after its integrity check passes.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StatusLine(state: state),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 7),
            Text(_progressLabel(state), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.verified_user_outlined, size: 19),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'NAZA verifies the model before inference. Partial or mismatched model data is never marked trusted.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: state.busy || actionBusy ? null : onEnsure,
                icon: Icon(
                  state.phase == NazaOnboardingModelPhase.failed
                      ? Icons.refresh_rounded
                      : Icons.download_rounded,
                ),
                label: Text(
                  state.phase == NazaOnboardingModelPhase.failed
                      ? 'Retry secure setup'
                      : state.ready
                          ? 'Continue'
                          : 'Download & verify',
                ),
              ),
              if (onChooseLocal != null)
                OutlinedButton.icon(
                  onPressed: state.busy || actionBusy ? null : onChooseLocal,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Use local model'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static double? _progress(NazaOnboardingModelState state) {
    if (state.progress case final p?) return p.clamp(0.0, 1.0);
    final received = state.bytesReceived;
    final total = state.totalBytes;
    if (received == null || total == null || total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }

  static String _progressLabel(NazaOnboardingModelState state) {
    final progress = _progress(state);
    if (progress == null) return 'Preparing…';
    final percent = (progress * 100).toStringAsFixed(progress < 0.1 ? 1 : 0);
    if (state.bytesReceived != null && state.totalBytes != null) {
      return '$percent% · ${_bytes(state.bytesReceived!)} / ${_bytes(state.totalBytes!)}';
    }
    return '$percent%';
  }

  static String _bytes(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit >= 2 ? 1 : 0)} ${units[unit]}';
  }
}

final class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.ready});
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            scheme.primary,
            scheme.tertiary,
            scheme.secondary,
            scheme.primary,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 22,
            color: scheme.primary.withValues(alpha: 0.34),
          ),
        ],
      ),
      child: Icon(
        ready ? Icons.check_rounded : Icons.memory_rounded,
        color: scheme.onPrimary,
      ),
    );
  }
}

final class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final NazaOnboardingModelState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (state.phase) {
      NazaOnboardingModelPhase.checking => (Icons.search_rounded, 'Checking local model'),
      NazaOnboardingModelPhase.missing => (Icons.cloud_download_outlined, 'Model is ready to download'),
      NazaOnboardingModelPhase.downloading => (Icons.downloading_rounded, 'Downloading model'),
      NazaOnboardingModelPhase.verifying => (Icons.verified_outlined, 'Verifying SHA-256 integrity'),
      NazaOnboardingModelPhase.ready => (Icons.check_circle_outline_rounded, 'Verified model ready'),
      NazaOnboardingModelPhase.failed => (Icons.error_outline_rounded, 'Model setup needs attention'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: state.phase == NazaOnboardingModelPhase.failed ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (state.message.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(state.message, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

final class _HelpCard extends StatelessWidget {
  const _HelpCard({
    super.key,
    required this.modelName,
    required this.onComplete,
  });

  final String modelName;
  final FutureOr<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        color: scheme.surface.withValues(alpha: 0.96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You’re ready to chat',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$modelName is verified and available locally. These are the controls worth knowing.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          const _HelpRow(
            icon: Icons.lock_outline_rounded,
            title: 'Private local inference',
            detail: 'Normal chats use the on-device model. Private memory remains local and encrypted at rest.',
          ),
          const _HelpRow(
            icon: Icons.psychology_alt_outlined,
            title: 'Smart Memory is on by default',
            detail: 'Relevant context is retrieved automatically. Pause or clear Smart Memory from Settings at any time.',
          ),
          const _HelpRow(
            icon: Icons.menu_open_rounded,
            title: 'Past chats',
            detail: 'Use History to search, reopen, pin, rename, or delete conversations.',
          ),
          const _HelpRow(
            icon: Icons.vertical_align_bottom_rounded,
            title: 'Streaming respects your scroll',
            detail: 'Scroll upward during generation and auto-follow detaches until you return to the latest message.',
          ),
          const _HelpRow(
            icon: Icons.speed_rounded,
            title: 'Local acceleration',
            detail: 'NAZA prefers hardware acceleration when supported and can fall back to a working backend when initialization fails.',
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async => onComplete(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open Chat'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.primaryContainer.withValues(alpha: 0.54),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
