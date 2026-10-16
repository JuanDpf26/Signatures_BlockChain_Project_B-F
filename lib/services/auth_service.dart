import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/js_bridge.dart';
import 'server_wake.dart';
import '../config/app_config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // ID del cliente OAuth de tipo "Aplicación web" (Google Cloud → Credenciales).
  static const _webClientId = '652903067880-d199sdfhh57qlmj52h2miim4kidfbec5.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web: el cliente web directamente.
    clientId: kIsWeb ? _webClientId : null,
    // Android: pide el idToken para el cliente web, que es el que valida el backend
    // (GOOGLE_CLIENT_ID). Además, Google exige un cliente OAuth "Android" con el
    // nombre del paquete y la huella SHA-1 de la llave con que se firma el APK.
    serverClientId: kIsWeb ? null : _webClientId,
  );

  static String get baseUrl => '${AppConfig.apiUrl}/api/auth';

  // ────────────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ────────────────────────────────────────────────
  /// Ruta a la que se vuelve después de iniciar sesión (p. ej. un enlace de verificación del correo)
  static String? pendingRoute;
  static String takeRoute() {
    final r = pendingRoute ?? '/home';
    pendingRoute = null;
    return r;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Lee un dato del token de sesión (sin validarlo: eso lo hace el servidor)
  static Map<String, dynamic>? _payload(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Id del usuario con sesión iniciada
  static Future<String?> currentUserId() async => _payload(await getToken())?['id']?.toString();

  /// Rol de la sesión ('user' o 'admin'). Solo decide qué interfaz se abre;
  /// los permisos los revisa siempre el servidor.
  static Future<String> currentRole() async => _payload(await getToken())?['role']?.toString() ?? 'user';

  /// true si el token ya venció (o no se puede leer)
  static bool isExpired(String? token) {
    final exp = _payload(token)?['exp'];
    if (exp is! num) return true;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000).isBefore(DateTime.now().add(const Duration(minutes: 5)));
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
      await ServerWake.ready();
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
      await ServerWake.ready();
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
    if (kIsWeb) {
      // Limpiar token anterior
      jsSet('googleIdToken', null);

      // Mostrar el botón oficial de Google
      jsCall('triggerGoogleSignIn');

      // Esperar hasta 60 segundos a que el usuario haga clic
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final token = jsGet('googleIdToken');
        if (token != null && token.toString().isNotEmpty) {
          // Ocultar overlay
          jsCall('eval', [
            "document.getElementById('google-btn-container').style.cssText='position:fixed;top:-9999px;left:-9999px;'"
          ]);

          await ServerWake.ready();
          final res = await http.post(
            Uri.parse('$baseUrl/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': token.toString(),
              'isWeb': false, // ya viene como idToken real
            }),
          ).timeout(const Duration(seconds: 15));

          if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
          final data = jsonDecode(res.body);
          if (data['token'] != null) await saveToken(data['token']);
          jsSet('googleIdToken', null);
          return data;
        }
      }
      return {'error': 'Tiempo de espera agotado. Intenta de nuevo.'};
    } else {
      // Móvil — funciona normal con el paquete
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return {'error': 'Cancelado'};
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return {'error': 'Google no entregó el token de identidad. Revisa la configuración del cliente OAuth.'};
      await ServerWake.ready();
      final res = await http.post(
        Uri.parse('$baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken, 'isWeb': false}),
      ).timeout(const Duration(seconds: 15));
      if (res.body.isEmpty) return {'error': 'Servidor sin respuesta'};
      final data = jsonDecode(res.body);
      if (data['token'] != null) await saveToken(data['token']);
      return data;
    }
  } on SocketException {
    return {'error': 'Sin conexión a internet'};
  } catch (e) {
    final msg = e.toString();
    // ApiException 10 = DEVELOPER_ERROR: el paquete o la huella SHA-1 del APK
    // no están registrados en un cliente OAuth de Android en Google Cloud.
    if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
      return {'error': 'Google rechazó esta versión de la app (falta registrar su huella SHA-1 en Google Cloud). Mientras tanto, entra con correo y contraseña.'};
    }
    if (msg.contains('network_error')) return {'error': 'Sin conexión con Google. Revisa tu internet.'};
    return {'error': 'Error con Google: $msg'};
  }
}

  // ────────────────────────────────────────────────
  // FORGOT PASSWORD
  // ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await ServerWake.ready();
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
      await ServerWake.ready();
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
    // Avisa al servidor para dejar de aparecer como conectado (si falla, no importa)
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        await http
            .post(Uri.parse('$baseUrl/logout'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: '{}')
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await deleteToken();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // en la web puede fallar si Google no se inició; la sesión ya quedó cerrada
    }
  }
}