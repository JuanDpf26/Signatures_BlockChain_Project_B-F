import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

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
        showBS(context, res['error'], isError: true);
      } else {
        setState(() => _emailSent = true);
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
          child: _emailSent
              ? _SuccessView(email: _email.text.trim(), isWeb: isWeb)
              : _FormView(
                  formKey: _formKey,
                  emailController: _email,
                  isLoading: _isLoading,
                  onSubmit: _submit,
                  isWeb: isWeb,
                ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isWeb
          ? ResponsiveLayout(maxWidth: 480, child: content)
          : content,
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmit;
  final bool isWeb;

  const _FormView({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSubmit,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.key_rounded, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recuperar contraseña',
            style: TextStyle(
              color: AppTheme.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
            style: TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),

          BSTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: emailController,
            icon: Icons.email_outlined,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Enviar enlace',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  final bool isWeb;
  const _SuccessView({required this.email, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: Colors.green, size: 36),
        ),
        const SizedBox(height: 24),
        const Text(
          'Revisa tu correo',
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Si $email está registrado, recibirás un enlace en los próximos minutos.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.hint, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 6),
        const Text(
          'El enlace expira en 1 hora.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.hint, fontSize: 12),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary),
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Volver al inicio de sesión',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}