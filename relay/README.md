# Route Engine Luna Relay

The Android app intentionally does **not** contain an OpenAI API key. Run this relay on a trusted server (or on your laptop for local debug) and point the app at it.

```bash
python3 -m pip install -r relay/requirements.txt
python3 relay/manage_secrets.py
export ROUTE_ENGINE_RELAY_TOKEN="choose-a-random-token"
python3 server.py
```

For emulator testing use `http://10.0.2.2:8787`. For a physical USB-connected Android device, `adb reverse tcp:8787 tcp:8787` then use `http://127.0.0.1:8787`. Those cleartext URLs are accepted only in debug builds; release builds require HTTPS.

For HTTPS, set `ROUTE_ENGINE_TLS_CERT` and `ROUTE_ENGINE_TLS_KEY`.
