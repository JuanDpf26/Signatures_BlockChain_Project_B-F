import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
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

  void _checkCaptcha() {
  if (kIsWeb) {
    // Primero mostrar el popup de reCAPTCHA
    js.context.callMethod('showCaptcha');
    
    // Verificar el token después de 30 segundos máximo
    Future.delayed(const Duration(seconds: 1), _pollCaptchaToken);
  } else {
    setState(() {
      _captchaVerified = true;
      _captchaToken = 'mobile_bypass_dev';
    });
  }
}

void _pollCaptchaToken({int attempts = 0}) {
  if (!mounted) return;
  if (attempts > 30) return; // máximo 30 segundos

  final token = js.context['captchaToken'];
  if (token != null && token.toString().isNotEmpty) {
    setState(() {
      _captchaVerified = true;
      _captchaToken = token.toString();
    });
  } else {
    Future.delayed(
      const Duration(seconds: 1),
      () => _pollCaptchaToken(attempts: attempts + 1),
    );
  }
}

  void _resetCaptcha() {
    if (kIsWeb) {
      js.context.callMethod('resetCaptcha');
    }
    setState(() {
      _captchaVerified = false;
      _captchaToken = null;
    });
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
        _resetCaptcha();
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
        title: const Text(
          'Crear cuenta',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700),
        ),
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

                _SectionLabel('Verificación'),
                const SizedBox(height: 12),

                // reCAPTCHA widget
                _CaptchaWidget(
                  verified: _captchaVerified,
                  onTap: _captchaVerified ? _resetCaptcha : _checkCaptcha,
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Crear cuenta',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Ya tienes cuenta? ',
                        style: TextStyle(color: AppTheme.hint)),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700),
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

// Widget visual del captcha
class _CaptchaWidget extends StatelessWidget {
  final bool verified;
  final VoidCallback onTap;

  const _CaptchaWidget({required this.verified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: verified
                ? AppTheme.success.withOpacity(0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: verified ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: verified ? AppTheme.success : AppTheme.hint,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: verified
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                verified ? 'Verificado ✓  (toca para resetear)' : 'No soy un robot — toca para verificar',
                style: TextStyle(
                  color: verified ? AppTheme.success : AppTheme.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('reCAPTCHA',
                    style: TextStyle(color: AppTheme.hint, fontSize: 10)),
                Text('Google',
                    style: TextStyle(color: Color(0xFF4b5563), fontSize: 9)),
              ],
            ),
          ],
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