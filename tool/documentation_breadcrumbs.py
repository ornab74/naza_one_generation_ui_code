#!/usr/bin/env python3
"""Apply deterministic, visible documentation breadcrumbs to maintained files.

This is a repository-maintenance tool, not part of the application runtime.
It intentionally skips generated, ephemeral, binary, and platform-resource files.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKER = "LLM-CONTEXT:BEGIN"

SKIP_PARTS = {
    ".git", ".dart_tool", "build", "ephemeral", ".idea", "naza_one_asset_pack"
}
SKIP_NAMES = {
    "pubspec.lock", ".flutter-plugins-dependencies", "GeneratedPluginRegistrant.java",
    "GeneratedPluginRegistrant.h", "GeneratedPluginRegistrant.m",
    "generated_plugin_registrant.cc", "generated_plugin_registrant.h",
    "generated_plugins.cmake", "GeneratedPluginRegistrant.swift",
}

COMMENTABLE = {
    ".dart": ("//", None), ".py": ("#", None), ".ps1": ("#", None),
    ".sh": ("#", None), ".cmake": ("#", None), ".yaml": ("#", None),
    ".yml": ("#", None), ".properties": ("#", None), ".xcconfig": ("//", None),
    ".swift": ("//", None), ".kt": ("//", None), ".kts": ("//", None),
    ".java": ("//", None), ".cc": ("//", None), ".cpp": ("//", None),
    ".h": ("//", None),
}

# These files carried intentional working-tree behavior before the repository-
# wide documentation pass. Never reconstruct them from HEAD during diff cleanup.
PRESERVE_WORKTREE = {
    "lib/app.dart", "lib/naza_exploration_hub.dart",
    "lib/naza_healthdash_monolith.dart",
    "lib/navigation/unified_feature_drawer.dart",
    "test/exploration_hub_test.dart", "test/unified_feature_drawer_test.dart",
}


def domain_for(path: Path) -> str:
    p = path.as_posix().lower()
    if "/security/" in p or "security" in path.name.lower(): return "security"
    if "/model/" in p or "model" in path.name.lower(): return "model-runtime"
    if "/food/" in p: return "food-vision"
    if "/chat/" in p: return "conversation"
    if "/navigation/" in p: return "navigation"
    if "/onboarding/" in p: return "onboarding"
    if "/memory/" in p: return "local-memory"
    if "/theme/" in p: return "appearance"
    if "/settings/" in p: return "settings"
    if "/scanner/" in p: return "scanner"
    if p.startswith("test/") or p.startswith("test_archive/"): return "verification"
    if p.startswith("android/") or p.startswith("ios/") or p.startswith("linux/") or p.startswith("macos/"): return "platform-shell"
    if p.startswith("tool/") or p.startswith("tools/"): return "developer-tooling"
    if p.startswith("native/"): return "native-boundary"
    return "application-core"


def responsibility(path: Path, domain: str) -> str:
    stem = path.stem.replace("_", " ").replace("-", " ")
    return f"Owns {stem} behavior within the {domain} subsystem."


def invariant_for(domain: str) -> str:
    return {
        "security": "Fail closed on malformed, unauthenticated, stale, or unavailable security state.",
        "model-runtime": "Treat model bytes, mirrors, profiles, and runtime state as untrusted until policy validation succeeds.",
        "navigation": "Resolve navigation only through the closed in-process destination registry; persisted IDs never carry callbacks.",
        "local-memory": "Keep user memory local, bounded, explicitly scoped, and unavailable while encrypted storage is locked.",
        "food-vision": "Bound image/data inputs and distinguish visible evidence from model inference.",
        "scanner": "Never fabricate a safety classification when parsing, generation, or evidence is incomplete.",
        "conversation": "Preserve turn identity, cancellation semantics, and encrypted-history ownership across async work.",
        "onboarding": "Complete vault establishment and artifact verification before entering private application surfaces.",
        "native-boundary": "Validate lengths, ownership, lifecycle, and ABI assumptions before crossing FFI boundaries.",
        "verification": "Tests encode behavioral and security contracts; update assertions only with an intentional contract change.",
        "platform-shell": "Keep platform permissions and generated integration boundaries minimal and reproducible.",
    }.get(domain, "Preserve local-first privacy, bounded resource use, and explicit error handling.")


def header(path: Path, prefix: str) -> str:
    rel = path.relative_to(ROOT).as_posix()
    domain = domain_for(path.relative_to(ROOT))
    lines = [
        f"{prefix} {MARKER}",
        f"{prefix} FILE: {rel}",
        f"{prefix} ROLE: {responsibility(path, domain)}",
        f"{prefix} DOMAIN: {domain}",
        f"{prefix} SECURITY-INVARIANT: {invariant_for(domain)}",
        f"{prefix} CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.",
        f"{prefix} DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.",
        f"{prefix} LLM-CONTEXT:END",
        "",
    ]
    return "\n".join(lines)


def should_comment(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    if any(part in SKIP_PARTS for part in rel.parts): return False
    if path.name in SKIP_NAMES: return False
    if path.suffix not in COMMENTABLE: return False
    if "generated" in path.name.lower(): return False
    return True


def insert_header(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if MARKER in text: return False
    prefix, _ = COMMENTABLE[path.suffix]
    doc = header(path, prefix)
    if text.startswith("#!"):
        first, rest = text.split("\n", 1)
        updated = f"{first}\n{doc}{rest}"
    else:
        updated = doc + text
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minimize-tracked-diff", action="store_true")
    args = parser.parse_args()
    if args.minimize_tracked_diff:
        minimized = 0
        for path in sorted(ROOT.rglob("*")):
            if not path.is_file() or not should_comment(path): continue
            rel = path.relative_to(ROOT).as_posix()
            if rel in PRESERVE_WORKTREE: continue
            baseline = subprocess.run(
                ["git", "show", f"HEAD:{rel}"], cwd=ROOT,
                check=False, capture_output=True,
            )
            if baseline.returncode != 0: continue
            text = baseline.stdout.decode("utf-8")
            prefix, _ = COMMENTABLE[path.suffix]
            doc = header(path, prefix)
            if text.startswith("#!"):
                first, rest = text.split("\n", 1)
                text = f"{first}\n{doc}{rest}"
            else:
                text = doc + text
            path.write_text(text, encoding="utf-8")
            minimized += 1
        print(f"Minimized {minimized} tracked files to baseline plus breadcrumbs.")
        return
    changed = []
    for path in sorted(ROOT.rglob("*")):
        if path.is_file() and should_comment(path):
            try:
                if insert_header(path): changed.append(path.relative_to(ROOT).as_posix())
            except UnicodeDecodeError:
                continue
    print(f"Added explicit LLM breadcrumbs to {len(changed)} maintained files.")


if __name__ == "__main__":
    main()
