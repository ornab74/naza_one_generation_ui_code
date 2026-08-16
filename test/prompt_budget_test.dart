// LLM-CONTEXT:BEGIN
// FILE: test/prompt_budget_test.dart
// ROLE: Owns prompt budget test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('prompt fitting always preserves the current user task', () {
    const sentinel = 'CURRENT_USER_TASK_SENTINEL_84f3';
    final oversizedPrompt =
        '''
[current_thread_context]
${List.filled(900, 'old-context').join(' ')}
[/current_thread_context]
[current_task]
[[USER_INPUT]]
Please answer $sentinel directly and completely.
[[/USER_INPUT]]
[/current_task]
[artifact_graph]
${List.filled(900, 'supporting-artifact').join(' ')}
[/artifact_graph]
''';

    for (final mode in NazaChatMode.values) {
      final systemInstruction = NazaChatModeRouter.prompt(mode);
      final fitted = NazaPromptBudget.fitPrompt(
        systemInstruction: systemInstruction,
        prompt: oversizedPrompt,
        headFraction: 0.38,
      );

      expect(fitted, contains(sentinel), reason: 'mode: ${mode.name}');
      expect(fitted, contains('[current_task]'), reason: 'mode: ${mode.name}');
      expect(fitted, contains('[/current_task]'), reason: 'mode: ${mode.name}');
      expect(
        NazaPromptBudget.fits(
          systemInstruction: systemInstruction,
          prompt: fitted,
        ),
        isTrue,
        reason: 'mode: ${mode.name}',
      );
    }
  });

  test(
    'token-heavy current task is compacted inside its trusted boundaries',
    () {
      const headSentinel = 'TASK_HEAD_SENTINEL';
      const tailSentinel = 'TASK_TAIL_SENTINEL';
      final tokenHeavyTask = List<String>.filled(900, '界🙂!').join();
      final prompt =
          '''
[current_thread_context]
${List.filled(400, 'older supporting context').join(' ')}
[/current_thread_context]
[current_task]
[[USER_INPUT]]
$headSentinel $tokenHeavyTask $tailSentinel
[[/USER_INPUT]]
[/current_task]
''';
      final systemInstruction = NazaChatModeRouter.prompt(NazaChatMode.writer);
      final fitted = NazaPromptBudget.fitPrompt(
        systemInstruction: systemInstruction,
        prompt: prompt,
        headFraction: 0.38,
      );

      expect(fitted, contains('[current_task]'));
      expect(fitted, contains('[/current_task]'));
      expect(fitted, contains(headSentinel));
      expect(fitted, contains(tailSentinel));
      expect(
        NazaPromptBudget.fits(
          systemInstruction: systemInstruction,
          prompt: fitted,
        ),
        isTrue,
      );
    },
  );
}
