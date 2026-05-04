import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

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
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        showBS(context, res['error'] ?? 'Error al iniciar sesión', isError: true);
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
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        showBS(context, res['error'] ?? 'Error con Google', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header solo en móvil
                if (!isWeb) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.featureCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.verified_user_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'BlockSign',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Inicia sesión en tu cuenta',
                      style: TextStyle(color: AppTheme.hint, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],

                if (isWeb) ...[
                  const Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ingresa tus credenciales para continuar',
                    style: TextStyle(color: AppTheme.hint, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                ],

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
                  label: 'Contraseña',
                  hint: '••••••••',
                  controller: _pass,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                        : const Text('Iniciar sesión',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 20),

                const Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('o continúa con',
                          style: TextStyle(
                              color: AppTheme.hint, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: AppTheme.border)),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border, width: 1.5),
                      foregroundColor: AppTheme.text,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google_logo.png',
                                  width: 20, height: 20),
                              const SizedBox(width: 10),
                              const Text('Continuar con Google',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? ',
                        style: TextStyle(color: AppTheme.hint, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Regístrate',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: isWeb
          ? ResponsiveLayout(maxWidth: 480, child: content)
          : content,
    );
  }
}