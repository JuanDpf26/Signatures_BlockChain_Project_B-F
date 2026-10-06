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
  String get category => meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
  String? get hash => raw['file_hash']?.toString();
  String? get tx => raw['blockchain_tx']?.toString();
  String? get fileUrl => raw['file_url']?.toString();

  String? get aiDescription => _s(meta['ai_description']);
  String? get aiSummary => _s(meta['ai_summary']);
  String? get aiConfidentiality => _s(meta['ai_confidentiality']);
  String? get aiError => _s(meta['ai_error']);
  String? get aiModel => _s(meta['ai_model']);
  List<String> get aiTags => ((meta['ai_tags'] as List?) ?? const []).map((e) => e.toString()).toList();
  List<String> get tags => ((meta['ai_tags'] as List?) ?? (meta['tags'] as List?) ?? const []).map((e) => e.toString()).toList();
  bool get analyzed => aiDescription != null;

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
  required void Function(String category, List<String> tags) onUpdate,
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
  final void Function(String category, List<String> tags) onUpdate;

  const DocumentDetailPanel({
    super.key,
    required this.doc,
    required this.isSigning,
    required this.onOpen,
    required this.onSign,
    required this.onDelete,
    required this.onReanalyze,
    required this.onUpdate,
  });

  @override
  State<DocumentDetailPanel> createState() => _DocumentDetailPanelState();
}

class _DocumentDetailPanelState extends State<DocumentDetailPanel> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final DocView d;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    d = DocView(widget.doc);
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
            Tab(text: 'Editar'),
          ],
        ),
      ),

      // Contenido
      Expanded(
        child: Container(
          color: BSColors.page,
          child: TabBarView(controller: _tabs, children: [
            _scroll(pad, [
              DocFichaCard(d: d),
              const SizedBox(height: 12),
              DocAiCard(d: d, compact: true, onReanalyze: widget.onReanalyze, onMore: () => _tabs.animateTo(1)),
              const SizedBox(height: 12),
              DocSecurityCard(d: d),
            ]),
            _scroll(pad, [DocAiCard(d: d, onReanalyze: widget.onReanalyze)]),
            _scroll(pad, [DocMetadataCards(d: d)]),
            _scroll(pad, [_EditTab(d: d, onSave: widget.onUpdate)]),
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
      BSLabelValue(label: 'Estado', value: bsDocStatusLabel(d.status)),
      BSLabelValue(label: 'Subido', value: d.createdLabel),
      if (DocView._s(m['author']) != null) BSLabelValue(label: 'Autor', value: m['author'].toString()),
    ];
    return BSCard(title: 'Información general', child: BSLabelGrid(items: items));
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

    final conf = d.aiConfidentiality;
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
  final void Function(String category, List<String> tags) onSave;
  const _EditTab({required this.d, required this.onSave});

  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  static const _cats = ['Documento', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto'];
  late String _category;
  late List<String> _tags;
  final _tagCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.d.category;
    _tags = List.of(widget.d.tags);
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _tagCtrl.text.trim().toLowerCase();
    if (t.isNotEmpty && !_tags.contains(t)) setState(() => _tags.add(t));
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BSCard(
        title: 'Categoría',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cats.map((c) {
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
      ),
      const SizedBox(height: 12),
      BSCard(
        title: 'Etiquetas',
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
                decoration: InputDecoration(
                  hintText: 'Agregar etiqueta y presionar Enter',
                  hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                  filled: true,
                  fillColor: BSColors.page,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BSPrimaryButton(label: 'Agregar', icon: Icons.add_rounded, onPressed: _addTag),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: BSPrimaryButton(label: 'Guardar cambios', icon: Icons.save_rounded, onPressed: () => widget.onSave(_category, _tags)),
      ),
    ]);
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
