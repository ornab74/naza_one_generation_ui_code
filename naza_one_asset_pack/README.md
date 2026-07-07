# Naza One visual asset pack

This pack contains original generated assets to make the Flutter app match the dark glass / nature / local-AI mockup style.

## Included

- `assets/backgrounds/splash_forest_waterfall.png`
- `assets/backgrounds/chat_river_forest.png`
- `assets/backgrounds/about_aurora_mountains.png`
- `assets/backgrounds/nature_glass_mesh.png`
- `assets/backgrounds/glass_noise_overlay.png`
- `assets/branding/naza_orb_1024.png` plus smaller orb sizes
- `assets/branding/naza_leaf_logo.svg`
- `assets/branding/naza_wordmark.svg`
- `assets/icons/*.svg`
- `assets/particles/quantum_wave.svg`
- Android launcher icon resources under `android/app/src/main/res/`
- Flutter helper files:
  - `lib/naza_asset_paths.dart`
  - `lib/naza_theme_snippet.dart`
- `pubspec_assets_snippet.yaml`
- `fonts/FONT_SETUP.md`

## Install

Copy the `assets/` folder into your Flutter project root.

Merge `pubspec_assets_snippet.yaml` into your `pubspec.yaml`.

For SVG icons, add:

```yaml
dependencies:
  flutter_svg: ^2.0.0
```

Then use:

```dart
import 'package:flutter_svg/flutter_svg.dart';
import 'naza_asset_paths.dart';

SvgPicture.asset(NazaAssets.iconChat, width: 24, height: 24);
Image.asset(NazaAssets.splashForest, fit: BoxFit.cover);
```

## Android launcher icon

Copy the generated `android/app/src/main/res/` folders into the matching location in your Android project.

The pack includes both adaptive icon resources and legacy mipmap PNG launcher icons.

## Fonts

No font binaries are included. See `fonts/FONT_SETUP.md`.
