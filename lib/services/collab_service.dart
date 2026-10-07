import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Bandeja de entrada (/api/inbox) y equipos (/api/teams)
class CollabService {
  static String get _base => AppConfig.apiUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  static Future<Map<String, dynamic>> _send(Future<http.Response> Function(Map<String, String> h) call) async {
    try {
      final res = await call(await _headers()).timeout(const Duration(seconds: 25));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(res.body);
      if (data is! Map) return {'error': 'Respuesta inesperada del servidor'};
      final map = Map<String, dynamic>.from(data);
      if (res.statusCode >= 400 && !map.containsKey('error')) map['error'] = 'Error ${res.statusCode}';
      return map;
    } catch (e) {
      return {'error': 'No se pudo conectar con el servidor: $e'};
    }
  }

  // ── Bandeja ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> inbox({String box = 'received', String? q}) => _send((h) => http.get(
        Uri.parse('$_base/api/inbox').replace(queryParameters: {'box': box, if (q != null && q.isNotEmpty) 'q': q}),
        headers: h,
      ));

  static Future<Map<String, dynamic>> inboxSummary() => _send((h) => http.get(Uri.parse('$_base/api/inbox/summary'), headers: h));

  static Future<Map<String, dynamic>> inboxItem(String id) => _send((h) => http.get(Uri.parse('$_base/api/inbox/$id'), headers: h));

  static Future<Map<String, dynamic>> respond(String id, {required bool approve, String? comment}) => _send((h) => http.post(
        Uri.parse('$_base/api/inbox/$id/respond'),
        headers: h,
        body: jsonEncode({'decision': approve ? 'approved' : 'rejected', if (comment != null) 'comment': comment}),
      ));

  static Future<Map<String, dynamic>> archive(String id, {bool archived = true}) => _send((h) => http.post(
        Uri.parse('$_base/api/inbox/$id/archive'),
        headers: h,
        body: jsonEncode({'archived': archived}),
      ));

  // ── Equipos ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> teams() => _send((h) => http.get(Uri.parse('$_base/api/teams'), headers: h));

  static Future<Map<String, dynamic>> team(String id) => _send((h) => http.get(Uri.parse('$_base/api/teams/$id'), headers: h));

  static Future<Map<String, dynamic>> createTeam(String name, String description) => _send((h) => http.post(
        Uri.parse('$_base/api/teams'),
        headers: h,
        body: jsonEncode({'name': name, 'description': description}),
      ));

  static Future<Map<String, dynamic>> updateTeam(String id, {String? name, String? description}) => _send((h) => http.patch(
        Uri.parse('$_base/api/teams/$id'),
        headers: h,
        body: jsonEncode({if (name != null) 'name': name, if (description != null) 'description': description}),
      ));

  static Future<Map<String, dynamic>> deleteTeam(String id) => _send((h) => http.delete(Uri.parse('$_base/api/teams/$id'), headers: h));

  static Future<Map<String, dynamic>> searchUsers(String q) => _send((h) => http.get(
        Uri.parse('$_base/api/teams/users/search').replace(queryParameters: {'q': q}),
        headers: h,
      ));

  static Future<Map<String, dynamic>> addMember(String teamId, String email, {bool admin = false}) => _send((h) => http.post(
        Uri.parse('$_base/api/teams/$teamId/members'),
        headers: h,
        body: jsonEncode({'email': email, 'role': admin ? 'admin' : 'member'}),
      ));

  static Future<Map<String, dynamic>> setRole(String teamId, String userId, {required bool admin}) => _send((h) => http.patch(
        Uri.parse('$_base/api/teams/$teamId/members/$userId'),
        headers: h,
        body: jsonEncode({'role': admin ? 'admin' : 'member'}),
      ));

  static Future<Map<String, dynamic>> removeMember(String teamId, String userId) =>
      _send((h) => http.delete(Uri.parse('$_base/api/teams/$teamId/members/$userId'), headers: h));
}
