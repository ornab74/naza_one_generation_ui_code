"""Optional quantum-inspired feature extractor for route ranking.

This is an evidence feature, not a decision maker. PennyLane is optional so a
production relay remains available on small servers without a simulator.
"""

from __future__ import annotations

import hashlib
import math
from typing import Any


def _fallback(features: list[float]) -> dict[str, float | str]:
    # Deterministic correlated softmax ensemble. It gives the model a calibrated
    # ambiguity signal when a quantum simulator is not installed.
    logits = [
        1.4 * features[0] + .8 * features[1] - .7 * features[2],
        .9 * features[0] - .4 * features[1] + 1.1 * features[3],
        -.8 * features[0] + .7 * features[2] + .5 * features[3],
    ]
    exps = [math.exp(max(-20.0, min(20.0, x))) for x in logits]
    total = sum(exps)
    probs = [x / total for x in exps]
    entropy = -sum(p * math.log(max(p, 1e-12), 2) for p in probs) / math.log(3, 2)
    return {
        "take_probability": round(probs[0], 6),
        "risk_probability": round(probs[2], 6),
        "entropy": round(entropy, 6),
        "method": "deterministic_quantum_inspired_fallback",
    }


def extract(payload: dict[str, Any]) -> dict[str, float | str]:
    offer = payload.get("offer") or {}
    weather = payload.get("weather") or {}
    rules = payload.get("rules") or {}
    pay = float(offer.get("pay") or 0)
    miles = max(float(offer.get("displayed_miles") or 0), .1)
    gust = float(weather.get("wind_gust_kph") or 0)
    rain = float(weather.get("precipitation_mm") or 0)
    target = max(float(rules.get("target_hourly") or 22), 1)
    features = [
        max(0.0, min(1.0, pay / miles / 5.0)),
        max(0.0, min(1.0, pay / target)),
        max(0.0, min(1.0, gust / 80.0)),
        max(0.0, min(1.0, rain / 10.0)),
    ]
    try:
        import pennylane as qml
        from pennylane import numpy as np

        seed = int(hashlib.sha256(repr(features).encode()).hexdigest()[:8], 16)
        weights = np.array([(seed >> (i * 5) & 31) / 31 * math.pi for i in range(8)])
        dev = qml.device("default.qubit", wires=4, shots=None)

        @qml.qnode(dev)
        def circuit():
            for wire, value in enumerate(features):
                qml.RY(value * math.pi, wires=wire)
                qml.RZ(weights[wire], wires=wire)
            for wire in range(3):
                qml.CNOT(wires=[wire, wire + 1])
            for wire in range(4):
                qml.RY(weights[wire + 4], wires=wire)
            return [qml.expval(qml.PauliZ(wire)) for wire in range(4)]

        state = [float(value) for value in circuit()]
        take = max(0.0, min(1.0, (state[0] + state[1] + 2) / 4))
        risk = max(0.0, min(1.0, (2 - state[2] - state[3]) / 4))
        entropy = max(0.0, min(1.0, 1 - abs(take - risk)))
        return {"take_probability": round(take, 6), "risk_probability": round(risk, 6), "entropy": round(entropy, 6), "method": "pennylane_default_qubit_4wire_vqc"}
    except ImportError:
        return _fallback(features)

