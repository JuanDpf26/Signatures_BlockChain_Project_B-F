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
import '../widgets/bs_ui.dart';
import '../widgets/document_detail.dart';
import '../theme/app_theme.dart';
import 'document_viewer_screen.dart';

//Juandiego son of ragnar//
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

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

  final _categories = ['Todos', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto', 'Documento'];
  final _statuses = ['Todos', 'pending', 'signed', 'verified', 'rejected'];
  final _exts = ['Todos', 'pdf', 'docx', 'doc'];

  bool get _hasFilters => _selCategory != null || _selStatus != null || _selExt != null || _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
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
      final res = await DocumentService.uploadDocument(fileBytes: file.bytes!, fileName: file.name, mimeType: mimeType);
      if (!mounted) return;
      if (res.containsKey('error')) {
        setState(() => _isUploading = false);
        await SweetAlert.error(context, title: 'No se pudo subir', text: res['error'].toString());
      } else {
        setState(() => _isUploading = false);
        SweetAlert.success(
          context,
          title: 'Documento subido',
          text: 'Lo estamos analizando con IA. En unos segundos verás su descripción.',
          autoClose: const Duration(milliseconds: 2500),
        );
        await _load();
        Future.delayed(const Duration(seconds: 6), () { if (mounted) _load(); });
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
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _signingDocId = docId);
    try {
      // Muestra el proceso real paso a paso: huella → firma → tx → bloque
      await showSigningProgress(context, docId: docId, docTitle: docTitle);
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

  Future<void> _reanalyze(String docId) async {
    final res = await DocumentService.reanalyzeDocument(docId);
    if (!mounted) return;
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo analizar', text: res['error'].toString());
    } else {
      SweetAlert.info(context, title: 'Análisis iniciado', text: 'La IA está revisando el documento. Se actualizará en unos segundos.');
      Future.delayed(const Duration(seconds: 6), () { if (mounted) _load(); });
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

  void _showDetail(Map<String, dynamic> doc) {
    final id = doc['id']?.toString() ?? '';
    final title = doc['title']?.toString() ?? '';
    showDocumentDetail(
      context,
      doc: doc,
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
      onUpdate: (category, tags) async {
        final res = await DocumentService.updateDocumentMeta(docId: id, category: category, tags: tags);
        if (!mounted) return;
        Navigator.pop(context);
        if (res.containsKey('error')) {
          await SweetAlert.error(context, title: 'No se pudo guardar', text: res['error'].toString());
        } else {
          SweetAlert.success(context, title: 'Cambios guardados', autoClose: const Duration(milliseconds: 1500));
          await _load();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 600;
    final isTable = width > 980;
    final pad = isWeb ? 28.0 : 16.0;

    final pending = _docs.where((d) => d['status'] == 'pending').length;
    final signed = _docs.where((d) => d['status'] == 'signed').length;
    final verified = _docs.where((d) => d['status'] == 'verified').length;

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

            // KPIs
            BSKpiRow(items: [
              BSKpiCard(label: 'Documentos', value: '${_docs.length}', caption: _hasFilters ? 'Con los filtros actuales' : 'En tu cuenta', color: AppTheme.primary),
              BSKpiCard(label: 'Pendientes de firma', value: '$pending', caption: pending > 0 ? 'Requieren tu firma' : 'Todo al día', color: BSColors.warning),
              BSKpiCard(label: 'Firmados', value: '$signed', caption: 'Registrados en Sepolia', color: AppTheme.featureCyan),
              BSKpiCard(label: 'Verificados', value: '$verified', caption: 'Integridad comprobada', color: BSColors.success),
            ]),
            const SizedBox(height: 16),

            // Filtros
            BSCard(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isWeb ? 320 : double.infinity,
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (_) => _load(),
                      onChanged: (v) { setState(() {}); if (v.isEmpty) _load(); },
                      style: const TextStyle(color: AppTheme.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, autor o descripción IA…',
                        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.hint, size: 16), onPressed: () { _searchCtrl.clear(); _load(); })
                            : null,
                        filled: true,
                        fillColor: BSColors.page,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
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
                  BSFilterDropdown(
                    label: 'Estado',
                    value: _selStatus ?? 'Todos',
                    options: _statuses,
                    display: bsDocStatusLabel,
                    onChanged: (v) { setState(() => _selStatus = v == 'Todos' ? null : v); _load(); },
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
        onReanalyze: () => _reanalyze(docId),
        onDelete: () => _delete(docId, info.title),
      );
      rows.add(isTable
          ? _DocRow(info: info, actions: actions, onTap: () => _showDetail(doc))
          : _DocTile(info: info, actions: actions, onTap: () => _showDetail(doc)));
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
      category: meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento',
      aiDesc: meta['ai_description']?.toString(),
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
    const s = TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: const Row(children: [
        Expanded(flex: 5, child: Text('Documento', style: s)),
        Expanded(flex: 2, child: Text('Categoría', style: s)),
        Expanded(flex: 2, child: Text('Tamaño', style: s)),
        Expanded(flex: 2, child: Text('Fecha', style: s)),
        Expanded(flex: 2, child: Text('Estado', style: s)),
        SizedBox(width: 160, child: Text('Acciones', style: s, textAlign: TextAlign.right)),
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
    const cell = TextStyle(color: AppTheme.text, fontSize: 13);
    return InkWell(
      onTap: onTap,
      hoverColor: AppTheme.primary.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              _typeBox(info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
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
          Expanded(flex: 2, child: Text(info.category, style: cell, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(info.pages != null ? '${info.sizeStr} · ${info.pages} págs' : info.sizeStr,
              style: const TextStyle(color: AppTheme.hint, fontSize: 13))),
          Expanded(flex: 2, child: Text(info.dateStr, style: const TextStyle(color: AppTheme.hint, fontSize: 13))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: BSPill.docStatus(info.status))),
          SizedBox(width: 160, child: Align(alignment: Alignment.centerRight, child: actions)),
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
  final VoidCallback onSign, onDetail, onReanalyze, onDelete;

  const _DocActions({required this.info, required this.isSigning, required this.onSign, required this.onDetail, required this.onReanalyze, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (info.canSign)
        SizedBox(
          height: 32,
          child: ElevatedButton.icon(
            onPressed: isSigning ? null : onSign,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
              elevation: 0,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
            icon: isSigning
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white))
                : const Icon(Icons.draw_rounded, size: 14),
            label: const Text('Firmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      PopupMenuButton<String>(
        tooltip: 'Más acciones',
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.hint),
        onSelected: (v) {
          if (v == 'detail') onDetail();
          if (v == 'ai') onReanalyze();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: _MenuItem(Icons.info_outline_rounded, 'Ver detalle', AppTheme.text)),
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
class _SignConfirmDialog extends StatelessWidget {
  final String docTitle;
  final String? signatureUrl;

  const _SignConfirmDialog({required this.docTitle, this.signatureUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.draw_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 10),
            Text('Confirmar firma', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),

          // Documento
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: AppTheme.hint, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(docTitle, style: const TextStyle(color: AppTheme.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 16),

          // Previsualización de firma
          const Text('Tu firma', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, height: 100,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: signatureUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      signatureUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
                      errorBuilder: (_, __, ___) => _NoSignature(),
                    ),
                  )
                : _NoSignature(),
          ),

          if (signatureUrl == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.2))),
              child: const Row(children: [
                Icon(Icons.warning_outlined, color: Colors.orange, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text('No tienes firma guardada. Ve a Perfil → Mi Firma y crea una antes de firmar.', style: TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // Info blockchain
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
            child: const Row(children: [
              Icon(Icons.link_rounded, color: AppTheme.primary, size: 14),
              SizedBox(width: 8),
              Expanded(child: Text('Esta firma se registrará en la blockchain Sepolia de forma inmutable.', style: TextStyle(color: AppTheme.hint, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 20),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.border), foregroundColor: AppTheme.hint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: signatureUrl == null ? null : () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                icon: const Icon(Icons.draw_rounded, size: 16),
                label: const Text('Firmar documento', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
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
