import '../security/secure_database.dart';

/// Versioned first-run state stored inside the encrypted NAZA vault.
/// Increment [currentExperienceVersion] only when a future onboarding change is
/// important enough that existing users should see the compact guide again.
final class NazaOnboardingStateStore {
  NazaOnboardingStateStore({NazaSecureDatabase? database})
      : _database = database ?? NazaSecureDatabase.instance;

  static const String namespace = 'naza-onboarding';
  static const String key = 'experience';
  static const int currentExperienceVersion = 2;

  final NazaSecureDatabase _database;

  Future<NazaOnboardingState> read() async {
    final raw = await _database.readJson(namespace, key);
    if (raw is! Map) return const NazaOnboardingState();
    return NazaOnboardingState.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<bool> shouldShow() async {
    final state = await read();
    return !state.completed || state.experienceVersion < currentExperienceVersion;
  }

  Future<void> recordModelVerified({String? modelDigest}) async {
    final current = await read();
    await _write(current.copyWith(
      modelVerified: true,
      modelDigest: modelDigest ?? current.modelDigest,
      lastUpdatedAt: DateTime.now().toUtc(),
    ));
  }

  Future<void> complete({String? modelDigest}) async {
    final current = await read();
    await _write(current.copyWith(
      completed: true,
      helpSeen: true,
      modelVerified: true,
      modelDigest: modelDigest ?? current.modelDigest,
      experienceVersion: currentExperienceVersion,
      completedAt: DateTime.now().toUtc(),
      lastUpdatedAt: DateTime.now().toUtc(),
    ));
  }

  Future<void> reset() => _database.delete(namespace, key);

  Future<void> _write(NazaOnboardingState state) =>
      _database.writeJson(namespace, key, state.toJson());
}

final class NazaOnboardingState {
  const NazaOnboardingState({
    this.completed = false,
    this.helpSeen = false,
    this.modelVerified = false,
    this.modelDigest,
    this.experienceVersion = 0,
    this.completedAt,
    this.lastUpdatedAt,
  });

  final bool completed;
  final bool helpSeen;
  final bool modelVerified;
  final String? modelDigest;
  final int experienceVersion;
  final DateTime? completedAt;
  final DateTime? lastUpdatedAt;

  NazaOnboardingState copyWith({
    bool? completed,
    bool? helpSeen,
    bool? modelVerified,
    String? modelDigest,
    int? experienceVersion,
    DateTime? completedAt,
    DateTime? lastUpdatedAt,
  }) => NazaOnboardingState(
        completed: completed ?? this.completed,
        helpSeen: helpSeen ?? this.helpSeen,
        modelVerified: modelVerified ?? this.modelVerified,
        modelDigest: modelDigest ?? this.modelDigest,
        experienceVersion: experienceVersion ?? this.experienceVersion,
        completedAt: completedAt ?? this.completedAt,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'format': 'naza-onboarding-state-v2',
        'completed': completed,
        'helpSeen': helpSeen,
        'modelVerified': modelVerified,
        'modelDigest': modelDigest,
        'experienceVersion': experienceVersion,
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
      };

  factory NazaOnboardingState.fromJson(Map<String, dynamic> json) =>
      NazaOnboardingState(
        completed: json['completed'] == true,
        helpSeen: json['helpSeen'] == true,
        modelVerified: json['modelVerified'] == true,
        modelDigest: json['modelDigest'] as String?,
        experienceVersion: json['experienceVersion'] as int? ?? 0,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '')?.toUtc(),
        lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '')?.toUtc(),
      );
}
