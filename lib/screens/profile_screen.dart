import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _user = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final res = await ProfileService.getProfile();
    if (!mounted) return;
    if (res.containsKey('user')) {
      setState(() => _user = res['user']);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final pad = isWeb ? 28.0 : 16.0;

    if (_isLoading) {
      return Container(
        color: BSColors.page,
        child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final stats = (_user['stats'] as Map<String, dynamic>?) ?? {};
    final idx = _tabController.index;

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BSPageHeader(
              breadcrumb: ['Inicio', 'Mi perfil'],
              title: 'Mi perfil',
              subtitle: 'Administra tus datos, la seguridad de tu cuenta y tu firma digital.',
            ),
            const SizedBox(height: 20),

            _ProfileCard(user: _user, isWeb: isWeb, onAvatarUpdated: _loadProfile),
            const SizedBox(height: 12),

            BSKpiRow(items: [
              BSKpiCard(label: 'Documentos', value: '${stats['total_docs'] ?? 0}', caption: 'Subidos', color: AppTheme.primary, icon: Icons.folder_copy_outlined),
              BSKpiCard(label: 'Firmados', value: '${stats['signed_docs'] ?? 0}', caption: 'Con registro en blockchain', color: AppTheme.featureCyan, icon: Icons.draw_outlined),
              BSKpiCard(label: 'Verificados', value: '${stats['verified_docs'] ?? 0}', caption: 'Integridad comprobada', color: BSColors.success, icon: Icons.verified_outlined),
              BSKpiCard(label: 'Almacenamiento', value: '${stats['total_size_mb'] ?? 0}', caption: 'MB usados', color: BSColors.warning, icon: Icons.cloud_outlined),
            ]),
            const SizedBox(height: 20),

            // Pestañas con subrayado
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.hint,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'Información'),
                  Tab(text: 'Seguridad'),
                  Tab(text: 'Mi firma'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Contenido de la pestaña seleccionada
            if (idx == 0) _InfoTab(user: _user, onUpdated: _loadProfile),
            if (idx == 1) _SecurityTab(user: _user),
            if (idx == 2) const _SignatureTab(),
          ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TARJETA DE PERFIL
// ─────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isWeb;
  final VoidCallback onAvatarUpdated;

  const _ProfileCard({required this.user, required this.isWeb, required this.onAvatarUpdated});

  Future<void> _pickAvatar(BuildContext context) async {
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
      onAvatarUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user['avatar_url']?.toString();
    final name = user['name']?.toString() ?? 'Usuario';
    final email = user['email']?.toString() ?? '';
    final isVerified = user['is_email_verified'] == true;
    final isGoogle = user['google_id'] != null;

    final pills = Wrap(spacing: 8, runSpacing: 6, alignment: isWeb ? WrapAlignment.start : WrapAlignment.center, children: [
      isVerified
          ? const BSPill(label: 'Correo verificado', color: BSColors.success)
          : const BSPill(label: 'Correo sin verificar', color: BSColors.warning),
      BSPill(label: isGoogle ? 'Cuenta Google' : 'Cuenta con contraseña', color: isGoogle ? AppTheme.primary : BSColors.neutral),
    ]);

    final info = Column(
      crossAxisAlignment: isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(name, textAlign: isWeb ? TextAlign.start : TextAlign.center,
            style: const TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(email, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        const SizedBox(height: 10),
        pills,
      ],
    );

    final avatar = _AvatarWidget(avatarUrl: avatarUrl, name: name, onTap: () => _pickAvatar(context));

    return BSCard(
      padding: EdgeInsets.all(isWeb ? 24 : 20),
      child: isWeb
          ? Row(children: [
              avatar,
              const SizedBox(width: 20),
              Expanded(child: info),
              BSOutlineButton(label: 'Cambiar foto', icon: Icons.photo_camera_outlined, onPressed: () => _pickAvatar(context)),
            ])
          : Column(children: [avatar, const SizedBox(height: 12), info]),
    );
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
// TAB 1: INFORMACIÓN
// ─────────────────────────────────────────
class _InfoTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUpdated;
  const _InfoTab({required this.user, required this.onUpdated});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user['name'] ?? '';
    _phoneCtrl.text = widget.user['phone'] ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      await SweetAlert.warning(context, title: 'Revisa el nombre', text: 'El nombre debe tener mínimo 2 caracteres.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ProfileService.updateProfile(name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (res.containsKey('error')) {
        await SweetAlert.error(context, title: 'No se pudo guardar', text: res['error'].toString());
      } else {
        SweetAlert.success(context, title: 'Perfil actualizado', autoClose: const Duration(milliseconds: 1500));
        widget.onUpdated();
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final created = widget.user['created_at'] != null
        ? DateTime.tryParse(widget.user['created_at'].toString())?.toLocal()
        : null;
    String two(int n) => n.toString().padLeft(2, '0');

    return _TabBody(left: [
      BSCard(
        title: 'Datos de la cuenta',
        child: BSLabelGrid(items: [
          BSLabelValue(label: 'Correo electrónico', value: widget.user['email']?.toString() ?? '-'),
          BSLabelValue(label: 'Número de cédula', value: widget.user['document_id']?.toString() ?? 'No registrado'),
          BSLabelValue(label: 'Miembro desde', value: created != null ? '${two(created.day)}/${two(created.month)}/${created.year}' : '-'),
          BSLabelValue(label: 'Último acceso', value: widget.user['last_login'] != null
              ? (DateTime.tryParse(widget.user['last_login'].toString())?.toLocal().toString().substring(0, 16) ?? '-')
              : '-'),
        ]),
      ),
      const SizedBox(height: 12),
      const BSInfoBanner(
        title: 'El correo y la cédula no se pueden modificar.',
        text: 'Identifican tu firma en los documentos registrados en blockchain.',
        icon: Icons.lock_outline_rounded,
      ),
    ], right: [
      BSCard(
        title: 'Datos personales',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BSTextField(label: 'Nombre completo', hint: 'Tu nombre', controller: _nameCtrl, icon: Icons.person_outline_rounded, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 16),
          BSTextField(label: 'Teléfono', hint: '3001234567', controller: _phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: BSPrimaryButton(label: 'Guardar cambios', icon: Icons.save_rounded, loading: _isLoading, onPressed: _save),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────
// TAB 2: SEGURIDAD
// ─────────────────────────────────────────
class _SecurityTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const _SecurityTab({required this.user});

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() { _currentPassCtrl.dispose(); _newPassCtrl.dispose(); _confirmPassCtrl.dispose(); super.dispose(); }

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
        await SweetAlert.success(context, title: 'Contraseña actualizada', text: 'Usa tu nueva contraseña la próxima vez que inicies sesión.');
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

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
      await AuthService.logout();
      if (!mounted) return;
      await SweetAlert.success(context, title: 'Cuenta eliminada', text: 'Lamentamos verte partir.', autoClose: const Duration(seconds: 2));
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = widget.user['google_id'] != null;
    return _TabBody(left: [
      if (!isGoogle)
        BSCard(
          title: 'Cambiar contraseña',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BSTextField(label: 'Contraseña actual', hint: '••••••••', controller: _currentPassCtrl, icon: Icons.lock_outline_rounded, obscureText: true),
            const SizedBox(height: 14),
            BSTextField(label: 'Nueva contraseña', hint: '8+ caracteres, mayúscula y número', controller: _newPassCtrl, icon: Icons.lock_reset_rounded, obscureText: true),
            const SizedBox(height: 14),
            BSTextField(label: 'Confirmar nueva contraseña', hint: 'Repite la nueva contraseña', controller: _confirmPassCtrl, icon: Icons.lock_reset_rounded, obscureText: true),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: BSPrimaryButton(label: 'Actualizar contraseña', icon: Icons.key_rounded, loading: _isLoading, onPressed: _changePassword),
            ),
          ]),
        )
      else
        const BSInfoBanner(
          title: 'Tu cuenta usa Google.',
          text: 'La contraseña se gestiona desde tu cuenta de Google.',
        ),
    ], right: [
      const BSCard(
        title: 'Recomendaciones de seguridad',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Tip(icon: Icons.password_rounded, text: 'Usa una contraseña única de al menos 8 caracteres, con mayúsculas y números.'),
          _Tip(icon: Icons.mark_email_read_outlined, text: 'Mantén tu correo verificado: por ahí recibes los enlaces de recuperación.'),
          _Tip(icon: Icons.draw_outlined, text: 'Tu firma solo se aplica cuando confirmas cada documento.'),
          _Tip(icon: Icons.logout_rounded, text: 'Cierra sesión al usar equipos compartidos.'),
        ]),
      ),
      const SizedBox(height: 16),
      BSCard(
        title: 'Zona de peligro',
        borderColor: BSColors.danger.withOpacity(0.35),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Eliminar cuenta', style: TextStyle(color: BSColors.danger, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Se eliminarán permanentemente tu cuenta y todos tus documentos. Las firmas ya registradas en blockchain no se pueden borrar.',
              style: TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          BSOutlineButton(label: 'Eliminar mi cuenta', icon: Icons.delete_outline_rounded, color: BSColors.danger, onPressed: _deleteAccount),
        ]),
      ),
    ]);
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
      return const Padding(
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(_savedSignatureUrl!, fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.hint)),
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
        const BSCard(
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
          const Text('Dibuja tu firma o sube una imagen PNG/JPG.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border, width: 1.5)),
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
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 28)),
                    const SizedBox(height: 12),
                    const Text('Sube tu firma como imagen', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Formatos: PNG, JPG\nFondo transparente recomendado (PNG)', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.5)),
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
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 13, height: 1.45))),
      ]),
    );
  }
}
