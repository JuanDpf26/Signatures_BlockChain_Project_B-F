import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Registro de auditoría del usuario (GET /api/audit)
class AuditService {
  static Future<Map<String, dynamic>> getMyAudit({String? action, String? result, int limit = 100}) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('${AppConfig.apiUrl}/api/audit').replace(queryParameters: {
        'limit': '$limit',
        if (action != null && action.isNotEmpty) 'action': action,
        if (result != null && result.isNotEmpty) 'result': result,
      });
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'error': 'Respuesta inesperada'};
    } catch (e) {
      return {'error': 'No se pudo consultar la auditoría: $e'};
    }
  }

  /// Pide un enlace temporal para descargar el registro (format: csv | html)
  static Future<Map<String, dynamic>> exportLink({String format = 'csv', String period = '30d', String? action, String? result}) async {
    try {
      final token = await AuthService.getToken();
      final res = await http
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/audit/export-link'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'format': format,
              'period': period,
              if (action != null && action.isNotEmpty) 'action': action,
              if (result != null && result.isNotEmpty) 'result': result,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'error': 'Respuesta inesperada'};
    } catch (e) {
      return {'error': 'No se pudo preparar la descarga: $e'};
    }
  }
}
