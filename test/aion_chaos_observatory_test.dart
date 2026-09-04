import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/aion_chaos_observatory.dart';

void main() {
  test('combines four bounded deterministic dynamical systems', () {
    const observatory = AionChaosObservatory();
    final first = observatory.evolve(seed: Uint8List(32)..fillRange(0, 32, 7));
    final second = observatory.evolve(seed: Uint8List(32)..fillRange(0, 32, 7));
    expect(first.frames, isNotEmpty);
    expect(
      first.frames.first.canonicalBytes(),
      second.frames.first.canonicalBytes(),
    );
    expect(first.divergenceScore, inInclusiveRange(0, 1));
    expect(first.entropyCreditBits, 0);
    expect(
      first.frames.expand((frame) => frame.coordinates),
      everyElement(inInclusiveRange(-1, 1)),
    );
  });

  test('different seeds produce different transcript projections', () {
    const observatory = AionChaosObservatory();
    final a = observatory.evolve(seed: Uint8List(32));
    final b = observatory.evolve(seed: Uint8List(32)..fillRange(0, 32, 1));
    expect(
      a.frames.first.canonicalBytes(),
      isNot(b.frames.first.canonicalBytes()),
    );
  });
}
