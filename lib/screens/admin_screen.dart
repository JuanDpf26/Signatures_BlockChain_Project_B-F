import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/proof_ui.dart' show fmtFechaHora;
import '../widgets/skeleton.dart';
import '../widgets/sweet_alert.dart';

/// Administración de la plataforma (solo rol admin).
/// Gestiona cuentas y servicios; nunca muestra documentos ajenos.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 28.0 : 16.0;
    return Container(
      color: BSColors.page,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 8),
          child: const BSPageHeader(
            breadcrumb: ['Inicio', 'Administración'],
            title: 'Administración',
            subtitle: 'Cuentas, actividad y estado de los servicios. El contenido de los documentos de cada usuario no es visible aquí.',
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: pad),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.hint,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Usuarios'),
              Tab(text: 'Auditoría global'),
              Tab(text: 'Estado del sistema'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _Overview(pad: pad),
            _Users(pad: pad),
            _GlobalAudit(pad: pad),
            _Health(pad: pad),
          ]),
        ),
      ]),
    );
  }
}

int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

// ─────────────────────────────────────────
// RESUMEN
// ─────────────────────────────────────────
class _Overview extends StatefulWidget {
  final double pad;
  const _Overview({required this.pad});

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await CollabService.adminOverview();
    if (!mounted) return;
    setState(() {
      _error = r['error']?.toString();
      _d = r['error'] == null ? r : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return Padding(padding: EdgeInsets.all(widget.pad), child: BSInfoBanner(title: 'No se pudo cargar', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded));
    if (_d == null) return const SingleChildScrollView(child: SkeletonList(rows: 6));
    final u = Map<String, dynamic>.from(_d!['users'] ?? {});
    final d = Map<String, dynamic>.from(_d!['documents'] ?? {});
    final q = Map<String, dynamic>.from(_d!['requests'] ?? {});
    final sec = Map<String, dynamic>.from(_d!['security7d'] ?? {});
    final daily = ((_d!['daily'] as List?) ?? const []).whereType<Map>().toList();
    final tiles = <Widget>[
      _Kpi('Usuarios', _i(u['total']), '${_i(u['verified'])} verificados · ${_i(u['new7d'])} nuevos en 7 días', Icons.people_alt_outlined, AppTheme.primary),
      _Kpi('Activos (7 días)', _i(u['active7d']), '${_i(u['suspended'])} suspendidos · ${_i(u['admins'])} administradores', Icons.bolt_rounded, AppTheme.featureCyan),
      _Kpi('Documentos', _i(d['total']), '${_i(d['pending'])} pendientes · ${_i(d['new7d'])} nuevos en 7 días', Icons.description_outlined, AppTheme.primary),
      _Kpi('Firmados', _i(d['signed']) + _i(d['verified']), '${_i(d['verified'])} verificados · ${_i(d['revoked'])} revocados', Icons.verified_outlined, BSColors.success),
      _Kpi('Solicitudes abiertas', _i(q['pending']), '${_i(q['cosignCollecting'])} firmas de varias personas en curso', Icons.pending_actions_rounded, BSColors.warning),
      _Kpi('Seguridad (7 días)', _i(sec['denied']), 'accesos denegados · ${_i(sec['errors'])} errores', Icons.shield_outlined, _i(sec['denied']) > 0 ? BSColors.danger : BSColors.success),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.fromLTRB(widget.pad, 16, widget.pad, 28), children: [
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 560 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        }),
        const SizedBox(height: 16),
        BSCard(
          title: 'Actividad de los últimos 14 días',
          child: daily.isEmpty
              ? Padding(padding: const EdgeInsets.all(12), child: Text('Sin actividad registrada.', style: TextStyle(color: AppTheme.hint)))
              : _ActivityBars(days: daily),
        ),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, sub;
  final int value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.sub, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$value', style: TextStyle(color: AppTheme.text, fontSize: 24, fontWeight: FontWeight.w800)),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

/// Barras por día: subidas, firmas e ingresos
class _ActivityBars extends StatelessWidget {
  final List<Map> days;
  const _ActivityBars({required this.days});

  @override
  Widget build(BuildContext context) {
    final series = [('uploads', 'Subidas', AppTheme.primary), ('signatures', 'Firmas', BSColors.success), ('logins', 'Ingresos', AppTheme.featureCyan)];
    var max = 1;
    for (final d in days) {
      for (final s in series) {
        if (_i(d[s.$1]) > max) max = _i(d[s.$1]);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 14, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(s.$2, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 150,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in days)
            Expanded(
              child: Tooltip(
                message: '${d['day']}: ${_i(d['uploads'])} subidas, ${_i(d['signatures'])} firmas, ${_i(d['logins'])} ingresos',
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final s in series)
                      Container(
                        width: 6,
                        height: 2 + 118 * _i(d[s.$1]) / max,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(color: s.$3, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text(d['day'].toString().substring(8), style: TextStyle(color: AppTheme.hint, fontSize: 11)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// USUARIOS
// ─────────────────────────────────────────
class _Users extends StatefulWidget {
  final double pad;
  const _Users({required this.pad});

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> with AutomaticKeepAliveClientMixin {
  final _q = TextEditingController();
  Timer? _deb;
  String _filter = 'all';
  int _page = 1, _pages = 1, _total = 0;
  List<Map<String, dynamic>>? _rows;
  String? _busy;

  static const _filters = {'all': 'Todos', 'unverified': 'Sin verificar', 'suspended': 'Suspendidos', 'admins': 'Administradores'};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.adminUsers(q: _q.text.trim(), filter: _filter, page: _page);
    if (!mounted) return;
    setState(() {
      _rows = ((r['users'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final p = (r['pagination'] as Map?) ?? {};
      _pages = _i(p['pages']) < 1 ? 1 : _i(p['pages']);
      _total = _i(p['total']);
    });
  }

  Future<void> _suspend(Map<String, dynamic> u) async {
    final suspended = u['suspended'] == true;
    final ok = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: !suspended,
      title: suspended ? 'Reactivar cuenta' : 'Suspender cuenta',
      text: suspended
          ? '${u['email']} podrá volver a entrar y usar DocBlockSign.'
          : '${u['email']} no podrá entrar ni usar la aplicación hasta que la reactives. Sus documentos y firmas se conservan.',
      confirmText: suspended ? 'Reactivar' : 'Suspender',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = u['id'].toString());
    final r = await CollabService.adminSuspend(u['id'].toString(), !suspended);
    if (!mounted) return;
    setState(() => _busy = null);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo', text: r['error'].toString());
      return;
    }
    showToast(context, title: r['message']?.toString() ?? 'Listo');
    _load();
  }

  Future<void> _resend(Map<String, dynamic> u) async {
    setState(() => _busy = u['id'].toString());
    final r = await CollabService.adminResendVerification(u['id'].toString());
    if (!mounted) return;
    setState(() => _busy = null);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo', text: r['error'].toString());
    } else {
      showToast(context, title: r['message']?.toString() ?? 'Correo reenviado');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final narrow = MediaQuery.of(context).size.width < 760;
    return ListView(padding: EdgeInsets.fromLTRB(widget.pad, 16, widget.pad, 28), children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: narrow ? double.infinity : 360,
          height: 44,
          child: TextField(
            controller: _q,
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), () { _page = 1; _load(); });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o correo',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
              filled: true,
              fillColor: AppTheme.card,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
        ),
        for (final e in _filters.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: _filter == e.key,
            onSelected: (_) { setState(() { _filter = e.key; _page = 1; }); _load(); },
            selectedColor: AppTheme.primary.withOpacity(0.12),
            labelStyle: TextStyle(color: _filter == e.key ? AppTheme.primary : AppTheme.text, fontWeight: FontWeight.w600, fontSize: 13),
          ),
      ]),
      const SizedBox(height: 14),
      BSCard(
        padding: EdgeInsets.zero,
        child: _rows == null
            ? const SkeletonList(rows: 6)
            : _rows!.isEmpty
                ? Padding(padding: const EdgeInsets.all(28), child: Center(child: Text('No hay usuarios con ese filtro.', style: TextStyle(color: AppTheme.hint))))
                : Column(children: [
                    for (final u in _rows!) _UserRow(user: u, busy: _busy == u['id'].toString(), onSuspend: () => _suspend(u), onResend: () => _resend(u)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                      child: Row(children: [
                        Expanded(child: Text('$_total ${_total == 1 ? 'usuario' : 'usuarios'}', style: TextStyle(color: AppTheme.hint, fontSize: 12))),
                        IconButton(tooltip: 'Anterior', onPressed: _page > 1 ? () { _page--; _load(); } : null, icon: const Icon(Icons.chevron_left_rounded)),
                        Text('$_page de $_pages', style: TextStyle(color: AppTheme.text, fontSize: 13)),
                        IconButton(tooltip: 'Siguiente', onPressed: _page < _pages ? () { _page++; _load(); } : null, icon: const Icon(Icons.chevron_right_rounded)),
                      ]),
                    ),
                  ]),
      ),
    ]);
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool busy;
  final VoidCallback onSuspend, onResend;
  const _UserRow({required this.user, required this.busy, required this.onSuspend, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final u = user;
    final narrow = MediaQuery.of(context).size.width < 760;
    final pills = Wrap(spacing: 6, runSpacing: 4, children: [
      if (u['role'] == 'admin') BSPill(label: 'Administrador', color: AppTheme.primary, dot: false),
      if (u['suspended'] == true) BSPill(label: 'Suspendida', color: BSColors.danger, dot: false),
      if (u['is_email_verified'] != true) BSPill(label: 'Sin verificar', color: BSColors.warning, dot: false),
      if (u['google'] == true) BSPill(label: 'Google', color: BSColors.neutral, dot: false),
    ]);
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((u['name'] ?? u['email']).toString(), style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
      Text(u['email'].toString(), style: TextStyle(color: AppTheme.hint, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        '${u['documents']} documentos · ${u['signed']} firmados · creada ${fmtFechaHora(u['created_at']?.toString())}'
        '${u['last_login'] != null ? ' · último ingreso ${fmtFechaHora(u['last_login'].toString())}' : ''}',
        style: TextStyle(color: AppTheme.hint, fontSize: 12),
      ),
    ]);
    final actions = Wrap(spacing: 6, runSpacing: 6, children: [
      if (u['is_email_verified'] != true)
        OutlinedButton.icon(onPressed: busy ? null : onResend, icon: const Icon(Icons.mark_email_read_outlined, size: 16), label: const Text('Reenviar verificación')),
      if (u['role'] != 'admin')
        OutlinedButton.icon(
          onPressed: busy ? null : onSuspend,
          style: OutlinedButton.styleFrom(foregroundColor: u['suspended'] == true ? BSColors.success : BSColors.danger),
          icon: Icon(u['suspended'] == true ? Icons.lock_open_rounded : Icons.block_rounded, size: 16),
          label: Text(u['suspended'] == true ? 'Reactivar' : 'Suspender'),
        ),
    ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), pills, const SizedBox(height: 8), actions])
          : Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppTheme.primary.withOpacity(0.12), child: Text(((u['name'] ?? u['email']).toString().trim().isEmpty ? '?' : (u['name'] ?? u['email']).toString().trim()[0]).toUpperCase(), style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(child: info),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: pills),
              actions,
            ]),
    );
  }
}

// ─────────────────────────────────────────
// AUDITORÍA GLOBAL
// ─────────────────────────────────────────
class _GlobalAudit extends StatefulWidget {
  final double pad;
  const _GlobalAudit({required this.pad});

  @override
  State<_GlobalAudit> createState() => _GlobalAuditState();
}

class _GlobalAuditState extends State<_GlobalAudit> with AutomaticKeepAliveClientMixin {
  final _q = TextEditingController();
  Timer? _deb;
  String? _result;
  int _page = 1, _pages = 1, _total = 0;
  List<Map<String, dynamic>>? _rows;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.adminAudit(result: _result, q: _q.text.trim(), page: _page);
    if (!mounted) return;
    setState(() {
      _rows = ((r['events'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final p = (r['pagination'] as Map?) ?? {};
      _pages = _i(p['pages']) < 1 ? 1 : _i(p['pages']);
      _total = _i(p['total']);
    });
  }

  Color _c(String? r) => r == 'denegado' ? BSColors.danger : r == 'error' ? BSColors.warning : BSColors.success;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final narrow = MediaQuery.of(context).size.width < 760;
    return ListView(padding: EdgeInsets.fromLTRB(widget.pad, 16, widget.pad, 28), children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: narrow ? double.infinity : 360,
          height: 44,
          child: TextField(
            controller: _q,
            onChanged: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 350), () { _page = 1; _load(); });
            },
            decoration: InputDecoration(
              hintText: 'Correo, IP o descripción',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
              filled: true,
              fillColor: AppTheme.card,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
        ),
        for (final e in const {null: 'Todos', 'denegado': 'Denegados', 'error': 'Errores', 'permitido': 'Permitidos'}.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: _result == e.key,
            onSelected: (_) { setState(() { _result = e.key; _page = 1; }); _load(); },
            selectedColor: AppTheme.primary.withOpacity(0.12),
            labelStyle: TextStyle(color: _result == e.key ? AppTheme.primary : AppTheme.text, fontWeight: FontWeight.w600, fontSize: 13),
          ),
      ]),
      const SizedBox(height: 14),
      BSCard(
        padding: EdgeInsets.zero,
        child: _rows == null
            ? const SkeletonList(rows: 8, leading: false)
            : Column(children: [
                for (final e in _rows!)
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((e['description'] ?? e['action']).toString(), style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            [fmtFechaHora(e['created_at']?.toString()), e['email'] ?? 'sin usuario', if (e['ip'] != null) e['ip'], e['action']].join(' · '),
                            style: TextStyle(color: AppTheme.hint, fontSize: 12),
                          ),
                        ]),
                      ),
                      BSPill(label: (e['result'] ?? '').toString(), color: _c(e['result']?.toString())),
                    ]),
                  ),
                if (_rows!.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Text('Sin eventos.', style: TextStyle(color: AppTheme.hint))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                  child: Row(children: [
                    Expanded(child: Text('$_total eventos', style: TextStyle(color: AppTheme.hint, fontSize: 12))),
                    IconButton(tooltip: 'Anterior', onPressed: _page > 1 ? () { _page--; _load(); } : null, icon: const Icon(Icons.chevron_left_rounded)),
                    Text('$_page de $_pages', style: TextStyle(color: AppTheme.text, fontSize: 13)),
                    IconButton(tooltip: 'Siguiente', onPressed: _page < _pages ? () { _page++; _load(); } : null, icon: const Icon(Icons.chevron_right_rounded)),
                  ]),
                ),
              ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// ESTADO DEL SISTEMA
// ─────────────────────────────────────────
class _Health extends StatefulWidget {
  final double pad;
  const _Health({required this.pad});

  @override
  State<_Health> createState() => _HealthState();
}

class _HealthState extends State<_Health> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _d;
  bool _running = false;

  static const _names = {
    'server': ('Servidor', Icons.dns_outlined),
    'database': ('Base de datos', Icons.storage_rounded),
    'blockchain': ('Blockchain (Sepolia)', Icons.link_rounded),
    'storage': ('Almacenamiento de archivos', Icons.folder_zip_outlined),
    'email': ('Correo (API de Gmail)', Icons.mail_outline_rounded),
    'ai': ('Inteligencia artificial (Groq)', Icons.psychology_outlined),
    'reminders': ('Recordatorios automáticos', Icons.notifications_active_outlined),
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _d = null);
    final r = await CollabService.adminHealth();
    if (mounted) setState(() => _d = r);
  }

  Future<void> _runReminders() async {
    setState(() => _running = true);
    final r = await CollabService.adminRunReminders();
    if (!mounted) return;
    setState(() => _running = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo', text: r['error'].toString());
    } else {
      showToast(context, title: r['message']?.toString() ?? 'Listo');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(padding: EdgeInsets.fromLTRB(widget.pad, 16, widget.pad, 28), children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        BSOutlineButton(label: 'Volver a comprobar', icon: Icons.refresh_rounded, onPressed: _d == null ? null : _load),
        BSOutlineButton(label: _running ? 'Enviando…' : 'Enviar recordatorios ahora', icon: Icons.notifications_active_outlined, onPressed: _running ? null : _runReminders),
      ]),
      const SizedBox(height: 14),
      if (_d == null)
        const SkeletonList(rows: 6)
      else if (_d!['error'] != null)
        BSInfoBanner(title: 'No se pudo comprobar', text: _d!['error'].toString(), color: BSColors.danger, icon: Icons.error_outline_rounded)
      else
        BSCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final e in _names.entries)
              if (_d![e.key] is Map)
                Builder(builder: (_) {
                  final s = Map<String, dynamic>.from(_d![e.key] as Map);
                  final ok = s['ok'] == true;
                  final warn = s['warn'] == true;
                  final color = !ok ? BSColors.danger : (warn ? BSColors.warning : BSColors.success);
                  return Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                    child: Row(children: [
                      Icon(e.value.$2, color: AppTheme.hint, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.value.$1, style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('${s['detail'] ?? ''}${s['ms'] != null ? ' · ${s['ms']} ms' : ''}', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        ]),
                      ),
                      if (e.key == 'blockchain' && s['contractUrl'] != null)
                        IconButton(
                          tooltip: 'Ver contrato en Etherscan',
                          onPressed: () => launchUrl(Uri.parse(s['contractUrl'].toString()), mode: LaunchMode.externalApplication),
                          icon: Icon(Icons.open_in_new_rounded, size: 18, color: AppTheme.primary),
                        ),
                      BSPill(label: !ok ? 'Falla' : (warn ? 'Revisar' : 'Bien'), color: color),
                    ]),
                  );
                }),
          ]),
        ),
      const SizedBox(height: 12),
      Text('El saldo de la cuenta emisora paga cada registro en Sepolia; si baja de 0,02 SepoliaETH aparece en amarillo.',
          style: TextStyle(color: AppTheme.hint, fontSize: 12)),
    ]);
  }
}
