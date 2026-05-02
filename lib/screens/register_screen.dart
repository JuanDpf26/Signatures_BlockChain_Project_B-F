import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();

  bool _isLoading = false;
  bool _captchaVerified = false;
  String? _captchaToken;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _document.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_captchaVerified || _captchaToken == null) {
      showBS(context, 'Completa el captcha para continuar', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        documentId: _document.text.trim(),
        phone: _phone.text.trim(),
        captchaToken: _captchaToken!,
      );

      if (!mounted) return;

      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(
          context,
          res['message'] ?? '¡Cuenta creada! Revisa tu correo para verificarla.',
          isError: false,
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Crear cuenta', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('Información personal'),
                const SizedBox(height: 12),

                BSTextField(
                  label: 'Nombre completo',
                  hint: 'Juan Pérez',
                  controller: _name,
                  icon: Icons.person_outline_rounded,
                  validator: Validators.name,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                BSTextField(
                  label: 'Correo electrónico',
                  hint: 'correo@ejemplo.com',
                  controller: _email,
                  icon: Icons.email_outlined,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                BSTextField(
                  label: 'Número de cédula',
                  hint: '1234567890',
                  controller: _document,
                  icon: Icons.badge_outlined,
                  validator: Validators.documentId,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                BSTextField(
                  label: 'Teléfono',
                  hint: '3001234567',
                  controller: _phone,
                  icon: Icons.phone_outlined,
                  validator: Validators.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                _SectionLabel('Seguridad'),
                const SizedBox(height: 12),

                BSTextField(
                  label: 'Contraseña',
                  hint: '8+ caracteres, mayúscula y número',
                  controller: _pass,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),

                BSTextField(
                  label: 'Confirmar contraseña',
                  hint: 'Repite tu contraseña',
                  controller: _confirmPass,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) => Validators.confirmPassword(v, _pass.text),
                ),
                const SizedBox(height: 24),

                // CAPTCHA widget — integra hCaptcha o Flutter Recaptcha aquí
                // Paquete recomendado: h_captcha_flutter o flutter_recaptcha_v2
                BSCaptchaWidget(
                  onVerified: (token) {
                    setState(() {
                      _captchaVerified = true;
                      _captchaToken = token;
                    });
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Crear cuenta',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Ya tienes cuenta? ', style: TextStyle(color: AppTheme.hint)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.hint,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}