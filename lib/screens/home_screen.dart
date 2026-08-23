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
  String _userName = '';
  String _userEmail = '';

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
        _recentDocs = List<Map<String, dynamic>>.from(docsRes['documents']).take(5).toList();
      }
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text('¿Deseas cerrar sesión?', style: TextStyle(color: AppTheme.hint, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1: return const DocumentsScreen();
      case 2: return _PlaceholderContent(icon: Icons.verified_outlined, title: 'Verificar firma', subtitle: 'Comprueba la autenticidad de documentos firmados en blockchain.');
      case 3: return const ProfileScreen();
      default: return _DashboardContent(stats: _stats, recentDocs: _recentDocs, loading: _loading, onNavTap: (i) => setState(() => _selectedIndex = i), onRefresh: _loadData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);
    return isWeb
        ? _WebShell(selectedIndex: _selectedIndex, onNavTap: (i) => setState(() => _selectedIndex = i), onLogout: _logout, content: _buildContent())
        : _MobileShell(selectedIndex: _selectedIndex, onNavTap: (i) => setState(() => _selectedIndex = i), content: _buildContent());
  }
}

// ── Web shell ──────────────────────────────────────────────────────────────
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
        // Sidebar
        SizedBox(
          width: 220,
          child: Container(
            color: AppTheme.surface,
            child: Column(children: [
              // Logo
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BlockSign', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('Firma digital', style: TextStyle(color: AppTheme.hint, fontSize: 10)),
                  ]),
                ]),
              ),
              const _SidebarDivider(),

              const SizedBox(height: 8),
              _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard', selected: selectedIndex == 0, onTap: () => onNavTap(0)),
              _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Documentos', selected: selectedIndex == 1, onTap: () => onNavTap(1)),
              _NavItem(icon: Icons.verified_outlined, activeIcon: Icons.verified_rounded, label: 'Verificar', selected: selectedIndex == 2, onTap: () => onNavTap(2)),

              const SizedBox(height: 8),
              const _SidebarDivider(),
              const SizedBox(height: 8),

              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil', selected: selectedIndex == 3, onTap: () => onNavTap(3)),

              const Spacer(),

              // Versión
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('UMB · IS25133 · v1.0.0', style: TextStyle(color: Color(0xFF4b5563), fontSize: 10), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              const _SidebarDivider(),

              // Logout
              InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, color: Colors.red, size: 17),
                    const SizedBox(width: 10),
                    const Text('Cerrar sesión', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        // Contenido
        Expanded(child: content),
      ]),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 0));
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(selected ? activeIcon : icon, color: selected ? AppTheme.primary : AppTheme.hint, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: selected ? AppTheme.primary : AppTheme.hint, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          if (selected) ...[const Spacer(), Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle))],
        ]),
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
        decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
        child: NavigationBar(
          backgroundColor: AppTheme.surface,
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

// ── Dashboard content ──────────────────────────────────────────────────────
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

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Topbar
          Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dashboard', style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w600)),
                Text(_greeting(), style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
              ]),
              const Spacer(),
              // Badge blockchain
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.circle, color: Colors.green, size: 7),
                  SizedBox(width: 5),
                  Text('Sepolia activo', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          const SizedBox(height: 20),

          // Banner blockchain
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.link_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Blockchain conectado — Ethereum Sepolia Testnet', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('Contrato verificado en Etherscan', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
              ])),
              const Icon(Icons.open_in_new_rounded, color: AppTheme.hint, size: 16),
            ]),
          ),
          const SizedBox(height: 20),

          // Stats
          _SectionLabel('Resumen de actividad'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isWeb ? 4 : 2,
            mainAxisSpacing: 10, crossAxisSpacing: 10,
            childAspectRatio: isWeb ? 1.8 : 1.5,
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(icon: Icons.description_outlined, label: 'Documentos', value: loading ? '-' : '$total', valueColor: AppTheme.primary),
              _StatCard(icon: Icons.draw_outlined, label: 'Firmados', value: loading ? '-' : '$signed', valueColor: AppTheme.text),
              _StatCard(icon: Icons.verified_outlined, label: 'Verificados', value: loading ? '-' : '$verified', valueColor: Colors.green),
              _StatCard(icon: Icons.storage_outlined, label: 'MB usados', value: loading ? '-' : mb, valueColor: Colors.orange),
            ],
          ),
          const SizedBox(height: 20),

          // Main grid
          if (isWeb)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [
                _RecentDocsCard(docs: recentDocs, onNavTap: onNavTap),
              ])),
              const SizedBox(width: 12),
              SizedBox(width: 300, child: Column(children: [
                _DistributionCard(total: total, pending: pending, signed: signed, verified: verified),
                const SizedBox(height: 12),
                _QuickActionsCard(onNavTap: onNavTap),
              ])),
            ])
          else
            Column(children: [
              _DistributionCard(total: total, pending: pending, signed: signed, verified: verified),
              const SizedBox(height: 12),
              _QuickActionsCard(onNavTap: onNavTap),
              const SizedBox(height: 12),
              _RecentDocsCard(docs: recentDocs, onNavTap: onNavTap),
            ]),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final g = h < 12 ? 'Buenos días' : h < 18 ? 'Buenas tardes' : 'Buenas noches';
    final now = DateTime.now();
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '$g — ${now.day} ${m[now.month-1]} ${now.year}';
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
        child: Icon(icon, color: AppTheme.hint, size: 16),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: const TextStyle(color: AppTheme.hint, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color valueColor;
  const _StatCard({required this.icon, required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: AppTheme.hint, size: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.w600)),
          Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _RecentDocsCard extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final ValueChanged<int> onNavTap;
  const _RecentDocsCard({required this.docs, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            const Text('Documentos recientes', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(onTap: () => onNavTap(1), child: const Text('Ver todos →', style: TextStyle(color: AppTheme.primary, fontSize: 12))),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),
        if (docs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Icon(Icons.inbox_outlined, color: AppTheme.hint, size: 32),
              const SizedBox(height: 8),
              const Text('Sin documentos aún', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onNavTap(1),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), foregroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.upload_file_rounded, size: 15),
                label: const Text('Subir documento', style: TextStyle(fontSize: 13)),
              ),
            ]),
          )
        else
          ...docs.asMap().entries.map((e) {
            final i = e.key;
            final doc = e.value;
            final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
            final ext = meta['extension']?.toString() ?? 'pdf';
            final isPdf = ext == 'pdf';
            final status = doc['status']?.toString() ?? 'pending';
            final created = doc['created_at'] != null ? DateTime.parse(doc['created_at']).toLocal() : DateTime.now();
            final dateStr = '${created.day}/${created.month}/${created.year}';

            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isPdf ? Colors.red.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded, color: isPdf ? Colors.red : AppTheme.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(doc['title']?.toString() ?? 'Sin nombre', style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$dateStr · ${meta['size_mb'] ?? '?'} MB', style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                  ])),
                  _StatusChip(status: status),
                ]),
              ),
              if (i < docs.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.border),
            ]);
          }),
      ]),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final int total, pending, signed, verified;
  const _DistributionCard({required this.total, required this.pending, required this.signed, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Distribución por estado', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        _Bar(label: 'Pendiente', count: pending, total: total, color: Colors.orange),
        const SizedBox(height: 10),
        _Bar(label: 'Firmado', count: signed, total: total, color: AppTheme.primary),
        const SizedBox(height: 10),
        _Bar(label: 'Verificado', count: verified, total: total, color: Colors.green),
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
        Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
        const Spacer(),
        Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, backgroundColor: AppTheme.border, valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
      ),
    ]);
  }
}

class _QuickActionsCard extends StatelessWidget {
  final ValueChanged<int> onNavTap;
  const _QuickActionsCard({required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Acciones rápidas', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.4,
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          children: [
            _ActionBtn(icon: Icons.upload_file_outlined, label: 'Subir', sub: 'PDF o Word', color: AppTheme.primary, onTap: () => onNavTap(1)),
            _ActionBtn(icon: Icons.draw_outlined, label: 'Firmar', sub: 'Documento', color: Colors.green, onTap: () => onNavTap(1)),
            _ActionBtn(icon: Icons.verified_outlined, label: 'Verificar', sub: 'Firma', color: Colors.orange, onTap: () => onNavTap(2)),
            _ActionBtn(icon: Icons.person_outline_rounded, label: 'Perfil', sub: 'Mi cuenta', color: Colors.purple, onTap: () => onNavTap(3)),
          ],
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(sub, style: const TextStyle(color: AppTheme.hint, fontSize: 10)),
          ]),
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
      'pending': (Colors.orange, 'Pendiente'),
      'signed': (AppTheme.primary, 'Firmado'),
      'verified': (Colors.green, 'Verificado'),
      'rejected': (Colors.red, 'Rechazado'),
    };
    final (color, label) = map[status] ?? (AppTheme.hint, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)), child: Icon(icon, color: AppTheme.hint, size: 28)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)), child: const Text('Próximamente', style: TextStyle(color: AppTheme.hint, fontSize: 12))),
      ]),
    );
  }
}