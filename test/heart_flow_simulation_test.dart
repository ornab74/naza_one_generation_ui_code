// LLM-CONTEXT:BEGIN
// FILE: test/heart_flow_simulation_test.dart
// ROLE: Verifies HeartFlow's bounded local simulation contract.
// SECURITY-INVARIANT: The simulation is deterministic, bounded, non-clinical,
// and must not require raw identity values to calculate a result.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/naza_exploration_hub.dart';

void main() {
  test('HeartFlow simulation stays bounded and exposes all six dimensions', () {
    final simulation = NazaHeartFlowSimulation.run(
      reflection:
          'I want to help my community, learn, rest, repair nature, and speak truth.',
      ageOrRange: '30–39',
      restingBaseline: '62 bpm',
    );

    final values = [
      simulation.stewardship,
      simulation.compassion,
      simulation.creativity,
      simulation.greedDissipation,
      simulation.courage,
      simulation.harmony,
      simulation.coherence,
      simulation.score,
    ];
    expect(values, everyElement(inInclusiveRange(0.0, 1.0)));
    expect(simulation.toPromptBlock(), contains('classical approximation'));
    expect(simulation.toPromptBlock(), contains('Stewardship Resonance'));
    expect(simulation.toPromptBlock(), contains('Harmony Coherence'));
  });

  test('empty reflection uses a safe regenerative baseline', () {
    final simulation = NazaHeartFlowSimulation.run(reflection: '');
    expect(simulation.score, greaterThan(0.0));
    expect(simulation.score, lessThanOrEqualTo(1.0));
  });
}
