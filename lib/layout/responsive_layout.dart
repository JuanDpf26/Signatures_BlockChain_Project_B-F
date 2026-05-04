import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  static bool isWeb(BuildContext context) =>
      MediaQuery.of(context).size.width > 600;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    if (!isWide) return child;

    return Row(
      children: [
        // Panel izquierdo decorativo solo en web
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0f0f1a), Color(0xFF1a1a3e)],
              ),
            ),
            child: Stack(
              children: [
                // Círculos decorativos
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366f1).withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  right: -60,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF06b6d4).withOpacity(0.06),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366f1), Color(0xFF06b6d4)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'BlockSign',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Firma digital segura\nimpulsada por blockchain.',
                          style: TextStyle(
                            color: Color(0xFF9ca3af),
                            fontSize: 18,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                        _WebFeature(
                          icon: Icons.lock_rounded,
                          color: const Color(0xFF6366f1),
                          title: 'Criptografía asimétrica',
                          desc: 'PKI + SHA-256 para máxima seguridad',
                        ),
                        const SizedBox(height: 20),
                        _WebFeature(
                          icon: Icons.link_rounded,
                          color: const Color(0xFF06b6d4),
                          title: 'Trazabilidad blockchain',
                          desc: 'Registro inmutable de cada firma',
                        ),
                        const SizedBox(height: 20),
                        _WebFeature(
                          icon: Icons.verified_rounded,
                          color: Colors.green,
                          title: 'Validez legal',
                          desc: 'Cumple estándares internacionales',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panel derecho — contenido de la pantalla
        Container(
          width: maxWidth,
          color: const Color(0xFF0f0f1a),
          child: child,
        ),
      ],
    );
  }
}

class _WebFeature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _WebFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text(desc,
                style: const TextStyle(
                    color: Color(0xFF6b7280), fontSize: 12)),
          ],
        ),
      ],
    );
  }
}