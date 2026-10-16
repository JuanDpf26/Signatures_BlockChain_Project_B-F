import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accessibility_menu.dart';
import '../widgets/brand.dart';
import '../widgets/bs_ui.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';

/// Consola de los superusuarios. Es una interfaz aparte de la del aplicativo:
/// no tiene documentos, bandeja ni firmas; solo administración y la cuenta.
class AdminConsole extends StatefulWidget {
  final VoidCallback onLogout;
  const AdminConsole({super.key, required this.onLogout});

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  int _view = 0; // 0 = panel, 1 = mi cuenta
  String _name = '';
  String _email = '';
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final r = await ProfileService.getProfile();
      if (!mounted || r['user'] is! Map) return;
      final u = Map<String, dynamic>.from(r['user']);
      setState(() {
        _name = u['name']?.toString() ?? '';
        _email = u['email']?.toString() ?? '';
        _avatar = u['avatar_url']?.toString();
      });
    } catch (_) {}
  }

  void _go(int v) {
    if (v == _view) return;
    setState(() => _view = v);
    if (v == 0) _loadUser(); // por si cambió el nombre o la foto
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    return Scaffold(
      backgroundColor: BSColors.page,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          wide ? _wideBar() : _narrowBar(),
          Expanded(
            child: IndexedStack(index: _view, children: const [
              AdminScreen(),
              ProfileScreen(adminMode: true),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _consoleTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.admin_panel_settings_rounded, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('Consola de administración', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _wideBar() {
    Widget tab(int v, IconData icon, String label) {
      final sel = _view == v;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextButton.icon(
          onPressed: () => _go(v),
          style: TextButton.styleFrom(
            backgroundColor: sel ? AppTheme.primary.withOpacity(0.10) : Colors.transparent,
            foregroundColor: sel ? AppTheme.primary : AppTheme.hint,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        const BrandSymbol(size: 34),
        const SizedBox(width: 10),
        const SizedBox(width: 150, child: BrandWordmark(fontSize: 22)),
        const SizedBox(width: 14),
        _consoleTag(),
        const Spacer(),
        tab(0, Icons.space_dashboard_outlined, 'Panel'),
        tab(1, Icons.manage_accounts_outlined, 'Mi cuenta'),
        const SizedBox(width: 10),
        const AccessibilityButton(),
        const SizedBox(width: 14),
        BSAvatar(name: _name, url: _avatar, radius: 19),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name.isEmpty ? 'Superusuario' : _name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(_email.isEmpty ? 'Superusuario' : 'Superusuario · $_email', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout_rounded, color: BSColors.danger, size: 20),
        ),
      ]),
    );
  }

  Widget _narrowBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        const BrandSymbol(size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_view == 0 ? 'Administración' : 'Mi cuenta',
                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(_name.isEmpty ? 'Consola de superusuario' : 'Superusuario · $_name', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
        const AccessibilityButton(),
        PopupMenuButton<int>(
          tooltip: 'Menú',
          icon: BSAvatar(name: _name, url: _avatar, radius: 17),
          onSelected: (v) => v == 2 ? widget.onLogout() : _go(v),
          itemBuilder: (_) => [
            _menu(0, Icons.space_dashboard_outlined, 'Panel de administración'),
            _menu(1, Icons.manage_accounts_outlined, 'Mi cuenta'),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 2,
              child: Row(children: [
                Icon(Icons.logout_rounded, size: 18, color: BSColors.danger),
                SizedBox(width: 10),
                Text('Cerrar sesión', style: TextStyle(color: BSColors.danger)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<int> _menu(int v, IconData icon, String label) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 18, color: _view == v ? AppTheme.primary : AppTheme.hint),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: _view == v ? AppTheme.primary : AppTheme.text, fontWeight: _view == v ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
}
