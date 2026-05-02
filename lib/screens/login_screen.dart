import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final email = TextEditingController();
  final pass = TextEditingController();

  void login(BuildContext context) async {
    final res = await AuthService.login(email.text, pass.text);

    if (res['token'] != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showBS(context, res['error'] ?? "Error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar sesión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            BSTextField(
              label: "Email",
              hint: "correo@ejemplo.com",
              controller: email,
            ),
            const SizedBox(height: 16),
            BSTextField(
              label: "Contraseña",
              hint: "••••••",
              controller: pass,
              obscureText: true,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => login(context),
              child: const Text("Entrar"),
            ),

            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot'),
              child: const Text("¿Olvidaste tu contraseña?"),
            ),

            const SizedBox(height: 20),

            BSDivider(),

            const SizedBox(height: 20),

            BSGoogleButton(
              onPressed: () {
                showBS(context, "Google login próximamente", isError: false);
              },
            ),
          ],
        ),
      ),
    );
  }
}