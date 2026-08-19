"""Pure-NumPy personal delivery ranking circuit for Naza Route Engine.

This module produces an evidence feature vector for the relay. It is a compact
state-vector simulator, not a claim of physical quantum advantage. The four
qubits encode economics/opportunity, customer-fit, delivery-integrity/health,
and safety/uncertainty. User-specified merchant mechanics can hard-override the
static personal pickup prior before the live model evaluates weather and offer
context.
"""

from __future__ import annotations

import math
import re
from typing import Any

import numpy as np

I2 = np.eye(2, dtype=complex)
H = np.array([[1, 1], [1, -1]], dtype=complex) / math.sqrt(2)


def _ry(theta: float) -> np.ndarray:
    return np.array(
        [
            [math.cos(theta / 2), -math.sin(theta / 2)],
            [math.sin(theta / 2), math.cos(theta / 2)],
        ],
        dtype=complex,
    )


def _rz(theta: float) -> np.ndarray:
    return np.array(
        [
            [np.exp(-1j * theta / 2), 0],
            [0, np.exp(1j * theta / 2)],
        ],
        dtype=complex,
    )


def _kron4(gates: list[np.ndarray]) -> np.ndarray:
    out = gates[0]
    for gate in gates[1:]:
        out = np.kron(out, gate)
    return out


def _apply_one(state: np.ndarray, gate: np.ndarray, qubit: int) -> np.ndarray:
    gates = [I2, I2, I2, I2]
    gates[qubit] = gate
    return _kron4(gates) @ state


def _controlled_z(qa: int, qb: int) -> np.ndarray:
    matrix = np.eye(16, dtype=complex)
    for idx in range(16):
        bits = [(idx >> (3 - q)) & 1 for q in range(4)]
        if bits[qa] and bits[qb]:
            matrix[idx, idx] = -1
    return matrix


CZ01 = _controlled_z(0, 1)
CZ12 = _controlled_z(1, 2)
CZ23 = _controlled_z(2, 3)
CZ30 = _controlled_z(3, 0)
CZ02 = _controlled_z(0, 2)
CZ13 = _controlled_z(1, 3)


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def _merchant(payload: dict[str, Any]) -> str:
    capture = payload.get("capture") or {}
    accessibility = capture.get("accessibility") or {}
    return str(accessibility.get("merchant") or "").strip()


def _personal_policy(name: str) -> dict[str, Any]:
    n = name.lower()
    if re.search(r"\bmcdonald'?s\b", n):
        return {
            "category": "mcdonalds",
            "customer_quality": 0.88,
            "delivery_integrity": 0.90,
            "personal_health_fit": 0.58,
            "override": "GO",
            "reason": "Personal hard GO: reliable pickup pattern and useful late-night availability.",
        }
    if re.search(r"\b(family dollar|dollar general|dollar tree)\b", n):
        return {
            "category": "dollar_store",
            "customer_quality": 0.06,
            "delivery_integrity": 0.35,
            "personal_health_fit": 0.20,
            "override": "NO-GO",
            "reason": "Personal hard NO-GO: dollar-store pickup/customer-fit rule.",
        }
    pizza_patterns = [
        r"\bpizza\b",
        r"\bpizzeria\b",
        r"\bdomino'?s\b",
        r"\bpapa john'?s\b",
        r"\bmarco'?s\b",
        r"\bmellow mushroom\b",
        r"\bhungry howie'?s\b",
        r"\bjet'?s pizza\b",
        r"\blittle caesars\b",
        r"\bpizza hut\b",
        r"\bcrust and craft\b",
        r"\blocal crust\b",
    ]
    if any(re.search(pattern, n) for pattern in pizza_patterns):
        return {
            "category": "pizza",
            "customer_quality": 0.30,
            "delivery_integrity": 0.18,
            "personal_health_fit": 0.16,
            "override": "NO-GO",
            "reason": "Personal hard NO-GO: pizza heat/spoilage pressure and historically weaker customer-fit.",
        }
    return {
        "category": "general",
        "customer_quality": 0.62,
        "delivery_integrity": 0.70,
        "personal_health_fit": 0.70,
        "override": "",
        "reason": "No personal merchant override; use live offer and evidence score.",
    }


def _simulate(
    opportunity: float,
    customer_quality: float,
    delivery_integrity: float,
    health_fit: float,
    risk: float,
    uncertainty: float,
) -> tuple[float, float]:
    encoded = [
        _clamp(opportunity),
        _clamp(customer_quality),
        _clamp(0.62 * delivery_integrity + 0.38 * health_fit),
        _clamp(1.0 - 0.58 * risk - 0.42 * uncertainty),
    ]

    state = np.zeros(16, dtype=complex)
    state[0] = 1.0
    for q, value in enumerate(encoded):
        state = _apply_one(state, _ry(math.pi * value), q)
        state = _apply_one(state, _rz(math.pi * (value - 0.5) * (q + 1) / 2), q)
    for gate in (CZ01, CZ12, CZ23, CZ30):
        state = gate @ state
    state = _apply_one(state, H, 0)
    state = _apply_one(state, _ry(math.pi / 5 * (encoded[1] - encoded[3])), 1)
    state = _apply_one(state, _ry(math.pi / 4 * (encoded[2] - encoded[0])), 2)
    state = _apply_one(state, H, 3)
    state = CZ02 @ state
    state = CZ13 @ state

    probs = np.abs(state) ** 2
    probs /= probs.sum()

    measured = []
    for q in range(4):
        measured.append(
            sum(float(p) * ((idx >> (3 - q)) & 1) for idx, p in enumerate(probs))
        )
    measured_score = 0.34 * measured[0] + 0.29 * measured[1] + 0.23 * measured[2] + 0.14 * measured[3]
    direct_score = 0.34 * encoded[0] + 0.29 * encoded[1] + 0.23 * encoded[2] + 0.14 * encoded[3]
    score = _clamp(0.52 * direct_score + 0.48 * measured_score)
    entropy = -sum(float(p) * math.log2(float(p)) for p in probs if p > 1e-15) / 4.0
    return score, _clamp(entropy)


def extract(payload: dict[str, Any]) -> dict[str, float | str]:
    capture = payload.get("capture") or {}
    accessibility = capture.get("accessibility") or {}
    rules = payload.get("rules") or {}
    weather = payload.get("weather") or {}

    pay = float(accessibility.get("offer_pay") or 0.0)
    miles = max(float(accessibility.get("displayed_miles") or 0.0), 0.1)
    target = max(float(rules.get("target_hourly") or 22.0), 1.0)
    precipitation = float(weather.get("precipitation") or weather.get("rain") or 0.0)
    gust = float(weather.get("wind_gusts_10m") or 0.0)

    dollars_per_mile = pay / miles
    opportunity = _clamp(0.58 * (dollars_per_mile / 5.0) + 0.42 * (pay / target))
    risk = _clamp(0.55 * (gust / 80.0) + 0.45 * (precipitation / 10.0))
    uncertainty = 0.22 if pay > 0 and miles > 0 else 0.60

    policy = _personal_policy(_merchant(payload))
    score, entropy = _simulate(
        opportunity,
        float(policy["customer_quality"]),
        float(policy["delivery_integrity"]),
        float(policy["personal_health_fit"]),
        risk,
        uncertainty,
    )

    override = str(policy["override"])
    if override == "NO-GO":
        score = min(score, 0.18)
    elif override == "GO":
        score = max(score, 0.82)

    return {
        "take_probability": round(score, 6),
        "risk_probability": round(1.0 - score, 6),
        "entropy": round(entropy, 6),
        "method": "numpy_statevector_q4_personal_customer_fit_v2",
        "merchant_category": str(policy["category"]),
        "personal_override": override,
        "personal_reason": str(policy["reason"]),
        "customer_quality_prior": round(float(policy["customer_quality"]), 6),
        "delivery_integrity_prior": round(float(policy["delivery_integrity"]), 6),
        "personal_health_fit": round(float(policy["personal_health_fit"]), 6),
    }
