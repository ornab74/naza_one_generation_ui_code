import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/models/stats_models.dart';

const List<AchievementDefinition> achievementCatalog = [
  AchievementDefinition(
    id: 'first_ignition',
    title: 'First Ignition',
    description: 'Finish your first memory run.',
    xp: 25,
    icon: Icons.key_rounded,
  ),
  AchievementDefinition(
    id: 'pattern_master',
    title: 'Pattern Master',
    description: 'Reach round 10 in any mode.',
    xp: 100,
    icon: Icons.psychology_rounded,
  ),
  AchievementDefinition(
    id: 'perfect_lap',
    title: 'Perfect Lap',
    description: 'Clear five rounds without a mistake.',
    xp: 75,
    icon: Icons.route_rounded,
  ),
  AchievementDefinition(
    id: 'garage_collector',
    title: 'Full Grid',
    description: 'Fill all eight active garage slots.',
    xp: 50,
    icon: Icons.garage_rounded,
  ),
  AchievementDefinition(
    id: 'sound_check',
    title: 'Sound Check',
    description: 'Preview every car sound in the garage.',
    xp: 125,
    icon: Icons.graphic_eq_rounded,
  ),
  AchievementDefinition(
    id: 'party_starter',
    title: 'Party Starter',
    description: 'Launch a Party Mode game.',
    xp: 40,
    icon: Icons.groups_rounded,
  ),
  AchievementDefinition(
    id: 'redline_memory',
    title: 'Redline Memory',
    description: 'Reach round 15 on Redline difficulty.',
    xp: 250,
    icon: Icons.local_fire_department_rounded,
  ),
];
