# GitHub Actions signing setup

The workflow in `.github/workflows/flutter-release.yml` builds:

- Android APK and AAB on Ubuntu
- Linux x64 bundle on Ubuntu
- Windows x64 bundle on Windows
- optional Windows Store/MSIX package on Windows
- macOS `.app` zip on macOS
- unsigned iOS app zip on macOS
- optional signed iOS IPA on macOS

## Android signing

Create an upload keystore locally, then add these GitHub Actions secrets:

- `ANDROID_KEYSTORE_B64` — base64 text of your `.jks` upload keystore
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Optional Google Play internal testing upload:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

Optional repository variable:

- `ANDROID_PACKAGE_NAME` — defaults to `com.qroadscan.lightcal`

Base64 examples:

```bash
# Linux
base64 -w0 upload-keystore.jks

# macOS
base64 -i upload-keystore.jks
```

The workflow writes `android/key.properties` at build time. Do not commit your
real keystore or real `key.properties`.

## iOS signing

Unsigned iOS builds run automatically. To also produce a signed IPA, add:

- `IOS_CERTIFICATE_P12_B64` — base64 text of the Apple distribution `.p12`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_B64` — base64 text of the `.mobileprovision`
- `IOS_EXPORT_OPTIONS_PLIST_B64` — base64 text of your `ExportOptions.plist`

The default iOS bundle id created by Flutter is `com.naza.nazaOne`. Make sure
your Apple provisioning profile and `ExportOptions.plist` match that bundle id,
or update the Xcode project bundle id before release.

## macOS signing and notarization

Unsigned/ad-hoc macOS builds run automatically. To sign and optionally notarize:

- `MACOS_CERTIFICATE_P12_B64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_CODESIGN_IDENTITY` — for example `Developer ID Application: ...`

For notarization, also add:

- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

## Windows Store / MSIX

The workflow always builds a normal Windows release zip. To also create a Store
MSIX package, set:

- `WINDOWS_MSIX_PUBLISHER` — usually the Microsoft Store dashboard publisher,
  for example `CN=...`

Optional repository variables:

- `WINDOWS_MSIX_IDENTITY_NAME` — defaults to `Naza.NazaOne`
- `WINDOWS_PUBLISHER_DISPLAY_NAME` — defaults to `Naza`

Optional outside-the-Store signing secrets:

- `WINDOWS_PFX_B64`
- `WINDOWS_PFX_PASSWORD`

For Microsoft Store upload, the Store signs the final distributed package; the
workflow creates a Store-mode MSIX with `store: true`.
