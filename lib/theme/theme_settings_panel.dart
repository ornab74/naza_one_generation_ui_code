import 'package:flutter/material.dart';

import 'naza_themes.dart';

/// Settings-ready theme surface. The app shell only needs to provide the
/// currently selected preset and persist [onSelected] using its existing
/// encrypted/settings storage mechanism.
final class NazaThemeSettingsPanel extends StatelessWidget {
  final NazaThemePreset selected;
  final ValueChanged<NazaThemePreset> onSelected;

  const NazaThemeSettingsPanel({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final active = NazaThemeCatalog.spec(selected);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: active.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.palette_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Appearance',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active: ${selected.label}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(selected.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Themes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fifteen Material 3 palettes. Theme changes are visual only; they do not alter model prompts, scanner risk logic, vault encryption, or security policy.',
        ),
        const SizedBox(height: 12),
        NazaThemePicker(selected: selected, onSelected: onSelected),
      ],
    );
  }
}
