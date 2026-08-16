// LLM-CONTEXT:BEGIN
// FILE: test_archive/naza_themes_test.dart
// ROLE: Owns naza themes test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/theme/naza_themes.dart';

void main() {
  test('theme catalog exposes fifteen named presets', () {
    expect(NazaThemePreset.values, hasLength(15));
    expect(
      NazaThemePreset.values.map((preset) => preset.label),
      containsAll(<String>['Halo 2', 'Barbie', 'Aqua', 'Naza']),
    );
    expect(NazaThemeCatalog.specs.keys.toSet(), NazaThemePreset.values.toSet());
  });

  test('every preset builds a Material 3 theme with visible contrast', () {
    for (final preset in NazaThemePreset.values) {
      final spec = NazaThemeCatalog.spec(preset);
      final theme = spec.build();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, spec.primary);
      expect(theme.scaffoldBackgroundColor, spec.background);
      expect(spec.primary, isNot(spec.background));
      expect(
        ThemeData.estimateBrightnessForColor(spec.text),
        isNotNull,
      );
    }
  });

  test('theme controller switches without recreating catalog', () {
    final controller = NazaThemeController();
    var changes = 0;
    controller.addListener(() => changes++);

    controller.select(NazaThemePreset.halo2);
    expect(controller.preset, NazaThemePreset.halo2);
    expect(changes, 1);

    controller.select(NazaThemePreset.halo2);
    expect(changes, 1);

    controller.select(NazaThemePreset.barbie);
    expect(controller.preset, NazaThemePreset.barbie);
    expect(changes, 2);
  });
}
