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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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
          _recentDocs = List<Map<String, dynamic>>.from(docsRes['documents']).take(5).toList();
        }
      });
    } catch (_) {
      // sin conexión: se muestran los valores vacíos
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTo(int i) {
    final leavingProfile = _selectedIndex == 3 && i != 3;
    setState(() => _selectedIndex = i);
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
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1:
        return const DocumentsScreen();
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
        ? _WebShell(selectedIndex: _selectedIndex, onNavTap: _goTo, onLogout: _logout, user: user, content: _buildContent())
        : _MobileShell(selectedIndex: _selectedIndex, onNavTap: _goTo, user: user, content: _buildContent());
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
  const _WebShell({required this.selectedIndex, required this.onNavTap, required this.onLogout, required this.user, required this.content});

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
      body: Row(children: [
        _Sidebar(
          selectedIndex: widget.selectedIndex,
          onNavTap: widget.onNavTap,
          onLogout: widget.onLogout,
          user: widget.user,
          collapsed: collapsed,
          onToggle: () => setState(() => _userCollapsed = !collapsed),
        ),
        Expanded(
          child: Column(children: [
            _TopBar(user: widget.user, onProfile: () => widget.onNavTap(3)),
            Expanded(child: widget.content),
          ]),
        ),
      ]),
    );
  }
}

// ── Menú lateral (expandido 260 px / contraído 80 px) ──────────────────────
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final _UserInfo user;
  final bool collapsed;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.user,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = collapsed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: c ? 80 : 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(right: BorderSide(color: AppTheme.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(2, 0))],
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: c ? 80 : 260,
          maxWidth: c ? 80 : 260,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Marca
            Container(
              height: 76,
              padding: EdgeInsets.symmetric(horizontal: c ? 0 : 18),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
              child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.featureCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 21),
                ),
                if (!c) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BlockSign', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                      Text('Firma digital con blockchain', style: TextStyle(color: AppTheme.hint, fontSize: 11)),
                    ]),
                  ),
                ],
              ]),
            ),

            // Navegación
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                _SideLabel('PRINCIPAL', collapsed: c),
                _NavItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: 'Dashboard', selected: selectedIndex == 0, collapsed: c, onTap: () => onNavTap(0)),
                _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Documentos', selected: selectedIndex == 1, collapsed: c, onTap: () => onNavTap(1)),
                _NavItem(icon: Icons.verified_outlined, activeIcon: Icons.verified_rounded, label: 'Verificar', selected: selectedIndex == 2, collapsed: c, onTap: () => onNavTap(2)),
                _SideLabel('CUENTA', collapsed: c),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Mi perfil', selected: selectedIndex == 3, collapsed: c, onTap: () => onNavTap(3)),
              ]),
            ),

            // Estado de la red
            Padding(
              padding: EdgeInsets.symmetric(horizontal: c ? 12 : 14),
              child: Tooltip(
                message: c ? 'Red: Sepolia Testnet · v1.0.0' : '',
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: c ? 0 : 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: BSColors.success.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BSColors.success.withOpacity(0.2)),
                  ),
                  child: c
                      ? const Center(child: Icon(Icons.hub_outlined, color: BSColors.success, size: 18))
                      : const Row(children: [
                          Icon(Icons.circle, color: BSColors.success, size: 9),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Sepolia Testnet', style: TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Text('UMB · IS25133 · v1.0.0', style: TextStyle(color: AppTheme.hint, fontSize: 10.5)),
                            ]),
                          ),
                        ]),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Usuario + cerrar sesión
            Container(
              margin: EdgeInsets.symmetric(horizontal: c ? 12 : 14),
              padding: EdgeInsets.all(c ? 6 : 10),
              decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: c
                  ? Column(children: [
                      Tooltip(
                        message: user.name.isEmpty ? 'Mi perfil' : user.name,
                        child: InkWell(
                          onTap: () => onNavTap(3),
                          customBorder: const CircleBorder(),
                          child: BSAvatar(name: user.name, url: user.avatarUrl, radius: 17),
                        ),
                      ),
                      const SizedBox(height: 4),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded, color: BSColors.danger, size: 20),
                      ),
                    ])
                  : Row(children: [
                      InkWell(
                        onTap: () => onNavTap(3),
                        customBorder: const CircleBorder(),
                        child: BSAvatar(name: user.name, url: user.avatarUrl, radius: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(user.name.isEmpty ? 'Mi cuenta' : user.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
                          if (user.email.isNotEmpty)
                            Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded, color: BSColors.danger, size: 20),
                      ),
                    ]),
            ),

            // Contraer / expandir
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Tooltip(
                message: c ? 'Expandir menú' : '',
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                      Icon(c ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded, color: AppTheme.hint, size: 20),
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

class _SideLabel extends StatelessWidget {
  final String text;
  final bool collapsed;
  const _SideLabel(this.text, {required this.collapsed});

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Divider(color: AppTheme.border, height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(text, style: const TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final String? badge;
  final bool selected, collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.text.withOpacity(0.75);
    final item = Material(
      color: selected ? AppTheme.primary.withOpacity(0.09) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppTheme.primary.withOpacity(0.05),
        child: SizedBox(
          height: 46,
          child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            if (!collapsed)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 4,
                height: selected ? 24 : 0,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
              ),
            Icon(selected ? activeIcon : icon, color: color, size: 21),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: BSColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(badge!, style: const TextStyle(color: BSColors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ]),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 12, vertical: 2),
      child: collapsed ? Tooltip(message: label, preferBelow: false, child: item) : item,
    );
  }
}

// ── Barra superior: saludo con nombre, fecha y hora en vivo, usuario ───────
class _TopBar extends StatelessWidget {
  final _UserInfo user;
  final VoidCallback onProfile;
  const _TopBar({required this.user, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final showDetails = MediaQuery.of(context).size.width > 980;
    final first = bsPrimerNombre(user.name);

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        Expanded(
          child: BSLiveClock(
            builder: (context, now) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.isEmpty ? '${bsSaludo(now)} 👋' : '${bsSaludo(now)}, $first 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.schedule_rounded, color: AppTheme.hint, size: 14),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${bsFechaLarga(now)} · ${bsHora(now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.hint, fontSize: 12.5),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        if (showDetails) ...[
          const BSPill(label: 'Sepolia activo', color: BSColors.success),
          const SizedBox(width: 18),
        ],
        Tooltip(
          message: 'Mi perfil',
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                BSAvatar(name: user.name, url: user.avatarUrl, radius: 19),
                if (showDetails) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name.isEmpty ? 'Mi cuenta' : user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      if (user.email.isNotEmpty)
                        Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                    ]),
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

// ── Mobile shell ───────────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final _UserInfo user;
  final Widget content;
  const _MobileShell({required this.selectedIndex, required this.onNavTap, required this.user, required this.content});

  @override
  Widget build(BuildContext context) {
    final first = bsPrimerNombre(user.name);
    return Scaffold(
      backgroundColor: BSColors.page,
      body: SafeArea(
        child: Column(children: [
          // Encabezado con saludo, fecha y hora
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(children: [
              Expanded(
                child: BSLiveClock(
                  builder: (context, now) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(first.isEmpty ? '${bsSaludo(now)} 👋' : '${bsSaludo(now)}, $first 👋',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${bsFechaLarga(now)} · ${bsHora(now)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                  ]),
                ),
              ),
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
          Expanded(child: content),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavTap,
          indicatorColor: AppTheme.primary.withOpacity(0.1),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded, color: AppTheme.primary), label: 'Docs'),
            NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primary), label: 'Verificar'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard ──────────────────────────────────────────────────────────────
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

    final recent = _RecentDocsCard(docs: recentDocs, loading: loading, onNavTap: onNavTap);
    final distribution = _DistributionCard(total: total, pending: pending, signed: signed, verified: verified);
    final quick = _QuickActionsCard(onNavTap: onNavTap);

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Dashboard'],
              title: 'Dashboard',
              subtitle: 'Resumen de tu actividad en BlockSign.',
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: loading ? null : () => onRefresh()),
                BSPrimaryButton(label: 'Subir documento', icon: Icons.upload_file_rounded, onPressed: () => onNavTap(1)),
              ],
            ),
            const SizedBox(height: 20),
            const BSInfoBanner(
              title: 'Blockchain conectado — Ethereum Sepolia Testnet',
              text: 'Cada firma queda registrada de forma inmutable y se puede comprobar en Etherscan.',
              color: BSColors.success,
              icon: Icons.link_rounded,
            ),
            const SizedBox(height: 16),
            BSKpiRow(items: [
              BSKpiCard(label: 'Documentos', value: v(total), caption: '$mb MB usados', color: AppTheme.primary),
              BSKpiCard(label: 'Pendientes de firma', value: v(pending), caption: pending > 0 ? 'Requieren tu firma' : 'Todo al día', color: BSColors.warning),
              BSKpiCard(label: 'Firmados', value: v(signed), caption: 'Registrados en Sepolia', color: AppTheme.featureCyan),
              BSKpiCard(label: 'Verificados', value: v(verified), caption: 'Integridad comprobada', color: BSColors.success),
            ]),
            const SizedBox(height: 16),
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: recent),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: Column(children: [distribution, const SizedBox(height: 16), quick])),
              ])
            else ...[
              recent,
              const SizedBox(height: 16),
              distribution,
              const SizedBox(height: 16),
              quick,
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
          child: Text(text, style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );
}

class _RecentDocsCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final bool loading;
  final ValueChanged<int> onNavTap;
  const _RecentDocsCard({required this.docs, required this.loading, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    } else if (docs.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.inbox_outlined, color: AppTheme.primary, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('Sin documentos aún', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Sube tu primer PDF o Word para empezar.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 16),
            BSPrimaryButton(label: 'Subir documento', icon: Icons.upload_file_rounded, onPressed: () => onNavTap(1)),
          ]),
        ),
      );
    } else {
      final rows = <Widget>[];
      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
        final ext = meta['extension']?.toString() ?? 'pdf';
        final isPdf = ext == 'pdf';
        final status = doc['status']?.toString() ?? 'pending';
        final created = doc['created_at'] != null ? DateTime.parse(doc['created_at']).toLocal() : DateTime.now();
        String two(int x) => x.toString().padLeft(2, '0');
        final dateStr = '${two(created.day)}/${two(created.month)}/${created.year}';

        rows.add(InkWell(
          onTap: () => onNavTap(1),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              BSInitialBox(
                text: ext.toUpperCase(),
                color: isPdf ? BSColors.danger : AppTheme.primary,
                icon: isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doc['title']?.toString() ?? 'Sin nombre', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$dateStr · ${meta['size_mb'] ?? '?'} MB', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 10),
              BSPill.docStatus(status),
            ]),
          ),
        ));
        if (i < docs.length - 1) rows.add(const Divider(height: 1, color: AppTheme.border));
      }
      body = Column(children: rows);
    }

    return BSCard(
      title: 'Documentos recientes',
      trailing: _LinkText('Ver todos →', () => onNavTap(1)),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: body,
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final int total, pending, signed, verified;
  const _DistributionCard({required this.total, required this.pending, required this.signed, required this.verified});

  @override
  Widget build(BuildContext context) {
    return BSCard(
      title: 'Distribución por estado',
      child: Column(children: [
        _Bar(label: 'Pendiente', count: pending, total: total, color: BSColors.warning),
        const SizedBox(height: 14),
        _Bar(label: 'Firmado', count: signed, total: total, color: AppTheme.primary),
        const SizedBox(height: 14),
        _Bar(label: 'Verificado', count: verified, total: total, color: BSColors.success),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _Bar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(children: [
      Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$count · ${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, backgroundColor: BSColors.page, valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
      ),
    ]);
  }
}

class _QuickActionsCard extends StatelessWidget {
  final ValueChanged<int> onNavTap;
  const _QuickActionsCard({required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return BSCard(
      title: 'Acciones rápidas',
      child: Column(children: [
        _ActionTile(icon: Icons.upload_file_outlined, label: 'Subir documento', sub: 'PDF o Word, analizado con IA', color: AppTheme.primary, onTap: () => onNavTap(1)),
        const SizedBox(height: 8),
        _ActionTile(icon: Icons.draw_outlined, label: 'Firmar pendientes', sub: 'Registra la firma en blockchain', color: BSColors.success, onTap: () => onNavTap(1)),
        const SizedBox(height: 8),
        _ActionTile(icon: Icons.verified_outlined, label: 'Verificar firma', sub: 'Comprueba un documento', color: BSColors.warning, onTap: () => onNavTap(2)),
        const SizedBox(height: 8),
        _ActionTile(icon: Icons.person_outline_rounded, label: 'Mi perfil', sub: 'Datos, seguridad y firma', color: const Color(0xFF8B5CF6), onTap: () => onNavTap(3)),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.hint, size: 20),
          ]),
        ),
      ),
    );
  }
}

