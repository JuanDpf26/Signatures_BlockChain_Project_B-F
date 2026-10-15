import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Colores de las pantallas de autenticación (Login y Registro). Siguen la
/// apariencia activa (clara u oscura) para combinar con el resto de la app.
class GoogleAuthTheme {
  static Color get background => AppTheme.card;
  static Color get surfaceAlt => AppTheme.surface;
  static Color get border => AppTheme.border;
  static Color get borderFocus => AppTheme.primary;
  static Color get text => AppTheme.text;
  static Color get textSecondary => AppTheme.hint;
  static Color get primary => AppTheme.primary;
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
}
