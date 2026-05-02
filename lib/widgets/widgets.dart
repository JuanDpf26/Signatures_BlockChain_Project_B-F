import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ═════════════════════════════════════════════════════
/// TEXT FIELD
/// ═════════════════════════════════════════════════════
class BSTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;

  const BSTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: AppTheme.text),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// ═════════════════════════════════════════════════════
/// GOOGLE BUTTON
/// ═════════════════════════════════════════════════════
class BSGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const BSGoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        onPressed: onPressed,
        child: const Text("Continuar con Google"),
      ),
    );
  }
}

/// ═════════════════════════════════════════════════════
/// DIVIDER
/// ═════════════════════════════════════════════════════
class BSDivider extends StatelessWidget {
  const BSDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white24)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text("o", style: TextStyle(color: AppTheme.hint)),
        ),
        Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

/// ═════════════════════════════════════════════════════
/// FEATURE CARD (🔥 ESTE ERA EL PROBLEMA)
/// ═════════════════════════════════════════════════════
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.text,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(color: AppTheme.hint)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// ═════════════════════════════════════════════════════
/// SNACKBAR (🔥 ESTE ERA EL OTRO ERROR)
/// ═════════════════════════════════════════════════════
void showBS(BuildContext context, String msg,
    {bool isError = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppTheme.error : AppTheme.success,
    ),
  );
}