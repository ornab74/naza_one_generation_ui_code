// LLM-CONTEXT:BEGIN
// FILE: test/bookforge_security_test.dart
// ROLE: Owns BookForge security regression coverage within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/naza_bookforge.dart';

void main() {
  test('publishing normalizes YAML control characters in metadata', () async {
    String? published;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{}', 404);
      published = utf8.decode(
        base64Decode(
          (jsonDecode(request.body) as Map<String, dynamic>)['content']
              as String,
        ),
      );
      return http.Response(
        jsonEncode(<String, Object?>{
          'content': <String, String>{
            'html_url': 'https://github.com/example/book',
          },
        }),
        201,
      );
    });
    final service = GitHubService(client: client);

    await service.publishMarkdown(
      target: const RepositoryTarget(owner: 'example', name: 'book'),
      book: BookDocument(
        id: '1',
        title: 'safe\nstatus: compromised',
        author: 'author\r\nowner: attacker',
        content: 'Body',
        format: BookFormat.markdown,
        origin: BookOrigin.local,
        status: BookStatus.draft,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        tags: const <String>['tag\n- injected', 'quote"tag'],
      ),
      token: 'token',
    );

    expect(published, isNotNull);
    expect(published, contains('title: "safe status: compromised"'));
    expect(published, contains('author: "author owner: attacker"'));
    expect(published, contains('"tag - injected"'));
    expect(published, contains('"quote\\"tag"'));
    expect(published, isNot(contains('\nstatus: compromised')));
    expect(published, isNot(contains('\nowner: attacker')));
  });

  test(
    'import rejects oversized compressed input before ZIP decoding',
    () async {
      final oversized = Uint8List(ImportService.maxCompressedBytes + 1);
      expect(
        () => ImportService().docxToMarkdown(oversized),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
