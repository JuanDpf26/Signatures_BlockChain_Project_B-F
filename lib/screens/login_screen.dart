import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/google_auth_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    // Mostrar mensaje si viene de verificación de email
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final verified = uri.queryParameters['verified'];
      if (verified == 'true') {
        SweetAlert.success(
          context,
          title: '¡Cuenta verificada!',
          text: 'Ya puedes iniciar sesión.',
        );
      } else if (verified == 'error') {
        SweetAlert.error(
          context,
          title: 'Enlace inválido',
          text: 'El enlace de verificación es inválido o ya expiró.',
        );
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      if (res['token'] != null) {
        setState(() => _isLoading = false);
        final now = DateTime.now();
        final name = bsPrimerNombre(res['user']?['name']?.toString());
        await SweetAlert.success(
          context,
          title: name.isEmpty ? '¡Bienvenido!' : '¡Bienvenido, $name!',
          text: '${bsSaludo(now)} · ${bsFechaLarga(now)}, ${bsHora(now)}',
          autoClose: const Duration(milliseconds: 2000),
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = (res['error'] ?? 'Error al iniciar sesión').toString();
        // Cuenta sin verificar → advertencia; credenciales u otro error → error
        if (msg.toLowerCase().contains('verificar')) {
          await SweetAlert.warning(
            context,
            title: 'Verifica tu correo',
            text: msg,
          );
        } else {
          await SweetAlert.error(
            context,
            title: 'No pudimos iniciar sesión',
            text: msg,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final res = await AuthService.loginWithGoogle();
      if (!mounted) return;
      if (res['token'] != null) {
        setState(() => _isGoogleLoading = false);
        final now = DateTime.now();
        final name = bsPrimerNombre(res['user']?['name']?.toString());
        await SweetAlert.success(
          context,
          title: name.isEmpty ? '¡Bienvenido!' : '¡Bienvenido, $name!',
          text: 'Sesión iniciada con Google\n${bsFechaLarga(now)}, ${bsHora(now)}',
          autoClose: const Duration(milliseconds: 2000),
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        await SweetAlert.error(
          context,
          title: 'Error con Google',
          text: (res['error'] ?? 'No se pudo iniciar sesión con Google.').toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BSAuthLayout(
      title: 'Iniciar sesión',
      subtitle: 'Ingresa tus credenciales para continuar.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BSTextField(
              label: 'Correo electrónico',
              hint: 'correo@ejemplo.com',
              controller: _email,
              icon: Icons.email_outlined,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              light: true,
            ),
            const SizedBox(height: 16),
            BSTextField(
              label: 'Contraseña',
              hint: '••••••••',
              controller: _pass,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
              light: true,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/forgot'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('¿Olvidaste tu contraseña?',
                      style: TextStyle(color: GoogleAuthTheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BSAuthButton(label: 'Iniciar sesión', loading: _isLoading, onPressed: _login),
            const SizedBox(height: 22),
            const BSAuthDivider(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: GoogleAuthTheme.border, width: 1),
                  foregroundColor: GoogleAuthTheme.text,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isGoogleLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/google_logo.png', width: 20, height: 20),
                          const SizedBox(width: 10),
                          const Text('Continuar con Google', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),
            BSAuthSwitch(
              question: '¿No tienes cuenta?',
              action: 'Regístrate',
              onTap: () => Navigator.pushNamed(context, '/register'),
            ),
          ],
        ),
      ),
    );
  }
}
