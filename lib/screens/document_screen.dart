import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_service.dart';
import '../services/profile_service.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/signing_progress_dialog.dart';
import '../widgets/analysis_progress_dialog.dart';
import '../widgets/bs_ui.dart';
import '../widgets/document_detail.dart';
import '../widgets/send_document_dialog.dart';
import '../theme/app_theme.dart';
import 'document_viewer_screen.dart';

//Juandiego son of ragnar//
class DocumentsScreen extends StatefulWidget {
  /// Búsqueda o estado con los que abre (desde el buscador o la campana de la barra superior)
  final String? initialSearch;
  final String? initialStatus;
  const DocumentsScreen({super.key, this.initialSearch, this.initialStatus});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _docs = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _signingDocId;

  String? _selCategory;
  String? _selStatus;
  String? _selExt;
  Map<String, dynamic> _stats = {};

  final _categories = ['Todos', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto', 'Documento'];
  final _statuses = ['Todos', 'pending', 'signed', 'verified', 'rejected'];
  final _exts = ['Todos', 'pdf', 'docx', 'doc'];

  bool get _hasFilters => _selCategory != null || _selStatus != null || _selExt != null || _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) _searchCtrl.text = widget.initialSearch!;
    if (widget.initialStatus != null) _selStatus = widget.initialStatus;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      DocumentService.getStats().then((st) {
        if (mounted && st['error'] == null) setState(() => _stats = st);
      });
      final res = await DocumentService.getDocuments(
        search: _searchCtrl.text.trim(),
        category: (_selCategory == 'Todos' || _selCategory == null) ? null : _selCategory,
        status: (_selStatus == 'Todos' || _selStatus == null) ? null : _selStatus,
        ext: (_selExt == 'Todos' || _selExt == null) ? null : _selExt,
      );
      if (!mounted) return;
      if (res.containsKey('documents')) {
        setState(() => _docs = List<Map<String, dynamic>>.from(res['documents']));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selCategory = null;
      _selStatus = null;
      _selExt = null;
      _searchCtrl.clear();
    });
    _load();
  }

  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) await SweetAlert.error(context, title: 'No se pudo leer el archivo', text: 'Intenta seleccionarlo de nuevo.');
        return;
      }
      final mimeType = file.extension == 'pdf' ? 'application/pdf' : file.extension == 'doc' ? 'application/msword' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      setState(() => _isUploading = true);
      // Muestra el proceso completo: subida → huella → texto → IA → resultado
      final r = await showAnalysisProgress(context, bytes: file.bytes!, fileName: file.name, mimeType: mimeType);
      if (!mounted) return;
      setState(() => _isUploading = false);
      await _load();
      if (!mounted) return;
      if (r.ok) {
        SweetAlert.success(context, title: 'Análisis guardado', autoClose: const Duration(milliseconds: 1600));
      } else if (r.background && r.docId != null) {
        _watchAnalysis(r.docId!, title: file.name);
      }
    } catch (e) {
      if (mounted) await SweetAlert.error(context, title: 'Error al subir', text: '$e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sign(String docId, String docTitle) async {
    // Obtener firma guardada del usuario
    final sigRes = await ProfileService.getSignature();
    if (!mounted) return;

    String? signatureUrl;
    if (sigRes.containsKey('signature')) {
      signatureUrl = sigRes['signature']['signature_url'];
    }

    // Mostrar previsualización
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _SignConfirmDialog(
        docTitle: docTitle,
        signatureUrl: signatureUrl,
        doc: _docs.cast<Map<String, dynamic>?>().firstWhere((d) => d?['id']?.toString() == docId, orElse: () => null),
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _signingDocId = docId);
    try {
      // Muestra el proceso real paso a paso: huella → firma → tx → bloque
      final ok = await showSigningProgress(context, docId: docId, docTitle: docTitle);
      if (ok && mounted) {
        SweetAlert.success(
          context,
          title: '¡Documento firmado!',
          text: '"$docTitle" quedó registrado en la blockchain Sepolia. Cualquiera puede comprobar su autenticidad desde Verificar.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingDocId = null);
    }
    if (mounted) await _load();
  }

  Future<void> _delete(String docId, String title) async {
    final ok = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: 'Eliminar documento',
      text: '¿Eliminar "$title"? Esta acción no se puede deshacer.',
      confirmText: 'Sí, eliminar',
    );
    if (!ok || !mounted) return;
    final res = await DocumentService.deleteDocument(docId);
    if (!mounted) return;
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo eliminar', text: res['error'].toString());
    } else {
      SweetAlert.success(context, title: 'Documento eliminado', autoClose: const Duration(milliseconds: 1500));
      await _load();
    }
  }

  /// Consulta el documento cada 3 s hasta que la IA termine y muestra una alerta con el resultado.
  final Set<String> _watching = {};
  Future<void> _watchAnalysis(String docId, {String? title, String? prevAnalyzedAt, String? prevErrorAt}) async {
    if (!_watching.add(docId)) return;
    try {
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        final res = await DocumentService.getDocument(docId);
        final doc = res['document'];
        if (doc is! Map) continue;
        final meta = (doc['metadata'] as Map?) ?? {};
        final analyzedAt = meta['ai_analyzed_at']?.toString();
        final errorAt = meta['ai_error_at']?.toString();
        final name = title ?? doc['title']?.toString() ?? 'el documento';

        if (analyzedAt != null && analyzedAt != prevAnalyzedAt) {
          await _load();
          if (!mounted) return;
          final cat = meta['ai_category']?.toString();
          final desc = meta['ai_description']?.toString() ?? '';
          final short = desc.length > 180 ? '${desc.substring(0, 180)}…' : desc;
          SweetAlert.success(
            context,
            title: 'Análisis con IA listo',
            text: [
              name,
              if (cat != null && cat.isNotEmpty) 'Categoría: $cat',
              if (short.isNotEmpty) short,
            ].join('\n\n'),
          );
          return;
        }
        if (errorAt != null && errorAt != prevErrorAt) {
          await _load();
          if (!mounted) return;
          SweetAlert.error(
            context,
            title: 'No se pudo analizar',
            text: '${meta['ai_error'] ?? 'La IA no respondió.'}\n\nPuedes intentarlo de nuevo desde el detalle del documento.',
          );
          return;
        }
      }
      if (mounted) await _load();
    } finally {
      _watching.remove(docId);
    }
  }

  Future<void> _reanalyze(String docId) async {
    final doc = _docs.firstWhere((d) => d['id']?.toString() == docId, orElse: () => <String, dynamic>{});
    final meta = (doc['metadata'] as Map?) ?? {};
    final prevAnalyzedAt = meta['ai_analyzed_at']?.toString();
    final prevErrorAt = meta['ai_error_at']?.toString();
    final r = await showAnalysisProgress(context, docId: docId, title: doc['title']?.toString());
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (r.ok) {
      SweetAlert.success(context, title: 'Análisis actualizado', autoClose: const Duration(milliseconds: 1600));
    } else if (r.background) {
      _watchAnalysis(docId, title: doc['title']?.toString(), prevAnalyzedAt: prevAnalyzedAt, prevErrorAt: prevErrorAt);
    }
  }

  // Abre el visor pasándole también estado, fecha, hash y transacción
  void _openViewer(Map<String, dynamic> doc) {
    final meta = Map<String, dynamic>.from((doc['metadata'] as Map?) ?? {});
    Navigator.push(context, MaterialPageRoute(
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
  }

  void _showDetail(Map<String, dynamic> doc, {int tab = 0}) {
    final id = doc['id']?.toString() ?? '';
    final title = doc['title']?.toString() ?? '';
    showDocumentDetail(
      context,
      doc: doc,
      initialTab: tab,
      isSigning: _signingDocId == id,
      onOpen: () => _openViewer(doc),
      onSign: () {
        Navigator.pop(context);
        _sign(id, title);
      },
      onDelete: () {
        Navigator.pop(context);
        _delete(id, title);
      },
      onReanalyze: () {
        Navigator.pop(context);
        _reanalyze(id);
      },
      onUpdate: (changes) async {
        final res = await DocumentService.updateDocumentMeta(
          docId: id,
          title: changes['title'] as String?,
          description: changes['description'] as String?,
          category: changes['category'] as String?,
          tags: (changes['tags'] as List?)?.map((e) => e.toString()).toList(),
          confidentiality: changes['confidentiality'] as String?,
        );
        if (!mounted) return null;
        if (res.containsKey('error') || res['document'] is! Map) {
          await SweetAlert.error(context, title: 'No se pudo guardar', text: (res['error'] ?? 'Respuesta inesperada del servidor').toString());
          return null;
        }
        _load(); // refresca la lista sin cerrar el detalle
        return Map<String, dynamic>.from(res['document'] as Map);
      },
      onReplaceFile: () => _replaceFile(doc),
      onSend: () => _sendByEmail(doc),
    );
  }

  Future<void> _sendByEmail(Map<String, dynamic> doc) async {
    // Usa los datos más recientes (por si se editó o se firmó hace un momento)
    final fresh = await DocumentService.getDocument(doc['id'].toString());
    if (!mounted) return;
    final d = fresh['document'] is Map ? Map<String, dynamic>.from(fresh['document'] as Map) : doc;
    final sent = await showSendDocumentDialog(context, d);
    if (sent && mounted) _load();
  }

  /// Nueva versión del archivo: elegir → confirmar → subir → análisis con IA visible
  Future<void> _replaceFile(Map<String, dynamic> doc) async {
    final id = doc['id']?.toString() ?? '';
    final meta = (doc['metadata'] as Map?) ?? {};
    final pick = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final file = pick.files.first;
    if (file.bytes == null) {
      await SweetAlert.error(context, title: 'No se pudo leer el archivo', text: 'Intenta seleccionarlo de nuevo.');
      return;
    }
    final ok = await SweetAlert.confirm(
      context,
      title: '¿Subir nueva versión?',
      text: 'Se reemplazará "${doc['title']}" por "${file.name}".\n\nLa huella SHA-256 cambiará y el documento se volverá a analizar con IA. '
          'La versión actual queda guardada en el historial.',
      confirmText: 'Subir versión',
    );
    if (!ok || !mounted) return;

    final ext = (file.extension ?? '').toLowerCase();
    final mime = ext == 'pdf' ? 'application/pdf' : ext == 'doc' ? 'application/msword' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppTheme.primary)),
            SizedBox(width: 16),
            Text('Subiendo nueva versión…', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
    final res = await DocumentService.replaceFile(docId: id, fileBytes: file.bytes!, fileName: file.name, mimeType: mime);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // cierra "cargando"
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo reemplazar', text: res['error'].toString());
      return;
    }
    Navigator.of(context).pop(); // cierra el detalle (tenía la versión anterior)
    await _load();
    if (!mounted) return;
    final title = res['document'] is Map ? (res['document'] as Map)['title']?.toString() : file.name;
    final r = await showAnalysisProgress(context, docId: id, title: title);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (r.ok) {
      SweetAlert.success(context, title: 'Versión ${res['version'] ?? ''} lista', text: 'Archivo reemplazado y analizado.', autoClose: const Duration(milliseconds: 1800));
    } else if (r.background) {
      _watchAnalysis(id, title: title, prevAnalyzedAt: meta['ai_analyzed_at']?.toString(), prevErrorAt: meta['ai_error_at']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 600;
    final isTable = width > 980;
    final pad = isWeb ? 28.0 : 16.0;

    return Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Documentos'],
              title: 'Documentos',
              subtitle: 'Sube tus archivos, analízalos con IA y fírmalos con registro en blockchain.',
              actions: [
                BSOutlineButton(label: 'Actualizar', icon: Icons.refresh_rounded, onPressed: _isLoading ? null : _load),
                BSPrimaryButton(
                  label: _isUploading ? 'Subiendo...' : 'Subir documento',
                  icon: Icons.upload_file_rounded,
                  loading: _isUploading,
                  onPressed: _upload,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Resumen por estado (sirve también de filtro rápido)
            _StatusTabs(
              stats: _stats,
              selected: _selStatus,
              onSelect: (v) { setState(() => _selStatus = v); _load(); },
            ),
            const SizedBox(height: 16),

            // Filtros
            BSCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isWeb ? (width > 1250 ? 460 : 320) : double.infinity,
                    height: 44,
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (_) => _load(),
                      onChanged: (v) { setState(() {}); if (v.isEmpty) _load(); },
                      style: const TextStyle(color: AppTheme.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, autor, etiqueta o descripción…',
                        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.hint, size: 16), onPressed: () { _searchCtrl.clear(); _load(); })
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.6)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  BSFilterDropdown(
                    label: 'Tipo',
                    value: _selExt ?? 'Todos',
                    options: _exts,
                    display: (s) => s == 'Todos' ? 'Todos' : s.toUpperCase(),
                    onChanged: (v) { setState(() => _selExt = v == 'Todos' ? null : v); _load(); },
                  ),
                  BSFilterDropdown(
                    label: 'Categoría',
                    value: _selCategory ?? 'Todos',
                    options: _categories,
                    onChanged: (v) { setState(() => _selCategory = v == 'Todos' ? null : v); _load(); },
                  ),
                  if (_hasFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(foregroundColor: BSColors.danger, minimumSize: const Size(0, 40)),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Limpiar filtros', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista / tabla
            BSCard(
              padding: EdgeInsets.zero,
              child: _buildList(isTable),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool isTable) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: _EmptyState(onUpload: _upload, filtered: _hasFilters, onClear: _clearFilters),
      );
    }

    final rows = <Widget>[];
    if (isTable) rows.add(const _TableHeader());
    for (var i = 0; i < _docs.length; i++) {
      final doc = _docs[i];
      final docId = doc['id']?.toString() ?? '';
      final info = _DocInfo.from(doc);
      final actions = _DocActions(
        info: info,
        isSigning: _signingDocId == docId,
        onSign: () => _sign(docId, info.title),
        onDetail: () => _showDetail(doc),
        onEdit: () => _showDetail(doc, tab: 3),
        onSend: () => _sendByEmail(doc),
        onReanalyze: () => _reanalyze(docId),
        onDelete: () => _delete(docId, info.title),
        quick: isTable,
      );
      // Cada fila aparece con un pequeño escalonado
      rows.add(BSEntrance(
        key: ValueKey('doc-$docId'),
        delay: Duration(milliseconds: 35 * (i < 12 ? i : 12)),
        offsetY: 10,
        // Material transparente: así el resaltado al pasar el mouse se ve sobre la tarjeta blanca
        child: Material(
          type: MaterialType.transparency,
          child: isTable
              ? _DocRow(info: info, actions: actions, onTap: () => _showDetail(doc))
              : _DocTile(info: info, actions: actions, onTap: () => _showDetail(doc)),
        ),
      ));
      if (i < _docs.length - 1) rows.add(const Divider(height: 1, color: AppTheme.border));
    }
    rows.add(Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: Text(
        'Mostrando ${_docs.length} ${_docs.length == 1 ? 'documento' : 'documentos'}',
        style: const TextStyle(color: AppTheme.hint, fontSize: 12),
      ),
    ));
    return Column(children: rows);
  }
}

// ── Pestañas de resumen por estado (Todos · Por firmar · Firmados · Verificados) ──
class _StatusTabs extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _StatusTabs({required this.stats, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    int n(String k) => int.tryParse('${stats[k] ?? 0}') ?? 0;
    final tabs = <(String, String?, int, Color)>[
      ('Todos', null, n('total'), AppTheme.primary),
      ('Por firmar', 'pending', n('pending'), BSColors.warning),
      ('Firmados', 'signed', n('signed'), AppTheme.primary),
      ('Verificados', 'verified', n('verified'), BSColors.success),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final t in tabs) _StatusTab(label: t.$1, count: t.$3, color: t.$4, selected: selected == t.$2, onTap: () => onSelect(t.$2)),
    ]);
  }
}

class _StatusTab extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusTab({required this.label, required this.count, required this.color, required this.selected, required this.onTap});

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppTheme.primary : (_hover ? AppTheme.primary.withOpacity(0.35) : AppTheme.border)),
            boxShadow: sel ? [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: TextStyle(color: sel ? Colors.white : AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withOpacity(0.2) : widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${widget.count}', style: TextStyle(color: sel ? Colors.white : widget.color, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Datos de un documento listos para mostrar ──────────────────────────────
class _DocInfo {
  final String title, ext, status, category, dateStr, sizeStr;
  final String? aiDesc;
  final int? pages;
  bool get isPdf => ext == 'pdf';
  // 'chain' = la transacción está en la red; al tocar Firmar se vuelve a ver el progreso
  bool get canSign => status == 'pending' || status == 'chain';

  _DocInfo({required this.title, required this.ext, required this.status, required this.category, required this.dateStr, required this.sizeStr, this.aiDesc, this.pages});

  factory _DocInfo.from(Map<String, dynamic> doc) {
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final created = doc['created_at'] != null ? DateTime.parse(doc['created_at']).toLocal() : DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final pages = int.tryParse('${meta['pages'] ?? ''}');
    return _DocInfo(
      title: doc['title']?.toString() ?? 'Sin nombre',
      ext: meta['extension']?.toString() ?? 'pdf',
      status: _visibleStatus(doc['status']?.toString() ?? 'pending', meta),
      category: docCategoryOf(meta),
      aiDesc: meta['user_description']?.toString().trim().isNotEmpty == true ? meta['user_description'].toString() : meta['ai_description']?.toString(),
      dateStr: '${two(created.day)}/${two(created.month)}/${created.year}',
      sizeStr: meta['size_mb'] != null ? '${meta['size_mb']} MB' : '-',
      pages: (pages != null && pages > 0) ? pages : null,
    );
  }
}

/// Estado que se muestra: añade "en blockchain" y "revocado" según la metadata
String _visibleStatus(String status, Map<String, dynamic> meta) {
  if (status != 'pending') return status;
  final chain = meta['blockchain_status']?.toString();
  if (chain == 'sending' || chain == 'confirming') return 'chain';
  if (meta['revoked'] == true) return 'revoked';
  return status;
}

Widget _typeBox(_DocInfo info) => BSInitialBox(
      text: info.ext.toUpperCase(),
      color: info.isPdf ? BSColors.danger : AppTheme.primary,
      icon: info.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
    );

// ── Encabezado de tabla (web) ──────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: const Row(children: [
        Expanded(flex: 5, child: Text('DOCUMENTO', style: s)),
        Expanded(flex: 2, child: Text('CATEGORÍA', style: s)),
        Expanded(flex: 2, child: Text('TAMAÑO', style: s)),
        Expanded(flex: 2, child: Text('FECHA', style: s)),
        Expanded(flex: 2, child: Text('ESTADO', style: s)),
        SizedBox(width: 168, child: Text('ACCIONES', style: s)),
      ]),
    );
  }
}

// ── Fila de tabla (web) ────────────────────────────────────────────────────
class _DocRow extends StatelessWidget {
  final _DocInfo info;
  final Widget actions;
  final VoidCallback onTap;
  const _DocRow({required this.info, required this.actions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const cell = TextStyle(color: AppTheme.text, fontSize: 14);
    return InkWell(
      onTap: onTap,
      hoverColor: BSColors.selected.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              _typeBox(info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  info.aiDesc != null
                      ? Row(children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 12),
                          const SizedBox(width: 4),
                          Expanded(child: Text(info.aiDesc!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.hint, fontSize: 12))),
                        ])
                      : const Row(children: [
                          Icon(Icons.hourglass_empty_rounded, color: AppTheme.hint, size: 12),
                          SizedBox(width: 4),
                          Text('Análisis IA pendiente…', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        ]),
                ]),
              ),
            ]),
          ),
          Expanded(flex: 2, child: Text(info.category, style: const TextStyle(color: AppTheme.hint, fontSize: 13.5, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(info.pages != null ? '${info.sizeStr} · ${info.pages} págs' : info.sizeStr, style: cell)),
          Expanded(flex: 2, child: Text(info.dateStr, style: cell)),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: BSPill.docStatus(info.status))),
          SizedBox(width: 168, child: Align(alignment: Alignment.centerLeft, child: actions)),
        ]),
      ),
    );
  }
}

// ── Tarjeta (móvil) ────────────────────────────────────────────────────────
class _DocTile extends StatelessWidget {
  final _DocInfo info;
  final Widget actions;
  final VoidCallback onTap;
  const _DocTile({required this.info, required this.actions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _typeBox(info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  _Chip(label: info.ext.toUpperCase(), color: info.isPdf ? BSColors.danger : AppTheme.primary),
                  _Chip(label: info.sizeStr, color: AppTheme.hint),
                  if (info.pages != null) _Chip(label: '${info.pages} págs', color: AppTheme.hint),
                  _Chip(label: info.category, color: AppTheme.primary),
                  _Chip(label: info.dateStr, color: AppTheme.hint),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          if (info.aiDesc != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(info.aiDesc!, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4))),
              ]),
            ),
          Row(children: [
            BSPill.docStatus(info.status),
            const Spacer(),
            actions,
          ]),
        ]),
      ),
    );
  }
}

// ── Acciones de un documento: botón Firmar + menú ⋯ ────────────────────────
class _DocActions extends StatelessWidget {
  final _DocInfo info;
  final bool isSigning;
  final VoidCallback onSign, onDetail, onEdit, onSend, onReanalyze, onDelete;
  /// En la tabla de escritorio se muestran accesos rápidos (ver / enviar)
  final bool quick;

  const _DocActions({required this.info, required this.isSigning, required this.onSign, required this.onDetail, required this.onEdit, required this.onSend, required this.onReanalyze, required this.onDelete, this.quick = false});

  Widget _quick(IconData icon, String tip, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: tip,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppTheme.border)),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              hoverColor: BSColors.selected,
              child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 17, color: AppTheme.primary)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (!info.canSign && quick) ...[
        _quick(Icons.visibility_outlined, 'Ver detalle', onDetail),
        _quick(Icons.send_outlined, 'Enviar', onSend),
      ],
      if (info.canSign)
        SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: isSigning ? null : onSign,
            style: ElevatedButton.styleFrom(
              backgroundColor: BSColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BSColors.success.withOpacity(0.5),
              elevation: 0,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: isSigning
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white))
                : const Icon(Icons.draw_rounded, size: 14),
            label: const Text('Firmar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ),
      PopupMenuButton<String>(
        tooltip: 'Más acciones',
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.hint),
        onSelected: (v) {
          if (v == 'detail') onDetail();
          if (v == 'edit') onEdit();
          if (v == 'send') onSend();
          if (v == 'ai') onReanalyze();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: _MenuItem(Icons.visibility_outlined, 'Ver detalle', AppTheme.text)),
          PopupMenuItem(value: 'edit', child: _MenuItem(Icons.edit_outlined, 'Editar', AppTheme.text)),
          PopupMenuItem(value: 'send', child: _MenuItem(Icons.send_outlined, 'Enviar o pedir revisión', AppTheme.text)),
          PopupMenuItem(value: 'ai', child: _MenuItem(Icons.auto_awesome_rounded, 'Analizar con IA', AppTheme.text)),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: _MenuItem(Icons.delete_outline_rounded, 'Eliminar', BSColors.danger)),
        ],
      ),
    ]);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Sign Confirm Dialog ────────────────────────────────────────────────────
class _SignConfirmDialog extends StatefulWidget {
  final String docTitle;
  final String? signatureUrl;
  final Map<String, dynamic>? doc;

  const _SignConfirmDialog({required this.docTitle, this.signatureUrl, this.doc});

  @override
  State<_SignConfirmDialog> createState() => _SignConfirmDialogState();
}

class _SignConfirmDialogState extends State<_SignConfirmDialog> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final meta = Map<String, dynamic>.from((widget.doc?['metadata'] as Map?) ?? {});
    final ext = (meta['extension'] ?? 'pdf').toString();
    final isPdf = ext.toLowerCase() == 'pdf';
    final hash = widget.doc?['file_hash']?.toString();
    final pages = int.tryParse('${meta['pages'] ?? ''}');
    final info = [
      ext.toUpperCase(),
      if (meta['size_mb'] != null) '${meta['size_mb']} MB',
      if (pages != null && pages > 0) '$pages págs',
      docCategoryOf(meta),
    ].join(' · ');
    final hasSig = widget.signatureUrl != null;
    final narrow = MediaQuery.of(context).size.width < 560;

    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: BSColors.selected, shape: BoxShape.circle),
              child: Text('$n', style: const TextStyle(color: AppTheme.primary, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.4))),
          ]),
        );

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 0),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: BSColors.selected, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.draw_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Confirmar firma', style: TextStyle(color: AppTheme.text, fontSize: 19, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Revisa los datos antes de firmar', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.hint),
                ),
              ]),
            ),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Documento
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    BSInitialBox(
                      text: ext.toUpperCase(),
                      color: isPdf ? BSColors.danger : AppTheme.primary,
                      icon: isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.docTitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(info, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
                        if (hash != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.fingerprint_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(hash.length > 26 ? '${hash.substring(0, 14)}…${hash.substring(hash.length - 10)}' : hash,
                                  style: const TextStyle(color: AppTheme.hint, fontSize: 12, fontFamily: 'monospace')),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Firma
                Row(children: [
                  const Text('Tu firma', style: TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (hasSig) const BSPill(label: 'Registrada en tu perfil', color: BSColors.success),
                ]),
                const SizedBox(height: 8),
                Container(
                  height: narrow ? 110 : 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hasSig ? AppTheme.border : BSColors.warning, width: hasSig ? 1 : 1.4),
                  ),
                  child: Stack(children: [
                    // Línea de firma
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 26,
                      child: Container(height: 1, color: AppTheme.border),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                        child: hasSig
                            ? Image.network(
                                widget.signatureUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (ctx, child, progress) =>
                                    progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorBuilder: (_, __, ___) => _NoSignature(),
                              )
                            : _NoSignature(),
                      ),
                    ),
                  ]),
                ),
                if (!hasSig) ...[
                  const SizedBox(height: 10),
                  const BSInfoBanner(
                    title: 'No tienes firma guardada',
                    text: 'Ve a Mi perfil → Mi firma, dibújala una vez y vuelve a firmar.',
                    color: BSColors.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
                const SizedBox(height: 16),

                // Qué va a pasar
                const Text('Qué va a pasar', style: TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                step(1, 'Se combina la huella SHA-256 del archivo con tu identidad y la fecha exacta.'),
                step(2, 'Se envía una transacción al contrato en Ethereum Sepolia; verás cada paso en vivo.'),
                step(3, 'Al confirmarse en un bloque, recibes el comprobante por correo.'),
                const SizedBox(height: 12),

                // Aceptación
                InkWell(
                  onTap: hasSig ? () => setState(() => _agree = !_agree) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agree,
                          onChanged: hasSig ? (v) => setState(() => _agree = v ?? false) : null,
                          activeColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Revisé el documento y estoy de acuerdo con su contenido. Entiendo que la firma queda registrada de forma permanente.',
                            style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.4)),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),

            // Acciones
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: const BoxDecoration(color: BSColors.page, border: Border(top: BorderSide(color: AppTheme.border))),
              child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
                BSOutlineButton(label: 'Cancelar', icon: Icons.close_rounded, color: AppTheme.hint, onPressed: () => Navigator.pop(context, false)),
                BSPrimaryButton(
                  label: 'Firmar documento',
                  icon: Icons.draw_rounded,
                  onPressed: hasSig && _agree ? () => Navigator.pop(context, true) : null,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NoSignature extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.draw_outlined, color: AppTheme.hint, size: 24),
        SizedBox(height: 4),
        Text('Sin firma registrada', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onClear;
  final bool filtered;
  const _EmptyState({required this.onUpload, required this.onClear, this.filtered = false});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Icon(filtered ? Icons.search_off_rounded : Icons.description_outlined, color: AppTheme.primary, size: 28),
      ),
      const SizedBox(height: 16),
      Text(filtered ? 'Sin resultados' : 'Sin documentos aún',
          style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(filtered ? 'Ningún documento coincide con la búsqueda o los filtros.' : 'Sube tu primer PDF o Word para analizarlo y firmarlo.',
          textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
      const SizedBox(height: 20),
      filtered
          ? BSOutlineButton(label: 'Limpiar filtros', icon: Icons.close_rounded, onPressed: onClear)
          : BSPrimaryButton(label: 'Subir documento', icon: Icons.upload_file_rounded, onPressed: onUpload),
    ]));
  }
}
