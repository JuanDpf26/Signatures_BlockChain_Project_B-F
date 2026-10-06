import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.forgotPassword(_email.text.trim());
      if (!mounted) return;
      if (res.containsKey('error')) {
        setState(() => _isLoading = false); // que el botón no siga girando detrás de la alerta
        await SweetAlert.error(
          context,
          title: 'No se pudo enviar',
          text: res['error'].toString(),
        );
      } else {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
        await SweetAlert.success(
          context,
          title: 'Revisa tu correo',
          text: 'Si ${_email.text.trim()} está registrado, te enviamos un enlace '
              'para restablecer tu contraseña. Expira en 1 hora.',
          confirmText: 'Entendido',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return BSAuthLayout(
        title: 'Revisa tu correo',
        subtitle: 'Si ${_email.text.trim()} está registrado, recibirás un enlace para restablecer tu contraseña en los próximos minutos.',
        leading: const BSAuthIcon(icon: Icons.mark_email_read_rounded, color: BSColors.success),
        showBack: true,
        onBack: () => Navigator.pushReplacementNamed(context, '/login'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BSInfoBanner(
            title: 'El enlace expira en 1 hora.',
            text: 'Revisa también la carpeta de spam o correo no deseado.',
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 24),
          BSAuthButton(label: 'Volver a iniciar sesión', onPressed: () => Navigator.pushReplacementNamed(context, '/login')),
          const SizedBox(height: 18),
          BSAuthSwitch(
            question: '¿No te llegó?',
            action: 'Enviar de nuevo',
            onTap: () => setState(() => _emailSent = false),
          ),
        ]),
      );
    }

    return BSAuthLayout(
      title: 'Recuperar contraseña',
      subtitle: 'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
      leading: const BSAuthIcon(icon: Icons.key_rounded),
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BSTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: _email,
            icon: Icons.email_outlined,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            light: true,
          ),
          const SizedBox(height: 24),
          BSAuthButton(label: 'Enviar enlace', loading: _isLoading, onPressed: _submit),
          const SizedBox(height: 24),
          BSAuthSwitch(
            question: '¿Recordaste tu contraseña?',
            action: 'Inicia sesión',
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ]),
      ),
    );
  }
}
