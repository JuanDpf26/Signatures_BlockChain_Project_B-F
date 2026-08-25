import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../layout/responsive_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveLayout.isWeb(context);

    if (isWeb) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          children: [
            Expanded(child: _LeftPanel()),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: _RightPanel(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(child: _MobileContent()),
    );
  }
}

// ─────────────────────────────────────────
// PANEL IZQUIERDO
// ─────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
          Positioned(top: -80, left: -80, child: _Circle(300, const Color(0xFF6366f1), 0.06)),
          Positioned(bottom: -60, right: -60, child: _Circle(250, const Color(0xFF06b6d4), 0.05)),

          SingleChildScrollView(
            padding: const EdgeInsets.all(52),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BlockSign', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Firma digital blockchain', style: TextStyle(color: Color(0xFF6b7280), fontSize: 11)),
                    ]),
                  ]),
                  const SizedBox(height: 40),

                  // Título
                  const Text(
                    'Firma documentos\ncon validez legal',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Protege tus documentos con criptografía\nde extremo a extremo y registro inmutable.',
                    style: TextStyle(color: Color(0xFF9ca3af), fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 36),

                  // Stats blockchain
                  Row(children: [
                    _StatBadge(label: 'SHA-256', sub: 'Cifrado'),
                    const SizedBox(width: 12),
                    _StatBadge(label: 'Sepolia', sub: 'Blockchain', color: const Color(0xFF06b6d4)),
                    const SizedBox(width: 12),
                    _StatBadge(label: 'TLS 1.3', sub: 'Conexión', color: Colors.green),
                  ]),
                  const SizedBox(height: 36),

                  // Features — descripción funcional
                  _Feature(
                    icon: Icons.lock_outline_rounded,
                    color: AppTheme.primary,
                    title: 'Firma con respaldo criptográfico',
                    desc: 'Cada firma genera un hash único que garantiza la integridad del documento.',
                  ),
                  const SizedBox(height: 20),
                  _Feature(
                    icon: Icons.link_rounded,
                    color: const Color(0xFF06b6d4),
                    title: 'Registro inmutable en blockchain',
                    desc: 'La firma queda registrada en Ethereum de forma permanente y verificable.',
                  ),
                  const SizedBox(height: 20),
                  _Feature(
                    icon: Icons.verified_outlined,
                    color: Colors.green,
                    title: 'Verifica la autenticidad al instante',
                    desc: 'Cualquier persona puede comprobar que un documento es auténtico y no fue alterado.',
                  ),
                  const SizedBox(height: 20),
                  _Feature(
                    icon: Icons.auto_awesome_outlined,
                    color: Colors.orange,
                    title: 'Análisis inteligente de documentos',
                    desc: 'La IA extrae metadatos, genera descripciones y clasifica tus archivos automáticamente.',
                  ),
                  const SizedBox(height: 48),

                  // Banner online
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 8),
                      Text('Red blockchain activa — Ethereum Sepolia Testnet',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 32),

                  const Text('Universidad Manuela Beltrán · IS25133 · 2026',
                      style: TextStyle(color: Color(0xFF374151), fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PANEL DERECHO
// ─────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bienvenido', style: TextStyle(color: AppTheme.text, fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Sistema de firma digital segura', style: TextStyle(color: AppTheme.hint, fontSize: 14)),
              const SizedBox(height: 32),

              // Botón principal
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Iniciar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),

              // Botón secundario
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    foregroundColor: AppTheme.text,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Crear cuenta', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 40),

              // Info cards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(children: [
                  _InfoRow(icon: Icons.security_rounded, text: 'Tus documentos cifrados con SHA-256'),
                  SizedBox(height: 10),
                  _InfoRow(icon: Icons.link_rounded, text: 'Firma registrada en blockchain permanentemente'),
                  SizedBox(height: 10),
                  _InfoRow(icon: Icons.verified_rounded, text: 'Verificación pública e instantánea'),
                ]),
              ),

              const SizedBox(height: 32),
              const Center(
                child: Text('Universidad Manuela Beltrán · 2026',
                    style: TextStyle(color: Color(0xFF4b5563), fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MOBILE
// ─────────────────────────────────────────
class _MobileContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            const Text('BlockSign', style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 32),
          const Text('Firma documentos\ncon validez legal', style: TextStyle(color: AppTheme.text, fontSize: 28, fontWeight: FontWeight.w600, height: 1.25)),
          const SizedBox(height: 12),
          const Text('Protege tus documentos con criptografía de extremo a extremo y registro inmutable en blockchain.', style: TextStyle(color: AppTheme.hint, fontSize: 14, height: 1.6)),
          const SizedBox(height: 32),

          _Feature(icon: Icons.lock_outline_rounded, color: AppTheme.primary, title: 'Firma con respaldo criptográfico', desc: 'Hash único que garantiza la integridad del documento.'),
          const SizedBox(height: 16),
          _Feature(icon: Icons.link_rounded, color: const Color(0xFF06b6d4), title: 'Registro inmutable en blockchain', desc: 'Firma registrada en Ethereum de forma permanente.'),
          const SizedBox(height: 16),
          _Feature(icon: Icons.verified_outlined, color: Colors.green, title: 'Verificación al instante', desc: 'Comprueba que un documento es auténtico sin alterar.'),
          const SizedBox(height: 40),

          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Iniciar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.border), foregroundColor: AppTheme.text, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Crear cuenta', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// WIDGETS HELPER
// ─────────────────────────────────────────
class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Circle(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)));
  }
}

class _StatBadge extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _StatBadge({required this.label, required this.sub, this.color = const Color(0xFF6366f1)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(color: Color(0xFF6b7280), fontSize: 10)),
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
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12, height: 1.4)),
      ])),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.primary, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: AppTheme.hint, fontSize: 12))),
    ]);
  }
}