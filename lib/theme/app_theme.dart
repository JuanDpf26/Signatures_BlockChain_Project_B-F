import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta institucional (mockups): azul sólido profundo, rojo, ámbar,
  // verde y gris para estados. Superficies blancas y planas.
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F8FB);
  static const Color border = Color(0xFFE3E7EE);
  static const Color primary = Color(0xFF0B45B5);
  static const Color primaryDark = Color(0xFF08368F);
  static const Color text = Color(0xFF1B1F27);
  static const Color hint = Color(0xFF5F6670);
  static const Color featureBlue = Color(0xFF7E9FDB); // azul claro (series secundarias)
  static const Color featureCyan = Color(0xFF1565C0);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);

  // Sombras suaves en capas: dan profundidad sin verse pesadas
  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.025), blurRadius: 6, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get hoverShadow => [
        BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 6)),
      ];

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: featureCyan,
      surface: Colors.white,
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
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: text.withOpacity(0.92), borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(hint.withOpacity(0.35)),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
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
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: border, width: 1),
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
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(color: hint),
        hintStyle: const TextStyle(color: hint),
        errorStyle: const TextStyle(color: error),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
