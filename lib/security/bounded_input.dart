// LLM-CONTEXT:BEGIN
// FILE: lib/security/bounded_input.dart
// ROLE: Central bounded materialization for attacker-influenced file streams.
// DOMAIN: security
// SECURITY-INVARIANT: Reject oversized or empty inputs before retaining more than the configured byte cap.
// CHANGE-GUARD: Preserve metadata prechecks, streaming enforcement, and caller-owned error types.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

final class NazaBoundedInput {
  const NazaBoundedInput._();

  static Future<Uint8List> readXFile(
    XFile file, {
    required int maxBytes,
    required Object violation,
  }) async {
    _validateLimit(maxBytes);
    final reportedLength = await file.length();
    if (reportedLength < 0 || reportedLength > maxBytes) throw violation;
    return _readStream(
      file.openRead(),
      maxBytes: maxBytes,
      violation: violation,
    );
  }

  static Future<Uint8List> readPlatformFile(
    PlatformFile file, {
    required int maxBytes,
    required Object violation,
  }) async {
    _validateLimit(maxBytes);
    if (file.size < 0 || file.size > maxBytes) throw violation;
    return _readStream(
      file.readStream ?? file.xFile.openRead(),
      maxBytes: maxBytes,
      violation: violation,
    );
  }

  static Future<Uint8List> _readStream(
    Stream<List<int>> stream, {
    required int maxBytes,
    required Object violation,
  }) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in stream) {
      if (chunk.length > maxBytes - total) throw violation;
      total += chunk.length;
      builder.add(chunk);
    }
    if (total == 0) throw violation;
    return builder.takeBytes();
  }

  static void _validateLimit(int maxBytes) {
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }
  }
}
