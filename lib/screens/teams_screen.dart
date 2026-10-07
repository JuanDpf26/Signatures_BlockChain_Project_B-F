import 'dart:async';
import 'package:flutter/material.dart';
import '../services/collab_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/chain_steps.dart';
import '../widgets/sweet_alert.dart';
import 'inbox_screen.dart' show parseHexColor, inboxAgo;

/// Equipos: grupos de personas con cuenta en BlockSign para compartir
/// documentos y pedir revisiones a todos a la vez.
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

String roleLabel(String? r) => switch (r) { 'owner' => 'Dueño', 'admin' => 'Administrador', _ => 'Miembro' };
Color roleColor(String? r) => switch (r) { 'owner' => AppTheme.primary, 'admin' => AppTheme.featureCyan, _ => BSColors.neutral };

class _TeamsScreenState extends State<TeamsScreen> {
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  String? _error;

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
    final r = await CollabService.teams();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r['error'] != null) {
        _error = r['error'].toString();
      } else {
        _teams = ((r['teams'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  Future<void> _create() async {
    final created = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _TeamFormDialog());
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    SweetAlert.success(context, title: 'Equipo creado', text: 'Ahora agrega a las personas que lo conforman.', autoClose: const Duration(milliseconds: 1600));
    _openTeam(created['id'].toString());
  }

  Future<void> _openTeam(String id) async {
    final size = MediaQuery.of(context).size;
    final panel = _TeamDetail(id: id, onChanged: _load);
    if (size.width > 900) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 860, maxHeight: size.height * 0.88), child: panel),
        ),
      );
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, foregroundColor: AppTheme.text, elevation: 0, title: const Text('Equipo')),
          body: panel,
        ),
      ));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 28.0 : 16.0;

    Widget body;
    if (_loading) {
      body = const SizedBox(height: 240, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    } else if (_error != null) {
      body = BSInfoBanner(title: 'No se pudieron cargar los equipos', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded);
    } else if (_teams.isEmpty) {
      body = _EmptyTeams(onCreate: _create);
    } else {
      body = LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 680 ? 2 : 1;
        final cw = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < _teams.length; i++)
            SizedBox(
              width: cw,
              child: BSEntrance(delay: Duration(milliseconds: 40 * (i < 9 ? i : 9)), child: _TeamCard(team: _teams[i], onTap: () => _openTeam(_teams[i]['id'].toString()))),
            ),
          SizedBox(width: cw, child: _NewTeamCard(onTap: _create)),
        ]);
      });
    }

    final owned = _teams.where((t) => t['my_role'] == 'owner').length;
    final people = _teams.fold<int>(0, (a, t) => a + (int.tryParse('${t['members_count'] ?? 0}') ?? 0));

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Equipos'],
              title: 'Equipos',
              subtitle: 'Agrupa a las personas con las que trabajas para compartir documentos y pedir revisiones a todas a la vez.',
              actions: [BSPrimaryButton(label: 'Crear equipo', icon: Icons.group_add_rounded, onPressed: _create)],
            ),
            const SizedBox(height: 20),
            if (_teams.isNotEmpty) ...[
              BSKpiRow(items: [
                BSKpiCard(label: 'Mis equipos', value: '${_teams.length}', caption: '$owned creados por ti', color: AppTheme.primary, icon: Icons.groups_rounded),
                BSKpiCard(label: 'Personas', value: '$people', caption: 'Suma de miembros', color: AppTheme.featureCyan, icon: Icons.person_outline_rounded),
                BSKpiCard(
                  label: 'Envíos a equipos',
                  value: '${_teams.fold<int>(0, (a, t) => a + (int.tryParse('${t['shares_count'] ?? 0}') ?? 0))}',
                  caption: 'Documentos compartidos',
                  color: BSColors.success,
                  icon: Icons.send_outlined,
                ),
              ]),
              const SizedBox(height: 20),
            ],
            body,
          ]),
        ),
      ),
    );
  }
}

class _TeamCard extends StatefulWidget {
  final Map<String, dynamic> team;
  final VoidCallback onTap;
  const _TeamCard({required this.team, required this.onTap});

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.team;
    final color = parseHexColor(t['color']?.toString()) ?? AppTheme.primary;
    final preview = ((t['preview'] as List?) ?? const []).whereType<Map>().toList();
    final members = int.tryParse('${t['members_count'] ?? 0}') ?? 0;
    final shares = int.tryParse('${t['shares_count'] ?? 0}') ?? 0;
    final name = t['name']?.toString() ?? 'Equipo';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? color.withOpacity(0.4) : AppTheme.border),
            boxShadow: _hover ? AppTheme.hoverShadow : AppTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 6, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(bsIniciales(name), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  BSPill(label: roleLabel(t['my_role']?.toString()), color: roleColor(t['my_role']?.toString()), dot: false),
                ]),
                const SizedBox(height: 10),
                Text(
                  (t['description']?.toString().trim().isNotEmpty == true) ? t['description'].toString() : 'Sin descripción',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  SizedBox(
                    height: 30,
                    width: preview.isEmpty ? 0 : 22.0 * preview.length + 10,
                    child: Stack(children: [
                      for (var i = 0; i < preview.length; i++)
                        Positioned(
                          left: i * 22.0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: BSAvatar(name: (preview[i]['name'] ?? preview[i]['email'])?.toString(), radius: 13),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('$members ${members == 1 ? 'miembro' : 'miembros'} · $shares ${shares == 1 ? 'envío' : 'envíos'}',
                        style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: _hover ? color : AppTheme.hint),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NewTeamCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTeamCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: BSColors.selected,
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.35), width: 1.4),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.group_add_rounded, color: AppTheme.primary, size: 30),
            SizedBox(height: 8),
            Text('Crear equipo', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 15)),
            SizedBox(height: 2),
            Text('Área, proyecto, comité…', style: TextStyle(color: AppTheme.hint, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyTeams({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    Widget use(IconData i, String t, String d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(i, size: 17, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(d, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
              ]),
            ),
          ]),
        );
    return BSCard(
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 34),
        ),
        const SizedBox(height: 14),
        const Text('Aún no perteneces a ningún equipo', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 4),
        const Text('Crea uno o pide que te agreguen al de tu área.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(children: [
            use(Icons.send_outlined, 'Comparte con todos a la vez', 'Envía un documento al equipo y llega a la bandeja de cada miembro.'),
            use(Icons.fact_check_outlined, 'Pide revisiones', 'Cada persona aprueba o rechaza y tú ves el avance.'),
            use(Icons.admin_panel_settings_outlined, 'Roles', 'Dueño, administradores y miembros.'),
          ]),
        ),
        const SizedBox(height: 18),
        BSPrimaryButton(label: 'Crear mi primer equipo', icon: Icons.group_add_rounded, onPressed: onCreate),
        const SizedBox(height: 10),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// CREAR / EDITAR EQUIPO
// ─────────────────────────────────────────
class _TeamFormDialog extends StatefulWidget {
  final Map<String, dynamic>? team;
  const _TeamFormDialog({this.team});

  @override
  State<_TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<_TeamFormDialog> {
  late final _name = TextEditingController(text: widget.team?['name']?.toString() ?? '');
  late final _desc = TextEditingController(text: widget.team?['description']?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      );

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      await SweetAlert.warning(context, title: 'Falta el nombre', text: 'Ponle un nombre de al menos 2 letras.');
      return;
    }
    setState(() => _saving = true);
    final r = widget.team == null
        ? await CollabService.createTeam(_name.text.trim(), _desc.text.trim())
        : await CollabService.updateTeam(widget.team!['id'].toString(), name: _name.text.trim(), description: _desc.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo guardar', text: r['error'].toString());
      return;
    }
    Navigator.of(context).pop(Map<String, dynamic>.from((r['team'] as Map?) ?? {}));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.team != null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(editing ? 'Editar equipo' : 'Nuevo equipo', style: const TextStyle(color: AppTheme.text, fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 18),
            const Text('Nombre', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(controller: _name, maxLength: 60, autofocus: true, decoration: _dec('Ej.: Comité de contratación').copyWith(counterText: '')),
            const SizedBox(height: 14),
            const Text('Descripción (opcional)', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(controller: _desc, minLines: 2, maxLines: 4, maxLength: 300, decoration: _dec('¿Para qué usan este equipo?')),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              BSPrimaryButton(label: editing ? 'Guardar' : 'Crear equipo', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// DETALLE DEL EQUIPO
// ─────────────────────────────────────────
class _TeamDetail extends StatefulWidget {
  final String id;
  final VoidCallback onChanged;
  const _TeamDetail({required this.id, required this.onChanged});

  @override
  State<_TeamDetail> createState() => _TeamDetailState();
}

class _TeamDetailState extends State<_TeamDetail> {
  Map<String, dynamic>? _team;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _docs = [];
  String? _error;
  final _email = TextEditingController();
  List<Map<String, dynamic>> _suggest = [];
  Timer? _debounce;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await CollabService.team(widget.id);
    if (!mounted) return;
    setState(() {
      if (r['error'] != null) {
        _error = r['error'].toString();
      } else {
        _team = Map<String, dynamic>.from((r['team'] as Map?) ?? {});
        _members = ((r['members'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _docs = ((r['documents'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  String get _myRole => _team?['my_role']?.toString() ?? 'member';
  bool get _canManage => _myRole == 'owner' || _myRole == 'admin';

  void _onType(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() => _suggest = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final r = await CollabService.searchUsers(v.trim());
      if (!mounted) return;
      final inTeam = _members.map((m) => m['email']?.toString().toLowerCase()).toSet();
      setState(() => _suggest = ((r['users'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((u) => !inTeam.contains(u['email']?.toString().toLowerCase()))
          .toList());
    });
  }

  Future<void> _add([String? email]) async {
    final e = (email ?? _email.text).trim();
    if (e.isEmpty) return;
    setState(() => _adding = true);
    final r = await CollabService.addMember(widget.id, e);
    if (!mounted) return;
    setState(() => _adding = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo agregar', text: r['error'].toString());
      return;
    }
    _email.clear();
    setState(() => _suggest = []);
    SweetAlert.success(context, title: r['message']?.toString() ?? 'Miembro agregado', autoClose: const Duration(milliseconds: 1300));
    await _load();
    widget.onChanged();
  }

  Future<void> _memberAction(Map<String, dynamic> m, String action) async {
    final uid = m['user_id'].toString();
    Map<String, dynamic> r;
    if (action == 'remove') {
      final ok = await SweetAlert.confirm(context, title: '¿Quitar a ${m['name'] ?? m['email']}?', text: 'Dejará de recibir los documentos que se envíen al equipo.', confirmText: 'Sí, quitar', danger: true);
      if (!ok) return;
      r = await CollabService.removeMember(widget.id, uid);
    } else {
      r = await CollabService.setRole(widget.id, uid, admin: action == 'admin');
    }
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo completar', text: r['error'].toString());
      return;
    }
    await _load();
    widget.onChanged();
  }

  Future<void> _edit() async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _TeamFormDialog(team: _team));
    if (r != null) {
      await _load();
      widget.onChanged();
    }
  }

  Future<void> _leaveOrDelete() async {
    final owner = _myRole == 'owner';
    final ok = await SweetAlert.confirm(
      context,
      title: owner ? '¿Eliminar el equipo?' : '¿Salir del equipo?',
      text: owner ? 'Se eliminará para todos los miembros. Los documentos ya enviados se conservan en sus bandejas.' : 'Dejarás de recibir los documentos que se envíen a este equipo.',
      confirmText: owner ? 'Sí, eliminar' : 'Sí, salir',
      danger: true,
    );
    if (!ok || !mounted) return;
    final r = owner ? await CollabService.deleteTeam(widget.id) : await CollabService.removeMember(widget.id, _team?['my_user_id']?.toString() ?? '');
    if (!mounted) return;
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo completar', text: r['error'].toString());
      return;
    }
    widget.onChanged();
    Navigator.of(context).pop();
    SweetAlert.success(context, title: r['message']?.toString() ?? 'Listo', autoClose: const Duration(milliseconds: 1300));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(20), child: BSInfoBanner(title: 'No se pudo abrir el equipo', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded));
    }
    if (_team == null) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    final color = parseHexColor(_team!['color']?.toString()) ?? AppTheme.primary;
    final narrow = MediaQuery.of(context).size.width < 600;
    final pad = narrow ? 16.0 : 24.0;
    final wide = MediaQuery.of(context).size.width > 900;

    final header = Container(
      padding: EdgeInsets.fromLTRB(pad, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(bsIniciales(_team!['name']?.toString()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_team!['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              (_team!['description']?.toString().trim().isNotEmpty == true) ? _team!['description'].toString() : '${_members.length} miembros',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
            ),
          ]),
        ),
        if (_canManage) IconButton(tooltip: 'Editar', onPressed: _edit, icon: const Icon(Icons.edit_outlined, color: Colors.white)),
        IconButton(
          tooltip: _myRole == 'owner' ? 'Eliminar equipo' : 'Salir del equipo',
          onPressed: _leaveOrDelete,
          icon: Icon(_myRole == 'owner' ? Icons.delete_outline_rounded : Icons.logout_rounded, color: Colors.white),
        ),
        if (wide) IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
      ]),
    );

    final membersCard = BSCard(
      title: 'Miembros',
      trailing: Text('${_members.length}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_canManage) ...[
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _email,
                  onChanged: _onType,
                  onSubmitted: (_) => _add(),
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.text, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Correo de la persona (debe tener cuenta)',
                    hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                    prefixIcon: const Icon(Icons.person_add_alt_rounded, size: 18, color: AppTheme.hint),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BSPrimaryButton(label: 'Agregar', icon: Icons.add_rounded, loading: _adding, onPressed: () => _add()),
          ]),
          if (_suggest.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.cardShadow),
              child: Column(children: [
                for (final u in _suggest)
                  ListTile(
                    dense: true,
                    leading: BSAvatar(name: u['name']?.toString(), radius: 15),
                    title: Text(u['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text(u['email']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                    onTap: () => _add(u['email']?.toString()),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
        ],
        for (final m in _members)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(children: [
              BSAvatar(name: (m['name'] ?? m['email'])?.toString(), url: m['avatar_url']?.toString(), radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((m['name'] ?? m['email']).toString(), style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(m['email']?.toString() ?? '', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                ]),
              ),
              BSPill(label: roleLabel(m['role']?.toString()), color: roleColor(m['role']?.toString()), dot: false),
              if (_canManage && m['role'] != 'owner')
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.hint, size: 20),
                  onSelected: (a) => _memberAction(m, a),
                  itemBuilder: (_) => [
                    if (_myRole == 'owner' && m['role'] != 'admin') const PopupMenuItem(value: 'admin', child: Text('Hacer administrador')),
                    if (_myRole == 'owner' && m['role'] == 'admin') const PopupMenuItem(value: 'member', child: Text('Quitar como administrador')),
                    const PopupMenuItem(value: 'remove', child: Text('Quitar del equipo', style: TextStyle(color: BSColors.danger))),
                  ],
                )
              else
                const SizedBox(width: 12),
            ]),
          ),
      ]),
    );

    final docsCard = BSCard(
      title: 'Documentos enviados al equipo',
      trailing: Text('${_docs.length}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: _docs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Aún no se ha enviado nada. Desde Documentos, usa “Enviar” y elige este equipo.',
                  style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
            )
          : Column(children: [
              for (final d in _docs)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.description_outlined, color: AppTheme.primary, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['title']?.toString() ?? 'Documento', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text('${d['sender_name'] ?? d['sender_email'] ?? ''} · ${inboxAgo(d['created_at']?.toString())}',
                            style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                      ]),
                    ),
                    BSPill(label: d['kind'] == 'review' ? 'Revisión' : 'Conocimiento', color: d['kind'] == 'review' ? AppTheme.featureCyan : BSColors.neutral, dot: false),
                  ]),
                ),
            ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      Expanded(
        child: Container(
          color: BSColors.page,
          child: ListView(padding: EdgeInsets.fromLTRB(pad, 16, pad, 24), children: [
            BSInfoBanner(
              title: 'Tu rol: ${roleLabel(_myRole)}',
              text: _canManage
                  ? 'Puedes agregar y quitar miembros. Para enviar un documento a todo el equipo, ábrelo en Documentos y usa “Enviar”.'
                  : 'Recibirás en tu bandeja los documentos que se envíen a este equipo. Creado el ${chainDate(_team!['created_at']?.toString())}.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 14),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: membersCard),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: docsCard),
              ])
            else ...[
              membersCard,
              const SizedBox(height: 14),
              docsCard,
            ],
          ]),
        ),
      ),
    ]);
  }
}
