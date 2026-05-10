import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

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
      js.context.callMethod('showCaptcha');
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
    if (attempts > 30) return;
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
    if (kIsWeb) js.context.callMethod('resetCaptcha');
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
          res['message'] ?? '¡Cuenta creada! Revisa tu correo.',
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
    final isWeb = ResponsiveLayout.isWeb(context);

    final content = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 48 : 24,
          vertical: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (isWeb) ...[
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completa los datos para registrarte',
                  style: TextStyle(color: AppTheme.hint, fontSize: 14),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completa los datos para registrarte',
                  style: TextStyle(color: AppTheme.hint, fontSize: 14),
                ),
                const SizedBox(height: 28),
              ],

              // Sección: Info personal
              _SectionLabel('Información personal'),
              const SizedBox(height: 12),

              // En web: 2 columnas para nombre y email
              if (isWeb)
                Row(
                  children: [
                    Expanded(
                      child: BSTextField(
                        label: 'Nombre completo',
                        hint: 'Juan Pérez',
                        controller: _name,
                        icon: Icons.person_outline_rounded,
                        validator: Validators.name,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BSTextField(
                        label: 'Correo electrónico',
                        hint: 'correo@ejemplo.com',
                        controller: _email,
                        icon: Icons.email_outlined,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                )
              else ...[
                BSTextField(
                  label: 'Nombre completo',
                  hint: 'Juan Pérez',
                  controller: _name,
                  icon: Icons.person_outline_rounded,
                  validator: Validators.name,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                BSTextField(
                  label: 'Correo electrónico',
                  hint: 'correo@ejemplo.com',
                  controller: _email,
                  icon: Icons.email_outlined,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],

              const SizedBox(height: 14),

              // Cédula y teléfono — siempre en fila
              Row(
                children: [
                  Expanded(
                    child: BSTextField(
                      label: 'Cédula',
                      hint: '1234567890',
                      controller: _document,
                      icon: Icons.badge_outlined,
                      validator: Validators.documentId,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: BSTextField(
                      label: 'Teléfono',
                      hint: '3001234567',
                      controller: _phone,
                      icon: Icons.phone_outlined,
                      validator: Validators.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sección: Seguridad
              _SectionLabel('Seguridad'),
              const SizedBox(height: 12),

              if (isWeb)
                Row(
                  children: [
                    Expanded(
                      child: BSTextField(
                        label: 'Contraseña',
                        hint: '8+ chars, mayúscula y número',
                        controller: _pass,
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: Validators.password,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BSTextField(
                        label: 'Confirmar contraseña',
                        hint: 'Repite tu contraseña',
                        controller: _confirmPass,
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: (v) =>
                            Validators.confirmPassword(v, _pass.text),
                      ),
                    ),
                  ],
                )
              else ...[
                BSTextField(
                  label: 'Contraseña',
                  hint: '8+ caracteres, mayúscula y número',
                  controller: _pass,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                BSTextField(
                  label: 'Confirmar contraseña',
                  hint: 'Repite tu contraseña',
                  controller: _confirmPass,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) => Validators.confirmPassword(v, _pass.text),
                ),
              ],

              const SizedBox(height: 24),

              // Sección: Captcha
              _SectionLabel('Verificación'),
              const SizedBox(height: 12),

              _CaptchaWidget(
                verified: _captchaVerified,
                onTap: _captchaVerified ? _resetCaptcha : _checkCaptcha,
              ),

              const SizedBox(height: 24),

              // Botón registrar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Crear cuenta',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta? ',
                      style: TextStyle(color: AppTheme.hint, fontSize: 14)),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text(
                      'Inicia sesión',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isWeb
          ? ResponsiveLayout(maxWidth: 560, child: content)
          : content,
    );
  }
}

// ─────────────────────────────────────────
// CAPTCHA WIDGET
// ─────────────────────────────────────────
class _CaptchaWidget extends StatelessWidget {
  final bool verified;
  final VoidCallback onTap;

  const _CaptchaWidget({required this.verified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: verified ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: verified ? AppTheme.success : AppTheme.hint,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: verified
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 15)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                verified
                    ? 'Verificado ✓  (toca para resetear)'
                    : 'No soy un robot — toca para verificar',
                style: TextStyle(
                  color: verified ? AppTheme.success : AppTheme.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('reCAPTCHA',
                    style:
                        TextStyle(color: AppTheme.hint, fontSize: 10)),
                Text('Google',
                    style: TextStyle(
                        color: Color(0xFF4b5563), fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.hint,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}