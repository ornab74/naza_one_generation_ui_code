// Laboratory-only MSL reader records. This module deliberately does not
// implement MslSecureReader and cannot be used as authentication evidence.
import 'dart:convert';

final class MslResearchSample {
  const MslResearchSample({
    required this.sequence,
    required this.channels,
    required this.polarizationDegrees,
    required this.durationMs,
    required this.saturated,
    required this.underexposed,
    required this.temperatureC,
  });

  final int sequence;
  final List<int> channels;
  final int polarizationDegrees;
  final int durationMs;
  final bool saturated;
  final bool underexposed;
  final double? temperatureC;

  static MslResearchSample parseJsonLine(String line) {
    if (line.isEmpty || line.length > 16384) {
      throw const FormatException('MSL research record length is invalid.');
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic> || decoded['type'] != 'sample') {
      throw const FormatException('Not an MSL research sample.');
    }
    final sequence = decoded['sequence'];
    final channels = decoded['channels'];
    final polarization = decoded['polarization_deg'];
    final duration = decoded['duration_ms'];
    final saturated = decoded['saturated'];
    final underexposed = decoded['underexposed'];
    final temperature = decoded['temperature_c'];
    if (sequence is! int ||
        sequence < 0 ||
        sequence > 1000000000 ||
        channels is! List<dynamic> ||
        channels.length != 12 ||
        channels.any((value) => value is! int || value < 0 || value > 65535) ||
        polarization is! int ||
        polarization < 0 ||
        polarization > 180 ||
        duration is! int ||
        duration < 10 ||
        duration > 10000 ||
        saturated is! bool ||
        underexposed is! bool ||
        (temperature != null &&
            (temperature is! num ||
                !temperature.isFinite ||
                temperature < -40 ||
                temperature > 125))) {
      throw const FormatException('Malformed MSL research sample.');
    }
    return MslResearchSample(
      sequence: sequence,
      channels: List<int>.unmodifiable(channels.cast<int>()),
      polarizationDegrees: polarization,
      durationMs: duration,
      saturated: saturated,
      underexposed: underexposed,
      temperatureC: temperature?.toDouble(),
    );
  }

  String toCsvRow() => <Object?>[
    sequence,
    ...channels,
    polarizationDegrees,
    durationMs,
    saturated ? 1 : 0,
    underexposed ? 1 : 0,
    temperatureC ?? '',
  ].join(',');

  static const String csvHeader =
      'sequence,f1_415,f2_445,f3_480,f4_515,clear_low,nir_low,'
      'f5_555,f6_590,f7_630,f8_680,clear,nir,polarization_deg,'
      'duration_ms,saturated,underexposed,temperature_c';
}
