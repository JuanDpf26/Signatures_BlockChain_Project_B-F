import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'sweet_alert.dart';

/// Piezas compartidas para mostrar procesos de blockchain paso a paso
/// (firma de documentos y verificación).

enum ChainStepState { waiting, active, done, error }

class ChainStep {
  final String title;
  final String? detail;
  final ChainStepState state;
  final List<Widget> extra;
  const ChainStep(this.title, {this.detail, this.state = ChainStepState.waiting, this.extra = const []});
}

/// Línea de tiempo vertical con un círculo por paso.
class ChainTimeline extends StatelessWidget {
  final List<ChainStep> steps;
  const ChainTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < steps.length; i++) _StepRow(step: steps[i], index: i, isLast: i == steps.length - 1),
    ]);
  }
}

Color chainStepColor(ChainStepState s) => switch (s) {
      ChainStepState.done => BSColors.success,
      ChainStepState.active => AppTheme.primary,
      ChainStepState.error => BSColors.danger,
      ChainStepState.waiting => const Color(0xFFCBD5E1),
    };

class _StepRow extends StatelessWidget {
  final ChainStep step;
  final int index;
  final bool isLast;
  const _StepRow({required this.step, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = chainStepColor(step.state);
    final waiting = step.state == ChainStepState.waiting;
    // La línea se dibuja con Positioned para que siempre llegue al siguiente paso,
    // sin importar cuánto mida el contenido.
    return Stack(children: [
      if (!isLast)
        Positioned(
          left: 14,
          top: 34,
          bottom: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 2,
            decoration: BoxDecoration(
              color: step.state == ChainStepState.done ? BSColors.success.withOpacity(0.5) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepDot(state: step.state, index: index),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(top: 5, bottom: isLast ? 0 : 18),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: waiting ? 0.55 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.title,
                  style: TextStyle(
                    color: step.state == ChainStepState.error ? BSColors.danger : AppTheme.text,
                    fontSize: 14,
                    fontWeight: step.state == ChainStepState.active ? FontWeight.w800 : FontWeight.w700,
                  )),
              if (step.detail != null) ...[
                const SizedBox(height: 3),
                Text(step.detail!,
                    style: TextStyle(
                        color: step.state == ChainStepState.error ? BSColors.danger : AppTheme.hint, fontSize: 12.5, height: 1.35)),
              ],
              if (step.extra.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...step.extra,
              ],
              if (step.state == ChainStepState.active) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: color,
                    backgroundColor: color.withOpacity(0.12),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
      ]),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final ChainStepState state;
  final int index;
  const _StepDot({required this.state, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = chainStepColor(state);
    Widget inner;
    switch (state) {
      case ChainStepState.done:
        inner = const Icon(Icons.check_rounded, color: Colors.white, size: 17);
        break;
      case ChainStepState.error:
        inner = const Icon(Icons.close_rounded, color: Colors.white, size: 17);
        break;
      case ChainStepState.active:
        inner = const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white));
        break;
      case ChainStepState.waiting:
        inner = Text('${index + 1}', style: const TextStyle(color: AppTheme.hint, fontWeight: FontWeight.w800, fontSize: 12));
    }
    final filled = state != ChainStepState.waiting;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: filled ? color : const Color(0xFFCBD5E1), width: 2),
        boxShadow: state == ChainStepState.active
            ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(state), child: inner)),
    );
  }
}

/// Fila compacta "etiqueta  valor-mono  [copiar] [abrir]".
class ChainValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool shorten;
  final String? url;
  final bool copy;
  const ChainValueRow(
      {super.key, required this.label, required this.value, this.mono = true, this.shorten = true, this.url, this.copy = true});

  @override
  Widget build(BuildContext context) {
    final shown = shorten && value.length > 26 ? '${value.substring(0, 12)}…${value.substring(value.length - 10)}' : value;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              )),
        ),
        if (copy)
          _MiniIcon(
            icon: Icons.copy_rounded,
            tooltip: 'Copiar',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                SweetAlert.success(context, title: '$label copiado', autoClose: const Duration(milliseconds: 1000));
              }
            },
          ),
        if (url != null) _MiniIcon(icon: Icons.open_in_new_rounded, tooltip: 'Ver en Etherscan', onTap: () => openExternal(url!)),
      ]),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 15, color: AppTheme.primary)),
      ),
    );
  }
}

Future<void> openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// "hace 12 s", "hace 3 min"…
String chainElapsed(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  return '${d.inMinutes} min ${d.inSeconds % 60} s';
}

/// Fecha ISO → "6 oct 2026, 14:32:05" (hora local)
String chainDate(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
