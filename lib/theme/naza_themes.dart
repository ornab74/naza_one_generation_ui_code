import 'package:flutter/material.dart';

enum NazaThemePreset {
  naza,
  halo2,
  barbie,
  aqua,
  cyberpunk,
  midnight,
  terminal,
  solar,
  arctic,
  ember,
  lavender,
  ocean,
  forest,
  graphite,
  synthwave,
}

extension NazaThemePresetInfo on NazaThemePreset {
  String get label => switch (this) {
    NazaThemePreset.naza => 'Naza',
    NazaThemePreset.halo2 => 'Halo 2',
    NazaThemePreset.barbie => 'Barbie',
    NazaThemePreset.aqua => 'Aqua',
    NazaThemePreset.cyberpunk => 'Cyberpunk',
    NazaThemePreset.midnight => 'Midnight',
    NazaThemePreset.terminal => 'Terminal',
    NazaThemePreset.solar => 'Solar',
    NazaThemePreset.arctic => 'Arctic',
    NazaThemePreset.ember => 'Ember',
    NazaThemePreset.lavender => 'Lavender',
    NazaThemePreset.ocean => 'Ocean',
    NazaThemePreset.forest => 'Forest',
    NazaThemePreset.graphite => 'Graphite',
    NazaThemePreset.synthwave => 'Synthwave',
  };

  String get description => switch (this) {
    NazaThemePreset.naza => 'Deep emerald local-AI default',
    NazaThemePreset.halo2 => 'Olive armor, amber HUD, gunmetal surfaces',
    NazaThemePreset.barbie => 'Glossy pink, lilac, bright playful contrast',
    NazaThemePreset.aqua => 'Clean cyan, teal glass, ocean glow',
    NazaThemePreset.cyberpunk => 'Neon yellow and magenta over black',
    NazaThemePreset.midnight => 'Blue-black with electric indigo',
    NazaThemePreset.terminal => 'Phosphor green terminal minimalism',
    NazaThemePreset.solar => 'Warm amber, cream, sunset bronze',
    NazaThemePreset.arctic => 'Ice blue, white glass, steel shadows',
    NazaThemePreset.ember => 'Coal, orange, copper and ember red',
    NazaThemePreset.lavender => 'Soft purple glass and moonlight blue',
    NazaThemePreset.ocean => 'Deep navy, reef cyan and seafoam',
    NazaThemePreset.forest => 'Moss, fern, bark and soft mint',
    NazaThemePreset.graphite => 'Neutral graphite with silver highlights',
    NazaThemePreset.synthwave => 'Violet night with cyan and hot pink',
  };
}

final class NazaThemeSpec {
  final NazaThemePreset preset;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color danger;
  final Color text;
  final Color muted;

  const NazaThemeSpec({
    required this.preset,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.danger,
    required this.text,
    required this.muted,
  });

  ThemeData build({String fontFamily = 'Inter'}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: _bestOn(primary),
      secondary: secondary,
      onSecondary: _bestOn(secondary),
      error: danger,
      onError: _bestOn(danger),
      surface: surface,
      onSurface: text,
    );
    final radius = BorderRadius.circular(18);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: muted.withAlpha(dark ? 52 : 42),
      // Avoid compiling InkSparkle on the first interaction. The app uses
      // explicit selected/focused states for feedback instead.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withAlpha(dark ? 44 : 30),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: text, fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withAlpha(dark ? 44 : 30),
        selectedIconTheme: IconThemeData(color: primary),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: primary.withAlpha(dark ? 38 : 28)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _bestOn(primary),
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withAlpha(150)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(0, 46),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withAlpha(190)),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: muted.withAlpha(70)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: muted.withAlpha(70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainer,
        selectedColor: primary.withAlpha(dark ? 48 : 38),
        side: BorderSide(color: primary.withAlpha(70)),
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withAlpha(70),
        selectionHandleColor: primary,
      ),
    );
  }

  static Color _bestOn(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : const Color(0xFF111111);
}

final class NazaThemeCatalog {
  const NazaThemeCatalog._();

  static const Map<NazaThemePreset, NazaThemeSpec> specs =
      <NazaThemePreset, NazaThemeSpec>{
        NazaThemePreset.naza: NazaThemeSpec(
          preset: NazaThemePreset.naza,
          brightness: Brightness.dark,
          background: Color(0xFF020806),
          surface: Color(0xFF071611),
          surfaceContainer: Color(0xFF0A1D16),
          primary: Color(0xFF8DFFC4),
          secondary: Color(0xFF59EFA9),
          tertiary: Color(0xFF7FD7FF),
          danger: Color(0xFFFF8B70),
          text: Color(0xFFF2FFF7),
          muted: Color(0xFF8FB8A3),
        ),
        NazaThemePreset.halo2: NazaThemeSpec(
          preset: NazaThemePreset.halo2,
          brightness: Brightness.dark,
          background: Color(0xFF0B0D09),
          surface: Color(0xFF171A12),
          surfaceContainer: Color(0xFF242719),
          primary: Color(0xFFD5A83B),
          secondary: Color(0xFF7E8F4E),
          tertiary: Color(0xFF8DB7B0),
          danger: Color(0xFFD95F45),
          text: Color(0xFFF0E7C9),
          muted: Color(0xFFA9A58C),
        ),
        NazaThemePreset.barbie: NazaThemeSpec(
          preset: NazaThemePreset.barbie,
          brightness: Brightness.light,
          background: Color(0xFFFFF2FA),
          surface: Color(0xFFFFFAFD),
          surfaceContainer: Color(0xFFFFE0F3),
          primary: Color(0xFFE50087),
          secondary: Color(0xFFFF64B7),
          tertiary: Color(0xFF9C63FF),
          danger: Color(0xFFC51A54),
          text: Color(0xFF45102F),
          muted: Color(0xFF86516E),
        ),
        NazaThemePreset.aqua: NazaThemeSpec(
          preset: NazaThemePreset.aqua,
          brightness: Brightness.dark,
          background: Color(0xFF001014),
          surface: Color(0xFF04232A),
          surfaceContainer: Color(0xFF06343D),
          primary: Color(0xFF5CF6E8),
          secondary: Color(0xFF4BBFE8),
          tertiary: Color(0xFF9FFFD8),
          danger: Color(0xFFFF7B86),
          text: Color(0xFFE9FFFD),
          muted: Color(0xFF8ABCC1),
        ),
        NazaThemePreset.cyberpunk: NazaThemeSpec(
          preset: NazaThemePreset.cyberpunk,
          brightness: Brightness.dark,
          background: Color(0xFF070707),
          surface: Color(0xFF141414),
          surfaceContainer: Color(0xFF202020),
          primary: Color(0xFFF8F000),
          secondary: Color(0xFFFF2DAA),
          tertiary: Color(0xFF00E5FF),
          danger: Color(0xFFFF4C4C),
          text: Color(0xFFF9F9F2),
          muted: Color(0xFFB0B0A2),
        ),
        NazaThemePreset.midnight: NazaThemeSpec(
          preset: NazaThemePreset.midnight,
          brightness: Brightness.dark,
          background: Color(0xFF030510),
          surface: Color(0xFF0A1024),
          surfaceContainer: Color(0xFF111A38),
          primary: Color(0xFF8DA2FF),
          secondary: Color(0xFF6678FF),
          tertiary: Color(0xFF62D7FF),
          danger: Color(0xFFFF718A),
          text: Color(0xFFF2F5FF),
          muted: Color(0xFF929CBC),
        ),
        NazaThemePreset.terminal: NazaThemeSpec(
          preset: NazaThemePreset.terminal,
          brightness: Brightness.dark,
          background: Color(0xFF000500),
          surface: Color(0xFF061006),
          surfaceContainer: Color(0xFF0A1B0A),
          primary: Color(0xFF73FF73),
          secondary: Color(0xFF30D95B),
          tertiary: Color(0xFFB0FF9B),
          danger: Color(0xFFFF6B6B),
          text: Color(0xFFDCFCDC),
          muted: Color(0xFF7DA47D),
        ),
        NazaThemePreset.solar: NazaThemeSpec(
          preset: NazaThemePreset.solar,
          brightness: Brightness.light,
          background: Color(0xFFFFF7E5),
          surface: Color(0xFFFFFBF2),
          surfaceContainer: Color(0xFFFFE9BC),
          primary: Color(0xFFB96500),
          secondary: Color(0xFFE79A13),
          tertiary: Color(0xFFBF5035),
          danger: Color(0xFFC4342D),
          text: Color(0xFF3E2811),
          muted: Color(0xFF806445),
        ),
        NazaThemePreset.arctic: NazaThemeSpec(
          preset: NazaThemePreset.arctic,
          brightness: Brightness.light,
          background: Color(0xFFF3FAFF),
          surface: Color(0xFFFFFFFF),
          surfaceContainer: Color(0xFFE2F3FF),
          primary: Color(0xFF087EB0),
          secondary: Color(0xFF50B9D7),
          tertiary: Color(0xFF617FA8),
          danger: Color(0xFFC83D4F),
          text: Color(0xFF0D3042),
          muted: Color(0xFF617D8C),
        ),
        NazaThemePreset.ember: NazaThemeSpec(
          preset: NazaThemePreset.ember,
          brightness: Brightness.dark,
          background: Color(0xFF0C0705),
          surface: Color(0xFF1C100B),
          surfaceContainer: Color(0xFF2A1710),
          primary: Color(0xFFFF9B50),
          secondary: Color(0xFFE76432),
          tertiary: Color(0xFFFFC078),
          danger: Color(0xFFFF5147),
          text: Color(0xFFFFF0E7),
          muted: Color(0xFFC49B84),
        ),
        NazaThemePreset.lavender: NazaThemeSpec(
          preset: NazaThemePreset.lavender,
          brightness: Brightness.dark,
          background: Color(0xFF0B0714),
          surface: Color(0xFF171025),
          surfaceContainer: Color(0xFF241735),
          primary: Color(0xFFC7A1FF),
          secondary: Color(0xFF9D7BFF),
          tertiary: Color(0xFF9ACBFF),
          danger: Color(0xFFFF7C9D),
          text: Color(0xFFF8F1FF),
          muted: Color(0xFFB0A1C1),
        ),
        NazaThemePreset.ocean: NazaThemeSpec(
          preset: NazaThemePreset.ocean,
          brightness: Brightness.dark,
          background: Color(0xFF00101F),
          surface: Color(0xFF071F31),
          surfaceContainer: Color(0xFF0A3046),
          primary: Color(0xFF4BD5DF),
          secondary: Color(0xFF4F9AE8),
          tertiary: Color(0xFF85F0CC),
          danger: Color(0xFFFF7880),
          text: Color(0xFFEAFBFF),
          muted: Color(0xFF88ABB8),
        ),
        NazaThemePreset.forest: NazaThemeSpec(
          preset: NazaThemePreset.forest,
          brightness: Brightness.dark,
          background: Color(0xFF071008),
          surface: Color(0xFF101D11),
          surfaceContainer: Color(0xFF192B1A),
          primary: Color(0xFF9AE39D),
          secondary: Color(0xFF62B36B),
          tertiary: Color(0xFFC7D58C),
          danger: Color(0xFFE6816F),
          text: Color(0xFFF0F9ED),
          muted: Color(0xFF9BAF96),
        ),
        NazaThemePreset.graphite: NazaThemeSpec(
          preset: NazaThemePreset.graphite,
          brightness: Brightness.dark,
          background: Color(0xFF0B0C0E),
          surface: Color(0xFF17191C),
          surfaceContainer: Color(0xFF23262A),
          primary: Color(0xFFD3D8E0),
          secondary: Color(0xFF9CA5B1),
          tertiary: Color(0xFF7DB5E8),
          danger: Color(0xFFFF7474),
          text: Color(0xFFF4F5F7),
          muted: Color(0xFFA2A8B0),
        ),
        NazaThemePreset.synthwave: NazaThemeSpec(
          preset: NazaThemePreset.synthwave,
          brightness: Brightness.dark,
          background: Color(0xFF0B0317),
          surface: Color(0xFF1B0B2E),
          surfaceContainer: Color(0xFF2B1042),
          primary: Color(0xFFFF4FD8),
          secondary: Color(0xFF8F6BFF),
          tertiary: Color(0xFF35E7FF),
          danger: Color(0xFFFF6363),
          text: Color(0xFFFFF0FC),
          muted: Color(0xFFBE9FC9),
        ),
      };

  static NazaThemeSpec spec(NazaThemePreset preset) => specs[preset]!;
}

final class NazaThemeController extends ChangeNotifier {
  NazaThemeController({NazaThemePreset initial = NazaThemePreset.naza})
    : _preset = initial;

  NazaThemePreset _preset;

  NazaThemePreset get preset => _preset;

  NazaThemeSpec get spec => NazaThemeCatalog.spec(_preset);

  ThemeData get theme => spec.build();

  void select(NazaThemePreset preset) {
    if (_preset == preset) return;
    _preset = preset;
    notifyListeners();
  }
}

final class NazaThemePicker extends StatelessWidget {
  final NazaThemePreset selected;
  final ValueChanged<NazaThemePreset> onSelected;

  const NazaThemePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 4
            : width >= 700
            ? 3
            : width >= 440
            ? 2
            : 1;
        final gap = 10.0;
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final preset in NazaThemePreset.values)
              SizedBox(
                width: tileWidth,
                child: _ThemeTile(
                  preset: preset,
                  selected: preset == selected,
                  onTap: () => onSelected(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _ThemeTile extends StatelessWidget {
  final NazaThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spec = NazaThemeCatalog.spec(preset);
    return Material(
      color: spec.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? spec.primary : spec.muted.withAlpha(70),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (final color in <Color>[
                    spec.primary,
                    spec.secondary,
                    spec.tertiary,
                  ])
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: spec.primary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                preset.label,
                style: TextStyle(
                  color: spec.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                preset.description,
                style: TextStyle(color: spec.muted, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
