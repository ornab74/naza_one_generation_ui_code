import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model/sentinel_model_runtime.dart';

void main() {
  test('PUNKD matches Python hazard weighting and marker shape', () {
    final weights = NazaScannerChunkd.analyze('ice ice road road road clear');
    expect(weights['ice'], greaterThan(weights['road']!));
    final patched = NazaScannerChunkd.apply(
      'prompt',
      weights,
      profile: 'balanced',
    );
    expect(patched.prompt, contains('[PUNKD_MARKERS]'));
    expect(patched.prompt, contains('<ATTN:ice:'));
    expect(patched.multiplier, inInclusiveRange(.6, 1.8));
  });

  test('CHUNKD carries continuation context and removes overlap', () async {
    final prompts = <String>[];
    final temperatures = <double>[];
    var call = 0;
    final result = await NazaScannerChunkd.generate(
      prompt: 'Classify a road with ice and debris.',
      isAbandoned: () => false,
      generator: (prompt, {required maxTokens, required temperature}) async {
        prompts.add(prompt);
        temperatures.add(temperature);
        call++;
        return call == 1
            ? 'Internal scan continues across enough words for another model chunk'
            : 'model chunkHigh';
      },
    );
    expect(prompts, hasLength(2));
    expect(prompts.first, contains('[PUNKD_MARKERS]'));
    expect(prompts.last, contains('Assistant so far:'));
    expect(result, endsWith('High'));
    expect('model chunk'.allMatches(result), hasLength(1));
    expect(temperatures.first, isNot(.18));
  });

  test('CHUNKD applies the Python short-chunk stopping rule', () async {
    var calls = 0;
    final result = await NazaScannerChunkd.generate(
      prompt: 'Classify this scene.',
      isAbandoned: () => false,
      generator: (prompt, {required maxTokens, required temperature}) async {
        calls++;
        return 'not enough words';
      },
    );
    expect(result, 'not enough words');
    expect(calls, 1);
  });
}
