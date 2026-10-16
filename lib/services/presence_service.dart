import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Presencia: mientras la app está abierta envía un latido cada 45 s con la
/// sección en la que está la persona. Así la consola de administración ve
/// quién está conectado. Si el servidor responde que la sesión fue cerrada
/// por un administrador (o la cuenta se suspendió), avisa con [onRevoked].
class PresenceService {
  static const _every = Duration(seconds: 45);
  static Timer? _timer;
  static AppLifecycleListener? _life;
  static String _section = '';
  static void Function(String message)? _onRevoked;
  static bool _revoked = false;

  static String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      _ => 'web',
    };
  }

  /// Empieza (o retoma) los latidos. [onRevoked] recibe el mensaje del servidor.
  static void start({required String section, required void Function(String message) onRevoked}) {
    _section = section;
    _onRevoked = onRevoked;
    _revoked = false;
    _timer?.cancel();
    _timer = Timer.periodic(_every, (_) => _beat());
    _life ??= AppLifecycleListener(
      onResume: () {
        _beat();
        _timer?.cancel();
        _timer = Timer.periodic(_every, (_) => _beat());
      },
      onPause: () => _timer?.cancel(),
    );
    _beat();
  }

  /// Cambia la sección que se informa (sin esperar al siguiente latido)
  static void section(String s) {
    if (s == _section) return;
    _section = s;
    _beat();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _life?.dispose();
    _life = null;
    _onRevoked = null;
  }

  static Future<void> _beat() async {
    if (_revoked) return;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;
      final res = await http
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/auth/heartbeat'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'section': _section, 'platform': platform}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 401 && res.statusCode != 403) return;
      Map<String, dynamic> body = {};
      try {
        body = Map<String, dynamic>.from(jsonDecode(res.body));
      } catch (_) {}
      final code = body['code']?.toString();
      // Solo se expulsa por decisión del administrador; un token vencido lo maneja cada pantalla
      if (code == 'session_revoked' || code == 'suspended') {
        _revoked = true;
        final cb = _onRevoked;
        stop();
        cb?.call(body['error']?.toString() ?? 'Tu sesión se cerró.');
      }
    } catch (_) {
      // sin conexión: se intenta en el siguiente latido
    }
  }
}
