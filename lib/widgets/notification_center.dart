import 'dart:async';
import 'package:flutter/material.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';

/// Campana con el centro de notificaciones (estilo Vercel): pestañas
/// Entrada / Archivo, avisos con ícono, nombres en negrita y fecha a la derecha.
class NotificationBell extends StatefulWidget {
  final List<Map<String, dynamic>> pending; // documentos por firmar (fila fija arriba)
  final VoidCallback onShowPending;
  const NotificationBell({super.key, required this.pending, required this.onShowPending});

  // Navegación de la app (las asigna HomeScreen)
  static ValueChanged<int>? navigate;
  static ValueChanged<String>? openDocument;

  /// Vuelve a consultar el contador (por ejemplo, después de responder una revisión)
  static final refresh = ValueNotifier<int>(0);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
    NotificationBell.refresh.addListener(_load);
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotificationBell.refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.notificationsSummary();
    if (!mounted || r['error'] != null) return;
    final n = int.tryParse('${r['unread'] ?? 0}') ?? 0;
    if (n != _unread) setState(() => _unread = n);
  }

  Future<void> _open() async {
    final size = MediaQuery.of(context).size;
    final panel = _NotificationPanel(pending: widget.pending, onShowPending: widget.onShowPending, onChanged: _load);
    if (size.width >= 700) {
      final box = context.findRenderObject() as RenderBox?;
      final pos = box?.localToGlobal(Offset.zero) ?? Offset(size.width - 60, 16);
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar notificaciones',
        barrierColor: Colors.black.withOpacity(0.08),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (ctx, _, __) => Stack(children: [
          Positioned(
            top: pos.dy + 52,
            right: (size.width - pos.dx - 42).clamp(12, size.width),
            width: 440,
            height: (size.height - pos.dy - 80).clamp(320, 640),
            child: Material(
              color: AppTheme.card,
              elevation: 12,
              shadowColor: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: panel,
              ),
            ),
          ),
        ]),
        transitionBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, -0.01), end: Offset.zero).animate(a), child: child),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (_) => SizedBox(height: size.height * 0.88, child: panel),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final n = _unread;
    return Tooltip(
      message: n == 0 ? 'Notificaciones' : '$n notificaci${n == 1 ? 'ón' : 'ones'} sin leer',
      child: InkWell(
        onTap: _open,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Icon(n > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded, color: AppTheme.text, size: 22),
            if (n > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: BSColors.danger, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.card, width: 1.5)),
                  alignment: Alignment.center,
                  child: Text(n > 9 ? '9+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatefulWidget {
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowPending;
  final VoidCallback onChanged;
  const _NotificationPanel({required this.pending, required this.onShowPending, required this.onChanged});

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  int _tab = 0; // 0 Entrada · 1 Archivo
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  static bool _hideEmailTip = false;

  String get _box => _tab == 0 ? 'inbox' : 'archive';

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
    final r = await CollabService.notifications(box: _box);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r['error'] != null) {
        _error = r['error'].toString();
      } else {
        _items = ((r['items'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  Future<void> _openItem(Map<String, dynamic> n) async {
    if (n['read'] != true) {
      setState(() => n['read'] = true);
      CollabService.notificationsRead(keys: [n['key'].toString()]).then((_) => widget.onChanged());
    }
    final link = Map<String, dynamic>.from((n['link'] as Map?) ?? {});
    Navigator.of(context).pop();
    switch (link['section']) {
      case 'inbox':
        NotificationBell.navigate?.call(5);
        break;
      case 'teams':
        NotificationBell.navigate?.call(6);
        break;
      case 'documents':
        if (link['title'] != null) {
          NotificationBell.openDocument?.call(link['title'].toString());
        } else {
          NotificationBell.navigate?.call(1);
        }
        break;
    }
  }

  Future<void> _archive(Map<String, dynamic> n) async {
    final archived = _tab == 0;
    setState(() => _items.remove(n));
    await CollabService.notificationsArchive(keys: [n['key'].toString()], archived: archived);
    widget.onChanged();
  }

  Future<void> _markAll() async {
    setState(() {
      for (final n in _items) {
        n['read'] = true;
      }
    });
    await CollabService.notificationsRead(all: true);
    widget.onChanged();
  }

  Future<void> _archiveAll() async {
    setState(() => _items = []);
    await CollabService.notificationsArchive(all: true);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['read'] != true).length;
    Widget tab(String label, int i) => InkWell(
          onTap: () {
            if (_tab == i) return;
            setState(() => _tab = i);
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            margin: const EdgeInsets.only(right: 18),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? AppTheme.text : Colors.transparent, width: 2))),
            child: Text(label,
                style: TextStyle(color: _tab == i ? AppTheme.text : AppTheme.hint, fontSize: 14.5, fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500)),
          ),
        );

    Widget body;
    if (_loading && _items.isEmpty) {
      body = Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.primary));
    } else if (_error != null) {
      body = Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: TextStyle(color: AppTheme.hint)));
    } else {
      final pinned = _tab == 0 && widget.pending.isNotEmpty;
      if (_items.isEmpty && !pinned) {
        body = _Empty(archive: _tab == 1);
      } else {
        body = ListView(padding: EdgeInsets.zero, children: [
          if (pinned)
            _Row(
              n: {
                'type': 'pending',
                'text': widget.pending.length == 1
                    ? 'Tienes **1 documento** por firmar: ${widget.pending.first['title']}'
                    : 'Tienes **${widget.pending.length} documentos** por firmar',
                'read': true,
              },
              trailingText: 'Ver',
              onTap: () {
                Navigator.of(context).pop();
                widget.onShowPending();
              },
            ),
          for (final n in _items)
            _Row(
              n: n,
              archived: _tab == 1,
              onTap: () => _openItem(n),
              onArchive: () => _archive(n),
            ),
        ]);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Encabezado: pestañas y acciones
      Container(
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          tab('Entrada', 0),
          tab('Archivo', 1),
          const Spacer(),
          if (_tab == 0 && _items.isNotEmpty) ...[
            if (unread > 0)
              IconButton(
                tooltip: 'Marcar todo como leído',
                onPressed: _markAll,
                icon: Icon(Icons.done_all_rounded, size: 20, color: AppTheme.hint),
              ),
            IconButton(
              tooltip: 'Archivar todo',
              onPressed: _archiveAll,
              icon: Icon(Icons.archive_outlined, size: 20, color: AppTheme.hint),
            ),
          ],
          IconButton(
            tooltip: 'Preferencias',
            onPressed: () {
              Navigator.of(context).pop();
              NotificationBell.navigate?.call(3);
            },
            icon: Icon(Icons.settings_outlined, size: 20, color: AppTheme.hint),
          ),
        ]),
      ),
      Expanded(child: body),
      // Aviso inferior (como el de Vercel)
      if (_tab == 0 && !_hideEmailTip)
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.mark_email_unread_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Los avisos importantes también te llegan por correo: revisiones, respuestas y comprobantes de firma.',
                    style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.4)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _hideEmailTip = true),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: AppTheme.text),
                  child: const Text('Ocultar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    NotificationBell.navigate?.call(5);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    backgroundColor: AppTheme.text,
                    foregroundColor: AppTheme.card,
                  ),
                  child: const Text('Ir a la bandeja'),
                ),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

/// Un aviso: ícono, texto con **negritas**, fecha y archivar al pasar el mouse
class _Row extends StatefulWidget {
  final Map<String, dynamic> n;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final String? trailingText;
  const _Row({required this.n, required this.onTap, this.onArchive, this.archived = false, this.trailingText});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  static (IconData, Color) _look(String? type) => switch (type) {
        'review' => (Icons.fact_check_rounded, BSColors.warning),
        'share' => (Icons.description_rounded, AppTheme.primary),
        'approved' => (Icons.check_circle_rounded, BSColors.success),
        'rejected' => (Icons.cancel_rounded, BSColors.danger),
        'signed' => (Icons.verified_rounded, AppTheme.primary),
        'error' => (Icons.warning_amber_rounded, BSColors.danger),
        'team' => (Icons.groups_rounded, const Color(0xFF8E24AA)),
        'pending' => (Icons.draw_rounded, BSColors.warning),
        _ => (Icons.notifications_rounded, AppTheme.hint),
      };

  static String _when(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
    return '${t.day} ${m[t.month - 1]}';
  }

  List<TextSpan> _spans(String text, bool unread) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: TextStyle(fontWeight: i.isOdd ? FontWeight.w800 : (unread ? FontWeight.w600 : FontWeight.w400))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final unread = n['read'] != true;
    final (icon, color) = _look(n['type']?.toString());
    final desktop = MediaQuery.of(context).size.width >= 700;
    final showArchive = widget.onArchive != null && (_hover || !desktop);

    final row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.surface : (unread ? AppTheme.primary.withOpacity(AppTheme.isDark ? 0.08 : 0.035) : Colors.transparent),
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Punto de no leído
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 14, right: 6),
              decoration: BoxDecoration(color: unread ? AppTheme.primary : Colors.transparent, shape: BoxShape.circle),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: _spans(n['text']?.toString() ?? '', unread)),
                style: TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.45),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.topRight,
                child: showArchive && desktop
                    ? Tooltip(
                        message: widget.archived ? 'Mover a Entrada' : 'Archivar',
                        child: InkWell(
                          onTap: widget.onArchive,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(widget.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18, color: AppTheme.hint),
                          ),
                        ),
                      )
                    : Text(widget.trailingText ?? _when(n['date']?.toString()),
                        style: TextStyle(
                            color: widget.trailingText != null ? AppTheme.primary : AppTheme.hint,
                            fontSize: 12.5,
                            fontWeight: widget.trailingText != null ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ]),
        ),
      ),
    );
    // En el celular: deslizar para archivar
    if (desktop || widget.onArchive == null) return row;
    return Dismissible(
      key: ValueKey(n['key']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onArchive!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.primary.withOpacity(0.12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.archived ? Icons.unarchive_outlined : Icons.archive_outlined, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(widget.archived ? 'Mover a Entrada' : 'Archivar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ]),
      ),
      child: row,
    );
  }
}

class _Empty extends StatelessWidget {
  final bool archive;
  const _Empty({required this.archive});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(archive ? Icons.archive_outlined : Icons.notifications_none_rounded, size: 34, color: AppTheme.hint),
            const SizedBox(height: 10),
            Text(archive ? 'No hay notificaciones archivadas' : 'Estás al día',
                style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(archive ? 'Lo que archives aparecerá aquí.' : 'Aquí verás revisiones, respuestas, firmas y avisos de tus equipos.',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          ]),
        ),
      );
}
