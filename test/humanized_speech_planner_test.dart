import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  const planner = HumanizedSpeechPlanner();

  test('same seed produces the same bounded performance', () {
    const settings = NazaVoiceSettings(
      backend: NazaSpeechBackend.openAi,
      paceVariation: 0.16,
      pauseVariation: 0.60,
      disfluencyRate: 0.25,
      breathRate: 0.40,
    );
    final text = List<String>.generate(
      18,
      (index) =>
          'This is natural thought number $index, with enough detail to make the cadence planner choose a useful boundary.',
    ).join(' ');

    final first = planner.plan(text: text, settings: settings, seed: 9123);
    final second = planner.plan(text: text, settings: settings, seed: 9123);

    expect(first.segmentCount, greaterThan(1));
    expect(second.segmentCount, first.segmentCount);
    for (var i = 0; i < first.segmentCount; i++) {
      final a = first.segments[i];
      final b = second.segments[i];
      expect(a.spokenText, b.spokenText);
      expect(a.speed, b.speed);
      expect(a.pauseAfter, b.pauseAfter);
      expect(a.audibleBreathAfter, b.audibleBreathAfter);
      expect(a.barkTextTemperature, b.barkTextTemperature);
      expect(a.speed, inInclusiveRange(0.84, 1.14));
      expect(
        a.pauseAfter,
        lessThanOrEqualTo(const Duration(milliseconds: 1100)),
      );
    }
    expect(
      first.segments.map((segment) => segment.speed).toSet().length,
      greaterThan(1),
    );
  });

  test('Bark plan uses short long-form chunks', () {
    const settings = NazaVoiceSettings(
      backend: NazaSpeechBackend.replicateBark,
      replicateApiToken: 'r8_test_token',
      disfluenciesEnabled: false,
      breathsEnabled: false,
    );
    final plan = planner.plan(
      text: List<String>.filled(
        12,
        'A deliberately long sentence keeps going through several clauses, while the planner finds inexpensive boundaries and preserves every spoken idea.',
      ).join(' '),
      settings: settings,
      seed: 44,
    );

    expect(plan.segmentCount, greaterThan(5));
    for (final segment in plan.segments) {
      expect(segment.sourceText.length, lessThanOrEqualTo(190));
      expect(segment.barkPrompt.length, lessThanOrEqualTo(220));
    }
  });

  test('ugh is restricted to negative emotional context', () {
    const settings = NazaVoiceSettings(
      backend: NazaSpeechBackend.replicateBark,
      replicateApiToken: 'r8_test_token',
      disfluencyRate: 0.25,
      breathsEnabled: false,
    );
    final positive = List<String>.filled(
      80,
      'This thoughtful explanation gives us another clear and useful detail.',
    ).join('\n');
    final negative = List<String>.filled(
      80,
      'This frustrating and exhausting delay is genuinely awful to handle.',
    ).join('\n');

    var negativeUsedUgh = false;
    for (var seed = 0; seed < 12; seed++) {
      final positivePlan = planner.plan(
        text: positive,
        settings: settings,
        seed: seed,
      );
      expect(
        positivePlan.segments.any(
          (segment) => segment.spokenText.startsWith('Ugh...'),
        ),
        isFalse,
      );
      final negativePlan = planner.plan(
        text: negative,
        settings: settings,
        seed: seed,
      );
      negativeUsedUgh =
          negativeUsedUgh ||
          negativePlan.segments.any(
            (segment) => segment.spokenText.startsWith('Ugh...'),
          );
    }
    expect(negativeUsedUgh, isTrue);
  });

  test('paragraph endings receive a restorative pause', () {
    const settings = NazaVoiceSettings(
      pauseScale: 1,
      pauseVariation: 0,
      disfluenciesEnabled: false,
      breathsEnabled: false,
    );
    final plan = planner.plan(
      text: 'First paragraph ends here.\n\nSecond paragraph begins here.',
      settings: settings,
      seed: 1,
    );

    expect(plan.segmentCount, 2);
    expect(
      plan.segments.first.pauseAfter,
      greaterThanOrEqualTo(const Duration(milliseconds: 500)),
    );
    expect(plan.segments.last.pauseAfter, Duration.zero);
  });

  test('invalid empty and oversized input fails before generation', () {
    expect(
      () => planner.plan(
        text: '   ',
        settings: const NazaVoiceSettings(),
        seed: 1,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => planner.plan(
        text: List<String>.filled(
          HumanizedSpeechPlanner.maxInputCharacters + 1,
          'a',
        ).join(),
        settings: const NazaVoiceSettings(),
        seed: 1,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
