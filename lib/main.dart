import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/email_verified_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verify_screen.dart';
import 'widgets/bs_ui.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlockSign',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Parsear URI para manejar query parameters en web
        final uri = Uri.parse(settings.name ?? '/');

        // /reset-password?token=xxx
        if (uri.path == '/reset-password') {
          final token = uri.queryParameters['token'];
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
            settings: settings,
          );
        }

        // /verify-email?token=xxx (cuando el backend redirige)
        if (uri.path == '/verify-email') {
          final success = uri.queryParameters['success'] == 'true';
          return MaterialPageRoute(
            builder: (_) => EmailVerifiedScreen(success: success),
            settings: settings,
          );
        }

        // /verify?hash=xxx → verificación pública (sin iniciar sesión), enlace de los correos
        if (uri.path == '/verify') {
          return MaterialPageRoute(
            builder: (ctx) => Scaffold(
              backgroundColor: BSColors.page,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                foregroundColor: AppTheme.text,
                title: const Text('Verificar documento · BlockSign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pushReplacementNamed('/login'),
                    child: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: VerifyScreen(initialHash: uri.queryParameters['hash']),
            ),
            settings: settings,
          );
        }

        // Rutas normales
        switch (uri.path) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const WelcomeScreen(),
              settings: settings,
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
              settings: settings,
            );
          case '/register':
            return MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
              settings: settings,
            );
          case '/forgot':
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
              settings: settings,
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const WelcomeScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}