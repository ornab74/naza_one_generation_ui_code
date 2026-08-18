import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/data/achievements.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UtilityScaffold(
      title: 'HOW TO PLAY',
      children: [
        _HowToStep(
          number: '1',
          title: 'Listen',
          body: 'The wheel plays a growing sequence of engine profiles.',
          icon: Icons.hearing_rounded,
        ),
        _HowToStep(
          number: '2',
          title: 'Remember',
          body:
              'Match each sound to its glowing car segment and keep the order in memory.',
          icon: Icons.psychology_rounded,
        ),
        _HowToStep(
          number: '3',
          title: 'Repeat',
          body:
              'Tap the car segments in exactly the same order. One new engine is added each round.',
          icon: Icons.touch_app_rounded,
        ),
        _HowToStep(
          number: '4',
          title: 'Choose your pressure',
          body:
              'Classic gives one life, Elimination gives three, and Party Mode rotates drivers.',
          icon: Icons.local_fire_department_rounded,
        ),
        SizedBox(height: 10),
        NeonPanel(
          borderColor: AppColors.cyan,
          child: Text(
            'Headphones help separate the bass-heavy V8s, boxer rhythm, high-rev V10, turbo sixes, '
            'three-cylinder beat, and electric whine.',
          ),
        ),
      ],
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final players = [...app.partyPlayers]
      ..sort((a, b) => b.score.compareTo(a.score));
    return _UtilityScaffold(
      title: 'LOCAL LEADERBOARD',
      children: [
        NeonPanel(
          borderColor: AppColors.amber,
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.amber,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PERSONAL BEST',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${app.stats.bestScore} points • round ${app.stats.bestRound}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...players.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeonPanel(
              borderColor: entry.value.color.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Text(
                    '#${entry.key + 1}',
                    style: TextStyle(
                      color: entry.key == 0 ? AppColors.amber : AppColors.muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      entry.value.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${entry.value.score} pts',
                    style: TextStyle(color: entry.value.color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Party scores are live during a run. Persistent global accounts are intentionally not included.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _UtilityScaffold(
      title: 'ACHIEVEMENTS',
      children: achievementCatalog.map((achievement) {
        final unlocked = app.unlockedAchievementIds.contains(achievement.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: NeonPanel(
            borderColor: unlocked ? AppColors.amber : AppColors.border,
            glowColor: unlocked ? AppColors.amber : null,
            child: Row(
              children: [
                Icon(
                  unlocked ? achievement.icon : Icons.lock_rounded,
                  color: unlocked ? AppColors.amber : AppColors.muted,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        achievement.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text('${achievement.xp} XP'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UtilityScaffold extends StatelessWidget {
  const _UtilityScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  const _HowToStep({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String number;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeonPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.purple.withValues(alpha: 0.2),
              foregroundColor: AppColors.purple,
              child: Text(
                number,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.cyan),
                      const SizedBox(width: 7),
                      Text(
                        title.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
