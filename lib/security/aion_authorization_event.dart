import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

final class AionAuthorizationIntent {
  AionAuthorizationIntent({
    required this.purpose,
    required Uint8List eventNonce,
    required Uint8List verifierNonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.expectedAionEpoch,
    required this.expectedMslCounter,
    required this.mslDeviceId,
    required this.mslProfileId,
    required Uint8List postQuantumContextDigest,
    required Uint8List targetDigest,
  }) : eventNonce = Uint8List.fromList(eventNonce),
       verifierNonce = Uint8List.fromList(verifierNonce),
       postQuantumContextDigest = Uint8List.fromList(
         postQuantumContextDigest,
       ),
       targetDigest = Uint8List.fromList(targetDigest) {
    final lifetime = expiresAt.toUtc().difference(issuedAt.toUtc());
    if (!_safeId(purpose) ||
        !_safeId(mslDeviceId) ||
        !_safeId(mslProfileId) ||
        eventNonce.length != 32 ||
        verifierNonce.length != 32 ||
        postQuantumContextDigest.length != 32 ||
        targetDigest.length != 32 ||
        expectedAionEpoch < 1 ||
        expectedMslCounter < 1 ||
        lifetime <= Duration.zero ||
        lifetime > const Duration(minutes: 5)) {
      throw ArgumentError('Invalid AION authorization intent.');
    }
    commitment = _hash(canonicalBytes());
  }

  final String purpose;
  final Uint8List eventNonce;
  final Uint8List verifierNonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int expectedAionEpoch;
  final int expectedMslCounter;
  final String mslDeviceId;
  final String mslProfileId;
  final Uint8List postQuantumContextDigest;
  final Uint8List targetDigest;
  late final Uint8List commitment;

  Uint8List canonicalBytes() => _join([
    utf8.encode('AION-AUTHORIZATION-INTENT/v1'),
    _field(utf8.encode(purpose)),
    _field(eventNonce),
    _field(verifierNonce),
    _i64(issuedAt.toUtc().microsecondsSinceEpoch),
    _i64(expiresAt.toUtc().microsecondsSinceEpoch),
    _u64(expectedAionEpoch),
    _u64(expectedMslCounter),
    _field(utf8.encode(mslDeviceId)),
    _field(utf8.encode(mslProfileId)),
    _field(postQuantumContextDigest),
    _field(targetDigest),
  ]);

  void validateAt(DateTime now) {
    final instant = now.toUtc();
    if (instant.isBefore(issuedAt.toUtc().subtract(const Duration(seconds: 30))) ||
        !instant.isBefore(expiresAt.toUtc())) {
      throw StateError('Authorization intent is not currently valid.');
    }
  }
}

bool _safeId(String value) =>
    RegExp(r'^[A-Za-z0-9._:/-]{1,64}$').hasMatch(value);
Uint8List _hash(List<int> value) =>
    Uint8List.fromList(crypto.sha256.convert(value).bytes);
Uint8List _field(List<int> value) => _join([
  (ByteData(4)..setUint32(0, value.length, Endian.big)).buffer.asUint8List(),
  value,
]);
Uint8List _u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.big)).buffer.asUint8List();
Uint8List _i64(int value) =>
    (ByteData(8)..setInt64(0, value, Endian.big)).buffer.asUint8List();
Uint8List _join(Iterable<List<int>> values) {
  final builder = BytesBuilder(copy: false);
  for (final value in values) {
    builder.add(value);
  }
  return builder.takeBytes();
}
