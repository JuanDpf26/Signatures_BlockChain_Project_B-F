import 'dart:async';
import '../widgets/brand.dart';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/server_wake.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de carga de la app móvil.
///
/// Mientras se muestra:
/// 1. Despierta el servidor (en el plan gratuito de Render puede tardar ~50 s
///    la primera vez) consultando /health.
/// 2. Revisa si hay una sesión guardada.
/// Luego abre el inicio (/home) o la bienvenida (/welcome).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _minVisible = Duration(milliseconds: 900);

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  String _status = 'Iniciando…';
  bool _slow = false;
  bool _failed = false;
  Timer? _slowTimer;
  bool _loggedIn = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // El servidor se despierta en segundo plano: no se espera aquí. Las
    // pantallas muestran su carga y sus peticiones esperan a que responda.
    unawaited(ServerWake.ready());
    // Pase lo que pase, a los 6 s se sale de la pantalla de carga
    _slowTimer = Timer(const Duration(seconds: 6), () => _go(_loggedIn));

    try {
      _loggedIn = await AuthService.isLoggedIn().timeout(const Duration(seconds: 3));
    } catch (_) {
      _loggedIn = false;
    }
    await Future.delayed(_minVisible);
    if (!mounted || _navigated) return;

    // Android: si hay una versión nueva publicada, se ofrece antes de entrar
    try {
      final upd = await UpdateService.latest().timeout(const Duration(seconds: 2));
      if (upd != null && mounted && !_navigated) {
        _slowTimer?.cancel();
        await UpdateService.prompt(context, upd);
      }
    } catch (_) {}
    _go(_loggedIn);
  }

  void _go(bool loggedIn) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _slowTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(loggedIn ? '/home' : '/welcome');
  }

  Future<void> _continueOffline() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (mounted) _go(loggedIn);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    final scale = Tween(begin: 0.82, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(
                    scale: scale,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 10)),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const BrandSymbol(size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: fade,
                  child: const Column(children: [
                    BrandWordmark(fontSize: 32, onDark: true),
                    SizedBox(height: 6),
                    Text(
                      'Firma y verificación de documentos con blockchain',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14, height: 1.35),
                    ),
                  ]),
                ),
                const Spacer(flex: 2),
                if (!_failed) ...[
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  AnimatedOpacity(
                    opacity: _slow ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'El servidor se está activando; la primera vez puede tardar hasta un minuto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 34),
                  const SizedBox(height: 10),
                  Text(_status, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'Revisa tu conexión a internet e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                    FilledButton.icon(
                      onPressed: _start,
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.card, foregroundColor: AppTheme.primary),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    OutlinedButton(
                      onPressed: _continueOffline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x99FFFFFF)),
                      ),
                      child: const Text('Continuar'),
                    ),
                  ]),
                ],
                const Spacer(flex: 1),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'SHA-256 · Ethereum Sepolia · IA',
                    style: TextStyle(color: Color(0x80FFFFFF), fontSize: 11.5, letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
