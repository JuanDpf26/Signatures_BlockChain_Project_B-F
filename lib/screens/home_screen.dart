import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';
import '../screens/document_screen.dart';
import 'profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final statsRes = await DocumentService.getStats();
    final docsRes = await DocumentService.getDocuments(page: 1);
    if (!mounted) return;
    setState(() {
      if (!statsRes.containsKey('error')) _stats = statsRes;
      if (docsRes.containsKey('documents')) {
        _recentDocs = List<Map<String, dynamic>>.from(docsRes['documents']).take(6).toList();
      }
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('¿Deseas cerrar sesión?', style: TextStyle(color: AppTheme.hint, fontSize: 14)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _go(int i) => setState(() => _selectedIndex = i);

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1: return const DocumentsScreen();
      case 2: return const _PlaceholderContent(icon: Icons.verified_outlined, title: 'Verificar firma', subtitle: 'Comprueba la autenticidad de documentos firmados en blockchain.');
      case 3: return const ProfileScreen();
      default: return _DashboardContent(stats: _stats, recentDocs: _recentDocs, loading: _loading, onNavTap: _go, onRefresh: _loadData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);
    return isWeb
        ? _WebShell(selectedIndex: _selectedIndex, onNavTap: _go, onLogout: _logout, content: _buildContent())
        : _MobileShell(selectedIndex: _selectedIndex, onNavTap: _go, content: _buildContent());
  }
}

// ── Web shell: rail lateral compacto ───────────────────────────────────────
class _WebShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final Widget content;
  const _WebShell({required this.selectedIndex, required this.onNavTap, required this.onLogout, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(children: [
        Container(
          width: 84,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(right: BorderSide(color: AppTheme.border)),
          ),
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 22),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 20),
              // Acción principal: subir / crear documento
              Tooltip(
                message: 'Nuevo documento',
                child: InkWell(
                  onTap: () => onNavTap(1),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppTheme.card, shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
                    child: const Icon(Icons.add_rounded, color: AppTheme.text, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _RailItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Dashboard', selected: selectedIndex == 0, onTap: () => onNavTap(0)),
              _RailItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Documentos', selected: selectedIndex == 1, onTap: () => onNavTap(1)),
              _RailItem(icon: Icons.verified_outlined, activeIcon: Icons.verified_rounded, label: 'Verificar', selected: selectedIndex == 2, onTap: () => onNavTap(2)),
              _RailItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil', selected: selectedIndex == 3, onTap: () => onNavTap(3)),
              const Spacer(),
              _RailItem(icon: Icons.logout_rounded, activeIcon: Icons.logout_rounded, label: 'Cerrar sesión', selected: false, onTap: onLogout, color: AppTheme.error),
              const SizedBox(height: 16),
            ]),
          ),
        ),
        Expanded(child: content),
      ]),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _RailItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (selected ? AppTheme.primary : AppTheme.hint);
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: selected ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 48, height: 48,
              child: Icon(selected ? activeIcon : icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile shell ───────────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final Widget content;
  const _MobileShell({required this.selectedIndex, required this.onNavTap, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(child: content),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavTap,
          height: 68,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.primary), label: 'Inicio'),
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
  final VoidCallback onRefresh;

  const _DashboardContent({required this.stats, required this.recentDocs, required this.loading, required this.onNavTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);
    final pad = isWeb ? 28.0 : 16.0;
    final total = int.tryParse(stats['total']?.toString() ?? '0') ?? 0;
    final signed = int.tryParse(stats['signed']?.toString() ?? '0') ?? 0;
    final verified = int.tryParse(stats['verified']?.toString() ?? '0') ?? 0;
    final pending = int.tryParse(stats['pending']?.toString() ?? '0') ?? 0;
    final mb = stats['total_size_mb']?.toString() ?? '0';

    String v(int n) => loading ? '—' : '$n';

    final main = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ResponsiveGrid(minItemWidth: 130, gap: 16, maxCols: 4, children: [
        _StatCard(icon: Icons.description_outlined, label: 'Documentos', count: v(total), color: AppTheme.text, outlined: true, onTap: () => onNavTap(1)),
        _StatCard(icon: Icons.schedule_rounded, label: 'Pendientes', count: v(pending), color: AppTheme.warning, onTap: () => onNavTap(1)),
        _StatCard(icon: Icons.draw_rounded, label: 'Firmados', count: v(signed), color: AppTheme.primary, onTap: () => onNavTap(1)),
        _StatCard(icon: Icons.check_rounded, label: 'Verificados', count: v(verified), color: AppTheme.success, onTap: () => onNavTap(2)),
      ]),
      const SizedBox(height: 20),
      _MidRow(children: [
        _ProgressCard(done: signed + verified, total: total, mb: mb, loading: loading, onNavTap: onNavTap),
        _DistributionCard(total: total, pending: pending, signed: signed, verified: verified),
      ]),
      const SizedBox(height: 28),
      _RecentActivity(docs: recentDocs, onNavTap: onNavTap),
    ]);

    final side = Column(children: [
      _GetStartedCard(total: total, signedOrVerified: signed + verified, verified: verified, onNavTap: onNavTap),
      const SizedBox(height: 16),
      const _ChainCard(),
    ]);

    return Column(children: [
      _TopBar(pad: pad, isWeb: isWeb, pending: pending, greeting: _greeting(), onNavTap: onNavTap, onRefresh: onRefresh),
      Expanded(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => onRefresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 1080) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: main),
                  const SizedBox(width: 24),
                  SizedBox(width: 340, child: side),
                ]);
              }
              return Column(children: [main, const SizedBox(height: 20), side]);
            }),
          ),
        ),
      ),
    ]);
  }

  String _greeting() {
    final now = DateTime.now();
    final g = now.hour < 12 ? 'Buenos días' : now.hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    const m = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '$g · ${now.day} ${m[now.month - 1]} ${now.year}';
  }
}

// ── Barra superior ─────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final double pad;
  final bool isWeb;
  final int pending;
  final String greeting;
  final ValueChanged<int> onNavTap;
  final VoidCallback onRefresh;
  const _TopBar({required this.pad, required this.isWeb, required this.pending, required this.greeting, required this.onNavTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: isWeb ? 20 : 12),
      decoration: const BoxDecoration(color: AppTheme.card, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bienvenido de nuevo', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.text, fontSize: isWeb ? 30 : 20, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
            const SizedBox(height: 2),
            Text(greeting, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
          ]),
        ),
        if (isWeb) ...[
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.link_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sepolia activo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 14),
        ],
        _CircleBtn(icon: Icons.refresh_rounded, tooltip: 'Actualizar', onTap: onRefresh),
        const SizedBox(width: 10),
        _CircleBtn(icon: Icons.notifications_none_rounded, tooltip: 'Pendientes', badge: pending, onTap: () => onNavTap(1)),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Mi perfil',
          child: InkWell(
            onTap: () => onNavTap(3),
            customBorder: const CircleBorder(),
            child: Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badge;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.tooltip, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 50, height: 50,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: AppTheme.card, shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
              child: Icon(icon, color: AppTheme.text, size: 21),
            ),
            if (badge > 0)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.card, width: 2)),
                  child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.1)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Primitivas ─────────────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(22), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard), side: const BorderSide(color: AppTheme.border)),
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Reparte los hijos en N columnas según el ancho disponible.
class _ResponsiveGrid extends StatelessWidget {
  final double minItemWidth, gap;
  final int maxCols;
  final List<Widget> children;
  const _ResponsiveGrid({required this.minItemWidth, required this.gap, required this.maxCols, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = ((c.maxWidth + gap) ~/ (minItemWidth + gap)).clamp(1, maxCols);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

/// Dos tarjetas lado a lado en ancho, apiladas en estrecho.
class _MidRow extends StatelessWidget {
  final List<Widget> children;
  const _MidRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 640) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ]),
        );
      }
      return Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ]);
    });
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, count;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _StatCard({required this.icon, required this.label, required this.count, required this.color, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(count);
    final sub = n == null ? '—' : '$n ${n == 1 ? 'documento' : 'documentos'}';
    return _Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: outlined ? AppTheme.card : color,
            shape: BoxShape.circle,
            border: outlined ? Border.all(color: AppTheme.border) : null,
            boxShadow: outlined ? null : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Icon(icon, color: outlined ? AppTheme.text : Colors.white, size: 22),
        ),
        const SizedBox(height: 26),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
        ),
        const SizedBox(height: 4),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      ]),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _CardTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
          ],
        ]),
      ),
    ]);
  }
}

// ── Progreso de firmas (estilo “créditos”) ─────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final int done, total;
  final String mb;
  final bool loading;
  final ValueChanged<int> onNavTap;
  const _ProgressCard({required this.done, required this.total, required this.mb, required this.loading, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Firmas completadas', style: TextStyle(color: AppTheme.hint, fontSize: 15)),
              const SizedBox(height: 6),
              Text(loading ? '—' : '$done', style: const TextStyle(color: AppTheme.text, fontSize: 48, fontWeight: FontWeight.w600, letterSpacing: -1.5, height: 1.05)),
            ]),
          ),
          OutlinedButton(
            onPressed: () => onNavTap(1),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('Ver documentos'),
          ),
        ]),
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final fill = w * pct;
          const bubbleW = 96.0;
          final left = (fill - bubbleW / 2).clamp(0.0, math.max(0.0, w - bubbleW)).toDouble();
          return Column(children: [
            SizedBox(
              height: 30,
              child: Stack(children: [
                Positioned(
                  left: left, top: 0,
                  child: Container(
                    width: bubbleW, height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)),
                    child: Text('${(pct * 100).round()}% completado', style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Stack(children: [
              Container(height: 22, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                height: 22,
                width: fill,
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
              ),
            ]),
          ]);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Text(loading ? '—' : '$done firmados', style: const TextStyle(color: AppTheme.text, fontSize: 13)),
          const Spacer(),
          Text('de ${loading ? '—' : total}', style: const TextStyle(color: AppTheme.text, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.cloud_outlined, size: 15, color: AppTheme.hint),
          const SizedBox(width: 6),
          Text('$mb MB almacenados', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── Distribución por estado (barras tipo píldora) ──────────────────────────
class _DistributionCard extends StatelessWidget {
  final int total, pending, signed, verified;
  const _DistributionCard({required this.total, required this.pending, required this.signed, required this.verified});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _CardTitle('Distribución por estado', subtitle: 'Todos tus documentos'),
        const SizedBox(height: 22),
        _PillBar(label: 'Pendiente', count: pending, total: total, color: AppTheme.warning),
        const SizedBox(height: 10),
        _PillBar(label: 'Firmado', count: signed, total: total, color: AppTheme.primary),
        const SizedBox(height: 10),
        _PillBar(label: 'Verificado', count: verified, total: total, color: AppTheme.success),
        const SizedBox(height: 10),
        _PillBar(label: 'Total', count: total, total: total, color: AppTheme.text),
      ]),
    );
  }
}

class _PillBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _PillBar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return SizedBox(
      height: 46,
      child: LayoutBuilder(builder: (context, c) {
        // El relleno nunca baja de un mínimo para que la etiqueta siempre quepa.
        final fillW = math.max(c.maxWidth * pct, math.min(c.maxWidth, 104.0));
        return Stack(children: [
          Container(
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(23)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            width: fillW,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(23)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Positioned(
            right: 16, top: 0, bottom: 0,
            child: Center(child: Text('${(pct * 100).round()}%', style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600))),
          ),
        ]);
      }),
    );
  }
}

// ── Primeros pasos (checklist con datos reales) ────────────────────────────
class _GetStartedCard extends StatefulWidget {
  final int total, signedOrVerified, verified;
  final ValueChanged<int> onNavTap;
  const _GetStartedCard({required this.total, required this.signedOrVerified, required this.verified, required this.onNavTap});

  @override
  State<_GetStartedCard> createState() => _GetStartedCardState();
}

class _GetStartedCardState extends State<_GetStartedCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      _Step('Sube tu primer documento', 'PDF o Word, hasta donde lo necesites.', widget.total > 0, 1),
      _Step('Firma un documento', 'Dibuja tu firma y regístrala con respaldo criptográfico.', widget.signedOrVerified > 0, 1),
      _Step('Verifica en blockchain', 'Comprueba la autenticidad de una firma en Sepolia.', widget.verified > 0, 2),
      _Step('Completa tu perfil', 'Mantén tus datos al día para firmar con confianza.', false, 3, trackable: false),
    ];
    final doneCount = steps.where((s) => s.done).length;
    final trackable = steps.where((s) => s.trackable).length;

    return Material(
      color: AppTheme.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard), side: const BorderSide(color: AppTheme.border)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Primeros pasos', style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('$doneCount de $trackable completados', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
                ]),
              ),
              AnimatedRotation(turns: _open ? 0 : 0.5, duration: const Duration(milliseconds: 200), child: const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.text)),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          secondChild: const SizedBox(width: double.infinity),
          firstChild: Column(children: [
            for (var i = 0; i < steps.length; i++) ...[
              const Divider(height: 1, color: AppTheme.border),
              _StepTile(index: i + 1, step: steps[i], onTap: () => widget.onNavTap(steps[i].target)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Step {
  final String title, desc;
  final bool done;
  final int target;
  final bool trackable;
  const _Step(this.title, this.desc, this.done, this.target, {this.trackable = true});
}

class _StepTile extends StatelessWidget {
  final int index;
  final _Step step;
  final VoidCallback onTap;
  const _StepTile({required this.index, required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 18, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          step.done
              ? Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 16))
              : Container(
                  width: 28, height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
                  child: Text('$index', style: const TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: step.done
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(step.title, style: const TextStyle(color: AppTheme.hint, fontSize: 14, decoration: TextDecoration.lineThrough, decorationColor: AppTheme.hint)),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(step.title, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 3),
                    Text(step.desc, style: const TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.35)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _ChainCard extends StatelessWidget {
  const _ChainCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.link_rounded, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ethereum Sepolia Testnet', style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('Contrato verificado en Etherscan', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
        Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
      ]),
    );
  }
}

// ── Actividad reciente (tabla) ─────────────────────────────────────────────
class _RecentActivity extends StatefulWidget {
  final List<Map<String, dynamic>> docs;
  final ValueChanged<int> onNavTap;
  const _RecentActivity({required this.docs, required this.onNavTap});

  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  String _filter = 'all';

  static const _labels = {
    'all': 'Todos los estados',
    'pending': 'Pendiente',
    'signed': 'Firmado',
    'verified': 'Verificado',
    'rejected': 'Rechazado',
  };

  @override
  Widget build(BuildContext context) {
    final docs = _filter == 'all' ? widget.docs : widget.docs.where((d) => (d['status']?.toString() ?? 'pending') == _filter).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Actividad reciente', style: TextStyle(color: AppTheme.text, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4))),
        PopupMenuButton<String>(
          tooltip: 'Filtrar por estado',
          onSelected: (v) => setState(() => _filter = v),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
          color: AppTheme.card,
          surfaceTintColor: Colors.transparent,
          itemBuilder: (_) => [
            for (final e in _labels.entries)
              PopupMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontSize: 13, fontWeight: e.key == _filter ? FontWeight.w700 : FontWeight.w400, color: AppTheme.text))),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.tune_rounded, size: 16, color: AppTheme.text),
              const SizedBox(width: 8),
              Text(_labels[_filter]!, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.hint),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Material(
        color: AppTheme.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard), side: const BorderSide(color: AppTheme.border)),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 560;
          return Column(children: [
            if (wide)
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: const Row(children: [
                  Expanded(flex: 5, child: _Th('Documento')),
                  Expanded(flex: 3, child: _Th('Estado')),
                  Expanded(flex: 3, child: _Th('Fecha')),
                  SizedBox(width: 72, child: _Th('Tamaño')),
                ]),
              ),
            if (docs.isEmpty)
              _EmptyActivity(hasAny: widget.docs.isNotEmpty, onNavTap: widget.onNavTap)
            else
              for (var i = 0; i < docs.length; i++) ...[
                if (i > 0 || wide) const Divider(height: 1, color: AppTheme.border),
                _DocRow(doc: docs[i], wide: wide, onTap: () => widget.onNavTap(1)),
              ],
            if (docs.isNotEmpty) ...[
              const Divider(height: 1, color: AppTheme.border),
              InkWell(
                onTap: () => widget.onNavTap(1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Ver todos los documentos', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600))),
                ),
              ),
            ],
          ]);
        }),
      ),
    ]);
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600));
}

class _EmptyActivity extends StatelessWidget {
  final bool hasAny;
  final ValueChanged<int> onNavTap;
  const _EmptyActivity({required this.hasAny, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle),
            child: const Icon(Icons.inbox_outlined, color: AppTheme.hint, size: 26),
          ),
          const SizedBox(height: 12),
          Text(hasAny ? 'Ningún documento con este estado' : 'Aún no hay actividad', style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
          if (!hasAny) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => onNavTap(1),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Subir documento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool wide;
  final VoidCallback onTap;
  const _DocRow({required this.doc, required this.wide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = (meta['extension']?.toString() ?? 'pdf').toLowerCase();
    final status = doc['status']?.toString() ?? 'pending';
    final title = doc['title']?.toString() ?? 'Sin nombre';
    final size = '${meta['size_mb'] ?? '?'} MB';

    String dateStr = '—';
    try {
      if (doc['created_at'] != null) {
        final d = DateTime.parse(doc['created_at'].toString()).toLocal();
        dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    } catch (_) {}

    final (Color iconColor, IconData iconData) = switch (ext) {
      'pdf' => (AppTheme.error, Icons.picture_as_pdf_rounded),
      'doc' || 'docx' => (AppTheme.info, Icons.article_rounded),
      _ => (AppTheme.primary, Icons.insert_drive_file_rounded),
    };

    final icon = Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(iconData, color: iconColor, size: 18),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: wide ? 16 : 14),
        child: wide
            ? Row(children: [
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w500))),
                  ]),
                ),
                Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: _StatusChip(status: status))),
                Expanded(flex: 3, child: Text(dateStr, style: const TextStyle(color: AppTheme.hint, fontSize: 13))),
                SizedBox(width: 72, child: Text(size, style: const TextStyle(color: AppTheme.hint, fontSize: 13))),
              ])
            : Row(children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('$dateStr · $size', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
              ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'pending': (AppTheme.warning, 'Pendiente'),
      'signed': (AppTheme.primary, 'Firmado'),
      'verified': (AppTheme.success, 'Verificado'),
      'rejected': (AppTheme.error, 'Rechazado'),
    };
    final (color, label) = map[status] ?? (AppTheme.hint, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: HSLColor.fromColor(color).withLightness(0.3).toColor(), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Placeholder ────────────────────────────────────────────────────────────
class _PlaceholderContent extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _PlaceholderContent({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: AppTheme.text, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.5)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
              child: const Text('Próximamente', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}
