import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Componentes de interfaz de BlockSign (estilo panel administrativo):
/// encabezado con migas de pan, tarjetas blancas con borde, KPIs con
/// borde de color, píldoras de estado con punto, aviso informativo y
/// pares etiqueta/valor.

// ── Colores semánticos ──────────────────────────────────────────────
class BSColors {
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const neutral = Color(0xFF6B7280);
  static const page = Color(0xFFF4F6FA); // fondo gris claro de página
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

    if (actions.isEmpty) return titleBlock;

    return isWide
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
          );
  }
}

// ── Tarjeta blanca con borde ────────────────────────────────────────
class BSCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const BSCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppTheme.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

// ── KPI con borde de color a la izquierda ───────────────────────────
class BSKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color color;

  const BSKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Borde izquierdo de color sin IntrinsicHeight: ClipRRect redondea y el
    // Border no uniforme (sin borderRadius en la decoración) pinta la franja.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: color, width: 4),
            top: const BorderSide(color: AppTheme.border),
            right: const BorderSide(color: AppTheme.border),
            bottom: const BorderSide(color: AppTheme.border),
          ),
        ),
        child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.hint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(value,
                        style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(caption!,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
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
    return _bsGrid(items, cols, 12, 12);
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
    return SizedBox(
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
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c, width: 1.2),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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

/// Avatar circular con foto o iniciales
class BSAvatar extends StatelessWidget {
  final String? name;
  final String? url;
  final double radius;
  const BSAvatar({super.key, this.name, this.url, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl
          ? null
          : Text(bsIniciales(name),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.75)),
    );
  }
}
