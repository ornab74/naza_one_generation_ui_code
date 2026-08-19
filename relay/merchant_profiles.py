"""Personal merchant seed profiles for Naza Route Engine.

The store supports multiple branches with the same merchant name. When the
geocoded seed exists, live phone GPS is used to select the nearest matching
branch instead of collapsing every chain to its first occurrence.
"""

from __future__ import annotations

import csv
import difflib
import math
import re
import unicodedata
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).with_name("data")
GEOCODED_PROFILE_PATH = DATA_DIR / "woodruff_superlist_geocoded.csv"
SEED_PROFILE_PATH = DATA_DIR / "woodruff_superlist_seed.csv"
LEGACY_PROFILE_PATH = DATA_DIR / "woodruff_personal_profiles.csv"


def profile_path() -> Path:
    for path in (GEOCODED_PROFILE_PATH, SEED_PROFILE_PATH, LEGACY_PROFILE_PATH):
        if path.exists():
            return path
    return GEOCODED_PROFILE_PATH


def normalize_name(value: str) -> str:
    text = unicodedata.normalize("NFKD", value or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.lower().replace("&", " and ")
    text = re.sub(r"['’`]", "", text)
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


def _float(value: Any, default: float | None = 0.0) -> float | None:
    try:
        if value in (None, ""):
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6371.0088
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(min(1.0, math.sqrt(a)))


@lru_cache(maxsize=1)
def _profiles() -> tuple[dict[str, list[dict[str, Any]]], list[str]]:
    by_name: dict[str, list[dict[str, Any]]] = {}
    names: list[str] = []
    path = profile_path()
    if not path.exists():
        return by_name, names

    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            normalized = normalize_name(row.get("name", ""))
            if not normalized:
                continue
            profile = {
                "record_index": int(row.get("record_index") or 0),
                "name": row.get("name", ""),
                "normalized_name": normalized,
                "address_full": row.get("address_full", ""),
                "address_city": row.get("address_city", ""),
                "address_postal_code": row.get("address_postal_code", ""),
                "latitude": _float(row.get("latitude"), None),
                "longitude": _float(row.get("longitude"), None),
                "coordinate_source": row.get("coordinate_source", ""),
                "coordinate_precision": row.get("coordinate_precision", ""),
                "coordinate_confidence": _float(row.get("coordinate_confidence"), 0.0),
                "category": row.get("personal_category", "general"),
                "customer_quality_prior": _float(row.get("customer_quality_prior"), 0.62),
                "delivery_integrity_prior": _float(row.get("delivery_integrity_prior"), 0.70),
                "personal_health_fit": _float(row.get("personal_health_fit"), 0.70),
                "seed_go_probability": _float(row.get("q4_go_probability"), 0.50),
                "seed_entropy": _float(row.get("q4_entropy"), 1.0),
                "policy_override": row.get("personal_policy_override", ""),
                "seed_decision": row.get("go_no_go", ""),
            }
            if normalized not in by_name:
                by_name[normalized] = []
                names.append(normalized)
            by_name[normalized].append(profile)
    return by_name, names


def _choose_branch(
    candidates: list[dict[str, Any]],
    latitude: float | None,
    longitude: float | None,
) -> tuple[dict[str, Any], str, float, float | None]:
    if len(candidates) == 1:
        return candidates[0], "unique_name", 1.0, None

    if latitude is not None and longitude is not None:
        located = []
        for profile in candidates:
            plat = profile.get("latitude")
            plon = profile.get("longitude")
            if plat is None or plon is None:
                continue
            located.append((_haversine_km(latitude, longitude, float(plat), float(plon)), profile))
        if located:
            located.sort(key=lambda item: item[0])
            distance, profile = located[0]
            confidence = max(0.72, min(0.99, 0.99 - distance / 100.0))
            return profile, "nearest_geocoded_branch", confidence, distance

    return candidates[0], "ambiguous_chain_name", 0.72, None


def lookup(
    merchant_name: str,
    latitude: float | None = None,
    longitude: float | None = None,
) -> dict[str, Any] | None:
    normalized = normalize_name(merchant_name)
    if not normalized:
        return None

    by_name, names = _profiles()
    exact = by_name.get(normalized)
    if exact:
        profile, branch_type, branch_confidence, distance = _choose_branch(exact, latitude, longitude)
        return {
            **profile,
            "match_type": "exact",
            "match_confidence": round(branch_confidence, 6),
            "branch_match_type": branch_type,
            "branch_distance_km": None if distance is None else round(distance, 4),
        }

    containment = [
        name for name in names
        if min(len(name), len(normalized)) >= 8 and (name in normalized or normalized in name)
    ]
    if len(containment) == 1:
        candidates = by_name[containment[0]]
        lexical = min(len(containment[0]), len(normalized)) / max(len(containment[0]), len(normalized))
        if lexical >= 0.72:
            profile, branch_type, branch_confidence, distance = _choose_branch(candidates, latitude, longitude)
            return {
                **profile,
                "match_type": "containment",
                "match_confidence": round(lexical * branch_confidence, 6),
                "branch_match_type": branch_type,
                "branch_distance_km": None if distance is None else round(distance, 4),
            }

    close = difflib.get_close_matches(normalized, names, n=2, cutoff=0.90)
    if len(close) == 1:
        lexical = difflib.SequenceMatcher(None, normalized, close[0]).ratio()
        profile, branch_type, branch_confidence, distance = _choose_branch(by_name[close[0]], latitude, longitude)
        return {
            **profile,
            "match_type": "fuzzy",
            "match_confidence": round(lexical * branch_confidence, 6),
            "branch_match_type": branch_type,
            "branch_distance_km": None if distance is None else round(distance, 4),
        }

    return None


def stats() -> dict[str, int | str]:
    by_name, _ = _profiles()
    return {
        "seed_profiles": sum(len(values) for values in by_name.values()),
        "unique_normalized_names": len(by_name),
        "profile_path": str(profile_path()),
    }
