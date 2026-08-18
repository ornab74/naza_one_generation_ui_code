import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_controller.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/screens/game_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/players_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/utility_screens.dart';
import 'package:naza_one/naza_rev_recall/widgets/car_wheel.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelSize = math.min(330.0, constraints.maxWidth - 44);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _showAbout(context),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PlayersScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.groups_rounded),
                        tooltip: 'Players',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const GradientTitle(text: 'REV//RECALL'),
                  const SizedBox(height: 8),
                  Text(
                    'MEMORIZE THE MACHINE.\nMASTER THE SOUND.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.1,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  CarWheel(
                    cars: app.activeCars,
                    centerLabel: 'REV',
                    size: wheelSize,
                    enabled: false,
                  ),
                  const SizedBox(height: 20),
                  _ModeSelector(app: app),
                  const SizedBox(height: 12),
                  NeonButton(
                    label: 'Quick Play',
                    icon: Icons.bolt_rounded,
                    onPressed: () => _launchGame(context, app.selectedMode),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Shortcut(
                          icon: Icons.help_outline_rounded,
                          label: 'How to play',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HowToPlayScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Shortcut(
                          icon: Icons.leaderboard_rounded,
                          label: 'Leaderboard',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Shortcut(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Achievements',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AchievementsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${app.activeCarIds.length}/8 engine slots active • ${app.difficulty.label} difficulty',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _launchGame(BuildContext context, GameMode mode) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => GameScreen(mode: mode)));
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REV//RECALL',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text(
              'A car-only memory game. Every segment has a distinct procedural engine profile. '
              'No music, instruments, shock hardware, or copied YouTube audio is included.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GameMode.values.map((mode) {
        final selected = app.selectedMode == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode == GameMode.party ? 0 : 8),
            child: NeonPanel(
              onTap: () => app.selectMode(mode),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              borderColor: selected ? AppColors.purple : AppColors.border,
              glowColor: selected ? AppColors.purple : null,
              child: Column(
                children: [
                  Icon(
                    mode.icon,
                    color: selected ? AppColors.amber : AppColors.purple,
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    child: Text(
                      mode.label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Column(
        children: [
          Icon(icon, color: AppColors.purple, size: 21),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
