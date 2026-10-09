import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/chain_steps.dart';
import '../widgets/sweet_alert.dart';

/// Bandeja de entrada: documentos que te compartieron (y los que enviaste),
/// con solicitudes de revisión que puedes aprobar o rechazar.
class InboxScreen extends StatefulWidget {
  /// Se llama cuando cambia el número de no leídos (para el contador del menú)
  final VoidCallback? onChanged;
  const InboxScreen({super.key, this.onChanged});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

enum _Box { received, sent, archived }

extension on _Box {
  String get api => switch (this) { _Box.received => 'received', _Box.sent => 'sent', _Box.archived => 'archived' };
  String get label => switch (this) { _Box.received => 'Recibidos', _Box.sent => 'Enviados', _Box.archived => 'Archivados' };
  IconData get icon => switch (this) {
        _Box.received => Icons.inbox_rounded,
        _Box.sent => Icons.send_rounded,
        _Box.archived => Icons.archive_outlined,
      };
}

class _InboxScreenState extends State<InboxScreen> {
  _Box _box = _Box.received;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;
  Map<String, dynamic> _summary = {};
  final _searchCtrl = TextEditingController();
  String _readFilter = 'Todo'; // Todo | No leídos | Leídos | Por revisar

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _visible {
    if (_box == _Box.sent || _readFilter == 'Todo') return _items;
    return _items.where((it) {
      final st = it['status']?.toString();
      return switch (_readFilter) {
        'No leídos' => st == 'sent',
        'Leídos' => st != 'sent',
        'Por revisar' => it['kind'] == 'review' && (st == 'sent' || st == 'read'),
        _ => true,
      };
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool keepSelection = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!keepSelection) _selectedId = null;
    });
    final results = await Future.wait([
      CollabService.inbox(box: _box.api, q: _searchCtrl.text.trim()),
      CollabService.inboxSummary(),
    ]);
    if (!mounted) return;
    final res = results[0];
    setState(() {
      _loading = false;
      if (res['error'] != null) {
        _error = res['error'].toString();
        _items = [];
      } else {
        _items = ((res['items'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (results[1]['error'] == null) _summary = results[1];
    });
    widget.onChanged?.call();
  }

  void _open(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) return;
    final wide = MediaQuery.of(context).size.width >= 1000;
    // Se marca como leído en la lista de inmediato (el servidor lo marca al abrir)
    if (_box != _Box.sent && item['status'] == 'sent') {
      setState(() => item['status'] = 'read');
    }
    if (wide) {
      setState(() => _selectedId = id);
      Future.delayed(const Duration(milliseconds: 600), () => mounted ? _refreshSummary() : null);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: BSColors.page,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppTheme.text,
            elevation: 0,
            title: Text(_box == _Box.sent ? 'Enviado' : 'Mensaje', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          body: _InboxDetail(id: id, onChanged: () => _load(keepSelection: true), onClose: () => Navigator.of(context).pop()),
        ),
      )).then((_) => _load(keepSelection: true));
    }
  }

  Future<void> _refreshSummary() async {
    final s = await CollabService.inboxSummary();
    if (mounted && s['error'] == null) setState(() => _summary = s);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 28.0 : 16.0;
    final wide = w >= 1000;
    final unread = int.tryParse('${_summary['unread'] ?? 0}') ?? 0;
    final pendingReviews = int.tryParse('${_summary['pending_reviews'] ?? 0}') ?? 0;

    final list = _ListPanel(
      box: _box,
      items: _visible,
      readFilter: _readFilter,
      onReadFilter: (v) => setState(() => _readFilter = v),
      loading: _loading,
      error: _error,
      selectedId: _selectedId,
      unread: unread,
      searchCtrl: _searchCtrl,
      onBox: (b) {
        setState(() => _box = b);
        _load();
      },
      onSearch: () => _load(),
      onOpen: _open,
    );

    return Container(
      color: BSColors.page,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, wide ? 24 : 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BSPageHeader(
            breadcrumb: const ['Inicio', 'Bandeja'],
            title: 'Bandeja de entrada',
            subtitle: 'Documentos que te compartieron y los que enviaste, con sus revisiones y aprobaciones.',
            badges: [
              if (unread > 0) BSPill(label: '$unread sin leer', color: AppTheme.primary),
              if (pendingReviews > 0) BSPill(label: '$pendingReviews por revisar', color: BSColors.warning),
            ],
            actions: [BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: _loading ? null : () => _load(keepSelection: true))],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: w > 1350 ? 440 : 380, child: list),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _selectedId == null
                          ? const _EmptyDetail()
                          : _Panel(
                              child: _InboxDetail(
                                key: ValueKey(_selectedId),
                                id: _selectedId!,
                                onChanged: () => _load(keepSelection: true),
                                onClose: () => setState(() => _selectedId = null),
                              ),
                            ),
                    ),
                  ])
                : list,
          ),
        ]),
      ),
    );
  }
}

/// Contenedor blanco con borde (como una tarjeta que ocupa todo el alto)
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

// ─────────────────────────────────────────
// LISTA
// ─────────────────────────────────────────
class _ListPanel extends StatelessWidget {
  final _Box box;
  final List<Map<String, dynamic>> items;
  final String readFilter;
  final ValueChanged<String> onReadFilter;
  final bool loading;
  final String? error;
  final String? selectedId;
  final int unread;
  final TextEditingController searchCtrl;
  final ValueChanged<_Box> onBox;
  final VoidCallback onSearch;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _ListPanel({
    required this.box,
    required this.items,
    required this.readFilter,
    required this.onReadFilter,
    required this.loading,
    required this.error,
    required this.selectedId,
    required this.unread,
    required this.searchCtrl,
    required this.onBox,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    } else if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: BSInfoBanner(title: 'No se pudo cargar la bandeja', text: error, color: BSColors.danger, icon: Icons.error_outline_rounded),
      );
    } else if (items.isEmpty) {
      body = _EmptyList(box: box);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.border),
        itemBuilder: (_, i) => BSEntrance(
          delay: Duration(milliseconds: 25 * (i < 10 ? i : 10)),
          offsetY: 8,
          child: _InboxRow(item: items[i], sent: box == _Box.sent, selected: items[i]['id']?.toString() == selectedId, onTap: () => onOpen(items[i])),
        ),
      );
    }

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Carpetas
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              for (final b in _Box.values)
                Expanded(
                  child: _BoxTab(
                    box: b,
                    selected: b == box,
                    badge: b == _Box.received ? unread : 0,
                    onTap: () => onBox(b),
                  ),
                ),
            ]),
          ),
        ),
        // Filtro de lectura + buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            if (box != _Box.sent) ...[
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: readFilter,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.hint),
                    style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                    borderRadius: BorderRadius.circular(10),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'Todo', child: Text('Todo')),
                      DropdownMenuItem(value: 'No leídos', child: Text('No leídos')),
                      DropdownMenuItem(value: 'Leídos', child: Text('Leídos')),
                      DropdownMenuItem(value: 'Por revisar', child: Text('Por revisar')),
                    ],
                    onChanged: (v) {
                      if (v != null) onReadFilter(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchCtrl,
              onSubmitted: (_) => onSearch(),
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar por documento o mensaje…',
                hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
            ),
          )),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(child: body),
      ]),
    );
  }
}

class _BoxTab extends StatelessWidget {
  final _Box box;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _BoxTab({required this.box, required this.selected, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? AppTheme.cardShadow : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(box.icon, size: 16, color: selected ? AppTheme.primary : AppTheme.hint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(box.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: selected ? AppTheme.primary : AppTheme.hint, fontSize: 12.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

String inboxAgo(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays == 1) return 'ayer';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}

(String, Color) shareStatus(String? status, {bool sent = false}) => switch (status) {
      'approved' => ('Aprobado', BSColors.success),
      'rejected' => ('Rechazado', BSColors.danger),
      'read' => ('Leído', BSColors.neutral),
      _ => (sent ? 'Enviado' : 'Nuevo', AppTheme.primary),
    };

class _InboxRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool sent;
  final bool selected;
  final VoidCallback onTap;
  const _InboxRow({required this.item, required this.sent, required this.selected, required this.onTap});

  @override
  State<_InboxRow> createState() => _InboxRowState();
}

class _InboxRowState extends State<_InboxRow> {
  bool _hover = false;

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
  static String _fecha(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return d.inMinutes < 1 ? 'ahora' : 'hace ${d.inMinutes} min';
    if (d.inHours < 12 && t.day == DateTime.now().day) return 'hoy, ${bsHora(t)}';
    return '${t.day} ${_meses[t.month - 1]} ${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final review = it['kind'] == 'review';
    final status = it['status']?.toString();
    final unread = !widget.sent && status == 'sent';
    final recipients = ((it['recipients'] as List?) ?? const []).whereType<Map>().toList();
    final title = (it['subject']?.toString().trim().isNotEmpty == true ? it['subject'] : it['doc_title'])?.toString() ?? 'Documento';
    final msg = it['message']?.toString().trim();

    // "Enviado por … | fecha"
    String byline;
    if (widget.sent) {
      final first = recipients.isNotEmpty ? (recipients.first['name'] ?? recipients.first['email']).toString() : '';
      byline = recipients.length <= 1 ? 'Enviado a $first' : 'Enviado a $first y ${recipients.length - 1} más';
    } else {
      byline = 'Enviado por ${it['sender_name'] ?? it['sender_email'] ?? 'alguien'}';
    }
    byline = '$byline  |  ${_fecha(it['created_at']?.toString())}';

    // Línea de contexto (como el nombre del curso): equipo o tipo de envío
    final context0 = (it['team_name'] ?? (review ? 'Solicitud de revisión' : 'Documento compartido')).toString().toUpperCase();

    // Indicador a la derecha: círculo vacío = pendiente / check verde = leído o respondido
    bool done;
    String tip;
    if (widget.sent) {
      final responded = recipients.where((r) => r['status'] == 'approved' || r['status'] == 'rejected').length;
      final read = recipients.where((r) => r['status'] != 'sent').length;
      done = review ? responded == recipients.length : read == recipients.length;
      tip = review ? '$responded de ${recipients.length} respondieron' : '$read de ${recipients.length} lo leyeron';
    } else {
      done = review ? (status == 'approved' || status == 'rejected') : status != 'sent';
      tip = review ? (done ? 'Ya respondiste' : 'Pendiente de tu revisión') : (done ? 'Leído' : 'Sin leer');
    }
    final rejected = status == 'rejected';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          decoration: BoxDecoration(
            color: widget.selected ? BSColors.selected : (_hover ? BSColors.page : Colors.white),
            border: Border(left: BorderSide(color: widget.selected ? AppTheme.primary : (unread ? AppTheme.primary.withOpacity(0.5) : Colors.transparent), width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              widget.sent
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, size: 20, color: AppTheme.primary),
                    )
                  : BSAvatar(name: (it['sender_name'] ?? it['sender_email'])?.toString(), radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (review)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 1),
                        child: Icon(Icons.fact_check_outlined, size: 17, color: done ? AppTheme.hint : BSColors.warning),
                      ),
                    Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.text, fontSize: 14.5, height: 1.3, fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(byline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(context0,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: it['team_name'] != null ? (parseHexColor(it['team_color']?.toString()) ?? AppTheme.hint) : AppTheme.hint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      )),
                ]),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: tip,
                child: done
                    ? Icon(rejected ? Icons.close_rounded : Icons.check_rounded, color: rejected ? BSColors.danger : BSColors.success, size: 26)
                    : Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: unread ? AppTheme.primary : AppTheme.hint, width: 1.6)),
                      ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              (msg != null && msg.isNotEmpty) ? msg : '${it['doc_title'] ?? 'Documento'} · ${review ? 'te piden revisarlo y aprobarlo o rechazarlo' : 'compartido para tu conocimiento'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.text, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text('Más información',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  decoration: _hover ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: AppTheme.primary,
                )),
          ]),
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String name;
  final String? color;
  const _TeamChip({required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    final c = parseHexColor(color) ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_rounded, size: 13, color: c),
        const SizedBox(width: 4),
        Text(name, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _EmptyList extends StatelessWidget {
  final _Box box;
  const _EmptyList({required this.box});

  @override
  Widget build(BuildContext context) {
    final (title, text) = switch (box) {
      _Box.received => ('Tu bandeja está vacía', 'Cuando alguien te comparta un documento por DocBlockSign, aparecerá aquí.'),
      _Box.sent => ('Aún no has enviado documentos', 'Desde Documentos, usa “Enviar” para compartir con personas o equipos.'),
      _Box.archived => ('Nada archivado', 'Los mensajes que archives quedan guardados aquí.'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(box.icon, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, height: 1.4)),
        ]),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) => _Panel(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.07), shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_unread_outlined, color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 14),
            const Text('Selecciona un mensaje', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Verás el documento, el mensaje y podrás aprobarlo o rechazarlo.',
                style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────
// DETALLE
// ─────────────────────────────────────────
class _InboxDetail extends StatefulWidget {
  final String id;
  final VoidCallback onChanged;
  final VoidCallback onClose;
  const _InboxDetail({super.key, required this.id, required this.onChanged, required this.onClose});

  @override
  State<_InboxDetail> createState() => _InboxDetailState();
}

class _InboxDetailState extends State<_InboxDetail> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _sending = false;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.inboxItem(widget.id);
    if (!mounted) return;
    setState(() {
      if (r['error'] != null) {
        _error = r['error'].toString();
      } else {
        _data = r;
        _error = null;
      }
    });
  }

  Future<void> _respond(bool approve) async {
    final comment = _comment.text.trim();
    if (!approve && comment.isEmpty) {
      await SweetAlert.warning(context, title: 'Falta el motivo', text: 'Escribe por qué rechazas el documento; se lo enviaremos a quien te lo pidió.');
      return;
    }
    if (!approve) {
      final ok = await SweetAlert.confirm(context, title: '¿Rechazar el documento?', text: 'Quien lo envió recibirá tu comentario por correo.', confirmText: 'Sí, rechazar', danger: true);
      if (!ok) return;
    }
    setState(() => _sending = true);
    final r = await CollabService.respond(widget.id, approve: approve, comment: comment.isEmpty ? null : comment);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo responder', text: r['error'].toString());
      return;
    }
    SweetAlert.success(context, title: approve ? 'Documento aprobado' : 'Documento rechazado', text: 'Le avisamos por correo a quien lo envió.', autoClose: const Duration(milliseconds: 1800));
    await _load();
    widget.onChanged();
  }

  Future<void> _archive(bool archived) async {
    final r = await CollabService.archive(widget.id, archived: archived);
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo archivar', text: r['error'].toString());
      return;
    }
    SweetAlert.success(context, title: r['message']?.toString() ?? 'Listo', autoClose: const Duration(milliseconds: 1100));
    widget.onChanged();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: BSInfoBanner(title: 'No se pudo abrir', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded),
      );
    }
    if (_data == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));

    final role = _data!['role']?.toString();
    final isSender = role == 'sender';
    final share = Map<String, dynamic>.from((_data!['share'] as Map?) ?? {});
    final doc = Map<String, dynamic>.from((_data!['document'] as Map?) ?? {});
    final review = share['kind'] == 'review';
    final archived = isSender ? share['archived_by_sender'] == true : share['archived_by_recipient'] == true;
    final subject = share['subject']?.toString().trim();
    final title = (subject != null && subject.isNotEmpty)
        ? subject
        : (review ? 'Solicitud de revisión: ${doc['title'] ?? 'documento'}' : '${doc['title'] ?? 'Documento'}');
    final narrow = MediaQuery.of(context).size.width < 600;
    final pad = narrow ? 16.0 : 24.0;

    return ListView(padding: EdgeInsets.fromLTRB(pad, pad, pad, 28), children: [
      // Encabezado
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              BSPill(label: review ? 'Para revisión y aprobación' : 'Para conocimiento', color: review ? AppTheme.featureCyan : BSColors.neutral, dot: false),
              if (share['team_name'] != null) _TeamChip(name: share['team_name'].toString()),
            ]),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: AppTheme.text, fontSize: narrow ? 18 : 21, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          ]),
        ),
        Tooltip(
          message: archived ? 'Mover a la bandeja' : 'Archivar',
          child: IconButton(
            onPressed: () => _archive(!archived),
            icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined, color: AppTheme.hint),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      // De / para
      Row(children: [
        BSAvatar(name: isSender ? 'Yo' : (share['sender_name'] ?? share['sender_email'])?.toString(), radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSender ? 'Enviado por ti' : (share['sender_name'] ?? 'Remitente').toString(),
                style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(isSender ? 'a ${(_data!['recipients'] as List?)?.length ?? 1} destinatario(s)' : (share['sender_email'] ?? '').toString(),
                style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
          ]),
        ),
        Text(chainDate(share['created_at']?.toString()), style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
      ]),
      if ((share['message']?.toString().trim() ?? '').isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Text(share['message'].toString(), style: const TextStyle(color: AppTheme.text, fontSize: 14, height: 1.55)),
        ),
      ],
      const SizedBox(height: 18),
      _DocumentCard(doc: doc),
      const SizedBox(height: 18),
      if (!isSender && review) _reviewBox(share),
      if (isSender) _recipients(),
    ]);
  }

  Widget _reviewBox(Map<String, dynamic> share) {
    final status = share['status']?.toString();
    if (status == 'approved' || status == 'rejected') {
      final ok = status == 'approved';
      return BSInfoBanner(
        title: ok ? 'Aprobaste este documento' : 'Rechazaste este documento',
        text: [
          if (share['responded_at'] != null) chainDate(share['responded_at'].toString()),
          if ((share['response']?.toString() ?? '').isNotEmpty) '“${share['response']}”',
        ].join(' · '),
        color: ok ? BSColors.success : BSColors.danger,
        icon: ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      );
    }
    return BSCard(
      title: '¿Apruebas este documento?',
      borderColor: BSColors.warning.withOpacity(0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Revísalo y deja tu respuesta. Quien lo envió recibirá un aviso por correo.',
            style: TextStyle(color: AppTheme.hint, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          style: const TextStyle(color: AppTheme.text, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Comentario (obligatorio si rechazas)',
            hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
          BSOutlineButton(label: 'Rechazar', icon: Icons.close_rounded, color: BSColors.danger, onPressed: _sending ? null : () => _respond(false)),
          BSPrimaryButton(label: 'Aprobar', icon: Icons.check_rounded, color: BSColors.success, loading: _sending, onPressed: () => _respond(true)),
        ]),
      ]),
    );
  }

  Widget _recipients() {
    final list = ((_data!['recipients'] as List?) ?? const []).whereType<Map>().toList();
    return BSCard(
      title: 'Destinatarios',
      trailing: Text('${list.length}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: Column(children: [
        for (final r in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BSAvatar(name: (r['name'] ?? r['email'])?.toString(), radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((r['name'] ?? r['email']).toString(), style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text([r['email'], if (r['team'] != null) 'equipo ${r['team']}', if (r['name'] == null) 'sin cuenta en DocBlockSign'].join(' · '),
                      style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                  if ((r['response']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('“${r['response']}”', style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontStyle: FontStyle.italic)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              Builder(builder: (_) {
                final st = shareStatus(r['status']?.toString(), sent: true);
                return BSPill(label: st.$1, color: st.$2);
              }),
            ]),
          ),
      ]),
    );
  }
}

/// Tarjeta del documento compartido: datos, huella y accesos
class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final pdf = (doc['extension'] ?? 'pdf').toString().toLowerCase() == 'pdf';
    final tint = pdf ? BSColors.danger : AppTheme.primary;
    final signed = ['signed', 'verified'].contains(doc['status']);
    final hash = doc['file_hash']?.toString() ?? '';
    final info = [
      doc['category'],
      if (doc['size_mb'] != null) '${doc['size_mb']} MB',
      if (doc['pages'] != null) '${doc['pages']} pág.',
      if (doc['owner_name'] != null) 'de ${doc['owner_name']}',
    ].whereType<Object>().join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: tint.withOpacity(0.09), borderRadius: BorderRadius.circular(10)),
            child: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['title']?.toString() ?? 'Documento', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(info, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          BSPill(label: signed ? 'Firmado' : 'Sin firmar', color: signed ? BSColors.success : BSColors.warning),
        ]),
        if ((doc['description']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(doc['description'].toString(), style: const TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.45)),
        ],
        const SizedBox(height: 12),
        if (hash.isNotEmpty) ChainValueRow(label: 'Huella', value: hash),
        if (signed && doc['blockchain_tx'] != null)
          ChainValueRow(label: 'Tx', value: doc['blockchain_tx'].toString(), url: doc['blockchain_explorer']?.toString()),
        if (signed && doc['blockchain_block'] != null)
          ChainValueRow(label: 'Bloque', value: '#${doc['blockchain_block']}', mono: false, copy: false, shorten: false),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (doc['file_url'] != null)
            BSPrimaryButton(label: 'Ver documento', icon: Icons.visibility_outlined, onPressed: () => openExternal(doc['file_url'].toString())),
          if (hash.isNotEmpty)
            BSOutlineButton(
              label: 'Verificar autenticidad',
              icon: Icons.verified_outlined,
              onPressed: () => Navigator.of(context).pushNamed('/verify?hash=$hash'),
            ),
          if (hash.isNotEmpty)
            BSOutlineButton(
              label: 'Copiar huella',
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: hash));
                if (context.mounted) SweetAlert.success(context, title: 'Huella copiada', autoClose: const Duration(milliseconds: 1000));
              },
            ),
        ]),
      ]),
    );
  }
}
