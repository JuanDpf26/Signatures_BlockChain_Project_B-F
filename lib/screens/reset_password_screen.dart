import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _isLoading = false;
  bool _done = false;

  bool get _hasToken => widget.token != null && widget.token!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Actualiza la lista de requisitos mientras se escribe
    _newPass.addListener(() => setState(() {}));
    _confirmPass.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  void _goLogin() => Navigator.pushReplacementNamed(context, '/login');

  Future<void> _submit() async {
    if (!_hasToken) {
      await SweetAlert.error(context, title: 'Enlace inválido', text: 'El enlace no tiene un token válido. Solicita uno nuevo.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_newPass.text != _confirmPass.text) {
      await SweetAlert.warning(context, title: 'Las contraseñas no coinciden', text: 'Escribe la misma contraseña en ambos campos.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await AuthService.resetPassword(widget.token!, _newPass.text);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (res.containsKey('error')) {
        final msg = res['error'].toString();
        await SweetAlert.error(
          context,
          title: 'No se pudo cambiar',
          text: msg.toLowerCase().contains('token')
              ? 'El enlace es inválido o ya expiró (dura 1 hora). Solicita uno nuevo.'
              : msg,
        );
      } else {
        setState(() => _done = true);
        final goLogin = await SweetAlert.success(
          context,
          title: '¡Contraseña actualizada!',
          text: 'Ya puedes iniciar sesión con tu nueva contraseña.',
          confirmText: 'Iniciar sesión',
        );
        if (goLogin == true && mounted) _goLogin();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enlace sin token
    if (!_hasToken) {
      return BSAuthLayout(
        title: 'Enlace inválido',
        subtitle: 'Este enlace para restablecer la contraseña no es válido o está incompleto.',
        leading: const BSAuthIcon(icon: Icons.link_off_rounded, color: BSColors.danger),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BSInfoBanner(
            title: 'Solicita un enlace nuevo.',
            text: 'Desde "¿Olvidaste tu contraseña?" te enviaremos otro correo. Cada enlace dura 1 hora.',
            color: BSColors.warning,
            icon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: 24),
          BSAuthButton(label: 'Solicitar nuevo enlace', onPressed: () => Navigator.pushReplacementNamed(context, '/forgot')),
          const SizedBox(height: 18),
          BSAuthSwitch(question: '¿Recordaste tu contraseña?', action: 'Inicia sesión', onTap: _goLogin),
        ]),
      );
    }

    // Contraseña cambiada
    if (_done) {
      return BSAuthLayout(
        title: '¡Contraseña actualizada!',
        subtitle: 'Ya puedes iniciar sesión con tu nueva contraseña.',
        leading: const BSAuthIcon(icon: Icons.check_circle_rounded, color: BSColors.success),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BSInfoBanner(
            title: 'Tu cuenta está protegida.',
            text: 'Si no fuiste tú quien hizo este cambio, recupera tu contraseña de inmediato.',
            color: BSColors.success,
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 24),
          BSAuthButton(label: 'Ir al inicio de sesión', onPressed: _goLogin),
        ]),
      );
    }

    // Formulario
    final p = _newPass.text;
    return BSAuthLayout(
      title: 'Nueva contraseña',
      subtitle: 'Crea una contraseña segura para recuperar el acceso a tu cuenta.',
      leading: const BSAuthIcon(icon: Icons.lock_reset_rounded),
      showBack: true,
      onBack: _goLogin,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BSTextField(
            label: 'Nueva contraseña',
            hint: '8+ caracteres, mayúscula y número',
            controller: _newPass,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: Validators.password,
            light: true,
          ),
          const SizedBox(height: 14),
          BSTextField(
            label: 'Confirmar contraseña',
            hint: 'Repite tu nueva contraseña',
            controller: _confirmPass,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (v) => Validators.confirmPassword(v, _newPass.text),
            light: true,
          ),
          const SizedBox(height: 16),

          // Requisitos en vivo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BSColors.page,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tu contraseña debe tener:',
                  style: TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _Rule(ok: p.length >= 8, text: 'Mínimo 8 caracteres'),
              _Rule(ok: RegExp(r'[A-Z]').hasMatch(p), text: 'Una letra mayúscula'),
              _Rule(ok: RegExp(r'[0-9]').hasMatch(p), text: 'Un número'),
              _Rule(ok: p.isNotEmpty && p == _confirmPass.text, text: 'Ambas contraseñas iguales'),
            ]),
          ),
          const SizedBox(height: 24),

          BSAuthButton(label: 'Cambiar contraseña', loading: _isLoading, onPressed: _submit),
          const SizedBox(height: 18),
          BSAuthSwitch(question: '¿Recordaste tu contraseña?', action: 'Inicia sesión', onTap: _goLogin),
        ]),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final bool ok;
  final String text;
  const _Rule({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: ok ? BSColors.success : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: ok ? BSColors.success : AppTheme.border, width: 1.5),
          ),
          child: ok ? const Icon(Icons.check_rounded, color: Colors.white, size: 12) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(color: ok ? BSColors.success : AppTheme.hint, fontSize: 12.5, fontWeight: ok ? FontWeight.w600 : FontWeight.w400)),
        ),
      ]),
    );
  }
}
