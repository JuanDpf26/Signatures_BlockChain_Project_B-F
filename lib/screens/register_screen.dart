import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final document = TextEditingController();
  final phone = TextEditingController();

  bool isLoading = false;

  void register(BuildContext context) async {
    setState(() => isLoading = true);

    try {
      final res = await AuthService.register(
        name.text,
        email.text,
        pass.text,
        document.text,
        phone.text,
      );

      print("RESPONSE: $res"); // 🔍 DEBUG

      if (res == null) {
        showBS(context, "Sin respuesta del servidor", isError: true);
        return;
      }

      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(
          context,
          res['message'] ?? "Registro exitoso",
          isError: false,
        );

        // limpiar campos si fue exitoso
        name.clear();
        email.clear();
        pass.clear();
        document.clear();
        phone.clear();
      }
    } catch (e) {
      showBS(context, "Error de conexión: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            BSTextField(
              label: "Nombre",
              hint: "Tu nombre",
              controller: name,
            ),
            const SizedBox(height: 16),

            BSTextField(
              label: "Email",
              hint: "correo@ejemplo.com",
              controller: email,
            ),
            const SizedBox(height: 16),

            BSTextField(
              label: "Cédula",
              hint: "Número de documento",
              controller: document,
            ),
            const SizedBox(height: 16),

            BSTextField(
              label: "Teléfono",
              hint: "3001234567",
              controller: phone,
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
              onPressed: isLoading ? null : () => register(context),
              child: isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : const Text("Registrarse"),
            ),
          ],
        ),
      ),
    );
  }
}