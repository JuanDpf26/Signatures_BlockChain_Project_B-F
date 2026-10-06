import 'package:flutter/material.dart';

/// Paleta clara estilo Google, usada únicamente en las pantallas de
/// autenticación (Login y Registro). El resto de la app sigue con [AppTheme].
class GoogleAuthTheme {
  // Misma paleta natural de AppTheme para que login y registro combinen con el resto
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF2F6BDB);
  static const Color text = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color primary = Color(0xFF2F6BDB);
  static const Color error = Color(0xFFDC4B4B);
  static const Color success = Color(0xFF1F9D55);
}
