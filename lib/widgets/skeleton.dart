import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Marcadores grises que muestran la forma del contenido mientras carga,
/// en lugar de un círculo girando. Respetan "Reducir movimiento".
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), lowerBound: 0.45, upperBound: 1)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return Opacity(opacity: 0.7, child: widget.child);
    return FadeTransition(opacity: _c, child: widget.child);
  }
}

class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Bone({this.width, this.height = 12, this.radius = 6});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.isDark ? Colors.white.withOpacity(0.09) : const Color(0xFFE6EAF0),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Lista de filas en carga: ícono, dos líneas de texto y una etiqueta
class SkeletonList extends StatelessWidget {
  final int rows;
  final bool leading;
  final bool trailing;
  final EdgeInsetsGeometry padding;
  const SkeletonList({super.key, this.rows = 5, this.leading = true, this.trailing = true, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8)});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: _Pulse(
        child: Padding(
          padding: padding,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  if (leading) ...[const _Bone(width: 36, height: 36, radius: 10), const SizedBox(width: 12)],
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _Bone(width: c.maxWidth * (i.isEven ? 0.62 : 0.48), height: 13),
                        const SizedBox(height: 8),
                        _Bone(width: c.maxWidth * (i.isEven ? 0.4 : 0.55), height: 10),
                      ]),
                    ),
                  ),
                  if (trailing) ...[const SizedBox(width: 12), const _Bone(width: 72, height: 24, radius: 12)],
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Bloque en carga para tarjetas y paneles
class SkeletonBlock extends StatelessWidget {
  final double height;
  const SkeletonBlock({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: SizedBox(
        height: height,
        child: _Pulse(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (_, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Bone(width: c.maxWidth * 0.35, height: 16),
                const SizedBox(height: 16),
                if (c.maxHeight > 90) ...[_Bone(width: c.maxWidth * 0.9), const SizedBox(height: 10)],
                if (c.maxHeight > 120) ...[_Bone(width: c.maxWidth * 0.75), const SizedBox(height: 10)],
                if (c.maxHeight > 150) _Bone(width: c.maxWidth * 0.55),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
