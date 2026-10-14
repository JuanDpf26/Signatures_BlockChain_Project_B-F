import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// El backend está en el plan gratuito de Render: si pasa ~15 min sin uso se
/// apaga y la primera petición tarda cerca de un minuto en despertarlo.
///
/// Todas las peticiones con sesión esperan aquí a que el servidor responda
/// (una sola consulta a /health compartida), en vez de fallar por tiempo de
/// espera. Cuando el servidor ya respondió hace poco, no se espera nada.
class ServerWake {
  static Future<bool>? _pending;
  static DateTime? _lastOk;
  static const _fresh = Duration(minutes: 10);
  static const _giveUp = Duration(seconds: 80);

  /// true mientras el servidor tarda en despertar (para mostrar un aviso)
  static final ValueNotifier<bool> waking = ValueNotifier(false);

  static bool get isAwake => _lastOk != null && DateTime.now().difference(_lastOk!) < _fresh;

  /// Espera a que el servidor esté despierto (o a que se agote el tiempo).
  static Future<bool> ready() {
    if (isAwake) return Future.value(true);
    return _pending ??= _ping().whenComplete(() => _pending = null);
  }

  /// Marca el servidor como despierto (cualquier respuesta correcta sirve).
  static void markAwake() => _lastOk = DateTime.now();

  static Future<bool> _ping() async {
    // Si en 2 s no responde, se avisa que se está activando
    final hint = Timer(const Duration(seconds: 2), () => waking.value = true);
    try {
      return await _loop();
    } finally {
      hint.cancel();
      waking.value = false;
    }
  }

  static Future<bool> _loop() async {
    final url = Uri.parse('${AppConfig.apiUrl}/health');
    final deadline = DateTime.now().add(_giveUp);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 25));
        if (res.statusCode == 200) {
          markAwake();
          return true;
        }
      } catch (_) {
        // dormido o sin red: se reintenta
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }
}
