import 'dart:async';

import 'package:flutter/material.dart';

/// Platform-neutral view state supplied by NAZA's existing secure model store.
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

/// First-run gate: securely acquire/verify the model, give the user a compact
/// explanation, then hand off to Chat. Automatic acquisition is attempted once
/// per mount; failures stay recoverable with retry/local-file controls.
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
  bool _started = false;
  bool _showHelp = false;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    widget.modelState.addListener(_modelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
  }

  @override
  void didUpdateWidget(covariant NazaFirstRunOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelState != widget.modelState) {
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
    final ready = widget.modelState.value.ready;
    if (ready && !_showHelp) setState(() => _showHelp = true);
  }

  void _maybeAutoStart() {
    if (!mounted || _started || !widget.autoStartDownload) return;
    final state = widget.modelState.value;
    if (state.ready) {
      setState(() => _showHelp = true);
      return;
    }
    if (state.phase == NazaOnboardingModelPhase.missing ||
        state.phase == NazaOnboardingModelPhase.failed) {
      _started = true;
      unawaited(_runEnsureModel());
    }
  }

  Future<void> _runEnsureModel() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await widget.ensureModel();
      if (mounted && widget.modelState.value.ready) {
        setState(() => _showHelp = true);
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NazaOnboardingModelState>(
      valueListenable: widget.modelState,
      builder: (context, state, _) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showHelp && state.ready
                    ? _NazaHelpCard(
                        key: const ValueKey('help'),
                        modelName: widget.modelName,
                        onContinue: () async => widget.onComplete(),
                      )
                    : _modelCard(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _modelCard(BuildContext context, NazaOnboardingModelState state) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progress(state);
    return Container(
      key: const ValueKey('model'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            scheme.surface.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 50,
            spreadRadius: -18,
            color: scheme.primary.withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _orb(context, state),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Private model setup',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.modelName} runs locally on this device after setup.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _statusRow(context, state),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text(_progressLabel(state), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.verified_user_outlined, size: 19),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'NAZA verifies the model before inference. A partial or mismatched download is never treated as trusted model data.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: state.busy || _actionBusy ? null : _runEnsureModel,
                icon: Icon(state.phase == NazaOnboardingModelPhase.failed
                    ? Icons.refresh_rounded
                    : Icons.download_rounded),
                label: Text(state.phase == NazaOnboardingModelPhase.failed
                    ? 'Retry secure setup'
                    : state.ready
                        ? 'Continue'
                        : 'Download & verify'),
              ),
              if (widget.chooseLocalModel != null)
                OutlinedButton.icon(
                  onPressed: state.busy || _actionBusy
                      ? null
                      : () async {
                          setState(() => _actionBusy = true);
                          try {
                            await widget.chooseLocalModel!();
                          } finally {
                            if (mounted) setState(() => _actionBusy = false);
                          }
                        },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Use local model'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orb(BuildContext context, NazaOnboardingModelState state) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: <Color>[
          scheme.primary,
          scheme.tertiary,
          scheme.secondary,
          scheme.primary,
        ]),
        boxShadow: <BoxShadow>[
          BoxShadow(blurRadius: 22, color: scheme.primary.withValues(alpha: 0.34)),
        ],
      ),
      child: Icon(
        state.ready ? Icons.check_rounded : Icons.memory_rounded,
        color: scheme.onPrimary,
        size: 27,
      ),
    );
  }

  Widget _statusRow(BuildContext context, NazaOnboardingModelState state) {
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
        Icon(icon, color: state.phase == NazaOnboardingModelPhase.failed ? scheme.error : scheme.primary),
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

  static double? _progress(NazaOnboardingModelState state) {
    final explicit = state.progress;
    if (explicit != null) return explicit.clamp(0.0, 1.0);
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

final class _NazaHelpCard extends StatelessWidget {
  const _NazaHelpCard({
    super.key,
    required this.modelName,
    required this.onContinue,
  });

  final String modelName;
  final FutureOr<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        color: scheme.surface.withValues(alpha: 0.95),
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$modelName is verified and available locally. Here are the controls worth knowing.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          const _HelpRow(
            icon: Icons.lock_outline_rounded,
            title: 'Private local inference',
            detail: 'Normal chats use the on-device model; your memory index is local and encrypted at rest.',
          ),
          const _HelpRow(
            icon: Icons.psychology_alt_outlined,
            title: 'Smart Memory is on by default',
            detail: 'Relevant past context is retrieved automatically. You can pause or clear it from Settings.',
          ),
          const _HelpRow(
            icon: Icons.menu_open_rounded,
            title: 'Past chats',
            detail: 'Use the history button to search, reopen, pin, rename, or delete private conversations.',
          ),
          const _HelpRow(
            icon: Icons.vertical_align_bottom_rounded,
            title: 'Streaming respects your scroll',
            detail: 'If you scroll up while NAZA is answering, auto-follow detaches until you return to the latest message.',
          ),
          const _HelpRow(
            icon: Icons.tune_rounded,
            title: 'Model management',
            detail: 'Settings shows model integrity and backend controls. Unsupported acceleration can fall back to a working backend.',
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async => onContinue(),
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
  const _HelpRow({required this.icon, required this.title, required this.detail});

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
                Text(detail, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
