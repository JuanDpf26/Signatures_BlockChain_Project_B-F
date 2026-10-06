import 'package:flutter/material.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';

class EmailVerifiedScreen extends StatefulWidget {
  final bool success;
  const EmailVerifiedScreen({super.key, this.success = true});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  @override
  void initState() {
    super.initState();
    // SweetAlert al abrir la pantalla (después del primer frame)
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSweetAlert());
  }

  Future<void> _showSweetAlert() async {
    if (!mounted) return;

    if (widget.success) {
      final goLogin = await SweetAlert.success(
        context,
        title: '¡Correo verificado!',
        text: 'Tu cuenta ha sido verificada exitosamente.\n'
            'Ya puedes iniciar sesión en BlockSign.',
        confirmText: 'Iniciar sesión',
      );
      // Si pulsa "Iniciar sesión" va al login; si cierra la alerta, se queda en la pantalla
      if (goLogin == true && mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      await SweetAlert.error(
        context,
        title: 'Enlace inválido',
        text: 'El enlace de verificación es inválido, ya fue usado o expiró.\n'
            'Solicita un nuevo correo de verificación.',
        confirmText: 'Entendido',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.success;

    return BSAuthLayout(
      title: ok ? '¡Correo verificado!' : 'Enlace inválido',
      subtitle: ok
          ? 'Tu cuenta ha sido verificada exitosamente. Ya puedes iniciar sesión en BlockSign.'
          : 'El enlace de verificación es inválido, ya fue usado o expiró. Si ya verificaste tu cuenta, simplemente inicia sesión.',
      leading: BSAuthIcon(
        icon: ok ? Icons.verified_rounded : Icons.link_off_rounded,
        color: ok ? BSColors.success : BSColors.danger,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ok
            ? const BSInfoBanner(
                title: 'Tu cuenta está protegida.',
                text: 'Cada documento que firmes queda cifrado con SHA-256 y registrado en blockchain.',
                color: BSColors.success,
                icon: Icons.security_rounded,
              )
            : const BSInfoBanner(
                title: '¿Necesitas un enlace nuevo?',
                text: 'Intenta registrarte de nuevo con el mismo correo y te enviaremos otro enlace de verificación.',
                color: BSColors.warning,
                icon: Icons.mail_outline_rounded,
              ),
        const SizedBox(height: 24),
        BSAuthButton(
          label: ok ? 'Iniciar sesión' : 'Ir a iniciar sesión',
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        if (!ok) ...[
          const SizedBox(height: 18),
          BSAuthSwitch(
            question: '¿Aún no tienes cuenta?',
            action: 'Regístrate',
            onTap: () => Navigator.pushReplacementNamed(context, '/register'),
          ),
        ],
      ]),
    );
  }
}
