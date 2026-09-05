import 'dart:io';

/// Reads a former library's implementation from the single application file.
/// Scope source assertions to that section so unrelated features cannot satisfy
/// them accidentally. Missing or duplicate sections fail explicitly.
Future<String> readApplicationSource(String formerPath) async {
  final source = await File('lib/main.dart').readAsString();
  const separator =
      '// ============================================================================\n';
  final marker = '$separator// SOURCE SECTION: $formerPath\n$separator';
  final start = source.indexOf(marker);
  if (start < 0 || source.indexOf(marker, start + marker.length) >= 0) {
    throw StateError('Expected exactly one application section: $formerPath');
  }
  final bodyStart = start + marker.length;
  final end = source.indexOf('$separator// SOURCE SECTION:', bodyStart);
  return source.substring(bodyStart, end < 0 ? source.length : end);
}
