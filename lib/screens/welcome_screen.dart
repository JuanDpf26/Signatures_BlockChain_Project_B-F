import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);

    if (isWeb) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: ResponsiveLayout(
          maxWidth: 520,
          child: _WelcomeContent(isWeb: true),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _WelcomeContent(isWeb: false),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  final bool isWeb;
  const _WelcomeContent({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 48 : 24,
          vertical: isWeb ? 60 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isWeb) ...[
              // Logo solo en móvil (en web está en el panel izquierdo)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.featureCyan],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 28),
              const Text(
                'BlockSign',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Firma digital segura\ncon blockchain.',
                style: TextStyle(
                  color: AppTheme.hint,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
            ],

            if (isWeb) ...[
              const Text(
                'Bienvenido de nuevo',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accede a tu cuenta para gestionar\ntus documentos digitales.',
                style: TextStyle(color: AppTheme.hint, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),
            ],

            // Feature cards solo en móvil
            if (!isWeb) ...[
              _FeatureRow(
                icon: Icons.lock_rounded,
                iconColor: AppTheme.primary,
                title: 'Criptografía asimétrica',
                desc: 'PKI + SHA-256',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.link_rounded,
                iconColor: AppTheme.featureCyan,
                title: 'Trazabilidad blockchain',
                desc: 'Registro inmutable',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.verified_rounded,
                iconColor: Colors.green,
                title: 'Validez legal',
                desc: 'Estándares internacionales',
              ),
              const SizedBox(height: 40),
            ],

            // Botones
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Iniciar sesión',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border, width: 1.5),
                  foregroundColor: AppTheme.text,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Crear cuenta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Universidad Manuela Beltrán · 2025',
                style: TextStyle(
                    color: AppTheme.hint.withOpacity(0.5), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text(desc,
                  style: const TextStyle(
                      color: AppTheme.hint, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}