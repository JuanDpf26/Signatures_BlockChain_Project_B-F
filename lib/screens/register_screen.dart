import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import '../utils/js_bridge.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_auth_layout.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/google_auth_theme.dart';

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
  bool _captchaChecking = false; // esperando que el usuario resuelva el reto
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
    if (_captchaChecking) {
      // Si cerró el reto sin resolverlo, al tocar de nuevo se vuelve a mostrar
      if (kIsWeb) jsCall('showCaptcha');
      return;
    }
    if (kIsWeb) {
      setState(() => _captchaChecking = true);
      jsCall('showCaptcha');
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
    if (attempts > 30) {
      // El usuario no completó el reto en 30 s: vuelve al estado inicial
      setState(() => _captchaChecking = false);
      return;
    }
    final token = jsGet('captchaToken');
    if (token != null && token.toString().isNotEmpty) {
      setState(() {
        _captchaVerified = true;
        _captchaChecking = false;
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
    if (kIsWeb) jsCall('resetCaptcha');
    setState(() {
      _captchaVerified = false;
      _captchaChecking = false;
      _captchaToken = null;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_captchaVerified || _captchaToken == null) {
      await SweetAlert.warning(
        context,
        title: 'Falta el captcha',
        text: 'Marca "No soy un robot" para continuar.',
      );
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
        _resetCaptcha();
        await SweetAlert.error(
          context,
          title: 'No se pudo crear la cuenta',
          text: res['error'].toString(),
        );
      } else {
        setState(() => _isLoading = false);
        await SweetAlert.success(
          context,
          title: '¡Cuenta creada!',
          text: res['message'] ??
              'Te enviamos un correo para verificar tu cuenta. Revisa tu bandeja de entrada y spam.',
          confirmText: 'Ir a iniciar sesión',
          barrierDismissible: false,
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final twoCols = MediaQuery.of(context).size.width > 1200;

    Widget pair(Widget a, Widget b) => twoCols
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ])
        : Column(children: [a, const SizedBox(height: 14), b]);

    return BSAuthLayout(
      title: 'Crear cuenta',
      subtitle: 'Completa tus datos para empezar a firmar documentos.',
      showBack: true,
      onBack: () => Navigator.pushReplacementNamed(context, '/login'),
      maxFormWidth: 600,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('INFORMACIÓN PERSONAL'),
            const SizedBox(height: 12),
            pair(
              BSTextField(
                label: 'Nombre completo',
                hint: 'Juan Pérez',
                controller: _name,
                icon: Icons.person_outline_rounded,
                validator: Validators.name,
                textCapitalization: TextCapitalization.words,
                light: true,
              ),
              BSTextField(
                label: 'Correo electrónico',
                hint: 'correo@ejemplo.com',
                controller: _email,
                icon: Icons.email_outlined,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                light: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: BSTextField(
                  label: 'Cédula',
                  hint: '1234567890',
                  controller: _document,
                  icon: Icons.badge_outlined,
                  validator: Validators.documentId,
                  keyboardType: TextInputType.number,
                  light: true,
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
                  light: true,
                ),
              ),
            ]),
            const SizedBox(height: 26),
            _SectionLabel('SEGURIDAD'),
            const SizedBox(height: 12),
            pair(
              BSTextField(
                label: 'Contraseña',
                hint: '8+ caracteres, mayúscula y número',
                controller: _pass,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: Validators.password,
                light: true,
              ),
              BSTextField(
                label: 'Confirmar contraseña',
                hint: 'Repite tu contraseña',
                controller: _confirmPass,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (v) => Validators.confirmPassword(v, _pass.text),
                light: true,
              ),
            ),
            const SizedBox(height: 26),
            _SectionLabel('VERIFICACIÓN'),
            const SizedBox(height: 12),
            _CaptchaWidget(
              verified: _captchaVerified,
              checking: _captchaChecking,
              onTap: _captchaVerified ? _resetCaptcha : _checkCaptcha,
            ),
            const SizedBox(height: 26),
            BSAuthButton(label: 'Crear cuenta', loading: _isLoading, onPressed: _register),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Te enviaremos un correo para verificar tu cuenta.',
                style: TextStyle(color: GoogleAuthTheme.textSecondary, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 22),
            BSAuthSwitch(
              question: '¿Ya tienes cuenta?',
              action: 'Inicia sesión',
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// CAPTCHA WIDGET
// ─────────────────────────────────────────
class _CaptchaWidget extends StatelessWidget {
  final bool verified;
  final bool checking;
  final VoidCallback onTap;

  const _CaptchaWidget({required this.verified, required this.checking, required this.onTap});

  static const _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final borderColor = verified
        ? _green.withOpacity(0.55)
        : checking
            ? GoogleAuthTheme.primary.withOpacity(0.5)
            : GoogleAuthTheme.border;

    return Material(
      color: verified ? _green.withOpacity(0.05) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: verified || checking ? 1.5 : 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            // Casilla: vacía → girando → ✓
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: verified
                  ? Container(
                      key: const ValueKey('ok'),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    )
                  : checking
                      ? const SizedBox(
                          key: ValueKey('wait'),
                          width: 30,
                          height: 30,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 3, color: GoogleAuthTheme.primary),
                          ),
                        )
                      : Container(
                          key: const ValueKey('empty'),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GoogleAuthTheme.textSecondary.withOpacity(0.6), width: 2),
                          ),
                        ),
            ),
            const SizedBox(width: 14),

            // Texto según el estado
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  verified
                      ? 'Verificación completada'
                      : checking
                          ? 'Verificando…'
                          : 'No soy un robot',
                  style: TextStyle(
                    color: verified ? _green : GoogleAuthTheme.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  verified
                      ? 'Toca para reiniciar si lo necesitas'
                      : checking
                          ? 'Resuelve el reto que aparece en pantalla'
                          : 'Toca para confirmar que eres una persona',
                  style: const TextStyle(color: GoogleAuthTheme.textSecondary, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 10),

            // Marca de reCAPTCHA
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                verified ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: verified ? _green : GoogleAuthTheme.primary,
                size: 26,
              ),
              const SizedBox(height: 3),
              const Text('reCAPTCHA',
                  style: TextStyle(color: GoogleAuthTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
              const Text('Privacidad · Términos',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 8.5)),
            ]),
          ]),
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
        color: GoogleAuthTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }
}