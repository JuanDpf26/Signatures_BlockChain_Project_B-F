import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';

/// Ingreso con huella o rostro (solo celular).
///
/// La app cierra la sesión al cerrarse. Si la persona activa esta opción, se
/// guarda una copia de su sesión en el almacenamiento seguro del teléfono
/// (Keystore / Keychain) y solo se usa después de que el teléfono confirme su
/// huella o su rostro. La sesión dura lo mismo que siempre (7 días); al vencer
/// se pide la contraseña otra vez.
class BiometricService {
  BiometricService._();
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'bio_token';
  static const _askedKey = 'bio_asked';

  /// El teléfono tiene huella o rostro configurado
  static Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// "Huella", "rostro" o "huella o rostro" según el teléfono
  static Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final face = types.contains(BiometricType.face);
      final finger = types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong);
      if (face && !finger) return 'rostro';
      if (finger && !face) return 'huella';
    } catch (_) {}
    return 'huella o rostro';
  }

  static Future<bool> enabled() async {
    if (kIsWeb) return false;
    try {
      final t = await _storage.read(key: _tokenKey);
      return t != null && t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _confirm(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Activa el ingreso: pide la huella/rostro y guarda la sesión actual
  static Future<bool> enable() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;
    if (!await _confirm('Confirma para activar el ingreso rápido en DocBlockSign')) return false;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _askedKey, value: '1');
    return true;
  }

  static Future<void> disable() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Tras iniciar sesión con contraseña o Google: si ya estaba activo, renueva la sesión guardada
  static Future<void> refreshSavedSession() async {
    if (!await enabled()) return;
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) await _storage.write(key: _tokenKey, value: token);
  }

  /// ¿Mostrar la invitación a activarlo? (una sola vez por teléfono)
  static Future<bool> shouldOffer() async {
    if (await enabled() || !await available()) return false;
    try {
      return await _storage.read(key: _askedKey) == null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markOffered() async {
    try {
      await _storage.write(key: _askedKey, value: '1');
    } catch (_) {}
  }

  /// Entra con huella/rostro. Devuelve null si entró, o el motivo si no.
  static Future<String?> login() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null || saved.isEmpty) return 'El ingreso rápido no está activado en este teléfono.';
    if (AuthService.isExpired(saved)) {
      await disable();
      return 'Tu sesión guardada venció. Entra con tu contraseña y vuelve a activar el ingreso rápido.';
    }
    if (!await _confirm('Confirma tu identidad para entrar a DocBlockSign')) return 'cancelado';
    await AuthService.saveToken(saved);
    return null;
  }
}
