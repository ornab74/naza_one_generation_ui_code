"""Security tests for BarkPack checkpoint conversion."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import convert_bark_to_barkpack as converter  # noqa: E402


class _FakeTensor:
    def detach(self) -> "_FakeTensor":
        return self

    def cpu(self) -> "_FakeTensor":
        return self


class _RecordingTorch:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, object]]] = []

    def load(self, path: str, **kwargs: object) -> dict[str, _FakeTensor]:
        self.calls.append((path, kwargs))
        return {"weight": _FakeTensor()}


class BarkPackCheckpointSecurityTest(unittest.TestCase):
    def setUp(self) -> None:
        self._original_torch = converter.torch

    def tearDown(self) -> None:
        converter.torch = self._original_torch

    def test_pytorch_checkpoint_uses_restricted_weights_loader(self) -> None:
        fake_torch = _RecordingTorch()
        converter.torch = fake_torch

        state = converter.load_state(Path("untrusted.pt"))

        self.assertEqual(["weight"], list(state))
        self.assertEqual(1, len(fake_torch.calls))
        self.assertEqual(
            {"map_location": "cpu", "weights_only": True},
            fake_torch.calls[0][1],
        )

    def test_unsupported_safe_loader_fails_without_unsafe_retry(self) -> None:
        class _OldTorch:
            calls = 0

            @classmethod
            def load(cls, path: str, **kwargs: object) -> object:
                del path, kwargs
                cls.calls += 1
                raise TypeError("unexpected keyword argument 'weights_only'")

        converter.torch = _OldTorch()

        with self.assertRaisesRegex(RuntimeError, "cannot safely load"):
            converter.load_state(Path("untrusted.pth"))
        self.assertEqual(1, _OldTorch.calls)


if __name__ == "__main__":
    unittest.main()
