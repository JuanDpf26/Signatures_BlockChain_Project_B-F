import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // clientId solo necesario en iOS/Web, Android usa google-services.json
  );

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api/auth';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/auth';
    return 'http://localhost:3000/api/auth';
    // En producción: 'https://tuapi.com/api/auth'
  }

  // ────────────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ────────────────────────────────────────────────
  // REGISTER
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String documentId,
    required String phone,
    required String captchaToken,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'document_id': documentId,
              'phone': phone,
              'captchaToken': captchaToken,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ────────────────────────────────────────────────
  // LOGIN
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};

      final data = jsonDecode(res.body);

      if (data['token'] != null) {
        await saveToken(data['token']);
      }

      return data;
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ────────────────────────────────────────────────
  // GOOGLE LOGIN
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return {'error': 'Inicio con Google cancelado'};

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) return {'error': 'No se pudo obtener token de Google'};

      final res = await http
          .post(
            Uri.parse('$baseUrl/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};

      final data = jsonDecode(res.body);

      if (data['token'] != null) {
        await saveToken(data['token']);
      }

      return data;
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error con Google: $e'};
    }
  }

  // ────────────────────────────────────────────────
  // FORGOT PASSWORD
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } on SocketException {
      return {'error': 'Sin conexión a internet'};
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ────────────────────────────────────────────────
  // RESET PASSWORD
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  // ────────────────────────────────────────────────
  // LOGOUT
  // ────────────────────────────────────────────────
  static Future<void> logout() async {
    await deleteToken();
    await _googleSignIn.signOut();
  }
}