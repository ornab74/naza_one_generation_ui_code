# Naza Route Engine

Android-first Flutter/Dart delivery foresight prototype for hands-free motorcycle use.

Package/application ID: **`com.qroadsan.routengine`**

## What is implemented

- **Real DoorDash state observation (Android accessibility service)**
  - scoped to `com.doordash.driverapp`
  - listens for window/content/text state changes
  - classifies only likely offer screens or active-order state changes
  - hashes the visible state and debounces duplicates
- **Real screen capture on qualifying DoorDash changes**
  - Android AccessibilityService screenshot API on Android 11+
  - Android 14+ uses window-specific screenshot capture so the Naza overlay is not part of the image
  - Android 11–13 temporarily hides the overlay before capture
  - if Android reports a secure window, capture fails closed; the app does not bypass `FLAG_SECURE`
- **Encrypted local capture vault**
  - app-private SQLite via `SQLiteOpenHelper`
  - capture JSON, screenshots, and Luna decisions are AES-256-GCM encrypted per record
  - AES key is generated and held by **Android Keystore**
  - per-record AAD binds ciphertext to timestamp, state kind, hashed fingerprint, and slot
  - relay bearer token is also AES-GCM protected before SharedPreferences storage
  - vault automatically keeps the newest 120 records
- **Small DoorDash-only heads-up overlay**
  - `TYPE_ACCESSIBILITY_OVERLAY`, created by the accessibility service
  - non-focusable and non-touchable
  - chromatic verdict dot + compact Naza verdict + `WX GO/CAUTION/NO_GO`
  - shown only while DoorDash is the foreground accessibility package
- **Online-only analysis**
  - current conditions from Open-Meteo
  - latest RainViewer radar frame for local/personal testing
  - DoorDash screenshot + accessibility text + weather + radar are sent to your trusted relay
  - relay calls **`gpt-5.6-luna`** with image input and strict structured output
- **Hands-free output**
  - Android TTS announces the Luna result
  - the overlay turns green / amber / red
  - if Luna returns a trustworthy navigation query and the verdict is TAKE with no weather NO-GO, Google Maps navigation can launch automatically
- **Flutter UI**
  - Foresight dashboard
  - manual test lab (no bundled demo order)
  - weather/radar view
  - real encrypted capture vault with decrypted screenshot viewing
  - settings for Luna relay, economic thresholds, weather gates, TTS, navigation, radar, monitor, and overlay
  - animated chromatic future ribbon

## Important boundary

This build **does not secretly press DoorDash Accept or Decline**. It observes a user-authorized accessibility surface, captures qualifying state changes, analyzes them, speaks a verdict, updates the overlay, and can launch navigation. It does not bypass Android secure-window screenshot controls.

## Requirements

- Flutter stable compatible with Dart `^3.9.0` (the repository was prepared around Flutter 3.44-era Android templates)
- Android 11 / API 30 or newer
- Java 17
- Android SDK
- An OpenAI API key **only on the relay**, never inside the APK
- For live radar: RainViewer personal/educational API availability is appropriate for this local test build; replace it for a commercial deployment if required by provider terms

## Run locally

```bash
flutter pub get
flutter run
```

On first launch:

1. Open **Settings**.
2. Set the Naza relay URL and optional bearer token.
3. Grant location permission when requested.
4. Tap **Open Android accessibility settings**.
5. Enable **Naza Route Engine DoorDash Monitor**.
6. Open DoorDash.
7. When an offer/state change matches the classifier, Route Engine captures it, encrypts it into the vault, calls Luna, updates the overlay, and speaks the result.

No fake/demo order or screenshot is bundled.

## Local Luna relay

The relay is included in `relay/server.py` and uses only the Python standard library.

```bash
export OPENAI_API_KEY="YOUR_KEY"
export ROUTE_ENGINE_RELAY_TOKEN="a-long-random-token"
python3 relay/server.py
```

### Emulator

Use:

```text
http://10.0.2.2:8787
```

### Physical USB device

```bash
adb reverse tcp:8787 tcp:8787
```

Then set:

```text
http://127.0.0.1:8787
```

Loopback cleartext is accepted only by Android **debug** builds. Release builds require HTTPS.

For an HTTPS relay:

```bash
export ROUTE_ENGINE_TLS_CERT=/path/to/cert.pem
export ROUTE_ENGINE_TLS_KEY=/path/to/key.pem
python3 relay/server.py
```

## Signed release build

The Android Gradle config supports either a local `android/key.properties` file or the same environment names used by the Naza repository:

```text
NAZA_ANDROID_KEYSTORE_PATH
NAZA_ANDROID_KEYSTORE_PASSWORD
NAZA_ANDROID_KEY_ALIAS
NAZA_ANDROID_KEY_PASSWORD
```

The included GitHub Action maps these from repository secrets:

```text
ANDROID_KEYSTORE_B64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Build:

```bash
flutter build appbundle --release
```

## Capture classification

The accessibility service is intentionally narrow.

A state is `OFFER` when the visible accessibility tree includes:

- a dollar amount,
- mileage,
- and an Accept affordance.

A state is `ORDER_STATE` only when at least two active-delivery markers are present, such as pickup/arrived/deliver/customer/directions/complete-delivery text.

The service stores a SHA-256 fingerprint and ignores identical or too-frequent repeated states.

## Project layout

```text
lib/main.dart
android/app/src/main/kotlin/com/qroadsan/routengine/
  MainActivity.kt
  DoorDashAccessibilityService.kt
  OverlayController.kt
  SecureCaptureStore.kt
  CryptoBox.kt
  NativeSettings.kt
  OnlineDecisionPipeline.kt
  NativeEventBus.kt
relay/server.py
test/
docs/
.github/workflows/android-aab.yml
```

## Validation note

This ZIP was assembled in an environment without the Flutter SDK, so I could not execute `flutter analyze`, `flutter test`, or an Android Gradle build here. The repository includes a normal Flutter/Android structure and a test plan; run the commands in `docs/TESTING.md` on your development machine before relying on it while riding.
