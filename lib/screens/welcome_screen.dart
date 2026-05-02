import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "BlockSign",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Firma digital segura con blockchain",
              style: TextStyle(color: AppTheme.hint),
            ),
            const SizedBox(height: 40),

            FeatureCard(
              icon: Icons.lock,
              iconColor: AppTheme.featureBlue,
              iconBg: AppTheme.featureBlue.withOpacity(0.2),
              title: "Seguridad",
              description: "Protección avanzada de documentos",
            ),

            const SizedBox(height: 12),

            FeatureCard(
              icon: Icons.cloud,
              iconColor: AppTheme.featureCyan,
              iconBg: AppTheme.featureCyan.withOpacity(0.2),
              title: "Cloud",
              description: "Accede desde cualquier dispositivo",
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text("Iniciar sesión"),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text("Crear cuenta"),
            ),
          ],
        ),
      ),
    );
  }
}