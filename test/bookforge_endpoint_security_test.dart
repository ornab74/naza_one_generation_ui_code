// LLM-CONTEXT:BEGIN
// FILE: test/bookforge_endpoint_security_test.dart
// ROLE: Owns BookForge endpoint egress security coverage within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/naza_bookforge.dart';

void main() {
  test('API-key generation accepts only the pinned OpenAI origin', () {
    expect(
      () => GenerationService.validateApiKeyEndpoint(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      ),
      returnsNormally,
    );
    for (final String endpoint in <String>[
      'http://api.openai.com/v1/chat/completions',
      'https://evil.example/v1/chat/completions',
      'https://api.openai.com:8443/v1/chat/completions',
    ]) {
      expect(
        () => GenerationService.validateApiKeyEndpoint(Uri.parse(endpoint)),
        throwsArgumentError,
        reason: endpoint,
      );
    }
  });
}
