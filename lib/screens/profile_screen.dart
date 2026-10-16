import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../widgets/skeleton.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/proof_ui.dart';
import '../widgets/bs_ui.dart';
import '../theme/app_theme.dart';
import '../widgets/accessibility_menu.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _user = {};
  bool _isLoading = true;
  int _section = 0;

  // Secciones (como la configuración de cuenta de Vercel)
  static const _sections = [
    (Icons.person_outline_rounded, 'General'),
    (Icons.lock_outline_rounded, 'Seguridad'),
    (Icons.key_outlined, 'Llaves de firma'),
    (Icons.draw_outlined, 'Firma manuscrita'),
    (Icons.accessibility_new_rounded, 'Apariencia y accesibilidad'),
    (Icons.warning_amber_rounded, 'Eliminar cuenta'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = _user.isEmpty);
    final res = await ProfileService.getProfile();
    if (!mounted) return;
    setState(() {
      if (res.containsKey('user')) _user = Map<String, dynamic>.from(res['user']);
      _isLoading = false;
    });
  }

  Widget _content() => switch (_section) {
        0 => _InfoTab(key: const ValueKey('info'), user: _user, onUpdated: _loadProfile),
        1 => _SecurityTab(key: const ValueKey('sec'), user: _user),
        2 => const _KeysSection(),
        3 => const _SignatureTab(),
        4 => const _SettingsCard(
            title: 'Apariencia y accesibilidad',
            description: 'Elige el tema, el tamaño del texto y otras opciones para leer con comodidad.',
            footer: 'También puedes abrir este menú desde el ícono de accesibilidad de la barra superior.',
            child: AccessibilityPanel(),
          ),
        _ => _AccountSection(user: _user),
      };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWeb = w > 600;
    final wide = w > 1050;
    final pad = isWeb ? 28.0 : 16.0;

    if (_isLoading) {
      return Container(color: BSColors.page, child: const SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [SkeletonBlock(height: 140), SizedBox(height: 16), SkeletonBlock(height: 180)])));
    }

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, isWeb ? 28 : 96),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Configuración de la cuenta', style: TextStyle(color: AppTheme.text, fontSize: isWeb ? 28 : 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text('Tu información, la seguridad, la firma y cómo se ve la aplicación.', style: TextStyle(color: AppTheme.hint, fontSize: 14)),
            const SizedBox(height: 24),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 240,
                  child: _SectionNav(sections: _sections, selected: _section, onSelect: (i) => setState(() => _section = i)),
                ),
                const SizedBox(width: 32),
                Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: _content())),
              ])
            else ...[
              _SectionChips(sections: _sections, selected: _section, onSelect: (i) => setState(() => _section = i)),
              const SizedBox(height: 18),
              _content(),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Menú lateral sin caja, como en Vercel: texto simple y el elegido resaltado
class _SectionNav extends StatelessWidget {
  final List<(IconData, String)> sections;
  final int selected;
  final ValueChanged<int> onSelect;
  const _SectionNav({required this.sections, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < sections.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: i == selected ? AppTheme.primary.withOpacity(AppTheme.isDark ? 0.18 : 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(children: [
                  Icon(sections[i].$1, size: 18,
                      color: i == sections.length - 1 ? BSColors.danger : (i == selected ? AppTheme.primary : AppTheme.hint)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(sections[i].$2,
                        style: TextStyle(
                          color: i == sections.length - 1 ? BSColors.danger : (i == selected ? AppTheme.primary : AppTheme.hint),
                          fontSize: 14,
                          fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Secciones como fichas desplazables (celular y tableta)
class _SectionChips extends StatelessWidget {
  final List<(IconData, String)> sections;
  final int selected;
  final ValueChanged<int> onSelect;
  const _SectionChips({required this.sections, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == selected;
          return InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary : AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(sections[i].$1, size: 16, color: sel ? Colors.white : AppTheme.hint),
                const SizedBox(width: 6),
                Text(sections[i].$2, style: TextStyle(color: sel ? Colors.white : AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta de ajuste al estilo Vercel: título, explicación, contenido y
/// una barra inferior con una ayuda y la acción.
class _SettingsCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? child;
  final Widget? trailing; // a la derecha del título (p. ej. la foto)
  final String? footer;
  final Widget? action;
  final bool danger;
  const _SettingsCard({required this.title, this.description, this.child, this.trailing, this.footer, this.action, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    final border = danger ? BSColors.danger.withOpacity(0.45) : AppTheme.border;
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
      if (description != null) ...[
        const SizedBox(height: 8),
        Text(description!, style: TextStyle(color: AppTheme.text.withOpacity(0.8), fontSize: 14, height: 1.5)),
      ],
    ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.all(narrow ? 18 : 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            trailing == null ? head : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: head), const SizedBox(width: 16), trailing!]),
            if (child != null) ...[const SizedBox(height: 18), child!],
          ]),
        ),
        if (footer != null || action != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 24, vertical: 12),
            decoration: BoxDecoration(
              color: danger ? BSColors.danger.withOpacity(0.06) : AppTheme.surface,
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(footer ?? '', style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
              ),
              if (action != null) ...[const SizedBox(width: 12), action!],
            ]),
          ),
      ]),
    );
  }
}

/// Botón compacto de las tarjetas (Guardar)
class _SaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final Color? color;
  const _SaveButton({this.label = 'Guardar', this.loading = false, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.primary;
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bg.withOpacity(0.35),
          disabledForegroundColor: Colors.white.withOpacity(0.8),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

/// Campo de texto sobrio para las tarjetas de ajustes
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  const _Field({required this.controller, this.hint, this.obscure = false, this.enabled = true, this.maxLength, this.keyboard, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        maxLength: maxLength,
        keyboardType: keyboard,
        onChanged: onChanged,
        style: TextStyle(color: AppTheme.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: enabled ? AppTheme.card : AppTheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primary, width: 1.4)),
        ),
      ),
    );
  }
}

Future<void> _pickAvatar(BuildContext context, VoidCallback onDone) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 85);
  if (picked == null) return;
  final bytes = await picked.readAsBytes();
  final mimeType = picked.mimeType ?? 'image/jpeg';
  final res = await ProfileService.uploadAvatar(bytes, mimeType);
  if (!context.mounted) return;
  if (res.containsKey('error')) {
    await SweetAlert.error(context, title: 'No se pudo actualizar la foto', text: res['error'].toString());
  } else {
    SweetAlert.success(context, title: 'Foto actualizada', autoClose: const Duration(milliseconds: 1500));
    onDone();
  }
}

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final VoidCallback onTap;
  const _AvatarWidget({required this.avatarUrl, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(children: [
          BSAvatar(name: name, url: avatarUrl, radius: 40),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
            ),
          ),
        ]),
      ),
    );
  }
}

// Contenido de cada pestaña: dos columnas en pantallas anchas, una en celular.
// Ocupa todo el ancho disponible (sin espacios vacíos a la derecha).
class _TabBody extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  const _TabBody({required this.left, this.right = const []});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 1180 && right.isNotEmpty;
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...left,
      if (right.isNotEmpty) const SizedBox(height: 16),
      ...right,
    ]);
  }
}

// ─────────────────────────────────────────
// GENERAL
// ─────────────────────────────────────────
class _InfoTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUpdated;
  const _InfoTab({super.key, required this.user, required this.onUpdated});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  late final _nameCtrl = TextEditingController(text: widget.user['name']?.toString() ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.user['phone']?.toString() ?? '');
  String? _saving; // 'name' | 'phone'

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _nameChanged => _nameCtrl.text.trim() != (widget.user['name']?.toString() ?? '');
  bool get _phoneChanged => _phoneCtrl.text.trim() != (widget.user['phone']?.toString() ?? '');

  Future<void> _save(String what) async {
    if (_nameCtrl.text.trim().length < 2) {
      await SweetAlert.warning(context, title: 'Revisa el nombre', text: 'El nombre debe tener mínimo 2 caracteres.');
      return;
    }
    setState(() => _saving = what);
    final res = await ProfileService.updateProfile(name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = null);
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo guardar', text: res['error'].toString());
    } else {
      SweetAlert.success(context, title: what == 'name' ? 'Nombre actualizado' : 'Teléfono actualizado', autoClose: const Duration(milliseconds: 1400));
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final stats = (u['stats'] as Map?) ?? {};
    final verified = u['is_email_verified'] == true;
    final isGoogle = u['google_id'] != null;
    final readOnly = Row(children: [
      Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.hint),
      const SizedBox(width: 6),
      Text('Solo lectura', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SettingsCard(
        title: 'Foto de perfil',
        description: 'Esta es tu foto. Haz clic en ella para subir una desde tus archivos.',
        trailing: _AvatarWidget(avatarUrl: u['avatar_url']?.toString(), name: u['name']?.toString() ?? '', onTap: () => _pickAvatar(context, widget.onUpdated)),
        footer: 'La foto es opcional, pero ayuda a que te reconozcan en la bandeja y en los equipos.',
      ),
      _SettingsCard(
        title: 'Nombre',
        description: 'Tu nombre completo, como aparecerá en las firmas, la bandeja y los correos.',
        child: _Field(controller: _nameCtrl, hint: 'Tu nombre completo', maxLength: 60, onChanged: (_) => setState(() {})),
        footer: 'Usa máximo 60 caracteres.',
        action: _SaveButton(loading: _saving == 'name', onPressed: _nameChanged ? () => _save('name') : null),
      ),
      _SettingsCard(
        title: 'Teléfono',
        description: 'Un número de contacto para tu cuenta.',
        child: _Field(controller: _phoneCtrl, hint: '3001234567', keyboard: TextInputType.phone, maxLength: 20, onChanged: (_) => setState(() {})),
        footer: 'Es opcional.',
        action: _SaveButton(loading: _saving == 'phone', onPressed: _phoneChanged ? () => _save('phone') : null),
      ),
      _SettingsCard(
        title: 'Correo electrónico',
        description: 'Con este correo inicias sesión y recibes los avisos de DocBlockSign.',
        child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(u['email']?.toString() ?? '—', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          verified ? const BSPill(label: 'Verificado', color: BSColors.success) : const BSPill(label: 'Sin verificar', color: BSColors.warning),
          if (isGoogle) BSPill(label: 'Cuenta Google', color: AppTheme.primary, dot: false),
        ]),
        footer: 'El correo identifica tu firma en los documentos registrados en blockchain, por eso no se puede cambiar.',
        action: readOnly,
      ),
      _SettingsCard(
        title: 'Número de documento',
        description: 'Tu cédula queda asociada a cada firma que haces.',
        child: Text(u['document_id']?.toString() ?? 'No registrado', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
        footer: 'Por seguridad no se puede modificar.',
        action: readOnly,
      ),
      _SettingsCard(
        title: 'Actividad de la cuenta',
        child: Wrap(spacing: 28, runSpacing: 16, children: [
          for (final (label, value) in [
            ('Miembro desde', fmtFecha(u['created_at']?.toString())),
            ('Último acceso', u['last_login'] != null ? fmtFechaHora(u['last_login'].toString()) : '—'),
            ('Documentos', '${stats['total_docs'] ?? 0}'),
            ('Firmados', '${stats['signed_docs'] ?? 0}'),
            ('Verificados', '${stats['verified_docs'] ?? 0}'),
            ('Espacio usado', '${'${stats['total_size_mb'] ?? 0}'.replaceAll('.', ',')} MB'),
          ])
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// TAB 2: SEGURIDAD
// ─────────────────────────────────────────
/// Ingreso con huella o rostro (solo aparece en celulares que lo tienen)
class _BiometricCard extends StatefulWidget {
  const _BiometricCard();

  @override
  State<_BiometricCard> createState() => _BiometricCardState();
}

class _BiometricCardState extends State<_BiometricCard> {
  bool? _available;
  bool _on = false;
  String _label = 'huella o rostro';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final a = await BiometricService.available();
    final on = await BiometricService.enabled();
    final l = a ? await BiometricService.label() : _label;
    if (mounted) setState(() { _available = a; _on = on; _label = l; });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _busy = true);
    if (v) {
      final ok = await BiometricService.enable();
      if (mounted && ok) showToast(context, title: 'Ingreso con $_label activado');
    } else {
      await BiometricService.disable();
      if (mounted) showToast(context, title: 'Ingreso con $_label desactivado');
    }
    await _check();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_available != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _SettingsCard(
        title: 'Entrar con $_label',
        description: 'Entra a DocBlockSign sin escribir tu contraseña. Tu sesión se guarda cifrada en este teléfono y solo se abre con tu $_label.',
        footer: 'Solo aplica a este teléfono. La sesión guardada dura 7 días; después te pedimos la contraseña otra vez.',
        trailing: Switch(value: _on, onChanged: _busy ? null : _toggle, activeColor: AppTheme.primary),
      ),
    );
  }
}

class _SecurityTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const _SecurityTab({super.key, required this.user});

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _currentPassCtrl.dispose(); _newPassCtrl.dispose(); _confirmPassCtrl.dispose(); super.dispose(); }

  /// Medidor de fortaleza: 4 requisitos
  Widget _strength() {
    final p = _newPassCtrl.text;
    final reqs = <(String, bool)>[
      ('8 caracteres o más', p.length >= 8),
      ('Una mayúscula', p.contains(RegExp(r'[A-Z]'))),
      ('Un número', p.contains(RegExp(r'[0-9]'))),
      ('Un símbolo', p.contains(RegExp(r'[^A-Za-z0-9]'))),
    ];
    final ok = reqs.where((r) => r.$2).length;
    final color = ok <= 1 ? BSColors.danger : ok == 2 ? BSColors.warning : BSColors.success;
    final label = p.isEmpty ? 'Escribe la nueva contraseña' : ok <= 1 ? 'Contraseña débil' : ok == 2 ? 'Contraseña aceptable' : 'Contraseña fuerte';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 6,
              decoration: BoxDecoration(color: i < ok && p.isNotEmpty ? color : AppTheme.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          if (i < 3) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(color: p.isEmpty ? AppTheme.hint : color, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 16, runSpacing: 6, children: [
        for (final r in reqs)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.$2 ? Icons.check_rounded : Icons.close_rounded, size: 15, color: r.$2 ? BSColors.success : AppTheme.hint),
            const SizedBox(width: 5),
            Text(r.$1, style: TextStyle(color: r.$2 ? AppTheme.text : AppTheme.hint, fontSize: 12)),
          ]),
      ]),
    ]);
  }

  Future<void> _changePassword() async {
    if (_currentPassCtrl.text.isEmpty) {
      await SweetAlert.warning(context, title: 'Falta la contraseña actual', text: 'Escríbela para confirmar que eres tú.');
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      await SweetAlert.warning(context, title: 'Las contraseñas no coinciden', text: 'Escribe la misma contraseña nueva en ambos campos.');
      return;
    }
    if (_newPassCtrl.text.length < 8 || !_newPassCtrl.text.contains(RegExp(r'[A-Z]')) || !_newPassCtrl.text.contains(RegExp(r'[0-9]'))) {
      await SweetAlert.warning(context, title: 'Contraseña débil', text: 'Debe tener 8 o más caracteres, una mayúscula y un número.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ProfileService.changePassword(currentPassword: _currentPassCtrl.text, newPassword: _newPassCtrl.text);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (res.containsKey('error')) {
        await SweetAlert.error(context, title: 'No se pudo cambiar', text: res['error'].toString());
      } else {
        _currentPassCtrl.clear(); _newPassCtrl.clear(); _confirmPassCtrl.clear();
        await SweetAlert.success(context, title: 'Contraseña actualizada', text: 'Usa tu nueva contraseña la próxima vez que inicies sesión.', autoClose: const Duration(seconds: 3));
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = widget.user['google_id'] != null;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(t, style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _BiometricCard(),
      if (!isGoogle)
        _SettingsCard(
          title: 'Contraseña',
          description: 'Cámbiala cuando quieras. Te enviaremos un aviso por correo cuando se actualice.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Contraseña actual'),
            _Field(controller: _currentPassCtrl, hint: '••••••••', obscure: true),
            const SizedBox(height: 12),
            label('Nueva contraseña'),
            _Field(controller: _newPassCtrl, hint: 'Mínimo 8 caracteres', obscure: true),
            const SizedBox(height: 10),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _strength()),
            const SizedBox(height: 12),
            label('Confirmar nueva contraseña'),
            _Field(controller: _confirmPassCtrl, hint: 'Repítela', obscure: true),
          ]),
          footer: 'Debe tener 8 o más caracteres, una mayúscula y un número.',
          action: _SaveButton(label: 'Actualizar', loading: _isLoading, onPressed: _changePassword),
        )
      else
        const _SettingsCard(
          title: 'Contraseña',
          description: 'Tu cuenta inicia sesión con Google, así que la contraseña se gestiona desde tu cuenta de Google.',
        ),
      const _SettingsCard(
        title: 'Recomendaciones',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Tip(icon: Icons.password_rounded, text: 'Usa una contraseña única que no uses en otros sitios.'),
          _Tip(icon: Icons.mark_email_read_outlined, text: 'Mantén tu correo verificado: por ahí recibes los enlaces de recuperación.'),
          _Tip(icon: Icons.draw_outlined, text: 'Tu firma solo se aplica cuando confirmas cada documento.'),
          _Tip(icon: Icons.logout_rounded, text: 'Cierra sesión al usar equipos compartidos.'),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// LLAVES DE FIRMA
// ─────────────────────────────────────────
class _KeysSection extends StatelessWidget {
  const _KeysSection();
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _KeysCard(),
        SizedBox(height: 20),
        _SettingsCard(
          title: '¿Para qué sirven?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Tip(icon: Icons.key_rounded, text: 'Tu llave privada firma cada documento; nunca sale del servidor y se guarda cifrada.'),
            _Tip(icon: Icons.verified_user_outlined, text: 'Tu llave pública permite comprobar que la firma es tuya.'),
            _Tip(icon: Icons.fingerprint_rounded, text: 'La huella identifica tu llave en los comprobantes y en la verificación.'),
          ]),
        ),
      ]);
}

// ─────────────────────────────────────────
// CUENTA (eliminar)
// ─────────────────────────────────────────
class _AccountSection extends StatefulWidget {
  final Map<String, dynamic> user;
  const _AccountSection({required this.user});
  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  Future<void> _deleteAccount() async {
    final confirm = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: '¿Eliminar tu cuenta?',
      text: 'Esta acción es permanente. Se eliminarán todos tus documentos y datos.',
      confirmText: 'Sí, eliminar cuenta',
    );
    if (!confirm || !mounted) return;
    final res = await ProfileService.deleteAccount();
    if (!mounted) return;
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo eliminar', text: res['error'].toString());
    } else {
      await BiometricService.disable();
      await AuthService.logout();
      if (!mounted) return;
      await SweetAlert.success(context, title: 'Cuenta eliminada', text: 'Lamentamos verte partir.', autoClose: const Duration(seconds: 2));
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }


  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      danger: true,
      title: 'Eliminar cuenta',
      description: 'Elimina de forma permanente tu cuenta y todos tus documentos de DocBlockSign. Esta acción no se puede deshacer, así que hazlo con cuidado.',
      footer: 'Las firmas ya registradas en blockchain no se borran, porque la cadena es inmutable.',
      action: _SaveButton(label: 'Eliminar mi cuenta', color: BSColors.danger, onPressed: _deleteAccount),
    );
  }
}

// ─────────────────────────────────────────
// TAB 3: FIRMA DIGITAL — Canvas + Subir imagen
// ─────────────────────────────────────────
class _SignatureTab extends StatefulWidget {
  const _SignatureTab();

  @override
  State<_SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<_SignatureTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Canvas
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  final GlobalKey _canvasKey = GlobalKey();

  // Estado
  String? _savedSignatureUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSignature();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadSignature() async {
    setState(() => _isLoading = true);
    final res = await ProfileService.getSignature();
    if (!mounted) return;
    if (res.containsKey('signature')) {
      setState(() => _savedSignatureUrl = res['signature']['signature_url']);
    }
    setState(() => _isLoading = false);
  }

  // Canvas handlers
  void _onPanStart(Offset p) { _currentStroke = [p]; setState(() => _strokes.add(_currentStroke)); }
  void _onPanUpdate(Offset p) { setState(() => _currentStroke.add(p)); }
  void _onPanEnd() { _currentStroke.add(null); }
  void _clearCanvas() => setState(() { _strokes.clear(); _currentStroke = []; });

  // Guardar desde canvas
  Future<void> _saveFromCanvas() async {
    if (_strokes.isEmpty) {
      await SweetAlert.warning(context, title: 'Dibuja tu firma primero', text: 'Usa el recuadro blanco para trazar tu firma.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final base64Str = 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';
      await _upload(base64Str);
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  // Subir imagen PNG/JPG
  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() => _isSaving = true);
      final mimeType = file.extension == 'png' ? 'image/png' : 'image/jpeg';
      final base64Str = 'data:$mimeType;base64,${base64Encode(file.bytes!)}';
      await _upload(base64Str);
    } catch (e) {
      if (mounted) await SweetAlert.error(context, title: 'Error al subir la imagen', text: '$e');
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  Future<void> _upload(String base64Str) async {
    final res = await ProfileService.saveSignature(base64Str);
    if (!mounted) return;
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo guardar la firma', text: res['error'].toString());
    } else {
      setState(() { _savedSignatureUrl = res['signature_url']; _strokes.clear(); _currentStroke = []; });
      SweetAlert.success(context, title: 'Firma guardada', text: 'Ya puedes firmar documentos.', autoClose: const Duration(seconds: 2));
    }
  }

  Future<void> _deleteSignature() async {
    final ok = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: '¿Eliminar tu firma?',
      text: 'No podrás firmar documentos hasta que registres una nueva.',
      confirmText: 'Sí, eliminar',
    );
    if (!ok || !mounted) return;
    final res = await ProfileService.deleteSignature();
    if (!mounted) return;
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo eliminar', text: res['error'].toString());
    } else {
      setState(() => _savedSignatureUrl = null);
      SweetAlert.success(context, title: 'Firma eliminada', autoClose: const Duration(milliseconds: 1500));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return _TabBody(left: [
      const BSInfoBanner(
        title: 'Tu firma se estampa en los documentos que firmes.',
        text: 'Cada firma queda registrada en la blockchain Sepolia junto con el hash SHA-256 del documento.',
        icon: Icons.verified_user_rounded,
      ),
      const SizedBox(height: 16),

      // Firma guardada
      if (_savedSignatureUrl != null) ...[
        BSCard(
          title: 'Firma actual',
          trailing: const BSPill(label: 'Registrada', color: BSColors.success),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 130, width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFFFFF), // papel blanco: la firma es tinta oscura
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(_savedSignatureUrl!, fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.hint)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: BSOutlineButton(label: 'Eliminar firma', icon: Icons.delete_outline_rounded, color: BSColors.danger, onPressed: _deleteSignature),
            ),
          ]),
        ),
      ] else
        BSCard(
          title: 'Firma actual',
          trailing: BSPill(label: 'Sin registrar', color: BSColors.warning),
          child: Row(children: [
            Icon(Icons.draw_outlined, color: BSColors.warning, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text('Todavía no tienes una firma. Créala en el panel "Crear firma digital" para poder firmar documentos.',
                  style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.45)),
            ),
          ]),
        ),
    ], right: [
      BSCard(
        title: _savedSignatureUrl != null ? 'Actualizar firma' : 'Crear firma digital',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dibuja tu firma o sube una imagen PNG/JPG.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          const SizedBox(height: 14),

          // Tabs: Dibujar / Subir
          Container(
            decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.hint,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.draw_rounded, size: 18), text: 'Dibujar'),
                Tab(icon: Icon(Icons.upload_file_rounded, size: 18), text: 'Subir imagen'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 290,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // ── Canvas ──
                Column(children: [
                  Expanded(
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border, width: 1.5)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          // El recognizer "eager" reclama el gesto para que la página
                          // y las pestañas no se desplacen mientras se dibuja.
                          child: RawGestureDetector(
                            gestures: {
                              EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                                (_) {},
                              ),
                            },
                            child: Listener(
                            onPointerDown: (e) => _onPanStart(e.localPosition),
                            onPointerMove: (e) => _onPanUpdate(e.localPosition),
                            onPointerUp: (_) => _onPanEnd(),
                            onPointerCancel: (_) => _onPanEnd(),
                            child: CustomPaint(
                              painter: _SignaturePainter(_strokes),
                              child: _strokes.isEmpty
                                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.draw_rounded, color: Colors.grey[300], size: 32),
                                      const SizedBox(height: 8),
                                      Text('Dibuja aquí tu firma', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                                    ]))
                                  : const SizedBox.expand(),
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: BSOutlineButton(label: 'Limpiar', icon: Icons.refresh_rounded, color: AppTheme.hint, onPressed: _clearCanvas)),
                    const SizedBox(width: 12),
                    Expanded(child: BSPrimaryButton(label: _isSaving ? 'Guardando...' : 'Guardar firma', icon: Icons.save_rounded, loading: _isSaving, onPressed: _saveFromCanvas)),
                  ]),
                ]),

                // ── Subir imagen ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BSColors.page,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 28)),
                    const SizedBox(height: 12),
                    Text('Sube tu firma como imagen', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Formatos: PNG, JPG\nFondo transparente recomendado (PNG)', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.5)),
                    const SizedBox(height: 18),
                    BSPrimaryButton(label: _isSaving ? 'Subiendo...' : 'Seleccionar imagen', icon: Icons.image_rounded, loading: _isSaving, onPressed: _pickAndUpload),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// SIGNATURE PAINTER
// ─────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1a1a2e)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != null && stroke[i + 1] != null) canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppTheme.primary, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.45))),
      ]),
    );
  }
}


/// Claves de firma del usuario (criptografía asimétrica ECDSA P-256)
class _KeysCard extends StatefulWidget {
  const _KeysCard();

  @override
  State<_KeysCard> createState() => _KeysCardState();
}

class _KeysCardState extends State<_KeysCard> {
  Map<String, dynamic>? _k;
  String? _error;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    ProfileService.getMyKeys().then((r) {
      if (!mounted) return;
      setState(() {
        if (r['error'] != null) {
          _error = r['error'].toString();
        } else {
          _k = r;
        }
      });
    });
  }

  String _group(String fp) {
    final s = fp.toUpperCase();
    final parts = <String>[];
    for (var i = 0; i < s.length && i < 32; i += 4) {
      parts.add(s.substring(i, i + 4 > s.length ? s.length : i + 4));
    }
    return parts.join(' ');
  }

  String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${bsHora(d)}';
  }

  Widget _row(String k, String v, {bool mono = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w600))),
          Flexible(
            child: SelectableText(v,
                textAlign: TextAlign.right,
                style: TextStyle(color: AppTheme.text, fontSize: mono ? 12.5 : 13.5, fontWeight: mono ? FontWeight.w600 : FontWeight.w700, fontFamily: mono ? 'monospace' : null)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final pem = _k?['publicKey']?.toString() ?? '';
    return BSCard(
      title: 'Tus llaves de firma',
      trailing: BSPill(label: 'ECDSA P-256', color: AppTheme.primary, dot: false),
      child: _error != null
          ? BSInfoBanner(title: 'No se pudieron cargar', text: _error, color: BSColors.danger, icon: Icons.error_outline_rounded)
          : _k == null
              ? const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    'Cada firma se hace con tu llave privada, que se guarda cifrada (AES-256-GCM) y nunca sale del servidor. '
                    'Cualquiera puede comprobarla con tu llave pública.',
                    style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  _row('Huella de la llave', _group(_k!['fingerprint']?.toString() ?? ''), mono: true),
                  _row('Creada', _date(_k!['createdAt']?.toString())),
                  _row('Algoritmo', _k!['algorithm']?.toString() ?? 'ECDSA-P256-SHA256', mono: true),
                  const SizedBox(height: 14),
                  // Llave pública en bloque oscuro, con copiar
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
                    decoration: BoxDecoration(color: const Color(0xFF0F1B33), borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text('Llave pública (PEM)', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w700))),
                        IconButton(
                          tooltip: 'Copiar llave pública',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.copy_rounded, size: 16, color: Colors.white.withOpacity(0.75)),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: pem));
                            if (context.mounted) SweetAlert.success(context, title: 'Llave pública copiada', autoClose: const Duration(milliseconds: 1100));
                          },
                        ),
                      ]),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: _showKey ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: Text(
                          pem.split('\n').where((l) => l.trim().isNotEmpty).take(3).join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFB8C7EA), fontSize: 12, fontFamily: 'monospace', height: 1.45),
                        ),
                        secondChild: SelectableText(pem, style: const TextStyle(color: Color(0xFFB8C7EA), fontSize: 12, fontFamily: 'monospace', height: 1.45)),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _showKey = !_showKey),
                          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                          child: Text(_showKey ? 'Ver menos' : 'Ver completa', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const BSInfoBanner(
                    title: '¿Dónde está la criptografía asimétrica?',
                    text: 'Tu llave privada firma y la pública verifica. Además, la billetera del servidor firma la transacción en Ethereum (ECDSA secp256k1).',
                    icon: Icons.key_rounded,
                  ),
                ]),
    );
  }
}
