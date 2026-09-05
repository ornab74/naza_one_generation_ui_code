import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

final class _DerivationBroker implements AionBrokerTransport {
  _DerivationBroker(this.codec);
  final AionBrokerCodec codec;

  @override
  Future<Uint8List> exchange(Uint8List request) async {
    final frame = codec.decode(request);
    expect(frame.code, AionBrokerOperation.deriveCapability.code);
    final bindingOffset = frame.payload.length - 72;
    final data = ByteData.sublistView(frame.payload);
    expect(data.getUint32(bindingOffset, Endian.big), 32);
    expect(
      frame.payload.sublist(bindingOffset + 4, bindingOffset + 36),
      everyElement(7),
    );
    expect(data.getUint32(bindingOffset + 36, Endian.big), 32);
    expect(frame.payload.sublist(bindingOffset + 40), everyElement(9));
    return codec.encode(
      response: true,
      sequence: frame.sequence,
      code: 0,
      payload: Uint8List(64)..fillRange(0, 64, 19),
    );
  }

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'derives an exact active key through authenticated broker IPC',
    () async {
      final key = Uint8List(32)..fillRange(0, 32, 1);
      final serverCodec = AionBrokerCodec(key);
      final client = AionAuthenticatedBrokerClient(
        transport: _DerivationBroker(serverCodec),
        codec: AionBrokerCodec(key),
      );
      final schedule = AionBrokerKeySchedule(client);
      final active = await schedule.deriveActiveKey(
        transcriptDigest: Uint8List(32),
        priorRatchet: Uint8List(64),
        freshEntropy: Uint8List(64),
        postQuantumSecret: Uint8List(32),
        federationSecret: Uint8List(32),
        authorizationEventCommitment: Uint8List(32)..fillRange(0, 32, 7),
        physicalReceiptDigest: Uint8List(32)..fillRange(0, 32, 9),
      );
      expect(active, everyElement(19));
      await client.close();
      serverCodec.dispose();
    },
  );

  test('rejects malformed transition material before IPC', () async {
    final key = Uint8List(32);
    final serverCodec = AionBrokerCodec(key);
    final client = AionAuthenticatedBrokerClient(
      transport: _DerivationBroker(serverCodec),
      codec: AionBrokerCodec(key),
    );
    final schedule = AionBrokerKeySchedule(client);
    await expectLater(
      schedule.deriveActiveKey(
        transcriptDigest: Uint8List(31),
        priorRatchet: Uint8List(64),
        freshEntropy: Uint8List(64),
        postQuantumSecret: Uint8List(32),
        federationSecret: Uint8List(32),
        authorizationEventCommitment: Uint8List(32)..fillRange(0, 32, 7),
        physicalReceiptDigest: Uint8List(32)..fillRange(0, 32, 9),
      ),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_broker_schedule_input_invalid',
        ),
      ),
    );
    await client.close();
    serverCodec.dispose();
  });

  for (final invalidEvent in [true, false]) {
    test(
      'rejects malformed ${invalidEvent ? "event" : "receipt"} digest',
      () async {
        final key = Uint8List(32);
        final serverCodec = AionBrokerCodec(key);
        final client = AionAuthenticatedBrokerClient(
          transport: _DerivationBroker(serverCodec),
          codec: AionBrokerCodec(key),
        );
        try {
          await expectLater(
            AionBrokerKeySchedule(client).deriveActiveKey(
              transcriptDigest: Uint8List(32),
              priorRatchet: Uint8List(64),
              freshEntropy: Uint8List(64),
              postQuantumSecret: Uint8List(32),
              federationSecret: Uint8List(32),
              authorizationEventCommitment: Uint8List(invalidEvent ? 31 : 32),
              physicalReceiptDigest: Uint8List(invalidEvent ? 32 : 33),
            ),
            throwsA(
              isA<MslProtocolException>().having(
                (error) => error.code,
                'code',
                'aion_broker_schedule_input_invalid',
              ),
            ),
          );
        } finally {
          await client.close();
          serverCodec.dispose();
        }
      },
    );
  }
}
