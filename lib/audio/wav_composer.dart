// LLM-CONTEXT:BEGIN
// FILE: lib/audio/wav_composer.dart
// ROLE: Safely joins generated PCM WAV segments and adds low-cost cadence rests.
// DOMAIN: audio
// SECURITY-INVARIANT: Parse untrusted audio with bounded sizes and reject incompatible formats.
// CHANGE-GUARD: Keep output canonical PCM WAV and never trust remote RIFF length fields.
// DOCS: See /docs/llm-context-schema.md and /lib/mermaid.md.
// LLM-CONTEXT:END
import 'dart:math' as math;
import 'dart:typed_data';

import 'humanized_speech_planner.dart';

final class NazaWavComposer {
  const NazaWavComposer();

  static const int maxCombinedBytes = 128 * 1024 * 1024;

  Uint8List compose({
    required List<Uint8List> wavs,
    required List<NazaSpeechSegment> segments,
  }) {
    if (wavs.isEmpty || wavs.length != segments.length) {
      throw const FormatException('Speech segment audio is incomplete.');
    }
    final parsed = wavs.map(_parse).toList(growable: false);
    final format = parsed.first.format;
    for (final item in parsed.skip(1)) {
      if (item.format != format) {
        throw const FormatException(
          'Speech segments returned incompatible WAV formats.',
        );
      }
    }

    final output = BytesBuilder(copy: false);
    for (var i = 0; i < parsed.length; i++) {
      final polished = _polishPcm(parsed[i].pcm, format);
      output.add(polished);
      final pauseFrames =
          (segments[i].pauseAfter.inMicroseconds * format.sampleRate) ~/
          Duration.microsecondsPerSecond;
      if (pauseFrames > 0) {
        output.add(
          _cadenceRest(
            frames: pauseFrames,
            format: format,
            breath: segments[i].audibleBreathAfter,
            seed: segments[i].breathSeed,
          ),
        );
      }
      if (output.length + 44 > maxCombinedBytes) {
        throw const FormatException('Combined speech audio is too large.');
      }
    }

    final pcm = output.takeBytes();
    return _canonicalWav(pcm, format);
  }

  static _ParsedWav _parse(Uint8List bytes) {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 12) != 'WAVE') {
      throw const FormatException('Invalid WAV response.');
    }
    final view = ByteData.sublistView(bytes);
    _WavFormat? format;
    Uint8List? pcm;
    int? sourceAudioFormat;
    int? sourceBitsPerSample;
    int? sourceBlockAlign;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset, offset + 4);
      final declaredLength = view.getUint32(offset + 4, Endian.little);
      final dataStart = offset + 8;
      if (dataStart > bytes.length) break;
      final available = bytes.length - dataStart;
      final actualLength = math.min(declaredLength, available);
      if (id == 'fmt ') {
        if (actualLength < 16) {
          throw const FormatException('Invalid WAV format chunk.');
        }
        final audioFormat = view.getUint16(dataStart, Endian.little);
        final channels = view.getUint16(dataStart + 2, Endian.little);
        final sampleRate = view.getUint32(dataStart + 4, Endian.little);
        final byteRate = view.getUint32(dataStart + 8, Endian.little);
        final blockAlign = view.getUint16(dataStart + 12, Endian.little);
        final bitsPerSample = view.getUint16(dataStart + 14, Endian.little);
        final supportedEncoding =
            (audioFormat == 1 && bitsPerSample == 16) ||
            (audioFormat == 3 && bitsPerSample == 32);
        final expectedBlockAlign = channels * (bitsPerSample ~/ 8);
        if (!supportedEncoding ||
            (channels != 1 && channels != 2) ||
            sampleRate < 8000 ||
            sampleRate > 96000 ||
            blockAlign != expectedBlockAlign ||
            byteRate != sampleRate * blockAlign) {
          throw const FormatException(
            'Only bounded PCM16 or IEEE-float32 mono/stereo WAV is supported.',
          );
        }
        sourceAudioFormat = audioFormat;
        sourceBitsPerSample = bitsPerSample;
        sourceBlockAlign = blockAlign;
        format = _WavFormat(
          channels: channels,
          sampleRate: sampleRate,
          bitsPerSample: 16,
          blockAlign: channels * 2,
          byteRate: sampleRate * channels * 2,
        );
      } else if (id == 'data') {
        if (actualLength <= 0) {
          throw const FormatException('WAV response has no audio data.');
        }
        pcm = Uint8List.sublistView(bytes, dataStart, dataStart + actualLength);
        // A streaming WAV commonly uses 0xffffffff as the data length. The
        // completed HTTP body is authoritative, so stop after the data bytes.
        break;
      }
      final padded = actualLength + (actualLength.isOdd ? 1 : 0);
      if (padded <= 0 || dataStart + padded <= offset) break;
      offset = dataStart + padded;
    }
    if (format == null ||
        pcm == null ||
        sourceAudioFormat == null ||
        sourceBitsPerSample == null ||
        sourceBlockAlign == null ||
        pcm.length % sourceBlockAlign != 0) {
      throw const FormatException('Incomplete WAV response.');
    }
    return _ParsedWav(
      format,
      _toPcm16(
        pcm,
        audioFormat: sourceAudioFormat,
        bitsPerSample: sourceBitsPerSample,
      ),
    );
  }

  static Uint8List _toPcm16(
    Uint8List source, {
    required int audioFormat,
    required int bitsPerSample,
  }) {
    if (audioFormat == 1 && bitsPerSample == 16) {
      return Uint8List.fromList(source);
    }
    if (audioFormat != 3 || bitsPerSample != 32 || source.length % 4 != 0) {
      throw const FormatException('Unsupported WAV sample encoding.');
    }
    final input = ByteData.sublistView(source);
    final output = Uint8List(source.length ~/ 2);
    final encoded = ByteData.sublistView(output);
    for (
      var inputOffset = 0, outputOffset = 0;
      inputOffset < source.length;
      inputOffset += 4, outputOffset += 2
    ) {
      final sample = input.getFloat32(inputOffset, Endian.little);
      if (!sample.isFinite) {
        throw const FormatException('WAV contains a non-finite sample.');
      }
      final clamped = sample.clamp(-1.0, 1.0).toDouble();
      final pcm = clamped <= -1
          ? -32768
          : (clamped * 32767).round().clamp(-32768, 32767);
      encoded.setInt16(outputOffset, pcm, Endian.little);
    }
    return output;
  }

  static Uint8List _polishPcm(Uint8List source, _WavFormat format) {
    final bytes = Uint8List.fromList(source);
    final view = ByteData.sublistView(bytes);
    var sumSquares = 0.0;
    var activeSamples = 0;
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      final sample = view.getInt16(offset, Endian.little);
      if (sample.abs() < 96) continue;
      sumSquares += sample * sample;
      activeSamples++;
    }
    final rms = activeSamples == 0 ? 0 : math.sqrt(sumSquares / activeSamples);
    // A small gain window evens out independent generations without pumping
    // room noise or flattening the natural dynamics of a sentence.
    final gain = rms <= 0 ? 1.0 : (3100 / rms).clamp(0.86, 1.12).toDouble();
    final fadeFrames = math.min(
      bytes.length ~/ format.blockAlign ~/ 2,
      (format.sampleRate * 0.004).round(),
    );
    final totalFrames = bytes.length ~/ format.blockAlign;
    for (var frame = 0; frame < totalFrames; frame++) {
      var envelope = 1.0;
      if (fadeFrames > 0 && frame < fadeFrames) {
        envelope = frame / fadeFrames;
      } else if (fadeFrames > 0 && frame >= totalFrames - fadeFrames) {
        envelope = (totalFrames - frame - 1) / fadeFrames;
      }
      for (var channel = 0; channel < format.channels; channel++) {
        final offset = frame * format.blockAlign + channel * 2;
        final original = view.getInt16(offset, Endian.little);
        final adjusted = (original * gain * envelope).round().clamp(
          -32768,
          32767,
        );
        view.setInt16(offset, adjusted, Endian.little);
      }
    }
    return bytes;
  }

  static Uint8List _cadenceRest({
    required int frames,
    required _WavFormat format,
    required bool breath,
    required int seed,
  }) {
    final bytes = Uint8List(frames * format.blockAlign);
    if (!breath || frames < (format.sampleRate * 0.18).round()) return bytes;

    final view = ByteData.sublistView(bytes);
    final breathFrames = math.min(
      (format.sampleRate * 0.24).round(),
      (frames * 0.52).round(),
    );
    final leadFrames = math.max(1, ((frames - breathFrames) * 0.34).round());
    var state = seed == 0 ? 0x6d2b79f5 : seed;
    var smoothed = 0.0;
    for (var i = 0; i < breathFrames && leadFrames + i < frames; i++) {
      state ^= (state << 13) & 0x7fffffff;
      state ^= state >> 17;
      state ^= (state << 5) & 0x7fffffff;
      final white = ((state & 0xffff) / 32767.5) - 1.0;
      smoothed = smoothed * 0.72 + white * 0.28;
      final phase = i / math.max(1, breathFrames - 1);
      final envelope = math.sin(math.pi * phase);
      final shaped = envelope * envelope * smoothed;
      // Approximately -40 dBFS: present on headphones, unobtrusive on
      // speakers, and never loud enough to become a repeated hiss.
      final sample = (shaped * 330).round().clamp(-420, 420);
      final frame = leadFrames + i;
      for (var channel = 0; channel < format.channels; channel++) {
        view.setInt16(
          frame * format.blockAlign + channel * 2,
          sample,
          Endian.little,
        );
      }
    }
    return bytes;
  }

  static Uint8List _canonicalWav(Uint8List pcm, _WavFormat format) {
    final bytes = Uint8List(44 + pcm.length);
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    bytes.setRange(8, 12, 'WAVE'.codeUnits);
    bytes.setRange(12, 16, 'fmt '.codeUnits);
    bytes.setRange(36, 40, 'data'.codeUnits);
    final view = ByteData.sublistView(bytes);
    view.setUint32(4, bytes.length - 8, Endian.little);
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, format.channels, Endian.little);
    view.setUint32(24, format.sampleRate, Endian.little);
    view.setUint32(28, format.byteRate, Endian.little);
    view.setUint16(32, format.blockAlign, Endian.little);
    view.setUint16(34, format.bitsPerSample, Endian.little);
    view.setUint32(40, pcm.length, Endian.little);
    bytes.setRange(44, bytes.length, pcm);
    return bytes;
  }

  static String _ascii(Uint8List bytes, int start, int end) =>
      String.fromCharCodes(bytes.sublist(start, end));
}

final class _ParsedWav {
  const _ParsedWav(this.format, this.pcm);

  final _WavFormat format;
  final Uint8List pcm;
}

final class _WavFormat {
  const _WavFormat({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.byteRate,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int blockAlign;
  final int byteRate;

  @override
  bool operator ==(Object other) =>
      other is _WavFormat &&
      channels == other.channels &&
      sampleRate == other.sampleRate &&
      bitsPerSample == other.bitsPerSample &&
      blockAlign == other.blockAlign &&
      byteRate == other.byteRate;

  @override
  int get hashCode =>
      Object.hash(channels, sampleRate, bitsPerSample, blockAlign, byteRate);
}
