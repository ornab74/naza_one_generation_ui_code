# Naza One release checklist

Run this checklist on a clean Windows machine before submitting to Microsoft
Store. A successful debug launch is not a release qualification.

## Build and tests

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- Launch the release executable and exercise the feature wheel, settings,
  BookForge, Food Scanner, Road Scanner, Walking, and Rev Recall.
- Confirm no `RenderFlex overflow`, uncaught gesture exception, missing asset,
  or audio-device error appears in the release run.

## Windows packaging

- Confirm `msix_config.identity_name` matches the reserved Store identity.
- Confirm the publisher name and certificate subject match the Partner Center
  publisher exactly.
- Increment `version` and `msix_version` together for every submission.
- Build with `flutter pub run msix:create --store` and inspect the generated
  package with Windows App Certification Kit (WACK).
- Install the package on a clean Windows profile and test uninstall/reinstall.
- Verify the package declares only `internetClient` and `location`. Location is
  requested in context when the user refreshes Walking weather; it must never
  be collected in the background.

## Privacy and data safety

- Publish `privacypolicy.md` at a stable HTTPS URL and use the same URL in
  Partner Center.
- Ensure Store disclosures mention optional Open-Meteo weather requests,
  remote model providers, camera/file pickers, and encrypted local storage.
- Verify API keys, GitHub tokens, and model-routing settings remain in the
  encrypted vault and never appear in logs, diagnostics, or exports.
- Test the offline path: local Gemma, local history, and scanners must remain
  usable without network access where their model assets are present.

## Accessibility and certification

- Test keyboard-only navigation, focus order, and activation of every wheel,
  drawer, dialog, tab, and form control.
- Test Windows high-contrast mode, 125–200% text scaling, and a narrow window.
- Verify every icon-only control has a tooltip/semantic label and every text
  field has a visible label or hint.
- Verify errors are visible, actionable, and do not expose credentials or raw
  provider responses.
- Capture Store screenshots from the release build at supported window sizes.

Record the Flutter, Windows SDK, and package versions used for the submission
alongside the signed MSIX and WACK result.
