import 'package:flutter/material.dart';
import '../theme/app_settings.dart';
import '../theme/app_theme.dart';

/// Abre el menú de apariencia y accesibilidad (hoja inferior en celular,
/// ventana en computador).
Future<void> showAccessibilityMenu(BuildContext context) {
  final wide = MediaQuery.of(context).size.width >= 700;
  if (wide) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const AccessibilityPanel(showClose: true)),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: const AccessibilityPanel(showClose: true),
    ),
  );
}

/// Botón con el ícono de accesibilidad para las barras superiores
class AccessibilityButton extends StatelessWidget {
  final Color? color;
  const AccessibilityButton({super.key, this.color});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Apariencia y accesibilidad',
        onPressed: () => showAccessibilityMenu(context),
        icon: Icon(Icons.accessibility_new_rounded, color: color ?? AppTheme.text),
      );
}

/// Contenido del menú. Se usa también dentro de Mi perfil.
class AccessibilityPanel extends StatelessWidget {
  final bool showClose;
  const AccessibilityPanel({super.key, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (showClose)
              Row(children: [
                Icon(Icons.accessibility_new_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Apariencia y accesibilidad', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppTheme.hint),
                ),
              ]),
            if (showClose) const SizedBox(height: 8),
            _Label('Tema'),
            Row(children: [
              for (final (t, label, icon) in const [
                (AppThemeChoice.light, 'Claro', Icons.light_mode_outlined),
                (AppThemeChoice.dark, 'Oscuro', Icons.dark_mode_outlined),
                (AppThemeChoice.system, 'Sistema', Icons.brightness_auto_outlined),
              ]) ...[
                Expanded(
                  child: _ThemeOption(
                    label: label,
                    icon: icon,
                    choice: t,
                    selected: s.theme == t,
                    onTap: () => s.update(theme: t),
                  ),
                ),
                if (t != AppThemeChoice.system) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 22),
            _Label('Tamaño del texto'),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                Row(children: [
                  Text('A', style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Slider(
                      value: s.textScale,
                      min: 0.9,
                      max: 1.5,
                      divisions: 6,
                      label: '${(s.textScale * 100).round()} %',
                      onChanged: (v) => s.update(textScale: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  Text('A', style: TextStyle(color: AppTheme.hint, fontSize: 24, fontWeight: FontWeight.w700)),
                ]),
                Text('Así se verá el texto (${(s.textScale * 100).round()} %).',
                    style: TextStyle(color: AppTheme.text, fontSize: 14)),
                const SizedBox(height: 6),
              ]),
            ),
            const SizedBox(height: 22),
            _Label('Lectura y movimiento'),
            Container(
              decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                _Toggle(
                  icon: Icons.contrast_rounded,
                  title: 'Alto contraste',
                  subtitle: 'Textos y bordes más marcados',
                  value: s.highContrast,
                  onChanged: (v) => s.update(highContrast: v),
                ),
                Divider(height: 1, color: AppTheme.border),
                _Toggle(
                  icon: Icons.format_bold_rounded,
                  title: 'Texto en negrita',
                  subtitle: 'Letras más gruesas en toda la app',
                  value: s.boldText,
                  onChanged: (v) => s.update(boldText: v),
                ),
                Divider(height: 1, color: AppTheme.border),
                _Toggle(
                  icon: Icons.motion_photos_off_outlined,
                  title: 'Reducir animaciones',
                  subtitle: 'Menos movimiento al abrir pantallas',
                  value: s.reduceMotion,
                  onChanged: (v) => s.update(reduceMotion: v),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text('Tus preferencias se guardan en este dispositivo.', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: s.isDefault ? null : s.reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Restablecer'),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(), style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
      );
}

/// Tarjeta de tema con una miniatura de la interfaz
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.choice, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget mini(Palette p) => Container(
          decoration: BoxDecoration(color: p.page, borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.all(6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 6, width: 26, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 5),
            Container(
              height: 26,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(4), border: Border.all(color: p.border)),
              padding: const EdgeInsets.all(4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 4, width: 34, color: p.text.withOpacity(0.7)),
                const SizedBox(height: 4),
                Container(height: 4, width: 22, color: p.hint.withOpacity(0.6)),
              ]),
            ),
          ]),
        );
    final preview = switch (choice) {
      AppThemeChoice.light => mini(Palette.light),
      AppThemeChoice.dark => mini(Palette.darkPalette),
      AppThemeChoice.system => Row(children: [Expanded(child: mini(Palette.light)), const SizedBox(width: 3), Expanded(child: mini(Palette.darkPalette))]),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: selected ? 2 : 1),
          ),
          child: Column(children: [
            SizedBox(height: 52, child: preview),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: selected ? AppTheme.primary : AppTheme.hint),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: selected ? AppTheme.primary : AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
        secondary: Icon(icon, color: AppTheme.hint),
        title: Text(title, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
      );
}

