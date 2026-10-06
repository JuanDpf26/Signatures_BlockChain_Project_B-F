import 'package:flutter/foundation.dart';

/// Dirección del backend.
///
/// - `flutter run` (debug)           → backend LOCAL (http://localhost:3000)
/// - `flutter build web --release`   → backend PUBLICADO (Render)
/// - Forzar una URL:   --dart-define=API_URL=https://...
/// - Forzar local/prod: --dart-define=IS_LOCAL=true | false
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

  /// Local en modo debug, publicado en release (salvo que IS_LOCAL diga otra cosa)
  static bool get isLocal => _isLocalEnv.isEmpty ? !kReleaseMode : _isLocalEnv == 'true';

  static String get apiUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    return isLocal ? _local : _prod;
  }
}
