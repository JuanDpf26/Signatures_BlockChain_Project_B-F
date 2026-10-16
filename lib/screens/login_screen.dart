import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';
import '../widgets/superuser_entry.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
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
  // Ingreso con huella o rostro (celular)
  bool _bioEnabled = false;
  String _bioLabel = 'huella o rostro';

  @override
  void initState() {
    super.initState();
    _checkBio();
    // Android: avisa si hay una versión nueva para instalarla desde la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
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
      } else if (AuthService.pendingRoute?.startsWith('/verify') == true) {
        SweetAlert.info(
          context,
          title: 'Inicia sesión para verificar',
          text: 'Por seguridad, la verificación de documentos solo está disponible para usuarios con cuenta.',
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

  Future<void> _checkBio() async {
    final on = await BiometricService.enabled() && await BiometricService.available();
    if (!on || !mounted) return;
    final label = await BiometricService.label();
    if (!mounted) return;
    setState(() { _bioEnabled = true; _bioLabel = label; });
    // Si no viene de otra pantalla, propone entrar de una vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Uri.base.queryParameters['verified'] == null) _loginBio();
    });
  }

  Future<void> _loginBio() async {
    final err = await BiometricService.login();
    if (!mounted) return;
    if (err == null) {
      Navigator.pushReplacementNamed(context, AuthService.takeRoute());
      return;
    }
    if (err == 'cancelado') return;
    setState(() => _bioEnabled = false);
    await SweetAlert.info(context, title: 'Entra con tu contraseña', text: err);
  }

  /// Después de entrar con contraseña o Google: renueva o propone el ingreso rápido
  Future<void> _afterLogin() async {
    await BiometricService.refreshSavedSession();
    if (!mounted || !await BiometricService.shouldOffer() || !mounted) return;
    final label = await BiometricService.label();
    if (!mounted) return;
    await BiometricService.markOffered();
    final yes = await SweetAlert.confirm(
      context,
      title: 'Entrar con $label',
      text: 'La próxima vez puedes entrar con tu $label, sin escribir la contraseña. Puedes cambiarlo en Configuración → Seguridad.',
      confirmText: 'Activar',
      cancelText: 'Ahora no',
    );
    if (yes && mounted) {
      final ok = await BiometricService.enable();
      if (mounted && ok) showToast(context, title: 'Ingreso con $label activado');
    }
  }

  /// Bienvenida según el tipo de cuenta. Un superusuario va siempre a su consola.
  Future<void> _welcome(Map<String, dynamic> res, {bool google = false}) async {
    final now = DateTime.now();
    final name = bsPrimerNombre(res['user']?['name']?.toString());
    final admin = res['user']?['role'] == 'admin';
    if (admin) {
      // Anuncio de superusuario y, si la contraseña es temporal, cambio obligatorio
      final go = await showSuperuserNotice(context, name: res['user']?['name']?.toString() ?? '', email: res['user']?['email']?.toString() ?? '');
      if (!mounted) return;
      final mustChange = res['user']?['must_change_password'] == true;
      final ok = go && (!mustChange || await showForcedPasswordChange(context, currentPassword: _pass.text));
      if (!ok) {
        await AuthService.deleteToken();
        if (mounted) showToast(context, title: 'No se inició la sesión');
        return;
      }
    } else {
      await SweetAlert.success(
        context,
        title: name.isEmpty ? '¡Bienvenido!' : '¡Bienvenido, $name!',
        text: google ? 'Sesión iniciada con Google\n${bsFechaLarga(now)}, ${bsHora(now)}' : '${bsSaludo(now)} · ${bsFechaLarga(now)}, ${bsHora(now)}',
        autoClose: const Duration(milliseconds: 2000),
      );
    }
    if (!mounted) return;
    await _afterLogin();
    final route = AuthService.takeRoute(); // se consume aunque el superusuario no la use
    if (mounted) Navigator.pushReplacementNamed(context, admin ? '/home' : route);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      if (res['token'] != null) {
        setState(() => _isLoading = false);
        await _welcome(res);
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
        await _welcome(res, google: true);
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
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('¿Olvidaste tu contraseña?',
                      style: TextStyle(color: GoogleAuthTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BSAuthButton(label: 'Iniciar sesión', loading: _isLoading, onPressed: _login),
            if (_bioEnabled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loginBio,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: GoogleAuthTheme.primary, width: 1.2),
                    foregroundColor: GoogleAuthTheme.primary,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_bioLabel == 'rostro' ? Icons.face_rounded : Icons.fingerprint_rounded, size: 22),
                  label: Text('Entrar con $_bioLabel', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const BSAuthDivider(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: GoogleAuthTheme.border, width: 1),
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
                          const Text('Continuar con Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 22),
            const BSInfoBanner(
              title: 'Tu información está protegida.',
              text: 'Las contraseñas se guardan cifradas y la sesión usa un token seguro con vencimiento.',
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: 24),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 20),
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
