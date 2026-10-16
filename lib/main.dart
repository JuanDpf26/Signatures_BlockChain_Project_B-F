import 'services/presence_service.dart';
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
import 'theme/app_settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En el celular la sesión dura mientras la app está abierta: al cerrarla y
  // volver a abrirla se pide iniciar sesión otra vez (en la web se conserva).
  if (!kIsWeb) {
    try {
      await AuthService.deleteToken();
    } catch (_) {}
  }
  await AppSettings.instance.load();
  _applyPalette();
  runApp(const MyApp());
}

void _applyPalette() {
  final s = AppSettings.instance;
  AppTheme.apply(dark: s.isDark, highContrast: s.highContrast);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => AppSettings.instance.platformBrightnessChanged();

  /// Cambió la apariencia: se aplica la paleta y se vuelve a dibujar todo
  /// (sin reiniciar la navegación, así sigues en la misma pantalla).
  void _onSettings() {
    _applyPalette();
    setState(() {});
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }
    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return MaterialApp(
      navigatorKey: PresenceService.navigatorKey,
      title: 'DocBlockSign',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      initialRoute: '/',
      // Accesibilidad (tamaño de texto, negrita, menos animación) y aviso
      // flotante mientras el servidor gratuito se despierta
      builder: (context, child) => Stack(children: [
        Builder(builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(settings.textScale),
              boldText: mq.boldText || settings.boldText,
              disableAnimations: mq.disableAnimations || settings.reduceMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        }),
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
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
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

        // Rutas normales. La dirección del navegador no decide a dónde se entra:
        // sin sesión válida todo lleva al inicio de sesión, y con sesión las
        // pantallas de acceso llevan a la aplicación.
        final Widget Function() page;
        bool needsSession = false; // solo con sesión
        bool guestOnly = false; // solo sin sesión (con sesión → aplicación)
        switch (uri.path) {
          case '/':
          case '/welcome':
            page = () => (uri.path == '/' && !kIsWeb) ? const SplashScreen() : const WelcomeScreen();
            guestOnly = kIsWeb;
            break;
          case '/login':
            page = () => const LoginScreen();
            guestOnly = true;
            break;
          case '/register':
            page = () => const RegisterScreen();
            guestOnly = true;
            break;
          case '/forgot':
            page = () => const ForgotPasswordScreen();
            guestOnly = true;
            break;
          case '/home':
            page = () => const HomeScreen();
            needsSession = true;
            break;
          default:
            // Cualquier otra dirección escrita a mano: a la entrada que corresponda
            page = () => const LoginScreen();
            guestOnly = true;
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _RouteGuard(needsSession: needsSession, guestOnly: guestOnly, page: page),
        );
      },
    );
  }
}

/// Revisa la sesión antes de mostrar una pantalla abierta desde la dirección del navegador
class _RouteGuard extends StatelessWidget {
  final bool needsSession, guestOnly;
  final Widget Function() page;
  const _RouteGuard({required this.needsSession, required this.guestOnly, required this.page});

  static Future<bool> _hasSession() async {
    final t = await AuthService.getToken();
    if (t == null || t.isEmpty) return false;
    if (AuthService.isExpired(t)) {
      await AuthService.deleteToken();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!needsSession && !guestOnly) return page();
    return FutureBuilder<bool>(
      future: _hasSession(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
        final logged = snap.data!;
        if (needsSession && !logged) return const LoginScreen();
        if (guestOnly && logged) return const HomeScreen();
        return page();
      },
    );
  }
}
