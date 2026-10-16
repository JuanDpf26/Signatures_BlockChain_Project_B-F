import 'package:flutter/material.dart';
import 'admin_console.dart';
import '../utils/doc_name.dart';
import '../widgets/skeleton.dart';
import '../services/update_service.dart';
import '../widgets/accessibility_menu.dart';
import '../widgets/notification_center.dart';
import '../widgets/brand.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/proof_ui.dart';
import '../widgets/bs_ui.dart';
import '../screens/document_screen.dart';
import 'profile_screen.dart';
import 'verify_screen.dart';
import 'audit_screen.dart';
import '../widgets/sign_ia_assistant.dart';
import '../services/collab_service.dart';
import '../services/presence_service.dart';
import 'inbox_screen.dart';
import 'teams_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String? verifyHash; // huella que llega desde un enlace de verificación
  const HomeScreen({super.key, this.initialIndex = 0, this.verifyHash});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex = widget.initialIndex;
  String? _docSearch; // búsqueda que viene del buscador de la barra superior
  String? _docStatus; // estado con el que se abre Documentos (campana)
  int _docKey = 0;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentDocs = [];
  bool _loading = true;
  int _unread = 0; // mensajes sin leer en la bandeja
  int _pendingReviews = 0; // solicitudes de revisión sin responder

  // Usuario (para el saludo de la barra superior)
  String _userName = '';
  String _userEmail = '';
  String? _avatarUrl;
  // null mientras se lee la sesión; true = superusuario (consola de administración)
  bool? _admin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
    NotificationBell.navigate = (i) => _goTo(i);
    NotificationBell.openDocument = _searchDocs;
    _start();
  }

  Future<void> _start() async {
    final admin = await AuthService.currentRole() == 'admin';
    if (!mounted) return;
    setState(() => _admin = admin);
    if (admin) return; // la consola carga sus propios datos
    _loadUser();
    _loadData();
    PresenceService.start(section: _sectionName(_selectedIndex), onRevoked: _onRevoked);
  }

  static String _sectionName(int i) => switch (i) {
        1 => 'Documentos',
        2 => 'Verificar',
        3 => 'Mi perfil',
        4 => 'Auditoría',
        5 => 'Bandeja',
        6 => 'Equipos',
        _ => 'Tablero',
      };

  /// Un administrador cerró la sesión o suspendió la cuenta
  Future<void> _onRevoked(String message) async {
    try {
      await AuthService.logout();
    } catch (_) {
      await AuthService.deleteToken();
    }
    resetSignIa();
    if (!mounted) return;
    await SweetAlert.info(context, title: 'Tu sesión se cerró', text: message);
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  void dispose() {
    PresenceService.stop();
    super.dispose();
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
      // Sesión antigua de un superusuario (token sin rol): pasa a la consola
      if (u['role'] == 'admin' && _admin != true) setState(() => _admin = true);
    } catch (_) {
      // Si el backend no responde, la barra muestra el saludo sin nombre
    }
  }

  Future<void> _refreshInbox() async {
    final s = await CollabService.inboxSummary();
    if (!mounted || s['error'] != null) return;
    final n = int.tryParse('${s['unread'] ?? 0}') ?? 0;
    final r = int.tryParse('${s['pending_reviews'] ?? 0}') ?? 0;
    if (n != _unread || r != _pendingReviews) {
      setState(() {
        _unread = n;
        _pendingReviews = r;
      });
    }
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
    PresenceService.section('Documentos');
  }

  void _showPending() => _openDocs('pending');

  /// Abre Documentos con un filtro de estado (null = todos)
  void _openDocs(String? status) {
    setState(() {
      _docSearch = null;
      _docStatus = status;
      _docKey++;
      _selectedIndex = 1;
    });
    PresenceService.section('Documentos');
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
    PresenceService.section(_sectionName(i));
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
      PresenceService.stop();
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
        return VerifyScreen(initialHash: widget.verifyHash);
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
          pendingDocs: _pending,
          loading: _loading,
          unread: _unread,
          pendingReviews: _pendingReviews,
          userName: _userName,
          onNavTap: _goTo,
          onOpenDocs: _openDocs,
          onOpenDoc: _searchDocs,
          onRefresh: _loadData,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_admin == null) return Scaffold(backgroundColor: BSColors.page);
    if (_admin == true) return AdminConsole(onLogout: _logout, onRevoked: _onRevoked);
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
            Expanded(child: SignIaFab.scrollAware(_ContentSwitcher(index: widget.selectedIndex, child: widget.content))),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // En modo oscuro, azul noche para no encandilar
          colors: AppTheme.isDark ? const [Color(0xFF13203A), Color(0xFF0D1117)] : [AppTheme.primary, AppTheme.primaryDark],
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
                        const BrandWordmark(fontSize: 24, onDark: true),
                        Text('Firma digital con blockchain',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
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
                            Text('Contraer menú', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w600)),
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
        color: AppTheme.card,
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
                        style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
                    if (user.email.isNotEmpty)
                      Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
              child: Text(widget.label, style: TextStyle(color: fg, fontSize: 16, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
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
                      style: TextStyle(color: sel ? (widget.badgeColor == BSColors.warning ? BSColors.warning : AppTheme.primary) : Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
          ]);

    final item = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: BSFocusable(onTap: widget.onTap, child: GestureDetector(
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
              color: sel ? AppTheme.card : (_hover ? Colors.white.withOpacity(0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 6))] : null,
            ),
            child: content,
          ),
        ),
      )),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: c ? 12 : 14, vertical: 3),
      child: c ? Tooltip(message: widget.label, preferBelow: false, waitDuration: const Duration(milliseconds: 500), child: item) : item,
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
      decoration: BoxDecoration(
        color: AppTheme.card,
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
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar documento, categoría o descripción…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.hint, size: 22),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Buscar',
                          icon: Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.primary),
                          onPressed: () => widget.onSearch(_ctrl.text.trim()),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: BSColors.page,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
        const Spacer(),
        const AccessibilityButton(),
        const SizedBox(width: 6),
        // Notificaciones: documentos pendientes de firma
        NotificationBell(pending: widget.pending, onShowPending: widget.onShowPending),
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
                            style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                        Text('${bsSaludo(now)} · ${bsHora(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
  static const _order = [0, 1, 5, 2]; // el quinto botón es "Más"

  /// Hoja con el resto de secciones: así Equipos y Auditoría no quedan escondidos en el avatar
  void _showMore(BuildContext context) {
    Widget item(BuildContext ctx, IconData icon, String title, String sub, VoidCallback onTap, {Color? color, bool selected = false}) => ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (color ?? AppTheme.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color ?? AppTheme.primary, size: 22),
          ),
          title: Text(title, style: TextStyle(color: color ?? AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: sub.isEmpty ? null : Text(sub, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          trailing: selected ? Icon(Icons.check_rounded, color: AppTheme.primary) : null,
          selected: selected,
          selectedTileColor: AppTheme.primary.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () {
            Navigator.of(ctx).pop();
            onTap();
          },
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Más opciones', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            item(ctx, Icons.groups_rounded, 'Equipos', 'Comparte documentos con tu grupo', () => onNavTap(6), selected: selectedIndex == 6),
            item(ctx, Icons.receipt_long_rounded, 'Auditoría', 'Historial de acciones de tu cuenta', () => onNavTap(4), selected: selectedIndex == 4),
            item(ctx, Icons.manage_accounts_rounded, 'Configuración de la cuenta', 'Perfil, seguridad y firma', () => onNavTap(3), selected: selectedIndex == 3),
            item(ctx, Icons.accessibility_new_rounded, 'Apariencia y accesibilidad', 'Tema, tamaño de letra y movimiento', () => showAccessibilityMenu(context)),
            Divider(height: 16, color: AppTheme.border),
            item(ctx, Icons.logout_rounded, 'Cerrar sesión', '', onLogout, color: BSColors.danger),
          ]),
        ),
      ),
    );
  }

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
            decoration: BoxDecoration(color: AppTheme.card, border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(children: [
              const _LogoMark(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: BSLiveClock(
                  builder: (context, now) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(first.isEmpty ? bsSaludo(now) : '${bsSaludo(now)}, $first',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${bsFechaLarga(now)} · ${bsHora(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ]),
                ),
              ),
              const AccessibilityButton(),
              NotificationBell(pending: pending, onShowPending: onShowPending),
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
          Expanded(child: SignIaFab.scrollAware(_ContentSwitcher(index: selectedIndex, child: content))),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.card,
          surfaceTintColor: Colors.transparent,
          // Tablero · Docs · Bandeja · Verificar · Más (Equipos, Auditoría, Configuración…)
          selectedIndex: _order.contains(selectedIndex) ? _order.indexOf(selectedIndex) : 4,
          onDestinationSelected: (i) => i < _order.length ? onNavTap(_order[i]) : _showMore(context),
          indicatorColor: BSColors.selected,
          destinations: [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded, color: AppTheme.primary), label: 'Tablero'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded, color: AppTheme.primary), label: 'Docs'),
            NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.inbox_outlined)),
              selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: Icon(Icons.inbox_rounded, color: AppTheme.primary)),
              label: 'Bandeja',
            ),
            NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primary), label: 'Verificar'),
            NavigationDestination(icon: const Icon(Icons.menu_rounded), selectedIcon: Icon(Icons.menu_open_rounded, color: AppTheme.primary), label: 'Más', tooltip: 'Más opciones'),
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
  final List<Map<String, dynamic>> pendingDocs;
  final bool loading;
  final int unread, pendingReviews;
  final String userName;
  final ValueChanged<int> onNavTap;
  final ValueChanged<String?> onOpenDocs; // abre Documentos filtrado por estado
  final ValueChanged<String> onOpenDoc; // abre Documentos buscando ese documento
  final Future<void> Function() onRefresh;

  const _DashboardContent({
    required this.stats,
    required this.recentDocs,
    required this.pendingDocs,
    required this.loading,
    required this.unread,
    required this.pendingReviews,
    required this.userName,
    required this.onNavTap,
    required this.onOpenDocs,
    required this.onOpenDoc,
    required this.onRefresh,
  });

  static String hoursLabel(dynamic h) {
    final x = double.tryParse('${h ?? ''}');
    if (x == null) return '—';
    if (x < 1) return '${(x * 60).round()} min';
    if (x < 48) return '${x.toStringAsFixed(1).replaceAll('.', ',')} h';
    return '${(x / 24).toStringAsFixed(1).replaceAll('.', ',')} d';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = ResponsiveLayout.isWeb(context);
    final isWide = width > 1150;
    final pad = isWeb ? 28.0 : 16.0;

    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    String v(String x) => loading ? '–' : x;

    final hero = _HeroCard(
      stats: stats,
      loading: loading,
      pendingReviews: pendingReviews,
      unread: unread,
      userName: userName,
      showGreeting: isWeb,
      onOpenDocs: onOpenDocs,
      onRefresh: onRefresh,
    );
    final todo = _TodoCard(
      loading: loading,
      pendingDocs: pendingDocs,
      pendingCount: (n('pending') - n('in_chain') - n('revoked')).clamp(0, 1 << 30),
      inChain: n('in_chain'),
      pendingReviews: pendingReviews,
      unread: unread,
      onOpenDocs: onOpenDocs,
      onOpenDoc: onOpenDoc,
      onNavTap: onNavTap,
    );
    final quick = _QuickLinks(onNavTap: onNavTap, unread: unread, wide: width >= 760);
    final kpis = BSKpiRow(items: [
      BSKpiCard(
        label: 'Firmas este mes',
        value: v('${n('signed_month')}'),
        caption: '${n('signed') + n('verified')} firmas en total',
        color: AppTheme.primary,
        icon: Icons.draw_outlined,
        onTap: () => onOpenDocs('signed'),
      ),
      BSKpiCard(
        label: 'Tiempo promedio de firma',
        value: v(hoursLabel(stats['avg_hours_to_sign'])),
        caption: 'De la carga al registro en blockchain',
        color: BSColors.warning,
        icon: Icons.timer_outlined,
      ),
      BSKpiCard(
        label: 'Documentos analizados',
        value: v('${n('analyzed_pct')} %'),
        caption: n('ai_errors') > 0 ? '${n('ai_errors')} con error' : '${n('analyzed')} de ${n('total')} documentos',
        color: BSColors.success,
        icon: Icons.insights_outlined,
      ),
      BSKpiCard(
        label: 'Mensajes sin leer',
        value: v('$unread'),
        caption: unread == 0 ? 'Bandeja al día' : 'En tu bandeja de entrada',
        color: AppTheme.featureCyan,
        icon: Icons.mark_email_unread_outlined,
        onTap: () => onNavTap(5),
      ),
    ]);

    final activity7 = _WeekChartCard(days: ((stats['activity'] as List?) ?? []).whereType<Map>().toList(), loading: loading);
    final statusCard = _StatusMixCard(stats: stats, loading: loading, onOpenDocs: onOpenDocs);
    final confCard = _ConfidentialityCard(rows: ((stats['confidentiality'] as List?) ?? []).whereType<Map>().toList(), loading: loading);
    final recent = _RecentTableCard(docs: recentDocs.take(6).toList(), loading: loading, onNavTap: onNavTap, onOpenDoc: onOpenDoc);
    final feed = _ActivityCard(docs: recentDocs, loading: loading);
    const gap = SizedBox(height: 20);

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // En celular deja espacio para el botón flotante de Sign IA
          padding: EdgeInsets.fromLTRB(pad, isWeb ? 24 : 16, pad, isWeb ? 32 : 96),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSEntrance(child: hero),
            gap,
            if (isWide) ...[
              BSEntrance(delay: const Duration(milliseconds: 60), child: kpis),
              gap,
            ],
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 13,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    BSEntrance(delay: const Duration(milliseconds: 80), child: todo),
                    gap,
                    BSEntrance(delay: const Duration(milliseconds: 200), child: activity7),
                    gap,
                    BSEntrance(delay: const Duration(milliseconds: 260), child: recent),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 7,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    BSEntrance(delay: const Duration(milliseconds: 110), child: quick),
                    gap,
                    BSEntrance(delay: const Duration(milliseconds: 170), child: statusCard),
                    gap,
                    BSEntrance(delay: const Duration(milliseconds: 230), child: confCard),
                    gap,
                    BSEntrance(delay: const Duration(milliseconds: 290), child: feed),
                  ]),
                ),
              ])
            else if (width >= 760) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: todo),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: quick),
              ]),
              gap,
              kpis,
              gap,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: statusCard),
                const SizedBox(width: 16),
                Expanded(child: confCard),
              ]),
              gap,
              activity7,
              gap,
              recent,
              gap,
              feed,
            ] else ...[
              todo,
              const SizedBox(height: 16),
              quick,
              const SizedBox(height: 16),
              kpis,
              const SizedBox(height: 16),
              statusCard,
              const SizedBox(height: 16),
              recent,
              const SizedBox(height: 16),
              activity7,
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

// ── Encabezado destacado: saludo, resumen en una frase y el flujo del documento ──
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading, showGreeting;
  final int pendingReviews, unread;
  final String userName;
  final ValueChanged<String?> onOpenDocs;
  final Future<void> Function() onRefresh;
  const _HeroCard({
    required this.stats,
    required this.loading,
    required this.pendingReviews,
    required this.unread,
    required this.userName,
    required this.showGreeting,
    required this.onOpenDocs,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    final total = n('total');
    final porFirmar = (n('pending') - n('in_chain') - n('revoked')).clamp(0, 1 << 30);
    final firmados = n('signed') + n('verified');
    final pct = total == 0 ? 0.0 : firmados / total;
    final narrow = MediaQuery.of(context).size.width < 700;

    String plural(int x, String uno, String varios) => '$x ${x == 1 ? uno : varios}';
    final tareas = [
      if (porFirmar > 0) plural(porFirmar, 'documento por firmar', 'documentos por firmar'),
      if (pendingReviews > 0) plural(pendingReviews, 'revisión esperando tu respuesta', 'revisiones esperando tu respuesta'),
    ];
    final resumen = loading
        ? 'Cargando tu resumen…'
        : total == 0
            ? 'Aún no tienes documentos. Ve a Documentos para subir el primero y empezar el flujo.'
            : tareas.isEmpty
                ? 'Estás al día: no tienes firmas ni revisiones pendientes.'
                : 'Tienes ${tareas.join(' y ')}.';

    final first = bsPrimerNombre(userName);
    final steps = [
      ('Subidos', total, Icons.upload_file_rounded, null as String?, 'Subidos'),
      ('Analizados', n('analyzed'), Icons.manage_search_rounded, null, 'Analizados'),
      ('Firmados en blockchain', firmados, Icons.draw_rounded, 'signed', 'Firmados'),
      ('Verificados', n('verified'), Icons.verified_rounded, 'verified', 'Verificados'),
    ];

    final ring = SizedBox(
      width: narrow ? 74 : 104,
      height: narrow ? 74 : 104,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: loading ? 0 : pct),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, x, __) => Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: x,
              strokeWidth: narrow ? 7 : 9,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(x * 100).round()} %', style: TextStyle(color: Colors.white, fontSize: narrow ? 17 : 22, fontWeight: FontWeight.w900)),
            Text('firmado', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: narrow ? 10.5 : 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B45B5), Color(0xFF08368F), Color(0xFF062A6E)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        // Círculos decorativos
        Positioned(right: -60, top: -70, child: _HeroRing(size: 220)),
        Positioned(right: 120, bottom: -90, child: _HeroRing(size: 160)),
        Padding(
          padding: EdgeInsets.all(narrow ? 18 : 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    showGreeting ? (first.isEmpty ? '${bsSaludo(DateTime.now())}' : '${bsSaludo(DateTime.now())}, $first') : 'Tu resumen de hoy',
                    style: TextStyle(color: Colors.white, fontSize: narrow ? 20 : 26, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  Text(resumen, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: narrow ? 13.5 : 15, height: 1.45)),
                  if (!narrow) ...[
                    const SizedBox(height: 14),
                    _HeroButton(label: 'Actualizar', icon: Icons.refresh_rounded, onTap: loading ? null : () => onRefresh()),
                  ],
                ]),
              ),
              const SizedBox(width: 16),
              ring,
            ]),
            SizedBox(height: narrow ? 16 : 22),
            Text('EL RECORRIDO DE TUS DOCUMENTOS',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 520 ? 2 : 4;
              final w = (c.maxWidth - (cols - 1) * (cols == 4 ? 26 : 10)) / cols;
              return Wrap(
                spacing: cols == 4 ? 0 : 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    SizedBox(
                      width: w,
                      child: _HeroStep(
                        n: i + 1,
                        label: cols == 4 ? steps[i].$1 : steps[i].$5,
                        value: loading ? null : steps[i].$2,
                        icon: steps[i].$3,
                        onTap: () => onOpenDocs(steps[i].$4),
                      ),
                    ),
                    if (cols == 4 && i < steps.length - 1)
                      SizedBox(width: 26, child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.55))),
                  ],
                ],
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _HeroRing extends StatelessWidget {
  final double size;
  const _HeroRing({required this.size});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.08), width: 26)),
        ),
      );
}

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _HeroButton({required this.label, required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => BSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _HeroStep extends StatelessWidget {
  final int n;
  final String label;
  final int? value;
  final IconData icon;
  final VoidCallback onTap;
  const _HeroStep({required this.n, required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ver en Documentos',
      child: BSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.11),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: AppTheme.primary, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (value ?? 0).toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, x, __) => Text(value == null ? '–' : '${x.round()}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                ),
                Text('$n. $label', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Pendientes para ti: lo que necesita una acción ────────────────────────
class _TodoCard extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> pendingDocs;
  final int pendingCount, inChain, pendingReviews, unread;
  final ValueChanged<String?> onOpenDocs;
  final ValueChanged<String> onOpenDoc;
  final ValueChanged<int> onNavTap;
  const _TodoCard({
    required this.loading,
    required this.pendingDocs,
    required this.pendingCount,
    required this.inChain,
    required this.pendingReviews,
    required this.unread,
    required this.onOpenDocs,
    required this.onOpenDoc,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (pendingReviews > 0) {
      items.add(_TodoItem(
        icon: Icons.fact_check_outlined,
        color: BSColors.warning,
        title: pendingReviews == 1 ? 'Te pidieron revisar un documento' : 'Te pidieron revisar $pendingReviews documentos',
        subtitle: 'Apruébalo o recházalo desde la bandeja',
        action: 'Revisar',
        onTap: () => onNavTap(5),
      ));
    }
    for (final d in pendingDocs.take(3)) {
      final m = _metaOf(d);
      items.add(_TodoItem(
        icon: _isPdf(d) ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
        color: _isPdf(d) ? BSColors.danger : AppTheme.primary,
        title: docDisplayName(d['title']?.toString()),
        subtitle: 'Por firmar · ${_categoryOf(m)}',
        action: 'Firmar',
        onTap: () => onOpenDoc(d['title']?.toString() ?? ''),
      ));
    }
    if (pendingCount > 3) {
      items.add(_TodoItem(
        icon: Icons.more_horiz_rounded,
        color: BSColors.neutral,
        title: pendingCount - 3 == 1 ? 'Y 1 documento más por firmar' : 'Y ${pendingCount - 3} documentos más por firmar',
        subtitle: 'Míralos todos en Documentos',
        action: 'Ver',
        onTap: () => onOpenDocs('pending'),
      ));
    }
    if (inChain > 0) {
      items.add(_TodoItem(
        icon: Icons.sync_rounded,
        color: AppTheme.featureBlue,
        title: inChain == 1 ? '1 firma registrándose en blockchain' : '$inChain firmas registrándose en blockchain',
        subtitle: 'No tienes que hacer nada: se confirma sola en unos segundos',
        onTap: () => onOpenDocs(null),
      ));
    }
    if (unread > 0) {
      items.add(_TodoItem(
        icon: Icons.mark_email_unread_outlined,
        color: AppTheme.featureCyan,
        title: unread == 1 ? '1 mensaje sin leer' : '$unread mensajes sin leer',
        subtitle: 'Documentos que te compartieron',
        action: 'Abrir',
        onTap: () => onNavTap(5),
      ));
    }

    final total = pendingCount + pendingReviews;
    return BSCard(
      title: 'Pendientes para ti',
      trailing: total > 0 ? BSPill(label: '$total por atender', color: BSColors.warning) : null,
      child: loading
          ? _loadingBox(160)
          : items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: BSColors.success.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.task_alt_rounded, color: BSColors.success),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('¡Todo al día!', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('No tienes firmas, revisiones ni mensajes pendientes.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                      ]),
                    ),
                  ]),
                )
              : Column(children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppTheme.border),
                    items[i],
                  ],
                ]),
    );
  }
}

class _TodoItem extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final String? action;
  final VoidCallback onTap;
  const _TodoItem({required this.icon, required this.color, required this.title, required this.subtitle, this.action, required this.onTap});

  @override
  State<_TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<_TodoItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: BSFocusable(onTap: widget.onTap, child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(color: _hover ? BSColors.page : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, color: c, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 2),
                Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 10),
            if (widget.action != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _hover ? AppTheme.primary : AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(widget.action!,
                    style: TextStyle(color: _hover ? Colors.white : AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w800)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppTheme.hint),
          ]),
        ),
      )),
    );
  }
}

// ── Accesos rápidos ───────────────────────────────────────────────────────
class _QuickLinks extends StatelessWidget {
  final ValueChanged<int> onNavTap;
  final int unread;
  final bool wide;
  const _QuickLinks({required this.onNavTap, required this.unread, required this.wide});

  @override
  Widget build(BuildContext context) {
    final links = [
      (5, 'Bandeja', 'Lo que te compartieron', Icons.inbox_rounded, AppTheme.primary, unread),
      (2, 'Verificar', 'Comprueba un documento', Icons.verified_rounded, BSColors.success, 0),
      (6, 'Equipos', 'Comparte con tu grupo', Icons.groups_rounded, const Color(0xFF8E24AA), 0),
      (4, 'Auditoría', 'Historial de acciones', Icons.receipt_long_rounded, BSColors.warning, 0),
    ];
    return BSCard(
      title: 'Accesos rápidos',
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final l in links)
            SizedBox(
              width: w,
              child: BSPressable(
                onTap: () => onNavTap(l.$1),
                glowColor: l.$5,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: l.$5.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: l.$5.withOpacity(0.16)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: l.$5, borderRadius: BorderRadius.circular(10)),
                        child: Icon(l.$4, color: Colors.white, size: 19),
                      ),
                      const Spacer(),
                      if (l.$6 > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: BSColors.danger, borderRadius: BorderRadius.circular(10)),
                          child: Text('${l.$6}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Text(l.$2, style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(l.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ]),
                ),
              ),
            ),
        ]);
      }),
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
      trailing: Text('$totalUp subidos · $totalSig firmados', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
      child: loading
          ? _loadingBox(250)
          : data.isEmpty
              ? _emptyBox('Sin datos de actividad', 250)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
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
                            style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
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
  final ValueChanged<String?> onOpenDocs;
  const _StatusMixCard({required this.stats, required this.loading, required this.onOpenDocs});

  @override
  Widget build(BuildContext context) {
    int n(String k) => int.tryParse(stats[k]?.toString() ?? '0') ?? 0;
    final total = n('total');
    final pend = n('pending') - n('in_chain') - n('revoked');
    final parts = [
      ('Por firmar', pend < 0 ? 0 : pend, BSColors.warning, Icons.edit_document, 'pending'),
      ('En registro', n('in_chain'), AppTheme.featureBlue, Icons.sync_rounded, null),
      ('Firmados', n('signed'), AppTheme.primary, Icons.draw_rounded, 'signed'),
      ('Verificados', n('verified'), BSColors.success, Icons.verified_rounded, 'verified'),
      ('Revocados', n('revoked'), BSColors.danger, Icons.block_rounded, null),
    ].where((p) => p.$2 > 0 || (p.$1 != 'En registro' && p.$1 != 'Revocados')).toList();

    return BSCard(
      title: 'Estado de tus documentos',
      trailing: Text('$total en total', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
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
                          child: _CountTile(label: p.$1, value: p.$2, color: p.$3, icon: p.$4, onTap: () => onOpenDocs(p.$5)),
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
                    Icon(Icons.auto_stories_outlined, size: 16, color: AppTheme.hint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${n('pages')} páginas · ${'${stats['total_size_mb'] ?? 0}'.replaceAll('.', ',')} MB · ${n('pdfs')} PDF / ${n('words')} Word',
                          style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
      child: BSFocusable(onTap: widget.onTap, child: GestureDetector(
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
                Text(widget.label, maxLines: 1, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      )),
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
                              style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
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
                              style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
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
          child: Text(text, style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w700)),
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

Widget _loadingBox([double h = 200]) => SkeletonBlock(height: h);

Widget _emptyBox(String text, [double h = 200]) => SizedBox(
      height: h,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_chart_outlined_rounded, color: AppTheme.hint, size: 30),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
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
        Text(label, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
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
          Text('${widget.value}', style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w800)),
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
  final ValueChanged<String> onOpenDoc;
  const _RecentTableCard({required this.docs, required this.loading, required this.onNavTap, required this.onOpenDoc});

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
            Text('Sin documentos aún', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Sube tu primer PDF o Word desde la sección Documentos.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 14),
            BSOutlineButton(label: 'Ir a Documentos', icon: Icons.arrow_forward_rounded, onPressed: () => onNavTap(1)),
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
              child: _RecentRow(doc: docs[i], wide: wide, onTap: () => onOpenDoc(docs[i]['title']?.toString() ?? '')),
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
    final sub = [cat, if (m['size_mb'] != null || m['size_bytes'] != null) fmtTamano(m), if (pages != null && pages > 0) '$pages pág.'].join('  ·  ');

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
        Icon(Icons.event_outlined, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text('$date · ${two(created.hour)}:${two(created.minute)}',
            style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: BSFocusable(onTap: widget.onTap, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover ? BSColors.page : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? AppTheme.primary.withOpacity(0.25) : AppTheme.border),
          ),
          child: widget.wide ? Row(children: [
            tile,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(docDisplayName(d['title']?.toString()),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _hover ? AppTheme.primary : AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(sub,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
                Text(docDisplayName(d['title']?.toString()),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text('$cat · $date', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  BSPill.docStatus(_visibleStatusOf(d)),
                ]),
              ]),
            ),
          ]),
        ),
      )),
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
      final title = docDisplayName(d['title']?.toString());
      DateTime? at(String k) => DateTime.tryParse(m[k]?.toString() ?? '')?.toLocal();
      final up = at('uploaded_at') ?? DateTime.tryParse(d['created_at']?.toString() ?? '')?.toLocal();
      if (up != null) events.add((up, 'Documento subido', title, AppTheme.primary));
      final ai = at('ai_analyzed_at');
      if (ai != null) events.add((ai, 'Análisis completado', '$title · ${_categoryOf(m)}', AppTheme.primary));
      final edited = at('last_edited_at');
      if (edited != null) events.add((edited, 'Documento editado', title, AppTheme.featureCyan));
      final shared = at('last_shared_at');
      if (shared != null) events.add((shared, 'Enviado por correo', title, AppTheme.primary));
      final aiErr = at('ai_error_at');
      if (aiErr != null && (ai == null || aiErr.isAfter(ai))) events.add((aiErr, 'El análisis falló', title, BSColors.danger));
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
                              Text(top[i].$2, style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${top[i].$3} · ${ago(top[i].$1)}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
