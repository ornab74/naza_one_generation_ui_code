// LLM-CONTEXT:BEGIN
// FILE: lib/audio/humanized_speech_planner.dart
// ROLE: Builds a bounded, clause-aware performance plan for remote speech engines.
// DOMAIN: audio
// SECURITY-INVARIANT: Planning is local, deterministic when seeded, and never expands input without a strict bound.
// CHANGE-GUARD: Preserve semantic text, rare opt-in disfluencies, and conservative prosody ranges.
// DOCS: See /docs/llm-context-schema.md and /lib/mermaid.md.
// LLM-CONTEXT:END
import 'dart:math' as math;

import 'voice_settings.dart';

enum NazaSpeechEmotion {
  neutral,
  warm,
  curious,
  bright,
  reassuring,
  solemn,
  weary,
}

extension NazaSpeechEmotionX on NazaSpeechEmotion {
  String get delivery => switch (this) {
    NazaSpeechEmotion.neutral =>
      'grounded, unforced, conversational neutrality',
    NazaSpeechEmotion.warm => 'gentle warmth and relaxed confidence',
    NazaSpeechEmotion.curious =>
      'light curiosity with a natural upward question contour',
    NazaSpeechEmotion.bright =>
      'quiet enthusiasm without becoming loud or sing-song',
    NazaSpeechEmotion.reassuring => 'calm reassurance with softened consonants',
    NazaSpeechEmotion.solemn =>
      'measured, compassionate restraint with a lower-energy cadence',
    NazaSpeechEmotion.weary =>
      'subtle frustration or weariness without melodrama',
  };
}

final class NazaSpeechSegment {
  const NazaSpeechSegment({
    required this.sourceText,
    required this.spokenText,
    required this.barkPrompt,
    required this.speed,
    required this.pauseAfter,
    required this.emotion,
    required this.audibleBreathAfter,
    required this.breathSeed,
    required this.barkTextTemperature,
    required this.barkWaveformTemperature,
  });

  /// Original text represented by this segment, before an optional filler.
  final String sourceText;

  /// Text sent to conventional TTS. This can contain a rare enabled filler.
  final String spokenText;

  /// Bark prompt with only Bark-supported non-verbal markers.
  final String barkPrompt;
  final double speed;
  final Duration pauseAfter;
  final NazaSpeechEmotion emotion;
  final bool audibleBreathAfter;
  final int breathSeed;
  final double barkTextTemperature;
  final double barkWaveformTemperature;

  String openAiInstructions(String baseInstructions) {
    final breathDirection = audibleBreathAfter
        ? 'Let the thought resolve with a very soft, natural breath.'
        : 'Do not force a breath or dramatic pause.';
    return '$baseInstructions '
        'For this short take use ${emotion.delivery}. '
        'Vary micro-pauses and stress within the sentence, keep loudness even, '
        'avoid announcer cadence, and do not sound sing-song. $breathDirection '
        'Speak only the supplied words; never announce these directions.';
  }
}

final class NazaSpeechPlan {
  const NazaSpeechPlan({required this.segments, required this.seed});

  final List<NazaSpeechSegment> segments;
  final int seed;

  int get segmentCount => segments.length;
}

/// A cheap local prosody planner. It uses punctuation and a tiny lexical
/// classifier instead of another model call, keeping latency and cost bounded.
final class HumanizedSpeechPlanner {
  const HumanizedSpeechPlanner();

  static const int maxInputCharacters = 200000;
  static const int _maxOpenAiSegmentCharacters = 720;
  static const int _maxBarkSegmentCharacters = 190;

  NazaSpeechPlan plan({
    required String text,
    required NazaVoiceSettings settings,
    int? seed,
  }) {
    if (text.length > maxInputCharacters) {
      throw const FormatException(
        'Reading text exceeds the 200,000 character limit.',
      );
    }
    final cleaned = _cleanForSpeech(text);
    if (cleaned.isEmpty) {
      throw const FormatException('There is no text to read.');
    }

    final planSeed = seed ?? math.Random.secure().nextInt(0x7fffffff);
    final random = math.Random(planSeed);
    final segmentLimit = settings.backend == NazaSpeechBackend.replicateBark
        ? _maxBarkSegmentCharacters
        : _maxOpenAiSegmentCharacters;
    final atoms = _buildAtoms(cleaned, segmentLimit);
    final grouped = _groupAtoms(atoms, segmentLimit);
    final segments = <NazaSpeechSegment>[];
    var priorSpeed = settings.baseSpeed;

    for (var index = 0; index < grouped.length; index++) {
      final atom = grouped[index];
      final emotion = _emotionFor(atom.text);
      final rawSpeed =
          settings.baseSpeed +
          _triangular(random) * settings.paceVariation +
          _emotionSpeedOffset(emotion) * settings.emotionStrength;
      final smoothedSpeed = index == 0
          ? rawSpeed
          : priorSpeed * 0.48 + rawSpeed * 0.52;
      final speed = _clamp(smoothedSpeed, 0.84, 1.14);
      priorSpeed = speed;

      final pauseMs = index == grouped.length - 1
          ? 0
          : _pauseMilliseconds(
              atom.text,
              paragraphEnd: atom.paragraphEnd,
              settings: settings,
              random: random,
            );
      final canDisfluent = index > 0 && _safeForDisfluency(atom.text);
      final addDisfluency =
          settings.disfluenciesEnabled &&
          canDisfluent &&
          random.nextDouble() < settings.disfluencyRate;
      final filler = addDisfluency ? _fillerFor(emotion, random) : '';
      final spokenText = filler.isEmpty ? atom.text : '$filler ${atom.text}';

      final breathChance =
          settings.breathRate *
          (atom.paragraphEnd ? 1.45 : 1.0) *
          (emotion == NazaSpeechEmotion.solemn ||
                  emotion == NazaSpeechEmotion.weary
              ? 1.25
              : 1.0);
      final breath =
          settings.breathsEnabled &&
          pauseMs >= 180 &&
          random.nextDouble() < breathChance.clamp(0, 0.75);
      final barkMarker = _barkMarker(
        text: atom.text,
        emotion: emotion,
        breath: breath,
        strength: settings.emotionStrength,
        random: random,
      );
      final barkPrompt = barkMarker.isEmpty
          ? spokenText
          : '$barkMarker $spokenText';
      final temperatureDrift =
          _triangular(random) * 0.055 * settings.emotionStrength;

      segments.add(
        NazaSpeechSegment(
          sourceText: atom.text,
          spokenText: spokenText,
          barkPrompt: barkPrompt,
          speed: double.parse(speed.toStringAsFixed(3)),
          pauseAfter: Duration(milliseconds: pauseMs),
          emotion: emotion,
          audibleBreathAfter: breath,
          breathSeed: random.nextInt(0x7fffffff),
          barkTextTemperature: _clamp(
            settings.barkTextTemperature + temperatureDrift,
            0.35,
            1,
          ),
          barkWaveformTemperature: _clamp(
            settings.barkWaveformTemperature - temperatureDrift * 0.55,
            0.35,
            1,
          ),
        ),
      );
    }

    return NazaSpeechPlan(
      segments: List<NazaSpeechSegment>.unmodifiable(segments),
      seed: planSeed,
    );
  }

  static String _cleanForSpeech(String input) {
    var value = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Keep the displayed meaning while preventing Markdown punctuation from
    // being read aloud as formatting syntax.
    value = value.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((?:https?://|mailto:)[^\s)]+\)'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'^\s{0,3}(?:#{1,6}|[-*+]\s|>\s?)', multiLine: true),
      (_) => '',
    );
    value = value.replaceAll(RegExp(r'[`*_]{1,3}'), '');
    value = value.replaceAll(RegExp(r'[ \t]+'), ' ');
    value = value.replaceAll(RegExp(r' *\n *'), '\n');
    value = value.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return value.trim();
  }

  static List<_SpeechAtom> _buildAtoms(String text, int limit) {
    final paragraphs = text.split(RegExp(r'\n\s*\n|\n'));
    final atoms = <_SpeechAtom>[];
    for (final rawParagraph in paragraphs) {
      final paragraph = rawParagraph.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (paragraph.isEmpty) continue;
      final sentences = _sentences(paragraph);
      final paragraphAtoms = <String>[];
      for (final sentence in sentences) {
        paragraphAtoms.addAll(_splitLong(sentence, limit));
      }
      for (var i = 0; i < paragraphAtoms.length; i++) {
        atoms.add(
          _SpeechAtom(
            paragraphAtoms[i],
            paragraphEnd: i == paragraphAtoms.length - 1,
          ),
        );
      }
    }
    return atoms;
  }

  static List<String> _sentences(String paragraph) {
    final out = <String>[];
    var start = 0;
    for (var i = 0; i < paragraph.length; i++) {
      final char = paragraph[i];
      if (char != '.' && char != '!' && char != '?' && char != ';') continue;
      final atEnd = i == paragraph.length - 1;
      final followedBySpace =
          !atEnd && _isWhitespace(paragraph.codeUnitAt(i + 1));
      if (!atEnd && !followedBySpace) continue;
      if (char == '.' && _looksLikeAbbreviation(paragraph, i)) continue;
      final sentence = paragraph.substring(start, i + 1).trim();
      if (sentence.isNotEmpty) out.add(sentence);
      start = i + 1;
    }
    final tail = paragraph.substring(start).trim();
    if (tail.isNotEmpty) out.add(tail);
    return out.isEmpty ? <String>[paragraph] : out;
  }

  static bool _looksLikeAbbreviation(String value, int periodIndex) {
    if (periodIndex > 0 &&
        periodIndex + 1 < value.length &&
        _isDigit(value.codeUnitAt(periodIndex - 1)) &&
        _isDigit(value.codeUnitAt(periodIndex + 1))) {
      return true;
    }
    final prefix = value.substring(0, periodIndex).toLowerCase();
    const abbreviations = <String>[
      'mr',
      'mrs',
      'ms',
      'dr',
      'prof',
      'sr',
      'jr',
      'st',
      'vs',
      'e.g',
      'i.e',
    ];
    return abbreviations.any((item) => prefix.endsWith(item));
  }

  static List<String> _splitLong(String text, int limit) {
    if (text.length <= limit) return <String>[text];
    final out = <String>[];
    var cursor = 0;
    while (cursor < text.length) {
      final hardEnd = math.min(cursor + limit, text.length);
      if (hardEnd == text.length) {
        out.add(text.substring(cursor).trim());
        break;
      }
      final minimum = cursor + (limit * 0.48).round();
      var cut = -1;
      for (var i = hardEnd; i >= minimum; i--) {
        final char = text[i - 1];
        if (',;:—–'.contains(char)) {
          cut = i;
          break;
        }
      }
      if (cut < 0) {
        for (var i = hardEnd; i >= minimum; i--) {
          if (_isWhitespace(text.codeUnitAt(i - 1))) {
            cut = i;
            break;
          }
        }
      }
      cut = cut < 0 ? hardEnd : cut;
      final part = text.substring(cursor, cut).trim();
      if (part.isNotEmpty) out.add(part);
      cursor = cut;
      while (cursor < text.length && _isWhitespace(text.codeUnitAt(cursor))) {
        cursor++;
      }
    }
    return out;
  }

  static List<_SpeechAtom> _groupAtoms(List<_SpeechAtom> atoms, int limit) {
    final out = <_SpeechAtom>[];
    var text = '';
    var paragraphEnd = false;
    for (final atom in atoms) {
      final joined = text.isEmpty ? atom.text : '$text ${atom.text}';
      if (text.isNotEmpty && (joined.length > limit || paragraphEnd)) {
        out.add(_SpeechAtom(text, paragraphEnd: paragraphEnd));
        text = atom.text;
      } else {
        text = joined;
      }
      paragraphEnd = atom.paragraphEnd;
      if (paragraphEnd) {
        out.add(_SpeechAtom(text, paragraphEnd: true));
        text = '';
        paragraphEnd = false;
      }
    }
    if (text.isNotEmpty) out.add(_SpeechAtom(text, paragraphEnd: paragraphEnd));
    return out;
  }

  static int _pauseMilliseconds(
    String text, {
    required bool paragraphEnd,
    required NazaVoiceSettings settings,
    required math.Random random,
  }) {
    final trimmed = text.trimRight();
    final last = trimmed.isEmpty ? '' : trimmed[trimmed.length - 1];
    var base = switch (last) {
      '?' => 305,
      '!' => 230,
      '.' => 255,
      ';' => 185,
      ':' => 175,
      ',' || '—' || '–' => 135,
      _ => 115,
    };
    if (paragraphEnd) base += 285;
    final jitter = 1 + _triangular(random) * settings.pauseVariation;
    return (base * settings.pauseScale * jitter).round().clamp(55, 1100);
  }

  static NazaSpeechEmotion _emotionFor(String text) {
    final lower = text.toLowerCase();
    if (text.trimRight().endsWith('?')) return NazaSpeechEmotion.curious;
    if (RegExp(r'\bugh\b').hasMatch(lower) ||
        _hasAny(lower, const <String>[
          'frustrat',
          'annoy',
          'exhaust',
          'tired',
          'hate ',
          'awful',
        ])) {
      return NazaSpeechEmotion.weary;
    }
    if (_hasAny(lower, const <String>[
      'grief',
      'loss',
      'died',
      'death',
      'sorry',
      'sad',
      'pain',
      'fear',
    ])) {
      return NazaSpeechEmotion.solemn;
    }
    if (_hasAny(lower, const <String>[
      'safe',
      'okay',
      'breathe',
      'together',
      'help',
      'steady',
      'support',
    ])) {
      return NazaSpeechEmotion.reassuring;
    }
    if (text.contains('!') ||
        _hasAny(lower, const <String>[
          'great',
          'wonderful',
          'love',
          'exciting',
          'happy',
          'yes',
        ])) {
      return NazaSpeechEmotion.bright;
    }
    if (_hasAny(lower, const <String>[
      'welcome',
      'glad',
      'thank',
      'friend',
      'kind',
    ])) {
      return NazaSpeechEmotion.warm;
    }
    return NazaSpeechEmotion.neutral;
  }

  static double _emotionSpeedOffset(NazaSpeechEmotion emotion) =>
      switch (emotion) {
        NazaSpeechEmotion.bright => 0.025,
        NazaSpeechEmotion.curious => -0.008,
        NazaSpeechEmotion.reassuring => -0.018,
        NazaSpeechEmotion.solemn => -0.038,
        NazaSpeechEmotion.weary => -0.026,
        NazaSpeechEmotion.warm => -0.006,
        NazaSpeechEmotion.neutral => 0,
      };

  static bool _safeForDisfluency(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.length < 28 ||
        trimmed.startsWith(RegExp(r'[0-9]')) ||
        trimmed.contains('://') ||
        trimmed.contains('@') ||
        trimmed.contains(RegExp(r'\b(?:class|void|return|import)\b'))) {
      return false;
    }
    return true;
  }

  static String _fillerFor(NazaSpeechEmotion emotion, math.Random random) {
    if (emotion == NazaSpeechEmotion.weary && random.nextDouble() < 0.42) {
      return 'Ugh...';
    }
    final pick = random.nextDouble();
    if (pick < 0.46) return 'Um...';
    if (pick < 0.82) return 'Uh...';
    return 'Well...';
  }

  static String _barkMarker({
    required String text,
    required NazaSpeechEmotion emotion,
    required bool breath,
    required double strength,
    required math.Random random,
  }) {
    if (!breath) return '';
    if ((emotion == NazaSpeechEmotion.solemn ||
            emotion == NazaSpeechEmotion.weary) &&
        random.nextDouble() < 0.48 * strength) {
      return '[sighs]';
    }
    final lower = text.toLowerCase();
    if (emotion == NazaSpeechEmotion.bright &&
        (lower.contains('haha') || lower.contains('funny')) &&
        random.nextDouble() < 0.35 * strength) {
      return '[laughs]';
    }
    return '';
  }

  static bool _hasAny(String value, List<String> needles) =>
      needles.any(value.contains);

  static double _triangular(math.Random random) =>
      random.nextDouble() + random.nextDouble() - 1;

  static double _clamp(double value, double minimum, double maximum) =>
      value.clamp(minimum, maximum).toDouble();

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A;

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}

final class _SpeechAtom {
  const _SpeechAtom(this.text, {required this.paragraphEnd});

  final String text;
  final bool paragraphEnd;
}
