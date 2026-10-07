import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/chain_steps.dart' show openExternal;

/// Auditoría: todo lo que se hizo con la cuenta, con fecha, IP, ID de
/// petición y resultado. Los datos vienen de la tabla audit_logs.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;
  String _type = 'Todos';
  String _result = 'Todos';

  static const _types = {
    'Todos': '',
    'Sesión y cuenta': 'auth',
    'Documentos': 'document',
    'Firma y verificación': 'signing',
    'Perfil': 'profile',
    'Sign IA': 'agent',
    'Bandeja': 'inbox',
    'Equipos': 'team',
  };
  static const _results = ['Todos', 'permitido', 'denegado', 'error'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await AuditService.getMyAudit(
      action: _types[_type],
      result: _result == 'Todos' ? null : _result,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['error'] != null) {
        _error = res['error'].toString();
      } else {
        _events = ((res['events'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _summary = Map<String, dynamic>.from((res['summary'] as Map?) ?? {});
      }
    });
  }

  /// Diálogo para descargar el registro: formato y periodo (usa los filtros actuales)
  Future<void> _download() async {
    final opts = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ExportDialog(filters: [if (_type != 'Todos') _type, if (_result != 'Todos') _result]),
    );
    if (opts == null || !mounted) return;
    final r = await AuditService.exportLink(
      format: opts.$1,
      period: opts.$2,
      action: _types[_type],
      result: _result == 'Todos' ? null : _result,
    );
    if (!mounted) return;
    if (r['error'] != null || r['url'] == null) {
      await SweetAlert.error(context, title: 'No se pudo descargar', text: (r['error'] ?? 'Intenta de nuevo').toString());
      return;
    }
    await openExternal(r['url'].toString());
    if (!mounted) return;
    SweetAlert.success(
      context,
      title: opts.$1 == 'csv' ? 'Descargando registro' : 'Informe abierto',
      text: opts.$1 == 'csv'
          ? 'El archivo CSV se abre en Excel. La descarga también queda registrada en la auditoría.'
          : 'Usa “Imprimir o guardar como PDF” en la pestaña que se abrió.',
      autoClose: const Duration(milliseconds: 2200),
    );
  }

  String _fmt(String? iso, {bool seconds = false}) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}${seconds ? ':${two(d.second)}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 28.0 : 16.0;
    int n(String k) => int.tryParse('${_summary[k] ?? 0}') ?? 0;
    String v(int x) => _loading ? '–' : '$x';

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Auditoría'],
              title: 'Auditoría',
              subtitle: 'Cada acción queda registrada: quién la hizo, qué hizo, cuándo, desde dónde y con qué resultado.',
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: _loading ? null : _load),
                BSPrimaryButton(label: 'Descargar registro', icon: Icons.download_rounded, onPressed: _download),
              ],
            ),
            const SizedBox(height: 18),
            const BSInfoBanner(
              title: 'Registro de trazabilidad.',
              text: 'Nunca se guardan contraseñas, tokens ni el contenido de tus documentos. Los eventos de firma incluyen la transacción y el bloque.',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 16),
            BSKpiRow(items: [
              BSKpiCard(label: 'Eventos registrados', value: v(n('total')), caption: '${v(n('last7'))} en los últimos 7 días', color: AppTheme.primary, icon: Icons.monitor_heart_outlined),
              BSKpiCard(label: 'Accesos denegados', value: v(n('denied')), caption: n('denied') > 0 ? 'Tokens vencidos o rechazados' : 'Sin intentos sospechosos', color: BSColors.warning, icon: Icons.gpp_maybe_outlined),
              BSKpiCard(
                label: 'Último ingreso',
                value: _loading ? '–' : (_summary['last_login'] == null ? '—' : _fmt(_summary['last_login']?.toString()).split(' ').last),
                caption: _summary['last_login'] == null ? 'Sin registro' : _fmt(_summary['last_login']?.toString()).split(' ').first,
                color: BSColors.success,
                icon: Icons.person_outline_rounded,
              ),
              BSKpiCard(label: 'Direcciones IP', value: v(n('ips')), caption: '${v(n('errors'))} operaciones con error', color: AppTheme.featureCyan, icon: Icons.public_rounded),
            ]),
            const SizedBox(height: 16),
            BSCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                BSFilterDropdown(
                  label: 'Tipo',
                  value: _type,
                  options: _types.keys.toList(),
                  onChanged: (x) {
                    setState(() => _type = x);
                    _load();
                  },
                ),
                BSFilterDropdown(
                  label: 'Resultado',
                  value: _result,
                  options: _results,
                  display: (s) => s == 'Todos' ? 'Todos' : '${s[0].toUpperCase()}${s.substring(1)}',
                  onChanged: (x) {
                    setState(() => _result = x);
                    _load();
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),
            BSCard(
              title: 'Últimos eventos',
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: _body(w > 900),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body(bool table) {
    if (_loading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    if (_error != null) {
      return BSInfoBanner(title: 'No se pudo cargar', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded);
    }
    if (_events.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Aún no hay eventos con estos filtros.', style: TextStyle(color: AppTheme.hint))),
      );
    }
    const head = TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8);
    return Column(children: [
      if (table)
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Row(children: [
            Expanded(flex: 3, child: Text('FECHA Y HORA', style: head)),
            Expanded(flex: 5, child: Text('EVENTO', style: head)),
            Expanded(flex: 3, child: Text('RECURSO', style: head)),
            Expanded(flex: 3, child: Text('IP', style: head)),
            Expanded(flex: 3, child: Text('ID DE PETICIÓN', style: head)),
            SizedBox(width: 132, child: Text('RESULTADO', style: head)),
          ]),
        ),
      const Divider(height: 1, color: AppTheme.border),
      for (var i = 0; i < _events.length; i++) ...[
        BSEntrance(
          key: ValueKey('ev-${_events[i]['id']}'),
          delay: Duration(milliseconds: 25 * (i < 15 ? i : 15)),
          offsetY: 8,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _showDetail(_events[i]),
              hoverColor: BSColors.selected.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: table ? _row(_events[i]) : _tile(_events[i]),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text('Mostrando ${_events.length} eventos · toca uno para ver el detalle',
            style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
      ),
    ]);
  }

  static Color resultColor(String? r) => switch (r) {
        'permitido' => BSColors.success,
        'denegado' => BSColors.danger,
        _ => BSColors.warning,
      };

  static IconData iconFor(String action) {
    if (action.startsWith('auth')) return Icons.login_rounded;
    if (action.startsWith('document')) return Icons.description_outlined;
    if (action.startsWith('signing')) return Icons.draw_outlined;
    if (action.startsWith('profile')) return Icons.person_outline_rounded;
    if (action.startsWith('agent')) return Icons.auto_awesome_outlined;
    return Icons.receipt_long_outlined;
  }

  String _short(String? s, [int n = 8]) {
    if (s == null || s.isEmpty) return '—';
    return s.length > n * 2 + 1 ? '${s.substring(0, n)}…${s.substring(s.length - 4)}' : s;
  }

  Widget _pill(Map<String, dynamic> e) {
    final r = e['result']?.toString() ?? 'permitido';
    return BSPill(label: '${r[0].toUpperCase()}${r.substring(1)}', color: resultColor(r));
  }

  Widget _row(Map<String, dynamic> e) {
    const cell = TextStyle(color: AppTheme.text, fontSize: 14);
    const mono = TextStyle(color: AppTheme.hint, fontSize: 13, fontFamily: 'monospace');
    final action = e['action']?.toString() ?? '';
    return Row(children: [
      Expanded(flex: 3, child: Text(_fmt(e['created_at']?.toString()), style: const TextStyle(color: AppTheme.hint, fontSize: 13.5))),
      Expanded(
        flex: 5,
        child: Row(children: [
          Icon(iconFor(action), size: 17, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e['description']?.toString() ?? action,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: cell.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      Expanded(flex: 3, child: Text(_short(e['resource']?.toString()), style: mono)),
      Expanded(flex: 3, child: Text(e['ip']?.toString() ?? '—', style: mono)),
      Expanded(flex: 3, child: Text(_short(e['request_id']?.toString(), 4), style: mono)),
      SizedBox(
        width: 132,
        child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: _pill(e))),
      ),
    ]);
  }

  Widget _tile(Map<String, dynamic> e) {
    final action = e['action']?.toString() ?? '';
    return Row(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: BSColors.selected, borderRadius: BorderRadius.circular(10)),
        child: Icon(iconFor(action), size: 19, color: AppTheme.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e['description']?.toString() ?? action,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${_fmt(e['created_at']?.toString())} · ${e['ip'] ?? '—'}', style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
        ]),
      ),
      const SizedBox(width: 8),
      _pill(e),
    ]);
  }

  void _showDetail(Map<String, dynamic> e) {
    final detail = e['detail'];
    final rows = <(String, String)>[
      ('Fecha y hora', _fmt(e['created_at']?.toString(), seconds: true)),
      ('Acción', e['action']?.toString() ?? '—'),
      ('Resultado', '${e['result'] ?? '—'} (HTTP ${e['status_code'] ?? '—'})'),
      ('Recurso', e['resource']?.toString() ?? '—'),
      ('Petición', '${e['method'] ?? ''} ${e['path'] ?? ''}'.trim()),
      ('IP', e['ip']?.toString() ?? '—'),
      ('ID de petición', e['request_id']?.toString() ?? '—'),
      ('Navegador', e['user_agent']?.toString() ?? '—'),
      if (detail != null) ('Detalle', const JsonEncoder.withIndent('  ').convert(detail)),
    ];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(iconFor(e['action']?.toString() ?? ''), color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e['description']?.toString() ?? 'Evento',
                      style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                _pill(e),
              ]),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 120, child: Text(r.$1, style: const TextStyle(color: AppTheme.hint, fontSize: 13))),
                          Expanded(
                            child: SelectableText(r.$2,
                                style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
                BSOutlineButton(
                  label: 'Copiar ID',
                  icon: Icons.copy_rounded,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: e['request_id']?.toString() ?? ''));
                    if (ctx.mounted) SweetAlert.success(ctx, title: 'ID copiado', autoClose: const Duration(milliseconds: 1000));
                  },
                ),
                BSPrimaryButton(label: 'Cerrar', icon: Icons.close_rounded, onPressed: () => Navigator.pop(ctx)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


// ── Diálogo de descarga ────────────────────────────────────
class _ExportDialog extends StatefulWidget {
  final List<String> filters;
  const _ExportDialog({required this.filters});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  String _format = 'csv';
  String _period = '30d';

  Widget _formatOption(String value, IconData icon, String title, String help) {
    final sel = _format == value;
    return InkWell(
      onTap: () => setState(() => _format = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.border, width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: sel ? AppTheme.primary : AppTheme.text, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(help, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
            ]),
          ),
          if (sel) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const periods = {'7d': 'Últimos 7 días', '30d': 'Últimos 30 días', '90d': 'Últimos 90 días', 'all': 'Todo el historial'};
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Descargar registro de auditoría', style: TextStyle(color: AppTheme.text, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              widget.filters.isEmpty ? 'Incluye todas las acciones y resultados.' : 'Con los filtros actuales: ${widget.filters.join(' · ')}.',
              style: const TextStyle(color: AppTheme.hint, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _formatOption('csv', Icons.table_chart_outlined, 'Excel (CSV)', 'Para filtrar y analizar en Excel o Google Sheets.'),
            const SizedBox(height: 10),
            _formatOption('html', Icons.picture_as_pdf_outlined, 'Informe para PDF', 'Con resumen y tabla; se imprime o guarda como PDF.'),
            const SizedBox(height: 18),
            const Text('Periodo', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in periods.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _period == e.key,
                  onSelected: (_) => setState(() => _period = e.key),
                  showCheckmark: false,
                  selectedColor: AppTheme.primary.withOpacity(0.12),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _period == e.key ? AppTheme.primary : AppTheme.border),
                  labelStyle: TextStyle(color: _period == e.key ? AppTheme.primary : AppTheme.text, fontWeight: _period == e.key ? FontWeight.w700 : FontWeight.w500, fontSize: 12.5),
                ),
            ]),
            const SizedBox(height: 16),
            const BSInfoBanner(
              title: 'Con huella de integridad',
              text: 'Cada descarga incluye la huella SHA-256 del contenido y queda registrada en la auditoría.',
              icon: Icons.fingerprint_rounded,
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              BSPrimaryButton(label: 'Descargar', icon: Icons.download_rounded, onPressed: () => Navigator.of(context).pop((_format, _period))),
            ]),
          ]),
        ),
      ),
    );
  }
}
