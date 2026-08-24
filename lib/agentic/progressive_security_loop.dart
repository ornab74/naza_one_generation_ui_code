// Progressive, bounded security review for model-proposed code and container plans.
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import '../security/boundary_sanitizer.dart';

enum NazaSecuritySeverity { low, medium, high, critical }

@immutable
final class NazaSecurityFinding {
  const NazaSecurityFinding({
    required this.ruleId,
    required this.severity,
    required this.evidence,
    required this.remediation,
    required this.confidence,
    required this.line,
  });
  final String ruleId;
  final NazaSecuritySeverity severity;
  final String evidence;
  final String remediation;
  final double confidence;
  final int line;
}

@immutable
final class NazaProgressiveSecurityReport {
  const NazaProgressiveSecurityReport({
    required this.iterations,
    required this.findings,
    required this.reviewedDigest,
    required this.truncated,
  });
  final int iterations;
  final List<NazaSecurityFinding> findings;
  final String reviewedDigest;
  final bool truncated;
  bool get denied => findings.any(
    (finding) =>
        finding.severity == NazaSecuritySeverity.high ||
        finding.severity == NazaSecuritySeverity.critical,
  );
}

/// A deterministic first line of defence inspired by Daybreak's progressive
/// source review. It repeats independent rule families until no new evidence
/// appears; an LLM may add findings elsewhere, but can never remove these.
final class NazaProgressiveSecurityLoop {
  const NazaProgressiveSecurityLoop({this.maximumCharacters = 256000});
  final int maximumCharacters;

  NazaProgressiveSecurityReport review(String untrustedText) {
    final sanitized = NazaBoundarySanitizer.modelOutput(
      untrustedText,
      maxCharacters: maximumCharacters,
    );
    final truncated = untrustedText.length > sanitized.length;
    final lines = const LineSplitter().convert(sanitized);
    final findings = <NazaSecurityFinding>[];
    final seen = <String>{};
    var iterations = 0;
    for (final family in _families) {
      iterations++;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        for (final rule in family) {
          if (!rule.pattern.hasMatch(line)) continue;
          final key = '${rule.id}:${index + 1}';
          if (!seen.add(key)) continue;
          findings.add(
            NazaSecurityFinding(
              ruleId: rule.id,
              severity: rule.severity,
              evidence: _evidence(line),
              remediation: rule.remediation,
              confidence: rule.confidence,
              line: index + 1,
            ),
          );
          if (findings.length >= 48) break;
        }
        if (findings.length >= 48) break;
      }
      if (findings.length >= 48) break;
    }
    findings.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return NazaProgressiveSecurityReport(
      iterations: iterations,
      findings: List.unmodifiable(findings),
      reviewedDigest: crypto.sha256.convert(utf8.encode(sanitized)).toString(),
      truncated: truncated,
    );
  }

  static String _evidence(String value) =>
      NazaBoundarySanitizer.databaseText(value.trim(), maxCharacters: 240);
}

final class _Rule {
  const _Rule(
    this.id,
    this.pattern,
    this.severity,
    this.confidence,
    this.remediation,
  );
  final String id;
  final RegExp pattern;
  final NazaSecuritySeverity severity;
  final double confidence;
  final String remediation;
}

final _families = <List<_Rule>>[
  <_Rule>[
    _Rule(
      'container.no-sandbox',
      RegExp(r'--no-sandbox\b', caseSensitive: false),
      NazaSecuritySeverity.critical,
      .99,
      'Keep Chromium sandboxing enabled.',
    ),
    _Rule(
      'container.privileged',
      RegExp(r'\bprivileged\s*:\s*true\b|--privileged\b', caseSensitive: false),
      NazaSecuritySeverity.critical,
      .99,
      'Use rootless containers with all capabilities dropped.',
    ),
    _Rule(
      'container.host-mount',
      RegExp(
        r'(/var/run/docker\.sock|/run/docker\.sock|/dev/dri|network_mode\s*:\s*host)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .97,
      'Remove host sockets, devices, and host networking.',
    ),
    _Rule(
      'container.unpinned-image',
      RegExp(
        r'\bimage\s*:\s*[^\s@]+:(latest|main|master)\b',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .93,
      'Pin the image by sha256 digest.',
    ),
  ],
  <_Rule>[
    _Rule(
      'shell.destructive',
      RegExp(
        r'\brm\s+-[^\n]*r[^\n]*f\b|\bmkfs\b|\bdd\s+if=',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.critical,
      .97,
      'Reject destructive shell operations.',
    ),
    _Rule(
      'shell.remote-pipe',
      RegExp(
        r'\b(curl|wget)\b[^\n|]*\|\s*(sh|bash|zsh)\b',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.critical,
      .98,
      'Download, hash-verify, inspect, then execute an immutable artifact.',
    ),
    _Rule(
      'shell.secret-echo',
      RegExp(
        r'\b(echo|printf)\b[^\n]*(token|secret|api[_-]?key|password)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .90,
      'Keep secrets out of commands and logs.',
    ),
  ],
  <_Rule>[
    _Rule(
      'network.tls-disabled',
      RegExp(
        r'(verify\s*=\s*false|rejectUnauthorized\s*:\s*false|CERT_NONE|--insecure\b)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .96,
      'Require TLS certificate and hostname verification.',
    ),
    _Rule(
      'network.wildcard-egress',
      RegExp(
        r'(allowedDomains|allowlist|egress)[^\n]*(\*|0\.0\.0\.0/0)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .91,
      'Use an explicit domain/IP allowlist.',
    ),
    _Rule(
      'network.public-admin',
      RegExp(
        r'(5001|2375|2376|9222)[^\n]*(0\.0\.0\.0|::)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.critical,
      .94,
      'Bind administrative endpoints to loopback or a private authenticated tunnel.',
    ),
  ],
  <_Rule>[
    _Rule(
      'code.dynamic-execution',
      RegExp(r'\b(eval|exec)\s*\(|new\s+Function\s*\(', caseSensitive: false),
      NazaSecuritySeverity.high,
      .86,
      'Replace dynamic execution with a typed allowlisted operation.',
    ),
    _Rule(
      'code.unsafe-deserialization',
      RegExp(
        r'pickle\.loads?\s*\(|yaml\.load\s*\([^\n]*Loader\s*=\s*yaml\.Loader',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .94,
      'Use a safe parser and schema validation.',
    ),
    _Rule(
      'sql.interpolation',
      RegExp(
        r'("|\x27)(SELECT|INSERT|UPDATE|DELETE)[^\n]*(\$\{|%s|\+\s*\w+)',
        caseSensitive: false,
      ),
      NazaSecuritySeverity.high,
      .82,
      'Use parameterized database statements.',
    ),
  ],
];
