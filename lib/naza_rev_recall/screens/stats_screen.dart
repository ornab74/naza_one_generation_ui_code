import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/data/achievements.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stats = app.stats;
    final winRate = stats.gamesPlayed == 0
        ? 0
        : (stats.wins / stats.gamesPlayed * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DRIVER STATS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Local progress stored on this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.65,
                children: [
                  MetricCard(
                    label: 'Games played',
                    value: '${stats.gamesPlayed}',
                    color: AppColors.cyan,
                    icon: Icons.sports_esports_rounded,
                  ),
                  MetricCard(
                    label: 'Wins',
                    value: '${stats.wins}',
                    color: AppColors.amber,
                    icon: Icons.emoji_events_rounded,
                  ),
                  MetricCard(
                    label: 'Best round',
                    value: '${stats.bestRound}',
                    color: AppColors.purple,
                    icon: Icons.trending_up_rounded,
                  ),
                  MetricCard(
                    label: 'Best score',
                    value: '${stats.bestScore}',
                    color: AppColors.pink,
                    icon: Icons.stars_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NeonPanel(
                borderColor: AppColors.green.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.green,
                      size: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$winRate% WIN RATE',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${stats.totalCorrectInputs} correct engine inputs • ${app.totalXp} XP',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionTitle(
                title: 'Achievements',
                trailing: Text(
                  '${app.unlockedAchievementIds.length}/${achievementCatalog.length}',
                  style: const TextStyle(color: AppColors.purple),
                ),
              ),
              const SizedBox(height: 10),
              ...achievementCatalog.map((achievement) {
                final unlocked = app.unlockedAchievementIds.contains(
                  achievement.id,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: NeonPanel(
                    borderColor: unlocked
                        ? AppColors.amber.withValues(alpha: 0.55)
                        : AppColors.border,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: unlocked
                              ? AppColors.amber.withValues(alpha: 0.14)
                              : AppColors.panelBright,
                          foregroundColor: unlocked
                              ? AppColors.amber
                              : AppColors.muted,
                          child: Icon(
                            unlocked ? achievement.icon : Icons.lock_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                achievement.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: unlocked
                                      ? AppColors.text
                                      : AppColors.muted,
                                ),
                              ),
                              Text(
                                achievement.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${achievement.xp} XP',
                          style: TextStyle(
                            color: unlocked ? AppColors.amber : AppColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
