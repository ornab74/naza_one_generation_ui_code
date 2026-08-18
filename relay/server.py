#!/usr/bin/env python3
"""
Minimal Naza Route Engine relay.

Why a relay:
- OPENAI_API_KEY stays server-side.
- The phone sends its captured DoorDash screenshot, accessibility text, weather,
  and radar image to this endpoint.
- This server calls OpenAI Responses API with model gpt-5.6-luna and strict
  structured output, then returns only the compact decision JSON.

Secrets:
  Run `python3 relay/manage_secrets.py`; API keys are AES-GCM encrypted in
  relay/secrets.db. The database key is relay/.secrets.key.
  ROUTE_ENGINE_RELAY_TOKEN       optional bearer token required from phone
  ROUTE_ENGINE_HOST              default 0.0.0.0
  ROUTE_ENGINE_PORT              default 8787
  ROUTE_ENGINE_TLS_CERT          optional PEM cert
  ROUTE_ENGINE_TLS_KEY           optional PEM key

For Android emulator debug:
  python3 relay/server.py
  relay URL: http://10.0.2.2:8787
For a physical device over adb:
  adb reverse tcp:8787 tcp:8787
  relay URL: http://127.0.0.1:8787
Debug builds allow loopback cleartext. Release builds require HTTPS.
"""

from __future__ import annotations

import base64
import json
import os
import ssl
import sqlite3
import secrets
import hmac
import sys
from pathlib import Path
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from quantum_ranker import extract as quantum_features

SECRETS_DB = Path(__file__).with_name("secrets.db")
SECRETS_KEY = Path(__file__).with_name(".secrets.key")


class EncryptedSecrets:
    """Small AES-GCM encrypted SQLite keystore for relay credentials."""

    def __init__(self, database: Path = SECRETS_DB, key_path: Path = SECRETS_KEY):
        self.database = database
        self.key_path = key_path
        self.database.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not self.key_path.exists():
            self.key_path.write_bytes(secrets.token_bytes(32))
            os.chmod(self.key_path, 0o600)
        self.key = self.key_path.read_bytes()
        if len(self.key) != 32:
            raise RuntimeError(f"Invalid secrets key: {self.key_path}")
        with sqlite3.connect(self.database) as db:
            db.execute("CREATE TABLE IF NOT EXISTS secrets (name TEXT PRIMARY KEY, nonce BLOB NOT NULL, ciphertext BLOB NOT NULL)")
            db.commit()
        os.chmod(self.database, 0o600)

    def get(self, name: str, default: str = "") -> str:
        with sqlite3.connect(self.database) as db:
            row = db.execute("SELECT nonce, ciphertext FROM secrets WHERE name = ?", (name,)).fetchone()
        if not row:
            return default
        try:
            return AESGCM(self.key).decrypt(row[0], row[1], name.encode()).decode()
        except Exception as exc:
            raise RuntimeError(f"Could not decrypt secret {name}") from exc

    def set(self, name: str, value: str) -> None:
        nonce = secrets.token_bytes(12)
        ciphertext = AESGCM(self.key).encrypt(nonce, value.encode(), name.encode())
        with sqlite3.connect(self.database) as db:
            db.execute("INSERT INTO secrets(name, nonce, ciphertext) VALUES (?, ?, ?) ON CONFLICT(name) DO UPDATE SET nonce=excluded.nonce, ciphertext=excluded.ciphertext", (name, nonce, ciphertext))
            db.commit()


SECRET_STORE = EncryptedSecrets()
OPENAI_API_KEY = SECRET_STORE.get("openai_api_key")
META_MUSE_API_KEY = SECRET_STORE.get("meta_muse_api_key")
META_MUSE_BASE_URL = SECRET_STORE.get("meta_muse_base_url", "https://api.muse.meta.com/v1").rstrip("/")
META_MUSE_MODEL = SECRET_STORE.get("meta_muse_model", "muse")
XAI_API_KEY = SECRET_STORE.get("xai_api_key")
XAI_BASE_URL = SECRET_STORE.get("xai_base_url", "https://api.x.ai/v1").rstrip("/")
XAI_MODEL = SECRET_STORE.get("xai_model", "grok-4.5")
RELAY_TOKEN = os.environ.get("ROUTE_ENGINE_RELAY_TOKEN", "").strip()
HOST = os.environ.get("ROUTE_ENGINE_HOST", "127.0.0.1")
PORT = int(os.environ.get("ROUTE_ENGINE_PORT", "8787"))
TLS_CERT = os.environ.get("ROUTE_ENGINE_TLS_CERT", "").strip()
TLS_KEY = os.environ.get("ROUTE_ENGINE_TLS_KEY", "").strip()

MAX_BODY = 12 * 1024 * 1024

SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "verdict",
        "confidence",
        "score",
        "headline",
        "predicted_future",
        "primary_risk",
        "reasons",
        "expected_minutes",
        "expected_net_hourly",
        "weather_gate",
        "weather_reason",
        "weather_score",
        "spoken_summary",
        "navigation_query",
        "radar_summary",
        "model",
    ],
    "properties": {
        "verdict": {
            "type": "string",
            "enum": ["STRONG_TAKE", "TAKE", "BORDERLINE", "SKIP", "HARD_SKIP"],
        },
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "score": {"type": "number", "minimum": 0, "maximum": 1},
        "headline": {"type": "string", "maxLength": 90},
        "predicted_future": {"type": "string", "maxLength": 500},
        "primary_risk": {"type": "string", "maxLength": 120},
        "reasons": {
            "type": "array",
            "maxItems": 6,
            "items": {"type": "string", "maxLength": 120},
        },
        "expected_minutes": {"type": "number", "minimum": 0, "maximum": 300},
        "expected_net_hourly": {"type": "number", "minimum": 0, "maximum": 500},
        "weather_gate": {
            "type": "string",
            "enum": ["GO", "CAUTION", "NO_GO"],
        },
        "weather_reason": {"type": "string", "maxLength": 220},
        "weather_score": {"type": "number", "minimum": 0, "maximum": 1},
        "spoken_summary": {"type": "string", "maxLength": 300},
        "navigation_query": {"type": "string", "maxLength": 260},
        "radar_summary": {"type": "string", "maxLength": 240},
        "model": {"type": "string", "enum": ["gpt-5.6-luna"]},
    },
}


def _strip_large_images(payload: dict[str, Any]) -> dict[str, Any]:
    """Copy context but replace base64 blobs with size markers for text context."""
    capture = dict(payload.get("capture") or {})
    screenshot = capture.get("screenshot")
    if isinstance(screenshot, dict):
        data = screenshot.get("base64", "")
        capture["screenshot"] = {
            "present": bool(data),
            "encoded_bytes": len(data),
        }

    radar = payload.get("radar")
    radar_meta: Any = radar
    if isinstance(radar, dict):
        data = radar.get("base64", "")
        radar_meta = {
            "present": bool(data),
            "captured_at": radar.get("captured_at"),
            "encoded_bytes": len(data),
        }

    return {
        "mode": payload.get("mode"),
        "capture": capture,
        "location": payload.get("location"),
        "weather": payload.get("weather"),
        "radar": radar_meta,
        "rules": payload.get("rules"),
        "quantum_features": quantum_features(payload),
    }


def _data_url(image: dict[str, Any] | None) -> str | None:
    if not isinstance(image, dict):
        return None
    data = str(image.get("base64") or "")
    if not data:
        return None
    mime = str(image.get("mime_type") or "image/png")
    # Validate base64 before forwarding.
    base64.b64decode(data, validate=True)
    return f"data:{mime};base64,{data}"


def _openai_request(payload: dict[str, Any]) -> dict[str, Any]:
    if not OPENAI_API_KEY:
        raise RuntimeError("OpenAI API key is not configured in relay/secrets.db")

    model = str(payload.get("model") or "gpt-5.6-luna")
    if model != "gpt-5.6-luna":
        raise ValueError("This relay only permits model gpt-5.6-luna")

    context = _strip_large_images(payload)
    screenshot_url = _data_url((payload.get("capture") or {}).get("screenshot"))
    radar_url = _data_url(payload.get("radar"))

    system_text = (
        "You are Naza Route Engine, a motorcycle delivery offer decision system. "
        "Analyze only the evidence provided: DoorDash accessibility text/screenshot, "
        "current location, Open-Meteo weather, radar image, and user thresholds. "
        "Do not invent addresses, route distances, times, or merchant history. "
        "If destination information is not visible, keep navigation_query empty. "
        "Weather is an independent motorcycle safety gate: dangerous precipitation, "
        "poor visibility, strong gusts, or threatening radar can force NO_GO even when "
        "the economics are good. Return compact output for hands-free TTS. "
        "Do not claim literal certainty; confidence is a calibrated forecast score."
    )

    user_content: list[dict[str, Any]] = [
        {
            "type": "input_text",
            "text": (
                "Evaluate this live delivery state. User/context JSON:\n"
                + json.dumps(context, separators=(",", ":"), ensure_ascii=False)
            ),
        }
    ]
    if screenshot_url:
        user_content.extend(
            [
                {
                    "type": "input_text",
                    "text": "DoorDash screen capture corresponding to this state:",
                },
                {
                    "type": "input_image",
                    "image_url": screenshot_url,
                    "detail": "high",
                },
            ]
        )
    if radar_url:
        user_content.extend(
            [
                {
                    "type": "input_text",
                    "text": (
                        "Latest local weather radar frame. Evaluate precipitation/storm "
                        "risk for a motorcycle; radar is historical/current evidence, "
                        "not a guarantee of future motion."
                    ),
                },
                {
                    "type": "input_image",
                    "image_url": radar_url,
                    "detail": "high",
                },
            ]
        )

    request_body = {
        "model": "gpt-5.6-luna",
        "store": False,
        "reasoning": {"effort": "low"},
        "input": [
            {
                "role": "system",
                "content": [{"type": "input_text", "text": system_text}],
            },
            {
                "role": "user",
                "content": user_content,
            },
        ],
        "text": {
            "verbosity": "low",
            "format": {
                "type": "json_schema",
                "name": "route_engine_decision",
                "description": "Compact motorcycle delivery offer and weather decision.",
                "strict": True,
                "schema": SCHEMA,
            },
        },
    }

    req = urllib.request.Request(
        "https://api.openai.com/v1/responses",
        method="POST",
        data=json.dumps(request_body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=80) as response:
            response_json = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI HTTP {exc.code}: {body[:800]}") from exc

    text = response_json.get("output_text")
    if not text:
        for item in response_json.get("output", []):
            if item.get("type") != "message":
                continue
            for content in item.get("content", []):
                if content.get("type") == "output_text":
                    text = content.get("text")
                    break
            if text:
                break
    if not text:
        raise RuntimeError("OpenAI response did not contain output_text")

    result = json.loads(text)
    result["model"] = "gpt-5.6-luna"
    return result


def _compatible_request(payload: dict[str, Any], provider: str) -> dict[str, Any]:
    """Adapter for providers exposing an OpenAI-compatible chat endpoint.

    Provider credentials remain server-side. Meta Muse endpoint/model names are
    intentionally environment-configurable because access is deployment-specific.
    """
    if provider == "meta_muse":
        key, base, model = META_MUSE_API_KEY, META_MUSE_BASE_URL, str(payload.get("model") or META_MUSE_MODEL)
    elif provider == "grok":
        key, base, model = XAI_API_KEY, XAI_BASE_URL, str(payload.get("model") or XAI_MODEL)
    else:
        raise ValueError(f"Unsupported provider: {provider}")
    if not key:
        raise RuntimeError(f"{provider} API key is not configured on the relay")

    context = _strip_large_images(payload)
    system = (
        "Return only valid JSON matching this route decision contract: "
        + json.dumps(SCHEMA, separators=(",", ":"))
        + ". Analyze only the supplied delivery, weather, and safety evidence."
    )
    user: list[dict[str, Any]] = [{
        "type": "text",
        "text": "Evaluate this delivery state:\n" + json.dumps(context, separators=(",", ":")),
    }]
    screenshot = _data_url((payload.get("capture") or {}).get("screenshot"))
    if screenshot:
        user.append({"type": "image_url", "image_url": {"url": screenshot}})
    request_body = {
        "model": model,
        "temperature": 0,
        "response_format": {"type": "json_object"},
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
    }
    req = urllib.request.Request(
        f"{base}/chat/completions", method="POST",
        data=json.dumps(request_body).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=80) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{provider} HTTP {exc.code}: {body[:800]}") from exc
    text = result.get("choices", [{}])[0].get("message", {}).get("content")
    if isinstance(text, list):
        text = "".join(str(part.get("text", "")) for part in text if isinstance(part, dict))
    if not text:
        raise RuntimeError(f"{provider} response did not contain JSON content")
    output = json.loads(text)
    output["model"] = model
    return output


class Handler(BaseHTTPRequestHandler):
    server_version = "NazaRouteEngineRelay/0.4"

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._json(
                200,
                {
                    "ok": True,
                    "model": "gpt-5.6-luna",
                    "openai_key_configured": bool(OPENAI_API_KEY),
                },
            )
            return
        self._json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path != "/v1/route-engine/analyze":
            self._json(404, {"error": "not_found"})
            return

        if RELAY_TOKEN:
            expected = f"Bearer {RELAY_TOKEN}"
            supplied = self.headers.get("Authorization", "")
            if not hmac.compare_digest(supplied, expected):
                self._json(401, {"error": "unauthorized"})
                return

        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BODY:
            self._json(413, {"error": "body_size"})
            return

        try:
            body = self.rfile.read(length)
            payload = json.loads(body.decode("utf-8"))
            provider = str(payload.get("provider") or "openai")
            result = _openai_request(payload) if provider == "openai" else _compatible_request(payload, provider)
            self._json(200, result)
        except (ValueError, json.JSONDecodeError) as exc:
            self._json(400, {"error": "bad_request", "message": str(exc)})
        except Exception as exc:
            print(f"relay error: {exc}", file=sys.stderr)
            self._json(502, {"error": "upstream_error", "message": str(exc)[:500]})

    def log_message(self, fmt: str, *args: Any) -> None:
        # Avoid logging request bodies or bearer tokens.
        print("%s - %s" % (self.address_string(), fmt % args), file=sys.stderr)


def main() -> None:
    loopback_hosts = {"127.0.0.1", "::1", "localhost"}
    if HOST not in loopback_hosts and not RELAY_TOKEN:
        raise RuntimeError("A relay token is required for non-loopback listeners.")
    if HOST not in loopback_hosts and not (TLS_CERT and TLS_KEY):
        raise RuntimeError("TLS certificate and key are required for non-loopback listeners.")
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    scheme = "http"
    if TLS_CERT and TLS_KEY:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(TLS_CERT, TLS_KEY)
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
        scheme = "https"
    print(f"Naza Route Engine relay listening on {scheme}://{HOST}:{PORT}")
    print("Model: gpt-5.6-luna")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
