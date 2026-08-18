import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SETTINGS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              NeonPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ENGINE VOLUME',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text('${(app.engineVolume * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: app.engineVolume,
                      onChanged: app.setEngineVolume,
                    ),
                    Row(
                      children: [
                        const Text(
                          'LOW',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            final car = app.activeCars.first;
                            unawaited(
                              AppScope.audioOf(
                                context,
                              ).play(car, volume: app.engineVolume),
                            );
                          },
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text('TEST REV'),
                        ),
                        const Spacer(),
                        const Text(
                          'MAX',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeonPanel(
                child: Column(
                  children: [
                    _SettingSwitch(
                      icon: Icons.vibration_rounded,
                      title: 'Haptics',
                      subtitle: 'Light feedback on every engine input.',
                      value: app.hapticsEnabled,
                      onChanged: app.setHaptics,
                    ),
                    const Divider(),
                    _SettingSwitch(
                      icon: Icons.skip_next_rounded,
                      title: 'Auto-advance rounds',
                      subtitle: 'Start the next sequence automatically.',
                      value: app.autoAdvance,
                      onChanged: app.setAutoAdvance,
                    ),
                    const Divider(),
                    _SettingSwitch(
                      icon: Icons.pin_rounded,
                      title: 'Show sequence positions',
                      subtitle: 'Display numbered input slots under the wheel.',
                      value: app.showSequenceNumbers,
                      onChanged: app.setShowSequenceNumbers,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeonPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: AppColors.cyan),
                        const SizedBox(width: 10),
                        Text(
                          'DIFFICULTY',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Difficulty.values.map((difficulty) {
                        return ChoiceChip(
                          selected: app.difficulty == difficulty,
                          onSelected: (_) => app.setDifficulty(difficulty),
                          avatar: Icon(
                            difficulty == Difficulty.redline
                                ? Icons.local_fire_department_rounded
                                : Icons.speed_rounded,
                            size: 17,
                          ),
                          label: Text(difficulty.label),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sequence speed: ${app.difficulty.flashDuration.inMilliseconds} ms per car • '
                      '${app.difficulty.scoreMultiplier}× score',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeonPanel(
                borderColor: AppColors.red.withValues(alpha: 0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'LOCAL DATA',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Game progress, garage selection, and settings stay on this device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _confirmReset(context),
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('RESET STATS & ACHIEVEMENTS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Audio mode: car sounds only. No background music is included.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset local progress?'),
        content: const Text(
          'This clears stats, preview history, and achievements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppScope.of(context).resetStats();
    }
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.purple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
