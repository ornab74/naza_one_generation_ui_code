import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/audio/humanized_speech_planner.dart';
import 'package:naza_one/audio/wav_composer.dart';

void main() {
  const composer = NazaWavComposer();

  test('joins PCM WAVs and inserts exact cadence silence', () {
    final first = _wav(sampleRate: 8000, frames: 100);
    final second = _wav(sampleRate: 8000, frames: 100);
    final result = composer.compose(
      wavs: <Uint8List>[first, second],
      segments: <NazaSpeechSegment>[
        _segment(pause: const Duration(milliseconds: 250)),
        _segment(),
      ],
    );

    final view = ByteData.sublistView(result);
    expect(String.fromCharCodes(result.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(result.sublist(8, 12)), 'WAVE');
    expect(view.getUint32(4, Endian.little), result.length - 8);
    // 2 * (100 mono frames * 2 bytes) + 250 ms * 8 kHz * 2 bytes.
    expect(view.getUint32(40, Endian.little), 4400);
    expect(result.length, 4444);
  });

  test('accepts a streaming data-size placeholder but rebuilds the header', () {
    final streamed = _wav(
      sampleRate: 24000,
      frames: 120,
      declaredDataLength: 0xffffffff,
    );
    final result = composer.compose(
      wavs: <Uint8List>[streamed],
      segments: <NazaSpeechSegment>[_segment()],
    );

    final view = ByteData.sublistView(result);
    expect(view.getUint32(40, Endian.little), 240);
    expect(result.length, 284);
  });

  test('converts Replicate Bark IEEE float32 WAV to canonical PCM16', () {
    final bark = _wav(sampleRate: 24000, frames: 120, audioFormat: 3);
    final result = composer.compose(
      wavs: <Uint8List>[bark],
      segments: <NazaSpeechSegment>[_segment()],
    );
    final view = ByteData.sublistView(result);

    expect(view.getUint16(20, Endian.little), 1);
    expect(view.getUint16(22, Endian.little), 1);
    expect(view.getUint32(24, Endian.little), 24000);
    expect(view.getUint16(34, Endian.little), 16);
    expect(view.getUint32(40, Endian.little), 240);
    expect(view.getInt16(44 + 100, Endian.little).abs(), greaterThan(1000));
  });

  test('subtle breath is synthesized only inside an enabled long rest', () {
    final source = _wav(sampleRate: 8000, frames: 100);
    final withBreath = composer.compose(
      wavs: <Uint8List>[source],
      segments: <NazaSpeechSegment>[
        _segment(pause: const Duration(milliseconds: 300), breath: true),
      ],
    );
    final withoutBreath = composer.compose(
      wavs: <Uint8List>[source],
      segments: <NazaSpeechSegment>[
        _segment(pause: const Duration(milliseconds: 300)),
      ],
    );
    const restStart = 44 + 200;

    expect(withBreath.sublist(restStart).any((byte) => byte != 0), isTrue);
    expect(withoutBreath.sublist(restStart).every((byte) => byte == 0), isTrue);
  });

  test('rejects incompatible or non-PCM remote WAV data', () {
    expect(
      () => composer.compose(
        wavs: <Uint8List>[
          _wav(sampleRate: 8000, frames: 100),
          _wav(sampleRate: 24000, frames: 100),
        ],
        segments: <NazaSpeechSegment>[_segment(), _segment()],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => composer.compose(
        wavs: <Uint8List>[_wav(sampleRate: 8000, frames: 100, audioFormat: 6)],
        segments: <NazaSpeechSegment>[_segment()],
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

NazaSpeechSegment _segment({
  Duration pause = Duration.zero,
  bool breath = false,
}) => NazaSpeechSegment(
  sourceText: 'Hello.',
  spokenText: 'Hello.',
  barkPrompt: 'Hello.',
  speed: 1,
  pauseAfter: pause,
  emotion: NazaSpeechEmotion.neutral,
  audibleBreathAfter: breath,
  breathSeed: 9182,
  barkTextTemperature: 0.7,
  barkWaveformTemperature: 0.7,
);

Uint8List _wav({
  required int sampleRate,
  required int frames,
  int audioFormat = 1,
  int? declaredDataLength,
}) {
  final sampleBytes = audioFormat == 3 ? 4 : 2;
  final bitsPerSample = sampleBytes * 8;
  final pcmLength = frames * sampleBytes;
  final bytes = Uint8List(44 + pcmLength);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  bytes.setRange(36, 40, 'data'.codeUnits);
  final view = ByteData.sublistView(bytes);
  view.setUint32(4, bytes.length - 8, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, audioFormat, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * sampleBytes, Endian.little);
  view.setUint16(32, sampleBytes, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  view.setUint32(40, declaredDataLength ?? pcmLength, Endian.little);
  for (var offset = 44; offset < bytes.length; offset += sampleBytes) {
    if (audioFormat == 3) {
      view.setFloat32(offset, 0.25, Endian.little);
    } else {
      view.setInt16(offset, 2200, Endian.little);
    }
  }
  return bytes;
}
