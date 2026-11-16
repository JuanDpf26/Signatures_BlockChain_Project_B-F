import 'package:flutter/material.dart';

class AppTheme {
  // ── Paleta moderna: verde esmeralda, neutros fríos y mucho aire ───────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F8FA); // fondos suaves / rail lateral
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E8EC);
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1558B0);
  static const Color primarySoft = Color(0xFFE8F0FE);
  static const Color text = Color(0xFF111827);
  static const Color hint = Color(0xFF6B7280);
  static const Color featureBlue = Color(0xFF3b82f6);
  static const Color featureCyan = Color(0xFF06b6d4);
  static const Color error = Color(0xFFE11D48);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF5A623);
  static const Color info = Color(0xFF3B82F6);

  // Radios consistentes
  static const double radiusCard = 24;
  static const double radiusControl = 14;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A73E8), Color(0xFF5B9DF5)],
  );

  // Sombra muy sutil: la separación la hace sobre todo el borde
  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: const Color(0xFF111827).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
      ];

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: surface,
        background: background,
        error: error,
      ),
      fontFamily: 'Inter', // Agrega Inter a pubspec.yaml > fonts
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: border, width: 1),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: error, width: 1.6),
        ),
        labelStyle: const TextStyle(color: hint),
        hintStyle: const TextStyle(color: hint),
        errorStyle: const TextStyle(color: error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? primary : hint,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
