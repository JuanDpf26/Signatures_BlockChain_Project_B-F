import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'sweet_alert.dart';

/// Piezas para mostrar la evidencia de blockchain de forma clara:
/// primero lo que entiende cualquier persona (quién, cuándo, estado) y los
/// datos técnicos (transacción, bloque, gas, llaves) plegados aparte.

// ─────────────────────────────────────────
// FORMATOS
// ─────────────────────────────────────────

/// 11871509 → "11.871.509"
String fmtMiles(dynamic n) {
  final v = int.tryParse('${n ?? ''}'.replaceAll(RegExp(r'[^0-9-]'), ''));
  if (v == null) return '${n ?? '—'}';
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return v < 0 ? '-$b' : b.toString();
}

/// Huella o transacción abreviada: "e5ba393a…6fe3b5" / "0x961958…f16ef"
String fmtHuella(String? h, {int head = 8, int tail = 6}) {
  if (h == null || h.isEmpty) return '—';
  final pre = h.startsWith('0x') ? '0x' : '';
  final body = pre.isEmpty ? h : h.substring(2);
  if (body.length <= head + tail + 1) return h;
  return '$pre${body.substring(0, head)}…${body.substring(body.length - tail)}';
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// ISO → "8 oct 2026, 11:58 a. m." (hora local)
String fmtFechaHora(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  return '${d.day} ${_meses[d.month - 1]} ${d.year}, ${bsHora(d)}';
}

/// ISO → "8 oct 2026"
String fmtFecha(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  return '${d.day} ${_meses[d.month - 1]} ${d.year}';
}

/// Costo de la transacción en la red de prueba, en palabras
String fmtCostoRed(dynamic feeEth) {
  final v = double.tryParse('${feeEth ?? ''}');
  if (v == null) return 'Sin costo real (red de prueba)';
  final txt = v == 0 ? '0' : v.toStringAsPrecision(2).replaceAll('.', ',');
  return '$txt SepoliaETH · sin valor real (red de prueba)';
}

/// Bytes → "0,54 MB" / "82 KB"
String fmtTamano(Map meta) {
  final bytes = num.tryParse('${meta['size_bytes'] ?? ''}');
  final mb = bytes != null ? bytes / 1048576 : num.tryParse('${meta['size_mb'] ?? ''}');
  if (mb == null) return '—';
  if (mb < 0.1) return '${(mb * 1024).round()} KB';
  return '${mb.toStringAsFixed(2).replaceAll('.', ',')} MB';
}

Future<void> copiarValor(BuildContext context, String value, String what) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    SweetAlert.success(context, title: '$what copiado', autoClose: const Duration(milliseconds: 1100));
  }
}

Future<void> abrirEnlace(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

// ─────────────────────────────────────────
// HUELLA DIGITAL (abreviada, con copiar)
// ─────────────────────────────────────────
class HuellaField extends StatelessWidget {
  final String label;
  final String value;
  final String? help;
  const HuellaField({super.key, required this.label, required this.value, this.help});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: BSColors.page,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Tooltip(
              message: value,
              child: Text(fmtHuella(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace', letterSpacing: 0.2)),
            ),
            if (help != null) ...[
              const SizedBox(height: 2),
              Text(help!, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, height: 1.3)),
            ],
          ]),
        ),
        IconButton(
          tooltip: 'Copiar huella completa',
          onPressed: () => copiarValor(context, value, 'Huella'),
          icon: const Icon(Icons.copy_rounded, color: AppTheme.hint, size: 18),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// DATOS CLAVE (ícono · etiqueta · valor) en una o dos columnas
// ─────────────────────────────────────────
class Fact {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  const Fact(this.icon, this.label, {this.value, this.valueWidget});
}

class FactGrid extends StatelessWidget {
  final List<Fact> facts;
  /// Columnas en pantallas anchas (en celular siempre una)
  final int columns;
  const FactGrid({super.key, required this.facts, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 420 ? 1 : columns;
      final rows = <Widget>[];
      for (var i = 0; i < facts.length; i += cols) {
        final chunk = facts.sublist(i, (i + cols).clamp(0, facts.length));
        rows.add(Container(
          decoration: BoxDecoration(
            border: i + cols < facts.length ? const Border(bottom: BorderSide(color: Color(0xFFEDF0F5))) : null,
          ),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var k = 0; k < cols; k++) ...[
                if (k > 0) const SizedBox(width: 16),
                Expanded(child: k < chunk.length ? _FactCell(f: chunk[k]) : const SizedBox()),
              ],
            ]),
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

class _FactCell extends StatelessWidget {
  final Fact f;
  const _FactCell({required this.f});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(f.icon, size: 17, color: AppTheme.hint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            f.valueWidget ??
                Text(f.value ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// DETALLES TÉCNICOS (plegados por defecto)
// ─────────────────────────────────────────
class TechRow {
  final String label;
  final String value;
  /// Valor completo que se copia (si es distinto del que se muestra)
  final String? copyValue;
  final String? url;
  final bool mono;
  const TechRow(this.label, this.value, {this.copyValue, this.url, this.mono = false});
}

class TechDetails extends StatefulWidget {
  final List<TechRow> rows;
  final String title;
  final String? note;
  final bool initiallyOpen;
  const TechDetails({super.key, required this.rows, this.title = 'Detalles técnicos', this.note, this.initiallyOpen = false});

  @override
  State<TechDetails> createState() => _TechDetailsState();
}

class _TechDetailsState extends State<TechDetails> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const Icon(Icons.code_rounded, size: 17, color: AppTheme.hint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                Text(_open ? 'Ocultar' : 'Mostrar',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, size: 20, color: AppTheme.primary),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Container(
                  color: BSColors.page,
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < widget.rows.length; i++) _TechRowView(r: widget.rows[i], last: i == widget.rows.length - 1),
                    if (widget.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Text(widget.note!, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, height: 1.35)),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _TechRowView extends StatelessWidget {
  final TechRow r;
  final bool last;
  const _TechRowView({required this.r, required this.last});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE6EAF0)))),
      child: Row(children: [
        SizedBox(
          width: 118,
          child: Text(r.label, style: const TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Tooltip(
            message: r.copyValue ?? r.value,
            child: Text(r.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: r.mono ? 'monospace' : null,
                )),
          ),
        ),
        if (r.copyValue != null)
          _Mini(icon: Icons.copy_rounded, tooltip: 'Copiar', onTap: () => copiarValor(context, r.copyValue!, r.label)),
        if (r.url != null) _Mini(icon: Icons.open_in_new_rounded, tooltip: 'Abrir en el explorador', onTap: () => abrirEnlace(r.url!)),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _Mini({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 15, color: AppTheme.primary)),
        ),
      );
}

// ─────────────────────────────────────────
// SELLO DE ESTADO (banda de color con ícono)
// ─────────────────────────────────────────
class StatusSeal extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const StatusSeal({super.key, required this.icon, required this.color, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(color: AppTheme.text, fontSize: 12.5, height: 1.35)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}
