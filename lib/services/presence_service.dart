import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import '../widgets/sweet_alert.dart';

/// Presencia: mientras la app está abierta envía un latido cada 45 s con la
/// sección en la que está la persona. Así la consola de administración ve
/// quién está conectado. Si el servidor responde que la sesión fue cerrada
/// por un administrador (o la cuenta se suspendió), borra la sesión local,
/// avisa y vuelve al inicio de sesión.
class PresenceService {
  /// Navegador de la app: el aviso no depende de la pantalla que esté abierta
  static final navigatorKey = GlobalKey<NavigatorState>();
  static Object? _owner;
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
  static void start({required Object owner, required String section, void Function(String message)? onRevoked}) {
    _owner = owner;
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

  /// Detiene los latidos. Con [owner], solo si esa pantalla fue la que los inició.
  static void stop([Object? owner]) {
    if (owner != null && !identical(owner, _owner)) return;
    _owner = null;
    _timer?.cancel();
    _timer = null;
    _life?.dispose();
    _life = null;
    _onRevoked = null;
  }

  static Future<void> _expel(String message) async {
    // La sesión ya no sirve en el servidor: basta con borrarla aquí
    await AuthService.deleteToken();
    AuthService.logout().catchError((_) {}); // limpia Google sin esperar
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Primero al inicio de sesión (la pantalla anterior ya no sirve) y ahí el aviso
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
    await Future.delayed(const Duration(milliseconds: 600));
    final ctx = nav.overlay?.context; // contexto debajo del navegador
    if (ctx == null) return;
    try {
      await SweetAlert.info(ctx, title: 'Tu sesión se cerró', text: message);
    } catch (e) {
      debugPrint('[presencia] aviso: $e');
    }
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
        await _expel(body['error']?.toString() ?? 'Tu sesión se cerró.');
        cb?.call(body['error']?.toString() ?? 'Tu sesión se cerró.');
      }
    } catch (e) {
      debugPrint('[presencia] $e'); // sin conexión: se intenta en el siguiente latido
    }
  }
}
