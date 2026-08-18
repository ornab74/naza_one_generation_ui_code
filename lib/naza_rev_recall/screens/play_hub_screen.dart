import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/screens/game_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/players_screen.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class PlayHubScreen extends StatelessWidget {
  const PlayHubScreen({super.key});

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
              Text('PLAY', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text(
                'Choose a mode, listen to the sequence, then tap the matching cars.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              ...GameMode.values.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ModeCard(
                    mode: mode,
                    selected: app.selectedMode == mode,
                    onSelect: () => app.selectMode(mode),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NeonPanel(
                borderColor: AppColors.cyan.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT SETUP',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${app.difficulty.label} • ${app.activeCarIds.length} cars • '
                            '${app.autoAdvance ? 'auto-advance' : 'manual advance'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (app.selectedMode == GameMode.party) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlayersScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.groups_rounded),
                  label: Text('EDIT ${app.partyPlayers.length} PARTY PLAYERS'),
                ),
              ],
              const SizedBox(height: 18),
              NeonButton(
                label: 'Start ${app.selectedMode.label}',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(mode: app.selectedMode),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onSelect,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      onTap: onSelect,
      borderColor: selected ? AppColors.purple : AppColors.border,
      glowColor: selected ? AppColors.purple : null,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(mode.icon, color: AppColors.purple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  mode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.green : AppColors.muted,
          ),
        ],
      ),
    );
  }
}
