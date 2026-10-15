import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemeChoice { light, dark, system }

/// Preferencias de apariencia y accesibilidad. Se guardan en el dispositivo
/// y se aplican a toda la app sin perder la pantalla en la que estás.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_settings_v1';

  AppThemeChoice theme = AppThemeChoice.light;
  double textScale = 1.0; // 1.0 · 1.15 · 1.3 · 1.5
  bool highContrast = false;
  bool reduceMotion = false;
  bool boldText = false;

  /// Tema efectivo (resuelve "Sistema" con la preferencia del dispositivo)
  bool get isDark => switch (theme) {
        AppThemeChoice.dark => true,
        AppThemeChoice.light => false,
        AppThemeChoice.system => SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  bool get isDefault =>
      theme == AppThemeChoice.light && textScale == 1.0 && !highContrast && !reduceMotion && !boldText;

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      theme = AppThemeChoice.values.firstWhere((t) => t.name == m['theme'], orElse: () => AppThemeChoice.light);
      textScale = (m['textScale'] as num?)?.toDouble().clamp(0.9, 1.6) ?? 1.0;
      highContrast = m['highContrast'] == true;
      reduceMotion = m['reduceMotion'] == true;
      boldText = m['boldText'] == true;
    } catch (_) {
      // Preferencias dañadas o almacenamiento no disponible: se usan las de fábrica
    }
  }

  Future<void> _save() async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'theme': theme.name,
          'textScale': textScale,
          'highContrast': highContrast,
          'reduceMotion': reduceMotion,
          'boldText': boldText,
        }),
      );
    } catch (_) {}
  }

  void update({
    AppThemeChoice? theme,
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? boldText,
  }) {
    this.theme = theme ?? this.theme;
    this.textScale = textScale ?? this.textScale;
    this.highContrast = highContrast ?? this.highContrast;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.boldText = boldText ?? this.boldText;
    notifyListeners();
    _save();
  }

  void reset() {
    theme = AppThemeChoice.light;
    textScale = 1.0;
    highContrast = false;
    reduceMotion = false;
    boldText = false;
    notifyListeners();
    _save();
  }

  /// Avisa cuando el dispositivo cambia entre claro y oscuro (modo "Sistema")
  void platformBrightnessChanged() {
    if (theme == AppThemeChoice.system) notifyListeners();
  }
}
