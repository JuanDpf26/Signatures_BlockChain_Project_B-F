class Validators {
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'El nombre es requerido';
    if (value.trim().length < 2) return 'El nombre debe tener mínimo 2 caracteres';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo es requerido';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Ingresa un correo válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Debe contener al menos una mayúscula';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Debe contener al menos un número';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? documentId(String? value) {
    if (value == null || value.trim().isEmpty) return 'El documento es requerido';
    if (!RegExp(r'^\d{6,12}$').hasMatch(value.trim())) {
      return 'Documento inválido (6-12 dígitos)';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'El teléfono es requerido';
    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
      return 'Teléfono inválido (10 dígitos)';
    }
    return null;
  }
}