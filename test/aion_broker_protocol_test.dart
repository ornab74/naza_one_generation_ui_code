import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/aion_broker_protocol.dart';
import 'package:naza_one/security/metameric_surface_lattice.dart';

final class _LoopbackBroker implements AionBrokerTransport {
  _LoopbackBroker(this.codec);
  final AionBrokerCodec codec;
  bool replay = false;

  @override
  Future<Uint8List> exchange(Uint8List request) async {
    final decoded = codec.decode(request);
    return codec.encode(
      response: true,
      sequence: replay ? decoded.sequence + 1 : decoded.sequence,
      code: 0,
      payload: decoded.payload,
    );
  }

  @override
  Future<void> close() async {}
}

final class _HangingBroker implements AionBrokerTransport {
  @override
  Future<Uint8List> exchange(Uint8List request) =>
      Completer<Uint8List>().future;

  @override
  Future<void> close() async {}
}

void main() {
  test('authenticates bounded broker requests and responses', () async {
    final key = Uint8List(32)..fillRange(0, 32, 7);
    final serverCodec = AionBrokerCodec(key);
    final client = AionAuthenticatedBrokerClient(
      transport: _LoopbackBroker(serverCodec),
      codec: AionBrokerCodec(key),
    );
    expect(
      await client.invoke(
        AionBrokerOperation.verifyContribution,
        Uint8List.fromList([1, 2, 3]),
      ),
      [1, 2, 3],
    );
    await client.close();
    serverCodec.dispose();
  });

  test('rejects tampering and response replay', () async {
    final key = Uint8List(32)..fillRange(0, 32, 9);
    final codec = AionBrokerCodec(key);
    final frame = codec.encode(
      response: false,
      sequence: 1,
      code: AionBrokerOperation.deriveCapability.code,
      payload: Uint8List.fromList([4]),
    );
    frame[23] ^= 0xff;
    expect(
      () => codec.decode(frame),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_broker_authentication_failed',
        ),
      ),
    );

    final serverCodec = AionBrokerCodec(key);
    final transport = _LoopbackBroker(serverCodec)..replay = true;
    final client = AionAuthenticatedBrokerClient(
      transport: transport,
      codec: AionBrokerCodec(key),
    );
    await expectLater(
      client.invoke(AionBrokerOperation.deriveCapability, Uint8List(0)),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_broker_replay',
        ),
      ),
    );
    await expectLater(
      client.invoke(AionBrokerOperation.deriveCapability, Uint8List(0)),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_broker_unavailable',
        ),
      ),
    );
    await client.close();
    codec.dispose();
    serverCodec.dispose();
  });

  test('timeouts poison the broker session', () async {
    final client = AionAuthenticatedBrokerClient(
      transport: _HangingBroker(),
      codec: AionBrokerCodec(Uint8List(32)),
      requestTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      client.invoke(AionBrokerOperation.checkpointCommit, Uint8List(0)),
      throwsA(
        isA<MslProtocolException>().having(
          (error) => error.code,
          'code',
          'aion_broker_timeout',
        ),
      ),
    );
    await expectLater(
      client.invoke(AionBrokerOperation.checkpointCommit, Uint8List(0)),
      throwsA(isA<MslProtocolException>()),
    );
  });
}
