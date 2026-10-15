import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/proof_ui.dart';
import '../widgets/chain_steps.dart';
import '../widgets/sweet_alert.dart';
import 'document_viewer_screen.dart';
import 'verify_screen.dart';
import '../services/document_service.dart';
import '../widgets/send_document_dialog.dart';

/// Bandeja de entrada al estilo de un cliente de correo: carpetas, mensajes
/// agrupados por fecha, panel de lectura y acciones (responder, reenviar,
/// archivar, eliminar, leído/no leído y marcar para seguimiento).
class InboxScreen extends StatefulWidget {
  /// Se llama cuando cambia el número de no leídos (para el contador del menú)
  final VoidCallback? onChanged;
  const InboxScreen({super.key, this.onChanged});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

enum _Folder { received, flagged, sent, archived, deleted }

extension on _Folder {
  String get api => name;
  String get label => switch (this) {
        _Folder.received => 'Bandeja de entrada',
        _Folder.flagged => 'Marcados',
        _Folder.sent => 'Enviados',
        _Folder.archived => 'Archivo',
        _Folder.deleted => 'Eliminados',
      };
  String get short => switch (this) {
        _Folder.received => 'Entrada',
        _Folder.flagged => 'Marcados',
        _Folder.sent => 'Enviados',
        _Folder.archived => 'Archivo',
        _Folder.deleted => 'Eliminados',
      };
  IconData get icon => switch (this) {
        _Folder.received => Icons.inbox_outlined,
        _Folder.flagged => Icons.flag_outlined,
        _Folder.sent => Icons.send_outlined,
        _Folder.archived => Icons.archive_outlined,
        _Folder.deleted => Icons.delete_outline_rounded,
      };
}

class _InboxScreenState extends State<InboxScreen> {
  _Folder _folder = _Folder.received;
  int _focus = 0; // 0 = Prioritarios, 1 = Otros (solo en la bandeja de entrada)
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;
  Map<String, dynamic> _summary = {};
  final _searchCtrl = TextEditingController();
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isSent => _folder == _Folder.sent;

  /// Prioritarios: solicitudes de revisión, marcados y mensajes de tus equipos
  static bool _isPriority(Map<String, dynamic> it) =>
      it['kind'] == 'review' || it['flagged'] == true || it['team_name'] != null;

  List<Map<String, dynamic>> get _visible {
    var list = _items;
    if (_folder == _Folder.received) list = list.where((it) => _isPriority(it) == (_focus == 0)).toList();
    if (_onlyUnread && !_isSent) list = list.where((it) => it['status'] == 'sent').toList();
    return list;
  }

  int get _otherUnread => _folder == _Folder.received
      ? _items.where((it) => _isPriority(it) != (_focus == 0) && it['status'] == 'sent').length
      : 0;

  Future<void> _load({bool keepSelection = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!keepSelection) _selectedId = null;
    });
    final results = await Future.wait([
      CollabService.inbox(box: _folder.api, q: _searchCtrl.text.trim()),
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

  /// Nuevo envío: elegir un documento y abrir la ventana de envío
  Future<void> _compose() async {
    final doc = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _PickDocumentDialog());
    if (doc == null || !mounted) return;
    final sent = await showSendDocumentDialog(context, doc);
    if (!sent || !mounted) return;
    setState(() {
      _folder = _Folder.sent;
      _focus = 0;
    });
    _load();
  }

  Future<void> _refreshSummary() async {
    final s = await CollabService.inboxSummary();
    if (mounted && s['error'] == null) setState(() => _summary = s);
    widget.onChanged?.call();
  }

  void _setFolder(_Folder f) {
    if (f == _folder) return;
    setState(() {
      _folder = f;
      _focus = 0;
    });
    _load();
  }

  void _open(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) return;
    final wide = MediaQuery.of(context).size.width >= 900;
    if (!_isSent && item['status'] == 'sent') setState(() => item['status'] = 'read');
    if (wide) {
      setState(() => _selectedId = id);
      Future.delayed(const Duration(milliseconds: 600), () => mounted ? _refreshSummary() : null);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => _MessagePage(id: id, folder: _folder, onChanged: () => _load(keepSelection: true)),
          ))
          .then((_) => _load(keepSelection: true));
    }
  }

  /// Acciones rápidas desde la lista (sin abrir el mensaje)
  Future<void> _quick(Map<String, dynamic> it, String action) async {
    final id = it['id'].toString();
    Map<String, dynamic> r;
    switch (action) {
      case 'flag':
        final v = it['flagged'] != true;
        setState(() => it['flagged'] = v);
        r = await CollabService.flag(id, flagged: v);
        break;
      case 'read':
        final read = it['status'] == 'sent';
        setState(() => it['status'] = read ? 'read' : 'sent');
        r = await CollabService.markRead(id, read: read);
        break;
      case 'archive':
        r = await CollabService.archive(id, archived: _folder != _Folder.archived);
        break;
      case 'delete':
        r = await CollabService.deleteMessage(id, deleted: _folder != _Folder.deleted);
        break;
      default:
        return;
    }
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo completar', text: r['error'].toString());
    }
    if (action == 'archive' || action == 'delete') {
      if (_selectedId == id) _selectedId = null;
      await _load(keepSelection: true);
    } else {
      _refreshSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 24.0 : 12.0;
    final showRail = w >= 1250;
    final twoPanes = w >= 900;
    final unread = int.tryParse('${_summary['unread'] ?? 0}') ?? 0;
    final pending = int.tryParse('${_summary['pending_reviews'] ?? 0}') ?? 0;
    final flagged = int.tryParse('${_summary['flagged'] ?? 0}') ?? 0;

    final list = _ListPane(
      folder: _folder,
      focus: _focus,
      onFocus: (v) => setState(() => _focus = v),
      otherUnread: _otherUnread,
      items: _visible,
      loading: _loading,
      error: _error,
      selectedId: _selectedId,
      searchCtrl: _searchCtrl,
      onSearch: () => _load(),
      onlyUnread: _onlyUnread,
      onOnlyUnread: (v) => setState(() => _onlyUnread = v),
      onOpen: _open,
      onQuick: _quick,
      onRefresh: () => _load(keepSelection: true),
      showFolderChips: !showRail,
      unread: unread,
      flagged: flagged,
      onFolder: _setFolder,
      onCompose: w > 600 ? null : _compose,
    );

    return Container(
      color: BSColors.page,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, w > 600 ? 20 : 12, pad, twoPanes ? 20 : 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (w > 600) ...[
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Bandeja'],
              title: 'Bandeja de entrada',
              subtitle: 'Documentos que te compartieron y los que enviaste, con sus revisiones y respuestas.',
              badges: [
                if (unread > 0) BSPill(label: '$unread sin leer', color: AppTheme.primary),
                if (pending > 0) BSPill(label: '$pending por revisar', color: BSColors.warning),
              ],
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: _loading ? null : () => _load(keepSelection: true)),
                BSPrimaryButton(label: 'Nuevo envío', icon: Icons.edit_square, onPressed: _compose),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: twoPanes
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (showRail) ...[
                      SizedBox(
                        width: 220,
                        child: _FolderRail(folder: _folder, unread: unread, flagged: flagged, pending: pending, onFolder: _setFolder),
                      ),
                      const SizedBox(width: 14),
                    ],
                    SizedBox(width: w > 1450 ? 430 : 380, child: list),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _selectedId == null
                          ? const _EmptyReading()
                          : _Panel(
                              child: _Reading(
                                key: ValueKey(_selectedId),
                                id: _selectedId!,
                                folder: _folder,
                                onChanged: () => _load(keepSelection: true),
                                onClosed: () {
                                  setState(() => _selectedId = null);
                                  _load();
                                },
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

/// Contenedor blanco con borde
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
// CARPETAS
// ─────────────────────────────────────────
class _FolderRail extends StatelessWidget {
  final _Folder folder;
  final int unread, flagged, pending;
  final ValueChanged<_Folder> onFolder;
  const _FolderRail({required this.folder, required this.unread, required this.flagged, required this.pending, required this.onFolder});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListView(padding: const EdgeInsets.fromLTRB(10, 14, 10, 14), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text('CARPETAS', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ),
        for (final f in _Folder.values)
          _FolderTile(
            folder: f,
            selected: f == folder,
            count: switch (f) { _Folder.received => unread, _Folder.flagged => flagged, _ => 0 },
            onTap: () => onFolder(f),
          ),
        if (pending > 0) ...[
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BSColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BSColors.warning.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.fact_check_outlined, color: BSColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$pending ${pending == 1 ? 'documento espera' : 'documentos esperan'} tu revisión',
                    style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _FolderTile extends StatefulWidget {
  final _Folder folder;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _FolderTile({required this.folder, required this.selected, required this.count, required this.onTap});

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? BSColors.selected : (_hover ? BSColors.page : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(widget.folder.icon, size: 19, color: sel ? AppTheme.primary : AppTheme.hint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.folder.label,
                  style: TextStyle(
                    color: sel ? AppTheme.primary : AppTheme.text,
                    fontSize: 13.5,
                    fontWeight: sel || widget.count > 0 ? FontWeight.w800 : FontWeight.w500,
                  )),
            ),
            if (widget.count > 0)
              Text('${widget.count}', style: const TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// LISTA DE MENSAJES
// ─────────────────────────────────────────
class _ListPane extends StatelessWidget {
  final _Folder folder;
  final int focus;
  final ValueChanged<int> onFocus;
  final int otherUnread;
  final List<Map<String, dynamic>> items;
  final bool loading;
  final String? error;
  final String? selectedId;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final bool onlyUnread;
  final ValueChanged<bool> onOnlyUnread;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Future<void> Function(Map<String, dynamic>, String) onQuick;
  final Future<void> Function() onRefresh;
  final bool showFolderChips;
  final int unread, flagged;
  final ValueChanged<_Folder> onFolder;
  final VoidCallback? onCompose;

  const _ListPane({
    required this.folder,
    required this.focus,
    required this.onFocus,
    required this.otherUnread,
    required this.items,
    required this.loading,
    required this.error,
    required this.selectedId,
    required this.searchCtrl,
    required this.onSearch,
    required this.onlyUnread,
    required this.onOnlyUnread,
    required this.onOpen,
    required this.onQuick,
    required this.onRefresh,
    required this.showFolderChips,
    required this.unread,
    required this.flagged,
    required this.onFolder,
    this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    final sent = folder == _Folder.sent;
    Widget body;
    if (loading && items.isEmpty) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    } else if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: BSInfoBanner(title: 'No se pudo cargar la bandeja', text: error, color: BSColors.danger, icon: Icons.error_outline_rounded),
      );
    } else if (items.isEmpty) {
      body = _EmptyList(folder: folder, focus: focus);
    } else {
      // Agrupado por fecha, como en el correo
      final rows = <Widget>[];
      String? last;
      for (var i = 0; i < items.length; i++) {
        final g = _group(items[i]['created_at']?.toString());
        if (g != last) {
          rows.add(_GroupHeader(g));
          last = g;
        }
        rows.add(_MessageRow(
          item: items[i],
          sent: sent,
          folder: folder,
          selected: items[i]['id']?.toString() == selectedId,
          onTap: () => onOpen(items[i]),
          onQuick: (a) => onQuick(items[i], a),
        ));
      }
      body = RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: rows),
      );
    }

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showFolderChips)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              children: [
                for (final f in _Folder.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FolderChip(
                      folder: f,
                      selected: f == folder,
                      count: f == _Folder.received ? unread : (f == _Folder.flagged ? flagged : 0),
                      onTap: () => onFolder(f),
                    ),
                  ),
              ],
            ),
          ),
        // Buscador (y en celular, botón de nuevo envío)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
           Expanded(child: SizedBox(
            height: 40,
            child: TextField(
              controller: searchCtrl,
              onSubmitted: (_) => onSearch(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar en ${folder.label.toLowerCase()}',
                hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
                filled: true,
                fillColor: BSColors.page,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
            ),
           )),
           if (onCompose != null) ...[
             const SizedBox(width: 8),
             SizedBox(
               height: 40,
               child: ElevatedButton.icon(
                 onPressed: onCompose,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppTheme.primary,
                   foregroundColor: Colors.white,
                   elevation: 0,
                   padding: const EdgeInsets.symmetric(horizontal: 12),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                 ),
                 icon: const Icon(Icons.edit_square, size: 17),
                 label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.w800)),
               ),
             ),
           ],
          ]),
        ),
        // Prioritarios / Otros + filtro
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 6, 0),
          child: Row(children: [
            if (folder == _Folder.received) ...[
              _FocusTab(label: 'Prioritarios', selected: focus == 0, onTap: () => onFocus(0)),
              const SizedBox(width: 14),
              _FocusTab(label: 'Otros', selected: focus == 1, onTap: () => onFocus(1), badge: focus == 0 ? otherUnread : 0),
            ] else
              Text(folder.label, style: const TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (!sent)
              Tooltip(
                message: onlyUnread ? 'Mostrar todos' : 'Solo no leídos',
                child: IconButton(
                  onPressed: () => onOnlyUnread(!onlyUnread),
                  icon: Icon(onlyUnread ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                      color: onlyUnread ? AppTheme.primary : AppTheme.hint, size: 20),
                ),
              ),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(child: body),
      ]),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final _Folder folder;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _FolderChip({required this.folder, required this.selected, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(folder.icon, size: 16, color: selected ? Colors.white : AppTheme.hint),
          const SizedBox(width: 6),
          Text(folder.short,
              style: TextStyle(color: selected ? Colors.white : AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(color: selected ? Colors.white : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ]),
      ),
    );
  }
}

class _FocusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;
  const _FocusTab({required this.label, required this.selected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppTheme.primary : Colors.transparent, width: 2.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.hint,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              )),
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
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        color: Colors.white,
        child: Row(children: [
          const Icon(Icons.expand_more_rounded, size: 18, color: AppTheme.hint),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// "Hoy", "Ayer", "Esta semana", "La semana pasada", "Este mes" o el mes
String _group(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return 'Anteriores';
  final today = _day(DateTime.now());
  final d = today.difference(_day(t)).inDays;
  if (d <= 0) return 'Hoy';
  if (d == 1) return 'Ayer';
  final startWeek = today.subtract(Duration(days: today.weekday - 1));
  if (!t.isBefore(startWeek)) return 'Esta semana';
  if (!t.isBefore(startWeek.subtract(const Duration(days: 7)))) return 'La semana pasada';
  if (t.year == today.year && t.month == today.month) return 'Este mes';
  const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  return t.year == today.year ? meses[t.month - 1] : '${meses[t.month - 1]} ${t.year}';
}

/// Hora si es de hoy, día de la semana si es de esta semana, fecha si es anterior
String _when(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final today = _day(DateTime.now());
  final d = today.difference(_day(t)).inDays;
  if (d <= 0) return bsHora(t);
  if (d < 7) return '${_dias[t.weekday - 1]} ${bsHora(t)}';
  if (t.year == today.year) return '${t.day} ${_meses[t.month - 1]}';
  return '${t.day}/${t.month}/${t.year}';
}

/// Fecha completa para el encabezado del mensaje: "mar 13/10/2026 3:26 p. m."
String _fullDate(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_dias[t.weekday - 1]} ${two(t.day)}/${two(t.month)}/${t.year} ${bsHora(t)}';
}

const _avatarColors = [
  Color(0xFF0B45B5), Color(0xFF2E7D32), Color(0xFF8E24AA), Color(0xFFD84315),
  Color(0xFF00838F), Color(0xFF6D4C41), Color(0xFFC2185B), Color(0xFF5E35B1),
];

Color _avatarColor(String? name) {
  final s = (name ?? '').trim().toLowerCase();
  if (s.isEmpty) return _avatarColors.first;
  return _avatarColors[s.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) % _avatarColors.length];
}

class _Avatar extends StatelessWidget {
  final String? name;
  final double size;
  final IconData? icon;
  const _Avatar({this.name, this.size = 40, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = icon != null ? AppTheme.primary : _avatarColor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(0.14), shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, size: size * 0.45, color: c)
          : Text(bsIniciales(name), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

(String, Color) _reviewState(String? status) => switch (status) {
      'approved' => ('Aprobado', BSColors.success),
      'rejected' => ('Rechazado', BSColors.danger),
      _ => ('Por revisar', BSColors.warning),
    };

class _MessageRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool sent, selected;
  final _Folder folder;
  final VoidCallback onTap;
  final ValueChanged<String> onQuick;
  const _MessageRow({
    required this.item,
    required this.sent,
    required this.folder,
    required this.selected,
    required this.onTap,
    required this.onQuick,
  });

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final review = it['kind'] == 'review';
    final status = it['status']?.toString();
    final unread = !widget.sent && status == 'sent';
    final flagged = it['flagged'] == true;
    final recipients = ((it['recipients'] as List?) ?? const []).whereType<Map>().toList();
    final who = widget.sent
        ? (recipients.isEmpty
            ? 'Destinatarios'
            : '${(recipients.first['name'] ?? recipients.first['email'])}${recipients.length > 1 ? ' +${recipients.length - 1}' : ''}')
        : (it['sender_name'] ?? it['sender_email'] ?? 'Remitente').toString();
    final subject = (it['subject']?.toString().trim().isNotEmpty == true ? it['subject'] : it['doc_title'])?.toString() ?? 'Documento';
    final msg = it['message']?.toString().trim();
    final preview = (msg != null && msg.isNotEmpty)
        ? msg
        : '${it['doc_title'] ?? 'Documento'} · ${review ? 'te piden revisarlo y aprobarlo' : 'compartido para tu conocimiento'}';
    final desktop = MediaQuery.of(context).size.width >= 900;
    final showActions = desktop && _hover && !widget.sent;

    final reviewPill = review
        ? Builder(builder: (_) {
            if (widget.sent) {
              final done = recipients.where((r) => r['status'] == 'approved' || r['status'] == 'rejected').length;
              return _MiniPill(text: '$done/${recipients.length} respondieron', color: done == recipients.length ? BSColors.success : BSColors.warning);
            }
            final st = _reviewState(status);
            return _MiniPill(text: st.$1, color: st.$2);
          })
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: desktop || widget.sent ? null : () => _menu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
          decoration: BoxDecoration(
            color: widget.selected ? BSColors.selected : (flagged ? const Color(0xFFFFF8E1) : (_hover ? BSColors.page : Colors.white)),
            border: Border(
              left: BorderSide(color: widget.selected || unread ? AppTheme.primary : Colors.transparent, width: 3),
              bottom: const BorderSide(color: Color(0xFFEDF0F5)),
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Avatar(name: widget.sent ? null : who, icon: widget.sent ? Icons.send_rounded : null, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(widget.sent ? 'Para: $who' : who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  if (showActions) ...[
                    _RowAction(icon: flagged ? Icons.flag_rounded : Icons.flag_outlined, tip: flagged ? 'Quitar marca' : 'Marcar', color: flagged ? BSColors.danger : null, onTap: () => widget.onQuick('flag')),
                    _RowAction(icon: unread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, tip: unread ? 'Marcar como leído' : 'Marcar como no leído', onTap: () => widget.onQuick('read')),
                    _RowAction(icon: widget.folder == _Folder.archived ? Icons.unarchive_outlined : Icons.archive_outlined, tip: widget.folder == _Folder.archived ? 'Mover a la bandeja' : 'Archivar', onTap: () => widget.onQuick('archive')),
                    _RowAction(icon: widget.folder == _Folder.deleted ? Icons.restore_from_trash_outlined : Icons.delete_outline_rounded, tip: widget.folder == _Folder.deleted ? 'Restaurar' : 'Eliminar', onTap: () => widget.onQuick('delete')),
                  ] else ...[
                    if (flagged) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.flag_rounded, size: 15, color: BSColors.danger)),
                    Text(_when(it['created_at']?.toString()),
                        style: TextStyle(color: unread ? AppTheme.primary : AppTheme.hint, fontSize: 12, fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (review)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.fact_check_outlined, size: 15, color: unread ? AppTheme.primary : AppTheme.hint),
                    ),
                  Expanded(
                    child: Text(subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: unread ? AppTheme.primary : AppTheme.text, fontSize: 13.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (it['attached'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.attach_file_rounded, size: 15, color: AppTheme.hint)),
                ]),
                const SizedBox(height: 3),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
                if (reviewPill != null || it['team_name'] != null) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (reviewPill != null) reviewPill,
                    if (it['team_name'] != null)
                      _MiniPill(text: it['team_name'].toString(), color: parseHexColor(it['team_color']?.toString()) ?? AppTheme.primary, icon: Icons.groups_rounded),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final it = widget.item;
    final unread = it['status'] == 'sent';
    final flagged = it['flagged'] == true;
    final a = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: Icon(flagged ? Icons.outlined_flag_rounded : Icons.flag_rounded), title: Text(flagged ? 'Quitar marca' : 'Marcar para seguimiento'), onTap: () => Navigator.pop(ctx, 'flag')),
          ListTile(leading: Icon(unread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined), title: Text(unread ? 'Marcar como leído' : 'Marcar como no leído'), onTap: () => Navigator.pop(ctx, 'read')),
          ListTile(leading: const Icon(Icons.archive_outlined), title: Text(widget.folder == _Folder.archived ? 'Mover a la bandeja' : 'Archivar'), onTap: () => Navigator.pop(ctx, 'archive')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: BSColors.danger), title: Text(widget.folder == _Folder.deleted ? 'Restaurar' : 'Eliminar'), onTap: () => Navigator.pop(ctx, 'delete')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (a != null) widget.onQuick(a);
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tip;
  final Color? color;
  final VoidCallback onTap;
  const _RowAction({required this.icon, required this.tip, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(3), child: Icon(icon, size: 17, color: color ?? AppTheme.hint)),
        ),
      );
}

class _MiniPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _MiniPill({required this.text, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _EmptyList extends StatelessWidget {
  final _Folder folder;
  final int focus;
  const _EmptyList({required this.folder, required this.focus});

  @override
  Widget build(BuildContext context) {
    final (title, text) = switch (folder) {
      _Folder.received => focus == 0
          ? ('Nada prioritario', 'Aquí llegan las solicitudes de revisión, los mensajes de tus equipos y lo que marques.')
          : ('No hay otros mensajes', 'Los documentos que te compartan solo para conocimiento aparecen aquí.'),
      _Folder.flagged => ('No hay mensajes marcados', 'Marca un mensaje con la bandera para hacerle seguimiento.'),
      _Folder.sent => ('Aún no has enviado documentos', 'Desde Documentos, usa “Enviar” para compartir con personas o equipos.'),
      _Folder.archived => ('Nada archivado', 'Los mensajes que archives quedan guardados aquí.'),
      _Folder.deleted => ('No hay mensajes eliminados', 'Lo que elimines queda aquí y lo puedes restaurar.'),
    };
    return ListView(children: [
      const SizedBox(height: 60),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(folder.icon, color: AppTheme.primary, size: 28),
        ),
      ),
      const SizedBox(height: 14),
      Center(child: Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 15))),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, height: 1.4)),
      ),
    ]);
  }
}

class _EmptyReading extends StatelessWidget {
  const _EmptyReading();
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
            const Text('Selecciona un mensaje para leerlo', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Desde aquí puedes responder, reenviar, aprobar o rechazar.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────
// LECTURA DEL MENSAJE (celular: pantalla aparte)
// ─────────────────────────────────────────
class _MessagePage extends StatelessWidget {
  final String id;
  final _Folder folder;
  final VoidCallback onChanged;
  const _MessagePage({required this.id, required this.folder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _Reading(id: id, folder: folder, onChanged: onChanged, onClosed: () => Navigator.of(context).pop(), standalone: true),
      ),
    );
  }
}

class _Reading extends StatefulWidget {
  final String id;
  final _Folder folder;
  final VoidCallback onChanged;
  final VoidCallback onClosed;
  final bool standalone;
  const _Reading({super.key, required this.id, required this.folder, required this.onChanged, required this.onClosed, this.standalone = false});

  @override
  State<_Reading> createState() => _ReadingState();
}

class _ReadingState extends State<_Reading> {
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

  Map<String, dynamic> get _share => Map<String, dynamic>.from((_data?['share'] as Map?) ?? {});
  bool get _isSender => _data?['role'] == 'sender';

  Future<void> _done(Map<String, dynamic> r, String ok, {bool close = false}) async {
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo completar', text: r['error'].toString());
      return;
    }
    SweetAlert.success(context, title: ok, autoClose: const Duration(milliseconds: 1200));
    widget.onChanged();
    if (close) {
      widget.onClosed();
    } else {
      await _load();
    }
  }

  Future<void> _archive() async {
    final archived = _isSender ? _share['archived_by_sender'] == true : _share['archived_by_recipient'] == true;
    final r = await CollabService.archive(widget.id, archived: !archived);
    await _done(r, archived ? 'Movido a la bandeja' : 'Archivado', close: true);
  }

  Future<void> _delete() async {
    final deleted = _isSender ? _share['deleted_by_sender'] == true : _share['deleted_by_recipient'] == true;
    final r = await CollabService.deleteMessage(widget.id, deleted: !deleted);
    await _done(r, deleted ? 'Restaurado' : 'Movido a Eliminados', close: true);
  }

  Future<void> _toggleRead() async {
    final unread = _share['status'] == 'sent';
    final r = await CollabService.markRead(widget.id, read: unread);
    await _done(r, unread ? 'Marcado como leído' : 'Marcado como no leído', close: !unread && widget.standalone);
  }

  Future<void> _toggleFlag() async {
    final r = await CollabService.flag(widget.id, flagged: _share['flagged'] != true);
    await _done(r, _share['flagged'] == true ? 'Marca quitada' : 'Marcado para seguimiento');
  }

  Future<void> _reply() async {
    final to = _isSender ? 'todos los destinatarios' : (_share['sender_name'] ?? _share['sender_email'] ?? 'quien lo envió').toString();
    final text = await showDialog<String>(context: context, builder: (_) => _ComposeDialog(title: 'Responder', to: to, forward: false));
    if (text == null) return;
    setState(() => _sending = true);
    final r = await CollabService.reply(widget.id, text);
    if (mounted) setState(() => _sending = false);
    await _done(r, 'Respuesta enviada');
  }

  Future<void> _forward() async {
    final res = await showDialog<String>(context: context, builder: (_) => const _ComposeDialog(title: 'Reenviar', forward: true));
    if (res == null) return;
    final parts = res.split('\u0000');
    final emails = parts.first.split(RegExp(r'[,;\s]+')).where((e) => e.trim().isNotEmpty).toList();
    setState(() => _sending = true);
    final r = await CollabService.forward(widget.id, emails, parts.length > 1 ? parts[1] : '');
    if (mounted) setState(() => _sending = false);
    await _done(r, 'Documento reenviado');
  }

  Future<void> _respond(bool approve) async {
    final comment = await showDialog<String>(context: context, builder: (_) => _RespondDialog(approve: approve));
    if (comment == null || !mounted) return;
    setState(() => _sending = true);
    final r = await CollabService.respond(widget.id, approve: approve, comment: comment.isEmpty ? null : comment);
    if (!mounted) return;
    setState(() => _sending = false);
    await _done(r, approve ? 'Documento aprobado' : 'Documento rechazado');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(children: [
        if (widget.standalone) _backBar(context),
        Padding(
          padding: const EdgeInsets.all(20),
          child: BSInfoBanner(title: 'No se pudo abrir', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded),
        ),
      ]);
    }
    if (_data == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));

    final share = _share;
    final doc = Map<String, dynamic>.from((_data!['document'] as Map?) ?? {});
    final review = share['kind'] == 'review';
    final subject = share['subject']?.toString().trim();
    final title = (subject != null && subject.isNotEmpty)
        ? subject
        : (review ? 'Solicitud de revisión: ${doc['title'] ?? 'documento'}' : '${doc['title'] ?? 'Documento'}');
    final narrow = MediaQuery.of(context).size.width < 600;
    final pad = narrow ? 16.0 : 24.0;
    final recipients = ((_data!['recipients'] as List?) ?? const []).whereType<Map>().toList();
    final senderName = _isSender ? 'Tú' : (share['sender_name'] ?? share['sender_email'] ?? 'Remitente').toString();
    final senderEmail = _isSender ? '' : (share['sender_email'] ?? '').toString();
    final toLine = _isSender
        ? recipients.map((r) => (r['name'] ?? r['email']).toString()).join('; ')
        : 'Tú${share['team_name'] != null ? ' · equipo ${share['team_name']}' : ''}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Toolbar(
        standalone: widget.standalone,
        isSender: _isSender,
        busy: _sending,
        unread: share['status'] == 'sent',
        flagged: share['flagged'] == true,
        archived: _isSender ? share['archived_by_sender'] == true : share['archived_by_recipient'] == true,
        deleted: _isSender ? share['deleted_by_sender'] == true : share['deleted_by_recipient'] == true,
        onBack: widget.onClosed,
        onReply: _reply,
        onForward: _forward,
        onArchive: _archive,
        onDelete: _delete,
        onRead: _toggleRead,
        onFlag: _toggleFlag,
      ),
      Expanded(
        child: ListView(padding: EdgeInsets.fromLTRB(pad, 18, pad, 32), children: [
          // Asunto
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(title, style: TextStyle(color: AppTheme.text, fontSize: narrow ? 18 : 21, fontWeight: FontWeight.w800, height: 1.25)),
            ),
            if (share['flagged'] == true) const Padding(padding: EdgeInsets.only(left: 8, top: 4), child: Icon(Icons.flag_rounded, color: BSColors.danger, size: 20)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            BSPill(label: review ? 'Para revisión y aprobación' : 'Para conocimiento', color: review ? AppTheme.featureCyan : BSColors.neutral, dot: false),
            if (share['team_name'] != null)
              _MiniPill(text: 'Equipo ${share['team_name']}', color: AppTheme.primary, icon: Icons.groups_rounded),
          ]),
          const SizedBox(height: 16),
          if (review && !_isSender) ...[_reviewPrompt(share), const SizedBox(height: 16)],
          if (review && _isSender && recipients.isNotEmpty) ...[_reviewProgress(recipients), const SizedBox(height: 16)],
          // De / Para / fecha
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border), bottom: BorderSide(color: AppTheme.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Avatar(name: _isSender ? null : senderName, icon: _isSender ? Icons.send_rounded : null, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.text)),
                    if (senderEmail.isNotEmpty) TextSpan(text: '  <$senderEmail>', style: const TextStyle(color: AppTheme.hint)),
                  ]), style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('Para: $toLine', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
                  if (narrow) ...[
                    const SizedBox(height: 3),
                    Text(_fullDate(share['created_at']?.toString()), style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ],
                ]),
              ),
              if (!narrow) Text(_fullDate(share['created_at']?.toString()), style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
            ]),
          ),
          // Mensaje
          const SizedBox(height: 16),
          SelectableText(
            (share['message']?.toString().trim().isNotEmpty == true)
                ? share['message'].toString()
                : (review
                    ? '$senderName te pide revisar este documento y aprobarlo o rechazarlo.'
                    : '$senderName compartió este documento contigo para tu conocimiento.'),
            style: const TextStyle(color: AppTheme.text, fontSize: 14.5, height: 1.6),
          ),
          const SizedBox(height: 20),
          _DocumentCard(doc: doc),
          const SizedBox(height: 18),
          if (_isSender) _recipients(recipients),
          if (!widget.standalone || narrow) ...[
            const SizedBox(height: 16),
            Builder(builder: (_) {
              final a = BSOutlineButton(label: _isSender ? 'Responder a todos' : 'Responder', icon: Icons.reply_rounded, onPressed: _sending ? null : _reply);
              final b = BSOutlineButton(label: 'Reenviar', icon: Icons.forward_rounded, onPressed: _sending ? null : _forward);
              return narrow
                  ? Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)])
                  : Wrap(spacing: 10, runSpacing: 10, children: [a, b]);
            }),
          ],
        ]),
      ),
    ]);
  }

  Widget _backBar(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: IconButton(onPressed: widget.onClosed, icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text)),
      );

  /// Solicitud de revisión: lo primero que se ve, con las dos respuestas a mano
  Widget _reviewPrompt(Map<String, dynamic> share) {
    final status = share['status']?.toString();
    if (status == 'approved' || status == 'rejected') {
      final ok = status == 'approved';
      return BSInfoBanner(
        title: ok ? 'Aprobaste este documento' : 'Rechazaste este documento',
        text: [
          if (share['responded_at'] != null) fmtFechaHora(share['responded_at'].toString()),
          if ((share['response']?.toString() ?? '').isNotEmpty) '“${share['response']}”',
        ].join(' · '),
        color: ok ? BSColors.success : BSColors.danger,
        icon: ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      );
    }
    final narrow = MediaQuery.of(context).size.width < 600;
    final reject = BSOutlineButton(label: 'Rechazar', icon: Icons.close_rounded, color: BSColors.danger, onPressed: _sending ? null : () => _respond(false));
    final approve = BSPrimaryButton(label: 'Aprobar', icon: Icons.check_rounded, color: BSColors.success, loading: _sending, onPressed: () => _respond(true));
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('Te piden aprobar este documento', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
      SizedBox(height: 2),
      Text('Revísalo con “Ver documento” y responde. Quien lo envió recibe tu respuesta por correo.',
          style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
    ]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BSColors.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BSColors.warning.withOpacity(0.35)),
      ),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              text,
              const SizedBox(height: 12),
              Row(children: [Expanded(child: reject), const SizedBox(width: 10), Expanded(child: approve)]),
            ])
          : Row(children: [
              const Icon(Icons.fact_check_outlined, color: BSColors.warning, size: 26),
              const SizedBox(width: 14),
              Expanded(child: text),
              const SizedBox(width: 12),
              reject,
              const SizedBox(width: 8),
              approve,
            ]),
    );
  }

  /// Para quien envió: avance de las respuestas
  Widget _reviewProgress(List<Map> list) {
    final total = list.length;
    final ok = list.where((r) => r['status'] == 'approved').length;
    final no = list.where((r) => r['status'] == 'rejected').length;
    final pending = total - ok - no;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.fact_check_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pending == 0 ? 'Todos respondieron' : 'Esperando $pending de $total ${total == 1 ? 'respuesta' : 'respuestas'}',
                style: const TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Text('$ok aprobado${ok == 1 ? '' : 's'} · $no rechazado${no == 1 ? '' : 's'}', style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              if (ok > 0) Expanded(flex: ok, child: Container(color: BSColors.success)),
              if (no > 0) Expanded(flex: no, child: Container(color: BSColors.danger)),
              if (pending > 0) Expanded(flex: pending, child: Container(color: AppTheme.border)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _recipients(List<Map> list) {
    return BSCard(
      title: 'Destinatarios',
      trailing: Text('${list.length}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: Column(children: [
        for (final r in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F5)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Avatar(name: (r['name'] ?? r['email'])?.toString(), size: 32),
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
                final st = switch (r['status']) {
                  'approved' => ('Aprobado', BSColors.success),
                  'rejected' => ('Rechazado', BSColors.danger),
                  'read' => ('Leído', BSColors.neutral),
                  _ => ('Enviado', AppTheme.primary),
                };
                return BSPill(label: st.$1, color: st.$2);
              }),
            ]),
          ),
      ]),
    );
  }
}

/// Barra de acciones del mensaje (como la cinta de Outlook)
class _Toolbar extends StatelessWidget {
  final bool standalone, isSender, busy, unread, flagged, archived, deleted;
  final VoidCallback onBack, onReply, onForward, onArchive, onDelete, onRead, onFlag;
  const _Toolbar({
    required this.standalone,
    required this.isSender,
    required this.busy,
    required this.unread,
    required this.flagged,
    required this.archived,
    required this.deleted,
    required this.onBack,
    required this.onReply,
    required this.onForward,
    required this.onArchive,
    required this.onDelete,
    required this.onRead,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) => _bar(context, box.maxWidth));
  }

  Widget _bar(BuildContext context, double width) {
    final narrow = MediaQuery.of(context).size.width < 600;
    final compact = width < 700; // panel angosto: solo íconos en acciones secundarias
    Widget action(IconData icon, String label, VoidCallback? onTap, {Color? color, bool primary = false}) => narrow || (compact && !primary)
        ? IconButton(tooltip: label, onPressed: onTap, icon: Icon(icon, color: color ?? AppTheme.text, size: 22))
        : TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: color ?? AppTheme.text, padding: const EdgeInsets.symmetric(horizontal: 10)),
            icon: Icon(icon, size: 18),
            label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          );
    const sep = SizedBox(height: 22, child: VerticalDivider(width: 14, color: AppTheme.border));

    final deco = const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.border)));
    if (narrow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: deco,
        child: Row(children: [
          if (standalone) IconButton(tooltip: 'Volver', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text)),
          const Spacer(),
          action(archived ? Icons.unarchive_outlined : Icons.archive_outlined, archived ? 'Mover a la bandeja' : 'Archivar', onArchive),
          action(deleted ? Icons.restore_from_trash_outlined : Icons.delete_outline_rounded, deleted ? 'Restaurar' : 'Eliminar', onDelete,
              color: deleted ? null : BSColors.danger),
          if (!isSender) ...[
            action(unread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, unread ? 'Marcar como leído' : 'Marcar como no leído', onRead),
            action(flagged ? Icons.flag_rounded : Icons.flag_outlined, flagged ? 'Quitar marca' : 'Marcar', onFlag, color: flagged ? BSColors.danger : null),
          ],
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: deco,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          if (standalone) IconButton(tooltip: 'Volver', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text)),
          if (!narrow) ...[
            action(Icons.reply_rounded, isSender ? 'Responder a todos' : 'Responder', busy ? null : onReply, color: AppTheme.primary, primary: true),
            action(Icons.forward_rounded, 'Reenviar', busy ? null : onForward, color: AppTheme.primary, primary: true),
            sep,
          ],
          action(archived ? Icons.unarchive_outlined : Icons.archive_outlined, archived ? 'Mover a la bandeja' : 'Archivar', onArchive),
          action(deleted ? Icons.restore_from_trash_outlined : Icons.delete_outline_rounded, deleted ? 'Restaurar' : 'Eliminar', onDelete,
              color: deleted ? null : BSColors.danger),
          if (!isSender) ...[
            if (!narrow) sep,
            action(unread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, unread ? 'Leído' : 'No leído', onRead),
            action(flagged ? Icons.flag_rounded : Icons.flag_outlined, flagged ? 'Quitar marca' : 'Marcar', onFlag, color: flagged ? BSColors.danger : null),
          ],
        ]),
      ),
    );
  }
}

/// Ventana para responder o reenviar
class _ComposeDialog extends StatefulWidget {
  final String title;
  final String? to;
  final bool forward;
  const _ComposeDialog({required this.title, this.to, required this.forward});

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _to = TextEditingController();
  final _msg = TextEditingController();
  String? _err;
  static final _emailRe = RegExp(r'^[^\s@<>()\[\]\\,;:"]+@[^\s@<>()\[\]\\,;:"]+\.[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _to.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.forward) {
      final emails = _to.text.split(RegExp(r'[,;\s]+')).where((e) => e.trim().isNotEmpty).toList();
      if (emails.isEmpty) return setState(() => _err = 'Escribe al menos un correo');
      final bad = emails.where((e) => !_emailRe.hasMatch(e.trim())).toList();
      if (bad.isNotEmpty) return setState(() => _err = 'Correo no válido: ${bad.join(', ')}');
      if (emails.length > 5) return setState(() => _err = 'Máximo 5 correos a la vez');
      Navigator.pop(context, '${emails.join(',')}\u0000${_msg.text.trim()}');
    } else {
      if (_msg.text.trim().isEmpty) return setState(() => _err = 'Escribe tu respuesta');
      Navigator.pop(context, _msg.text.trim());
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(widget.forward ? Icons.forward_rounded : Icons.reply_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.title, style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppTheme.hint)),
            ]),
            const SizedBox(height: 10),
            if (widget.forward) ...[
              TextField(controller: _to, keyboardType: TextInputType.emailAddress, decoration: _dec('Para: correo1@ejemplo.com, correo2@ejemplo.com')),
              const SizedBox(height: 10),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Para: ${widget.to ?? ''}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
              ),
            TextField(
              controller: _msg,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: _dec(widget.forward ? 'Mensaje (opcional)' : 'Escribe tu respuesta…'),
            ),
            if (_err != null) Text(_err!, style: const TextStyle(color: BSColors.danger, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  widget.forward ? 'Se envía el enlace del documento y su huella para verificarlo.' : 'Le llega por correo y a su bandeja de DocBlockSign.',
                  style: const TextStyle(color: AppTheme.hint, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 10),
              BSPrimaryButton(label: 'Enviar', icon: Icons.send_rounded, onPressed: _send),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Aprobar (comentario opcional) o rechazar (motivo obligatorio)
class _RespondDialog extends StatefulWidget {
  final bool approve;
  const _RespondDialog({required this.approve});
  @override
  State<_RespondDialog> createState() => _RespondDialogState();
}

class _RespondDialogState extends State<_RespondDialog> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.approve;
    final color = ok ? BSColors.success : BSColors.danger;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(ok ? 'Aprobar documento' : 'Rechazar documento',
                    style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(ok ? 'Puedes dejar un comentario para quien lo envió (opcional).' : 'Explica qué hay que corregir; se lo enviaremos a quien lo pidió.',
                style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: ok ? 'Comentario' : 'Motivo del rechazo',
                errorText: _err,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: 1.5)),
              ),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              BSPrimaryButton(
                label: ok ? 'Aprobar' : 'Rechazar',
                icon: ok ? Icons.check_rounded : Icons.close_rounded,
                color: color,
                onPressed: () {
                  final t = _ctrl.text.trim();
                  if (!ok && t.isEmpty) return setState(() => _err = 'Escribe el motivo');
                  Navigator.pop(context, t);
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Nuevo envío: elegir cuál documento compartir
class _PickDocumentDialog extends StatefulWidget {
  const _PickDocumentDialog();
  @override
  State<_PickDocumentDialog> createState() => _PickDocumentDialogState();
}

class _PickDocumentDialogState extends State<_PickDocumentDialog> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await DocumentService.getDocuments(search: _q.text.trim().isEmpty ? null : _q.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _docs = ((r['documents'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: h * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nuevo envío', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Elige el documento que quieres compartir o enviar a revisión.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppTheme.hint)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _q,
                onSubmitted: (_) => _load(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar documento',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.hint),
                  filled: true,
                  fillColor: BSColors.page,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
                : _docs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No hay documentos. Súbelos desde la sección Documentos.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEDF0F5)),
                        itemBuilder: (_, i) {
                          final d = _docs[i];
                          final m = Map<String, dynamic>.from((d['metadata'] as Map?) ?? {});
                          final pdf = (m['extension'] ?? 'pdf').toString().toLowerCase() == 'pdf';
                          final signed = ['signed', 'verified'].contains(d['status']);
                          return ListTile(
                            onTap: () => Navigator.pop(context, d),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: (pdf ? BSColors.danger : AppTheme.primary).withOpacity(0.09), borderRadius: BorderRadius.circular(9)),
                              child: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined, color: pdf ? BSColors.danger : AppTheme.primary, size: 20),
                            ),
                            title: Text(d['title']?.toString() ?? 'Documento', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(fmtFecha(d['created_at']?.toString()), style: const TextStyle(fontSize: 12)),
                            trailing: BSPill(label: signed ? 'Firmado' : 'Sin firmar', color: signed ? BSColors.success : BSColors.warning),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

/// Tarjeta del documento compartido: datos, huella y accesos
class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final ext = (doc['extension'] ?? 'pdf').toString().toLowerCase();
    final pdf = ext == 'pdf';
    final tint = pdf ? BSColors.danger : AppTheme.primary;
    final signed = ['signed', 'verified'].contains(doc['status']);
    final hash = doc['file_hash']?.toString() ?? '';
    final info = [
      doc['category'],
      if (doc['size_mb'] != null) fmtTamano(doc),
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
        if (hash.isNotEmpty) HuellaField(label: 'Huella digital del archivo', value: hash),
        if (signed && doc['blockchain_tx'] != null) ...[
          const SizedBox(height: 8),
          TechDetails(rows: [
            TechRow('Transacción', fmtHuella(doc['blockchain_tx'].toString()),
                copyValue: doc['blockchain_tx'].toString(), url: doc['blockchain_explorer']?.toString(), mono: true),
            if (doc['blockchain_block'] != null) TechRow('Bloque', fmtMiles(doc['blockchain_block'])),
          ]),
        ],
        const SizedBox(height: 12),
        _cardButtons(context, [
          if (doc['file_url'] != null)
            BSPrimaryButton(
              label: 'Ver documento',
              icon: Icons.visibility_outlined,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DocumentViewerScreen(
                  fileUrl: doc['file_url'].toString(),
                  title: doc['title']?.toString() ?? 'Documento',
                  extension: ext,
                  metadata: {
                    'title': doc['title'],
                    'status': doc['status'],
                    'file_hash': doc['file_hash'],
                    'extension': ext,
                    if (doc['size_mb'] != null) 'size_mb': doc['size_mb'],
                    if (doc['pages'] != null) 'pages': doc['pages'],
                  },
                ),
              )),
            ),
          if (hash.isNotEmpty)
            BSOutlineButton(
              label: MediaQuery.of(context).size.width < 600 ? 'Verificar' : 'Verificar autenticidad',
              icon: Icons.verified_outlined,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: BSColors.page,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: AppTheme.text,
                    title: const Text('Verificar documento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  body: VerifyScreen(initialHash: hash),
                ),
              )),
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

  /// En celular: botón principal a todo el ancho y los demás en dos columnas iguales
  Widget _cardButtons(BuildContext context, List<Widget> b) {
    if (MediaQuery.of(context).size.width >= 600 || b.isEmpty) return Wrap(spacing: 10, runSpacing: 10, children: b);
    final rest = b.skip(1).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      b.first,
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < rest.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: rest[i]),
          ],
        ]),
      ],
    ]);
  }
}

// Compatibilidad con otras pantallas que usaban estas funciones
String inboxAgo(String? iso) => _when(iso);
String inboxDate(String? iso) => chainDate(iso);
