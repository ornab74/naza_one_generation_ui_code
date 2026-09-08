import 'dart:io';

/// Reads a former library's implementation from the single application file.
/// Scope source assertions to that section so unrelated features cannot satisfy
/// them accidentally. Missing or duplicate sections fail explicitly.
Future<String> readApplicationSource(String formerPath) async {
  final source = await File('lib/main.dart').readAsString();
  const separator =
      '// ============================================================================\n';
  final header = '// SOURCE SECTION: $formerPath\n';
  final headerMatches = header.allMatches(source).toList(growable: false);
  if (headerMatches.length != 1) {
    throw StateError('Expected exactly one application section: $formerPath');
  }
  final start = headerMatches.single.start;
  final bodyStart = source.indexOf(separator, start + header.length);
  if (bodyStart < 0) {
    throw StateError('Malformed application section: $formerPath');
  }
  final sectionBodyStart = bodyStart + separator.length;
  final end = source.indexOf('$separator// SOURCE SECTION:', sectionBodyStart);
  return source.substring(
    sectionBodyStart,
    end < 0 ? source.length : end,
  );
}
