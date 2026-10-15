import 'services/server_wake.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/email_verified_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocBlockSign',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      // Aviso flotante mientras el servidor gratuito se despierta
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox.shrink(),
        ValueListenableBuilder<bool>(
          valueListenable: ServerWake.waking,
          builder: (_, waking, __) => !waking
              ? const SizedBox.shrink()
              : Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1B33),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text('Activando el servidor… la primera carga puede tardar un poco',
                                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
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

        // /verify?hash=xxx (enlace de los correos): exige sesión; sin sesión pide iniciarla y vuelve aquí
        if (uri.path == '/verify') {
          final hash = uri.queryParameters['hash'];
          return MaterialPageRoute(
            builder: (_) => FutureBuilder<bool>(
              future: AuthService.isLoggedIn(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
                if (snap.data == true) return HomeScreen(initialIndex: 2, verifyHash: hash);
                AuthService.pendingRoute = '/verify?hash=${hash ?? ''}';
                return const LoginScreen();
              },
            ),
            settings: settings,
          );
        }

        // Rutas normales
        switch (uri.path) {
          case '/':
            // En la app móvil, pantalla de carga (despierta el servidor y revisa la sesión)
            return MaterialPageRoute(
              builder: (_) => kIsWeb ? const WelcomeScreen() : const SplashScreen(),
              settings: settings,
            );
          case '/welcome':
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