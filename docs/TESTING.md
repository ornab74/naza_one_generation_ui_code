# Testing

## 1. Static Flutter checks

```bash
flutter pub get
flutter analyze
flutter test
```

## 2. Debug install

```bash
flutter run
```

Confirm package:

```bash
adb shell pm list packages | grep com.qroadsan.routengine
```

## 3. Enable accessibility service

From Route Engine Settings, tap **Open Android accessibility settings** and enable the service.

Check:

```bash
adb shell settings get secure enabled_accessibility_services
```

The value should include:

```text
com.qroadsan.routengine/.DoorDashAccessibilityService
```

## 4. Relay

Run:

```bash
export OPENAI_API_KEY="..."
export ROUTE_ENGINE_RELAY_TOKEN="..."
python3 relay/server.py
```

Health:

```bash
curl http://127.0.0.1:8787/health
```

Physical USB device:

```bash
adb reverse tcp:8787 tcp:8787
```

Set relay URL in Route Engine debug build to `http://127.0.0.1:8787`.

## 5. Real DoorDash capture

Open DoorDash and wait for a real offer.

Expected:

1. Overlay appears only over DoorDash.
2. The offer state changes.
3. Service classifies `OFFER`.
4. Overlay briefly hides if needed for capture.
5. A new encrypted SQLite row is inserted.
6. Route Engine relay receives screenshot + accessibility text + weather + radar.
7. GPT-5.6-Luna returns the strict decision object.
8. Decision is AES-GCM encrypted into the same row.
9. Overlay becomes green/amber/red and shows a short WX state.
10. TTS speaks the decision.
11. Capture Vault shows the real screenshot after tapping the row.

## 6. Database-at-rest inspection

Without using the app's Keystore key, the stored BLOBs should not contain readable screenshot PNG or JSON payload data.

Database path on a debuggable build:

```bash
adb shell run-as com.qroadsan.routengine ls databases
adb exec-out run-as com.qroadsan.routengine cat databases/route_engine_capture_vault.db > /tmp/vault.db
strings /tmp/vault.db | head
```

The table will expose schema/minimal metadata, but sensitive payload/decision/screenshot content should remain ciphertext.

## 7. Secure-window behavior

If a target screen is protected by `FLAG_SECURE`, Android may reject screenshot capture. The expected behavior is:

- no attempt to bypass the protection,
- accessibility text/state may still be stored if available,
- the record notes screenshot failure/no screenshot.

## 8. Overlay

Verify the overlay:

- never receives touch focus;
- does not prevent DoorDash interaction;
- disappears when another app is foregrounded;
- shows only terse state: verdict, weather, chromatic dot.

## 9. Release AAB

```bash
flutter build appbundle --release
```

A release without a configured keystore falls back to debug signing for local testing. For store/release signing, use `android/key.properties` or `NAZA_ANDROID_*` environment variables.
