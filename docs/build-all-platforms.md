# Build Naza One for each platform

This guide shows how to build each target one by one. GitHub Actions already
does this in `.github/workflows/flutter-release.yml`, but these commands are
useful when you want to build manually on your own machine.

## 0. Shared setup

From the project root:

```bash
cd /home/user/naza_one_generation_ui_code
```

If you are using the project-local Flutter SDK on Linux:

```bash
export PATH="$PWD/.tooling/flutter/bin:$PATH"
export PUB_CACHE="$PWD/.pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
```

On Windows/macOS, install Flutter `3.44.4` or the same version used by GitHub
Actions, then run:

```bash
flutter --version
flutter pub get
flutter analyze --no-pub
```

The local model file is not committed. Use one of these:

- Android: place `gemma-4-E2B-it.litertlm` at
  `android/app/src/main/assets/models/gemma-4-E2B-it.litertlm`.
- Desktop: set `NAZA_MODEL_PATH` to the full `.litertlm` path, or copy the model
  beside the built executable under `models/gemma-4-E2B-it.litertlm`.
- iOS/macOS: bundle the model in the app target if you want local inference
  inside the final app. The UI still builds without the model and reports a
  model-unavailable state at runtime.

## 1. Android APK

Host OS: Linux, macOS, or Windows.

Requirements:

- Flutter
- Android SDK
- JDK 17+

Build:

```bash
flutter pub get
flutter build apk --release --no-pub
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 2. Android App Bundle / Google Play

Host OS: Linux, macOS, or Windows.

Build:

```bash
flutter pub get
flutter build appbundle --release --no-pub
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

For signed release builds, create `android/key.properties` from
`android/key.properties.example` and place your keystore at the referenced
`storeFile` path. Do not commit the real keystore or real `key.properties`.

GitHub Actions uses these secrets instead:

- `ANDROID_KEYSTORE_B64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## 3. Linux x64

Host OS: Linux.

Ubuntu dependencies:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
```

Build:

```bash
flutter pub get
flutter build linux --release --no-pub
```

Output folder:

```text
build/linux/x64/release/bundle/
```

Optional package:

```bash
tar -czf naza-one-linux-x64.tar.gz -C build/linux/x64/release/bundle .
```

Run:

```bash
NAZA_MODEL_PATH=/absolute/path/to/gemma-4-E2B-it.litertlm \
build/linux/x64/release/bundle/naza_one
```

## 4. Windows x64

Host OS: Windows.

Requirements:

- Flutter
- Visual Studio 2022 with “Desktop development with C++”

Build in PowerShell:

```powershell
flutter pub get
flutter build windows --release --no-pub
```

Output folder:

```text
build\windows\x64\runner\Release\
```

Optional zip package:

```powershell
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath naza-one-windows-x64.zip -Force
```

Run:

```powershell
$env:NAZA_MODEL_PATH="C:\path\to\gemma-4-E2B-it.litertlm"
.\build\windows\x64\runner\Release\naza_one.exe
```

## 5. Windows Store / MSIX

Host OS: Windows.

The project has `msix_config` in `pubspec.yaml`.

Build the Windows release first:

```powershell
flutter build windows --release --no-pub
```

Create a Store-mode MSIX:

```powershell
dart run msix:create `
  --store `
  --display-name "Naza One" `
  --publisher-display-name "Naza" `
  --identity-name "Naza.NazaOne" `
  --publisher "CN=YOUR_WINDOWS_STORE_PUBLISHER" `
  --build-windows false `
  --output-name "naza-one-windows-store"
```

For GitHub Actions, set:

- `WINDOWS_MSIX_PUBLISHER`
- optional `WINDOWS_MSIX_IDENTITY_NAME`
- optional `WINDOWS_PUBLISHER_DISPLAY_NAME`
- optional `WINDOWS_PFX_B64`
- optional `WINDOWS_PFX_PASSWORD`

## 6. macOS

Host OS: macOS.

Requirements:

- Flutter
- Xcode
- CocoaPods

Build:

```bash
flutter pub get
flutter build macos --release --no-pub
```

Output:

```text
build/macos/Build/Products/Release/Naza One.app
```

Package:

```bash
APP_PATH=$(find build/macos/Build/Products/Release -maxdepth 1 -name "*.app" | head -n 1)
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" naza-one-macos.zip
```

For Developer ID signing/notarization in GitHub Actions, set:

- `MACOS_CERTIFICATE_P12_B64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_CODESIGN_IDENTITY`
- optional `APPLE_ID`
- optional `APPLE_APP_SPECIFIC_PASSWORD`
- optional `APPLE_TEAM_ID`

## 7. iOS unsigned app

Host OS: macOS only.

Requirements:

- Flutter
- Xcode
- CocoaPods

Build unsigned:

```bash
flutter pub get
flutter build ios --release --no-codesign --no-pub
```

Output:

```text
build/ios/iphoneos/Runner.app
```

Package unsigned app:

```bash
ditto -c -k --sequesterRsrc --keepParent build/ios/iphoneos/Runner.app naza-one-ios-unsigned-app.zip
```

## 8. iOS signed IPA

Host OS: macOS only.

You need an Apple distribution certificate, provisioning profile, and
`ExportOptions.plist` matching the app bundle id. The generated default bundle id
is:

```text
com.naza.nazaOne
```

Build signed IPA:

```bash
flutter pub get
flutter build ipa --release --no-pub --export-options-plist=/path/to/ExportOptions.plist
```

Output:

```text
build/ios/ipa/*.ipa
```

For GitHub Actions signed IPA builds, set:

- `IOS_CERTIFICATE_P12_B64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_B64`
- `IOS_EXPORT_OPTIONS_PLIST_B64`

## 9. Optional Web build

Flutter web can compile the UI, but confirm the local model runtime behavior for
your deployment target before treating Web as a production build.

Build:

```bash
flutter pub get
flutter build web --release --no-pub
```

Output:

```text
build/web/
```

## 10. GitHub Actions one-by-one

To build everything in GitHub:

1. Push to `main`, open a pull request, push a `v*` tag, or run
   “Build Naza One” from the Actions tab with `workflow_dispatch`.
2. Download artifacts from the completed workflow run.
3. Add signing/store secrets from `docs/github-actions-signing.md` when you want
   signed Android, Windows Store MSIX, signed iOS IPA, or notarized macOS output.

The workflow jobs are separate:

- `Analyze`
- `Android APK/AAB`
- `Linux x64`
- `Windows x64`
- `macOS`
- `iOS`

If one platform fails, you can rerun only that failed job from the GitHub
Actions run page.
