import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'sweet_alert.dart';

/// Detalle de un documento: resumen, análisis IA, metadatos y edición.
/// En pantallas anchas se abre como diálogo centrado; en celular, como hoja
/// inferior de casi toda la pantalla.

// ─────────────────────────────────────────
// DATOS DEL DOCUMENTO LISTOS PARA MOSTRAR
// ─────────────────────────────────────────
class DocView {
  final Map<String, dynamic> raw;
  final Map<String, dynamic> meta;
  DocView(this.raw) : meta = Map<String, dynamic>.from((raw['metadata'] as Map?) ?? {});

  /// Para el visor, que solo recibe el mapa de metadatos (con title, status, etc.)
  factory DocView.fromMeta(Map<String, dynamic> m) => DocView({
        'title': m['title'] ?? m['original_name'],
        'status': m['status'],
        'created_at': m['created_at'],
        'file_hash': m['file_hash'],
        'blockchain_tx': m['blockchain_tx'],
        'file_url': m['file_url'],
        'metadata': m,
      });

  String get title => raw['title']?.toString() ?? meta['original_name']?.toString() ?? 'Sin nombre';
  String get ext => (meta['extension']?.toString() ?? 'pdf').toLowerCase();
  bool get isPdf => ext == 'pdf';
  String get status => raw['status']?.toString() ?? 'pending';
  bool get canSign => status == 'pending';
  /// Lo editado a mano tiene prioridad sobre lo que propuso la IA
  String get category => docCategoryOf(meta);
  String? get hash => raw['file_hash']?.toString();
  String? get tx => raw['blockchain_tx']?.toString();
  String? get fileUrl => raw['file_url']?.toString();

  String? get aiDescription => _s(meta['ai_description']);
  String? get aiSummary => _s(meta['ai_summary']);
  String? get aiConfidentiality => _s(meta['ai_confidentiality']);
  String? get aiError => _s(meta['ai_error']);
  String? get aiModel => _s(meta['ai_model']);
  List<String> get aiTags => ((meta['ai_tags'] as List?) ?? const []).map((e) => e.toString()).toList();
  List<String> get tags => ((meta['tags_source'] == 'manual' ? meta['tags'] as List? : (meta['ai_tags'] as List?) ?? (meta['tags'] as List?)) ?? const [])
      .map((e) => e.toString())
      .toList();
  bool get analyzed => aiDescription != null;

  // Edición
  String? get userDescription => _s(meta['user_description']);
  String? get description => userDescription ?? aiDescription;
  String? get confidentiality => _s(meta['confidentiality']) ?? aiConfidentiality;
  bool get confidentialityManual => _s(meta['confidentiality']) != null;
  bool get inChain => ['sending', 'confirming'].contains(meta['blockchain_status']);
  bool get canReplaceFile => status == 'pending' && !inChain;
  int get version => int.tryParse('${meta['version'] ?? ''}') ?? 1;
  String? get id => raw['id']?.toString();
  String? get editedLabel => fmtDate(meta['last_edited_at']?.toString());
  List<Map<String, dynamic>> get versions =>
      ((meta['versions'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> get editHistory =>
      ((meta['edit_history'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  String get sizeLabel {
    final mb = meta['size_mb'];
    final kb = meta['size_kb'];
    if (mb == null) return '-';
    return kb != null ? '$mb MB ($kb KB)' : '$mb MB';
  }

  String? get pages {
    final p = int.tryParse('${meta['pages'] ?? ''}');
    return (p != null && p > 0) ? '$p' : null;
  }

  String get createdLabel => fmtDate(raw['created_at']?.toString()) ?? '-';
  String? get analyzedLabel => fmtDate(meta['ai_analyzed_at']?.toString());

  static String? _s(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty || t == 'null') ? null : t;
  }

  static String? fmtDate(String? iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${bsHora(d)}';
  }
}

/// Categoría visible de un documento (mapa de metadata)
String docCategoryOf(Map meta) {
  final manual = meta['category_source'] == 'manual' ? meta['category']?.toString() : null;
  final v = manual ?? meta['ai_category']?.toString() ?? meta['category']?.toString();
  return (v == null || v.trim().isEmpty) ? 'Documento' : v;
}

Color confidentialityColor(String? level) {
  switch (level?.toLowerCase()) {
    case 'público':
    case 'publico':
      return BSColors.success;
    case 'interno':
      return AppTheme.primary;
    case 'confidencial':
      return BSColors.warning;
    case 'secreto':
      return BSColors.danger;
    default:
      return BSColors.neutral;
  }
}

String shortHash(String h) => h.length > 24 ? '${h.substring(0, 12)}…${h.substring(h.length - 10)}' : h;

Future<void> copyToClipboard(BuildContext context, String value, String what) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    SweetAlert.success(context, title: '$what copiado', autoClose: const Duration(milliseconds: 1100));
  }
}

// ─────────────────────────────────────────
// ABRIR EL DETALLE (diálogo en web, hoja en celular)
// ─────────────────────────────────────────
Future<void> showDocumentDetail(
  BuildContext context, {
  required Map<String, dynamic> doc,
  required bool isSigning,
  required VoidCallback onOpen,
  required VoidCallback onSign,
  required VoidCallback onDelete,
  required VoidCallback onReanalyze,
  required Future<Map<String, dynamic>?> Function(Map<String, dynamic> changes) onUpdate,
  VoidCallback? onReplaceFile,
  VoidCallback? onSend,
  int initialTab = 0,
}) {
  final size = MediaQuery.of(context).size;
  final panel = DocumentDetailPanel(
    doc: doc,
    isSigning: isSigning,
    onOpen: onOpen,
    onSign: onSign,
    onDelete: onDelete,
    onReanalyze: onReanalyze,
    onUpdate: onUpdate,
    onReplaceFile: onReplaceFile,
    onSend: onSend,
    initialTab: initialTab,
  );

  if (size.width > 900) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 920, maxHeight: size.height * 0.88),
          child: panel,
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(child: panel),
      ]),
    ),
  );
}

// ─────────────────────────────────────────
// PANEL DE DETALLE
// ─────────────────────────────────────────
class DocumentDetailPanel extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool isSigning;
  final VoidCallback onOpen, onSign, onDelete, onReanalyze;
  /// Guarda los cambios; devuelve el documento actualizado o null si falló
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> changes) onUpdate;
  final VoidCallback? onReplaceFile;
  final VoidCallback? onSend;
  final int initialTab;

  const DocumentDetailPanel({
    super.key,
    required this.doc,
    required this.isSigning,
    required this.onOpen,
    required this.onSign,
    required this.onDelete,
    required this.onReanalyze,
    required this.onUpdate,
    this.onReplaceFile,
    this.onSend,
    this.initialTab = 0,
  });

  @override
  State<DocumentDetailPanel> createState() => _DocumentDetailPanelState();
}

class _DocumentDetailPanelState extends State<DocumentDetailPanel> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late DocView d;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    d = DocView(widget.doc);
  }

  Future<bool> _save(Map<String, dynamic> changes) async {
    final updated = await widget.onUpdate(changes);
    if (updated == null || !mounted) return false;
    setState(() => d = DocView(updated));
    return true;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    final pad = narrow ? 16.0 : 24.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Encabezado
      Padding(
        padding: EdgeInsets.fromLTRB(pad, narrow ? 12 : 22, narrow ? 8 : 14, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BSInitialBox(
            text: d.ext.toUpperCase(),
            color: d.isPdf ? BSColors.danger : AppTheme.primary,
            icon: d.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.text, fontSize: narrow ? 17 : 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                BSPill.docStatus(d.status),
                BSPill(label: d.ext.toUpperCase(), color: d.isPdf ? BSColors.danger : AppTheme.primary, dot: false),
                BSPill(label: d.category, color: BSColors.neutral, dot: false),
                if (d.analyzed) const BSPill(label: 'Analizado con IA', color: AppTheme.primary),
              ]),
            ]),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppTheme.hint),
          ),
        ]),
      ),

      // Acciones
      Padding(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 4),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          BSPrimaryButton(label: 'Ver documento', icon: Icons.visibility_outlined, onPressed: widget.onOpen),
          if (d.canSign)
            BSPrimaryButton(
              label: widget.isSigning ? 'Firmando…' : 'Firmar',
              icon: Icons.draw_rounded,
              loading: widget.isSigning,
              color: BSColors.success,
              onPressed: widget.onSign,
            ),
          if (widget.onSend != null)
            BSOutlineButton(label: 'Enviar', icon: Icons.send_outlined, onPressed: widget.onSend),
          BSOutlineButton(label: 'Analizar con IA', icon: Icons.auto_awesome_rounded, onPressed: widget.onReanalyze),
          BSOutlineButton(label: 'Eliminar', icon: Icons.delete_outline_rounded, color: BSColors.danger, onPressed: widget.onDelete),
        ]),
      ),

      // Pestañas
      Container(
        margin: EdgeInsets.symmetric(horizontal: pad),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.hint,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Análisis IA'),
            Tab(text: 'Metadatos'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 6), Text('Editar')])),
          ],
        ),
      ),

      // Contenido
      Expanded(
        child: Container(
          color: BSColors.page,
          child: TabBarView(controller: _tabs, children: [
            _scroll(pad, [
              DocLifecycleCard(d: d),
              const SizedBox(height: 12),
              if (!narrow && MediaQuery.of(context).size.width > 900)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: DocFichaCard(d: d)),
                  const SizedBox(width: 12),
                  SizedBox(width: 330, child: DocIntegrityCard(d: d)),
                ])
              else ...[
                DocFichaCard(d: d),
                const SizedBox(height: 12),
                DocIntegrityCard(d: d),
              ],
              const SizedBox(height: 12),
              DocAiCard(d: d, compact: true, onReanalyze: widget.onReanalyze, onMore: () => _tabs.animateTo(1)),
              const SizedBox(height: 12),
              DocSecurityCard(d: d),
            ]),
            _scroll(pad, [DocAiCard(d: d, onReanalyze: widget.onReanalyze)]),
            _scroll(pad, [DocMetadataCards(d: d)]),
            _scroll(pad, [
              _EditTab(
                key: ValueKey('${d.meta['last_edited_at'] ?? ''}|${d.hash ?? ''}'),
                d: d,
                onSave: _save,
                onReplaceFile: widget.onReplaceFile,
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _scroll(double pad, List<Widget> children) => ListView(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
        children: children,
      );
}

// ─────────────────────────────────────────
// TARJETAS REUTILIZABLES (detalle y visor)
// ─────────────────────────────────────────

/// Información general
class DocFichaCard extends StatelessWidget {
  final DocView d;
  const DocFichaCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final m = d.meta;
    final items = <BSLabelValue>[
      BSLabelValue(label: 'Nombre original', value: m['original_name']?.toString() ?? d.title),
      BSLabelValue(label: 'Tipo', value: d.ext.toUpperCase()),
      BSLabelValue(label: 'Tamaño', value: d.sizeLabel),
      if (d.pages != null) BSLabelValue(label: 'Páginas', value: d.pages!),
      BSLabelValue(label: 'Categoría', value: d.category),
      BSLabelValue(label: 'Confidencialidad', value: d.confidentiality ?? 'Sin definir'),
      BSLabelValue(label: 'Estado', value: bsDocStatusLabel(d.status)),
      BSLabelValue(label: 'Subido', value: d.createdLabel),
      if (d.version > 1) BSLabelValue(label: 'Versión', value: 'v${d.version}'),
      if (d.editedLabel != null) BSLabelValue(label: 'Última edición', value: d.editedLabel!),
      if (DocView._s(m['author']) != null) BSLabelValue(label: 'Autor', value: m['author'].toString()),
    ];
    return BSCard(
      title: 'Información general',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (d.userDescription != null) ...[
          Text(d.userDescription!, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 14),
        ],
        BSLabelGrid(items: items),
        if (d.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: d.tags.map((t) => _TagChip(t)).toList()),
        ],
      ]),
    );
  }
}

/// Análisis con IA (completo o compacto)
class DocAiCard extends StatelessWidget {
  final DocView d;
  final bool compact;
  final VoidCallback? onReanalyze;
  final VoidCallback? onMore;
  const DocAiCard({super.key, required this.d, this.compact = false, this.onReanalyze, this.onMore});

  @override
  Widget build(BuildContext context) {
    // Error
    if (!d.analyzed && d.aiError != null) {
      return BSCard(
        title: 'Análisis con IA',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BSInfoBanner(title: 'No se pudo analizar el documento', text: d.aiError, color: BSColors.danger, icon: Icons.error_outline_rounded),
          if (onReanalyze != null) ...[
            const SizedBox(height: 14),
            BSPrimaryButton(label: 'Intentar de nuevo', icon: Icons.refresh_rounded, onPressed: onReanalyze),
          ],
        ]),
      );
    }

    // Pendiente
    if (!d.analyzed) {
      return BSCard(
        title: 'Análisis con IA',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.auto_awesome_outlined, color: AppTheme.primary, size: 26),
              ),
              const SizedBox(height: 12),
              const Text('Análisis pendiente', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('La IA genera una descripción, un resumen, etiquetas y el nivel de confidencialidad.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 12.5, height: 1.4)),
              if (onReanalyze != null) ...[
                const SizedBox(height: 14),
                BSPrimaryButton(label: 'Analizar ahora', icon: Icons.auto_awesome_rounded, onPressed: onReanalyze),
              ],
            ]),
          ),
        ),
      );
    }

    final conf = d.confidentiality;
    final confColor = confidentialityColor(conf);

    return BSCard(
      title: 'Análisis con IA',
      trailing: compact && onMore != null
          ? InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('Ver completo →', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )
          : const BSPill(label: 'IA', color: AppTheme.primary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Descripción
        _AiBlock(icon: Icons.description_outlined, title: 'Descripción', text: d.aiDescription!),
        if (!compact && d.aiSummary != null) ...[
          const SizedBox(height: 12),
          _AiBlock(icon: Icons.summarize_outlined, title: 'Resumen', text: d.aiSummary!),
        ],
        const SizedBox(height: 14),

        // Categoría y confidencialidad
        Row(children: [
          Expanded(child: _StatTile(label: 'Categoría', value: d.category, color: AppTheme.primary, icon: Icons.folder_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _StatTile(label: 'Confidencialidad', value: conf ?? '—', color: confColor, icon: Icons.shield_outlined)),
        ]),

        // Etiquetas
        if (d.aiTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Etiquetas', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: d.aiTags.map((t) => _TagChip(t)).toList()),
        ],

        if (!compact) ...[
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.schedule_rounded, color: AppTheme.hint, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Analizado ${d.analyzedLabel ?? ''}${d.aiModel != null ? ' · ${d.aiModel}' : ''}',
                style: const TextStyle(color: AppTheme.hint, fontSize: 11.5),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Hash SHA-256 y registro en blockchain
class DocSecurityCard extends StatelessWidget {
  final DocView d;
  const DocSecurityCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    return BSCard(
      title: 'Integridad y blockchain',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d.hash != null)
          _CopyRow(
            icon: Icons.fingerprint_rounded,
            label: 'Hash SHA-256',
            value: d.hash!,
            onCopy: () => copyToClipboard(context, d.hash!, 'Hash'),
          ),
        const SizedBox(height: 12),
        if (d.tx != null) ...[
          _CopyRow(
            icon: Icons.link_rounded,
            label: 'Transacción en Sepolia',
            value: d.tx!,
            onCopy: () => copyToClipboard(context, d.tx!, 'Transacción'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: BSOutlineButton(
              label: 'Ver en Etherscan',
              icon: Icons.open_in_new_rounded,
              onPressed: () => launchUrl(Uri.parse('https://sepolia.etherscan.io/tx/${d.tx}'), mode: LaunchMode.externalApplication),
            ),
          ),
        ] else
          BSInfoBanner(
            title: d.canSign ? 'Aún no está firmado' : 'Sin transacción registrada',
            text: d.canSign
                ? 'Al firmarlo, el hash quedará registrado de forma inmutable en la blockchain Sepolia.'
                : 'Este documento no tiene una transacción asociada.',
            color: d.canSign ? BSColors.warning : BSColors.neutral,
            icon: Icons.info_outline_rounded,
          ),
      ]),
    );
  }
}

/// Metadatos completos por secciones
class DocMetadataCards extends StatelessWidget {
  final DocView d;
  const DocMetadataCards({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final m = d.meta;
    String? s(String k) => DocView._s(m[k]);
    List<BSLabelValue> keep(List<MapEntry<String, String?>> e) =>
        e.where((x) => x.value != null).map((x) => BSLabelValue(label: x.key, value: x.value!)).toList();

    final file = keep([
      MapEntry('Nombre original', s('original_name')),
      MapEntry('Tipo MIME', s('mime_type')),
      MapEntry('Extensión', d.ext.toUpperCase()),
      MapEntry('Tamaño', d.sizeLabel),
      MapEntry('Subido', d.createdLabel),
    ]);
    final content = keep([
      MapEntry('Páginas', d.pages),
      MapEntry('Autor', s('author')),
      MapEntry('Título interno', s('doc_title')),
      MapEntry('Asunto', s('subject')),
      MapEntry('Creado con', s('creator')),
      MapEntry('Productor', s('producer')),
      MapEntry('Versión PDF', s('pdf_version')),
      MapEntry('Fecha de creación', s('creation_date')),
      MapEntry('Última modificación', s('modification_date')),
    ]);
    final text = keep([
      MapEntry('Palabras', s('word_count')),
      MapEntry('Caracteres', s('char_count')),
      MapEntry('Tiene texto', m['has_text'] == null ? null : (m['has_text'] == true ? 'Sí' : 'No (posible escaneo)')),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BSCard(title: 'Archivo', child: BSLabelGrid(items: file)),
      if (content.isNotEmpty) ...[
        const SizedBox(height: 12),
        BSCard(title: d.isPdf ? 'Contenido del PDF' : 'Contenido', child: BSLabelGrid(items: content)),
      ],
      if (text.isNotEmpty) ...[
        const SizedBox(height: 12),
        BSCard(title: 'Texto', child: BSLabelGrid(items: text)),
      ],
      if (s('text_preview') != null) ...[
        const SizedBox(height: 12),
        BSCard(
          title: 'Vista previa del texto',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: SelectableText(s('text_preview')!, style: const TextStyle(color: AppTheme.text, fontSize: 12.5, height: 1.5)),
          ),
        ),
      ],
      if (s('extraction_error') != null) ...[
        const SizedBox(height: 12),
        BSInfoBanner(title: 'No se pudo leer el contenido', text: s('extraction_error'), color: BSColors.warning, icon: Icons.warning_amber_rounded),
      ],
      const SizedBox(height: 12),
      DocSecurityCard(d: d),
    ]);
  }
}

// ─────────────────────────────────────────
// PESTAÑA EDITAR
// ─────────────────────────────────────────
class _EditTab extends StatefulWidget {
  final DocView d;
  final Future<bool> Function(Map<String, dynamic> changes) onSave;
  final VoidCallback? onReplaceFile;
  const _EditTab({super.key, required this.d, required this.onSave, this.onReplaceFile});

  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  static const _cats = ['Documento', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto'];
  static const _levels = [
    ('Público', Icons.public_rounded, 'Se puede compartir sin restricción'),
    ('Interno', Icons.apartment_rounded, 'Solo personas de la organización'),
    ('Confidencial', Icons.lock_outline_rounded, 'Acceso limitado a quienes lo necesitan'),
    ('Secreto', Icons.gpp_maybe_outlined, 'Máxima reserva'),
  ];

  late final TextEditingController _name;
  late final TextEditingController _desc;
  final _tagCtrl = TextEditingController();
  final _customCat = TextEditingController();
  late String _category;
  late List<String> _tags;
  String? _conf;
  bool _saving = false;

  DocView get d => widget.d;
  String get _ext => '.${d.ext}';
  String _baseName(String t) => t.toLowerCase().endsWith(_ext) ? t.substring(0, t.length - _ext.length) : t;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _baseName(d.title))..addListener(_touch);
    _desc = TextEditingController(text: d.userDescription ?? '')..addListener(_touch);
    _category = d.category;
    _tags = List.of(d.tags);
    _conf = d.confidentiality;
  }

  void _touch() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _tagCtrl.dispose();
    _customCat.dispose();
    super.dispose();
  }

  /// Solo los campos que cambiaron
  Map<String, dynamic> get _changes {
    final c = <String, dynamic>{};
    final name = _name.text.trim();
    if (name.isNotEmpty && name != _baseName(d.title)) c['title'] = name;
    if (_desc.text.trim() != (d.userDescription ?? '')) c['description'] = _desc.text.trim();
    if (_category != d.category) c['category'] = _category;
    if (_tags.join('|') != d.tags.join('|')) c['tags'] = _tags;
    if (_conf != null && _conf != d.confidentiality) c['confidentiality'] = _conf;
    return c;
  }

  bool get _dirty => _changes.isNotEmpty;

  void _reset() {
    _name.text = _baseName(d.title);
    _desc.text = d.userDescription ?? '';
    setState(() {
      _category = d.category;
      _tags = List.of(d.tags);
      _conf = d.confidentiality;
    });
  }

  void _addTag([String? value]) {
    final t = (value ?? _tagCtrl.text).trim().toLowerCase().replaceAll(RegExp(r'^#+'), '').replaceAll(RegExp(r'\s+'), '-');
    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 15) setState(() => _tags.add(t));
    if (value == null) _tagCtrl.clear();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      await SweetAlert.error(context, title: 'Falta el nombre', text: 'El documento necesita un nombre.');
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onSave(_changes);
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) {
      SweetAlert.success(context, title: 'Cambios guardados', autoClose: const Duration(milliseconds: 1400));
    }
  }

  InputDecoration _dec(String hint, {String? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13.5),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: AppTheme.hint, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.6)),
      );

  Widget _label(String text, [String? help]) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
          if (help != null) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(help, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12))),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final signed = !d.canSign;
    final cats = [..._cats, if (!_cats.contains(_category)) _category];
    final aiSuggest = d.aiTags.where((t) => !_tags.contains(t)).toList();

    final general = BSCard(
      title: 'Datos del documento',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label('Nombre'),
        TextField(
          controller: _name,
          maxLength: 140,
          style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: _dec('Nombre del documento', suffix: _ext).copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        _label('Descripción', 'Tu propia descripción; la de la IA se conserva aparte'),
        TextField(
          controller: _desc,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          style: const TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.45),
          decoration: _dec(d.aiDescription ?? 'Describe para qué sirve este documento…'),
        ),
        if (d.aiDescription != null && _desc.text.trim().isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _desc.text = d.aiDescription!,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Usar la descripción de la IA'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary, minimumSize: const Size(0, 36)),
            ),
          ),
      ]),
    );

    final category = BSCard(
      title: 'Categoría',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.map((c) {
            final sel = _category == c;
            return ChoiceChip(
              label: Text(c),
              selected: sel,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: AppTheme.primary.withOpacity(0.12),
              backgroundColor: Colors.white,
              side: BorderSide(color: sel ? AppTheme.primary : AppTheme.border),
              labelStyle: TextStyle(color: sel ? AppTheme.primary : AppTheme.text, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 12.5),
              showCheckmark: false,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _customCat,
              maxLength: 40,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) setState(() => _category = v.trim());
                _customCat.clear();
              },
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
              decoration: _dec('Otra categoría…').copyWith(counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          BSOutlineButton(
            label: 'Usar',
            icon: Icons.check_rounded,
            onPressed: () {
              if (_customCat.text.trim().isEmpty) return;
              setState(() => _category = _customCat.text.trim());
              _customCat.clear();
            },
          ),
        ]),
      ]),
    );

    final confidentiality = BSCard(
      title: 'Confidencialidad',
      trailing: d.aiConfidentiality != null
          ? Text('IA sugirió: ${d.aiConfidentiality}', style: const TextStyle(color: AppTheme.hint, fontSize: 12))
          : null,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 520 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in _levels)
            SizedBox(
              width: w,
              child: _LevelOption(
                label: l.$1,
                icon: l.$2,
                help: l.$3,
                color: confidentialityColor(l.$1),
                selected: _conf == l.$1,
                onTap: () => setState(() => _conf = l.$1),
              ),
            ),
        ]);
      }),
    );

    final tags = BSCard(
      title: 'Etiquetas',
      trailing: Text('${_tags.length}/15', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_tags.isEmpty)
          const Text('Sin etiquetas todavía.', style: TextStyle(color: AppTheme.hint, fontSize: 12.5))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags
                .map((t) => InputChip(
                      label: Text('#$t'),
                      onDeleted: () => setState(() => _tags.remove(t)),
                      deleteIconColor: AppTheme.primary,
                      backgroundColor: AppTheme.primary.withOpacity(0.07),
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
                      labelStyle: const TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _tagCtrl,
              onSubmitted: (_) => _addTag(),
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
              decoration: _dec('Nueva etiqueta y Enter'),
            ),
          ),
          const SizedBox(width: 8),
          BSPrimaryButton(label: 'Agregar', icon: Icons.add_rounded, onPressed: () => _addTag()),
        ]),
        if (aiSuggest.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Sugeridas por la IA', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: aiSuggest
                .map((t) => ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 15, color: AppTheme.primary),
                      label: Text(t),
                      onPressed: () => _addTag(t),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.border),
                      labelStyle: const TextStyle(color: AppTheme.text, fontSize: 12),
                    ))
                .toList(),
          ),
        ],
      ]),
    );

    final file = _FileVersionCard(d: d, onReplace: widget.onReplaceFile);
    final history = _EditHistoryCard(d: d);

    final saveBar = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: _dirty ? BSColors.selected : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dirty ? AppTheme.primary.withOpacity(0.35) : AppTheme.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_dirty ? Icons.edit_note_rounded : Icons.check_circle_outline_rounded, color: _dirty ? AppTheme.primary : BSColors.success, size: 20),
            const SizedBox(width: 8),
            Text(
              _dirty ? '${_changes.length} cambio${_changes.length == 1 ? '' : 's'} sin guardar' : 'Todo guardado',
              style: TextStyle(color: _dirty ? AppTheme.primary : AppTheme.hint, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (_dirty) ...[
              TextButton(onPressed: _saving ? null : _reset, child: const Text('Descartar')),
              const SizedBox(width: 6),
            ],
            BSPrimaryButton(
              label: _saving ? 'Guardando…' : 'Guardar cambios',
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ]),
        ],
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (signed) ...[
        const BSInfoBanner(
          title: 'Este documento ya está firmado',
          text: 'Puedes cambiar sus datos descriptivos. El archivo y su huella SHA-256 quedan fijos porque están registrados en blockchain.',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 12),
      ],
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [general, const SizedBox(height: 12), confidentiality, const SizedBox(height: 12), tags]),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [category, const SizedBox(height: 12), file, const SizedBox(height: 12), history]),
          ),
        ])
      else ...[
        general,
        const SizedBox(height: 12),
        category,
        const SizedBox(height: 12),
        confidentiality,
        const SizedBox(height: 12),
        tags,
        const SizedBox(height: 12),
        file,
        const SizedBox(height: 12),
        history,
      ],
      const SizedBox(height: 14),
      saveBar,
    ]);
  }
}

/// Opción de nivel de confidencialidad (tarjeta seleccionable)
class _LevelOption extends StatelessWidget {
  final String label, help;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _LevelOption({required this.label, required this.help, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.09) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 19),
              const Spacer(),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.check_circle_rounded, color: color, size: 18),
              ),
            ]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: selected ? color : AppTheme.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(help, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, height: 1.3)),
          ]),
        ),
      ),
    );
  }
}

/// Archivo actual, nueva versión y versiones anteriores
class _FileVersionCard extends StatelessWidget {
  final DocView d;
  final VoidCallback? onReplace;
  const _FileVersionCard({required this.d, this.onReplace});

  @override
  Widget build(BuildContext context) {
    final versions = d.versions;
    return BSCard(
      title: 'Archivo',
      trailing: BSPill(label: 'v${d.version}', color: AppTheme.primary, dot: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          BSInitialBox(
            text: d.ext.toUpperCase(),
            color: d.isPdf ? BSColors.danger : AppTheme.primary,
            icon: d.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.meta['original_name']?.toString() ?? d.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text('${d.sizeLabel}${d.pages != null ? ' · ${d.pages} pág.' : ''}', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
            ]),
          ),
        ]),
        if (d.hash != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => copyToClipboard(context, d.hash!, 'Hash'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.fingerprint_rounded, color: AppTheme.hint, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(shortHash(d.hash!), style: const TextStyle(color: AppTheme.text, fontFamily: 'monospace', fontSize: 12))),
                const Icon(Icons.copy_rounded, color: AppTheme.hint, size: 14),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (d.canReplaceFile && onReplace != null) ...[
          BSOutlineButton(label: 'Subir nueva versión', icon: Icons.upload_file_rounded, onPressed: onReplace),
          const SizedBox(height: 6),
          const Text('Cambia la huella SHA-256 y se vuelve a analizar con IA. Tus datos editados se conservan.',
              style: TextStyle(color: AppTheme.hint, fontSize: 11.5, height: 1.35)),
        ] else
          Text(
            d.inChain ? 'La firma se está registrando: no se puede cambiar el archivo.' : 'Firmado: el archivo ya no se puede reemplazar.',
            style: const TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.35),
          ),
        if (versions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Versiones anteriores', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final v in versions)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: v['file_url'] == null ? null : () => launchUrl(Uri.parse(v['file_url'].toString()), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(6)),
                      child: Text('v${v['version'] ?? '?'}', style: const TextStyle(color: AppTheme.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v['name']?.toString() ?? 'Archivo', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('Reemplazado ${DocView.fmtDate(v['replaced_at']?.toString()) ?? ''} · ${shortHash('${v['file_hash'] ?? ''}')}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                      ]),
                    ),
                    const Icon(Icons.open_in_new_rounded, color: AppTheme.hint, size: 15),
                  ]),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

/// Historial de cambios (quién y qué cambió)
class _EditHistoryCard extends StatelessWidget {
  final DocView d;
  const _EditHistoryCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final items = d.editHistory.take(8).toList();
    return BSCard(
      title: 'Historial de cambios',
      child: items.isEmpty
          ? const Text('Aún no se ha editado. Cada cambio queda registrado aquí y en Auditoría.',
              style: TextStyle(color: AppTheme.hint, fontSize: 12.5, height: 1.4))
          : Column(children: [
              for (var i = 0; i < items.length; i++)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppTheme.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    if (i < items.length - 1) Container(width: 2, height: 34, color: AppTheme.border),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Cambió ${((items[i]['fields'] as List?) ?? const []).join(', ')}',
                            style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        Text(DocView.fmtDate(items[i]['at']?.toString()) ?? '',
                            style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
                      ]),
                    ),
                  ),
                ]),
            ]),
    );
  }
}

// ─────────────────────────────────────────
// PIEZAS PEQUEÑAS
// ─────────────────────────────────────────
class _AiBlock extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _AiBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.primary, size: 15),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        SelectableText(text, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.55)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      ]),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Text('#$text', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onCopy;
  const _CopyRow({required this.icon, required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Tooltip(
              message: value,
              child: Text(shortHash(value),
                  style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            ),
          ]),
        ),
        IconButton(
          tooltip: 'Copiar',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, color: AppTheme.hint, size: 18),
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────
// CICLO DE VIDA DEL DOCUMENTO (como los gates de aprobación)
// ─────────────────────────────────────────
enum _Gate { done, current, pending, error }

class DocLifecycleCard extends StatelessWidget {
  final DocView d;
  const DocLifecycleCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final m = d.meta;
    final chain = m['blockchain_status']?.toString();
    final signedOk = d.status == 'signed' || d.status == 'verified';
    final inChain = chain == 'sending' || chain == 'confirming';
    final revoked = m['revoked'] == true;

    final steps = <(String, _Gate, String)>[
      ('Subido', _Gate.done, 'Completado'),
      d.analyzed
          ? ('Análisis IA', _Gate.done, 'Completado')
          : d.aiError != null
              ? ('Análisis IA', _Gate.error, 'Con error')
              : ('Análisis IA', _Gate.current, 'En curso'),
      revoked
          ? ('Firmado', _Gate.error, 'Revocado')
          : signedOk || inChain
              ? ('Firmado', _Gate.done, 'Aprobado')
              : ('Firmado', d.analyzed ? _Gate.current : _Gate.pending, d.analyzed ? 'Por firmar' : 'Pendiente'),
      signedOk
          ? ('Blockchain', _Gate.done, m['blockchain_block'] != null ? 'Bloque #${m['blockchain_block']}' : 'Registrado')
          : inChain
              ? ('Blockchain', _Gate.current, 'Confirmando')
              : chain == 'failed'
                  ? ('Blockchain', _Gate.error, 'Falló')
                  : ('Blockchain', _Gate.pending, 'Pendiente'),
      d.status == 'verified'
          ? ('Verificado', _Gate.done, 'Comprobado')
          : ('Verificado', signedOk ? _Gate.current : _Gate.pending, signedOk ? 'Disponible' : 'Pendiente'),
    ];

    Color colorOf(_Gate g) => switch (g) {
          _Gate.done => BSColors.success,
          _Gate.current => AppTheme.primary,
          _Gate.error => BSColors.danger,
          _Gate.pending => BSColors.neutral,
        };

    return BSCard(
      title: 'Ciclo de vida del documento',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(children: [
              Row(children: [
                // Línea hacia el paso anterior
                Expanded(
                  child: i == 0
                      ? const SizedBox()
                      : Container(height: 3, color: steps[i - 1].$2 == _Gate.done && steps[i].$2 != _Gate.pending ? AppTheme.primary : AppTheme.border),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: Duration(milliseconds: 350 + i * 90),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].$2 == _Gate.pending ? Colors.white : colorOf(steps[i].$2),
                      border: Border.all(color: steps[i].$2 == _Gate.pending ? AppTheme.border : colorOf(steps[i].$2), width: 2),
                    ),
                    child: switch (steps[i].$2) {
                      _Gate.done => const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      _Gate.error => const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      _ => Text('${i + 1}',
                          style: TextStyle(
                              color: steps[i].$2 == _Gate.current ? Colors.white : AppTheme.hint,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    },
                  ),
                ),
                // Línea hacia el paso siguiente
                Expanded(
                  child: i == steps.length - 1
                      ? const SizedBox()
                      : Container(height: 3, color: steps[i].$2 == _Gate.done && steps[i + 1].$2 != _Gate.pending ? AppTheme.primary : AppTheme.border),
                ),
              ]),
              const SizedBox(height: 10),
              Text(steps[i].$1,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(steps[i].$3,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorOf(steps[i].$2), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// INTEGRIDAD DEL DOCUMENTO (dona con porcentaje + lista de chequeo)
// ─────────────────────────────────────────
class DocIntegrityCard extends StatelessWidget {
  final DocView d;
  const DocIntegrityCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final m = d.meta;
    final signedOk = d.status == 'signed' || d.status == 'verified';
    // (texto, estado: true = ok, false = falla, null = pendiente)
    final checks = <(String, bool?)>[
      ('Huella SHA-256 calculada', d.hash != null),
      ('Metadatos extraídos', m['word_count'] != null || m['pages'] != null),
      ('Texto legible', m['has_text'] == null ? null : m['has_text'] == true),
      ('Análisis con IA', d.analyzed ? true : (d.aiError != null ? false : null)),
      ('Firma digital', m['revoked'] == true ? false : (signedOk || m['signature_hash'] != null ? true : null)),
      ('Registro en blockchain', signedOk ? true : (m['blockchain_status'] == 'failed' ? false : null)),
    ];
    final ok = checks.where((c) => c.$2 == true).length;
    final pct = ok / checks.length;

    Color dot(bool? v) => v == true ? BSColors.success : (v == false ? BSColors.danger : BSColors.warning);

    return BSCard(
      title: 'Integridad y cumplimiento',
      child: Column(children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _DonutPainter(v),
                child: Center(
                  child: Text('${(v * 100).round()} %',
                      style: const TextStyle(color: AppTheme.text, fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final c in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dot(c.$2), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(c.$1, style: const TextStyle(color: AppTheme.text, fontSize: 13.5))),
            ]),
          ),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double value;
  _DonutPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = const Color(0xFFEEF1F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, 2 * math.pi, false, bg);
    if (value > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * value, false, fg);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.value != value;
}
