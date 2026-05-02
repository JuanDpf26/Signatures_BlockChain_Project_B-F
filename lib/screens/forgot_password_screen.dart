import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

void showBS(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ),
  );
}

class ForgotPasswordScreen extends StatelessWidget {
  ForgotPasswordScreen({super.key});

  final email = TextEditingController();

  void send(BuildContext context) async {
    final res = await AuthService.forgotPassword(email.text);

    showBS(context, res['message'] ?? "Correo enviado", isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recuperar contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            BSTextField(
              label: "Email",
              hint: "correo@ejemplo.com",
              controller: email,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => send(context),
              child: const Text("Enviar"),
            ),
          ],
        ),
      ),
    );
  }
}