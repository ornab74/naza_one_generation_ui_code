# Font setup for the Naza One mockup style

Font binaries are intentionally not included in this asset pack.

Recommended look:
- Display / headings: Manrope ExtraBold or Space Grotesk Bold
- Body: Manrope Regular / SemiBold, or Android default Roboto
- Technical status chips: JetBrains Mono or Roboto Mono

Offline/private build recommendation:
1. Download open font files yourself from the official font source.
2. Put the `.ttf` files in `assets/fonts/`.
3. Add the `flutter.fonts` section from `pubspec_assets_snippet.yaml`.
4. In your theme, use `fontFamily: 'NazaBody'`.

Fastest no-extra-files option:
- Do not add fonts.
- Use Android's default Roboto. The UI will still match the mockup closely because the color, glass, spacing, and icon system do most of the visual work.
