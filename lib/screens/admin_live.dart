import 'dart:async';
import 'package:flutter/material.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/proof_ui.dart' show fmtFechaHora;
import '../widgets/skeleton.dart';
import '../widgets/sweet_alert.dart';

int _n(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

String _ago(int s) {
  if (s < 10) return 'ahora';
  if (s < 60) return 'hace $s s';
  if (s < 3600) return 'hace ${s ~/ 60} min';
  return 'hace ${s ~/ 3600} h';
}

String _dur(int s) {
  if (s < 60) return 'menos de 1 min';
  if (s < 3600) return '${s ~/ 60} min';
  final m = (s % 3600) ~/ 60;
  return '${s ~/ 3600} h ${m.toString().padLeft(2, '0')} min';
}

(IconData, String) _platform(dynamic p) => switch ('$p') {
      'android' => (Icons.android_rounded, 'Android'),
      'ios' => (Icons.phone_iphone_rounded, 'iPhone'),
      'windows' || 'macos' || 'linux' => (Icons.desktop_windows_outlined, 'Escritorio'),
      'web' => (Icons.language_rounded, 'Web'),
      _ => (Icons.devices_other_rounded, 'Sin dato'),
    };

Color _resultColor(dynamic r) => r == 'denegado' ? BSColors.danger : r == 'error' ? BSColors.warning : BSColors.success;

/// Punto verde que late (conectado)
class LiveDot extends StatefulWidget {
  final Color color;
  final double size;
  const LiveDot({super.key, this.color = BSColors.success, this.size = 10});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s * (1 + 1.2 * _c.value),
            height: s * (1 + 1.2 * _c.value),
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.35 * (1 - _c.value))),
          ),
          Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Avatar con el indicador de conexión en la esquina
class PresenceAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final bool online;
  final bool recent; // estuvo hace poco, pero ahora no da señales
  final double radius;
  const PresenceAvatar({super.key, required this.name, this.url, this.online = false, this.recent = false, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      BSAvatar(name: name, url: url, radius: radius),
      if (online || recent)
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? BSColors.success : BSColors.warning,
              border: Border.all(color: AppTheme.card, width: 2.5),
            ),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────
// PESTAÑA EN VIVO
// ─────────────────────────────────────────
class AdminLiveTab extends StatefulWidget {
  final double pad;
  const AdminLiveTab({super.key, required this.pad});

  @override
  State<AdminLiveTab> createState() => _AdminLiveTabState();
}

class _AdminLiveTabState extends State<AdminLiveTab> with AutomaticKeepAliveClientMixin {
  static const _every = Duration(seconds: 10);
  Map<String, dynamic>? _d;
  String? _error;
  Timer? _timer;
  bool _paused = false;
  DateTime? _at;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_every, (_) {
      // Solo mientras la pestaña está a la vista
      if (!_paused && mounted && TickerMode.of(context)) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.adminLive();
    if (!mounted) return;
    setState(() {
      _error = r['error']?.toString();
      if (r['error'] == null) {
        _d = r;
        _at = DateTime.now();
      }
    });
  }

  Future<void> _logout(Map<String, dynamic> p) async {
    final ok = await confirmForceLogout(context, p['email'].toString());
    if (!ok || !mounted) return;
    final r = await CollabService.adminForceLogout(p['id'].toString());
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo', text: r['error'].toString());
      return;
    }
    showToast(context, title: r['message']?.toString() ?? 'Sesión cerrada');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _d == null) {
      return Padding(padding: EdgeInsets.all(widget.pad), child: BSInfoBanner(title: 'No se pudo cargar', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded));
    }
    if (_d == null) return const SingleChildScrollView(child: SkeletonList(rows: 6));
    final d = _d!;
    final today = Map<String, dynamic>.from(d['today'] ?? {});
    final people = ((d['people'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final events = ((d['events'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final online = people.where((p) => p['online'] == true).toList();
    final away = people.where((p) => p['online'] != true).toList();
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 1100;

    final kpis = [
      _LiveKpi('Conectados ahora', _n(d['online']), '${_n(d['onlineUsers'])} usuarios · ${_n(d['onlineAdmins'])} superusuarios', Icons.wifi_tethering_rounded, BSColors.success, live: true),
      _LiveKpi('Activos (15 min)', _n(d['recent']), 'Con actividad en el último cuarto de hora', Icons.timelapse_rounded, AppTheme.primary),
      _LiveKpi('Ingresos hoy', _n(today['logins']), '${_n(today['people'])} personas con actividad hoy', Icons.login_rounded, AppTheme.featureCyan),
      _LiveKpi('Denegados hoy', _n(today['denied']), 'Ingresos fallidos o acciones sin permiso', Icons.gpp_maybe_outlined, _n(today['denied']) > 0 ? BSColors.danger : BSColors.success),
    ];

    final peopleCard = BSCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(title: 'Conectados ahora', trailing: '${online.length}'),
        if (online.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 20), child: Text('Nadie tiene la aplicación abierta en este momento.', style: TextStyle(color: AppTheme.hint)))
        else
          for (final p in online) _PersonRow(p: p, onOpen: () => showAdminUserDetail(context, p['id'].toString(), onChanged: _load), onLogout: () => _logout(p)),
        if (away.isNotEmpty) ...[
          _CardTitle(title: 'Estuvieron hace poco', trailing: '${away.length}', small: true),
          for (final p in away) _PersonRow(p: p, onOpen: () => showAdminUserDetail(context, p['id'].toString(), onChanged: _load), onLogout: () => _logout(p)),
        ],
      ]),
    );

    final feedCard = BSCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _CardTitle(title: 'Actividad en tiempo real'),
        if (events.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 20), child: Text('Sin actividad todavía.', style: TextStyle(color: AppTheme.hint)))
        else
          for (final e in events) _EventRow(e: e),
      ]),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.fromLTRB(widget.pad, 14, widget.pad, 28), children: [
        Row(children: [
          if (_paused) Icon(Icons.pause_circle_outline_rounded, color: AppTheme.hint, size: 20) else const LiveDot(),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _paused
                  ? 'En pausa · última lectura ${_at == null ? '' : _hhmmss(_at!)}'
                  : 'En vivo · se actualiza cada 10 s · última lectura ${_at == null ? '' : _hhmmss(_at!)}',
              style: TextStyle(color: AppTheme.hint, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: _paused ? 'Reanudar' : 'Pausar',
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: AppTheme.primary),
          ),
          IconButton(tooltip: 'Actualizar ahora', onPressed: _load, icon: Icon(Icons.refresh_rounded, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth > 1000 ? 4 : 2;
          final gap = c.maxWidth > 560 ? 12.0 : 10.0;
          final cw = (c.maxWidth - (cols - 1) * gap) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final k in kpis) SizedBox(width: cw, child: k)]);
        }),
        const SizedBox(height: 16),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: peopleCard),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: feedCard),
          ])
        else ...[
          peopleCard,
          const SizedBox(height: 16),
          feedCard,
        ],
        const SizedBox(height: 10),
        Text(
          'Se considera conectada a una persona con la aplicación abierta (la app avisa cada 45 s). '
          'Aquí no se ve el contenido de ningún documento.',
          style: TextStyle(color: AppTheme.hint, fontSize: 12),
        ),
      ]),
    );
  }

  static String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _CardTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final bool small;
  const _CardTitle({required this.title, this.trailing, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, small ? 12 : 16, 18, small ? 8 : 10),
      decoration: small ? BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))) : null,
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: TextStyle(color: small ? AppTheme.hint : AppTheme.text, fontSize: small ? 12 : 16, fontWeight: small ? FontWeight.w700 : FontWeight.w800)),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(trailing!, style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }
}

class _LiveKpi extends StatelessWidget {
  final String label, sub;
  final int value;
  final IconData icon;
  final Color color;
  final bool live;
  const _LiveKpi(this.label, this.value, this.sub, this.icon, this.color, {this.live = false});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 560;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        if (!compact) Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        if (!compact) const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (compact) ...[Icon(icon, color: color, size: 15), const SizedBox(width: 5)],
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
            Row(children: [
              Text('$value', style: TextStyle(color: AppTheme.text, fontSize: 24, fontWeight: FontWeight.w800)),
              if (live && value > 0) ...[const SizedBox(width: 4), const LiveDot(size: 8)],
            ]),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onOpen, onLogout;
  const _PersonRow({required this.p, required this.onOpen, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final online = p['online'] == true;
    final plat = _platform(p['platform']);
    final admin = p['role'] == 'admin';
    final name = (p['name'] ?? p['email']).toString();
    final narrow = MediaQuery.of(context).size.width < 600;
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 11, 6, 11),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.6)))),
        child: Row(children: [
          PresenceAvatar(name: name, url: p['avatar_url']?.toString(), online: online, recent: !online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700))),
                if (admin && !narrow) ...[const SizedBox(width: 6), BSPill(label: 'Superusuario', color: AppTheme.primary, dot: false)],
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  if (admin && narrow) 'Superusuario',
                  if ((p['section'] ?? '').toString().isNotEmpty) 'En ${p['section']}',
                  plat.$2,
                  if (!narrow && p['ip'] != null) 'IP ${p['ip']}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.hint, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(online ? _ago(_n(p['seconds_ago'])) : 'visto ${_ago(_n(p['seconds_ago']))}',
                style: TextStyle(color: online ? BSColors.success : AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w700)),
            if (online) Text('conectado ${_dur(_n(p['session_seconds']))}', style: TextStyle(color: AppTheme.hint, fontSize: 11)),
          ]),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.hint, size: 20),
            onSelected: (v) => v == 'open' ? onOpen() : onLogout(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Ver ficha de la cuenta')),
              if (!admin) const PopupMenuItem(value: 'logout', child: Text('Cerrar su sesión', style: TextStyle(color: BSColors.danger))),
            ],
          ),
        ]),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> e;
  const _EventRow({required this.e});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse('${e['created_at']}');
    final secs = created == null ? 0 : DateTime.now().difference(created.toLocal()).inSeconds.clamp(0, 1 << 30);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.6)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _resultColor(e['result']))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((e['description'] ?? e['action']).toString(), style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${e['email'] ?? 'Sin sesión'} · ${_ago(secs)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// FICHA DE UNA CUENTA
// ─────────────────────────────────────────
Future<bool> confirmForceLogout(BuildContext context, String email) => SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: 'Cerrar su sesión',
      text: 'Se cerrarán todas las sesiones abiertas de $email (web y celular). Podrá volver a entrar con su contraseña.',
      confirmText: 'Cerrar sesión',
    );

Future<void> showAdminUserDetail(BuildContext context, String id, {VoidCallback? onChanged}) {
  final w = MediaQuery.of(context).size.width;
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: w < 600 ? 12 : 40, vertical: 24),
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: _UserDetail(id: id, onChanged: onChanged)),
    ),
  );
}

class _UserDetail extends StatefulWidget {
  final String id;
  final VoidCallback? onChanged;
  const _UserDetail({required this.id, this.onChanged});

  @override
  State<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends State<_UserDetail> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _busy = false;
  double _statW = 180;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await CollabService.adminUserDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _error = r['error']?.toString();
      _d = r['error'] == null ? r : null;
    });
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() call) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo', text: r['error'].toString());
      return;
    }
    showToast(context, title: r['message']?.toString() ?? 'Listo');
    widget.onChanged?.call();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BSInfoBanner(title: 'No se pudo cargar', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))),
        ]),
      );
    }
    if (_d == null) return const Padding(padding: EdgeInsets.all(24), child: SkeletonList(rows: 5));
    final u = Map<String, dynamic>.from(_d!['user'] ?? {});
    final p = _d!['presence'] == null ? null : Map<String, dynamic>.from(_d!['presence']);
    final st = Map<String, dynamic>.from(_d!['stats'] ?? {});
    final activity = ((_d!['activity'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final admin = u['role'] == 'admin';
    final suspended = u['suspended'] == true;
    final online = p?['online'] == true;
    final name = (u['name'] ?? u['email']).toString();

    String status;
    Color statusColor;
    if (suspended) {
      status = 'Suspendida';
      statusColor = BSColors.danger;
    } else if (online) {
      status = 'Conectada ahora${(p?['section'] ?? '').toString().isEmpty ? '' : ' · en ${p!['section']}'}';
      statusColor = BSColors.success;
    } else if (p != null) {
      status = 'Vista por última vez ${fmtFechaHora(p['last_seen']?.toString())}';
      statusColor = AppTheme.hint;
    } else {
      status = 'Sin conexiones registradas';
      statusColor = AppTheme.hint;
    }

    Widget stat(String label, int v, {Color? color}) => Container(
          width: _statW,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$v', style: TextStyle(color: color ?? AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 2, style: TextStyle(color: AppTheme.hint, fontSize: 11.5)),
          ]),
        );

    Widget info(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 150, child: Text(k, style: TextStyle(color: AppTheme.hint, fontSize: 13))),
            Expanded(child: Text(v, style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        );

    final plat = _platform(p?['platform']);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
        child: Row(children: [
          PresenceAvatar(name: name, url: u['avatar_url']?.toString(), online: online, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(u['email'].toString(), style: TextStyle(color: AppTheme.hint, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                if (online) const LiveDot(size: 7),
                Flexible(child: Text(status, style: TextStyle(color: statusColor, fontSize: 12.5, fontWeight: FontWeight.w700))),
              ]),
            ]),
          ),
          IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppTheme.hint)),
        ]),
      ),
      Divider(height: 1, color: AppTheme.border),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (admin) BSPill(label: 'Superusuario', color: AppTheme.primary, dot: false),
              if (u['is_email_verified'] == true) BSPill(label: 'Correo verificado', color: BSColors.success, dot: false) else BSPill(label: 'Sin verificar', color: BSColors.warning, dot: false),
              if (u['google'] == true) BSPill(label: 'Google', color: BSColors.neutral, dot: false),
              if (u['email_reminders'] == false) BSPill(label: 'Recordatorios apagados', color: BSColors.neutral, dot: false),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (_, c) {
              _statW = (c.maxWidth - 20) / 3;
              return Wrap(spacing: 10, runSpacing: 10, children: [
              if (!admin) ...[
                stat('Documentos', _n(u['documents'])),
                stat('Firmados', _n(u['signed']), color: BSColors.success),
                stat('Pendientes', _n(u['pending']), color: BSColors.warning),
              ],
              stat('Ingresos (30 días)', _n(st['logins30'])),
              stat('Denegados (30 días)', _n(st['denied30']), color: _n(st['denied30']) > 0 ? BSColors.danger : null),
              stat('IP distintas (30 días)', _n(st['ips30'])),
            ]);
            }),
            const SizedBox(height: 16),
            info('Cuenta creada', fmtFechaHora(u['created_at']?.toString())),
            info('Último ingreso', u['last_login'] == null ? 'Nunca' : fmtFechaHora(u['last_login'].toString())),
            if (p != null) ...[
              info('Dispositivo', plat.$2),
              if (p['ip'] != null) info('Última IP', p['ip'].toString()),
              if (online) info('Conectada desde', '${fmtFechaHora(p['first_seen']?.toString())} (${_dur(_n(p['session_seconds']))})'),
            ],
            if (suspended && u['suspended_at'] != null) info('Suspendida el', fmtFechaHora(u['suspended_at'].toString())),
            if ((u['phone'] ?? '').toString().isNotEmpty) info('Teléfono', u['phone'].toString()),
            const SizedBox(height: 16),
            Text('Actividad reciente', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (activity.isEmpty)
              Text('Sin actividad registrada.', style: TextStyle(color: AppTheme.hint))
            else
              for (final a in activity)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: _resultColor(a['result']))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text((a['description'] ?? a['action']).toString(), style: TextStyle(color: AppTheme.text, fontSize: 13))),
                    const SizedBox(width: 8),
                    Text(fmtFechaHora(a['created_at']?.toString()), style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ]),
                ),
          ]),
        ),
      ),
      Divider(height: 1, color: AppTheme.border),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: admin
            ? Text('Las cuentas de superusuario se administran desde el servidor (npm run superusuario).', style: TextStyle(color: AppTheme.hint, fontSize: 12.5))
            : Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                if (u['is_email_verified'] != true)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => CollabService.adminResendVerification(widget.id)),
                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                    label: const Text('Reenviar verificación'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy || p == null
                      ? null
                      : () async {
                          if (await confirmForceLogout(context, u['email'].toString())) _run(() => CollabService.adminForceLogout(widget.id));
                        },
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Cerrar su sesión'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: suspended ? BSColors.success : BSColors.danger),
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await SweetAlert.confirm(
                            context,
                            type: SweetAlertType.warning,
                            danger: !suspended,
                            title: suspended ? 'Reactivar cuenta' : 'Suspender cuenta',
                            text: suspended
                                ? '${u['email']} podrá volver a entrar y usar DocBlockSign.'
                                : '${u['email']} no podrá entrar ni usar la aplicación hasta que la reactives. Si está conectada, sale de inmediato.',
                            confirmText: suspended ? 'Reactivar' : 'Suspender',
                          );
                          if (ok) _run(() => CollabService.adminSuspend(widget.id, !suspended));
                        },
                  icon: Icon(suspended ? Icons.lock_open_rounded : Icons.block_rounded, size: 16),
                  label: Text(suspended ? 'Reactivar' : 'Suspender'),
                ),
              ]),
      ),
    ]);
  }
}
