import 'dart:convert';
import 'dart:typed_data';

import 'aion_broker_protocol.dart';
import 'aion_virtual_msl.dart';
import 'metameric_surface_lattice.dart';

/// External AION v2 extract/expand adapter. Device and user roots never enter
/// this object; they are provisioned directly inside the isolated broker.
final class AionBrokerKeySchedule implements AionExternalKeySchedule {
  const AionBrokerKeySchedule(this.client);
  final AionAuthenticatedBrokerClient client;

  @override
  Future<Uint8List> deriveActiveKey({
    required Uint8List transcriptDigest,
    required Uint8List priorRatchet,
    required Uint8List freshEntropy,
    required Uint8List postQuantumSecret,
    required Uint8List federationSecret,
  }) async {
    if (transcriptDigest.length != 32 ||
        priorRatchet.length != 64 ||
        freshEntropy.length != 64 ||
        postQuantumSecret.length < 32 ||
        postQuantumSecret.length > 128 ||
        federationSecret.length != 32) {
      throw const MslProtocolException(
        'aion_broker_schedule_input_invalid',
        'The broker key-schedule input is malformed.',
      );
    }
    final payload = _join([
      utf8.encode('AION-MSL/broker-derive/v2'),
      _lengthPrefixed(transcriptDigest),
      _lengthPrefixed(priorRatchet),
      _lengthPrefixed(freshEntropy),
      _lengthPrefixed(postQuantumSecret),
      _lengthPrefixed(federationSecret),
    ]);
    try {
      final result = await client.invoke(
        AionBrokerOperation.deriveCapability,
        payload,
      );
      if (result.length != 64) {
        result.fillRange(0, result.length, 0);
        throw const MslProtocolException(
          'aion_broker_schedule_output_invalid',
          'The broker returned an invalid active-key length.',
        );
      }
      return result;
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }
}

Uint8List _lengthPrefixed(List<int> value) {
  final length = ByteData(4)..setUint32(0, value.length, Endian.big);
  return _join([length.buffer.asUint8List(), value]);
}

Uint8List _join(Iterable<List<int>> values) {
  final builder = BytesBuilder(copy: false);
  for (final value in values) {
    builder.add(value);
  }
  return builder.takeBytes();
}
