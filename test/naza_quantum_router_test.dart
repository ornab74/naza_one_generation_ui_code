import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  group('NazaQuantumRouter', () {
    test('returns the empty route for whitespace', () {
      final route = NazaQuantumRouter.route('   ');

      expect(route.label, 'empty');
      expect(route.score, 0);
    });

    test('is deterministic and always returns a normalized score', () {
      const prompt = 'Design a small local-first Flutter architecture.';

      final first = NazaQuantumRouter.route(prompt);
      final second = NazaQuantumRouter.route(prompt);

      expect(second.score, first.score);
      expect(second.label, first.label);
      expect(first.score, inInclusiveRange(0.0, 1.0));
      expect(first.label, isNotEmpty);
    });

    test('handles unicode input', () {
      final route = NazaQuantumRouter.route('Hello 🌿 — 你好 — مرحبا');

      expect(route.score, inInclusiveRange(0.0, 1.0));
      expect(route.label, isNot('empty'));
    });
  });

  group('release scanner and BarkPack config', () {
    test('pins the current BarkPack release-index JSON hash', () {
      expect(
        NazaAppConfig.barkPackIndexSha256,
        'e30d638dc477ec017aacd0ceaf21d97d94f6a83ac35f9037313e3f66f5640eaf',
      );
    });

    test('does not use the Actions artifact ZIP hash as the index pin', () {
      const artifactZipSha256 =
          '5e89db33478d430111bde5d1b430313a6c031a982acb41e254ae6417c1bbff6b';

      expect(NazaAppConfig.barkPackIndexSha256, isNot(artifactZipSha256));
    });

    test(
      'builds a single-pass scanner prompt with risk and safety outputs',
      () {
        final data = {
          'location': 'Main St bridge',
          'road_surface': 'wet with debris',
          'nearby_hazards': 'stalled car near shoulder',
        };
        final trace = NazaScannerPrompts.roadTrace(data);
        final prompt = NazaScannerPrompts.buildSinglePassScanner(
          kind: 'Road',
          visibleSummary: NazaScannerPrompts.roadSummary(data),
          primaryPrompt: NazaScannerPrompts.buildRoad(data, trace: trace),
          safetyPrompt: NazaScannerPrompts.buildRoadSafety(data, trace: trace),
        );

        expect(prompt, contains('Risk: Low | Medium | High'));
        expect(prompt, contains('Safety Score: 0-100'));
        expect(prompt, contains('[primary scanner instructions]'));
        expect(prompt, contains('[safety scoring instructions]'));
        expect(prompt, contains('Keep the full response under 450 words.'));
      },
    );

    test('bounds oversized scanner field values before prompt assembly', () {
      final longObservation = List.filled(900, 'x').join();
      final prompt = NazaScannerPrompts.buildFoodWater({
        'location': 'test kitchen',
        'food_water_type': 'bottled water',
        'sensor_notes': longObservation,
      });
      final boundedObservation =
          '${List.filled(NazaScannerPrompts.maxFieldChars, 'x').join()}...';

      expect(prompt, isNot(contains(longObservation)));
      expect(prompt, contains(boundedObservation));
    });

    test('keeps the app prompt conversational for live voice mode', () {
      final prompt = NazaAppConfig.systemInstruction.toLowerCase();

      expect(prompt, contains('conversational partner'));
      expect(prompt, isNot(contains("can't")));
      expect(prompt, isNot(contains('cannot')));
      expect(
        NazaAppConfig.liveVoiceOutputTokens,
        lessThan(NazaAppConfig.outputTokens),
      );
    });
  });
}
