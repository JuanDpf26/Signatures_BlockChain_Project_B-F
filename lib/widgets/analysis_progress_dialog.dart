import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'chain_steps.dart';

/// Resultado del análisis
class AnalysisResult {
  final bool ok;
  final String? docId;
  final bool background; // el usuario lo dejó corriendo en segundo plano
  const AnalysisResult({required this.ok, this.docId, this.background = false});
}

/// Muestra el análisis con IA paso a paso: subida, huella, extracción de texto
/// y lectura de la IA (con escáner animado, contadores y resultado revelado).
///
/// - Para subir: pasa [bytes], [fileName] y [mimeType].
/// - Para re-analizar: pasa [docId] y [title].
Future<AnalysisResult> showAnalysisProgress(
  BuildContext context, {
  Uint8List? bytes,
  String? fileName,
  String? mimeType,
  String? docId,
  String? title,
}) async {
  final wide = MediaQuery.of(context).size.width >= 720;
  final panel = AnalysisProgressPanel(bytes: bytes, fileName: fileName, mimeType: mimeType, docId: docId, title: title);
  final r = wide
      ? await showDialog<AnalysisResult>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780), child: panel),
          ),
        )
      : await showModalBottomSheet<AnalysisResult>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.94),
            child: SafeArea(top: false, child: panel),
          ),
        );
  return r ?? const AnalysisResult(ok: false);
}

enum _Phase { uploading, extracting, ai, done, failed, slow }

const _aiA = Color(0xFF6C63E0);
const _aiB = Color(0xFF0B45B5);
const _aiC = Color(0xFF1499AE);

class AnalysisProgressPanel extends StatefulWidget {
  final Uint8List? bytes;
  final String? fileName;
  final String? mimeType;
  final String? docId;
  final String? title;
  const AnalysisProgressPanel({super.key, this.bytes, this.fileName, this.mimeType, this.docId, this.title});

  @override
  State<AnalysisProgressPanel> createState() => _AnalysisProgressPanelState();
}

class _AnalysisProgressPanelState extends State<AnalysisProgressPanel> with TickerProviderStateMixin {
  _Phase _phase = _Phase.uploading;
  int _visual = 0; // pasos revelados
  String? _docId;
  String _title = '';
  Map<String, dynamic> _meta = {};
  String? _hash;
  String? _error;
  String? _prevAnalyzedAt;
  String? _prevErrorAt;
  String? _aiStage; // reading | thinking | done | failed
  String? _model;
  int _hint = 0;

  final _started = DateTime.now();
  Timer? _poll;
  Timer? _tick;
  bool _polling = false;

  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat(reverse: true);

  static const _aiHints = [
    'Leyendo el contenido…',
    'Identificando el tipo de documento…',
    'Evaluando la confidencialidad…',
    'Buscando palabras clave…',
    'Redactando la descripción…',
    'Generando el resumen…',
  ];

  bool get _isUpload => widget.bytes != null;

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? widget.fileName ?? 'Documento';
    _tick = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted && _phase == _Phase.ai) setState(() => _hint = (_hint + 1) % _aiHints.length);
    });
    _run();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _scan.dispose();
    super.dispose();
  }

  Future<void> _pause(int ms) => Future.delayed(Duration(milliseconds: ms));

  Future<void> _run() async {
    Map<String, dynamic>? doc;
    if (_isUpload) {
      final res = await DocumentService.uploadDocument(
          fileBytes: widget.bytes!, fileName: widget.fileName ?? 'documento', mimeType: widget.mimeType ?? 'application/pdf');
      if (!mounted) return;
      if (res['error'] != null || res['document'] is! Map) {
        setState(() {
          _phase = _Phase.failed;
          _error = res['error']?.toString() ?? 'No se pudo subir el archivo';
        });
        return;
      }
      doc = Map<String, dynamic>.from(res['document']);
    } else {
      // Re-analizar: guardamos las marcas anteriores para saber cuándo hay un resultado nuevo
      final before = await DocumentService.getDocument(widget.docId!);
      final bdoc = before['document'];
      if (bdoc is Map) {
        final m = (bdoc['metadata'] as Map?) ?? {};
        _prevAnalyzedAt = m['ai_analyzed_at']?.toString();
        _prevErrorAt = m['ai_error_at']?.toString();
        doc = Map<String, dynamic>.from(bdoc);
      }
      final res = await DocumentService.reanalyzeDocument(widget.docId!);
      if (!mounted) return;
      if (res['error'] != null || doc == null) {
        setState(() {
          _phase = _Phase.failed;
          _error = res['error']?.toString() ?? 'No se pudo iniciar el análisis';
        });
        return;
      }
    }

    if (doc == null) return;
    _docId = doc['id']?.toString();
    _title = doc['title']?.toString() ?? _title;
    _hash = doc['file_hash']?.toString();
    _meta = Map<String, dynamic>.from((doc['metadata'] as Map?) ?? {});

    // Revelamos los pasos que ya hizo el servidor, uno por uno
    setState(() {
      _phase = _Phase.extracting;
      _visual = 1;
    });
    await _pause(650);
    if (!mounted) return;
    setState(() => _visual = 2);
    // Tiempo para que se vea cómo aparece cada metadato extraído
    await _pause(500 + metaFields(_meta).length * _MetaReveal.stepMs);
    if (!mounted) return;
    setState(() {
      _visual = 3;
      _phase = _Phase.ai;
    });
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _checkAi();
    _poll = Timer.periodic(const Duration(milliseconds: 2000), (_) => _checkAi());
  }

  Future<void> _checkAi() async {
    if (_polling || !mounted || _docId == null) return;
    _polling = true;
    try {
      final res = await DocumentService.getDocument(_docId!);
      final doc = res['document'];
      if (!mounted || doc is! Map) return;
      final m = Map<String, dynamic>.from((doc['metadata'] as Map?) ?? {});
      final analyzedAt = m['ai_analyzed_at']?.toString();
      final errorAt = m['ai_error_at']?.toString();
      setState(() {
        _aiStage = m['ai_stage']?.toString();
        _model = m['ai_model']?.toString() ?? m['ai_trying_model']?.toString();
      });

      if (analyzedAt != null && analyzedAt != _prevAnalyzedAt) {
        _poll?.cancel();
        setState(() => _meta = m);
        await _pause(400);
        if (!mounted) return;
        setState(() {
          _visual = 4;
          _phase = _Phase.done;
        });
      } else if (errorAt != null && errorAt != _prevErrorAt) {
        _poll?.cancel();
        setState(() {
          _meta = m;
          _phase = _Phase.failed;
          _error = m['ai_error']?.toString() ?? 'La IA no respondió';
        });
      } else if (DateTime.now().difference(_started) > const Duration(seconds: 90)) {
        _poll?.cancel();
        setState(() => _phase = _Phase.slow);
      }
    } finally {
      _polling = false;
    }
  }

  // ── Pasos ─────────────────────────────────────────────
  ChainStepState _s(int i) {
    if (_phase == _Phase.done) return ChainStepState.done;
    if (_phase == _Phase.failed) {
      final at = _docId == null ? 0 : 3;
      if (i < at) return ChainStepState.done;
      if (i == at) return ChainStepState.error;
      return ChainStepState.waiting;
    }
    if (i < _visual) return ChainStepState.done;
    if (i == _visual) return ChainStepState.active;
    return ChainStepState.waiting;
  }

  String get _aiDetail {
    if (_phase == _Phase.failed && _docId != null) return _error ?? 'Falló el análisis';
    if (_s(3) == ChainStepState.done) return 'Analizado con ${_model ?? 'Groq'}';
    if (_s(3) != ChainStepState.active) return 'Un modelo de lenguaje lee el texto y lo clasifica.';
    final stage = switch (_aiStage) {
      'reading' => 'Preparando el texto para la IA',
      'thinking' => 'Pensando con ${_model ?? 'Groq'}',
      _ => 'En cola',
    };
    return '$stage · ${_aiHints[_hint]}';
  }

  List<ChainStep> get _steps {
    final words = int.tryParse('${_meta['word_count'] ?? ''}');
    final pages = int.tryParse('${_meta['pages'] ?? ''}');
    return [
      ChainStep(
        _isUpload ? 'Subir archivo de forma segura' : 'Preparar el documento',
        state: _s(0),
        detail: _s(0) == ChainStepState.done
            ? '${_meta['size_mb'] ?? '—'} MB · ${(_meta['extension'] ?? 'pdf').toString().toUpperCase()}'
            : (_isUpload ? 'Enviando el archivo al almacenamiento cifrado…' : 'Cargando la información del documento…'),
      ),
      ChainStep(
        'Calcular huella SHA-256',
        state: _s(1),
        detail: _s(1) == ChainStepState.waiting ? null : 'La identidad única del archivo.',
        extra: [if (_hash != null && _visual >= 1) ChainValueRow(label: 'Huella', value: _hash!)],
      ),
      ChainStep(
        'Extraer texto y metadatos',
        state: _s(2),
        detail: _s(2) == ChainStepState.waiting
            ? null
            : [
                if (pages != null && pages > 0) '$pages página${pages == 1 ? '' : 's'}',
                if (words != null) '$words palabras',
                if (_meta['author'] != null) 'autor: ${_meta['author']}',
              ].join(' · ').ifEmpty('Sin texto legible (posible escaneo)'),
        extra: [if (_visual >= 2) _MetaReveal(meta: _meta)],
      ),
      ChainStep('La IA lee el documento', state: _s(3), detail: _visual >= 3 || _phase == _Phase.failed ? _aiDetail : null),
      ChainStep(
        'Clasificar, etiquetar y resumir',
        state: _s(4),
        detail: _phase == _Phase.done ? 'Categoría, confidencialidad, etiquetas y resumen listos.' : null,
      ),
    ];
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    final done = _phase == _Phase.done;
    final failed = _phase == _Phase.failed;

    final scanner = _Scanner(
      scan: _scan,
      active: !done && !failed,
      done: done,
      failed: failed,
      ext: (_meta['extension'] ?? widget.fileName?.split('.').last ?? 'pdf').toString(),
      preview: _meta['text_preview']?.toString(),
      pages: int.tryParse('${_meta['pages'] ?? ''}'),
      words: int.tryParse('${_meta['word_count'] ?? ''}'),
      showStats: _visual >= 2,
    );

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(done, failed),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 230, child: scanner),
                const SizedBox(width: 24),
                Expanded(child: ChainTimeline(steps: _steps)),
              ])
            else ...[
              Center(child: SizedBox(width: 240, child: scanner)),
              const SizedBox(height: 20),
              ChainTimeline(steps: _steps),
            ],
            if (done) ...[
              const SizedBox(height: 18),
              _ResultCard(meta: _meta),
            ],
            if (failed) ...[
              const SizedBox(height: 14),
              BSInfoBanner(
                title: _docId == null ? 'No se pudo subir' : 'La IA no pudo analizarlo',
                text: _error,
                color: BSColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            if (_phase == _Phase.slow) ...[
              const SizedBox(height: 14),
              const BSInfoBanner(
                title: 'La IA está tardando',
                text: 'Puedes seguir usando la app: te avisaremos cuando termine.',
                color: BSColors.warning,
                icon: Icons.schedule_rounded,
              ),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
          if (_phase == _Phase.ai || _phase == _Phase.slow)
            BSOutlineButton(
              label: 'Seguir en segundo plano',
              icon: Icons.minimize_rounded,
              onPressed: () => Navigator.of(context).pop(AnalysisResult(ok: false, docId: _docId, background: true)),
            ),
          if (done || failed)
            BSPrimaryButton(
              label: done ? '¡Genial!' : 'Cerrar',
              icon: done ? Icons.check_rounded : Icons.close_rounded,
              color: done ? BSColors.success : null,
              onPressed: () => Navigator.of(context).pop(AnalysisResult(ok: done, docId: _docId)),
            )
          else if (_phase != _Phase.ai && _phase != _Phase.slow)
            const BSPrimaryButton(label: 'Procesando…', loading: true),
        ]),
      ),
    ]);
  }

  Widget _header(bool done, bool failed) {
    final title = failed
        ? 'No se pudo completar el análisis'
        : done
            ? '¡Análisis listo!'
            : _phase == _Phase.ai
                ? 'La IA está leyendo tu documento…'
                : _isUpload
                    ? 'Subiendo y preparando…'
                    : 'Preparando el análisis…';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: failed
            ? null
            : const LinearGradient(colors: [_aiA, _aiB, _aiC], begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: failed ? BSColors.danger : null,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: done
              ? const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22)
              : failed
                  ? const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22)
                  : RotationTransition(turns: _scan, child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
          ]),
        ),
        if (!done && !failed)
          Text(chainElapsed(DateTime.now().difference(_started)),
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// METADATOS: cada campo encontrado aparece uno por uno
// ─────────────────────────────────────────────────────────────
/// (ícono, etiqueta, valor) de los metadatos que trae el archivo
List<(IconData, String, String?)> metaFields(Map<String, dynamic> m) {
  String? v(String k) {
    final x = m[k];
    if (x == null) return null;
    final t = x.toString().trim();
    return t.isEmpty ? null : t;
  }

  String? date(String k) {
    final d = DateTime.tryParse(v(k) ?? '');
    if (d == null) return v(k);
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  final isPdf = (v('extension') ?? '').toLowerCase() == 'pdf';
  final chars = int.tryParse(v('char_count') ?? '');
  return [
    (Icons.insert_drive_file_outlined, 'Tipo', v('mime_type') ?? v('extension')?.toUpperCase()),
    (Icons.sd_storage_outlined, 'Tamaño', v('size_kb') != null ? '${v('size_kb')} KB' : null),
    (Icons.auto_stories_outlined, 'Páginas', v('pages')),
    (Icons.text_fields_rounded, 'Palabras', v('word_count')),
    (Icons.abc_rounded, 'Caracteres', chars?.toString()),
    (Icons.person_outline_rounded, 'Autor', v('author')),
    if (isPdf) (Icons.title_rounded, 'Título interno', v('doc_title')),
    if (isPdf) (Icons.subject_rounded, 'Asunto', v('subject')),
    if (isPdf) (Icons.build_outlined, 'Creado con', v('creator')),
    if (isPdf) (Icons.precision_manufacturing_outlined, 'Generador PDF', v('producer')),
    if (isPdf) (Icons.event_outlined, 'Fecha de creación', date('creation_date')),
    if (isPdf) (Icons.edit_calendar_outlined, 'Última modificación', date('modification_date')),
    if (isPdf) (Icons.tag_rounded, 'Versión PDF', v('pdf_version')),
    (Icons.spellcheck_rounded, 'Texto legible', m['has_text'] == null ? null : (m['has_text'] == true ? 'Sí' : 'No (posible escaneo)')),
  ];
}

class _MetaReveal extends StatefulWidget {
  static const stepMs = 170;
  final Map<String, dynamic> meta;
  const _MetaReveal({required this.meta});

  @override
  State<_MetaReveal> createState() => _MetaRevealState();
}

class _MetaRevealState extends State<_MetaReveal> {
  int _shown = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final total = metaFields(widget.meta).length;
    _t = Timer.periodic(const Duration(milliseconds: _MetaReveal.stepMs), (t) {
      if (!mounted) return;
      setState(() => _shown++);
      if (_shown >= total) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = metaFields(widget.meta);
    final found = fields.where((f) => f.$3 != null).length;
    final scanning = _shown < fields.length;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(scanning ? Icons.manage_search_rounded : Icons.check_circle_rounded,
              size: 14, color: scanning ? _aiC : const Color(0xFF4ADE80)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              scanning ? 'Leyendo metadatos del archivo… ${math.min(_shown, fields.length)}/${fields.length}' : '$found de ${fields.length} metadatos encontrados',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < fields.length && i < _shown; i++)
          TweenAnimationBuilder<double>(
            key: ValueKey(i),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(-10 * (1 - v), 0), child: child)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(children: [
                Icon(fields[i].$1, size: 13, color: fields[i].$3 != null ? _aiC : const Color(0xFF475569)),
                const SizedBox(width: 7),
                SizedBox(
                  width: 118,
                  child: Text(fields[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontFamily: 'monospace')),
                ),
                Expanded(
                  child: Text(fields[i].$3 ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fields[i].$3 != null ? Colors.white : const Color(0xFF475569),
                        fontSize: 11.5,
                        fontWeight: fields[i].$3 != null ? FontWeight.w600 : FontWeight.w400,
                        fontFamily: 'monospace',
                      )),
                ),
                Icon(fields[i].$3 != null ? Icons.check_rounded : Icons.remove_rounded,
                    size: 13, color: fields[i].$3 != null ? const Color(0xFF4ADE80) : const Color(0xFF475569)),
              ]),
            ),
          ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// ─────────────────────────────────────────────────────────────
// ESCÁNER ANIMADO (hoja con líneas de texto y un haz que la recorre)
// ─────────────────────────────────────────────────────────────
class _Scanner extends StatelessWidget {
  final AnimationController scan;
  final bool active, done, failed, showStats;
  final String ext;
  final String? preview;
  final int? pages, words;
  const _Scanner({
    required this.scan,
    required this.active,
    required this.done,
    required this.failed,
    required this.ext,
    required this.preview,
    required this.pages,
    required this.words,
    required this.showStats,
  });

  @override
  Widget build(BuildContext context) {
    final color = failed ? BSColors.danger : (done ? BSColors.success : _aiB);
    final words = (preview ?? '').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(40).toList();

    return Column(children: [
      AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35), width: 1.4),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            // Contenido de la hoja
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  BSInitialBox(
                    text: ext.toUpperCase(),
                    color: ext.toLowerCase() == 'pdf' ? BSColors.danger : AppTheme.primary,
                    icon: ext.toLowerCase() == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                  ),
                  const Spacer(),
                  if (done) const Icon(Icons.verified_rounded, color: BSColors.success, size: 22),
                ]),
                const SizedBox(height: 14),
                Expanded(
                  child: words.isEmpty
                      ? Column(children: [
                          for (var i = 0; i < 9; i++)
                            Container(
                              height: 7,
                              margin: const EdgeInsets.only(bottom: 9),
                              width: double.infinity,
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: [1.0, 0.92, 0.97, 0.7, 1.0, 0.85, 0.95, 0.6, 0.8][i],
                                child: Container(decoration: BoxDecoration(color: const Color(0xFFE5E9F2), borderRadius: BorderRadius.circular(4))),
                              ),
                            ),
                        ])
                      : ClipRect(
                          child: Wrap(spacing: 4, runSpacing: 3, children: [
                            for (var i = 0; i < words.length; i++)
                              _PopWord(word: words[i], delayMs: i * 45, highlight: done && i % 7 == 2),
                          ]),
                        ),
                ),
              ]),
            ),
            // Haz del escáner
            if (active)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: scan,
                    builder: (_, __) => Align(
                      alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(scan.value)),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_aiC.withOpacity(0), _aiC.withOpacity(0.22), _aiA.withOpacity(0.55), _aiC.withOpacity(0)],
                            stops: const [0, 0.45, 0.5, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
      if (showStats) ...[
        const SizedBox(height: 12),
        Row(children: [
          _CountStat(label: 'Páginas', value: pages ?? 0),
          const SizedBox(width: 8),
          _CountStat(label: 'Palabras', value: this.words ?? 0),
        ]),
      ],
    ]);
  }
}

/// Palabra del texto que aparece con un pequeño salto
class _PopWord extends StatelessWidget {
  final String word;
  final int delayMs;
  final bool highlight;
  const _PopWord({required this.word, required this.delayMs, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Interval(delayMs / (350 + delayMs), 1, curve: Curves.easeOutBack),
      builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: highlight ? _aiA.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(3)),
        child: Text(word,
            maxLines: 1,
            style: TextStyle(fontSize: 9.5, color: highlight ? _aiA : const Color(0xFF6B7280), fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

/// Número que cuenta desde 0 hasta su valor
class _CountStat extends StatelessWidget {
  final String label;
  final int value;
  const _CountStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${v.round()}',
                style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESULTADO (categoría, etiquetas que aparecen y texto que se escribe)
// ─────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  const _ResultCard({required this.meta});

  Color _confColor(String? c) => switch ((c ?? '').toLowerCase()) {
        'secreto' => BSColors.danger,
        'confidencial' => BSColors.warning,
        'interno' => AppTheme.primary,
        _ => BSColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final tags = (meta['ai_tags'] is List) ? (meta['ai_tags'] as List).map((e) => e.toString()).toList() : <String>[];
    final conf = meta['ai_confidentiality']?.toString();
    final cat = meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
    final desc = meta['ai_description']?.toString() ?? '';
    final summary = meta['ai_summary']?.toString();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: 0.92 + 0.08 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [_aiA.withOpacity(0.07), _aiC.withOpacity(0.07)]),
          border: Border.all(color: _aiA.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_aiA, _aiB]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_special_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
            if (conf != null)
              BSPill(label: conf, color: _confColor(conf)),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Typewriter(text: desc, style: const TextStyle(color: AppTheme.text, fontSize: 14, height: 1.5, fontWeight: FontWeight.w600)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < tags.length; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 160),
                  curve: Interval((i * 160) / (500 + i * 160), 1, curve: Curves.elasticOut),
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _aiA.withOpacity(0.3))),
                    child: Text('#${tags[i]}', style: const TextStyle(color: _aiA, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ],
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('RESUMEN', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(summary, style: const TextStyle(color: AppTheme.text, fontSize: 13, height: 1.5)),
          ],
        ]),
      ),
    );
  }
}

/// Texto que se va escribiendo letra por letra
class _Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _Typewriter({required this.text, required this.style});

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final step = math.max(1, (widget.text.length / 90).ceil()); // termina en ~1.8 s
    _t = Timer.periodic(const Duration(milliseconds: 20), (t) {
      if (!mounted) return;
      setState(() => _n = math.min(widget.text.length, _n + step));
      if (_n >= widget.text.length) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typing = _n < widget.text.length;
    return Text.rich(TextSpan(style: widget.style, children: [
      TextSpan(text: widget.text.substring(0, _n)),
      if (typing) const TextSpan(text: '▍', style: TextStyle(color: _aiA)),
    ]));
  }
}
