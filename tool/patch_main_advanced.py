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
    compiled = re.compile(pattern, re.MULTILINE | re.DOTALL)
    matches = list(compiled.finditer(text))
    if not matches:
        if replacement in text:
            print(f"[already] {label}")
            return text
        raise SystemExit(f"{label}: legacy shape not found")
    if len(matches) != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {len(matches)}")
    print(f"[patch] {label}")
    return compiled.sub(lambda _: replacement, text, count=1)


def main() -> None:
    text = MAIN.read_text(encoding="utf-8")
    original = text

    anchor = "import 'security/secure_database.dart';\n"
    imports = (
        "import 'security/secure_database.dart';\n"
        "import 'chat/history_drawer.dart';\n"
        "import 'chat/scroll_follow_controller.dart';\n"
        "import 'model/model_distribution_manifest.dart';\n"
        "import 'model/multiplane_model_downloader.dart';\n"
    )
    text = replace_exact(text, anchor, imports, label="advanced subsystem imports")

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

    # Replace the single-host sequential model GET with the bounded multi-plane
    # downloader. NazaSecureModelStore retains its existing target path,
    # attestation checks and final immutable SHA-256 trust boundary.
    downloader_method = r'''  static Future<void> _downloadVerified(
    File target, {
    void Function(int progress, String phase)? onProgress,
  }) async {
    final downloader = NazaMultiplaneModelDownloader(
      manifest: NazaModelDistributionManifest.gemma4E2b,
    );
    try {
      await downloader.download(
        target: target,
        onProgress: (snapshot) {
          final mapped = switch (snapshot.stage) {
            NazaDownloadStage.probing => 1,
            NazaDownloadStage.allocating => 2,
            NazaDownloadStage.downloading =>
              (2 + snapshot.fraction * 92).round().clamp(2, 94),
            NazaDownloadStage.verifying => 96,
            NazaDownloadStage.complete => 99,
          };
          final mib = snapshot.bytesPerSecond / (1024 * 1024);
          final provider = snapshot.fastestProvider;
          final phase = switch (snapshot.stage) {
            NazaDownloadStage.probing => 'probing redundant model providers',
            NazaDownloadStage.allocating => 'preparing resumable model download',
            NazaDownloadStage.downloading =>
              'multi-provider download ${mib.toStringAsFixed(1)} MiB/s'
                  '${provider == null ? '' : ' · $provider'}'
                  ' · ${snapshot.activeTransfers} streams',
            NazaDownloadStage.verifying => 'validating immutable model SHA-256',
            NazaDownloadStage.complete => 'verified multi-provider model cached',
          };
          onProgress?.call(mapped, phase);
        },
      );
    } finally {
      await downloader.close();
    }
  }

  static Future<HttpClientResponse> _openSecureGet'''
    text = replace_regex(
        text,
        r"  static Future<void> _downloadVerified\(\n    File target, \{\n    void Function\(int progress, String phase\)\? onProgress,\n  \}\) async \{.*?\n  \}\n\n  static Future<HttpClientResponse> _openSecureGet",
        downloader_method,
        label="multi-plane verified model transport",
    )

    if text == original:
        print("No main.dart changes required.")
        return

    MAIN.write_text(text, encoding="utf-8")
    print("main.dart integration patch complete")


if __name__ == "__main__":
    main()
