import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class DocumentService {
  static String get baseUrl => '${AppConfig.apiUrl}/api/documents';
  static String get signingUrl => '${AppConfig.apiUrl}/api/signing';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  static Future<Map<String, dynamic>> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName, contentType: MediaType.parse(mimeType)));
      final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 30)));
      if (response.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Error al subir: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDocuments({
    String? search, String? category, String? status, String? ext, int page = 1,
  }) async {
    try {
      final headers = await _authHeaders();
      final params = <String, String>{
        'page': page.toString(), 'limit': '20',
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
        if (status != null && status.isNotEmpty) 'status': status,
        if (ext != null && ext.isNotEmpty) 'ext': ext,
      };
      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$baseUrl/$docId'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> signDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(Uri.parse('$signingUrl/$docId/sign'), headers: headers).timeout(const Duration(seconds: 60));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error al firmar: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$signingUrl/$docId/verify'), headers: headers).timeout(const Duration(seconds: 30));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error al verificar: $e'};
    }
  }

  /// Estado de la firma en blockchain (sending | confirming | confirmed | failed)
  static Future<Map<String, dynamic>> getSigningStatus(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$signingUrl/$docId/status'), headers: headers).timeout(const Duration(seconds: 20));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error al consultar el estado: $e'};
    }
  }

  /// Verificación pública por huella SHA-256 (no necesita sesión; el archivo no se sube)
  static Future<Map<String, dynamic>> verifyByHash(String hash) async {
    try {
      final res = await http.get(Uri.parse('$signingUrl/public/${hash.trim().toLowerCase()}')).timeout(const Duration(seconds: 30));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'No se pudo conectar con el servidor: $e'};
    }
  }

  /// Datos de la red Sepolia y del contrato
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final res = await http.get(Uri.parse('$signingUrl/network')).timeout(const Duration(seconds: 20));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'connected': false, 'error': '$e'};
    }
  }

  static Future<Map<String, dynamic>> reanalyzeDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(Uri.parse('$baseUrl/$docId/reanalyze'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  /// Edita los datos del documento. Solo se envían los campos que cambiaron.
  /// Campos: title, description, category, tags, confidentiality.
  static Future<Map<String, dynamic>> updateDocumentMeta({
    required String docId, String? category, List<String>? tags, String? title, String? description, String? confidentiality,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (category != null) body['category'] = category;
      if (tags != null) body['tags'] = tags;
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (confidentiality != null) body['confidentiality'] = confidentiality;
      final res = await http.patch(Uri.parse('$baseUrl/$docId'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  /// Sube una nueva versión del archivo (solo si el documento aún no está firmado).
  /// analyze=0: la app lanza luego el análisis con IA mostrando el proceso.
  static Future<Map<String, dynamic>> replaceFile({
    required String docId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/$docId/file?analyze=0'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName, contentType: MediaType.parse(mimeType)));
      final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 45)));
      if (response.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(response.body);
      if (response.statusCode >= 400 && data is Map && !data.containsKey('error')) return {'error': 'Error ${response.statusCode}'};
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      return {'error': 'Error al subir la nueva versión: $e'};
    }
  }

  /// Envía el documento por correo (adjunto o enlace) a 1–5 personas
  static Future<Map<String, dynamic>> sendByEmail({
    required String docId,
    required List<String> recipients,
    List<String> teams = const [],
    bool review = false,
    String? subject,
    String? message,
    bool attach = true,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'recipients': recipients,
        'teams': teams,
        'kind': review ? 'review' : 'info',
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        'attach': attach,
      };
      final res = await http.post(Uri.parse('$baseUrl/$docId/send'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(res.body);
      if (data is! Map) return {'error': 'Respuesta inesperada del servidor'};
      if (res.statusCode >= 400 && !data.containsKey('error')) return {'error': 'Error ${res.statusCode}'};
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return {'error': 'No se pudo enviar: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/$docId'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$baseUrl/stats'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }
}