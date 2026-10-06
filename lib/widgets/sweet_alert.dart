import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Alertas estilo SweetAlert2 para BlockSign, sin dependencias externas.
///
/// Uso:
///   await SweetAlert.success(context, title: '¡Listo!', text: 'Cuenta creada');
///   await SweetAlert.error(context, title: 'Error', text: 'Algo salió mal');
///   final ok = await SweetAlert.confirm(context, title: '¿Seguro?', text: '...');
enum SweetAlertType { success, error, warning, info, question }

const _kBrand = Color(0xFF6366F1); // índigo BlockSign
const _kCancel = Color(0xFF6E7881);

Color _typeColor(SweetAlertType t) {
  switch (t) {
    case SweetAlertType.success:
      return const Color(0xFF22C55E);
    case SweetAlertType.error:
      return const Color(0xFFEF4444);
    case SweetAlertType.warning:
      return const Color(0xFFF59E0B);
    case SweetAlertType.info:
      return const Color(0xFF3B82F6);
    case SweetAlertType.question:
      return const Color(0xFF8B5CF6);
  }
}

/// Muestra la alerta. Devuelve true si se pulsó el botón de confirmar,
/// false si se pulsó cancelar y null si se cerró tocando fuera.
Future<bool?> showSweetAlert(
  BuildContext context, {
  required SweetAlertType type,
  required String title,
  String? text,
  String confirmText = 'Aceptar',
  String? cancelText,
  Color? confirmColor,
  bool barrierDismissible = true,
  Duration? autoClose,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'SweetAlert',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => _SweetAlertDialog(
      type: type,
      title: title,
      text: text,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor ?? _kBrand,
      autoClose: autoClose,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Atajos
class SweetAlert {
  static Future<bool?> success(BuildContext context,
          {required String title,
          String? text,
          String confirmText = 'Aceptar',
          bool barrierDismissible = true,
          Duration? autoClose}) =>
      showSweetAlert(context,
          type: SweetAlertType.success,
          title: title,
          text: text,
          confirmText: confirmText,
          barrierDismissible: barrierDismissible,
          autoClose: autoClose);

  static Future<bool?> error(BuildContext context,
          {required String title,
          String? text,
          String confirmText = 'Entendido',
          bool barrierDismissible = true}) =>
      showSweetAlert(context,
          type: SweetAlertType.error,
          title: title,
          text: text,
          confirmText: confirmText,
          confirmColor: _typeColor(SweetAlertType.error),
          barrierDismissible: barrierDismissible);

  static Future<bool?> warning(BuildContext context,
          {required String title, String? text, String confirmText = 'Aceptar'}) =>
      showSweetAlert(context,
          type: SweetAlertType.warning,
          title: title,
          text: text,
          confirmText: confirmText);

  static Future<bool?> info(BuildContext context,
          {required String title, String? text, String confirmText = 'Aceptar'}) =>
      showSweetAlert(context,
          type: SweetAlertType.info, title: title, text: text, confirmText: confirmText);

  /// Confirmación con dos botones. Devuelve true solo si confirma.
  /// Para acciones destructivas: type: SweetAlertType.warning, danger: true
  static Future<bool> confirm(BuildContext context,
      {required String title,
      String? text,
      String confirmText = 'Sí, continuar',
      String cancelText = 'Cancelar',
      SweetAlertType type = SweetAlertType.question,
      bool danger = false}) async {
    final r = await showSweetAlert(context,
        type: type,
        title: title,
        text: text,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: danger ? _typeColor(SweetAlertType.error) : null);
    return r == true;
  }
}

// ─────────────────────────────────────────
// DIÁLOGO
// ─────────────────────────────────────────
class _SweetAlertDialog extends StatefulWidget {
  final SweetAlertType type;
  final String title;
  final String? text;
  final String confirmText;
  final String? cancelText;
  final Color confirmColor;
  final Duration? autoClose;

  const _SweetAlertDialog({
    required this.type,
    required this.title,
    required this.text,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    required this.autoClose,
  });

  @override
  State<_SweetAlertDialog> createState() => _SweetAlertDialogState();
}

class _SweetAlertDialogState extends State<_SweetAlertDialog>
    with TickerProviderStateMixin {
  late final AnimationController _draw;
  late final AnimationController _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _timer = AnimationController(
        vsync: this, duration: widget.autoClose ?? const Duration(seconds: 1));

    // Dibuja el ícono un poco después de que aparece el diálogo
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _draw.forward();
    });

    if (widget.autoClose != null) {
      _timer.forward().whenComplete(() => _close(true));
    }
  }

  void _close(bool? value) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _draw.dispose();
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(widget.type);
    final width = math.min(420.0, MediaQuery.of(context).size.width - 48);

    return Center(
      child: Material(
        color: Colors.white,
        elevation: 24,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _draw,
                      builder: (_, __) => CustomPaint(
                        size: const Size(88, 88),
                        painter: _SweetIconPainter(
                          type: widget.type,
                          color: color,
                          progress: Curves.easeOut.transform(_draw.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (widget.text != null && widget.text!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.text!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (widget.cancelText != null)
                          _SweetButton(
                            label: widget.cancelText!,
                            color: _kCancel,
                            onTap: () => _close(false),
                          ),
                        _SweetButton(
                          label: widget.confirmText,
                          color: widget.confirmColor,
                          onTap: () => _close(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Barra de progreso del cierre automático
              if (widget.autoClose != null)
                AnimatedBuilder(
                  animation: _timer,
                  builder: (_, __) => LinearProgressIndicator(
                    value: 1 - _timer.value,
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.6)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SweetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SweetButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────
// ÍCONO ANIMADO (círculo + símbolo dibujado)
// ─────────────────────────────────────────
class _SweetIconPainter extends CustomPainter {
  final SweetAlertType type;
  final Color color;
  final double progress; // 0 → 1

  _SweetIconPainter(
      {required this.type, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = size.center(Offset.zero);
    final r = w / 2 - 3;

    // Anillo de fondo
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Relleno suave
    canvas.drawCircle(c, r - 2, Paint()..color = color.withOpacity(0.06));

    // Anillo que se dibuja (primera mitad de la animación)
    final ringT = (progress / 0.5).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ringT,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Símbolo (segunda parte de la animación)
    final t = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    if (t <= 0) return;

    final mark = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(w * x, w * y);

    if (type == SweetAlertType.success) {
      final path = Path()
        ..moveTo(p(0.29, 0.52).dx, p(0.29, 0.52).dy)
        ..lineTo(p(0.44, 0.66).dx, p(0.44, 0.66).dy)
        ..lineTo(p(0.72, 0.37).dx, p(0.72, 0.37).dy);
      _drawPartial(canvas, path, t, mark);
    } else if (type == SweetAlertType.error) {
      final t1 = (t * 2).clamp(0.0, 1.0);
      final t2 = (t * 2 - 1).clamp(0.0, 1.0);
      _drawPartial(canvas, _line(p(0.34, 0.34), p(0.66, 0.66)), t1, mark);
      if (t2 > 0) {
        _drawPartial(canvas, _line(p(0.66, 0.34), p(0.34, 0.66)), t2, mark);
      }
    } else if (type == SweetAlertType.warning) {
      _drawPartial(canvas, _line(p(0.5, 0.26), p(0.5, 0.58)), t, mark);
      if (t > 0.75) {
        canvas.drawCircle(p(0.5, 0.72), 3.8, Paint()..color = color);
      }
    } else if (type == SweetAlertType.info) {
      canvas.drawCircle(p(0.5, 0.29), 3.8 * t, Paint()..color = color);
      _drawPartial(canvas, _line(p(0.5, 0.42), p(0.5, 0.73)), t, mark);
    } else {
      // question: "?" con fundido
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            color: color.withOpacity(t),
            fontSize: w * 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  Path _line(Offset a, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy);

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_SweetIconPainter old) =>
      old.progress != progress || old.type != type || old.color != color;
}
