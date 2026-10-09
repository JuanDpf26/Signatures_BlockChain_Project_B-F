import 'package:flutter/material.dart';
import '../widgets/brand.dart';
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
import 'audit_screen.dart';
import '../widgets/sign_ia_assistant.dart';
import '../services/collab_service.dart';
import 'inbox_screen.dart';
import 'teams_screen.dart';

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
  int _unread = 0; // mensajes sin leer en la bandeja

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

  Future<void> _refreshInbox() async {
    final s = await CollabService.inboxSummary();
    if (!mounted || s['error'] != null) return;
    final n = int.tryParse('${s['unread'] ?? 0}') ?? 0;
    if (n != _unread) setState(() => _unread = n);
  }

  Future<void> _loadData() async {
    _refreshInbox();
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
    _refreshInbox();
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
      case 4:
        return const AuditScreen();
      case 5:
        return InboxScreen(onChanged: _refreshInbox);
      case 6:
        return const TeamsScreen();
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
            unread: _unread,
          )
        : _MobileShell(
            selectedIndex: _selectedIndex,
            onNavTap: _goTo,
            onLogout: _logout,
            user: user,
            content: _buildContent(),
            pending: _pending,
            onShowPending: _showPending,
            unread: _unread,
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
  final int unread;
  const _WebShell({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.user,
    required this.content,
    required this.onSearch,
    required this.pending,
    required this.onShowPending,
    this.unread = 0,
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
          user: widget.user,
          collapsed: collapsed,
          onToggle: () => setState(() => _userCollapsed = !collapsed),
          pendingCount: widget.pending.length,
          inboxCount: widget.unread,
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

// ── Menú lateral azul institucional ────────────────────────────────────────
// Expandido 268 px / contraído 92 px (ícono con su nombre debajo).
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final _UserInfo user;
  final bool collapsed;
  final VoidCallback onToggle;
  final int pendingCount;
  final int inboxCount;

  const _Sidebar({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.user,
    required this.collapsed,
    required this.onToggle,
    this.pendingCount = 0,
    this.inboxCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = collapsed;
    final w = c ? 92.0 : 268.0;

    Widget section(String text) => c
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            child: Container(height: 1, color: Colors.white.withOpacity(0.14)),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(26, 18, 16, 8),
            child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: w,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
      ),
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          // Círculos decorativos (mismo lenguaje que la pantalla de inicio de sesión)
          Positioned(top: -70, right: -80, child: _Ring(size: 220, opacity: 0.07)),
          Positioned(bottom: 120, left: -90, child: _Ring(size: 200, opacity: 0.05)),
          OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: w,
            maxWidth: w,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── Marca ──
              Padding(
                padding: EdgeInsets.fromLTRB(c ? 0 : 22, 24, c ? 0 : 16, 4),
                child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                  const _LogoMark(size: 46, onBlue: true),
                  if (!c) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const BrandWordmark(fontSize: 22, onDark: true),
                        Text('Firma digital con blockchain',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                ]),
              ),

              // ── Navegación ──
              Expanded(
                child: ListView(padding: const EdgeInsets.only(bottom: 8), children: [
                  section('PRINCIPAL'),
                  _NavItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: 'Tablero', selected: selectedIndex == 0, collapsed: c, onTap: () => onNavTap(0)),
                  _NavItem(
                    icon: Icons.description_outlined,
                    activeIcon: Icons.description_rounded,
                    label: 'Documentos',
                    selected: selectedIndex == 1,
                    collapsed: c,
                    badge: pendingCount,
                    badgeTooltip: '$pendingCount por firmar',
                    onTap: () => onNavTap(1),
                  ),
                  _NavItem(
                    icon: Icons.inbox_outlined,
                    activeIcon: Icons.inbox_rounded,
                    label: 'Bandeja',
                    selected: selectedIndex == 5,
                    collapsed: c,
                    badge: inboxCount,
                    badgeColor: const Color(0xFF7E9FDB),
                    badgeTooltip: '$inboxCount sin leer',
                    onTap: () => onNavTap(5),
                  ),
                  _NavItem(icon: Icons.verified_outlined, activeIcon: Icons.verified_rounded, label: 'Verificar', selected: selectedIndex == 2, collapsed: c, onTap: () => onNavTap(2)),
                  section('COLABORACIÓN'),
                  _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Equipos', selected: selectedIndex == 6, collapsed: c, onTap: () => onNavTap(6)),
                  section('CONTROL'),
                  _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Auditoría', selected: selectedIndex == 4, collapsed: c, onTap: () => onNavTap(4)),
                  _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Mi perfil', selected: selectedIndex == 3, collapsed: c, onTap: () => onNavTap(3)),
                ]),
              ),

              // ── Ambiente / red ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: c ? 16 : 16),
                child: Tooltip(
                  message: c ? 'Red: Sepolia Testnet · Datos de prueba' : '',
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: c ? 0 : 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: c
                        ? const Center(child: _PulseDot())
                        : Row(children: [
                            const _PulseDot(),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Sepolia Testnet', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                                Text('Red de pruebas · v1.0', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5)),
                              ]),
                            ),
                            Icon(Icons.hub_outlined, color: Colors.white.withOpacity(0.55), size: 18),
                          ]),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // ── Usuario con cerrar sesión ──
              _UserCard(user: user, collapsed: c, onProfile: () => onNavTap(3), onLogout: onLogout),

              // ── Contraer / expandir ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Tooltip(
                  message: c ? 'Expandir menú' : '',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: Colors.white.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                        child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                          AnimatedRotation(
                            turns: c ? 0.5 : 0,
                            duration: const Duration(milliseconds: 260),
                            child: Icon(Icons.keyboard_double_arrow_left_rounded, color: Colors.white.withOpacity(0.75), size: 20),
                          ),
                          if (!c) ...[
                            const SizedBox(width: 10),
                            Text('Contraer menú', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Aro decorativo translúcido
class _Ring extends StatelessWidget {
  final double size, opacity;
  const _Ring({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(opacity), width: 28)),
        ),
      );
}

/// Tarjeta del usuario al final del menú: avatar, nombre, correo y salir
class _UserCard extends StatelessWidget {
  final _UserInfo user;
  final bool collapsed;
  final VoidCallback onProfile, onLogout;
  const _UserCard({required this.user, required this.collapsed, required this.onProfile, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final logout = Tooltip(
      message: 'Cerrar sesión',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(10),
          hoverColor: BSColors.danger.withOpacity(0.08),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.logout_rounded, color: BSColors.danger, size: 20),
          ),
        ),
      ),
    );
    return Container(
      margin: EdgeInsets.symmetric(horizontal: collapsed ? 16 : 16),
      padding: EdgeInsets.all(collapsed ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: collapsed
          ? Column(children: [
              Tooltip(
                message: user.name.isEmpty ? 'Mi perfil' : user.name,
                child: InkWell(onTap: onProfile, customBorder: const CircleBorder(), child: BSAvatar(name: user.name, url: user.avatarUrl, radius: 17)),
              ),
              const SizedBox(height: 4),
              logout,
            ])
          : Row(children: [
              InkWell(onTap: onProfile, customBorder: const CircleBorder(), child: BSAvatar(name: user.name, url: user.avatarUrl, radius: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onProfile,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name.isEmpty ? 'Mi cuenta' : user.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    if (user.email.isNotEmpty)
                      Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                  ]),
                ),
              ),
              logout,
            ]),
    );
  }
}

/// Logo de DocBlockSign: el cubo verificado (claro sobre azul u original)
class _LogoMark extends StatelessWidget {
  final double size;
  final bool onBlue;
  const _LogoMark({required this.size, this.onBlue = false});

  @override
  Widget build(BuildContext context) {
    return BrandSymbol(size: size, onDark: onBlue);
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected, collapsed;
  final int badge;
  final String? badgeTooltip;
  final Color badgeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.badge = 0,
    this.badgeTooltip,
    this.badgeColor = BSColors.warning,
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
    final fg = sel ? AppTheme.primary : Colors.white.withOpacity(_hover ? 1 : 0.86);

    Widget icon = Icon(sel ? (widget.activeIcon ?? widget.icon) : widget.icon, color: fg, size: c ? 23 : 21);
    if (widget.badge > 0) {
      icon = Badge(
        label: Text('${widget.badge > 99 ? '99+' : widget.badge}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        backgroundColor: widget.badgeColor,
        textColor: Colors.white,
        offset: const Offset(8, -6),
        child: icon,
      );
    }

    final content = c
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(height: 5),
            Text(widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ])
        : Row(children: [
            AnimatedSlide(
              offset: Offset(_hover && !sel ? 0.12 : 0, 0),
              duration: const Duration(milliseconds: 180),
              child: icon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label, style: TextStyle(color: fg, fontSize: 15, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
            ),
            if (widget.badge > 0)
              Tooltip(
                message: widget.badgeTooltip ?? '',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sel ? widget.badgeColor.withOpacity(0.14) : Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.badge}',
                      style: TextStyle(color: sel ? (widget.badgeColor == BSColors.warning ? BSColors.warning : AppTheme.primary) : Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ),
          ]);

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
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: c ? 64 : 48,
            padding: EdgeInsets.symmetric(horizontal: c ? 4 : 16),
            decoration: BoxDecoration(
              color: sel ? Colors.white : (_hover ? Colors.white.withOpacity(0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 6))] : null,
            ),
            child: content,
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: c ? 12 : 14, vertical: 3),
      child: c ? Tooltip(message: widget.label, preferBelow: false, waitDuration: const Duration(milliseconds: 500), child: item) : item,
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
  final VoidCallback onLogout;
  final _UserInfo user;
  final Widget content;
  final List<Map<String, dynamic>> pending;
  final VoidCallback onShowPending;
  final int unread;
  const _MobileShell({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.user,
    required this.content,
    required this.pending,
    required this.onShowPending,
    this.unread = 0,
  });

  // Orden de la barra inferior → índice de sección
  static const _order = [0, 1, 5, 2, 3];

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
              // Avatar con menú: perfil o cerrar sesión
              PopupMenuButton<int>(
                tooltip: 'Mi cuenta',
                offset: const Offset(0, 46),
                onSelected: (v) => v < 0 ? onLogout() : onNavTap(v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 3, child: Row(children: [Icon(Icons.person_outline_rounded, size: 18), SizedBox(width: 10), Text('Mi perfil')])),
                  PopupMenuItem(value: 6, child: Row(children: [Icon(Icons.groups_outlined, size: 18), SizedBox(width: 10), Text('Equipos')])),
                  PopupMenuItem(value: 4, child: Row(children: [Icon(Icons.receipt_long_outlined, size: 18), SizedBox(width: 10), Text('Auditoría')])),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: -1,
                    child: Row(children: [
                      Icon(Icons.logout_rounded, size: 18, color: BSColors.danger),
                      SizedBox(width: 10),
                      Text('Cerrar sesión', style: TextStyle(color: BSColors.danger)),
                    ]),
                  ),
                ],
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
          // Tablero · Docs · Bandeja · Verificar · Perfil (Equipos y Auditoría están en el menú del avatar)
          selectedIndex: _order.contains(selectedIndex) ? _order.indexOf(selectedIndex) : 4,
          onDestinationSelected: (i) => onNavTap(_order[i]),
          indicatorColor: BSColors.selected,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded, color: AppTheme.primary), label: 'Tablero'),
            const NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded, color: AppTheme.primary), label: 'Docs'),
            NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.inbox_outlined)),
              selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.inbox_rounded, color: AppTheme.primary)),
              label: 'Bandeja',
            ),
            const NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primary), label: 'Verificar'),
            const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary), label: 'Perfil'),
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

  static String hoursLabel(dynamic h) {
    final x = double.tryParse('${h ?? ''}');
    if (x == null) return '—';
    if (x < 1) return '${(x * 60).round()} min';
    if (x < 48) return '${x.toStringAsFixed(1)} h';
    return '${(x / 24).toStringAsFixed(1)} d';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = ResponsiveLayout.isWeb(context);
    final isWide = width > 1150;
    final pad = isWeb ? 28.0 : 16.0;

    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    String v(String x) => loading ? '–' : x;
    final gas = double.tryParse('${stats['gas_eth'] ?? 0}') ?? 0;

    final activity7 = _WeekChartCard(days: ((stats['activity'] as List?) ?? []).whereType<Map>().toList(), loading: loading);
    final statusCard = _StatusMixCard(stats: stats, loading: loading, onNavTap: onNavTap);
    final confCard = _ConfidentialityCard(rows: ((stats['confidentiality'] as List?) ?? []).whereType<Map>().toList(), loading: loading);
    final recent = _RecentTableCard(docs: recentDocs.take(6).toList(), loading: loading, onNavTap: onNavTap);
    final feed = _ActivityCard(docs: recentDocs, loading: loading);

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // En celular deja espacio para el botón flotante de Sign IA
          padding: EdgeInsets.fromLTRB(pad, isWeb ? 24 : 18, pad, isWeb ? 32 : 96),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Tablero'],
              title: 'Tablero general',
              subtitle: 'Cómo va tu actividad de firma, análisis y registro en blockchain.',
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: loading ? null : () => onRefresh()),
                BSPrimaryButton(label: 'Subir documento', icon: Icons.add_rounded, onPressed: () => onNavTap(1)),
              ],
            ),
            const SizedBox(height: 22),
            BSKpiRow(items: [
              BSKpiCard(
                label: 'Firmas este mes',
                value: v('${n('signed_month')}'),
                caption: '${n('signed') + n('verified')} firmas en total',
                color: AppTheme.primary,
                icon: Icons.draw_outlined,
                onTap: () => onNavTap(1),
              ),
              BSKpiCard(
                label: 'Tiempo promedio de firma',
                value: v(hoursLabel(stats['avg_hours_to_sign'])),
                caption: 'Desde la carga hasta el bloque',
                color: BSColors.warning,
                icon: Icons.timer_outlined,
              ),
              BSKpiCard(
                label: 'Analizados con IA',
                value: v('${n('analyzed_pct')} %'),
                caption: n('ai_errors') > 0 ? '${n('ai_errors')} con error' : '${n('analyzed')} de ${n('total')} documentos',
                color: BSColors.success,
                icon: Icons.auto_awesome_outlined,
              ),
              BSKpiCard(
                label: 'Gas consumido',
                value: v(gas == 0 ? '0' : gas.toStringAsFixed(gas < 0.001 ? 6 : 4).replaceAll('.', ',')),
                caption: stats['last_block'] != null ? 'ETH de prueba · último bloque #${stats['last_block']}' : 'ETH de prueba en Sepolia',
                color: AppTheme.featureCyan,
                icon: Icons.local_gas_station_outlined,
              ),
            ]),
            const SizedBox(height: 20),
            // Dos columnas independientes: cada una apila sus tarjetas sin dejar huecos
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 13,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    BSEntrance(delay: const Duration(milliseconds: 120), child: activity7),
                    const SizedBox(height: 20),
                    BSEntrance(delay: const Duration(milliseconds: 220), child: recent),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 7,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    BSEntrance(delay: const Duration(milliseconds: 170), child: statusCard),
                    const SizedBox(height: 20),
                    BSEntrance(delay: const Duration(milliseconds: 260), child: confCard),
                    const SizedBox(height: 20),
                    BSEntrance(delay: const Duration(milliseconds: 320), child: feed),
                  ]),
                ),
              ])
            else if (width >= 760) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: statusCard),
                const SizedBox(width: 16),
                Expanded(child: confCard),
              ]),
              const SizedBox(height: 16),
              activity7,
              const SizedBox(height: 16),
              recent,
              const SizedBox(height: 16),
              feed,
            ] else ...[
              statusCard,
              const SizedBox(height: 16),
              activity7,
              const SizedBox(height: 16),
              recent,
              const SizedBox(height: 16),
              confCard,
              const SizedBox(height: 16),
              feed,
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Actividad de los últimos 7 días (subidos vs firmados) ─────────────────
class _WeekChartCard extends StatelessWidget {
  final List<Map> days;
  final bool loading;
  const _WeekChartCard({required this.days, required this.loading});

  @override
  Widget build(BuildContext context) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final data = [
      for (final d in days)
        (
          () {
            final t = DateTime.tryParse('${d['day']}');
            return t == null ? '' : '${names[t.weekday - 1]} ${t.day}';
          }(),
          int.tryParse('${d['uploaded']}') ?? 0,
          int.tryParse('${d['signed']}') ?? 0,
        ),
    ];
    final maxV = data.fold<int>(1, (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b));
    final totalUp = data.fold<int>(0, (m, e) => m + e.$2);
    final totalSig = data.fold<int>(0, (m, e) => m + e.$3);

    return BSCard(
      title: 'Actividad de los últimos 7 días',
      trailing: Text('$totalUp subidos · $totalSig firmados', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: loading
          ? _loadingBox(250)
          : data.isEmpty
              ? _emptyBox('Sin datos de actividad', 250)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    _Legend(color: AppTheme.primary, label: 'Subidos'),
                    SizedBox(width: 22),
                    _Legend(color: AppTheme.featureBlue, label: 'Firmados'),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 170,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final e in data)
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              _VBar(value: e.$2, max: maxV, color: AppTheme.primary, tooltip: '${e.$1} · subidos: ${e.$2}', width: 18),
                              const SizedBox(width: 4),
                              _VBar(value: e.$3, max: maxV, color: AppTheme.featureBlue, tooltip: '${e.$1} · firmados: ${e.$3}', width: 18),
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
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ]),
    );
  }
}

// ── Estado de tus documentos: barra segmentada + leyenda ──────────────────
class _StatusMixCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading;
  final ValueChanged<int> onNavTap;
  const _StatusMixCard({required this.stats, required this.loading, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    final total = n('total');
    final pend = n('pending') - n('in_chain') - n('revoked');
    final parts = [
      ('Por firmar', pend < 0 ? 0 : pend, BSColors.warning, Icons.edit_document),
      ('En registro', n('in_chain'), AppTheme.featureBlue, Icons.sync_rounded),
      ('Firmados', n('signed'), AppTheme.primary, Icons.draw_rounded),
      ('Verificados', n('verified'), BSColors.success, Icons.verified_rounded),
      ('Revocados', n('revoked'), BSColors.danger, Icons.block_rounded),
    ].where((p) => p.$2 > 0 || (p.$1 != 'En registro' && p.$1 != 'Revocados')).toList();

    return BSCard(
      title: 'Estado de tus documentos',
      trailing: Text('$total en total', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: loading
          ? _loadingBox(200)
          : total == 0
              ? _emptyBox('Aún no hay documentos', 200)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Contadores grandes (como un resumen de entregas)
                  LayoutBuilder(builder: (context, c) {
                    final cols = parts.length <= 3 ? parts.length : (c.maxWidth > 420 ? parts.length.clamp(3, 5) : 2);
                    final w = (c.maxWidth - (cols - 1) * 8) / cols;
                    return Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in parts)
                        SizedBox(
                          width: w,
                          child: _CountTile(label: p.$1, value: p.$2, color: p.$3, icon: p.$4, onTap: () => onNavTap(1)),
                        ),
                    ]);
                  }),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        for (final p in parts)
                          if (p.$2 > 0)
                            Expanded(
                              flex: p.$2,
                              child: Tooltip(
                                message: '${p.$1}: ${p.$2} (${(p.$2 * 100 / total).round()} %)',
                                child: Container(color: p.$3),
                              ),
                            ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.auto_stories_outlined, size: 16, color: AppTheme.hint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${n('pages')} páginas · ${stats['total_size_mb'] ?? 0} MB · ${n('pdfs')} PDF / ${n('words')} Word',
                          style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
                    ),
                  ]),
                ]),
    );
  }
}

/// Contador grande con fondo suave (resumen rápido)
class _CountTile extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _CountTile({required this.label, required this.value, required this.color, required this.icon, this.onTap});

  @override
  State<_CountTile> createState() => _CountTileState();
}

class _CountTileState extends State<_CountTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: c.withOpacity(_hover ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(_hover ? 0.35 : 0.12)),
          ),
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widget.value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, x, __) => Text('${x.round()}',
                  style: TextStyle(color: c, fontSize: 28, fontWeight: FontWeight.w900, height: 1.05)),
            ),
            const SizedBox(height: 4),
            // Se reduce si no cabe, en vez de cortar la palabra
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, size: 13, color: c),
                const SizedBox(width: 4),
                Text(widget.label, maxLines: 1, style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Nivel de confidencialidad (según la IA) ───────────────────────────────
class _ConfidentialityCard extends StatelessWidget {
  final List<Map> rows;
  final bool loading;
  const _ConfidentialityCard({required this.rows, required this.loading});

  static Color colorOf(String level) => switch (level.toLowerCase()) {
        'secreto' => BSColors.danger,
        'confidencial' => BSColors.warning,
        'interno' => AppTheme.primary,
        'público' || 'publico' => BSColors.success,
        _ => BSColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final items = [for (final r in rows) ('${r['level']}', int.tryParse('${r['n']}') ?? 0)];
    final maxV = items.isEmpty ? 1 : items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return BSCard(
      title: 'Nivel de confidencialidad',
      child: loading
          ? _loadingBox(160)
          : items.isEmpty
              ? _emptyBox('Sin documentos analizados', 160)
              : Column(children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        SizedBox(
                          width: 110,
                          child: Text(items[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(children: [
                              Container(height: 18, color: BSColors.page),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: items[i].$2 / maxV),
                                duration: Duration(milliseconds: 700 + i * 90),
                                curve: Curves.easeOutCubic,
                                builder: (_, x, __) => FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: x.clamp(0.03, 1.0),
                                  child: Container(height: 18, color: colorOf(items[i].$1)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('${items[i].$2}', textAlign: TextAlign.right,
                              style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                ]),
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

/// Categoría visible: la editada a mano tiene prioridad sobre la de la IA
String _categoryOf(Map m) {
  final v = (m['category_source'] == 'manual' ? m['category'] : (m['ai_category'] ?? m['category']))?.toString();
  return (v == null || v.trim().isEmpty) ? 'Documento' : v;
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
  final double width;
  const _VBar({required this.value, required this.max, required this.color, required this.tooltip, this.width = 34});

  @override
  State<_VBar> createState() => _VBarState();
}

class _VBarState extends State<_VBar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // La columna mide 170: se reservan ~30 px para el número de arriba
    const maxH = 135.0;
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
              width: _hover ? widget.width + 4 : widget.width,
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

// ── Tabla de documentos recientes ─────────────────────────────────────────
class _RecentTableCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  final ValueChanged<int> onNavTap;
  const _RecentTableCard({required this.docs, required this.loading, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 820;

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
        for (var i = 0; i < docs.length; i++)
          BSEntrance(
            delay: Duration(milliseconds: 50 * i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentRow(doc: docs[i], wide: wide, onTap: () => onNavTap(1)),
            ),
          ),
      ]);
    }

    return BSCard(
      title: 'Documentos recientes',
      trailing: _LinkText('Ver todos →', () => onNavTap(1)),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      child: body,
    );
  }
}

/// Fila de documento: ícono por tipo, nombre, detalle, fecha y estado
class _RecentRow extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool wide;
  final VoidCallback onTap;
  const _RecentRow({required this.doc, required this.wide, required this.onTap});

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final m = _metaOf(d);
    final pdf = _isPdf(d);
    final tint = pdf ? BSColors.danger : AppTheme.primary;
    final created = DateTime.tryParse(d['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    final date = '${two(created.day)}/${two(created.month)}/${created.year}';
    final cat = _categoryOf(m);
    final pages = int.tryParse('${m['pages'] ?? ''}');
    final sub = [cat, if (m['size_mb'] != null) '${m['size_mb']} MB', if (pages != null && pages > 0) '$pages pág.'].join('  ·  ');

    final tileSize = widget.wide ? 52.0 : 44.0;
    final tile = Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(color: tint.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined, color: tint, size: widget.wide ? 26 : 22),
    );

    final dateChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: BSColors.selected, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.event_outlined, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text('$date · ${two(created.hour)}:${two(created.minute)}',
            style: const TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover ? BSColors.page : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? AppTheme.primary.withOpacity(0.25) : AppTheme.border),
          ),
          child: widget.wide ? Row(children: [
            tile,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['title']?.toString() ?? 'Sin nombre',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _hover ? AppTheme.primary : AppTheme.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(sub,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 10),
            dateChip,
            const SizedBox(width: 10),
            SizedBox(
              width: 118,
              child: Align(alignment: Alignment.centerRight, child: BSPill.docStatus(_visibleStatusOf(d))),
            ),
          ])
          // Celular: el nombre usa todo el ancho y el estado va en la segunda línea
          : Row(children: [
            tile,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['title']?.toString() ?? 'Sin nombre',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text('$cat · $date', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  BSPill.docStatus(_visibleStatusOf(d)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
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
      if (ai != null) events.add((ai, 'Análisis con IA completado', '$title · ${_categoryOf(m)}', AppTheme.primary));
      final edited = at('last_edited_at');
      if (edited != null) events.add((edited, 'Documento editado', title, AppTheme.featureCyan));
      final shared = at('last_shared_at');
      if (shared != null) events.add((shared, 'Enviado por correo', title, AppTheme.primary));
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
