import 'dart:async';
import '../widgets/brand.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/auth_service.dart';
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
  static const _minVisible = Duration(milliseconds: 1800);
  static const _slowAfter = Duration(seconds: 5);
  static const _giveUpAfter = Duration(seconds: 70);

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  String _status = 'Iniciando…';
  bool _slow = false;
  bool _failed = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _status = 'Conectando con el servidor…';
      _slow = false;
      _failed = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });

    final shown = Future.delayed(_minVisible);
    final loggedIn = AuthService.isLoggedIn();
    final serverOk = _wakeServer();

    final results = await Future.wait([serverOk, loggedIn, shown]);
    _slowTimer?.cancel();
    if (!mounted) return;

    if (results[0] != true) {
      setState(() {
        _failed = true;
        _status = 'No se pudo conectar con el servidor';
      });
      return;
    }
    setState(() => _status = 'Listo');
    _go(results[1] == true);
  }

  /// Consulta /health hasta que responda o se agote el tiempo.
  Future<bool> _wakeServer() async {
    final url = Uri.parse('${AppConfig.apiUrl}/health');
    final deadline = DateTime.now().add(_giveUpAfter);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) return true;
      } catch (_) {
        // servidor dormido o sin red: se reintenta
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  void _go(bool loggedIn) {
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
        decoration: const BoxDecoration(
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
                        color: Colors.white,
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
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary),
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
