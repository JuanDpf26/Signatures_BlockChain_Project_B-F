import 'package:flutter/foundation.dart';

/// Dirección del backend.
///
/// POR AHORA TODO ES LOCAL: la app usa http://localhost:3000 siempre.
/// - Usar el servidor publicado:  --dart-define=IS_LOCAL=false
/// - Forzar una URL concreta:     --dart-define=API_URL=https://...
class AppConfig {
  static const String _apiFromEnv = String.fromEnvironment('API_URL');
  static const String _isLocalEnv = String.fromEnvironment('IS_LOCAL');

  static const String _prod = 'https://blocksign-backend.onrender.com';

  static String get _local {
    if (kIsWeb) return 'http://localhost:3000';
    // El emulador de Android ve tu computador en 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  /// Local por defecto (también en release) mientras el proyecto se trabaja en local
  static bool get isLocal => _isLocalEnv != 'false';

  /// Dirección pública de la web (donde vive el visor de PDF /visor/)
  static const String _webFromEnv = String.fromEnvironment('WEB_URL');
  static String get webUrl => _webFromEnv.isNotEmpty ? _webFromEnv : 'https://signatures-block-chain-project-b-f.vercel.app';

  /// Visor de PDF propio (pdf.js): nítido, con zoom, funciona igual en celular y computador
  static String visorPdf(String fileUrl) => '${kIsWeb ? '' : webUrl}/visor/index.html?file=${Uri.encodeComponent(fileUrl)}';

  /// Visor de Word propio (docx-preview): lee el archivo en el navegador, sin servicios externos
  static String visorWord(String fileUrl) => '${kIsWeb ? '' : webUrl}/visor/word.html?file=${Uri.encodeComponent(fileUrl)}';

  /// Visor de Word de Microsoft Office (el archivo debe ser público)
  static String visorOffice(String fileUrl) => 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(fileUrl)}';

  /// Visor de Google (alternativa para PDF y Word)
  static String visorGoogle(String fileUrl) => 'https://docs.google.com/viewer?url=${Uri.encodeComponent(fileUrl)}&embedded=true';

  static String get apiUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    return isLocal ? _local : _prod;
  }
}
