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
}
