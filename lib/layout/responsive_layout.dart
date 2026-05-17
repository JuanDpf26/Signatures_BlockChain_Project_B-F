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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (!isWide) return child;

    // Cada panel ocupa exactamente el 50% de la pantalla
    final panelWidth = screenWidth * 0.50;

    return Row(
      children: [
        // ── Panel izquierdo (50%) ──────────────────────
        SizedBox(
          width: panelWidth,
          height: screenHeight,
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
                // Círculo decorativo superior izquierdo
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366f1).withOpacity(0.08),
                    ),
                  ),
                ),
                // Círculo decorativo inferior derecho
                Positioned(
                  bottom: -80,
                  right: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF06b6d4).withOpacity(0.07),
                    ),
                  ),
                ),
                // Círculo decorativo central
                Positioned(
                  top: screenHeight * 0.35,
                  left: panelWidth * 0.6,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366f1).withOpacity(0.04),
                    ),
                  ),
                ),

                // Contenido con scroll
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 52, vertical: 56),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366f1), Color(0xFF06b6d4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366f1).withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Título
                        const Text(
                          'BlockSign',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Subtítulo
                        const Text(
                          'Firma digital segura\nimpulsada por blockchain.',
                          style: TextStyle(
                            color: Color(0xFF9ca3af),
                            fontSize: 20,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 52),

                        // Features
                        _WebFeature(
                          icon: Icons.lock_rounded,
                          color: const Color(0xFF6366f1),
                          title: 'Criptografía asimétrica',
                          desc: 'PKI + SHA-256 para máxima seguridad',
                        ),
                        const SizedBox(height: 24),
                        _WebFeature(
                          icon: Icons.link_rounded,
                          color: const Color(0xFF06b6d4),
                          title: 'Trazabilidad blockchain',
                          desc: 'Registro inmutable de cada firma',
                        ),
                        const SizedBox(height: 24),
                        _WebFeature(
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF22c55e),
                          title: 'Validez legal',
                          desc: 'Cumple estándares internacionales',
                        ),
                        const SizedBox(height: 52),

                        // Footer
                        const Text(
                          'Universidad Manuela Beltrán · 2025',
                          style: TextStyle(
                            color: Color(0xFF4b5563),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Panel derecho (50%) ──────────────────────
        SizedBox(
          width: panelWidth,
          height: screenHeight,
          child: Container(
            color: const Color(0xFF0f0f1a),
            child: child,
          ),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF6b7280),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}