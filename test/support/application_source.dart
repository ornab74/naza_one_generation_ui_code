import 'dart:io';

/// Reads a former library's implementation from the single application file.
/// Scope source assertions to that section so unrelated features cannot satisfy
/// them accidentally. Repeated sections are tolerated only when their bodies
/// are byte-for-byte identical; conflicting duplicates still fail closed.
Future<String> readApplicationSource(String formerPath) async {
  final source = await File('lib/main.dart').readAsString();
  const separator =
      '// ============================================================================\n';
  final header = '// SOURCE SECTION: $formerPath\n';
  final headerMatches = header.allMatches(source).toList(growable: false);
  if (headerMatches.isEmpty) {
    throw StateError('Missing application section: $formerPath');
  }

  String readBody(int start) {
    final bodyStart = source.indexOf(separator, start + header.length);
    if (bodyStart < 0) {
      throw StateError('Malformed application section: $formerPath');
    }
    final sectionBodyStart = bodyStart + separator.length;
    final end = source.indexOf(
      '$separator// SOURCE SECTION:',
      sectionBodyStart,
    );
    return source.substring(
      sectionBodyStart,
      end < 0 ? source.length : end,
    );
  }

  final bodies = headerMatches
      .map((match) => readBody(match.start))
      .toList(growable: false);
  final canonical = bodies.first;
  for (final body in bodies.skip(1)) {
    if (body != canonical) {
      throw StateError('Conflicting application sections: $formerPath');
    }
  }
  return canonical;
}
