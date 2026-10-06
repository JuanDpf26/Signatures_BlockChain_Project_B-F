import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../screens/document_viewer_screen.dart';
import '../services/agent_service.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'signing_progress_dialog.dart';
import 'sweet_alert.dart';

// ─────────────────────────────────────────────────────────────
// SIGN IA — asistente con IA (plus de BlockSign)
// Botón flotante + panel de chat. El agente consulta tus documentos,
// los revisa antes de firmar, responde preguntas y verifica huellas.
// ─────────────────────────────────────────────────────────────

const _iaA = Color(0xFF6C63E0); // violeta
const _iaB = Color(0xFF2F6BDB); // azul BlockSign
const _iaC = Color(0xFF1499AE); // cian
const _iaGradient = LinearGradient(colors: [_iaA, _iaB, _iaC], begin: Alignment.topLeft, end: Alignment.bottomRight);

/// Mensaje del chat (se guarda mientras la app esté abierta)
class _Msg {
  final String role; // user | assistant | error
  final String text;
  final List<Map<String, dynamic>> steps;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> cards;
  _Msg(this.role, this.text, {this.steps = const [], this.actions = const [], this.cards = const []});
}

class _SignIaMemory {
  static final List<_Msg> messages = [];
}

/// Borra la conversación (al cerrar sesión)
void resetSignIa() => _SignIaMemory.messages.clear();

/// Abre el asistente. En pantallas anchas como panel lateral, en celular a pantalla casi completa.
Future<void> showSignIa(
  BuildContext context, {
  required ValueChanged<int> onNavigate,
  String? prompt,
  String? documentId,
  String? documentTitle,
}) {
  final size = MediaQuery.of(context).size;
  final panel = SignIaPanel(onNavigate: onNavigate, initialPrompt: prompt, documentId: documentId, documentTitle: documentTitle);

  if (size.width >= 760) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar Sign IA',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Material(
            color: Colors.white,
            elevation: 18,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: math.min(440, size.width - 28), height: size.height - 28, child: panel),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(ctx).size.height * 0.92,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        clipBehavior: Clip.antiAlias,
        child: panel,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// BOTÓN FLOTANTE
// ─────────────────────────────────────────────────────────────
class SignIaFab extends StatefulWidget {
  final VoidCallback onTap;
  final bool extended;
  const SignIaFab({super.key, required this.onTap, this.extended = true});

  @override
  State<SignIaFab> createState() => _SignIaFabState();
}

class _SignIaFabState extends State<SignIaFab> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  bool _hover = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final glow = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi));
            return AnimatedScale(
              scale: _hover ? 1.06 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: widget.extended ? 18 : 0),
                constraints: const BoxConstraints(minWidth: 56),
                decoration: BoxDecoration(
                  gradient: SweepGradient(
                    colors: const [_iaA, _iaB, _iaC, _iaA],
                    transform: GradientRotation(_c.value * 2 * math.pi),
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: _iaA.withOpacity(glow), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 6))],
                ),
                child: child,
              ),
            );
          },
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
            if (widget.extended) ...[
              const SizedBox(width: 10),
              const Text('Sign IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL DE CHAT
// ─────────────────────────────────────────────────────────────
class SignIaPanel extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final String? initialPrompt;
  final String? documentId;
  final String? documentTitle;
  const SignIaPanel({super.key, required this.onNavigate, this.initialPrompt, this.documentId, this.documentTitle});

  @override
  State<SignIaPanel> createState() => _SignIaPanelState();
}

class _SignIaPanelState extends State<SignIaPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _thinking = false;
  int _hint = 0;
  Timer? _hintTimer;

  List<_Msg> get _msgs => _SignIaMemory.messages;

  static const _hints = [
    'Pensando…',
    'Revisando tus documentos…',
    'Consultando la información…',
    'Preparando la respuesta…',
  ];

  static const _suggestions = [
    (Icons.pending_actions_rounded, '¿Qué documentos tengo pendientes de firmar?'),
    (Icons.fact_check_rounded, 'Revisa mi documento más reciente antes de firmarlo'),
    (Icons.insights_rounded, 'Dame un resumen de mi cuenta'),
    (Icons.hub_rounded, '¿Cómo funciona la verificación en blockchain?'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initialPrompt!));
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg('user', text));
      _thinking = true;
      _hint = 0;
    });
    _toBottom();
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _hint = (_hint + 1) % _hints.length);
    });

    final history = _msgs
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
    final res = await AgentService.chat(history, documentId: widget.documentId, documentTitle: widget.documentTitle);
    _hintTimer?.cancel();
    if (!mounted) return;

    List<Map<String, dynamic>> list(dynamic v) =>
        v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

    setState(() {
      _thinking = false;
      if (res['error'] != null && res['reply'] == null) {
        _msgs.add(_Msg('error', res['error'].toString()));
      } else {
        _msgs.add(_Msg('assistant', res['reply']?.toString() ?? '',
            steps: list(res['steps']), actions: list(res['actions']), cards: list(res['cards'])));
      }
    });
    _toBottom();
  }

  Future<void> _runAction(Map<String, dynamic> a) async {
    final type = a['type'];
    final nav = Navigator.of(context);
    if (type == 'go_verify') {
      nav.pop();
      widget.onNavigate(2);
    } else if (type == 'open_document') {
      final res = await DocumentService.getDocument(a['documentId'].toString());
      final doc = res['document'];
      if (!mounted) return;
      if (doc is! Map) {
        SweetAlert.error(context, title: 'No se pudo abrir', text: res['error']?.toString());
        return;
      }
      final meta = Map<String, dynamic>.from((doc['metadata'] as Map?) ?? {});
      nav.push(MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          fileUrl: doc['file_url']?.toString() ?? '',
          title: doc['title']?.toString() ?? 'Documento',
          extension: (meta['extension'] ?? 'pdf').toString(),
          metadata: {
            ...meta,
            'id': doc['id'],
            'title': doc['title'],
            'status': doc['status'],
            'created_at': doc['created_at'],
            'file_hash': doc['file_hash'],
            'blockchain_tx': doc['blockchain_tx'],
            'file_url': doc['file_url'],
          },
        ),
      ));
    } else if (type == 'sign_document') {
      final id = a['documentId'].toString();
      final title = a['title']?.toString() ?? 'el documento';
      final ok = await SweetAlert.confirm(
        context,
        title: 'Firmar documento',
        text: '¿Firmar "$title" con tu firma registrada? Quedará registrado en la blockchain Sepolia.',
        confirmText: 'Sí, firmar',
      );
      if (!ok || !mounted) return;
      final signed = await showSigningProgress(context, docId: id, docTitle: title);
      if (signed && mounted) {
        SweetAlert.success(context, title: '¡Documento firmado!', text: '"$title" quedó registrado en blockchain.');
        setState(() => _msgs.add(_Msg('assistant', '✅ Listo, **$title** quedó firmado y registrado en la blockchain.')));
        _toBottom();
      }
    }
  }

  void _clear() => setState(() => _msgs.clear());

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      Expanded(
        child: Container(
          color: const Color(0xFFF7F8FC),
          child: _msgs.isEmpty && !_thinking
              ? _welcome()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  itemCount: _msgs.length + (_thinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) return _ThinkingBubble(text: _hints[_hint]);
                    return _MessageView(msg: _msgs[i], onAction: _runAction);
                  },
                ),
        ),
      ),
      _composer(),
    ]);
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(gradient: _iaGradient),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Sign IA', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(6)),
                child: const Text('PLUS', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
            ]),
            Text(
              widget.documentTitle != null ? 'Hablando sobre: ${widget.documentTitle}' : 'Tu asistente de documentos y firmas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ]),
        ),
        if (_msgs.isNotEmpty)
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: _thinking ? null : _clear,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _welcome() {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: _iaGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _iaA.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
        ),
      ),
      const SizedBox(height: 16),
      const Text('¿En qué te ayudo hoy?',
          textAlign: TextAlign.center, style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text(
        'Busco tus documentos, los reviso antes de que firmes, respondo preguntas sobre su contenido y verifico firmas en blockchain.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.45),
      ),
      const SizedBox(height: 22),
      if (widget.documentId != null) ...[
        _SuggestionTile(icon: Icons.fact_check_rounded, text: 'Revisa este documento antes de firmarlo', onTap: () => _send('Revisa este documento antes de firmarlo')),
        _SuggestionTile(icon: Icons.summarize_rounded, text: '¿De qué trata este documento?', onTap: () => _send('¿De qué trata este documento?')),
      ],
      for (final s in _suggestions) _SuggestionTile(icon: s.$1, text: s.$2, onTap: () => _send(s.$2)),
      const SizedBox(height: 14),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 13, color: AppTheme.hint),
        SizedBox(width: 6),
        Flexible(
          child: Text('Solo ve tus documentos. Nunca firma ni borra sin tu confirmación.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 11.5)),
        ),
      ]),
    ]);
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.of(context).padding.bottom * 0.5),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _input,
            focusNode: _focus,
            enabled: !_thinking,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Pregúntale algo a Sign IA…',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _thinking ? null : () => _send(),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _thinking ? 0.5 : 1,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(gradient: _iaGradient, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────
class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _SuggestionTile({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Icon(icon, size: 18, color: _iaA),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w600))),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.hint),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final _Msg msg;
  final Future<void> Function(Map<String, dynamic>) onAction;
  const _MessageView({required this.msg, required this.onAction});

  @override
  Widget build(BuildContext context) {
    if (msg.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_iaB, _iaA]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
          ),
          child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
        ),
      );
    }

    final isError = msg.role == 'error';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(gradient: isError ? null : _iaGradient, color: isError ? BSColors.danger : null, shape: BoxShape.circle),
          child: Icon(isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msg.steps.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in msg.steps) _StepChip(step: s)]),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isError ? BSColors.danger.withOpacity(0.06) : Colors.white,
                border: Border.all(color: isError ? BSColors.danger.withOpacity(0.25) : AppTheme.border),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: _RichText(text: msg.text, color: isError ? BSColors.danger : AppTheme.text),
            ),
            for (final c in msg.cards)
              if (c['type'] == 'review') Padding(padding: const EdgeInsets.only(top: 10), child: _ReviewCard(data: c)),
            if (msg.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final a in msg.actions) _ActionChip(action: a, onTap: () => onAction(a))]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StepChip extends StatelessWidget {
  final Map<String, dynamic> step;
  const _StepChip({required this.step});

  @override
  Widget build(BuildContext context) {
    final ok = step['ok'] != false;
    final c = ok ? BSColors.success : BSColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_rounded, size: 13, color: c),
        const SizedBox(width: 5),
        Text(step['label']?.toString() ?? '', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final Map<String, dynamic> action;
  final VoidCallback onTap;
  const _ActionChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sign = action['type'] == 'sign_document';
    final icon = switch (action['type']) {
      'sign_document' => Icons.draw_rounded,
      'go_verify' => Icons.verified_outlined,
      _ => Icons.visibility_outlined,
    };
    return Material(
      color: sign ? _iaB : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: sign ? _iaB : AppTheme.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sign ? Colors.white : _iaB),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(action['label']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: sign ? Colors.white : _iaB, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Texto con **negritas** y viñetas "- "
class _RichText extends StatelessWidget {
  final String text;
  final Color color;
  const _RichText({required this.text, required this.color});

  List<TextSpan> _spans(String line) {
    final parts = line.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: color, fontSize: 14, height: 1.45);
    final lines = text.split('\n');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final raw in lines)
        if (raw.trim().isEmpty)
          const SizedBox(height: 6)
        else if (RegExp(r'^\s*([-*•]|\d+\.)\s+').hasMatch(raw))
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8, left: 2),
                child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: _iaA, shape: BoxShape.circle)),
              ),
              Expanded(child: Text.rich(TextSpan(style: base, children: _spans(raw.replaceFirst(RegExp(r'^\s*([-*•]|\d+\.)\s+'), ''))))),
            ]),
          )
        else
          Text.rich(TextSpan(style: base, children: _spans(raw.replaceAll(RegExp(r'^#+\s*'), '')))),
    ]);
  }
}

class _ThinkingBubble extends StatefulWidget {
  final String text;
  const _ThinkingBubble({required this.text});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(gradient: _iaGradient, shape: BoxShape.circle),
          child: RotationTransition(turns: _c, child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Row(children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _iaA.withOpacity(0.3 + 0.7 * (0.5 + 0.5 * math.sin((_c.value * 2 * math.pi) - i * 0.9))),
                      shape: BoxShape.circle,
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(widget.text, key: ValueKey(widget.text), style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Tarjeta de revisión antes de firmar (semáforo de riesgo)
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewCard({required this.data});

  static Color riskColor(String? r) => switch ((r ?? '').toLowerCase()) {
        'alto' => BSColors.danger,
        'medio' => BSColors.warning,
        _ => BSColors.success,
      };

  List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : [];

  @override
  Widget build(BuildContext context) {
    final risk = data['risk']?.toString() ?? 'bajo';
    final color = riskColor(risk);
    final alerts = data['alerts'] is List ? (data['alerts'] as List).whereType<Map>().toList() : <Map>[];
    final parties = _strings(data['parties']);
    final dates = _strings(data['dates']);
    final amounts = _strings(data['amounts']);
    final missing = _strings(data['missing']);

    Widget section(IconData icon, String title, List<String> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 14, color: AppTheme.hint),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 20),
                  child: Text('• $it', style: const TextStyle(color: AppTheme.text, fontSize: 12.5, height: 1.35)),
                ),
            ]),
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: color.withOpacity(0.07),
          child: Row(children: [
            // Semáforo
            Column(children: [
              for (final r in ['alto', 'medio', 'bajo'])
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r == risk.toLowerCase() ? riskColor(r) : riskColor(r).withOpacity(0.15),
                    boxShadow: r == risk.toLowerCase() ? [BoxShadow(color: riskColor(r).withOpacity(0.6), blurRadius: 6)] : null,
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Revisión antes de firmar', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text('Riesgo ${risk.toLowerCase()}', style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w900)),
                Text(data['title']?.toString() ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (data['summary'] != null) Text(data['summary'].toString(), style: const TextStyle(color: AppTheme.text, fontSize: 13, height: 1.45)),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final a in alerts)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: riskColor(a['level']?.toString()).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: riskColor(a['level']?.toString()), width: 3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: riskColor(a['level']?.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a['text']?.toString() ?? '', style: const TextStyle(color: AppTheme.text, fontSize: 12.5, height: 1.35))),
                  ]),
                ),
            ],
            section(Icons.groups_outlined, 'PARTES', parties),
            section(Icons.event_outlined, 'FECHAS Y PLAZOS', dates),
            section(Icons.payments_outlined, 'VALORES', amounts),
            section(Icons.edit_note_rounded, 'DATOS FALTANTES', missing),
            if (data['recommendation'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _iaB.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 15, color: _iaB),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(data['recommendation'].toString(),
                        style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Revisión orientativa generada con IA. No reemplaza asesoría legal.',
                style: TextStyle(color: AppTheme.hint, fontSize: 10.5, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }
}
