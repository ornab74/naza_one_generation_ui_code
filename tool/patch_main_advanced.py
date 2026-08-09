#!/usr/bin/env python3
"""Guarded, idempotent integration patches for NAZA One's large main.dart.

This script intentionally refuses to write if an expected legacy shape is
missing or duplicated. It lets CI make surgical edits to the monolithic app
shell without replacing the entire ~800 KB file through an API call.
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

    # Make the new subsystems available to the app shell. Keeping them as
    # separate modules preserves testability and keeps main.dart from growing.
    anchor = "import 'security/secure_database.dart';\n"
    imports = (
        "import 'security/secure_database.dart';\n"
        "import 'chat/history_drawer.dart';\n"
        "import 'chat/scroll_follow_controller.dart';\n"
        "import 'memory/local_memory_service.dart';\n"
        "import 'onboarding/first_run_onboarding.dart';\n"
    )
    text = replace_exact(text, anchor, imports, label="advanced subsystem imports")

    # The vault used to force a newly-created user into Settings. That made the
    # first screen feel like configuration instead of a chat product. The new
    # onboarding gate owns first-run model/help flow; unlocked app navigation
    # should therefore default to Chat.
    text = replace_regex(
        text,
        r"^\s*bool _openPostQuantumSetup = false;\n",
        "",
        label="remove Settings-first state flag",
    )
    text = replace_regex(
        text,
        r"(?P<indent>\s*)_openPostQuantumSetup = true;\n",
        "",
        label="remove Settings-first assignment",
    )
    text = replace_regex(
        text,
        r"return NazaStableHome\(\n\s*initialPanel:\n\s*_openPostQuantumSetup \? NazaPanel\.settings : NazaPanel\.chat,\n\s*\);",
        "return const NazaStableHome(initialPanel: NazaPanel.chat);",
        label="route unlocked app to Chat",
    )

    if text == original:
        print("No main.dart changes required.")
        return

    MAIN.write_text(text, encoding="utf-8")
    print("main.dart integration patch complete")


if __name__ == "__main__":
    main()
