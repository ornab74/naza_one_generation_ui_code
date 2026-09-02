// LLM-CONTEXT:BEGIN
// FILE: lib/audio/voice_settings.dart
// ROLE: Stores the user-selected read-aloud backend and human cadence controls.
// DOMAIN: audio
// SECURITY-INVARIANT: Remote credentials are persisted only in the encrypted vault.
// CHANGE-GUARD: Keep parsing fail-closed, values bounded, and OpenAI as the local app default.
// DOCS: See /docs/llm-context-schema.md and /lib/mermaid.md.
// LLM-CONTEXT:END
import '../security/secure_database.dart';

enum NazaSpeechBackend { openAi, replicateBark }

extension NazaSpeechBackendX on NazaSpeechBackend {
  String get label => switch (this) {
    NazaSpeechBackend.openAi => 'OpenAI · fast natural voice',
    NazaSpeechBackend.replicateBark => 'Suno Bark · Replicate',
  };
}

/// Persisted controls for the read-aloud performance planner.
///
/// Values deliberately use small ranges. Large random speed or pause changes
/// sound synthetic and are more tiring than a steady voice.
final class NazaVoiceSettings {
  const NazaVoiceSettings({
    this.backend = NazaSpeechBackend.openAi,
    this.openAiVoice = 'marin',
    this.barkVoice = 'en_speaker_6',
    this.replicateApiToken = '',
    this.baseSpeed = 0.98,
    this.paceVariation = 0.065,
    this.pauseScale = 1.08,
    this.pauseVariation = 0.26,
    this.emotionStrength = 0.62,
    this.disfluenciesEnabled = true,
    this.disfluencyRate = 0.07,
    this.breathsEnabled = true,
    this.breathRate = 0.16,
    this.barkTextTemperature = 0.66,
    this.barkWaveformTemperature = 0.64,
    this.parallelRequests = 2,
  });

  static const Set<String> openAiVoices = <String>{
    'alloy',
    'ash',
    'ballad',
    'cedar',
    'coral',
    'echo',
    'fable',
    'marin',
    'nova',
    'onyx',
    'sage',
    'shimmer',
    'verse',
  };

  static const List<String> barkEnglishVoices = <String>[
    'en_speaker_0',
    'en_speaker_1',
    'en_speaker_2',
    'en_speaker_3',
    'en_speaker_4',
    'en_speaker_5',
    'en_speaker_6',
    'en_speaker_7',
    'en_speaker_8',
    'en_speaker_9',
  ];

  final NazaSpeechBackend backend;
  final String openAiVoice;
  final String barkVoice;
  final String replicateApiToken;
  final double baseSpeed;
  final double paceVariation;
  final double pauseScale;
  final double pauseVariation;
  final double emotionStrength;
  final bool disfluenciesEnabled;
  final double disfluencyRate;
  final bool breathsEnabled;
  final double breathRate;
  final double barkTextTemperature;
  final double barkWaveformTemperature;
  final int parallelRequests;

  NazaVoiceSettings copyWith({
    NazaSpeechBackend? backend,
    String? openAiVoice,
    String? barkVoice,
    String? replicateApiToken,
    bool clearReplicateApiToken = false,
    double? baseSpeed,
    double? paceVariation,
    double? pauseScale,
    double? pauseVariation,
    double? emotionStrength,
    bool? disfluenciesEnabled,
    double? disfluencyRate,
    bool? breathsEnabled,
    double? breathRate,
    double? barkTextTemperature,
    double? barkWaveformTemperature,
    int? parallelRequests,
  }) => NazaVoiceSettings(
    backend: backend ?? this.backend,
    openAiVoice: openAiVoice ?? this.openAiVoice,
    barkVoice: barkVoice ?? this.barkVoice,
    replicateApiToken: clearReplicateApiToken
        ? ''
        : replicateApiToken ?? this.replicateApiToken,
    baseSpeed: baseSpeed ?? this.baseSpeed,
    paceVariation: paceVariation ?? this.paceVariation,
    pauseScale: pauseScale ?? this.pauseScale,
    pauseVariation: pauseVariation ?? this.pauseVariation,
    emotionStrength: emotionStrength ?? this.emotionStrength,
    disfluenciesEnabled: disfluenciesEnabled ?? this.disfluenciesEnabled,
    disfluencyRate: disfluencyRate ?? this.disfluencyRate,
    breathsEnabled: breathsEnabled ?? this.breathsEnabled,
    breathRate: breathRate ?? this.breathRate,
    barkTextTemperature: barkTextTemperature ?? this.barkTextTemperature,
    barkWaveformTemperature:
        barkWaveformTemperature ?? this.barkWaveformTemperature,
    parallelRequests: parallelRequests ?? this.parallelRequests,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-voice-settings-v2',
    'backend': backend.name,
    'openAiVoice': openAiVoice,
    'barkVoice': barkVoice,
    // This object is written only through NazaSecureDatabase.
    'replicateApiToken': replicateApiToken,
    'baseSpeed': baseSpeed,
    'paceVariation': paceVariation,
    'pauseScale': pauseScale,
    'pauseVariation': pauseVariation,
    'emotionStrength': emotionStrength,
    'disfluenciesEnabled': disfluenciesEnabled,
    'disfluencyRate': disfluencyRate,
    'breathsEnabled': breathsEnabled,
    'breathRate': breathRate,
    'barkTextTemperature': barkTextTemperature,
    'barkWaveformTemperature': barkWaveformTemperature,
    'parallelRequests': parallelRequests,
  };

  factory NazaVoiceSettings.fromJson(Object? value) {
    const defaults = NazaVoiceSettings();
    if (value is! Map) return defaults;

    final backendName = value['backend']?.toString();
    final backend = NazaSpeechBackend.values.where(
      (item) => item.name == backendName,
    );
    final openAiVoice = value['openAiVoice']?.toString() ?? '';
    final barkVoice = value['barkVoice']?.toString() ?? '';
    final rawToken = value['replicateApiToken']?.toString() ?? '';

    return NazaVoiceSettings(
      backend: backend.isEmpty ? defaults.backend : backend.first,
      openAiVoice: openAiVoices.contains(openAiVoice)
          ? openAiVoice
          : defaults.openAiVoice,
      barkVoice: _validBarkVoice(barkVoice) ? barkVoice : defaults.barkVoice,
      replicateApiToken: _validToken(rawToken) ? rawToken : '',
      baseSpeed: _boundedDouble(
        value['baseSpeed'],
        defaults.baseSpeed,
        0.84,
        1.14,
      ),
      paceVariation: _boundedDouble(
        value['paceVariation'],
        defaults.paceVariation,
        0,
        0.16,
      ),
      pauseScale: _boundedDouble(
        value['pauseScale'],
        defaults.pauseScale,
        0.65,
        1.65,
      ),
      pauseVariation: _boundedDouble(
        value['pauseVariation'],
        defaults.pauseVariation,
        0,
        0.60,
      ),
      emotionStrength: _boundedDouble(
        value['emotionStrength'],
        defaults.emotionStrength,
        0,
        1,
      ),
      disfluenciesEnabled: value['disfluenciesEnabled'] is bool
          ? value['disfluenciesEnabled'] as bool
          : defaults.disfluenciesEnabled,
      disfluencyRate: _boundedDouble(
        value['disfluencyRate'],
        defaults.disfluencyRate,
        0,
        0.25,
      ),
      breathsEnabled: value['breathsEnabled'] is bool
          ? value['breathsEnabled'] as bool
          : defaults.breathsEnabled,
      breathRate: _boundedDouble(
        value['breathRate'],
        defaults.breathRate,
        0,
        0.40,
      ),
      barkTextTemperature: _boundedDouble(
        value['barkTextTemperature'],
        defaults.barkTextTemperature,
        0.35,
        1,
      ),
      barkWaveformTemperature: _boundedDouble(
        value['barkWaveformTemperature'],
        defaults.barkWaveformTemperature,
        0.35,
        1,
      ),
      parallelRequests: _boundedInt(
        value['parallelRequests'],
        defaults.parallelRequests,
        1,
        3,
      ),
    );
  }

  void validate() {
    final roundTrip = NazaVoiceSettings.fromJson(toJson());
    if (roundTrip.backend != backend ||
        roundTrip.openAiVoice != openAiVoice ||
        roundTrip.barkVoice != barkVoice ||
        roundTrip.replicateApiToken != replicateApiToken ||
        roundTrip.baseSpeed != baseSpeed ||
        roundTrip.paceVariation != paceVariation ||
        roundTrip.pauseScale != pauseScale ||
        roundTrip.pauseVariation != pauseVariation ||
        roundTrip.emotionStrength != emotionStrength ||
        roundTrip.disfluenciesEnabled != disfluenciesEnabled ||
        roundTrip.disfluencyRate != disfluencyRate ||
        roundTrip.breathsEnabled != breathsEnabled ||
        roundTrip.breathRate != breathRate ||
        roundTrip.barkTextTemperature != barkTextTemperature ||
        roundTrip.barkWaveformTemperature != barkWaveformTemperature ||
        roundTrip.parallelRequests != parallelRequests) {
      throw const FormatException('Voice settings contain an invalid value.');
    }
  }

  static bool _validBarkVoice(String value) => RegExp(
    r'^(?:v2/)?(?:en|de|es|fr|hi|it|ja|ko|pl|pt|ru|tr|zh)_speaker_[0-9]{1,2}$',
  ).hasMatch(value);

  static bool _validToken(String value) =>
      value.isEmpty ||
      (value.length >= 8 &&
          value.length <= 4096 &&
          !value.contains(RegExp(r'[\u0000-\u001f\u007f]')));

  static double _boundedDouble(
    Object? value,
    double fallback,
    double minimum,
    double maximum,
  ) {
    final parsed = value is num ? value.toDouble() : double.nan;
    return parsed.isFinite && parsed >= minimum && parsed <= maximum
        ? parsed
        : fallback;
  }

  static int _boundedInt(
    Object? value,
    int fallback,
    int minimum,
    int maximum,
  ) {
    final parsed = value is num ? value.toInt() : fallback;
    return parsed >= minimum && parsed <= maximum ? parsed : fallback;
  }
}

final class NazaVoiceSettingsStore {
  NazaVoiceSettingsStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;

  static const String _namespace = 'settings';
  static const String _key = 'voice-v2';
  final NazaSecureDatabase _database;

  Future<NazaVoiceSettings> load() async =>
      NazaVoiceSettings.fromJson(await _database.readJson(_namespace, _key));

  Future<void> save(NazaVoiceSettings settings) async {
    settings.validate();
    await _database.writeJson(_namespace, _key, settings.toJson());
  }
}
