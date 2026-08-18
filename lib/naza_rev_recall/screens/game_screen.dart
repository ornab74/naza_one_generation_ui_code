import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/game/game_controller.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/widgets/car_wheel.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.mode, super.key});

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final app = AppScope.of(context);
    controller = GameController(
      app: app,
      audio: AppScope.audioOf(context),
      mode: widget.mode,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.start());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    if (controller.phase != GamePhase.gameOver &&
        controller.phase != GamePhase.idle) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit this run?'),
          content: const Text(
            'Your current run will be recorded as incomplete.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('STAY'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EXIT'),
            ),
          ],
        ),
      );
      if (leave != true) {
        return false;
      }
      await controller.finish(won: false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final canPop =
        controller.phase == GamePhase.gameOver ||
        controller.phase == GamePhase.idle;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _handleBack() || !context.mounted) {
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: NeonBackground(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wheelSize = math.min(380.0, constraints.maxWidth - 34);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          children: [
                            _GameTopBar(controller: controller),
                            const SizedBox(height: 12),
                            _SequenceProgress(controller: controller),
                            const SizedBox(height: 12),
                            Text(
                              controller.statusText,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(letterSpacing: 0.8),
                            ),
                            if (controller.currentPlayer != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                '${controller.currentPlayer!.name}\'S TURN',
                                style: TextStyle(
                                  color: controller.currentPlayer!.color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            CarWheel(
                              cars: controller.activeCars,
                              centerLabel: '${controller.round}',
                              highlightedCarId: controller.highlightedCarId,
                              enabled: controller.acceptsInput,
                              onCarTap: controller.tapCar,
                              size: wheelSize,
                            ),
                            const SizedBox(height: 16),
                            _InputStrip(controller: controller),
                            if (widget.mode == GameMode.party) ...[
                              const SizedBox(height: 14),
                              _PartyStandings(controller: controller),
                            ],
                            const SizedBox(height: 14),
                            _ResultPanel(controller: controller),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GameTopBar extends StatelessWidget {
  const _GameTopBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROUND ${controller.round}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                controller.mode.label.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _MiniMetric(
          icon: Icons.favorite_rounded,
          value: '${controller.currentPlayer?.lives ?? controller.lives}',
          color: AppColors.red,
        ),
        const SizedBox(width: 8),
        _MiniMetric(
          icon: Icons.stars_rounded,
          value: '${controller.score}',
          color: AppColors.amber,
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SequenceProgress extends StatelessWidget {
  const _SequenceProgress({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 17,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: controller.sequence.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final car = controller.activeCars.firstWhere(
            (candidate) => candidate.id == controller.sequence[index],
          );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == controller.inputIndex && controller.acceptsInput
                ? 20
                : 10,
            height: 10,
            decoration: BoxDecoration(
              color: car.color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: car.color.withValues(alpha: 0.5),
                  blurRadius: 7,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InputStrip extends StatelessWidget {
  const _InputStrip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final app = controller.app;
    final visibleCount = math.min(10, controller.sequence.length);
    return Column(
      children: [
        Text(
          controller.acceptsInput ? 'YOUR INPUT' : 'ENGINE MEMORY',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(visibleCount, (index) {
              final completed = index < controller.inputIndex;
              final car = completed
                  ? controller.activeCars.firstWhere(
                      (candidate) => candidate.id == controller.sequence[index],
                    )
                  : null;
              return Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: car?.color.withValues(alpha: 0.15) ?? AppColors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: car?.color ?? AppColors.border),
                  boxShadow: car == null
                      ? const []
                      : [
                          BoxShadow(
                            color: car.color.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: Center(
                  child: completed
                      ? Icon(car!.icon, color: car.color, size: 22)
                      : app.showSequenceNumbers
                      ? Text(
                          '${index + 1}',
                          style: const TextStyle(color: AppColors.muted),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _PartyStandings extends StatelessWidget {
  const _PartyStandings({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: controller.partyPlayers.asMap().entries.map((entry) {
            final active = entry.key == controller.currentPlayerIndex;
            final player = entry.value;
            return Container(
              width: 104,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: player.color.withValues(alpha: active ? 0.16 : 0.05),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: active ? player.color : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${player.score} pts',
                    style: TextStyle(color: player.color, fontSize: 12),
                  ),
                  Text(
                    '${player.lives} lives',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == GamePhase.roundWon) {
      return NeonPanel(
        borderColor: AppColors.green,
        glowColor: AppColors.green,
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.green,
              size: 34,
            ),
            const SizedBox(height: 7),
            const Text(
              'SEQUENCE LOCKED IN',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            if (!controller.app.autoAdvance) ...[
              const SizedBox(height: 12),
              NeonButton(
                label: 'Next Round',
                color: AppColors.green,
                onPressed: controller.continueRound,
              ),
            ],
          ],
        ),
      );
    }

    if (controller.phase == GamePhase.wrong) {
      return NeonPanel(
        borderColor: AppColors.red,
        glowColor: AppColors.red,
        child: Column(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.red, size: 34),
            const SizedBox(height: 7),
            const Text(
              'WRONG ENGINE SEQUENCE',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'Mistakes: ${controller.mistakes}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!controller.app.autoAdvance) ...[
              const SizedBox(height: 12),
              NeonButton(
                label: 'Replay Sequence',
                color: AppColors.red,
                onPressed: controller.continueRound,
              ),
            ],
          ],
        ),
      );
    }

    if (controller.phase == GamePhase.gameOver) {
      return NeonPanel(
        borderColor: AppColors.purple,
        glowColor: AppColors.purple,
        child: Column(
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.purple, size: 38),
            const SizedBox(height: 8),
            Text('RUN COMPLETE', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('Round ${controller.round} • ${controller.score} points'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('EXIT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.start,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('RESTART'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
