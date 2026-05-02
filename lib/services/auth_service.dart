import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000/api/auth";
    }
    return "http://localhost:3000/api/auth";
  }

  // 🔐 LOGIN
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      print("LOGIN STATUS: ${res.statusCode}");
      print("LOGIN BODY: ${res.body}");

      if (res.body.isEmpty) {
        return {"error": "Servidor sin respuesta"};
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {"error": "Error de conexión: $e"};
    }
  }

  // 🧾 REGISTER
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String document,
    String phone,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
          "document_id": document,
          "phone": phone
        }),
      );

      print("REGISTER STATUS: ${res.statusCode}");
      print("REGISTER BODY: ${res.body}");

      if (res.body.isEmpty) {
        return {"error": "Servidor no respondió"};
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {"error": "Error de conexión: $e"};
    }
  }

  // 🔑 FORGOT PASSWORD
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      print("FORGOT STATUS: ${res.statusCode}");
      print("FORGOT BODY: ${res.body}");

      if (res.body.isEmpty) {
        return {"error": "Servidor no respondió"};
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {"error": "Error de conexión: $e"};
    }
  }
}