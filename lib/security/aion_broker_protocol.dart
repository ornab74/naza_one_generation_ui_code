import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'metameric_surface_lattice.dart';

enum AionBrokerOperation {
  verifyContribution(1),
  deriveCapability(2),
  checkpointCommit(3);

  const AionBrokerOperation(this.code);
  final int code;
}

abstract interface class AionBrokerTransport {
  Future<Uint8List> exchange(Uint8List request);
  Future<void> close();
}

final class AionBrokerFrame {
  AionBrokerFrame({
    required this.response,
    required this.sequence,
    required this.code,
    required Uint8List payload,
  }) : payload = Uint8List.fromList(payload);

  final bool response;
  final int sequence;
  final int code;
  final Uint8List payload;
}

/// Binary framing for a separately sandboxed AION broker. Authentication is
/// independent of transport security and binds direction, sequence, operation,
/// payload length and payload. The session key must arrive through an OS-
/// protected bootstrap channel and must never be passed in command arguments.
final class AionBrokerCodec {
  AionBrokerCodec(Uint8List sessionAuthenticationKey)
    : _key = Uint8List.fromList(sessionAuthenticationKey) {
    if (_key.length != 32) {
      throw const MslProtocolException(
        'aion_broker_key_invalid',
        'The broker session authentication key must be 256 bits.',
      );
    }
  }

  static final Uint8List _magic = Uint8List.fromList([
    0x41,
    0x49,
    0x4f,
    0x4e,
    0x42,
    0x52,
    0x4b,
    0x31,
  ]); // AIONBRK1
  static const int maximumPayloadBytes = 65536;
  final Uint8List _key;
  bool _disposed = false;

  Uint8List encode({
    required bool response,
    required int sequence,
    required int code,
    required Uint8List payload,
  }) {
    if (_disposed ||
        sequence < 1 ||
        code < 0 ||
        code > 255 ||
        payload.length > maximumPayloadBytes) {
      throw const MslProtocolException(
        'aion_broker_frame_invalid',
        'The broker frame exceeds its protocol bounds.',
      );
    }
    final authenticated = Uint8List(23 + payload.length);
    authenticated.setRange(0, 8, _magic);
    ByteData.sublistView(authenticated)
      ..setUint8(8, 1)
      ..setUint8(9, response ? 1 : 0)
      ..setUint64(10, sequence, Endian.big)
      ..setUint8(18, code)
      ..setUint32(19, payload.length, Endian.big);
    authenticated.setRange(23, authenticated.length, payload);
    final mac = crypto.Hmac(crypto.sha256, _key).convert(authenticated).bytes;
    return Uint8List.fromList([...authenticated, ...mac]);
  }

  AionBrokerFrame decode(Uint8List encoded) {
    if (_disposed ||
        encoded.length < 55 ||
        encoded.length > 55 + maximumPayloadBytes ||
        !_constantTimeEqual(encoded.sublist(0, 8), _magic)) {
      throw const MslProtocolException(
        'aion_broker_frame_invalid',
        'The broker frame is malformed.',
      );
    }
    final authenticatedLength = encoded.length - 32;
    final authenticated = Uint8List.sublistView(
      encoded,
      0,
      authenticatedLength,
    );
    final suppliedMac = Uint8List.sublistView(encoded, authenticatedLength);
    final expectedMac = crypto.Hmac(
      crypto.sha256,
      _key,
    ).convert(authenticated).bytes;
    if (!_constantTimeEqual(suppliedMac, expectedMac)) {
      throw const MslProtocolException(
        'aion_broker_authentication_failed',
        'The broker frame authentication failed.',
      );
    }
    final data = ByteData.sublistView(authenticated);
    final payloadLength = data.getUint32(19, Endian.big);
    if (data.getUint8(8) != 1 ||
        data.getUint8(9) > 1 ||
        data.getUint64(10, Endian.big) < 1 ||
        payloadLength != authenticated.length - 23) {
      throw const MslProtocolException(
        'aion_broker_frame_invalid',
        'The authenticated broker frame has invalid semantics.',
      );
    }
    return AionBrokerFrame(
      response: data.getUint8(9) == 1,
      sequence: data.getUint64(10, Endian.big),
      code: data.getUint8(18),
      payload: Uint8List.sublistView(authenticated, 23),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _key.fillRange(0, _key.length, 0);
  }
}

final class AionAuthenticatedBrokerClient {
  AionAuthenticatedBrokerClient({
    required this.transport,
    required AionBrokerCodec codec,
    this.requestTimeout = const Duration(seconds: 2),
    this.maximumInvocations = 1024,
  }) : _codec = codec {
    if (requestTimeout <= Duration.zero ||
        requestTimeout > const Duration(seconds: 30) ||
        maximumInvocations < 1 ||
        maximumInvocations > 65536) {
      throw const MslProtocolException(
        'aion_broker_policy_invalid',
        'The broker session policy exceeds its bounded envelope.',
      );
    }
  }

  final AionBrokerTransport transport;
  final AionBrokerCodec _codec;
  final Duration requestTimeout;
  final int maximumInvocations;
  int _sequence = 0;
  bool _busy = false;
  bool _closed = false;

  Future<Uint8List> invoke(
    AionBrokerOperation operation,
    Uint8List payload,
  ) async {
    if (_closed ||
        _busy ||
        _sequence >= maximumInvocations ||
        payload.length > AionBrokerCodec.maximumPayloadBytes) {
      throw const MslProtocolException(
        'aion_broker_unavailable',
        'The broker is closed, busy, or the request is oversized.',
      );
    }
    _busy = true;
    final sequence = ++_sequence;
    try {
      final request = _codec.encode(
        response: false,
        sequence: sequence,
        code: operation.code,
        payload: payload,
      );
      final encodedResponse = await transport
          .exchange(request)
          .timeout(
            requestTimeout,
            onTimeout: () => throw const MslProtocolException(
              'aion_broker_timeout',
              'The isolated broker exceeded its operation deadline.',
            ),
          );
      final response = _codec.decode(encodedResponse);
      if (!response.response || response.sequence != sequence) {
        throw const MslProtocolException(
          'aion_broker_replay',
          'The broker response has an invalid direction or sequence.',
        );
      }
      if (response.code != 0) {
        throw const MslProtocolException(
          'aion_broker_rejected',
          'The isolated broker rejected the operation.',
        );
      }
      return Uint8List.fromList(response.payload);
    } catch (_) {
      await _poison();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> close() async {
    await _poison();
  }

  Future<void> _poison() async {
    if (_closed) return;
    _closed = true;
    _codec.dispose();
    try {
      await transport.close();
    } catch (_) {
      // A failed close cannot restore trust in a poisoned session.
    }
  }
}

bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = math.min(left.length, right.length);
  for (var index = 0; index < length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
