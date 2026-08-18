import 'package:flutter/material.dart';

@immutable
class GameStats {
  const GameStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.bestRound = 0,
    this.bestScore = 0,
    this.totalCorrectInputs = 0,
  });

  final int gamesPlayed;
  final int wins;
  final int bestRound;
  final int bestScore;
  final int totalCorrectInputs;

  GameStats copyWith({
    int? gamesPlayed,
    int? wins,
    int? bestRound,
    int? bestScore,
    int? totalCorrectInputs,
  }) {
    return GameStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      bestRound: bestRound ?? this.bestRound,
      bestScore: bestScore ?? this.bestScore,
      totalCorrectInputs: totalCorrectInputs ?? this.totalCorrectInputs,
    );
  }
}

@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.xp,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int xp;
  final IconData icon;
}
