import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../screens/document_screen.dart';
import 'profile_screen.dart';
import 'verify_screen.dart';
import '../widgets/sign_ia_assistant.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _docSearch; // búsqueda que viene del buscador de la barra superior
  String? _docStatus; // estado con el que se abre Documentos (campana)
  int _docKey = 0;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentDocs = [];
  bool _loading = true;

  // Usuario (para el saludo de la barra superior)
  String _userName = '';
  String _userEmail = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    try {
      final res = await ProfileService.getProfile();
      if (!mounted || !res.containsKey('user')) return;
      final u = Map<String, dynamic>.from(res['user']);
      setState(() {
        _userName = u['name']?.toString() ?? '';
        _userEmail = u['email']?.toString() ?? '';
        _avatarUrl = u['avatar_url']?.toString();
      });
    } catch (_) {
      // Si el backend no responde, la barra muestra el saludo sin nombre
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final statsRes = await DocumentService.getStats();
      final docsRes = await DocumentService.getDocuments(page: 1);
      if (!mounted) return;
      setState(() {
        if (!statsRes.containsKey('error')) _stats = statsRes;
        if (docsRes.containsKey('documents')) {
          _recentDocs = List<Map<String, dynamic>>.from(docsRes['documents']);
        }
      });
    } catch (_) {
      // sin conexión: se muestran los valores vacíos
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _pending =>
      _recentDocs.where((d) => d['status'] == 'pending' && !['sending', 'confirming'].contains((d['metadata'] as Map?)?['blockchain_status'])).toList();

  void _searchDocs(String q) {
    setState(() {
      _docSearch = q.isEmpty ? null : q;
      _docStatus = null;
      _docKey++;
      _selectedIndex = 1;
    });
  }

  void _showPending() {
    setState(() {
      _docSearch = null;
      _docStatus = 'pending';
      _docKey++;
      _selectedIndex = 1;
    });
  }

  void _goTo(int i) {
    final leavingProfile = _selectedIndex == 3 && i != 3;
    setState(() {
      // Entrar a Documentos desde el menú lo abre sin filtros
      if (i == 1 && _selectedIndex != 1) {
        _docSearch = null;
        _docStatus = null;
      }
      _selectedIndex = i;
    });
    if (leavingProfile) _loadUser(); // por si cambió el nombre o la foto
    if (i == 0) _loadData();
  }

  Future<void> _logout() async {
    final ok = await SweetAlert.confirm(
      context,
      title: '¿Cerrar sesión?',
      text: 'Tendrás que volver a ingresar tus credenciales.',
      confirmText: 'Sí, cerrar sesión',
      type: SweetAlertType.question,
    );
    if (ok) {
      await AuthService.logout();
      resetSignIa();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1:
        return DocumentsScreen(key: ValueKey('docs-$_docKey'), initialSearch: _docSearch, initialStatus: _docStatus);
      case 2:
        return const VerifyScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _DashboardContent(
          stats: _stats,
          recentDocs: _recentDocs,
          loading: _loading,
          onNavTap: _goTo,
          onRefresh: _loadData,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);
    final user = _UserInfo(name: _userName, email: _userEmail, avatarUrl: _avatarUrl);
    return isWeb
        ? _WebShell(
            selectedIndex: _selectedIndex,
            onNavTap: _goTo,
            onLogout: _logout,
            user: user,
            content: _buildContent(),
            onSearch: _searchDocs,
            pending: _pending,
            onShowPending: _showPending,
          )
        : _MobileShell(
            selectedIndex: _selectedIndex,
            onNavTap: _goTo,
            user: user,
            content: _buildContent(),
            pending: _pending,
            onShowPending: _showPending,
          );
  }
}

/// Transición suave al cambiar de sección (se desvanece y sube un poco)
class _ContentSwitcher extends StatelessWidget {
  final int index;
  final Widget child;
  const _ContentSwitcher({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }
}

class _UserInfo {
  final String name, email;
  final String? avatarUrl;
  const _UserInfo({required this.name, required this.email, this.avatarUrl});
}

// ── Web shell ──────────────────────────────────────────────────────────────
class _WebShell extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final _UserInfo user;
  final Widget content;
  final ValueChanged<String> onSearch;
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowPending;
  const _WebShell({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.user,
    required this.content,
    required this.onSearch,
    required this.pending,
    required this.onShowPending,
  });

  @override
  State<_WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<_WebShell> {
  bool? _userCollapsed; // null = automático según el ancho

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // En pantallas medianas (tablet / laptop pequeña) el menú arranca contraído
    final collapsed = _userCollapsed ?? width < 1200;

    return Scaffold(
      backgroundColor: BSColors.page,
      floatingActionButton: SignIaFab(onTap: () => showSignIa(context, onNavigate: widget.onNavTap)),
      body: Row(children: [
        _Sidebar(
          selectedIndex: widget.selectedIndex,
          onNavTap: widget.onNavTap,
          onLogout: widget.onLogout,
          collapsed: collapsed,
          onToggle: () => setState(() => _userCollapsed = !collapsed),
        ),
        Expanded(
          child: Column(children: [
            _TopBar(
              user: widget.user,
              onProfile: () => widget.onNavTap(3),
              onSearch: widget.onSearch,
              pending: widget.pending,
              onShowPending: widget.onShowPending,
            ),
            Expanded(child: _ContentSwitcher(index: widget.selectedIndex, child: widget.content)),
          ]),
        ),
      ]),
    );
  }
}

// ── Menú lateral claro (estilo panel institucional) ────────────────────────
// Expandido 264 px / contraído 84 px.
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = collapsed;
    final w = c ? 84.0 : 264.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: w,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: w,
          maxWidth: w,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Marca ──
            Padding(
              padding: EdgeInsets.fromLTRB(c ? 0 : 22, 22, c ? 0 : 16, 0),
              child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                const _LogoMark(size: 46),
                if (!c) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'Block', style: TextStyle(color: AppTheme.text)),
                        TextSpan(text: 'Sign', style: TextStyle(color: AppTheme.primary)),
                      ]), style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.6, height: 1.05)),
                      Text('Firma digital', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
              ]),
            ),
            if (!c)
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 16, 6),
                child: Text('DOCUMENTOS Y FIRMAS',
                    style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              )
            else
              const SizedBox(height: 18),

            // ── Navegación ──
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                _NavItem(icon: Icons.space_dashboard_outlined, label: 'Tablero', selected: selectedIndex == 0, collapsed: c, onTap: () => onNavTap(0)),
                _NavItem(icon: Icons.description_outlined, label: 'Documentos', selected: selectedIndex == 1, collapsed: c, onTap: () => onNavTap(1)),
                _NavItem(icon: Icons.verified_outlined, label: 'Verificar', selected: selectedIndex == 2, collapsed: c, onTap: () => onNavTap(2)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: c ? 22 : 22, vertical: 14),
                  child: Container(height: 1, color: AppTheme.border),
                ),
                _NavItem(icon: Icons.person_outline_rounded, label: 'Mi perfil', selected: selectedIndex == 3, collapsed: c, onTap: () => onNavTap(3)),
                _NavItem(icon: Icons.logout_rounded, label: 'Cerrar sesión', selected: false, collapsed: c, danger: true, onTap: onLogout),
              ]),
            ),

            // ── Ambiente / red ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: c ? 14 : 16),
              child: Tooltip(
                message: c ? 'Red: Sepolia Testnet · Datos de prueba' : '',
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: c ? 0 : 16, vertical: 14),
                  decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12)),
                  child: c
                      ? const Center(child: _PulseDot())
                      : const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _PulseDot(),
                            SizedBox(width: 6),
                            Text('Red: Sepolia Testnet', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                          SizedBox(height: 4),
                          Text('Blockchain de pruebas · v1.0', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        ]),
                ),
              ),
            ),

            // ── Contraer / expandir ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Tooltip(
                message: c ? 'Expandir menú' : '',
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                      AnimatedRotation(
                        turns: c ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: const Icon(Icons.keyboard_double_arrow_left_rounded, color: AppTheme.hint, size: 20),
                      ),
                      if (!c) ...[
                        const SizedBox(width: 10),
                        const Text('Contraer menú', style: TextStyle(color: AppTheme.hint, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Logo de BlockSign: círculo azul con escudo blanco (como el sello de la marca)
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
      child: Icon(Icons.verified_user_rounded, color: Colors.white, size: size * 0.52),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected, collapsed, danger;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final c = widget.collapsed;
    final base = widget.danger ? BSColors.danger : AppTheme.text;
    final fg = sel ? AppTheme.primary : (_hover ? (widget.danger ? BSColors.danger : AppTheme.primary) : base.withOpacity(widget.danger ? 0.9 : 0.78));

    final item = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 50,
            decoration: BoxDecoration(
              color: sel ? BSColors.selected : (_hover ? BSColors.page : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(children: [
              // Barra azul a la izquierda de la opción activa
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 0,
                top: sel ? 8 : 25,
                bottom: sel ? 8 : 25,
                child: Container(width: 4, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4))),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: c ? 0 : 18),
                child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                  AnimatedSlide(
                    offset: Offset(_hover && !sel && !c ? 0.12 : 0, 0),
                    duration: const Duration(milliseconds: 180),
                    child: Icon(widget.icon, color: fg, size: 21),
                  ),
                  if (!c) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.label,
                          style: TextStyle(color: fg, fontSize: 15, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: c ? 14 : 14, vertical: 3),
      child: c ? Tooltip(message: widget.label, preferBelow: false, child: item) : item,
    );
  }
}

/// Punto verde que "late" (red en línea)
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = BSColors.success;
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 8 + 10 * _ctrl.value,
            height: 8 + 10 * _ctrl.value,
            decoration: BoxDecoration(shape: BoxShape.circle, color: green.withOpacity(0.4 * (1 - _ctrl.value))),
          ),
          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: green)),
        ]),
      ),
    );
  }
}

// ── Barra superior: buscador, notificaciones y usuario con fecha y hora ────
class _TopBar extends StatefulWidget {
  final _UserInfo user;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearch;
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowPending;
  const _TopBar({
    required this.user,
    required this.onProfile,
    required this.onSearch,
    required this.pending,
    required this.onShowPending,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final showDetails = w > 980;
    final user = widget.user;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        // Buscador global (abre Documentos con la búsqueda)
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  widget.onSearch(v.trim());
                },
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Buscar documento, categoría o descripción…',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 22),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Buscar',
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.primary),
                          onPressed: () => widget.onSearch(_ctrl.text.trim()),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: BSColors.page,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
        const Spacer(),
        // Notificaciones: documentos pendientes de firma
        _Bell(pending: widget.pending, onShowAll: widget.onShowPending),
        const SizedBox(width: 14),
        Tooltip(
          message: 'Mi perfil',
          child: InkWell(
            onTap: widget.onProfile,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                BSAvatar(name: user.name, url: user.avatarUrl, radius: 21),
                if (showDetails) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: BSLiveClock(
                      builder: (context, now) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name.isEmpty ? 'Mi cuenta' : user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                        Text('${bsSaludo(now)} · ${bsHora(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Campana con punto rojo y menú de documentos pendientes de firma
class _Bell extends StatelessWidget {
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowAll;
  const _Bell({required this.pending, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final n = pending.length;
    return PopupMenuButton<int>(
      tooltip: n == 0 ? 'Sin pendientes' : '$n documento${n == 1 ? '' : 's'} pendiente${n == 1 ? '' : 's'} de firma',
      offset: const Offset(0, 48),
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
      onSelected: (_) => onShowAll(),
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          enabled: false,
          child: Text(n == 0 ? 'Todo al día 🎉' : 'Pendientes de firma ($n)',
              style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
        for (final d in pending.take(5))
          PopupMenuItem<int>(
            value: 1,
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: BSColors.warning, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(d['title']?.toString() ?? 'Documento',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
            ]),
          ),
        if (n > 0)
          const PopupMenuItem<int>(
            value: 1,
            child: Text('Ver todos →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_none_rounded, color: AppTheme.text, size: 22),
          if (n > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: BSColors.danger, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1.5)),
                alignment: Alignment.center,
                child: Text(n > 9 ? '9+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Mobile shell ───────────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final _UserInfo user;
  final Widget content;
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowPending;
  const _MobileShell({
    required this.selectedIndex,
    required this.onNavTap,
    required this.user,
    required this.content,
    required this.pending,
    required this.onShowPending,
  });

  @override
  Widget build(BuildContext context) {
    final first = bsPrimerNombre(user.name);
    return Scaffold(
      backgroundColor: BSColors.page,
      floatingActionButton: SignIaFab(extended: false, onTap: () => showSignIa(context, onNavigate: onNavTap)),
      body: SafeArea(
        child: Column(children: [
          // Encabezado: logo, saludo con hora, campana y usuario
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(children: [
              const _LogoMark(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: BSLiveClock(
                  builder: (context, now) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(first.isEmpty ? bsSaludo(now) : '${bsSaludo(now)}, $first',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                    Text('${bsFechaLarga(now)} · ${bsHora(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                  ]),
                ),
              ),
              _Bell(pending: pending, onShowAll: onShowPending),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onNavTap(3),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: BSAvatar(name: user.name, url: user.avatarUrl, radius: 18),
                ),
              ),
            ]),
          ),
          Expanded(child: _ContentSwitcher(index: selectedIndex, child: content)),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavTap,
          indicatorColor: BSColors.selected,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded, color: AppTheme.primary), label: 'Tablero'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded, color: AppTheme.primary), label: 'Docs'),
            NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primary), label: 'Verificar'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ── Tablero general ────────────────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> recentDocs;
  final bool loading;
  final ValueChanged<int> onNavTap;
  final Future<void> Function() onRefresh;

  const _DashboardContent({required this.stats, required this.recentDocs, required this.loading, required this.onNavTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = ResponsiveLayout.isWeb(context);
    final isWide = width > 1150;
    final pad = isWeb ? 28.0 : 16.0;

    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    final total = n('total');
    final signed = n('signed');
    final verified = n('verified');
    final pending = n('pending');
    final mb = stats['total_size_mb']?.toString() ?? '0';
    String v(int x) => loading ? '–' : '$x';
    final pctSigned = total > 0 ? ((signed + verified) * 100 / total).round() : 0;

    final byStatus = _StatusChartCard(docs: recentDocs, loading: loading);
    final byCategory = _CategoryCard(docs: recentDocs, loading: loading);
    final recent = _RecentTableCard(docs: recentDocs.take(5).toList(), loading: loading, onNavTap: onNavTap);
    final activity = _ActivityCard(docs: recentDocs, loading: loading);

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Tablero'],
              title: 'Tablero general',
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: loading ? null : () => onRefresh()),
                BSPrimaryButton(label: 'Subir documento', icon: Icons.add_rounded, onPressed: () => onNavTap(1)),
              ],
            ),
            const SizedBox(height: 22),
            BSKpiRow(items: [
              BSKpiCard(label: 'Documentos registrados', value: v(total), caption: '$mb MB almacenados', color: AppTheme.primary, icon: Icons.folder_copy_outlined, onTap: () => onNavTap(1)),
              BSKpiCard(label: 'Pendientes de firma', value: v(pending), caption: pending > 0 ? 'Requieren tu firma' : 'Todo al día', color: BSColors.warning, icon: Icons.pending_actions_rounded, onTap: () => onNavTap(1)),
              BSKpiCard(label: 'Firmados en blockchain', value: v(signed), caption: '$pctSigned % del total', color: AppTheme.featureCyan, icon: Icons.draw_outlined, onTap: () => onNavTap(1)),
              BSKpiCard(label: 'Verificados', value: v(verified), caption: 'Integridad comprobada', color: BSColors.success, icon: Icons.verified_outlined, onTap: () => onNavTap(2)),
            ]),
            const SizedBox(height: 20),
            if (isWide) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 10, child: BSEntrance(delay: const Duration(milliseconds: 120), child: byStatus)),
                const SizedBox(width: 20),
                Expanded(flex: 10, child: BSEntrance(delay: const Duration(milliseconds: 180), child: byCategory)),
              ]),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 14, child: BSEntrance(delay: const Duration(milliseconds: 240), child: recent)),
                const SizedBox(width: 20),
                Expanded(flex: 7, child: BSEntrance(delay: const Duration(milliseconds: 300), child: activity)),
              ]),
            ] else ...[
              byStatus,
              const SizedBox(height: 16),
              byCategory,
              const SizedBox(height: 16),
              recent,
              const SizedBox(height: 16),
              activity,
            ],
          ]),
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _LinkText(this.text, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(text, style: const TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );
}

Map<String, dynamic> _metaOf(Map<String, dynamic> d) => Map<String, dynamic>.from((d['metadata'] as Map?) ?? {});
bool _isPdf(Map<String, dynamic> d) => (_metaOf(d)['extension'] ?? 'pdf').toString().toLowerCase() == 'pdf';

/// Estado visible (igual que en Documentos): en blockchain / revocado
String _visibleStatusOf(Map<String, dynamic> d) {
  final status = d['status']?.toString() ?? 'pending';
  if (status != 'pending') return status;
  final m = _metaOf(d);
  if (['sending', 'confirming'].contains(m['blockchain_status'])) return 'chain';
  if (m['revoked'] == true) return 'revoked';
  return status;
}

Widget _loadingBox([double h = 200]) => SizedBox(height: h, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)));

Widget _emptyBox(String text, [double h = 200]) => SizedBox(
      height: h,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_chart_outlined_rounded, color: AppTheme.hint, size: 30),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        ]),
      ),
    );

// ── Barras agrupadas: documentos por estado y tipo ─────────────────────────
class _StatusChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  const _StatusChartCard({required this.docs, required this.loading});

  @override
  Widget build(BuildContext context) {
    const groups = [('pending', 'Pendiente'), ('chain', 'En registro'), ('signed', 'Firmado'), ('verified', 'Verificado')];
    final data = [
      for (final g in groups)
        (
          g.$2,
          docs.where((d) => _visibleStatusOf(d) == g.$1 && _isPdf(d)).length,
          docs.where((d) => _visibleStatusOf(d) == g.$1 && !_isPdf(d)).length,
        ),
    ];
    final maxV = data.fold<int>(1, (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b));

    return BSCard(
      title: 'Documentos por estado y tipo',
      child: loading
          ? _loadingBox(250)
          : docs.isEmpty
              ? _emptyBox('Aún no hay documentos', 250)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    _Legend(color: AppTheme.primary, label: 'PDF'),
                    SizedBox(width: 22),
                    _Legend(color: AppTheme.featureBlue, label: 'Word'),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 210,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final e in data)
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              _VBar(value: e.$2, max: maxV, color: AppTheme.primary, tooltip: '${e.$1} · PDF: ${e.$2}'),
                              const SizedBox(width: 8),
                              _VBar(value: e.$3, max: maxV, color: AppTheme.featureBlue, tooltip: '${e.$1} · Word: ${e.$3}'),
                            ]),
                          ]),
                        ),
                    ]),
                  ),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final e in data)
                      Expanded(
                        child: Text(e.$1, textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.hint, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      ]);
}

/// Barra vertical animada con su valor encima; se resalta al pasar el mouse
class _VBar extends StatefulWidget {
  final int value, max;
  final Color color;
  final String tooltip;
  const _VBar({required this.value, required this.max, required this.color, required this.tooltip});

  @override
  State<_VBar> createState() => _VBarState();
}

class _VBarState extends State<_VBar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const maxH = 170.0;
    final h = widget.value == 0 ? 3.0 : (widget.value / widget.max) * maxH;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.value}', style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: h),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hover ? 38 : 34,
              height: v,
              decoration: BoxDecoration(
                color: _hover ? Color.lerp(widget.color, Colors.black, 0.12) : widget.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Barras horizontales: documentos por categoría ─────────────────────────
class _CategoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  const _CategoryCard({required this.docs, required this.loading});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final d in docs) {
      final m = _metaOf(d);
      final c = (m['ai_category'] ?? m['category'] ?? 'Documento').toString();
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final items = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = items.take(6).toList();
    final maxV = top.isEmpty ? 1 : top.first.value;

    return BSCard(
      title: 'Documentos por categoría',
      child: loading
          ? _loadingBox(250)
          : top.isEmpty
              ? _emptyBox('Sin categorías todavía', 250)
              : Column(children: [
                  for (var i = 0; i < top.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(children: [
                        SizedBox(
                          width: 130,
                          child: Text(top[i].key, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Tooltip(
                            message: '${top[i].key}: ${top[i].value}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(children: [
                                Container(height: 24, color: BSColors.page),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: top[i].value / maxV),
                                  duration: Duration(milliseconds: 700 + i * 80),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, __) => FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: v.clamp(0.02, 1.0),
                                    child: Container(height: 24, color: i == 0 ? AppTheme.primary : AppTheme.primary.withOpacity(0.85 - i * 0.1)),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('${top[i].value}', textAlign: TextAlign.right,
                              style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                ]),
    );
  }
}

// ── Tabla de documentos recientes ─────────────────────────────────────────
class _RecentTableCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  final ValueChanged<int> onNavTap;
  const _RecentTableCard({required this.docs, required this.loading, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 820;
    const head = TextStyle(color: AppTheme.hint, fontSize: 13.5, fontWeight: FontWeight.w700);
    String two(int x) => x.toString().padLeft(2, '0');

    Widget body;
    if (loading) {
      body = _loadingBox(220);
    } else if (docs.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Sin documentos aún', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Sube tu primer PDF o Word para empezar.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 14),
            BSPrimaryButton(label: 'Subir documento', icon: Icons.add_rounded, onPressed: () => onNavTap(1)),
          ]),
        ),
      );
    } else {
      body = Column(children: [
        if (wide)
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Row(children: [
              Expanded(flex: 5, child: Text('Documento', style: head)),
              Expanded(flex: 3, child: Text('Categoría', style: head)),
              Expanded(flex: 2, child: Text('Tamaño', style: head)),
              Expanded(flex: 2, child: Text('Fecha', style: head)),
              Expanded(flex: 3, child: Text('Estado', style: head)),
            ]),
          ),
        const Divider(height: 1, color: AppTheme.border),
        for (final d in docs) ...[
          Material(
            type: MaterialType.transparency,
            child: InkWell(
            onTap: () => onNavTap(1),
            hoverColor: BSColors.selected.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Builder(builder: (_) {
                final m = _metaOf(d);
                final created = DateTime.tryParse(d['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
                final date = '${two(created.day)}/${two(created.month)}/${created.year}';
                final title = Text(d['title']?.toString() ?? 'Sin nombre', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800));
                final cat = (m['ai_category'] ?? m['category'] ?? 'Documento').toString();
                if (!wide) {
                  return Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        title,
                        const SizedBox(height: 3),
                        Text('$cat · $date', style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    BSPill.docStatus(_visibleStatusOf(d)),
                  ]);
                }
                return Row(children: [
                  Expanded(flex: 5, child: title),
                  Expanded(flex: 3, child: Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 14))),
                  Expanded(flex: 2, child: Text('${m['size_mb'] ?? '?'} MB', style: const TextStyle(color: AppTheme.text, fontSize: 14))),
                  Expanded(flex: 2, child: Text(date, style: const TextStyle(color: AppTheme.text, fontSize: 14))),
                  Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: BSPill.docStatus(_visibleStatusOf(d)))),
                ]);
              }),
            ),
          ),
          ),
          const Divider(height: 1, color: AppTheme.border),
        ],
      ]);
    }

    return BSCard(
      title: 'Documentos recientes',
      trailing: _LinkText('Ver todos →', () => onNavTap(1)),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: body,
    );
  }
}

// ── Actividad reciente (eventos sacados de la metadata de los documentos) ──
class _ActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  const _ActivityCard({required this.docs, required this.loading});

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    if (d.inDays < 30) return 'hace ${d.inDays} d';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final events = <(DateTime, String, String, Color)>[];
    for (final d in docs) {
      final m = _metaOf(d);
      final title = d['title']?.toString() ?? 'Documento';
      DateTime? at(String k) => DateTime.tryParse(m[k]?.toString() ?? '')?.toLocal();
      final up = at('uploaded_at') ?? DateTime.tryParse(d['created_at']?.toString() ?? '')?.toLocal();
      if (up != null) events.add((up, 'Documento subido', title, AppTheme.primary));
      final ai = at('ai_analyzed_at');
      if (ai != null) events.add((ai, 'Análisis con IA completado', '$title · ${m['ai_category'] ?? 'Documento'}', AppTheme.primary));
      final aiErr = at('ai_error_at');
      if (aiErr != null && (ai == null || aiErr.isAfter(ai))) events.add((aiErr, 'Análisis con IA falló', title, BSColors.danger));
      final sent = at('blockchain_sent_at');
      if (sent != null && ['sending', 'confirming'].contains(m['blockchain_status'])) {
        events.add((sent, 'Firma enviada a Sepolia', title, BSColors.warning));
      }
      final conf = at('blockchain_confirmed_at') ?? at('signed_at');
      if (conf != null && (d['status'] == 'signed' || d['status'] == 'verified')) {
        events.add((conf, 'Firma registrada en blockchain', m['blockchain_block'] != null ? '$title · bloque #${m['blockchain_block']}' : title, BSColors.success));
      }
      final rev = at('revoked_at');
      if (rev != null) events.add((rev, 'Firma revocada', title, BSColors.danger));
    }
    events.sort((a, b) => b.$1.compareTo(a.$1));
    final top = events.take(6).toList();

    return BSCard(
      title: 'Actividad reciente',
      child: loading
          ? _loadingBox(220)
          : top.isEmpty
              ? _emptyBox('Sin actividad todavía', 220)
              : Column(children: [
                  for (var i = 0; i < top.length; i++)
                    BSEntrance(
                      delay: Duration(milliseconds: 60 * i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(color: top[i].$4, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(top[i].$2, style: const TextStyle(color: AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${top[i].$3} · ${ago(top[i].$1)}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
