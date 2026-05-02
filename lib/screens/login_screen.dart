import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../theme/app_theme.dart';
 
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
 
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.featureCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'BlockSign',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Inicia sesión en tu cuenta',
                        style: TextStyle(color: AppTheme.hint, fontSize: 15),
                      ),
                    ],
                  ),
                ),
 
                const SizedBox(height: 40),
 
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
                  validator: (v) => (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
                ),
                const SizedBox(height: 12),
 
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
 
                const SizedBox(height: 24),
 
                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                            'Iniciar sesión',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
 
                const SizedBox(height: 20),
 
                // Divider
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF2a2a4a))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('o continúa con', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF2a2a4a))),
                  ],
                ),
 
                const SizedBox(height: 20),
 
                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2a2a4a), width: 1.5),
                      foregroundColor: AppTheme.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google_logo.png', width: 22, height: 22),
                              const SizedBox(width: 12),
                              const Text(
                                'Continuar con Google',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
 
                const SizedBox(height: 32),
 
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? ', style: TextStyle(color: AppTheme.hint)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Regístrate',
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