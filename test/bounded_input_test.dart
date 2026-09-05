// LLM-CONTEXT:BEGIN
// FILE: test/bounded_input_test.dart
// ROLE: Verifies bounded file materialization at picker trust boundaries.
// DOMAIN: verification
// SECURITY-INVARIANT: Oversized input is rejected before or while streaming, never after full materialization.
// CHANGE-GUARD: Keep both metadata and streaming bypass regressions covered.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test(
    'reported oversized file is rejected without reading its stream',
    () async {
      var listened = false;
      final file = PlatformFile(
        name: 'oversized.docx',
        size: 9,
        readStream: Stream<List<int>>.multi((controller) {
          listened = true;
          controller.close();
        }),
      );

      await expectLater(
        NazaBoundedInput.readPlatformFile(
          file,
          maxBytes: 8,
          violation: const FormatException('too large'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(listened, isFalse);
    },
  );

  test(
    'stream growth beyond reported size is stopped at the byte cap',
    () async {
      final file = PlatformFile(
        name: 'growing.docx',
        size: 2,
        readStream: Stream<List<int>>.fromIterable(<List<int>>[
          <int>[1, 2],
          <int>[3, 4],
          <int>[5],
        ]),
      );

      await expectLater(
        NazaBoundedInput.readPlatformFile(
          file,
          maxBytes: 4,
          violation: const FormatException('too large'),
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('bounded stream preserves legitimate input bytes', () async {
    final file = PlatformFile(
      name: 'book.md',
      size: 4,
      readStream: Stream<List<int>>.fromIterable(<List<int>>[
        <int>[1, 2],
        <int>[3, 4],
      ]),
    );

    final bytes = await NazaBoundedInput.readPlatformFile(
      file,
      maxBytes: 4,
      violation: const FormatException('too large'),
    );
    expect(bytes, <int>[1, 2, 3, 4]);
  });
}
