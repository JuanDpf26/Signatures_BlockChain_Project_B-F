import 'package:flutter/material.dart';

/// Paleta clara estilo Google, usada únicamente en las pantallas de
/// autenticación (Login y Registro). El resto de la app sigue con [AppTheme].
class GoogleAuthTheme {
  // Misma paleta natural de AppTheme para que login y registro combinen con el resto
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F8FB);
  static const Color border = Color(0xFFE3E7EE);
  static const Color borderFocus = Color(0xFF0B45B5);
  static const Color text = Color(0xFF1B1F27);
  static const Color textSecondary = Color(0xFF5F6670);
  static const Color primary = Color(0xFF0B45B5);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
}
