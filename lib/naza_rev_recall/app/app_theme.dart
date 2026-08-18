import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF030711);
  static const backgroundRaised = Color(0xFF09101D);
  static const panel = Color(0xFF0D1423);
  static const panelBright = Color(0xFF131D31);
  static const border = Color(0xFF26324A);
  static const text = Color(0xFFF6F7FB);
  static const muted = Color(0xFF96A0B5);
  static const purple = Color(0xFF9B5CFF);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFFF4FB8);
  static const red = Color(0xFFFF3B4E);
  static const green = Color(0xFF53F087);
  static const amber = Color(0xFFFFC93D);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    brightness: Brightness.dark,
    surface: AppColors.panel,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppColors.text,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.text,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.muted),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.purple,
      inactiveTrackColor: AppColors.border,
      thumbColor: AppColors.purple,
      overlayColor: AppColors.purple.withValues(alpha: 0.2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.text
            : AppColors.muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.purple
            : AppColors.border;
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panelBright,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
