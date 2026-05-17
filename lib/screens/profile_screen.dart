import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
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

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : Column(
            children: [
              // Header perfil
              _ProfileHeader(
                user: _user,
                isWeb: isWeb,
                onAvatarUpdated: _loadProfile,
              ),

              // Tabs
              Container(
                color: AppTheme.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.hint,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Información'),
                    Tab(text: 'Seguridad'),
                    Tab(text: 'Mi Firma'),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _InfoTab(user: _user, onUpdated: _loadProfile),
                    _SecurityTab(user: _user),
                    const _SignatureTab(),
                  ],
                ),
              ),
            ],
          );
  }
}

// ─────────────────────────────────────────
// HEADER CON AVATAR Y STATS
// ─────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isWeb;
  final VoidCallback onAvatarUpdated;

  const _ProfileHeader({
    required this.user,
    required this.isWeb,
    required this.onAvatarUpdated,
  });

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';

    final res = await ProfileService.uploadAvatar(bytes, mimeType);
    if (!context.mounted) return;

    if (res.containsKey('error')) {
      showBS(context, res['error'], isError: true);
    } else {
      showBS(context, 'Foto actualizada');
      onAvatarUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = (user['stats'] as Map<String, dynamic>?) ?? {};
    final avatarUrl = user['avatar_url']?.toString();
    final name = user['name']?.toString() ?? 'Usuario';
    final email = user['email']?.toString() ?? '';
    final isVerified = user['is_email_verified'] == true;

    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      color: AppTheme.surface,
      child: isWeb
          ? Row(
              children: [
                _AvatarWidget(avatarUrl: avatarUrl, name: name, onTap: () => _pickAvatar(context)),
                const SizedBox(width: 24),
                Expanded(child: _UserInfo(name: name, email: email, isVerified: isVerified)),
                const SizedBox(width: 32),
                _StatsRow(stats: stats),
              ],
            )
          : Column(
              children: [
                _AvatarWidget(avatarUrl: avatarUrl, name: name, onTap: () => _pickAvatar(context)),
                const SizedBox(height: 12),
                _UserInfo(name: name, email: email, isVerified: isVerified),
                const SizedBox(height: 20),
                _StatsRow(stats: stats),
              ],
            ),
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
      child: Stack(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 32, fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfo extends StatelessWidget {
  final String name;
  final String email;
  final bool isVerified;

  const _UserInfo({required this.name, required this.email, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(name,
            style: const TextStyle(
                color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(email, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVerified ? Icons.verified_rounded : Icons.warning_rounded,
              color: isVerified ? Colors.green : Colors.orange,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isVerified ? 'Correo verificado' : 'Correo no verificado',
              style: TextStyle(
                  color: isVerified ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatItem(label: 'Documentos', value: '${stats['total_docs'] ?? 0}', color: AppTheme.primary),
        _divider(),
        _StatItem(label: 'Firmados', value: '${stats['signed_docs'] ?? 0}', color: AppTheme.featureCyan),
        _divider(),
        _StatItem(label: 'Verificados', value: '${stats['verified_docs'] ?? 0}', color: Colors.green),
        _divider(),
        _StatItem(label: 'MB usados', value: '${stats['total_size_mb'] ?? 0}', color: Colors.orange),
      ],
    );
  }

  Widget _divider() => Container(
        height: 30, width: 1,
        color: AppTheme.border,
        margin: const EdgeInsets.symmetric(horizontal: 16),
      );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
      ],
    );
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
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      showBS(context, 'El nombre debe tener mínimo 2 caracteres', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ProfileService.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(context, 'Perfil actualizado');
        widget.onUpdated();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Datos personales'),
          const SizedBox(height: 16),

          BSTextField(
            label: 'Nombre completo',
            hint: 'Tu nombre',
            controller: _nameCtrl,
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Email (solo lectura)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: AppTheme.hint, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Correo electrónico',
                        style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                    Text(widget.user['email'] ?? '',
                        style: const TextStyle(color: AppTheme.text, fontSize: 15)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded, color: AppTheme.hint, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Documento (solo lectura)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppTheme.hint, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Número de cédula',
                        style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                    Text(widget.user['document_id'] ?? 'No registrado',
                        style: const TextStyle(color: AppTheme.text, fontSize: 15)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded, color: AppTheme.hint, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),

          BSTextField(
            label: 'Teléfono',
            hint: '3001234567',
            controller: _phoneCtrl,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar cambios',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
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
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      showBS(context, 'Las contraseñas no coinciden', isError: true);
      return;
    }
    if (_newPassCtrl.text.length < 8 ||
        !_newPassCtrl.text.contains(RegExp(r'[A-Z]')) ||
        !_newPassCtrl.text.contains(RegExp(r'[0-9]'))) {
      showBS(context, 'La contraseña debe tener 8+ caracteres, una mayúscula y un número',
          isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ProfileService.changePassword(
        currentPassword: _currentPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(context, 'Contraseña actualizada exitosamente');
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Eliminar cuenta',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
        content: const Text(
            'Esta acción es permanente e irreversible. Se eliminarán todos tus documentos, firmas y datos.',
            style: TextStyle(color: AppTheme.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar mi cuenta',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await ProfileService.deleteAccount();
    if (!mounted) return;
    if (res.containsKey('error')) {
      showBS(context, res['error'], isError: true);
    } else {
      await AuthService.logout();
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final isGoogleAccount = widget.user['google_id'] != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isGoogleAccount) ...[
            const _SectionTitle('Cambiar contraseña'),
            const SizedBox(height: 16),

            BSTextField(
              label: 'Contraseña actual',
              hint: '••••••••',
              controller: _currentPassCtrl,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            BSTextField(
              label: 'Nueva contraseña',
              hint: '8+ chars, mayúscula y número',
              controller: _newPassCtrl,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 14),
            BSTextField(
              label: 'Confirmar nueva contraseña',
              hint: 'Repite la nueva contraseña',
              controller: _confirmPassCtrl,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Actualizar contraseña',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.hint),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu cuenta usa Google para iniciar sesión. La contraseña se gestiona desde tu cuenta Google.',
                      style: TextStyle(color: AppTheme.hint, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Zona de peligro
          const _SectionTitle('Zona de peligro'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Eliminar cuenta',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Esta acción eliminará permanentemente tu cuenta y todos tus documentos.',
                  style: TextStyle(color: AppTheme.hint, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Eliminar mi cuenta',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// TAB 3: FIRMA DIGITAL (Canvas)
// ─────────────────────────────────────────
class _SignatureTab extends StatefulWidget {
  const _SignatureTab();

  @override
  State<_SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<_SignatureTab> {
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  String? _savedSignatureBase64;
  bool _isLoading = true;
  bool _isSaving = false;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSignature();
  }

  Future<void> _loadSignature() async {
    setState(() => _isLoading = true);
    final res = await ProfileService.getSignature();
    if (!mounted) return;
    if (res.containsKey('signature')) {
      setState(() => _savedSignatureBase64 = res['signature']['signatureBase64']);
    }
    setState(() => _isLoading = false);
  }

  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
    setState(() => _strokes.add(_currentStroke));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    _currentStroke.add(null); // separador de trazo
  }

  void _clear() => setState(() { _strokes.clear(); _currentStroke = []; });

  Future<void> _save() async {
    if (_strokes.isEmpty) {
      showBS(context, 'Dibuja tu firma primero', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Capturar canvas como imagen
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final base64 = 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';

      final res = await ProfileService.saveSignature(base64);
      if (!mounted) return;

      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(context, 'Firma guardada exitosamente');
        setState(() => _savedSignatureBase64 = base64);
        _clear();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSignature() async {
    final res = await ProfileService.deleteSignature();
    if (!mounted) return;
    if (res.containsKey('error')) {
      showBS(context, res['error'], isError: true);
    } else {
      showBS(context, 'Firma eliminada');
      setState(() => _savedSignatureBase64 = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Firma guardada
          if (_savedSignatureBase64 != null) ...[
            const _SectionTitle('Firma guardada'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      const Text('Firma registrada',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _deleteSignature,
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_savedSignatureBase64!.split(',').last),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Canvas para nueva firma
          const _SectionTitle('Dibuja tu firma'),
          const SizedBox(height: 8),
          const Text(
            'Usa el mouse o tu dedo para dibujar tu firma en el área de abajo.',
            style: TextStyle(color: AppTheme.hint, fontSize: 13),
          ),
          const SizedBox(height: 16),

          RepaintBoundary(
            key: _canvasKey,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _SignaturePainter(_strokes),
                    child: _strokes.isEmpty
                        ? const Center(
                            child: Text(
                              'Dibuja tu firma aquí',
                              style: TextStyle(color: Color(0xFFcccccc), fontSize: 14),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    foregroundColor: AppTheme.hint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Limpiar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar firma',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        if (stroke[i] != null && stroke[i + 1] != null) {
          canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ─────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.hint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}