import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

final class _RejectingVerifier implements AionContributionVerifier {
  @override
  Future<bool> verify({
    required String sourceId,
    required int round,
    required Uint8List signedMessage,
    required Uint8List signature,
  }) async => false;
}

void main() {
  test(
    'fuzzed federation inputs reject without hangs or unexpected errors',
    () async {
      final random = Random(0xA10F022);
      final federation = AionEntropyFederation(verifier: _RejectingVerifier());
      for (var iteration = 0; iteration < 500; iteration++) {
        final values = List.generate(random.nextInt(20), (index) {
          Uint8List bytes(int maximum) => Uint8List.fromList(
            List.generate(random.nextInt(maximum), (_) => random.nextInt(256)),
          );
          return AionContribution(
            sourceId: random.nextBool()
                ? 'source-$index'
                : String.fromCharCode(random.nextInt(128)),
            round: random.nextInt(6) - 2,
            visibility: AionContributionVisibility.values[random.nextInt(2)],
            commitment: bytes(40),
            reveal: bytes(160),
            signature: bytes(100),
          );
        });
        try {
          await federation.combine(values);
          fail('A rejecting verifier must not produce a federation mix.');
        } on MslProtocolException {
          // Expected fail-closed outcome for arbitrary attacker-controlled input.
        }
      }
    },
  );
}
