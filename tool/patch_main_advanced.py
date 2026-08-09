#!/usr/bin/env python3
"""Guarded, idempotent integration patches for NAZA One's large main.dart.

Every edit asserts the exact legacy shape before writing. CI applies this to a
throw-away checkout first; the resulting main.dart is reviewed and analyzed
before any branch replacement is made.
"""
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "lib" / "main.dart"


def replace_exact(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if count == 0 and new in text:
        print(f"[already] {label}")
        return text
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one legacy match, found {count}")
    print(f"[patch] {label}")
    return text.replace(old, new, 1)


def replace_regex(text: str, pattern: str, replacement: str, *, label: str) -> str:
    compiled = re.compile(pattern, re.MULTILINE)
    matches = list(compiled.finditer(text))
    if not matches:
        if replacement in text:
            print(f"[already] {label}")
            return text
        raise SystemExit(f"{label}: legacy shape not found")
    if len(matches) != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {len(matches)}")
    print(f"[patch] {label}")
    return compiled.sub(replacement, text, count=1)


def main() -> None:
    text = MAIN.read_text(encoding="utf-8")
    original = text

    # Only import modules this first integration slice uses. Other advanced
    # services remain independently tested until their shell hooks are added.
    anchor = "import 'security/secure_database.dart';\n"
    imports = (
        "import 'security/secure_database.dart';\n"
        "import 'chat/history_drawer.dart';\n"
        "import 'chat/scroll_follow_controller.dart';\n"
    )
    text = replace_exact(text, anchor, imports, label="chat subsystem imports")

    # Chat-first startup. First-run model/help onboarding will become the only
    # intentional startup gate; vault creation must not throw users into Settings.
    text = replace_regex(
        text,
        r"^\s*bool _openPostQuantumSetup = false;\n",
        "",
        label="remove Settings-first state flag",
    )
    text = replace_regex(
        text,
        r"\s*_openPostQuantumSetup = true;\n",
        "",
        label="remove Settings-first assignment",
    )
    text = replace_regex(
        text,
        r"return NazaStableHome\(\n\s*initialPanel:\n\s*_openPostQuantumSetup \? NazaPanel\.settings : NazaPanel\.chat,\n\s*\);",
        "return const NazaStableHome(initialPanel: NazaPanel.chat);",
        label="route unlocked app to Chat",
    )

    # Replace the raw controller with the reader-aware auto-follow controller.
    text = replace_exact(
        text,
        "  final ScrollController _scrollController = ScrollController();\n",
        "  final NazaChatScrollFollowController _scrollFollow =\n"
        "      NazaChatScrollFollowController();\n"
        "  ScrollController get _scrollController => _scrollFollow.controller;\n",
        label="reader-aware scroll controller",
    )
    text = replace_exact(
        text,
        "  DateTime _lastScrollRequestAt = DateTime.fromMillisecondsSinceEpoch(0);\n",
        "",
        label="remove legacy scroll throttle timestamp",
    )
    text = replace_exact(
        text,
        "    _scrollController.dispose();\n",
        "    _scrollFollow.dispose();\n",
        label="dispose scroll-follow controller",
    )

    legacy_scroll_method = """  void _scrollToBottom({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastScrollRequestAt) <
            const Duration(milliseconds: 240)) {
      return;
    }
    _lastScrollRequestAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
"""
    new_scroll_method = """  void _scrollToBottom({bool force = false}) {
    if (force) {
      _scrollFollow.armForConversationTail();
      return;
    }
    _scrollFollow.onStreamPaint();
  }
"""
    text = replace_exact(
        text,
        legacy_scroll_method,
        new_scroll_method,
        label="streaming reader scroll policy",
    )

    # A new request may intentionally arm the tail, but generation completion
    # must never re-arm it after the reader deliberately scrolled upward.
    text = replace_exact(
        text,
        "    _scrollToBottom(force: true);\n    if (focusComposerWhenDone) {\n",
        "    _scrollToBottom();\n    if (focusComposerWhenDone) {\n",
        label="preserve reader position after primary response",
    )
    text = replace_exact(
        text,
        "      _continuationText = finalText;\n    });\n    _scrollToBottom(force: true);\n  }\n\n  void _newThread() {\n",
        "      _continuationText = finalText;\n    });\n    _scrollToBottom();\n  }\n\n  void _newThread() {\n",
        label="preserve reader position after continuation",
    )

    # History gets a useful compact fallback immediately. A later integration
    # slice persists local-model-generated titles through encrypted metadata.
    legacy_title = """          final title = firstPrompt.isEmpty
              ? 'Untitled conversation'
              : firstPrompt.length <= 72
              ? firstPrompt
              : '${firstPrompt.substring(0, 72).trimRight()}…';
"""
    text = replace_exact(
        text,
        legacy_title,
        "          final title = NazaConversationTitlePolicy.fallback(firstPrompt);\n",
        label="compact conversation fallback titles",
    )

    if text == original:
        print("No main.dart changes required.")
        return

    MAIN.write_text(text, encoding="utf-8")
    print("main.dart integration patch complete")


if __name__ == "__main__":
    main()
