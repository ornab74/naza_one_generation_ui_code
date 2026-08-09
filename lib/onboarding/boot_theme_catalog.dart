import 'package:flutter/material.dart';

final class NazaBootTheme {
  const NazaBootTheme({
    required this.id,
    required this.label,
    required this.description,
    required this.seed,
    required this.accent,
    required this.brightness,
  });

  final String id;
  final String label;
  final String description;
  final Color seed;
  final Color accent;
  final Brightness brightness;

  ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      tertiary: accent,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: dark
          ? Color.alphaBlend(seed.withValues(alpha: 0.055), const Color(0xFF030706))
          : Color.alphaBlend(seed.withValues(alpha: 0.035), const Color(0xFFFFFBFE)),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface.withValues(alpha: dark ? 0.92 : 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.18)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.52 : 0.68),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

final class NazaBootThemeCatalog {
  const NazaBootThemeCatalog._();

  static const String defaultId = 'naza-emerald';

  static const List<NazaBootTheme> all = <NazaBootTheme>[
    NazaBootTheme(id: 'naza-emerald', label: 'Naza Emerald', description: 'Deep emerald glass and mint signal light', seed: Color(0xFF38E89A), accent: Color(0xFF66D8FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'halo-olive', label: 'Orbital Olive', description: 'Armor olive with warm amber HUD accents', seed: Color(0xFF8DA35A), accent: Color(0xFFD6A83E), brightness: Brightness.dark),
    NazaBootTheme(id: 'cyber-neon', label: 'Cyber Neon', description: 'Electric yellow, magenta and deep black', seed: Color(0xFFF2E900), accent: Color(0xFFFF2CAA), brightness: Brightness.dark),
    NazaBootTheme(id: 'synthwave', label: 'Synthwave', description: 'Violet night, cyan glow and hot pink', seed: Color(0xFF9C5CFF), accent: Color(0xFFFF4BC8), brightness: Brightness.dark),
    NazaBootTheme(id: 'midnight-blue', label: 'Midnight', description: 'Blue-black surfaces with indigo energy', seed: Color(0xFF647CFF), accent: Color(0xFF62D7FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'terminal-green', label: 'Terminal', description: 'Phosphor green command-line minimalism', seed: Color(0xFF52E36D), accent: Color(0xFFA6FF93), brightness: Brightness.dark),
    NazaBootTheme(id: 'ocean-research', label: 'Ocean Lab', description: 'Deep navy with reef cyan and seafoam', seed: Color(0xFF29B9D0), accent: Color(0xFF75F0C7), brightness: Brightness.dark),
    NazaBootTheme(id: 'forest', label: 'Forest', description: 'Moss, fern and soft mint through dark bark', seed: Color(0xFF6ACB72), accent: Color(0xFFC2D786), brightness: Brightness.dark),
    NazaBootTheme(id: 'ember', label: 'Ember', description: 'Coal surfaces with copper and ember light', seed: Color(0xFFFF7A3D), accent: Color(0xFFFFC16B), brightness: Brightness.dark),
    NazaBootTheme(id: 'lavender', label: 'Lavender Moon', description: 'Soft violet glass and moonlit blue', seed: Color(0xFFAB82FF), accent: Color(0xFF8BC8FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'graphite', label: 'Graphite', description: 'Neutral graphite with cool silver detail', seed: Color(0xFF8C96A3), accent: Color(0xFFCBD4DF), brightness: Brightness.dark),
    NazaBootTheme(id: 'obsidian-red', label: 'Obsidian Red', description: 'Black glass with precision crimson signals', seed: Color(0xFFE44747), accent: Color(0xFFFF9966), brightness: Brightness.dark),
    NazaBootTheme(id: 'quantum-cyan', label: 'Quantum Cyan', description: 'Dark laboratory cyan with spectral violet', seed: Color(0xFF28D9E8), accent: Color(0xFFA476FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'deep-space', label: 'Deep Space', description: 'Near-black cosmos with ion-blue telemetry', seed: Color(0xFF4F78FF), accent: Color(0xFF7FE8FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'aurora', label: 'Aurora', description: 'Northern-light green with polar violet', seed: Color(0xFF46E6A2), accent: Color(0xFF9A78FF), brightness: Brightness.dark),
    NazaBootTheme(id: 'plasma', label: 'Plasma', description: 'Charged purple with electric coral', seed: Color(0xFFB74CFF), accent: Color(0xFFFF657A), brightness: Brightness.dark),
    NazaBootTheme(id: 'copper-circuit', label: 'Copper Circuit', description: 'Warm copper against charcoal electronics', seed: Color(0xFFC77943), accent: Color(0xFFF6B65F), brightness: Brightness.dark),
    NazaBootTheme(id: 'ice-station', label: 'Ice Station', description: 'Frozen blue glass with crisp white signal', seed: Color(0xFF66BDE8), accent: Color(0xFFB7EEFF), brightness: Brightness.dark),
    NazaBootTheme(id: 'rose-dark', label: 'Rose Dark', description: 'Deep berry surfaces with luminous rose', seed: Color(0xFFE45B9A), accent: Color(0xFFFFA7D1), brightness: Brightness.dark),
    NazaBootTheme(id: 'gold-black', label: 'Black Gold', description: 'Matte black with restrained gold telemetry', seed: Color(0xFFD5A637), accent: Color(0xFFFFD873), brightness: Brightness.dark),
    NazaBootTheme(id: 'matrix', label: 'Matrix Rain', description: 'Black and green with dense terminal energy', seed: Color(0xFF38D35C), accent: Color(0xFF8BFF9B), brightness: Brightness.dark),
    NazaBootTheme(id: 'ultraviolet', label: 'Ultraviolet', description: 'Ink violet with ultraviolet highlights', seed: Color(0xFF7E5BFF), accent: Color(0xFFD56BFF), brightness: Brightness.dark),
    NazaBootTheme(id: 'solar-light', label: 'Solar', description: 'Warm cream, amber and sunset bronze', seed: Color(0xFFE28A17), accent: Color(0xFFC95035), brightness: Brightness.light),
    NazaBootTheme(id: 'arctic-light', label: 'Arctic', description: 'Clean ice blue and white glass', seed: Color(0xFF258EB9), accent: Color(0xFF6A7FA8), brightness: Brightness.light),
    NazaBootTheme(id: 'paper-mint', label: 'Paper Mint', description: 'Bright paper with soft mint intelligence', seed: Color(0xFF27A878), accent: Color(0xFF3A93D5), brightness: Brightness.light),
    NazaBootTheme(id: 'rose-light', label: 'Rose Quartz', description: 'Warm white with rose and lilac accents', seed: Color(0xFFD34F8B), accent: Color(0xFF8C61D8), brightness: Brightness.light),
    NazaBootTheme(id: 'sky-light', label: 'Open Sky', description: 'Airy blue surfaces and clean cyan detail', seed: Color(0xFF318AC8), accent: Color(0xFF39B9BA), brightness: Brightness.light),
    NazaBootTheme(id: 'sand-light', label: 'Desert Paper', description: 'Sand, terracotta and warm graphite', seed: Color(0xFFB2693C), accent: Color(0xFFCC9442), brightness: Brightness.light),
  ];

  static NazaBootTheme byId(String? id) => all.firstWhere(
        (theme) => theme.id == id,
        orElse: () => all.first,
      );
}
