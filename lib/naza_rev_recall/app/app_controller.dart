import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/data/achievements.dart';
import 'package:naza_one/naza_rev_recall/data/car_catalog.dart';
import 'package:naza_one/naza_rev_recall/models/car_profile.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/models/stats_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppController extends ChangeNotifier {
  static const _activeCarsKey = 'active_car_ids';
  static const _volumeKey = 'engine_volume';
  static const _hapticsKey = 'haptics';
  static const _autoAdvanceKey = 'auto_advance';
  static const _showNumbersKey = 'show_sequence_numbers';
  static const _difficultyKey = 'difficulty';
  static const _playersKey = 'party_players';
  static const _unlockedKey = 'unlocked_achievements';
  static const _previewedKey = 'previewed_cars';

  static const _gamesKey = 'stats_games';
  static const _winsKey = 'stats_wins';
  static const _bestRoundKey = 'stats_best_round';
  static const _bestScoreKey = 'stats_best_score';
  static const _correctInputsKey = 'stats_correct_inputs';

  SharedPreferences? _preferences;
  Timer? _saveDebounce;

  bool isReady = false;
  double engineVolume = 0.82;
  bool hapticsEnabled = true;
  bool autoAdvance = true;
  bool showSequenceNumbers = true;
  Difficulty difficulty = Difficulty.sport;
  GameMode selectedMode = GameMode.classic;

  List<String> activeCarIds = List<String>.of(defaultActiveCarIds);
  List<PartyPlayer> partyPlayers = const [
    PartyPlayer(id: 'driver-1', name: 'YOU', colorValue: 0xFF9B5CFF),
    PartyPlayer(id: 'driver-2', name: 'MAYA', colorValue: 0xFF22D3EE),
    PartyPlayer(id: 'driver-3', name: 'JAY', colorValue: 0xFF76FF03),
    PartyPlayer(id: 'driver-4', name: 'LEX', colorValue: 0xFFFF6D3A),
  ];
  Set<String> unlockedAchievementIds = <String>{};
  Set<String> previewedCarIds = <String>{};
  GameStats stats = const GameStats();

  List<CarProfile> get activeCars =>
      activeCarIds.map(carById).toList(growable: false);

  int get totalXp => achievementCatalog
      .where((achievement) => unlockedAchievementIds.contains(achievement.id))
      .fold(0, (sum, achievement) => sum + achievement.xp);

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final prefs = _preferences!;

    final storedCars = prefs.getStringList(_activeCarsKey);
    if (storedCars != null) {
      final valid = storedCars
          .where((id) => carCatalog.any((car) => car.id == id))
          .toList();
      if (valid.length >= 4) {
        activeCarIds = valid.take(8).toList();
      }
    }

    engineVolume = prefs.getDouble(_volumeKey) ?? engineVolume;
    hapticsEnabled = prefs.getBool(_hapticsKey) ?? hapticsEnabled;
    autoAdvance = prefs.getBool(_autoAdvanceKey) ?? autoAdvance;
    showSequenceNumbers = prefs.getBool(_showNumbersKey) ?? showSequenceNumbers;

    final storedDifficulty = prefs.getString(_difficultyKey);
    difficulty = Difficulty.values.firstWhere(
      (value) => value.name == storedDifficulty,
      orElse: () => difficulty,
    );

    final encodedPlayers = prefs.getStringList(_playersKey);
    if (encodedPlayers != null && encodedPlayers.isNotEmpty) {
      try {
        partyPlayers = encodedPlayers
            .map(
              (entry) => PartyPlayer.fromJson(
                jsonDecode(entry) as Map<String, Object?>,
              ),
            )
            .toList();
      } on FormatException {
        // Keep defaults if a previous save was malformed.
      }
    }

    unlockedAchievementIds =
        (prefs.getStringList(_unlockedKey) ?? const <String>[]).toSet();
    previewedCarIds = (prefs.getStringList(_previewedKey) ?? const <String>[])
        .toSet();
    stats = GameStats(
      gamesPlayed: prefs.getInt(_gamesKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      bestRound: prefs.getInt(_bestRoundKey) ?? 0,
      bestScore: prefs.getInt(_bestScoreKey) ?? 0,
      totalCorrectInputs: prefs.getInt(_correctInputsKey) ?? 0,
    );

    isReady = true;
    notifyListeners();
  }

  void selectMode(GameMode mode) {
    selectedMode = mode;
    notifyListeners();
  }

  void setEngineVolume(double value) {
    engineVolume = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    _scheduleSave();
  }

  void setHaptics(bool value) {
    hapticsEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  void setAutoAdvance(bool value) {
    autoAdvance = value;
    notifyListeners();
    _scheduleSave();
  }

  void setShowSequenceNumbers(bool value) {
    showSequenceNumbers = value;
    notifyListeners();
    _scheduleSave();
  }

  void setDifficulty(Difficulty value) {
    difficulty = value;
    notifyListeners();
    _scheduleSave();
  }

  bool toggleActiveCar(String id) {
    if (activeCarIds.contains(id)) {
      if (activeCarIds.length <= 4) {
        return false;
      }
      activeCarIds.remove(id);
    } else {
      if (activeCarIds.length >= 8) {
        return false;
      }
      activeCarIds.add(id);
    }
    if (activeCarIds.length == 8) {
      unlockAchievement('garage_collector');
    }
    notifyListeners();
    _scheduleSave();
    return true;
  }

  void recordCarPreview(String id) {
    previewedCarIds.add(id);
    if (previewedCarIds.length == carCatalog.length) {
      unlockAchievement('sound_check');
    }
    notifyListeners();
    _scheduleSave();
  }

  void addPartyPlayer(String name) {
    if (partyPlayers.length >= 8 || name.trim().isEmpty) {
      return;
    }
    const colors = [
      0xFFFF4FB8,
      0xFFFFC93D,
      0xFF53F087,
      0xFF2979FF,
      0xFFFF6D3A,
      0xFF00E5FF,
      0xFFB388FF,
      0xFFFF5252,
    ];
    partyPlayers = [
      ...partyPlayers,
      PartyPlayer(
        id: 'driver-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim().toUpperCase(),
        colorValue: colors[partyPlayers.length % colors.length],
      ),
    ];
    notifyListeners();
    _scheduleSave();
  }

  void removePartyPlayer(String id) {
    if (partyPlayers.length <= 2) {
      return;
    }
    partyPlayers = partyPlayers.where((player) => player.id != id).toList();
    notifyListeners();
    _scheduleSave();
  }

  void renamePartyPlayer(String id, String name) {
    partyPlayers = partyPlayers
        .map(
          (player) => player.id == id
              ? player.copyWith(name: name.trim().toUpperCase())
              : player,
        )
        .toList();
    notifyListeners();
    _scheduleSave();
  }

  void recordPartyResults(List<PartyPlayer> results) {
    final scoresById = {for (final player in results) player.id: player.score};
    partyPlayers = partyPlayers.map((player) {
      final resultScore = scoresById[player.id] ?? 0;
      return player.copyWith(
        score: resultScore > player.score ? resultScore : player.score,
        lives: 3,
      );
    }).toList();
    notifyListeners();
    _scheduleSave();
  }

  void recordCorrectInput() {
    stats = stats.copyWith(totalCorrectInputs: stats.totalCorrectInputs + 1);
    _scheduleSave();
  }

  void recordGame({
    required int round,
    required int score,
    required bool won,
    required int mistakes,
    required GameMode mode,
  }) {
    stats = stats.copyWith(
      gamesPlayed: stats.gamesPlayed + 1,
      wins: stats.wins + (won ? 1 : 0),
      bestRound: round > stats.bestRound ? round : stats.bestRound,
      bestScore: score > stats.bestScore ? score : stats.bestScore,
    );
    unlockAchievement('first_ignition');
    if (round >= 10) {
      unlockAchievement('pattern_master');
    }
    if (round >= 5 && mistakes == 0) {
      unlockAchievement('perfect_lap');
    }
    if (mode == GameMode.party) {
      unlockAchievement('party_starter');
    }
    if (difficulty == Difficulty.redline && round >= 15) {
      unlockAchievement('redline_memory');
    }
    notifyListeners();
    _scheduleSave();
  }

  void unlockAchievement(String id) {
    if (unlockedAchievementIds.add(id)) {
      notifyListeners();
      _scheduleSave();
    }
  }

  Future<void> resetStats() async {
    stats = const GameStats();
    unlockedAchievementIds.clear();
    previewedCarIds.clear();
    partyPlayers = partyPlayers
        .map((player) => player.copyWith(score: 0, lives: 3))
        .toList();
    notifyListeners();
    await _save();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), _save);
  }

  Future<void> _save() async {
    final prefs = _preferences;
    if (prefs == null) {
      return;
    }
    await Future.wait([
      prefs.setStringList(_activeCarsKey, activeCarIds),
      prefs.setDouble(_volumeKey, engineVolume),
      prefs.setBool(_hapticsKey, hapticsEnabled),
      prefs.setBool(_autoAdvanceKey, autoAdvance),
      prefs.setBool(_showNumbersKey, showSequenceNumbers),
      prefs.setString(_difficultyKey, difficulty.name),
      prefs.setStringList(
        _playersKey,
        partyPlayers.map((player) => jsonEncode(player.toJson())).toList(),
      ),
      prefs.setStringList(_unlockedKey, unlockedAchievementIds.toList()),
      prefs.setStringList(_previewedKey, previewedCarIds.toList()),
      prefs.setInt(_gamesKey, stats.gamesPlayed),
      prefs.setInt(_winsKey, stats.wins),
      prefs.setInt(_bestRoundKey, stats.bestRound),
      prefs.setInt(_bestScoreKey, stats.bestScore),
      prefs.setInt(_correctInputsKey, stats.totalCorrectInputs),
    ]);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_save());
    super.dispose();
  }
}
