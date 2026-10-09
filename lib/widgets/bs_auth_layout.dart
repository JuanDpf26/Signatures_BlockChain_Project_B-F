import 'package:flutter/material.dart';
import 'brand.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';

/// Diseño común de las pantallas de acceso de DocBlockSign (login, registro,
/// recuperar y restablecer contraseña, verificación de correo).
///
/// - Web (> 900 px): panel de marca a la izquierda + formulario a la derecha.
/// - Móvil: logo arriba + formulario.
class BSAuthLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final double maxFormWidth;
  final Widget? leading; // ícono o insignia sobre el título

  const BSAuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.maxFormWidth = 440,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;

    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxFormWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack) ...[
                _BackLink(onTap: onBack ?? () => Navigator.maybePop(context)),
                const SizedBox(height: 20),
              ],
              _BrandMark(dark: false, big: wide),
              SizedBox(height: wide ? 40 : 28),
              if (leading != null) ...[
                leading!,
                const SizedBox(height: 18),
              ],
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: wide ? 34 : 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: const TextStyle(color: AppTheme.hint, fontSize: 14.5, height: 1.5)),
              ],
              const SizedBox(height: 28),
              child,
              const SizedBox(height: 32),
              const _EnvPill(),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(children: [
              const Expanded(flex: 9, child: _BrandPanel()),
              Expanded(flex: 11, child: form),
            ])
          : SafeArea(child: form),
    );
  }
}

// ── Panel de marca (solo web) ────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      child: Stack(fit: StackFit.expand, children: [
        // Círculos decorativos (como en el mockup institucional)
        Positioned(top: -90, right: -40, child: _Bubble(size: 320, opacity: 0.06)),
        Positioned(bottom: -140, left: -110, child: _Bubble(size: 360, opacity: 0.06)),
        // Desplazable y con altura mínima de pantalla: en pantallas bajas no se desborda
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (MediaQuery.of(context).size.height - 96).clamp(0, double.infinity).toDouble()),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BSEntrance(
                  child: Text(
                    'Firma digital\ncon blockchain',
                    style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
                  ),
                ),
                const SizedBox(height: 22),
                BSEntrance(
                  delay: const Duration(milliseconds: 80),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      'Sube, analiza, firma y verifica tus documentos con validez y trazabilidad en un solo lugar.',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 17, height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                for (final (i, t) in const [
                  'Huella SHA-256 única por documento',
                  'Registro inmutable en Ethereum Sepolia',
                  'Análisis inteligente con IA',
                  'Verificación pública sin subir el archivo',
                ].indexed) ...[
                  BSEntrance(delay: Duration(milliseconds: 160 + i * 70), child: _Feature(text: t)),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 28),
                Text(
                  'Universidad Manuela Beltrán · IS25133 · 2026',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Píldora de ambiente (como "Ambiente: Desarrollo" del mockup)
class _EnvPill extends StatelessWidget {
  const _EnvPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD99A00), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        const Text('Red: Sepolia Testnet · datos de prueba',
            style: TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size, opacity;
  const _Bubble({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withOpacity(opacity), shape: BoxShape.circle),
      );
}

class _Feature extends StatelessWidget {
  final String text;
  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w500))),
    ]);
  }
}

/// Logo + nombre. dark=true → sobre fondo de color (texto blanco). big → tamaño grande del panel de acceso.
class _BrandMark extends StatelessWidget {
  final bool dark;
  final bool big;
  const _BrandMark({required this.dark, this.big = false});

  @override
  Widget build(BuildContext context) {
    final logo = big ? 76.0 : 46.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandSymbol(size: logo, onDark: dark),
      SizedBox(width: big ? 16 : 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BrandWordmark(fontSize: big ? 38 : 22, onDark: dark),
        const SizedBox(height: 3),
        Text('Firma digital con blockchain',
            style: TextStyle(color: dark ? Colors.white.withOpacity(0.8) : AppTheme.hint, fontSize: big ? 14 : 11.5)),
      ]),
    ]);
  }
}

class _BackLink extends StatelessWidget {
  final VoidCallback onTap;
  const _BackLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_rounded, color: AppTheme.hint, size: 18),
          SizedBox(width: 6),
          Text('Volver', style: TextStyle(color: AppTheme.hint, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Piezas reutilizables para formularios de acceso ──────────────────────

/// Botón principal ancho completo con spinner
class BSAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const BSAuthButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return BSPressable(
      pressedScale: 0.98,
      glowColor: loading || onPressed == null ? null : AppTheme.primary,
      child: SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primary.withOpacity(0.55),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      ),
    );
  }
}

/// "¿No tienes cuenta? Regístrate"
class BSAuthSwitch extends StatelessWidget {
  final String question, action;
  final VoidCallback onTap;
  const BSAuthSwitch({super.key, required this.question, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('$question ', style: const TextStyle(color: AppTheme.hint, fontSize: 14)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(action, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

/// Separador "o continúa con"
class BSAuthDivider extends StatelessWidget {
  final String text;
  const BSAuthDivider({super.key, this.text = 'o continúa con'});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(color: AppTheme.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(text, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      ),
      const Expanded(child: Divider(color: AppTheme.border)),
    ]);
  }
}

/// Ícono grande en cuadro redondeado (para encabezados de recuperar/verificar)
class BSAuthIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const BSAuthIcon({super.key, required this.icon, this.color = AppTheme.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
