import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Cliente del asistente "Sign IA" (POST /api/agent/chat)
class AgentService {
  static String get _url => '${AppConfig.apiUrl}/api/agent/chat';

  /// [messages]: historial [{role: 'user'|'assistant', content: '...'}]
  static Future<Map<String, dynamic>> chat(
    List<Map<String, String>> messages, {
    String? documentId,
    String? documentTitle,
  }) async {
    try {
      final token = await AuthService.getToken();
      final res = await http
          .post(
            Uri.parse(_url),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages,
              if (documentId != null) 'context': {'documentId': documentId, 'documentTitle': documentTitle},
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (res.body.isEmpty) return {'error': 'El servidor no respondió'};
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'error': 'Respuesta inesperada'};
    } catch (e) {
      return {'error': 'No se pudo conectar con el asistente: $e'};
    }
  }
}
