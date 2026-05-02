import 'package:flutter/material.dart';

class AppTheme {
  // ── COLORES BASE ────────────────────────────────────────────────────────────
  static const Color background  = Color(0xFF0A0F1E);
  static const Color card        = Color(0xFF111827);
  static const Color cardAlt     = Color(0xFF0D1526);
  static const Color primary     = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color accent      = Color(0xFF06B6D4);
  static const Color text        = Color(0xFFF0F4FF);
  static const Color hint        = Color(0xFF8B9AB5);
  static const Color border      = Color(0x26638FED);

  // ── SEMÁNTICOS ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error   = Color(0xFFF87171);

  // ── FEATURE COLORS ──────────────────────────────────────────────────────────
  static const Color featureBlue  = Color(0xFF60A5FA);
  static const Color featureCyan  = Color(0xFF22D3EE);
  static const Color featureGreen = Color(0xFF34D399);

  // ── THEME DATA ──────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    fontFamily: 'Roboto',

    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: card,
      error: error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      foregroundColor: text,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: hint, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
    ),

    // Botón principal
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Botón outline
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: const TextStyle(color: text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}