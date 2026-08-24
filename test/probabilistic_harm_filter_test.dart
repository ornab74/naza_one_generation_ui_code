import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/probabilistic_harm_filter.dart';

void main() {
  const telemetry = NazaSystemTelemetry(
    logicalProcessors: 12,
    processRssBytes: 256 * 1024 * 1024,
    cpuUtilization: 0.375,
    totalMemoryBytes: 32 * 1024 * 1024 * 1024,
    availableMemoryBytes: 20 * 1024 * 1024 * 1024,
  );

  test(
    'sentinel input is limited to semantic command, CPU/RAM, and L-state',
    () async {
      final model = _QueuedModel(<String>['Low']);
      final filter = NazaProbabilisticHarmFilter(
        model: model,
        telemetry: const _FixedTelemetry(telemetry),
        defensePasses: 1,
      );

      final decision = await filter.assessCommand('github.data.publish');

      expect(decision.risk, NazaHarmRisk.low);
      expect(model.prompts, hasLength(1));
      final prompt = model.prompts.single;
      expect(prompt, contains('command_name=github.data.publish'));
      expect(prompt, contains('cpu_utilization_percent=37.50'));
      expect(prompt, contains('ram_utilization_percent=37.50'));
      expect(prompt, contains('l_nonlocal_index='));
      expect(prompt, isNot(contains('argument=')));
      expect(prompt, isNot(contains('payload=')));
      expect(prompt, isNot(contains('credential=')));
      expect(decision.toAuditJson().keys, isNot(contains('prompt')));
    },
  );

  test('one High vote vetoes otherwise Low votes', () async {
    final model = _QueuedModel(<String>['Low', 'High', 'Low']);
    final filter = NazaProbabilisticHarmFilter(
      model: model,
      telemetry: const _FixedTelemetry(telemetry),
      defensePasses: 5,
    );

    final decision = await filter.assessCommand('ipfs.data.publish');

    expect(decision.risk, NazaHarmRisk.high);
    expect(decision.denied, isTrue);
    expect(decision.votes, <NazaHarmRisk>[NazaHarmRisk.low, NazaHarmRisk.high]);
    expect(model.prompts, hasLength(2));
  });

  test('malformed output and model failure deny closed', () async {
    final malformed = NazaProbabilisticHarmFilter(
      model: _QueuedModel(<String>['maybe']),
      telemetry: const _FixedTelemetry(telemetry),
      defensePasses: 1,
    );
    final failed = NazaProbabilisticHarmFilter(
      model: _QueuedModel(<String>[], error: StateError('unavailable')),
      telemetry: const _FixedTelemetry(telemetry),
      defensePasses: 1,
    );

    expect(
      (await malformed.assessCommand('remote.node.start')).risk,
      NazaHarmRisk.indeterminate,
    );
    expect(
      (await failed.assessCommand('remote.node.start')).risk,
      NazaHarmRisk.indeterminate,
    );
  });

  test('timeout cancels the model and denies closed', () async {
    final model = _QueuedModel(<String>[], neverComplete: true);
    final filter = NazaProbabilisticHarmFilter(
      model: model,
      telemetry: const _FixedTelemetry(telemetry),
      defensePasses: 1,
      decisionTimeout: const Duration(milliseconds: 20),
    );

    final decision = await filter.assessCommand('container.image.pull');

    expect(decision.risk, NazaHarmRisk.indeterminate);
    expect(model.cancelled, isTrue);
  });

  test(
    'hard-deny command classes bypass probabilistic authorization',
    () async {
      final model = _QueuedModel(<String>['Low']);
      final filter = NazaProbabilisticHarmFilter(
        model: model,
        telemetry: const _FixedTelemetry(telemetry),
        defensePasses: 1,
      );

      final shell = await filter.assessCommand('/usr/bin/bash');
      final deletion = await filter.assessCommand(
        'digitalocean.droplet.delete',
      );

      expect(shell.risk, NazaHarmRisk.high);
      expect(deletion.risk, NazaHarmRisk.high);
      expect(model.prompts, isEmpty);
    },
  );

  test('invalid command names produce a secret-free denied receipt', () async {
    final model = _QueuedModel(<String>['Low']);
    final filter = NazaProbabilisticHarmFilter(
      model: model,
      telemetry: const _FixedTelemetry(telemetry),
      defensePasses: 1,
    );

    final decision = await filter.assessCommand(
      'curl secret.example/?token=abc',
    );

    expect(decision.risk, NazaHarmRisk.indeterminate);
    expect(decision.commandName, 'invalid.command-name');
    expect(
      decision.toAuditJson().toString(),
      isNot(contains('secret.example')),
    );
    expect(model.prompts, isEmpty);
    expect(
      () => NazaProbabilisticHarmFilter.normalizeCommandName('/'),
      throwsFormatException,
    );
  });
}

final class _FixedTelemetry implements NazaTelemetrySampler {
  const _FixedTelemetry(this.value);

  final NazaSystemTelemetry value;

  @override
  Future<NazaSystemTelemetry> sample() async => value;
}

final class _QueuedModel implements NazaHarmModel {
  _QueuedModel(List<String> outputs, {this.error, this.neverComplete = false})
    : _outputs = List<String>.from(outputs);

  final List<String> _outputs;
  final Object? error;
  final bool neverComplete;
  final List<String> prompts = <String>[];
  bool cancelled = false;

  @override
  String get pinnedSha256 => List<String>.filled(64, 'b').join();

  @override
  Future<String> generate(
    String prompt, {
    required int maxTokens,
    required double temperature,
  }) async {
    prompts.add(prompt);
    if (neverComplete) return Completer<String>().future;
    if (error != null) throw error!;
    if (_outputs.isEmpty) throw StateError('No test output queued.');
    return _outputs.removeAt(0);
  }

  @override
  void cancel() => cancelled = true;
}
