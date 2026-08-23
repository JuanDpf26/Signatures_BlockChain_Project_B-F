import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class DocumentService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api/documents';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/documents';
    return 'http://localhost:3000/api/documents';
  }

  static String get signingUrl {
    if (kIsWeb) return 'http://localhost:3000/api/signing';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/signing';
    return 'http://localhost:3000/api/signing';
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  // SUBIR DOCUMENTO
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
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error al subir: $e'};
    }
  }

  // LISTAR DOCUMENTOS
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
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // OBTENER DOCUMENTO
  static Future<Map<String, dynamic>> getDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$baseUrl/$docId'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // FIRMAR DOCUMENTO — llama al signing controller
  static Future<Map<String, dynamic>> signDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$signingUrl/$docId/sign'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error al firmar: $e'};
    }
  }

  // VERIFICAR DOCUMENTO
  static Future<Map<String, dynamic>> verifyDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse('$signingUrl/$docId/verify'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error al verificar: $e'};
    }
  }

  // RE-ANALIZAR CON GROQ
  static Future<Map<String, dynamic>> reanalyzeDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/$docId/reanalyze'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ACTUALIZAR METADATOS
  static Future<Map<String, dynamic>> updateDocumentMeta({
    required String docId, String? category, List<String>? tags, String? title,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (category != null) body['category'] = category;
      if (tags != null) body['tags'] = tags;
      if (title != null) body['title'] = title;
      final res = await http.patch(Uri.parse('$baseUrl/$docId'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ELIMINAR DOCUMENTO
  static Future<Map<String, dynamic>> deleteDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/$docId'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ESTADÍSTICAS
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse('$baseUrl/stats'), headers: headers).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }
}