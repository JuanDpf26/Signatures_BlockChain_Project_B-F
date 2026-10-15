import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de una apariencia (clara u oscura)
class Palette {
  final bool dark;
  final Color page, card, surface, border, text, hint, primary, primaryDark, selected, neutral;
  const Palette({
    required this.dark,
    required this.page,
    required this.card,
    required this.surface,
    required this.border,
    required this.text,
    required this.hint,
    required this.primary,
    required this.primaryDark,
    required this.selected,
    required this.neutral,
  });

  static final light = Palette(
    dark: false,
    page: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F8FB),
    border: Color(0xFFE3E7EE),
    text: Color(0xFF1B1F27),
    hint: Color(0xFF5F6670),
    primary: Color(0xFF0B45B5),
    primaryDark: Color(0xFF08368F),
    selected: Color(0xFFE8EEFB),
    neutral: Color(0xFF5F6670),
  );

  static final lightContrast = Palette(
    dark: false,
    page: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F4F7),
    border: Color(0xFF8A93A3),
    text: Color(0xFF000000),
    hint: Color(0xFF2E333B),
    primary: Color(0xFF00308F),
    primaryDark: Color(0xFF002266),
    selected: Color(0xFFD6E2FA),
    neutral: Color(0xFF2E333B),
  );

  static final darkPalette = Palette(
    dark: true,
    page: Color(0xFF0D1117),
    card: Color(0xFF161B22),
    surface: Color(0xFF1C222B),
    border: Color(0xFF2D3440),
    text: Color(0xFFE8ECF2),
    hint: Color(0xFF9AA4B2),
    primary: Color(0xFF4C8DF6),
    primaryDark: Color(0xFF2F6FD8),
    selected: Color(0xFF1B2A44),
    neutral: Color(0xFF9AA4B2),
  );

  static final darkContrast = Palette(
    dark: true,
    page: Color(0xFF000000),
    card: Color(0xFF0B0E13),
    surface: Color(0xFF151A21),
    border: Color(0xFF6B7585),
    text: Color(0xFFFFFFFF),
    hint: Color(0xFFD0D6DF),
    primary: Color(0xFF7FB0FF),
    primaryDark: Color(0xFF5A94F5),
    selected: Color(0xFF223658),
    neutral: Color(0xFFD0D6DF),
  );
}

class AppTheme {
  /// Apariencia activa; la cambia main.dart según las preferencias del usuario
  static Palette p = Palette.light;

  static void apply({required bool dark, required bool highContrast}) {
    p = dark
        ? (highContrast ? Palette.darkContrast : Palette.darkPalette)
        : (highContrast ? Palette.lightContrast : Palette.light);
  }

  static bool get isDark => p.dark;

  // Colores que cambian con la apariencia
  static Color get background => p.card;
  static Color get card => p.card;
  static Color get surface => p.surface;
  static Color get border => p.border;
  static Color get primary => p.primary;
  static Color get primaryDark => p.primaryDark;
  static Color get text => p.text;
  static Color get hint => p.hint;

  // Colores fijos
  static const Color featureBlue = Color(0xFF7E9FDB); // azul claro (series secundarias)
  static const Color featureCyan = Color(0xFF1565C0);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  // Sombras suaves en capas: dan profundidad sin verse pesadas (en oscuro casi no se usan)
  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: const Color(0xFF0F172A).withOpacity(isDark ? 0.0 : 0.025), blurRadius: 6, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get hoverShadow => [
        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.07), blurRadius: 18, offset: const Offset(0, 6)),
      ];

  /// Tema de Material construido con la apariencia activa
  static ThemeData build() => dark;

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: isDark ? Brightness.dark : Brightness.light).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: featureCyan,
      surface: card,
      onSurface: text,
      error: error,
    );
    WidgetStateProperty<Color?> overlay(Color c) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return c.withOpacity(0.14);
          if (s.contains(WidgetState.hovered)) return c.withOpacity(0.07);
          if (s.contains(WidgetState.focused)) return c.withOpacity(0.10);
          return null;
        });
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      canvasColor: card,
      cardColor: card,
      dividerColor: border,
      colorScheme: scheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      // Interacciones más vivas: onda suave, hover tenue y transiciones con zoom
      splashFactory: InkRipple.splashFactory,
      hoverColor: primary.withOpacity(0.045),
      splashColor: primary.withOpacity(0.10),
      highlightColor: primary.withOpacity(0.05),
      focusColor: primary.withOpacity(0.10),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      }),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withOpacity(0.18),
        selectionHandleColor: primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: text.withOpacity(0.92), borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(color: isDark ? const Color(0xFF0D1117) : Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(hint.withOpacity(0.35)),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        textStyle: TextStyle(color: text),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primary),
          overlayColor: overlay(primary),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: ButtonStyle(overlayColor: overlay(primary))),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ).copyWith(
          overlayColor: overlay(Colors.white),
          elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 4 : 0),
          shadowColor: WidgetStateProperty.all(primary.withOpacity(0.45)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border, width: 1),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ).copyWith(overlayColor: overlay(primary)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hoverColor: primary.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: TextStyle(color: hint),
        hintStyle: TextStyle(color: hint),
        errorStyle: const TextStyle(color: error),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
