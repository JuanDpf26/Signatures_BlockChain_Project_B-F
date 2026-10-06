import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/bs_auth_layout.dart';

/// Pantalla de bienvenida. Usa el mismo diseño de las pantallas de acceso:
/// panel de marca a la izquierda en computador; en celular, logo arriba y
/// las características dentro del contenido.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;

    return BSAuthLayout(
      title: 'Bienvenido a BlockSign',
      subtitle: 'Firma documentos con validez legal, protegidos con criptografía y registro inmutable en blockchain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En celular no se ve el panel de marca: mostramos las características aquí
          if (!wide) ...[
            const _Feature(
              icon: Icons.lock_outline_rounded,
              color: AppTheme.primary,
              title: 'Firma con respaldo criptográfico',
              desc: 'Cada firma genera un hash único que garantiza la integridad del documento.',
            ),
            const SizedBox(height: 14),
            const _Feature(
              icon: Icons.link_rounded,
              color: AppTheme.featureCyan,
              title: 'Registro inmutable en blockchain',
              desc: 'La firma queda registrada en Ethereum de forma permanente y verificable.',
            ),
            const SizedBox(height: 14),
            const _Feature(
              icon: Icons.auto_awesome_outlined,
              color: BSColors.warning,
              title: 'Análisis inteligente con IA',
              desc: 'Extrae metadatos y clasifica tus archivos automáticamente.',
            ),
            const SizedBox(height: 24),
          ],

          // Insignias de seguridad
          const Wrap(spacing: 10, runSpacing: 10, children: [
            _StatBadge(label: 'SHA-256', sub: 'Cifrado', color: AppTheme.primary),
            _StatBadge(label: 'Sepolia', sub: 'Blockchain', color: AppTheme.featureCyan),
            _StatBadge(label: 'TLS 1.3', sub: 'Conexión', color: BSColors.success),
          ]),
          const SizedBox(height: 28),

          BSAuthButton(label: 'Iniciar sesión', onPressed: () => Navigator.pushNamed(context, '/login')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                foregroundColor: AppTheme.text,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Crear cuenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 28),

          const BSInfoBanner(
            title: 'Red blockchain activa',
            text: 'Ethereum Sepolia Testnet — verificación pública e instantánea de cada firma.',
            color: BSColors.success,
            icon: Icons.sensors_rounded,
          ),

          if (!wide) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text('Universidad Manuela Beltrán · IS25133 · 2026',
                  style: TextStyle(color: AppTheme.hint, fontSize: 11.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _StatBadge({required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
      ]),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _Feature({required this.icon, required this.color, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, height: 1.4)),
        ]),
      ),
    ]);
  }
}
