// LLM-CONTEXT:BEGIN
// FILE: lib/security/probabilistic_harm_filter.dart
// ROLE: Fail-closed, model-assisted authorization for privileged operations.
// DOMAIN: security
// SECURITY-INVARIANT: The classifier receives only a normalized semantic
// command name, bounded CPU/RAM telemetry, and a locally derived L-state. A
// High, invalid, unavailable, or timed-out result can never authorize work.
// CHANGE-GUARD: Keep command arguments, prompts, payloads, paths, credentials,
// and user content outside this boundary; preserve deterministic hard denies.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

enum NazaHarmRisk { low, medium, high, indeterminate }

extension NazaHarmRiskX on NazaHarmRisk {
  String get label => switch (this) {
    NazaHarmRisk.low => 'Low',
    NazaHarmRisk.medium => 'Medium',
    NazaHarmRisk.high => 'High',
    NazaHarmRisk.indeterminate => 'Indeterminate',
  };

  bool get denied =>
      this == NazaHarmRisk.high || this == NazaHarmRisk.indeterminate;
}

/// Bounded host measurements used by the sentinel. No process arguments,
/// environment variables, filesystem paths, or user content are collected.
final class NazaSystemTelemetry {
  const NazaSystemTelemetry({
    required this.logicalProcessors,
    required this.processRssBytes,
    this.cpuUtilization,
    this.totalMemoryBytes,
    this.availableMemoryBytes,
  });

  final int logicalProcessors;
  final int processRssBytes;
  final double? cpuUtilization;
  final int? totalMemoryBytes;
  final int? availableMemoryBytes;

  double? get memoryUtilization {
    final total = totalMemoryBytes;
    final available = availableMemoryBytes;
    if (total == null || available == null || total <= 0) return null;
    return ((total - available) / total).clamp(0.0, 1.0).toDouble();
  }

  String get cpuPercent => cpuUtilization == null
      ? 'unknown'
      : (cpuUtilization! * 100).clamp(0, 100).toStringAsFixed(2);

  String get memoryPercent => memoryUtilization == null
      ? 'unknown'
      : (memoryUtilization! * 100).clamp(0, 100).toStringAsFixed(2);

  int get processRssMiB => processRssBytes ~/ (1024 * 1024);
  int? get totalMemoryMiB =>
      totalMemoryBytes == null ? null : totalMemoryBytes! ~/ (1024 * 1024);
  int? get availableMemoryMiB => availableMemoryBytes == null
      ? null
      : availableMemoryBytes! ~/ (1024 * 1024);
}

abstract interface class NazaTelemetrySampler {
  Future<NazaSystemTelemetry> sample();
}

/// Cross-platform baseline plus a bounded Linux `/proc` enhancement. Missing
/// platform metrics remain explicitly unknown; they are never replaced with a
/// fabricated zero that could make a risky operation look benign.
final class NazaHostTelemetrySampler implements NazaTelemetrySampler {
  const NazaHostTelemetrySampler({
    this.cpuSampleWindow = const Duration(milliseconds: 30),
  });

  final Duration cpuSampleWindow;

  @override
  Future<NazaSystemTelemetry> sample() async {
    double? cpu;
    int? totalMemory;
    int? availableMemory;
    if (Platform.isLinux) {
      try {
        cpu = await _linuxCpuUtilization();
      } on FileSystemException {
        cpu = null;
      } on FormatException {
        cpu = null;
      }
      try {
        final memory = await _linuxMemory();
        totalMemory = memory.$1;
        availableMemory = memory.$2;
      } on FileSystemException {
        totalMemory = null;
        availableMemory = null;
      } on FormatException {
        totalMemory = null;
        availableMemory = null;
      }
    }
    return NazaSystemTelemetry(
      logicalProcessors: math.max(1, Platform.numberOfProcessors),
      processRssBytes: math.max(0, ProcessInfo.currentRss),
      cpuUtilization: cpu,
      totalMemoryBytes: totalMemory,
      availableMemoryBytes: availableMemory,
    );
  }

  Future<double?> _linuxCpuUtilization() async {
    final first = await _readLinuxCpu();
    await Future<void>.delayed(cpuSampleWindow);
    final second = await _readLinuxCpu();
    final totalDelta = second.$1 - first.$1;
    final idleDelta = second.$2 - first.$2;
    if (totalDelta <= 0 || idleDelta < 0) return null;
    return (1 - (idleDelta / totalDelta)).clamp(0.0, 1.0).toDouble();
  }

  static Future<(int, int)> _readLinuxCpu() async {
    final line =
        (await File(
              '/proc/stat',
            ).openRead(0, 512).transform(utf8.decoder).join())
            .split('\n')
            .firstWhere(
              (value) => value.startsWith('cpu '),
              orElse: () => throw const FormatException('Missing CPU row.'),
            );
    final values = line
        .trim()
        .split(RegExp(r'\s+'))
        .skip(1)
        .map(int.tryParse)
        .toList(growable: false);
    if (values.length < 4 || values.any((value) => value == null)) {
      throw const FormatException('Malformed CPU row.');
    }
    final total = values.fold<int>(0, (sum, value) => sum + value!);
    final idle = values[3]! + (values.length > 4 ? values[4]! : 0);
    return (total, idle);
  }

  static Future<(int?, int?)> _linuxMemory() async {
    final text = await File(
      '/proc/meminfo',
    ).openRead(0, 16 * 1024).transform(utf8.decoder).join();
    int? field(String name) {
      final match = RegExp(
        '^$name:\\s+(\\d+)\\s+kB\\s*\$',
        multiLine: true,
      ).firstMatch(text);
      final kib = int.tryParse(match?.group(1) ?? '');
      return kib == null ? null : kib * 1024;
    }

    return (field('MemTotal'), field('MemAvailable'));
  }
}

/// A bounded local diagnostic state. This state is deliberately described as
/// a classifier feature, not cryptographic entropy or proof of physical
/// non-locality.
final class NazaSentinelLState {
  const NazaSentinelLState({
    required this.pZero,
    required this.pOne,
    required this.coherence,
    required this.phase,
    required this.nonlocalIndex,
    required this.stateBit,
    required this.checksum,
  });

  final double pZero;
  final double pOne;
  final double coherence;
  final double phase;
  final double nonlocalIndex;
  final int stateBit;
  final String checksum;

  static NazaSentinelLState derive({
    required String commandName,
    required NazaSystemTelemetry telemetry,
  }) {
    final canonical = <String>[
      commandName,
      telemetry.logicalProcessors.toString(),
      telemetry.cpuPercent,
      telemetry.processRssMiB.toString(),
      telemetry.totalMemoryMiB?.toString() ?? 'unknown',
      telemetry.availableMemoryMiB?.toString() ?? 'unknown',
    ].join('|');
    final digest = crypto.sha256.convert(utf8.encode(canonical)).bytes;
    double unit(int offset) {
      final value =
          (digest[offset] << 16) |
          (digest[offset + 1] << 8) |
          digest[offset + 2];
      return value / 0xFFFFFF;
    }

    final cpu = telemetry.cpuUtilization ?? unit(0);
    final memory = telemetry.memoryUtilization ?? unit(3);
    final phase = unit(6) * math.pi * 2;
    final wave = (0.5 + 0.5 * math.sin(phase + cpu * math.pi)).clamp(0.0, 1.0);
    final pOne = (cpu * 0.28 + memory * 0.26 + unit(9) * 0.24 + wave * 0.22)
        .clamp(0.0, 1.0)
        .toDouble();
    final pZero = (1.0 - pOne).clamp(0.0, 1.0).toDouble();
    final coherence =
        (math.cos(phase).abs() * 0.34 +
                (1 - (pZero - pOne).abs()) * 0.38 +
                unit(12) * 0.28)
            .clamp(0.0, 1.0)
            .toDouble();
    final nonlocal =
        (coherence * 0.34 +
                wave * 0.24 +
                (cpu - memory).abs() * 0.20 +
                unit(15) * 0.22)
            .clamp(0.0, 1.0)
            .toDouble();
    return NazaSentinelLState(
      pZero: pZero,
      pOne: pOne,
      coherence: coherence,
      phase: phase,
      nonlocalIndex: nonlocal,
      stateBit: pOne >= pZero ? 1 : 0,
      checksum: digest
          .take(12)
          .map((value) => value.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }
}

final class NazaHarmDecision {
  const NazaHarmDecision({
    required this.commandName,
    required this.risk,
    required this.votes,
    required this.telemetry,
    required this.lState,
    required this.decidedAt,
    required this.reason,
    this.modelSha256,
  });

  final String commandName;
  final NazaHarmRisk risk;
  final List<NazaHarmRisk> votes;
  final NazaSystemTelemetry telemetry;
  final NazaSentinelLState lState;
  final DateTime decidedAt;
  final String reason;
  final String? modelSha256;

  bool get denied => risk.denied;

  /// Secret-free audit projection. Command arguments and payloads never enter
  /// the decision, so they cannot leak through this receipt.
  Map<String, Object?> toAuditJson() => <String, Object?>{
    'schema': 'naza-probabilistic-harm-decision-v1',
    'commandName': commandName,
    'risk': risk.name,
    'votes': votes.map((vote) => vote.name).toList(growable: false),
    'cpuPercent': telemetry.cpuPercent,
    'memoryPercent': telemetry.memoryPercent,
    'processRssMiB': telemetry.processRssMiB,
    'logicalProcessors': telemetry.logicalProcessors,
    'lStateChecksum': lState.checksum,
    'modelSha256': modelSha256,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
    'reason': reason,
  };
}

final class NazaHarmDeniedException implements Exception {
  const NazaHarmDeniedException(this.decision);

  final NazaHarmDecision decision;

  @override
  String toString() =>
      'Probabilistic harm filter denied ${decision.commandName}: '
      '${decision.risk.label} (${decision.reason}).';
}

abstract interface class NazaHarmGate {
  Future<NazaHarmDecision> assessCommand(String commandName);

  Future<NazaHarmDecision> requireAllowed(String commandName);
}

abstract interface class NazaHarmModel {
  String? get pinnedSha256;

  Future<String> generate(
    String prompt, {
    required int maxTokens,
    required double temperature,
  });

  void cancel();
}

/// Model-assisted gate adapted from the supplied scanner's repeated
/// PUNKD/CHUNKD classifier. Security semantics are intentionally stricter:
/// every High vote is a veto and every malformed/failing result is denied.
final class NazaProbabilisticHarmFilter implements NazaHarmGate {
  NazaProbabilisticHarmFilter({
    required NazaHarmModel model,
    NazaTelemetrySampler telemetry = const NazaHostTelemetrySampler(),
    this.defensePasses = 5,
    this.decisionTimeout = const Duration(seconds: 45),
  }) : _model = model,
       _telemetry = telemetry {
    if (defensePasses < 1 || defensePasses > 5) {
      throw ArgumentError.value(defensePasses, 'defensePasses');
    }
  }

  final NazaHarmModel _model;
  final NazaTelemetrySampler _telemetry;
  final int defensePasses;
  final Duration decisionTimeout;

  Future<void> _tail = Future<void>.value();

  @override
  Future<NazaHarmDecision> assessCommand(String commandName) {
    final completer = Completer<NazaHarmDecision>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await _assess(commandName));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<NazaHarmDecision> requireAllowed(String commandName) async {
    final decision = await assessCommand(commandName);
    if (decision.denied) throw NazaHarmDeniedException(decision);
    return decision;
  }

  Future<NazaHarmDecision> _assess(String rawCommandName) async {
    final telemetry = await _safeTelemetry();
    String commandName;
    try {
      commandName = normalizeCommandName(rawCommandName);
    } on FormatException {
      // Never echo an invalid/raw value into a decision or audit record. The
      // placeholder is itself a valid semantic name and makes malformed gate
      // inputs fail closed with a structured receipt instead of escaping the
      // authorization boundary as an uncaught parser error.
      commandName = 'invalid.command-name';
      final lState = NazaSentinelLState.derive(
        commandName: commandName,
        telemetry: telemetry,
      );
      return _decision(
        commandName,
        telemetry,
        lState,
        const <NazaHarmRisk>[NazaHarmRisk.indeterminate],
        NazaHarmRisk.indeterminate,
        'invalid semantic command name',
      );
    }
    final lState = NazaSentinelLState.derive(
      commandName: commandName,
      telemetry: telemetry,
    );
    if (_deterministicallyDenied(commandName)) {
      return NazaHarmDecision(
        commandName: commandName,
        risk: NazaHarmRisk.high,
        votes: const <NazaHarmRisk>[NazaHarmRisk.high],
        telemetry: telemetry,
        lState: lState,
        decidedAt: DateTime.now().toUtc(),
        reason: 'deterministic hard-deny command class',
        modelSha256: _model.pinnedSha256,
      );
    }

    final votes = <NazaHarmRisk>[];
    var abandoned = false;
    try {
      await (() async {
        final basePrompt = _buildPrompt(commandName, telemetry, lState);
        for (var pass = 0; pass < defensePasses; pass++) {
          if (abandoned) {
            throw StateError('Classifier assessment was abandoned.');
          }
          final passPrompt =
              '''$basePrompt

[defense_pass]
index=${pass + 1}/$defensePasses; vote_privately=true
[/defense_pass]''';
          final output = await _chunkedGenerate(
            _applyPunkd(passPrompt, commandName),
            isAbandoned: () => abandoned,
          );
          if (abandoned) {
            throw StateError('Classifier assessment was abandoned.');
          }
          final risk = _strictRisk(output);
          votes.add(risk);
          // Mission-critical veto: one High is enough to deny. Invalid output
          // is also terminal because it cannot be interpreted safely.
          if (risk == NazaHarmRisk.high || risk == NazaHarmRisk.indeterminate) {
            break;
          }
        }
      }()).timeout(decisionTimeout);
    } on TimeoutException {
      abandoned = true;
      _model.cancel();
      votes.add(NazaHarmRisk.indeterminate);
      return _decision(
        commandName,
        telemetry,
        lState,
        votes,
        NazaHarmRisk.indeterminate,
        'classifier timeout',
      );
    } catch (_) {
      abandoned = true;
      _model.cancel();
      votes.add(NazaHarmRisk.indeterminate);
      return _decision(
        commandName,
        telemetry,
        lState,
        votes,
        NazaHarmRisk.indeterminate,
        'classifier unavailable or failed',
      );
    }

    if (votes.isEmpty || votes.contains(NazaHarmRisk.indeterminate)) {
      return _decision(
        commandName,
        telemetry,
        lState,
        votes,
        NazaHarmRisk.indeterminate,
        'no complete valid classifier vote',
      );
    }
    if (votes.contains(NazaHarmRisk.high)) {
      return _decision(
        commandName,
        telemetry,
        lState,
        votes,
        NazaHarmRisk.high,
        'High classifier veto',
      );
    }
    final medium = votes.where((vote) => vote == NazaHarmRisk.medium).length;
    final low = votes.where((vote) => vote == NazaHarmRisk.low).length;
    final risk = medium >= low ? NazaHarmRisk.medium : NazaHarmRisk.low;
    return _decision(
      commandName,
      telemetry,
      lState,
      votes,
      risk,
      'valid repeated classifier vote',
    );
  }

  NazaHarmDecision _decision(
    String commandName,
    NazaSystemTelemetry telemetry,
    NazaSentinelLState lState,
    List<NazaHarmRisk> votes,
    NazaHarmRisk risk,
    String reason,
  ) => NazaHarmDecision(
    commandName: commandName,
    risk: risk,
    votes: List<NazaHarmRisk>.unmodifiable(votes),
    telemetry: telemetry,
    lState: lState,
    decidedAt: DateTime.now().toUtc(),
    reason: reason,
    modelSha256: _model.pinnedSha256,
  );

  Future<NazaSystemTelemetry> _safeTelemetry() async {
    try {
      return await _telemetry.sample().timeout(const Duration(seconds: 2));
    } catch (_) {
      return NazaSystemTelemetry(
        logicalProcessors: math.max(1, Platform.numberOfProcessors),
        processRssBytes: math.max(0, ProcessInfo.currentRss),
      );
    }
  }

  Future<String> _chunkedGenerate(
    String prompt, {
    required bool Function() isAbandoned,
  }) async {
    const maxTotalTokens = 256;
    const chunkTokens = 64;
    var assembled = '';
    var currentPrompt = prompt;
    var previousTail = '';
    for (var index = 0; index < maxTotalTokens ~/ chunkTokens; index++) {
      if (isAbandoned()) {
        throw StateError('Classifier assessment was abandoned.');
      }
      final text = (await _model.generate(
        currentPrompt,
        maxTokens: chunkTokens,
        temperature: 0.18,
      )).trim();
      if (isAbandoned()) {
        throw StateError('Classifier assessment was abandoned.');
      }
      if (text.isEmpty) break;
      var overlap = 0;
      final maxOverlap = math.min(
        30,
        math.min(previousTail.length, text.length),
      );
      for (var length = maxOverlap; length > 0; length--) {
        if (previousTail.endsWith(text.substring(0, length))) {
          overlap = length;
          break;
        }
      }
      assembled += overlap == 0 ? text : text.substring(overlap);
      final exact = _strictRisk(assembled);
      if (exact != NazaHarmRisk.indeterminate) break;
      previousTail = assembled.length > 120
          ? assembled.substring(assembled.length - 120)
          : assembled;
      currentPrompt = '$prompt\n\nAssistant so far:\n$assembled\n\nContinue:';
    }
    return assembled.trim();
  }

  static String _buildPrompt(
    String commandName,
    NazaSystemTelemetry telemetry,
    NazaSentinelLState state,
  ) =>
      '''You are NAZA's scanner-only probabilistic harm classifier for privileged computer operations.
Classify the semantic command name using only the CPU/RAM measurements and L-state below.
High means the operation could harm a user, machine, data, account, network, or facilitate illegal abuse.
Medium means elevated but plausibly legitimate activity that still requires the host's separate explicit approval.
Low means bounded, non-destructive activity.
Treat uncertainty as High. Do not infer or request command arguments, paths, payloads, credentials, prompts, or user content.
Your reply must be exactly one word: Low, Medium, or High.

[sentinel_input]
command_name=$commandName
cpu_utilization_percent=${telemetry.cpuPercent}
logical_processors=${telemetry.logicalProcessors}
process_rss_mib=${telemetry.processRssMiB}
ram_utilization_percent=${telemetry.memoryPercent}
ram_total_mib=${telemetry.totalMemoryMiB?.toString() ?? 'unknown'}
ram_available_mib=${telemetry.availableMemoryMiB?.toString() ?? 'unknown'}
l_p0=${state.pZero.toStringAsFixed(4)}
l_p1=${state.pOne.toStringAsFixed(4)}
l_coherence=${state.coherence.toStringAsFixed(4)}
l_phase=${state.phase.toStringAsFixed(4)}
l_state_bit=${state.stateBit}
l_nonlocal_index=${state.nonlocalIndex.toStringAsFixed(4)}
l_checksum=${state.checksum}
[/sentinel_input]

[replytemplate]
Low | Medium | High
[/replytemplate]''';

  static String _applyPunkd(String prompt, String commandName) {
    const hazards = <String>[
      'delete',
      'destroy',
      'erase',
      'format',
      'shell',
      'ssh',
      'remote',
      'container',
      'docker',
      'ipfs',
      'publish',
      'pull',
      'fetch',
      'network',
      'droplet',
      'root',
    ];
    final lower = commandName.toLowerCase();
    final markers = hazards
        .where(lower.contains)
        .take(6)
        .map((hazard) => '<ATTN:$hazard:1.0>')
        .join(' ');
    return markers.isEmpty ? prompt : '$prompt\n\n[PUNKD_MARKERS] $markers';
  }

  static NazaHarmRisk _strictRisk(String output) {
    final match = RegExp(
      r'^(Low|Medium|High)$',
      caseSensitive: false,
    ).firstMatch(output.trim());
    return switch (match?.group(1)?.toLowerCase()) {
      'low' => NazaHarmRisk.low,
      'medium' => NazaHarmRisk.medium,
      'high' => NazaHarmRisk.high,
      _ => NazaHarmRisk.indeterminate,
    };
  }

  static bool _deterministicallyDenied(String commandName) {
    return RegExp(
      r'(?:^|[._:/-])(?:bash|sh|zsh|fish|cmd|powershell|pwsh|sudo|su|rm|rmdir|dd|mkfs|fdisk|diskpart|wipefs|shutdown|reboot|poweroff|halt|kill|killall|pkill|delete|destroy|erase|wipe|format)(?:$|[._:/-])',
      caseSensitive: false,
    ).hasMatch(commandName);
  }

  static String normalizeCommandName(String raw) {
    var value = raw.trim();
    if (value.contains('/') || value.contains('\\')) {
      final parts = value
          .split(RegExp(r'[/\\]'))
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      value = parts.isEmpty ? '' : parts.last;
    }
    value = value.toLowerCase();
    if (value.isEmpty ||
        value.length > 96 ||
        !RegExp(r'^[a-z0-9][a-z0-9._:-]{0,95}$').hasMatch(value)) {
      throw const FormatException(
        'Sentinel command name must be a bounded semantic identifier.',
      );
    }
    return value;
  }
}
