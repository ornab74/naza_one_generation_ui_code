import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:naza_one/naza_rev_recall/app/app_controller.dart';
import 'package:naza_one/naza_rev_recall/audio/audio_service.dart';
import 'package:naza_one/naza_rev_recall/data/car_catalog.dart';
import 'package:naza_one/naza_rev_recall/models/car_profile.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';

class GameController extends ChangeNotifier {
  GameController({required this.app, required this.audio, required this.mode})
    : _random = Random();

  final AppController app;
  final EngineAudioService audio;
  final GameMode mode;
  final Random _random;

  final List<String> sequence = <String>[];
  List<PartyPlayer> partyPlayers = <PartyPlayer>[];

  GamePhase phase = GamePhase.idle;
  String? highlightedCarId;
  int inputIndex = 0;
  int round = 1;
  int score = 0;
  int lives = 3;
  int mistakes = 0;
  int currentPlayerIndex = 0;
  int _playbackToken = 0;
  bool _recorded = false;
  bool _processingInput = false;
  bool _disposed = false;

  List<CarProfile> get activeCars => app.activeCars;

  PartyPlayer? get currentPlayer {
    if (mode != GameMode.party || partyPlayers.isEmpty) {
      return null;
    }
    return partyPlayers[currentPlayerIndex];
  }

  bool get acceptsInput => phase == GamePhase.input;

  String get statusText => switch (phase) {
    GamePhase.idle => 'READY TO START',
    GamePhase.countdown => 'GET READY',
    GamePhase.watching => 'WATCH THE SEQUENCE',
    GamePhase.input => 'REPEAT THE ENGINE SEQUENCE',
    GamePhase.roundWon => 'ROUND CLEARED',
    GamePhase.wrong => 'WRONG ENGINE',
    GamePhase.gameOver => 'RUN COMPLETE',
  };

  Future<void> start() async {
    _playbackToken++;
    sequence.clear();
    round = 1;
    score = 0;
    mistakes = 0;
    inputIndex = 0;
    lives = mode == GameMode.classic ? 1 : 3;
    _recorded = false;

    if (mode == GameMode.party) {
      partyPlayers = app.partyPlayers
          .map((player) => player.copyWith(score: 0, lives: 3))
          .toList();
      currentPlayerIndex = 0;
      app.unlockAchievement('party_starter');
    }

    for (var index = 0; index < app.difficulty.startingLength; index++) {
      _appendRandomCar();
    }
    notifyListeners();
    await _playSequence();
  }

  Future<void> _playSequence() async {
    final token = ++_playbackToken;
    phase = GamePhase.countdown;
    highlightedCarId = null;
    inputIndex = 0;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!_isCurrent(token)) {
      return;
    }

    phase = GamePhase.watching;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 220));

    for (final carId in sequence) {
      if (!_isCurrent(token)) {
        return;
      }
      final car = carById(carId);
      highlightedCarId = carId;
      notifyListeners();
      await audio.play(car, volume: app.engineVolume);
      if (app.hapticsEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
      await Future<void>.delayed(app.difficulty.flashDuration);
      highlightedCarId = null;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    if (!_isCurrent(token)) {
      return;
    }
    phase = GamePhase.input;
    notifyListeners();
  }

  Future<void> tapCar(String carId) async {
    if (!acceptsInput || _processingInput) {
      return;
    }
    _processingInput = true;
    try {
      final car = carById(carId);
      highlightedCarId = carId;
      notifyListeners();
      await audio.play(car, volume: app.engineVolume);

      if (app.hapticsEnabled) {
        unawaited(HapticFeedback.lightImpact());
      }

      final expected = sequence[inputIndex];
      if (carId != expected) {
        await _handleWrongInput();
        return;
      }

      app.recordCorrectInput();
      inputIndex += 1;
      score += (10 * round * app.difficulty.scoreMultiplier).round();
      notifyListeners();

      await Future<void>.delayed(const Duration(milliseconds: 130));
      highlightedCarId = null;
      notifyListeners();

      if (inputIndex == sequence.length) {
        await _handleRoundCleared();
      }
    } finally {
      _processingInput = false;
    }
  }

  Future<void> _handleRoundCleared() async {
    phase = GamePhase.roundWon;
    highlightedCarId = null;

    if (mode == GameMode.party && partyPlayers.isNotEmpty) {
      final player = partyPlayers[currentPlayerIndex];
      partyPlayers[currentPlayerIndex] = player.copyWith(
        score:
            player.score +
            (round * 100 * app.difficulty.scoreMultiplier).round(),
      );
    }

    notifyListeners();

    if (round >= 20) {
      await finish(won: true);
      return;
    }

    if (app.autoAdvance) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      await continueRound();
    }
  }

  Future<void> continueRound() async {
    if (phase != GamePhase.roundWon && phase != GamePhase.wrong) {
      return;
    }

    if (phase == GamePhase.roundWon) {
      round += 1;
      _appendRandomCar();
      if (mode == GameMode.party) {
        _advancePartyPlayer();
      }
    }
    await _playSequence();
  }

  Future<void> _handleWrongInput() async {
    mistakes += 1;
    phase = GamePhase.wrong;
    highlightedCarId = null;

    if (app.hapticsEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }

    if (mode == GameMode.classic) {
      lives = 0;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await finish(won: false);
      return;
    }

    if (mode == GameMode.elimination) {
      lives -= 1;
      notifyListeners();
      if (lives <= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await finish(won: false);
        return;
      }
    }

    if (mode == GameMode.party && partyPlayers.isNotEmpty) {
      final player = partyPlayers[currentPlayerIndex];
      partyPlayers[currentPlayerIndex] = player.copyWith(
        lives: max(0, player.lives - 1),
      );
      notifyListeners();
      if (partyPlayers.every((candidate) => candidate.lives <= 0)) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await finish(won: false);
        return;
      }
      _advancePartyPlayer();
    }

    if (app.autoAdvance) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await continueRound();
    }
  }

  void _advancePartyPlayer() {
    if (partyPlayers.isEmpty) {
      return;
    }
    for (var attempts = 0; attempts < partyPlayers.length; attempts++) {
      currentPlayerIndex = (currentPlayerIndex + 1) % partyPlayers.length;
      if (partyPlayers[currentPlayerIndex].lives > 0) {
        break;
      }
    }
    notifyListeners();
  }

  Future<void> replaySequence() async {
    if (phase == GamePhase.input ||
        phase == GamePhase.watching ||
        phase == GamePhase.countdown) {
      return;
    }
    await _playSequence();
  }

  Future<void> finish({required bool won}) async {
    _playbackToken++;
    await audio.stopAll();
    phase = GamePhase.gameOver;
    highlightedCarId = null;
    notifyListeners();

    if (!_recorded) {
      _recorded = true;
      if (mode == GameMode.party) {
        app.recordPartyResults(partyPlayers);
      }
      app.recordGame(
        round: round,
        score: score,
        won: won,
        mistakes: mistakes,
        mode: mode,
      );
    }
  }

  void _appendRandomCar() {
    final cars = activeCars;
    sequence.add(cars[_random.nextInt(cars.length)].id);
  }

  bool _isCurrent(int token) => !_disposed && token == _playbackToken;

  @override
  void dispose() {
    _disposed = true;
    _playbackToken++;
    unawaited(audio.stopAll());
    super.dispose();
  }
}
