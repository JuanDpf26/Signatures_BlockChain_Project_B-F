import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'bs_ui.dart';
import 'sweet_alert.dart';
import 'widgets.dart';

/// Anuncio al iniciar sesión con una cuenta de superusuario.
/// Devuelve true si la persona decide entrar a la consola.
Future<bool> showSuperuserNotice(BuildContext context, {required String name, required String email}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 16),
            Text('Ingreso como superusuario',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(name.isEmpty ? email : '$name · $email', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _line(Icons.space_dashboard_outlined, 'Vas a entrar a la consola de administración, no a la aplicación de usuarios.'),
                _line(Icons.manage_accounts_outlined, 'Puedes ver y gestionar las cuentas, pero nunca el contenido de los documentos.'),
                _line(Icons.history_rounded, 'Todo lo que hagas queda registrado en la auditoría con tu nombre.'),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Entrar a la consola', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ]),
        ),
      ),
    ),
  );
  return r == true;
}

Widget _line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.35))),
      ]),
    );

/// Contraseña temporal: hay que cambiarla antes de entrar. Devuelve true si se cambió.
Future<bool> showForcedPasswordChange(BuildContext context, {required String currentPassword}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ForcedPasswordDialog(currentPassword: currentPassword),
  );
  return r == true;
}

class _ForcedPasswordDialog extends StatefulWidget {
  final String currentPassword;
  const _ForcedPasswordDialog({required this.currentPassword});

  @override
  State<_ForcedPasswordDialog> createState() => _ForcedPasswordDialogState();
}

class _ForcedPasswordDialogState extends State<_ForcedPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ProfileService.changePassword(currentPassword: widget.currentPassword, newPassword: _p1.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['error'] != null) {
      setState(() => _error = r['error'].toString());
      return;
    }
    Navigator.pop(context, true);
    showToast(context, title: 'Contraseña actualizada');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.lock_reset_rounded, color: BSColors.warning, size: 40),
              const SizedBox(height: 12),
              Text('Crea tu contraseña', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Entraste con una contraseña temporal. Antes de usar la consola, cámbiala por una que solo tú conozcas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 18),
              BSTextField(label: 'Nueva contraseña', hint: 'Mínimo 8, con mayúscula y número', controller: _p1, obscureText: true, icon: Icons.lock_outline_rounded, validator: Validators.password),
              const SizedBox(height: 12),
              BSTextField(
                label: 'Repite la contraseña',
                hint: 'Escríbela otra vez',
                controller: _p2,
                obscureText: true,
                icon: Icons.lock_outline_rounded,
                validator: (v) => Validators.confirmPassword(v, _p1.text),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: BSColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar y entrar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Ahora no (cerrar sesión)')),
            ]),
          ),
        ),
      ),
    );
  }
}
