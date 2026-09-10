#!/usr/bin/env python3
"""Guarded, idempotent chat UI polish for the single-file application.

The application currently contains duplicated SOURCE SECTION blocks. This tool
therefore updates every identical copy of each known chat UI shape, while still
failing closed when a legacy shape is missing unexpectedly.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "lib" / "main.dart"


def replace_all(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if count == 0:
        if new in text:
            print(f"[already] {label}")
            return text
        raise SystemExit(f"{label}: expected UI shape was not found")
    if count > 2:
        raise SystemExit(f"{label}: refusing unexpected {count} matches")
    print(f"[patch] {label} ({count} copy/copies)")
    return text.replace(old, new)


def main() -> None:
    text = MAIN.read_text(encoding="utf-8")
    original = text

    # 1. Streaming smoothness: keep nearby bubbles warm and give the list a
    # little more breathing room without adding animations or blur work.
    text = replace_all(
        text,
        """          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          addRepaintBoundaries: true,
          itemCount: _messages.length + 1,""",
        """          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          cacheExtent: 720,
          addRepaintBoundaries: true,
          itemCount: _messages.length + 1,""",
        label="chat list cache and spacing",
    )

    # 2. Top-bar calmness: do not run a perpetual CustomPainter animation at
    # the same time the active answer is repainting token-by-token.
    text = replace_all(
        text,
        "            if (sending && !narrow) const _ModelWorkingBeacon(),",
        """            if (sending && !narrow)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: NazaPalette.shellSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NazaPalette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: NazaPalette.mintSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      stopping ? 'Stopping' : 'Writing',
                      style: TextStyle(
                        color: NazaPalette.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: NazaFonts.display,
                      ),
                    ),
                  ],
                ),
              ),""",
        label="static model-writing status",
    )

    # 3. Active-response readability: use a wider reading measure and a more
    # definite surface while a response is still streaming.
    text = replace_all(
        text,
        "    final maxWidth = width >= 760 ? 640.0 : width * 0.84;",
        """    final maxWidth = width >= 1200
        ? 760.0
        : width >= 760
        ? 680.0
        : width * 0.92;""",
        label="responsive message reading width",
    )
    text = replace_all(
        text,
        "            color: isUser ? NazaPalette.userBubble : NazaPalette.panelSoft,",
        """            color: isUser
                ? NazaPalette.userBubble
                : message.isWorking
                ? NazaPalette.panel
                : NazaPalette.panelSoft,""",
        label="active response surface",
    )
    text = replace_all(
        text,
        """            border: Border.all(
              color: message.isWorking
                  ? NazaPalette.borderStrong
                  : isUser
                  ? NazaPalette.borderStrong
                  : NazaPalette.border,
            ),""",
        """            border: Border.all(
              color: message.isWorking
                  ? NazaPalette.borderStrong
                  : isUser
                  ? NazaPalette.borderStrong
                  : NazaPalette.border,
              width: message.isWorking ? 1.25 : 1,
            ),""",
        label="active response border",
    )

    # 4. Composer ergonomics: reclaim horizontal room on phone and compact
    # desktop widths while retaining a 52px touch target.
    text = replace_all(
        text,
        "                minimumSize: const Size(102, 52),",
        "                minimumSize: const Size(88, 52),",
        label="compact composer action",
    )

    # 5. Scroll-follow behavior: follow a reader who is still near the tail and
    # make streaming corrections smaller/more frequent instead of 4Hz jumps.
    text = replace_all(
        text,
        "    _followOutput = distance <= 72;",
        "    _followOutput = distance <= 128;",
        label="conversation-tail follow threshold",
    )
    text = replace_all(
        text,
        """    if (!force &&
        now.difference(_lastScrollRequestAt) <
            const Duration(milliseconds: 240)) {
      return;
    }""",
        """    if (!force &&
        now.difference(_lastScrollRequestAt) <
            const Duration(milliseconds: 120)) {
      return;
    }""",
        label="stream scroll cadence",
    )

    if text == original:
        print("Chat UI is already current.")
        return
    MAIN.write_text(text, encoding="utf-8")
    print("Chat UI patch complete.")


if __name__ == "__main__":
    main()
