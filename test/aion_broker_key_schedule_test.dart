import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/aion_broker_key_schedule.dart';
import 'package:naza_one/security/aion_broker_protocol.dart';
import 'package:naza_one/security/metameric_surface_lattice.dart';

final class _DerivationBroker implements AionBrokerTransport {
  _DerivationBroker(this.codec);
  final AionBrokerCodec codec;

  @override
  Future<Uint8List> exchange(Uint8List request) async {
    final frame = codec.decode(request);
    expect(frame.code, AionBrokerOperation.deriveCapability.code);
    expect(frame.payload.length, greaterThan(200));
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
}
