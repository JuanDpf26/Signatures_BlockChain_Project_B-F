import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../layout/responsive_layout.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _isLoading = false;
  bool _done = false;

  @override
  void dispose() {
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token == null || widget.token!.isEmpty) {
      showBS(context, 'Token inválido o expirado', isError: true);
      return;
    }
    if (_newPass.text != _confirmPass.text) {
      showBS(context, 'Las contraseñas no coinciden', isError: true);
      return;
    }
    if (Validators.password(_newPass.text) != null) {
      showBS(context, Validators.password(_newPass.text)!, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await AuthService.resetPassword(widget.token!, _newPass.text);
      if (!mounted) return;
      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        setState(() => _done = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);

    final content = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 48 : 24,
            vertical: 24,
          ),
          child: _done
              ? _SuccessView()
              : _FormView(
                  newPass: _newPass,
                  confirmPass: _confirmPass,
                  isLoading: _isLoading,
                  onSubmit: _submit,
                  isWeb: isWeb,
                ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      // AppBar solo en móvil; en web el layout no tiene appBar
      appBar: isWeb
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.text),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
      body: isWeb
          ? ResponsiveLayout(child: content)
          : content,
    );
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController newPass;
  final TextEditingController confirmPass;
  final bool isLoading;
  final VoidCallback onSubmit;
  final bool isWeb;

  const _FormView({
    required this.newPass,
    required this.confirmPass,
    required this.isLoading,
    required this.onSubmit,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón volver solo en web (reemplaza el AppBar)
        if (isWeb) ...[
          TextButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppTheme.hint),
            label: const Text('Volver al login',
                style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: AppTheme.primary, size: 26),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nueva contraseña',
          style: TextStyle(
              color: AppTheme.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa tu nueva contraseña para recuperar el acceso.',
          style: TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),

        BSTextField(
          label: 'Nueva contraseña',
          hint: '8+ caracteres, mayúscula y número',
          controller: newPass,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          validator: Validators.password,
        ),
        const SizedBox(height: 16),

        BSTextField(
          label: 'Confirmar contraseña',
          hint: 'Repite tu nueva contraseña',
          controller: confirmPass,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          validator: (v) => Validators.confirmPassword(v, newPass.text),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Cambiar contraseña',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 36),
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Contraseña actualizada!',
          style: TextStyle(
              color: AppTheme.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ya puedes iniciar sesión con tu nueva contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Ir al inicio de sesión',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}