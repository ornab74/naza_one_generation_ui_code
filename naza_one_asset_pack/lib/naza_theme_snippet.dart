import 'package:flutter/material.dart';
// Optional: import 'package:google_fonts/google_fonts.dart';

class NazaPalette {
  static const ink = Color(0xFF06110D);
  static const inkDeep = Color(0xFF020806);
  static const glass = Color(0x16FFFFFF);
  static const glassBorder = Color(0x22FFFFFF);
  static const mint = Color(0xFF8DFFC4);
  static const mintSoft = Color(0xFFC7FFE3);
  static const moss = Color(0xFF208563);
  static const text = Color(0xFFF2FFF7);
  static const subtext = Color(0xFFA9CDBB);
  static const warning = Color(0xFFFF8B70);
}

ThemeData buildNazaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NazaPalette.ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NazaPalette.mint,
      brightness: Brightness.dark,
    ),
  );

  // Font note:
  // For fully offline builds, bundle your own licensed font files in assets/fonts
  // and set fontFamily here. This asset pack does not include font binaries.
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: NazaPalette.text,
      displayColor: NazaPalette.text,
      fontFamily: 'NazaBody', // or remove this and use Android Roboto.
    ),
  );
}
