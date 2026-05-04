import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('¿Estás seguro que deseas cerrar sesión?',
            style: TextStyle(color: AppTheme.hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.hint))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Próximamente'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);

    if (isWeb) {
      return _WebLayout(
        selectedIndex: _selectedIndex,
        onNavTap: (i) => setState(() => _selectedIndex = i),
        onLogout: _logout,
        onComingSoon: _showComingSoon,
      );
    }

    return _MobileLayout(
      selectedIndex: _selectedIndex,
      onNavTap: (i) => setState(() => _selectedIndex = i),
      onLogout: _logout,
      onComingSoon: _showComingSoon,
    );
  }
}

// ─────────────────────────────────────────
// WEB LAYOUT — sidebar + contenido
// ─────────────────────────────────────────
class _WebLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final void Function(String) onComingSoon;

  const _WebLayout({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: AppTheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.featureCyan],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'BlockSign',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Nav items
                _SidebarItem(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  selected: selectedIndex == 0,
                  onTap: () => onNavTap(0),
                ),
                _SidebarItem(
                  icon: Icons.description_rounded,
                  label: 'Documentos',
                  selected: selectedIndex == 1,
                  onTap: () => onNavTap(1),
                ),
                _SidebarItem(
                  icon: Icons.verified_rounded,
                  label: 'Verificar',
                  selected: selectedIndex == 2,
                  onTap: () => onNavTap(2),
                ),
                _SidebarItem(
                  icon: Icons.person_rounded,
                  label: 'Perfil',
                  selected: selectedIndex == 3,
                  onTap: () => onNavTap(3),
                ),

                const Spacer(),

                // Logout
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: onLogout,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.15)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.red, size: 18),
                          SizedBox(width: 10),
                          Text('Cerrar sesión',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: _DashboardContent(onComingSoon: onComingSoon),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.hint,
                size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.hint,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MOBILE LAYOUT
// ─────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;
  final void Function(String) onComingSoon;

  const _MobileLayout({
    required this.selectedIndex,
    required this.onNavTap,
    required this.onLogout,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _DashboardContent(
          onComingSoon: onComingSoon,
          onLogout: onLogout,
          showHeader: true,
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primary.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11);
            }
            return const TextStyle(color: AppTheme.hint, fontSize: 11);
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded, color: AppTheme.primary),
              label: 'Documentos',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primary),
              label: 'Verificar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// DASHBOARD CONTENT (compartido móvil/web)
// ─────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final void Function(String) onComingSoon;
  final VoidCallback? onLogout;
  final bool showHeader;

  const _DashboardContent({
    required this.onComingSoon,
    this.onLogout,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                isWeb ? 32 : 20, isWeb ? 32 : 20, isWeb ? 32 : 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header móvil
                if (showHeader)
                  Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              )),
                          Text('BlockSign',
                              style: TextStyle(
                                  color: AppTheme.hint, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      if (onLogout != null)
                        GestureDetector(
                          onTap: onLogout,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.15)),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Colors.red, size: 18),
                          ),
                        ),
                    ],
                  ),

                if (showHeader) const SizedBox(height: 28),

                if (isWeb && !showHeader)
                  const Text('Dashboard',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),

                if (isWeb) const SizedBox(height: 24),

                // Stats
                const Text('Resumen',
                    style: TextStyle(
                        color: AppTheme.hint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.description_rounded,
                        iconColor: AppTheme.primary,
                        label: 'Documentos',
                        value: '0',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.draw_rounded,
                        iconColor: AppTheme.featureCyan,
                        label: 'Firmados',
                        value: '0',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.verified_rounded,
                        iconColor: Colors.green,
                        label: 'Verificados',
                        value: '0',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Acciones
                const Text('Acciones rápidas',
                    style: TextStyle(
                        color: AppTheme.hint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: isWeb ? 4 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: isWeb ? 1.4 : 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ActionCard(
                      icon: Icons.upload_file_rounded,
                      label: 'Subir documento',
                      color: AppTheme.primary,
                      onTap: () => onComingSoon('Subir documentos'),
                    ),
                    _ActionCard(
                      icon: Icons.draw_rounded,
                      label: 'Firmar documento',
                      color: AppTheme.featureCyan,
                      onTap: () => onComingSoon('Firmar documentos'),
                    ),
                    _ActionCard(
                      icon: Icons.verified_user_rounded,
                      label: 'Verificar firma',
                      color: Colors.green,
                      onTap: () => onComingSoon('Verificar firmas'),
                    ),
                    _ActionCard(
                      icon: Icons.history_rounded,
                      label: 'Historial',
                      color: Colors.orange,
                      onTap: () => onComingSoon('Historial'),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Actividad reciente
                const Text('Actividad reciente',
                    style: TextStyle(
                        color: AppTheme.hint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_rounded,
                          color: Color(0xFF374151), size: 36),
                      SizedBox(height: 12),
                      Text('Sin actividad aún',
                          style: TextStyle(
                              color: Color(0xFF6b7280),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Sube y firma tu primer documento',
                          style: TextStyle(
                              color: Color(0xFF4b5563), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: iconColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6b7280), fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}