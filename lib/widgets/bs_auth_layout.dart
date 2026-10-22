import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'accessibility_menu.dart';
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

  /// Pantalla ancha (computador): diseño fijo, sin desplazamiento.
  static bool isWide(BuildContext context) => MediaQuery.of(context).size.width > 900;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          _BackLink(onTap: onBack ?? () => Navigator.maybePop(context)),
          SizedBox(height: wide ? 12 : 20),
        ],
        const _BrandMark(dark: false),
        SizedBox(height: wide ? 24 : 28),
        if (leading != null) ...[
          leading!,
          SizedBox(height: wide ? 14 : 18),
        ],
        Text(
          title,
          style: TextStyle(
            color: AppTheme.text,
            fontSize: wide ? 30 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.5)),
        ],
        SizedBox(height: wide ? 22 : 28),
        child,
        // En computador la red de prueba se indica en el panel azul
        if (!wide) ...[
          const SizedBox(height: 32),
          const _EnvPill(),
        ],
      ],
    );

    // Celular: desplazable (el teclado ocupa media pantalla)
    final mobileForm = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxFormWidth), child: content),
      ),
    );

    // Computador: fijo. Si la ventana es baja, el formulario se reduce para
    // caber completo en lugar de mostrar barra de desplazamiento.
    final desktopForm = LayoutBuilder(builder: (context, box) {
      final width = math.min(maxFormWidth, math.max(0.0, box.maxWidth - 96));
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: math.max(0.0, box.maxHeight - 56)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(width: width, child: content),
            ),
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: AppTheme.card,
      body: Stack(children: [
        wide
            ? Row(children: [
                const Expanded(flex: 9, child: _BrandPanel()),
                Expanded(flex: 11, child: desktopForm),
              ])
            : SafeArea(child: mobileForm),
        // Apariencia y accesibilidad, disponible desde antes de iniciar sesión
        const Positioned(top: 8, right: 8, child: SafeArea(child: AccessibilityButton())),
      ]),
    );
  }
}

// ── Panel de marca (solo web) ────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Azul institucional; en modo oscuro, azul noche
      color: AppTheme.isDark ? const Color(0xFF13203A) : AppTheme.primary,
      child: Stack(fit: StackFit.expand, children: [
        // Círculos decorativos (como en el mockup institucional)
        Positioned(top: -90, right: -40, child: _Bubble(size: 320, opacity: 0.06)),
        Positioned(bottom: -140, left: -110, child: _Bubble(size: 360, opacity: 0.06)),
        // Fijo: si la ventana es baja, el contenido se reduce en lugar de desplazarse
        LayoutBuilder(builder: (context, box) {
          final width = math.max(0.0, box.maxWidth - 144);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 40),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width,
                child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                for (final (i, t) in const [
                  'Huella SHA-256 única por documento',
                  'Registro inmutable en Ethereum Sepolia',
                  'Análisis inteligente con IA',
                  'Verificación sin subir el archivo',
                ].indexed) ...[
                  BSEntrance(delay: Duration(milliseconds: 160 + i * 70), child: _Feature(text: t)),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 28),
                const _EnvPill(onDark: true),
                const SizedBox(height: 16),
                Text(
                  'Universidad Manuela Beltrán · IS25133 · 2026',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                ),
              ],
            ),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

/// Píldora de ambiente (como "Ambiente: Desarrollo" del mockup)
class _EnvPill extends StatelessWidget {
  final bool onDark;
  const _EnvPill({this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withOpacity(0.12) : BSColors.page,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD99A00), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('Red: Sepolia Testnet · datos de prueba',
            style: TextStyle(color: onDark ? Colors.white : AppTheme.text, fontSize: 12, fontWeight: FontWeight.w700)),
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
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
    ]);
  }
}

/// Logo + nombre. dark=true → sobre fondo de color (texto blanco). big → tamaño grande del panel de acceso.
class _BrandMark extends StatelessWidget {
  final bool dark;
  const _BrandMark({required this.dark});

  @override
  Widget build(BuildContext context) {
    const logo = 46.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandSymbol(size: logo, onDark: dark),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BrandWordmark(fontSize: 22, onDark: dark),
        const SizedBox(height: 3),
        Text('Firma digital con blockchain',
            style: TextStyle(color: dark ? Colors.white.withOpacity(0.8) : AppTheme.hint, fontSize: 11.5)),
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_rounded, color: AppTheme.hint, size: 18),
          SizedBox(width: 6),
          Text('Volver', style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w600)),
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
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Text('$question ', style: TextStyle(color: AppTheme.hint, fontSize: 14)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(action, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14)),
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
      Expanded(child: Divider(color: AppTheme.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(text, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
      ),
      Expanded(child: Divider(color: AppTheme.border)),
    ]);
  }
}

/// Ícono grande en cuadro redondeado (para encabezados de recuperar/verificar)
class BSAuthIcon extends StatelessWidget {
  final IconData icon;
  final Color? _color;
  Color get color => _color ?? AppTheme.primary;
  const BSAuthIcon({super.key, required this.icon, Color? color}) : _color = color;

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
