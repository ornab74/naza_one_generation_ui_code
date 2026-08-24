import 'package:naza_one/security/probabilistic_harm_filter.dart';

final class RecordingHarmGate implements NazaHarmGate {
  RecordingHarmGate({
    this.defaultRisk = NazaHarmRisk.low,
    this.delay = Duration.zero,
    List<NazaHarmRisk> risks = const <NazaHarmRisk>[],
  }) : _risks = List<NazaHarmRisk>.from(risks);

  final NazaHarmRisk defaultRisk;
  final Duration delay;
  final List<NazaHarmRisk> _risks;
  final List<String> commands = <String>[];

  @override
  Future<NazaHarmDecision> assessCommand(String commandName) async {
    commands.add(commandName);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final risk = _risks.isEmpty ? defaultRisk : _risks.removeAt(0);
    const telemetry = NazaSystemTelemetry(
      logicalProcessors: 8,
      processRssBytes: 128 * 1024 * 1024,
      cpuUtilization: 0.25,
      totalMemoryBytes: 16 * 1024 * 1024 * 1024,
      availableMemoryBytes: 12 * 1024 * 1024 * 1024,
    );
    return NazaHarmDecision(
      commandName: commandName,
      risk: risk,
      votes: <NazaHarmRisk>[risk],
      telemetry: telemetry,
      lState: NazaSentinelLState.derive(
        commandName: commandName,
        telemetry: telemetry,
      ),
      decidedAt: DateTime.utc(2026, 1, 1),
      reason: 'test decision',
      modelSha256: List<String>.filled(64, 'a').join(),
    );
  }

  @override
  Future<NazaHarmDecision> requireAllowed(String commandName) async {
    final decision = await assessCommand(commandName);
    if (decision.denied) throw NazaHarmDeniedException(decision);
    return decision;
  }
}
