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

  static String get apiUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    return isLocal ? _local : _prod;
  }
}
