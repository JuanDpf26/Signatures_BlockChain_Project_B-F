import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Componentes de interfaz de BlockSign (estilo panel administrativo):
/// encabezado con migas de pan, tarjetas blancas con borde, KPIs con
/// borde de color, píldoras de estado con punto, aviso informativo y
/// pares etiqueta/valor.

// ── Colores semánticos ──────────────────────────────────────────────
class BSColors {
  static const success = Color(0xFF1F9D55);
  static const warning = Color(0xFFD9861A);
  static const danger = Color(0xFFDC4B4B);
  static const neutral = Color(0xFF64748B);
  static const page = Color(0xFFF5F7FA); // fondo gris claro de página
}

// ── Encabezado de página ────────────────────────────────────────────
class BSPageHeader extends StatelessWidget {
  final List<String> breadcrumb; // ej: ['Inicio', 'Documentos']
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;

  const BSPageHeader({
    super.key,
    required this.breadcrumb,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          breadcrumb.join(' / '),
          style: const TextStyle(color: AppTheme.hint, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.text,
                fontSize: isWide ? 26 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            ...badges,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        ],
      ],
    );

    if (actions.isEmpty) return BSEntrance(child: titleBlock);

    return BSEntrance(child: isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              Wrap(spacing: 10, children: actions),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ));
  }
}

// ── Tarjeta blanca con borde ────────────────────────────────────────
class BSCard extends StatefulWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  /// Se eleva suavemente al pasar el mouse (true por defecto si hay onTap)
  final bool? hoverable;

  const BSCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.onTap,
    this.hoverable,
  });

  @override
  State<BSCard> createState() => _BSCardState();
}

class _BSCardState extends State<BSCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.hoverable ?? widget.onTap != null;
    final lifted = interactive && _hover;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor ?? (lifted ? AppTheme.primary.withOpacity(0.25) : AppTheme.border)),
        boxShadow: lifted ? AppTheme.hoverShadow : AppTheme.cardShadow,
      ),
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title!,
                    style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          widget.child,
        ],
      ),
    );
    if (!interactive) return card;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: BSPressable(onTap: widget.onTap, hoverLift: false, pressedScale: widget.onTap != null ? 0.985 : 1, child: card),
    );
  }
}

// ── KPI con borde de color a la izquierda ───────────────────────────
class BSKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final String? caption;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const BSKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    required this.color,
    this.icon,
    this.onTap,
  });

  @override
  State<BSKpiCard> createState() => _BSKpiCardState();
}

class _BSKpiCardState extends State<BSKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final number = int.tryParse(widget.value);
    final valueStyle = const TextStyle(color: AppTheme.text, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: BSPressable(
        onTap: widget.onTap,
        hoverLift: false,
        pressedScale: widget.onTap != null ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? c.withOpacity(0.35) : AppTheme.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _hover ? c.withOpacity(0.07) : c.withOpacity(0.025)],
            ),
            boxShadow: _hover
                ? [BoxShadow(color: c.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))]
                : AppTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              // Franja de color que se ensancha al pasar el mouse
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: _hover ? 5 : 3.5,
                  color: c,
                ),
              ),
              // Círculo decorativo
              Positioned(
                right: -18,
                top: -18,
                child: AnimatedScale(
                  scale: _hover ? 1.15 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.07)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.label,
                          style: const TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      number == null
                          ? Text(widget.value, style: valueStyle)
                          : TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: number.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => Text('${v.round()}', style: valueStyle),
                            ),
                      if (widget.caption != null) ...[
                        const SizedBox(height: 4),
                        Text(widget.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
                  if (widget.icon != null)
                    AnimatedRotation(
                      turns: _hover ? -0.03 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(widget.icon, color: c, size: 19),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fila de KPIs: 4 columnas en pantallas anchas, 2 en móvil.
/// Usa filas con Expanded (sin LayoutBuilder ni anchos calculados), así
/// nunca puede generar anchos negativos.
class BSKpiRow extends StatelessWidget {
  final List<BSKpiCard> items;
  const BSKpiRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.of(context).size.width > 1000 ? items.length : 2;
    return _bsGrid([
      for (var i = 0; i < items.length; i++) BSEntrance(delay: Duration(milliseconds: 60 * i), child: items[i]),
    ], cols, 12, 12);
  }
}

/// Reparte widgets en filas de [cols] columnas iguales.
Widget _bsGrid(List<Widget> items, int cols, double hGap, double vGap) {
  final rows = <Widget>[];
  for (var i = 0; i < items.length; i += cols) {
    final cells = <Widget>[];
    for (var j = 0; j < cols; j++) {
      if (j > 0) cells.add(SizedBox(width: hGap));
      final k = i + j;
      cells.add(Expanded(child: k < items.length ? items[k] : const SizedBox.shrink()));
    }
    if (rows.isNotEmpty) rows.add(SizedBox(height: vGap));
    rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);
}

// ── Píldora de estado con punto ─────────────────────────────────────
class BSPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const BSPill({super.key, required this.label, required this.color, this.dot = true});

  /// Estados de documentos de BlockSign
  factory BSPill.docStatus(String status) {
    switch (status) {
      case 'pending':
        return const BSPill(label: 'Pendiente', color: BSColors.warning);
      case 'signed':
        return const BSPill(label: 'Firmado', color: AppTheme.primary);
      case 'verified':
        return const BSPill(label: 'Verificado', color: BSColors.success);
      case 'rejected':
        return const BSPill(label: 'Rechazado', color: BSColors.danger);
      case 'chain':
        return const BSPill(label: 'En blockchain…', color: AppTheme.featureCyan);
      case 'revoked':
        return const BSPill(label: 'Revocado', color: BSColors.danger);
      default:
        return BSPill(label: status, color: BSColors.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Etiqueta en español para un estado de documento
String bsDocStatusLabel(String s) => const {
      'pending': 'Pendiente',
      'signed': 'Firmado',
      'verified': 'Verificado',
      'rejected': 'Rechazado',
      'chain': 'En blockchain…',
      'revoked': 'Revocado',
      'Todos': 'Todos',
    }[s] ??
    s;

// ── Aviso informativo ───────────────────────────────────────────────
class BSInfoBanner extends StatelessWidget {
  final String title;
  final String? text;
  final Color color;
  final IconData icon;

  const BSInfoBanner({
    super.key,
    required this.title,
    this.text,
    this.color = AppTheme.primary,
    this.icon = Icons.info_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                if (text != null) ...[
                  const SizedBox(height: 2),
                  Text(text!,
                      style: TextStyle(color: color.withOpacity(0.85), fontSize: 12, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Par etiqueta / valor (fichas de detalle) ────────────────────────
class BSLabelValue extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const BSLabelValue({super.key, required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

/// Rejilla de 2 columnas (1 en pantallas angostas) para pares etiqueta/valor
class BSLabelGrid extends StatelessWidget {
  final List<BSLabelValue> items;
  const BSLabelGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.of(context).size.width > 900 ? 2 : 1;
    return _bsGrid(items, cols, 18, 14);
  }
}

// ── Cuadro con inicial (avatar cuadrado de filas) ───────────────────
class BSInitialBox extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const BSInitialBox({super.key, required this.text, this.color = AppTheme.primary, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: icon != null
          ? Icon(icon, color: color, size: 18)
          : Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

// ── Desplegable de filtro "Etiqueta: Valor" ─────────────────────────
class BSFilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final String Function(String)? display;
  final ValueChanged<String> onChanged;

  const BSFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.display,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != 'Todos';
    final String Function(String) show = display ?? ((String s) => s);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppTheme.primary.withOpacity(0.45) : AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: active ? AppTheme.primary : AppTheme.hint, size: 18),
          selectedItemBuilder: (_) => options
              .map((o) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$label: ${show(o)}',
                        style: TextStyle(
                            color: active ? AppTheme.primary : AppTheme.text,
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                  ))
              .toList(),
          items: options
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(show(o),
                      style: const TextStyle(fontSize: 13, color: AppTheme.text))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Botones estándar ────────────────────────────────────────────────
class BSPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;

  const BSPrimaryButton(
      {super.key, required this.label, this.icon, this.onPressed, this.loading = false, this.color});

  @override
  Widget build(BuildContext context) {
    return BSPressable(
      glowColor: onPressed == null || loading ? null : (color ?? AppTheme.primary),
      child: SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (color ?? AppTheme.primary).withOpacity(0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          // El tema global usa ancho infinito; aquí el botón se ajusta a su contenido
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon ?? Icons.check_rounded, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      ),
    );
  }
}

class BSOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  const BSOutlineButton({super.key, required this.label, this.icon, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return BSPressable(
      child: SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          backgroundColor: Colors.white,
          side: BorderSide(color: c.withOpacity(0.55), width: 1.2),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      ),
    );
  }
}


// ── Fecha, hora y saludo en español ─────────────────────────────────
const _bsDias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _bsMeses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// "Sábado, 3 de octubre de 2026"
String bsFechaLarga(DateTime d) {
  final dia = _bsDias[d.weekday - 1];
  return '${dia[0].toUpperCase()}${dia.substring(1)}, ${d.day} de ${_bsMeses[d.month - 1]} de ${d.year}';
}

/// "10:25 p. m."
String bsHora(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// "Buenos días" / "Buenas tardes" / "Buenas noches"
String bsSaludo(DateTime d) =>
    d.hour < 12 ? 'Buenos días' : (d.hour < 19 ? 'Buenas tardes' : 'Buenas noches');

/// Primer nombre a partir del nombre completo
String bsPrimerNombre(String? nombre) {
  final n = (nombre ?? '').trim();
  if (n.isEmpty) return '';
  return n.split(RegExp(r'\s+')).first;
}

/// Iniciales (máx. 2) para avatares
String bsIniciales(String? nombre) {
  final partes = (nombre ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return 'U';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// Reconstruye su contenido cada segundo con la hora actual.
class BSLiveClock extends StatefulWidget {
  final Widget Function(BuildContext context, DateTime now) builder;
  const BSLiveClock({super.key, required this.builder});

  @override
  State<BSLiveClock> createState() => _BSLiveClockState();
}

class _BSLiveClockState extends State<BSLiveClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// Avatar circular con foto o iniciales.
/// Si la foto falla (p. ej. Google responde 429 por demasiadas descargas),
/// muestra las iniciales y recuerda la URL fallida para no volver a pedirla.
class BSAvatar extends StatefulWidget {
  final String? name;
  final String? url;
  final double radius;
  const BSAvatar({super.key, this.name, this.url, this.radius = 18});

  /// URLs que ya fallaron en esta sesión
  static final Set<String> failedUrls = {};

  @override
  State<BSAvatar> createState() => _BSAvatarState();
}

class _BSAvatarState extends State<BSAvatar> {
  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final usable = url != null && url.isNotEmpty && !BSAvatar.failedUrls.contains(url);
    final initials = Text(bsIniciales(widget.name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: widget.radius * 0.75));
    final size = widget.radius * 2;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: !usable
          ? initials
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (_, child, frame, sync) => frame == null && !sync ? initials : child,
              errorBuilder: (_, __, ___) {
                if (BSAvatar.failedUrls.add(url)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                }
                return initials;
              },
            ),
    );
  }
}



// ─────────────────────────────────────────────────────────────
// INTERACCIONES
// ─────────────────────────────────────────────────────────────

/// Envuelve cualquier widget para darle vida al tocarlo:
/// se encoge un poco al presionar y (opcional) se eleva con brillo al pasar el mouse.
/// Usa Listener, así no le quita el toque a los botones que envuelve.
class BSPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool hoverLift;
  final Color? glowColor;
  const BSPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.hoverLift = true,
    this.glowColor,
  });

  @override
  State<BSPressable> createState() => _BSPressableState();
}

class _BSPressableState extends State<BSPressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _down ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, widget.hoverLift && _hover && !_down ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: widget.glowColor != null && _hover
              ? [BoxShadow(color: widget.glowColor!.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))]
              : const [],
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap != null) {
      child = GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: child);
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: child,
      ),
    );
  }
}

/// Aparición suave (sube y se desvanece) la primera vez que se muestra.
class BSEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;
  const BSEntrance({super.key, required this.child, this.delay = Duration.zero, this.offsetY = 14});

  @override
  State<BSEntrance> createState() => _BSEntranceState();
}

class _BSEntranceState extends State<BSEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, widget.offsetY * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}
