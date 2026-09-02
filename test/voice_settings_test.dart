import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/audio/voice_settings.dart';

void main() {
  test('voice settings round trip every advanced control', () {
    const original = NazaVoiceSettings(
      backend: NazaSpeechBackend.replicateBark,
      openAiVoice: 'cedar',
      barkVoice: 'fr_speaker_3',
      replicateApiToken: 'r8_round_trip_token',
      baseSpeed: 0.93,
      paceVariation: 0.11,
      pauseScale: 1.30,
      pauseVariation: 0.42,
      emotionStrength: 0.85,
      disfluenciesEnabled: false,
      disfluencyRate: 0.15,
      breathsEnabled: false,
      breathRate: 0.28,
      barkTextTemperature: 0.78,
      barkWaveformTemperature: 0.59,
      parallelRequests: 3,
    );

    final decoded = NazaVoiceSettings.fromJson(original.toJson());
    expect(decoded.backend, original.backend);
    expect(decoded.openAiVoice, original.openAiVoice);
    expect(decoded.barkVoice, original.barkVoice);
    expect(decoded.replicateApiToken, original.replicateApiToken);
    expect(decoded.baseSpeed, original.baseSpeed);
    expect(decoded.paceVariation, original.paceVariation);
    expect(decoded.pauseScale, original.pauseScale);
    expect(decoded.pauseVariation, original.pauseVariation);
    expect(decoded.emotionStrength, original.emotionStrength);
    expect(decoded.disfluenciesEnabled, isFalse);
    expect(decoded.disfluencyRate, original.disfluencyRate);
    expect(decoded.breathsEnabled, isFalse);
    expect(decoded.breathRate, original.breathRate);
    expect(decoded.barkTextTemperature, original.barkTextTemperature);
    expect(decoded.barkWaveformTemperature, original.barkWaveformTemperature);
    expect(decoded.parallelRequests, original.parallelRequests);
    expect(original.validate, returnsNormally);
  });

  test('untrusted persisted values fall back inside safe bounds', () {
    final settings = NazaVoiceSettings.fromJson(<String, Object?>{
      'backend': 'unknown',
      'openAiVoice': 'invented',
      'barkVoice': '../../voice',
      'replicateApiToken': 'token\nheader-injection',
      'baseSpeed': double.infinity,
      'paceVariation': 99,
      'pauseScale': -1,
      'pauseVariation': 'wide',
      'emotionStrength': 4,
      'parallelRequests': 800,
    });

    expect(settings.backend, NazaSpeechBackend.openAi);
    expect(settings.openAiVoice, 'marin');
    expect(settings.barkVoice, 'en_speaker_6');
    expect(settings.replicateApiToken, isEmpty);
    expect(settings.baseSpeed, inInclusiveRange(0.84, 1.14));
    expect(settings.paceVariation, inInclusiveRange(0, 0.16));
    expect(settings.pauseScale, inInclusiveRange(0.65, 1.65));
    expect(settings.parallelRequests, inInclusiveRange(1, 3));
  });

  test('validation rejects an unsafe token instead of silently saving it', () {
    const settings = NazaVoiceSettings(
      backend: NazaSpeechBackend.replicateBark,
      replicateApiToken: 'r8_valid\nAuthorization: injected',
    );
    expect(settings.validate, throwsA(isA<FormatException>()));
  });

  test('copyWith can explicitly clear an encrypted Replicate token', () {
    const settings = NazaVoiceSettings(
      backend: NazaSpeechBackend.replicateBark,
      replicateApiToken: 'r8_existing_token',
    );
    final cleared = settings.copyWith(
      backend: NazaSpeechBackend.openAi,
      clearReplicateApiToken: true,
    );

    expect(cleared.backend, NazaSpeechBackend.openAi);
    expect(cleared.replicateApiToken, isEmpty);
  });
}
