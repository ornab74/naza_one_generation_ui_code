#!/usr/bin/env python3
"""Stage BarkPack release assets and emit a SHA-256 release index."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def asset_record(source: Path, staged_name: str, logical_name: str) -> dict[str, object]:
    return {
        "name": logical_name,
        "asset": staged_name,
        "sha256": sha256(source),
        "size": source.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    pack = args.pack
    output = args.output
    manifest = pack / "manifest.json"
    if not manifest.exists():
        raise SystemExit(f"Missing BarkPack manifest: {manifest}")

    output.mkdir(parents=True, exist_ok=True)
    manifest_json = json.loads(manifest.read_text(encoding="utf-8"))
    if manifest_json.get("format") != "naza-barkpack-v1":
        raise SystemExit(f"Unsupported BarkPack format: {manifest_json.get('format')}")
    families = manifest_json.get("families", {})
    required_families = ("semantic", "coarse", "fine", "codec", "speaker")
    missing_families = [
        family for family in required_families if int(families.get(family, 0)) <= 0
    ]
    if missing_families:
        raise SystemExit(
            "BarkPack missing required families: " + ", ".join(missing_families)
        )

    staged_manifest = output / "naza-barkpack-manifest.json"
    shutil.copy2(manifest, staged_manifest)

    shard_records: list[dict[str, object]] = []
    for shard in sorted(pack.glob("tensors_*.bin")):
        staged_name = f"naza-barkpack-{shard.name}"
        shutil.copy2(shard, output / staged_name)
        shard_records.append(asset_record(shard, staged_name, shard.name))

    if not shard_records:
        raise SystemExit("BarkPack has no tensor shards.")

    index = {
        "format": "naza-barkpack-release-v1",
        "packFormat": "naza-barkpack-v1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "quant": manifest_json.get("quant", "unknown"),
        "tensorCount": manifest_json.get("tensorCount", 0),
        "families": manifest_json.get("families", {}),
        "qualityTier": manifest_json.get("qualityTier", "unknown"),
        "stages": manifest_json.get("stages", {}),
        "capabilities": manifest_json.get("capabilities", {}),
        "synthesizedSidecars": manifest_json.get("synthesizedSidecars", []),
        "pronunciationProfile": manifest_json.get("pronunciationProfile", {}),
        "manifest": asset_record(
            staged_manifest,
            "naza-barkpack-manifest.json",
            "manifest.json",
        ),
        "shards": shard_records,
    }

    index_path = output / "naza-barkpack-index.json"
    index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")
    (output / "naza-barkpack-index.sha256").write_text(
        f"{sha256(index_path)}  naza-barkpack-index.json\n",
        encoding="utf-8",
    )
    print(f"staged {1 + len(shard_records)} BarkPack assets in {output}")
    print(f"index sha256: {sha256(index_path)}")


if __name__ == "__main__":
    main()
