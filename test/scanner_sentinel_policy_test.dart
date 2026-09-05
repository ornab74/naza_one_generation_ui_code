import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('High sentinel vote overrides optimistic explanatory output', () {
    final decision = NazaScannerSentinelDecision(
      risk: NazaHarmRisk.high,
      votes: const <NazaHarmRisk>[
        NazaHarmRisk.high,
        NazaHarmRisk.high,
        NazaHarmRisk.high,
      ],
      modelSha256: List<String>.filled(64, 'a').join(),
    );

    final calibrated = NazaScannerSentinelPolicy.calibrateStructuredText(
      '''Risk: Low
Confidence: Low
Safety Score: 99
Safety Band: High
Recommendations:
- Continue carefully.''',
      decision,
    );

    expect(calibrated, contains('Risk: High'));
    expect(calibrated, contains('Confidence: High'));
    expect(calibrated, contains('Safety Score: 44'));
    expect(calibrated, contains('Safety Band: Low'));
    expect(calibrated, isNot(contains('Risk: Low')));
  });

  test('risk tiers enforce non-overlapping safety-score bands', () {
    String apply(NazaHarmRisk risk, String score) =>
        NazaScannerSentinelPolicy.calibrateStructuredText(
          'Safety Score: $score',
          NazaScannerSentinelDecision(
            risk: risk,
            votes: <NazaHarmRisk>[risk],
            modelSha256: List<String>.filled(64, 'b').join(),
          ),
        );

    expect(apply(NazaHarmRisk.high, '100'), contains('Safety Score: 44'));
    expect(apply(NazaHarmRisk.medium, '0'), contains('Safety Score: 45'));
    expect(apply(NazaHarmRisk.low, '0'), contains('Safety Score: 74'));
  });

  test('indeterminate scanner decision cannot be calibrated', () {
    expect(
      () => NazaScannerSentinelPolicy.calibrateStructuredText(
        'Risk: Low\nSafety Score: 100',
        NazaScannerSentinelDecision(
          risk: NazaHarmRisk.indeterminate,
          votes: const <NazaHarmRisk>[NazaHarmRisk.indeterminate],
          modelSha256: List<String>.filled(64, 'c').join(),
        ),
      ),
      throwsStateError,
    );
  });
}
