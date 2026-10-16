import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'server_wake.dart';

/// Firma con varios firmantes y PDF firmado
class CosignService {
  /// Convierte la respuesta en un mapa. Si el servidor devuelve una página
  /// (por ejemplo, porque todavía no tiene esta función), da un mensaje claro.
  static Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return {'error': 'Servidor sin respuesta'};
    if (!body.startsWith('{')) {
      return {
        'error': res.statusCode == 404
            ? 'El servidor todavía no tiene esta función. Se activa cuando se publique la nueva versión del backend.'
            : 'El servidor respondió algo inesperado (código ${res.statusCode}). Intenta de nuevo en un momento.',
      };
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400 && data['error'] == null) data['error'] = 'Error ${res.statusCode}';
    return data;
  }

  static String get _signing => '${AppConfig.apiUrl}/api/signing';
  static String get _docs => '${AppConfig.apiUrl}/api/documents';

  static Future<Map<String, dynamic>> _post(String url, [Map<String, dynamic>? body]) async {
    try {
      await ServerWake.ready();
      final token = await AuthService.getToken();
      final res = await http
          .post(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 60));
      return _decode(res);
    } catch (e) {
      return {'error': 'No se pudo conectar con el servidor. Revisa tu conexión.'};
    }
  }

  /// Pide la firma de varias personas, en el orden de la lista
  static Future<Map<String, dynamic>> request(String docId, List<String> signers, {String? message}) =>
      _post('$_signing/$docId/request', {'signers': signers, if (message != null && message.trim().isNotEmpty) 'message': message.trim()});

  /// Firmar o rechazar cuando es tu turno
  static Future<Map<String, dynamic>> respond(String docId, {required bool sign, String? comment}) =>
      _post('$_signing/$docId/cosign', {'decision': sign ? 'sign' : 'reject', if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()});

  static Future<Map<String, dynamic>> cancel(String docId) => _post('$_signing/$docId/request/cancel');

  static Future<Map<String, dynamic>> retryRegister(String docId) => _post('$_signing/$docId/request/register');

  /// Enlace (temporal) del PDF con sello, QR y certificado
  static Future<Map<String, dynamic>> signedPdf(String docId) async {
    try {
      await ServerWake.ready();
      final token = await AuthService.getToken();
      final res = await http.get(Uri.parse('$_docs/$docId/signed-pdf'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 60));
      return _decode(res);
    } catch (e) {
      return {'error': 'No se pudo conectar con el servidor. Revisa tu conexión.'};
    }
  }
}
