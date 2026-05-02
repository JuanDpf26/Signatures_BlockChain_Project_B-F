import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ────────────────────────────────────────────────
// SHOW BOTTOM SHEET (showBS)
// ────────────────────────────────────────────────
void showBS(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppTheme.error : AppTheme.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isError ? AppTheme.error.withOpacity(0.3) : AppTheme.success.withOpacity(0.3),
        ),
      ),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
    ),
  );
}

// ────────────────────────────────────────────────
// BS TEXT FIELD — con validación, icono, toggle contraseña
// ────────────────────────────────────────────────
class BSTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const BSTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.icon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<BSTextField> createState() => _BSTextFieldState();
}

class _BSTextFieldState extends State<BSTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(color: AppTheme.text, fontSize: 15),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.icon != null
            ? Icon(widget.icon, color: AppTheme.hint, size: 20)
            : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.hint,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}

// ────────────────────────────────────────────────
// BS CAPTCHA WIDGET
// Integra hCaptcha — añade el paquete: h_captcha_flutter
// Mientras no lo tengas, este widget simula la verificación
// ────────────────────────────────────────────────
class BSCaptchaWidget extends StatefulWidget {
  final void Function(String token) onVerified;

  const BSCaptchaWidget({super.key, required this.onVerified});

  @override
  State<BSCaptchaWidget> createState() => _BSCaptchaWidgetState();
}

class _BSCaptchaWidgetState extends State<BSCaptchaWidget> {
  bool _verified = false;

  // TODO: Reemplazar con hCaptcha real:
  // HCaptcha(
  //   apiKey: 'TU_HCAPTCHA_SITE_KEY',
  //   onVerify: (token) => widget.onVerified(token),
  // )
  void _simulate() {
    setState(() => _verified = true);
    // En producción, este token viene del widget de hCaptcha
    widget.onVerified('simulated_captcha_token_dev');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _verified ? AppTheme.success.withOpacity(0.4) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _verified ? null : _simulate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _verified ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: _verified ? AppTheme.success : AppTheme.hint,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _verified
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _verified ? 'Verificado ✓' : 'No soy un robot',
              style: TextStyle(
                color: _verified ? AppTheme.success : AppTheme.text,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // Logo hCaptcha
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('hCaptcha', style: TextStyle(color: AppTheme.hint, fontSize: 10)),
              const Text('Privacidad primero', style: TextStyle(color: Color(0xFF4b5563), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEATURE CARD (para WelcomeScreen)
// ────────────────────────────────────────────────
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(description, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// Divider y Google Button (compatibilidad)
class BSDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('o', style: TextStyle(color: AppTheme.hint)),
        ),
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}