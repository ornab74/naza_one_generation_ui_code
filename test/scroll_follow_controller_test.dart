// LLM-CONTEXT:BEGIN
// FILE: test/scroll_follow_controller_test.dart
// ROLE: Owns scroll follow controller regression coverage within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('does not dispose an injected scroll controller', () {
    final scrollController = ScrollController();
    final followController = NazaChatScrollFollowController(
      scrollController: scrollController,
    );

    followController.dispose();

    // A parent-owned controller must remain usable after the child controller
    // has been removed from the tree. This protects coordinated desktop and
    // mobile layouts from a delayed "used after dispose" failure.
    expect(() => scrollController.addListener(() {}), returnsNormally);
    scrollController.dispose();
  });
}
