// LLM-CONTEXT:BEGIN
// FILE: lib/security/boundary_sanitizer.dart
// ROLE: Shared text hygiene for model, remote-node, and encrypted-record edges.
// DOMAIN: security
// SECURITY-INVARIANT: Preserve readable Unicode while removing invisible
// control spoofing, bounding allocation, and redacting common outbound secrets.
// CHANGE-GUARD: Never apply text normalization to ciphertext, keys, hashes,
// signatures, binary data, or canonical cryptographic serialization.
// LLM-CONTEXT:END

final class NazaBoundarySanitizer {
  const NazaBoundarySanitizer._();

  static final RegExp _disallowedControls = RegExp(
    '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F'
    '\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
  );
  static final RegExp _pemPrivateKey = RegExp(
    r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----',
    caseSensitive: false,
  );
  static final RegExp _namedSecret = RegExp(
    r'''\b(api[_-]?key|access[_-]?token|auth(?:orization)?|client[_-]?secret|private[_-]?token|refresh[_-]?token|account[_-]?key|connection[_-]?string|password|passwd|secret)\b\s*[:=]\s*["']?[^\s,"'\]}]{8,}''',
    caseSensitive: false,
  );
  static final RegExp _bearerSecret = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]{12,}',
    caseSensitive: false,
  );
  static final RegExp _knownToken = RegExp(
    r'\b(?:'
    r'sk-(?:ant-|proj-|svcacct-)?[A-Za-z0-9_-]{20,}'
    r'|xai-[A-Za-z0-9_-]{20,}'
    r'|AIza[A-Za-z0-9_-]{30,}'
    r'|dop_v1_[A-Fa-f0-9]{32,}'
    r'|doo_v1_[A-Za-z0-9_-]{20,}'
    r'|gh[pousr]_[A-Za-z0-9]{20,}'
    r'|github_pat_[A-Za-z0-9_]{20,}'
    r'|glpat-[A-Za-z0-9_-]{20,}'
    r'|hf_[A-Za-z0-9]{20,}'
    r'|xox[baprs]-[A-Za-z0-9-]{20,}'
    r'|npm_[A-Za-z0-9]{20,}'
    r'|AKIA[A-Z0-9]{16}'
    r')\b',
  );
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
  );

  static String modelInput(
    String value, {
    required int maxCharacters,
    bool redactSecrets = false,
  }) {
    var clean = _clean(value, maxCharacters: maxCharacters);
    if (redactSecrets) clean = _redactSecrets(clean);
    if (clean.trim().isEmpty) {
      throw const FormatException('Model input is empty after sanitization.');
    }
    return clean.trim();
  }

  static String modelOutput(String value, {required int maxCharacters}) =>
      _clean(value, maxCharacters: maxCharacters).trim();

  static String remoteText(
    String value, {
    required int maxCharacters,
    bool redactSecrets = true,
  }) {
    var clean = _clean(value, maxCharacters: maxCharacters);
    if (redactSecrets) clean = _redactSecrets(clean);
    return clean.trim();
  }

  static String databaseText(String value, {required int maxCharacters}) =>
      _clean(value, maxCharacters: maxCharacters).trim();

  /// Removes known secret values even when they use an unfamiliar token
  /// prefix. Callers should pass only credentials already held in trusted
  /// configuration, never values discovered in untrusted content.
  static String redactExactSecrets(String value, Iterable<String> secrets) {
    var clean = value;
    for (final candidate in secrets) {
      final secret = candidate.trim();
      if (secret.length >= 8) {
        clean = clean.replaceAll(secret, '[REDACTED_CONFIGURED_SECRET]');
      }
    }
    return clean;
  }

  static String _clean(String value, {required int maxCharacters}) {
    if (maxCharacters < 1) {
      throw ArgumentError.value(maxCharacters, 'maxCharacters');
    }
    var clean = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_disallowedControls, '');
    if (clean.length > maxCharacters) {
      clean = clean.substring(0, maxCharacters);
      // Do not leave a dangling UTF-16 high surrogate at the truncation edge.
      if (clean.isNotEmpty) {
        final last = clean.codeUnitAt(clean.length - 1);
        if (last >= 0xD800 && last <= 0xDBFF) {
          clean = clean.substring(0, clean.length - 1);
        }
      }
    }
    return clean;
  }

  static String _redactSecrets(String value) => value
      .replaceAll(_pemPrivateKey, '[REDACTED_PRIVATE_KEY]')
      .replaceAll(_bearerSecret, 'Bearer [REDACTED]')
      .replaceAllMapped(_namedSecret, (match) => '${match.group(1)}=[REDACTED]')
      .replaceAll(_jwt, '[REDACTED_JWT]')
      .replaceAll(_knownToken, '[REDACTED_TOKEN]');
}
