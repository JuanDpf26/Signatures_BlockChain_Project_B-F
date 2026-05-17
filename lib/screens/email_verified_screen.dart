import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmailVerifiedScreen extends StatefulWidget {
  final bool success;
  const EmailVerifiedScreen({super.key, this.success = true});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.success;
    final color = isSuccess ? Colors.green : Colors.red;
    final icon = isSuccess ? Icons.verified_rounded : Icons.error_rounded;
    final title = isSuccess ? '¡Correo verificado!' : 'Enlace inválido';
    final message = isSuccess
        ? 'Tu cuenta ha sido verificada exitosamente.\nYa puedes iniciar sesión en BlockSign.'
        : 'El enlace de verificación es inválido o ha expirado.\nSolicita un nuevo correo de verificación.';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícono animado
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(icon, color: color, size: 52),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.featureCyan],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BlockSign',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Título
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Mensaje
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.hint,
                      fontSize: 15,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Botón
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess ? AppTheme.primary : AppTheme.surface,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        isSuccess ? 'Iniciar sesión' : 'Volver al inicio',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  if (isSuccess) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security_rounded,
                              color: Colors.green, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tu cuenta está protegida con cifrado de extremo a extremo y registro blockchain.',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}