import 'package:flutter/material.dart';

enum GameMode { classic, elimination, party }

enum Difficulty { cruise, sport, track, redline }

enum GamePhase { idle, countdown, watching, input, roundWon, wrong, gameOver }

extension GameModeX on GameMode {
  String get label => switch (this) {
    GameMode.classic => 'Classic',
    GameMode.elimination => 'Elimination',
    GameMode.party => 'Party Mode',
  };

  String get description => switch (this) {
    GameMode.classic => 'One mistake ends the run.',
    GameMode.elimination => 'Three lives. Keep the streak alive.',
    GameMode.party => 'Pass the phone and rotate drivers.',
  };

  IconData get icon => switch (this) {
    GameMode.classic => Icons.blur_circular_rounded,
    GameMode.elimination => Icons.emoji_events_rounded,
    GameMode.party => Icons.groups_rounded,
  };
}

extension DifficultyX on Difficulty {
  String get label => switch (this) {
    Difficulty.cruise => 'Cruise',
    Difficulty.sport => 'Sport',
    Difficulty.track => 'Track',
    Difficulty.redline => 'Redline',
  };

  int get startingLength => switch (this) {
    Difficulty.cruise => 2,
    Difficulty.sport => 3,
    Difficulty.track => 4,
    Difficulty.redline => 5,
  };

  Duration get flashDuration => switch (this) {
    Difficulty.cruise => const Duration(milliseconds: 620),
    Difficulty.sport => const Duration(milliseconds: 500),
    Difficulty.track => const Duration(milliseconds: 390),
    Difficulty.redline => const Duration(milliseconds: 290),
  };

  double get scoreMultiplier => switch (this) {
    Difficulty.cruise => 1.0,
    Difficulty.sport => 1.25,
    Difficulty.track => 1.6,
    Difficulty.redline => 2.0,
  };
}

@immutable
class PartyPlayer {
  const PartyPlayer({
    required this.id,
    required this.name,
    required this.colorValue,
    this.score = 0,
    this.lives = 3,
  });

  final String id;
  final String name;
  final int colorValue;
  final int score;
  final int lives;

  Color get color => Color(colorValue);

  PartyPlayer copyWith({String? name, int? score, int? lives}) {
    return PartyPlayer(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue,
      score: score ?? this.score,
      lives: lives ?? this.lives,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'score': score,
  };

  factory PartyPlayer.fromJson(Map<String, Object?> json) {
    return PartyPlayer(
      id: json['id']! as String,
      name: json['name']! as String,
      colorValue: json['colorValue']! as int,
      score: (json['score'] as int?) ?? 0,
    );
  }
}
