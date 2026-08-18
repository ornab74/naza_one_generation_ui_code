# Security and Android architecture

## Native boundary

Flutter `MethodChannel` / `EventChannel` connect the Dart UI to Android code. Cross-app accessibility observation, screenshot capture, the accessibility overlay, Android Keystore, SQLite, and background TTS/navigation are implemented in Kotlin.

## Capture security

The service only requests Android's documented accessibility screenshot capability. `android:canTakeScreenshot="true"` is declared in `accessibility_service_config.xml`.

On Android 14+, `takeScreenshotOfWindow()` is used with the DoorDash event window ID. On Android 11–13, the overlay is briefly hidden and `takeScreenshot()` is used.

If Android refuses capture because the target is a secure window, Route Engine stores the accessibility-state record without the screenshot. There is no fallback intended to defeat `FLAG_SECURE`.

## Vault encryption

The SQLite database itself is app-private. Sensitive record bodies are additionally sealed before insertion:

- key: AES-256 generated inside Android Keystore
- mode: GCM
- padding: none
- IV: random cipher IV per encryption
- authentication tag: included in GCM ciphertext
- AAD: timestamp + state type + SHA-256 fingerprint + data slot

Encrypted slots:

- accessibility/offer JSON
- screenshot PNG bytes
- Luna decision JSON

SQLite retains only minimal indexable metadata outside those blobs: record id, timestamp, state kind, hashed fingerprint, image dimensions, and presence flags.

## Relay key handling

The OpenAI API key belongs only on `relay/server.py` or another server-side relay. The phone never needs it.

The optional Route Engine relay bearer token is protected with the same Android Keystore AES-GCM key before it is written to SharedPreferences.

## Overlay

The compact HUD is an accessibility overlay rather than a generic `SYSTEM_ALERT_WINDOW` application overlay. It is non-focusable and non-touchable, and its visibility is tied to DoorDash foreground accessibility events.

## Data retention

The local vault prunes itself to the newest 120 records. The UI includes explicit "Clear vault".

The relay sets `store: false` in its OpenAI Responses API request. Review your OpenAI organization/project data-control configuration separately for your deployment requirements.
