import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class ProfileService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api/profile';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/profile';
    return 'http://localhost:3000/api/profile';
  }

  static String get signaturesUrl {
    if (kIsWeb) return 'http://localhost:3000/api/signatures';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/signatures';
    return 'http://localhost:3000/api/signatures';
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  // GET PERFIL
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _headers();
      final res = await http.get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ACTUALIZAR PERFIL
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
  }) async {
    try {
      final headers = await _headers();
      final res = await http.patch(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({'name': name, 'phone': phone}),
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // SUBIR AVATAR
  static Future<Map<String, dynamic>> uploadAvatar(Uint8List imageBytes, String mimeType) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/avatar'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes(
          'avatar',
          imageBytes,
          filename: 'avatar.jpg',
          contentType: MediaType.parse(mimeType),
        ));
      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 30)));
      if (response.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(response.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error al subir imagen: $e'};
    }
  }

  // CAMBIAR CONTRASEÑA
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _headers();
      final res = await http.patch(
        Uri.parse('$baseUrl/password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ELIMINAR CUENTA
  static Future<Map<String, dynamic>> deleteAccount({String? password}) async {
    try {
      final headers = await _headers();
      final res = await http.delete(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({'password': password}),
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // GUARDAR FIRMA
  static Future<Map<String, dynamic>> saveSignature(String base64Image) async {
    try {
      final headers = await _headers();
      final res = await http.post(
        Uri.parse(signaturesUrl),
        headers: headers,
        body: jsonEncode({'signatureBase64': base64Image}),
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // OBTENER FIRMA
  static Future<Map<String, dynamic>> getSignature() async {
    try {
      final headers = await _headers();
      final res = await http.get(Uri.parse(signaturesUrl), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }

  // ELIMINAR FIRMA
  static Future<Map<String, dynamic>> deleteSignature() async {
    try {
      final headers = await _headers();
      final res = await http.delete(Uri.parse(signaturesUrl), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error: $e'};
    }
  }
}