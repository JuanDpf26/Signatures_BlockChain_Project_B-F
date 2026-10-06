import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Diseño común de las pantallas de acceso de BlockSign (login, registro,
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
              if (!wide) ...[
                const _BrandMark(dark: false),
                const SizedBox(height: 28),
              ],
              if (leading != null) ...[
                leading!,
                const SizedBox(height: 18),
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
                const SizedBox(height: 8),
                Text(subtitle!, style: const TextStyle(color: AppTheme.hint, fontSize: 14.5, height: 1.5)),
              ],
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: form),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.featureCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Círculos decorativos
        Positioned(top: -80, right: -60, child: _Bubble(size: 260, opacity: 0.10)),
        Positioned(bottom: -100, left: -70, child: _Bubble(size: 300, opacity: 0.08)),
        Positioned(bottom: 140, right: 40, child: _Bubble(size: 90, opacity: 0.10)),
        // Desplazable y con altura mínima de pantalla: en pantallas bajas no se desborda
        SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (MediaQuery.of(context).size.height - 96).clamp(0, double.infinity).toDouble()),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandMark(dark: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                      'Firma digital con validez legal, respaldada por blockchain.',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sube tus documentos, fírmalos y comprueba su integridad en cualquier momento.',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    const _Feature(icon: Icons.lock_outline_rounded, text: 'Cifrado SHA-256 de extremo a extremo'),
                    const SizedBox(height: 14),
                    const _Feature(icon: Icons.link_rounded, text: 'Registro inmutable en Ethereum Sepolia'),
                    const SizedBox(height: 14),
                    const _Feature(icon: Icons.auto_awesome_rounded, text: 'Análisis inteligente de documentos con IA'),
                  ]),
                ),
                Text(
                  'Universidad Manuela Beltrán · IS25133 · 2026',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
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
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600))),
    ]);
  }
}

/// Logo + nombre. dark=true → sobre fondo de color (texto blanco).
class _BrandMark extends StatelessWidget {
  final bool dark;
  const _BrandMark({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.18) : null,
          gradient: dark ? null : const LinearGradient(colors: [AppTheme.primary, AppTheme.featureCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BlockSign',
            style: TextStyle(color: dark ? Colors.white : AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
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
    return SizedBox(
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
