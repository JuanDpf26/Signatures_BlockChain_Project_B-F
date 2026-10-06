import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_service.dart';
import '../services/profile_service.dart';
import '../widgets/widgets.dart';
import '../widgets/sweet_alert.dart';
import '../widgets/bs_ui.dart';
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
      final res = await DocumentService.signDocument(docId);
      if (!mounted) return;
      if (res.containsKey('error')) {
        setState(() => _signingDocId = null);
        await SweetAlert.error(context, title: 'No se pudo firmar', text: res['error'].toString());
      } else {
        final txHash = res['signature']?['blockchain']?['txHash']?.toString();
        setState(() => _signingDocId = null);
        SweetAlert.success(
          context,
          title: 'Documento firmado',
          text: txHash != null
              ? 'La firma quedó registrada en blockchain.\nTx: ${txHash.length > 20 ? '${txHash.substring(0, 10)}…${txHash.substring(txHash.length - 8)}' : txHash}'
              : 'El documento se firmó correctamente.',
        );
        await _load();
      }
    } finally {
      if (mounted) setState(() => _signingDocId = null);
    }
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

  void _showDetail(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        doc: doc,
        isSigning: _signingDocId == doc['id']?.toString(),
        onSign: () {
          Navigator.pop(context);
          _sign(doc['id'].toString(), doc['title'] ?? '');
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(doc['id'].toString(), doc['title'] ?? '');
        },
        onReanalyze: () {
          Navigator.pop(context);
          _reanalyze(doc['id'].toString());
        },
        onUpdate: (category, tags) async {
          final res = await DocumentService.updateDocumentMeta(docId: doc['id'].toString(), category: category, tags: tags);
          if (!mounted) return;
          Navigator.pop(context);
          if (res.containsKey('error')) {
            await SweetAlert.error(context, title: 'No se pudo guardar', text: res['error'].toString());
          } else {
            SweetAlert.success(context, title: 'Cambios guardados', autoClose: const Duration(milliseconds: 1500));
            await _load();
          }
        },
      ),
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
  bool get canSign => status == 'pending';

  _DocInfo({required this.title, required this.ext, required this.status, required this.category, required this.dateStr, required this.sizeStr, this.aiDesc, this.pages});

  factory _DocInfo.from(Map<String, dynamic> doc) {
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final created = doc['created_at'] != null ? DateTime.parse(doc['created_at']).toLocal() : DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final pages = int.tryParse('${meta['pages'] ?? ''}');
    return _DocInfo(
      title: doc['title']?.toString() ?? 'Sin nombre',
      ext: meta['extension']?.toString() ?? 'pdf',
      status: doc['status']?.toString() ?? 'pending',
      category: meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento',
      aiDesc: meta['ai_description']?.toString(),
      dateStr: '${two(created.day)}/${two(created.month)}/${created.year}',
      sizeStr: meta['size_mb'] != null ? '${meta['size_mb']} MB' : '-',
      pages: (pages != null && pages > 0) ? pages : null,
    );
  }
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

// ── Detail Sheet ───────────────────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool isSigning;
  final VoidCallback onSign, onDelete, onReanalyze;
  final void Function(String, List<String>) onUpdate;

  const _DetailSheet({required this.doc, required this.isSigning, required this.onSign, required this.onDelete, required this.onReanalyze, required this.onUpdate});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late String _category;
  late List<String> _tags;
  final _tagCtrl = TextEditingController();

  final _cats = ['Documento', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    _category = meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
    final rawTags = (meta['ai_tags'] as List<dynamic>?) ?? (meta['tags'] as List<dynamic>?) ?? [];
    _tags = rawTags.map((t) => t.toString()).toList();
  }

  @override
  void dispose() { _tabs.dispose(); _tagCtrl.dispose(); super.dispose(); }

  Future<void> _openDoc() async {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => DocumentViewerScreen(
      fileUrl: widget.doc['file_url'],
      title: widget.doc['title'] ?? 'Documento',
      extension: (widget.doc['metadata']?['extension'] ?? 'pdf').toString(),
      metadata: {
        ...widget.doc['metadata'] ?? {},
        'file_hash': widget.doc['file_hash'],
      },
    ),
  ));
}

  @override
  Widget build(BuildContext context) {
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = meta['extension']?.toString() ?? 'pdf';
    final isPdf = ext == 'pdf';
    final status = widget.doc['status']?.toString() ?? 'pending';
    final canSign = status == 'pending';

    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 3, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),

          // Header del sheet
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: isPdf ? Colors.red.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded, color: isPdf ? Colors.red : AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.doc['title'] ?? 'Sin nombre', style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(ext.toUpperCase(), style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
              ])),
              Row(children: [
                // Botón firmar en modal
                if (canSign)
                  GestureDetector(
                    onTap: widget.isSigning ? null : widget.onSign,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isSigning ? AppTheme.hint.withOpacity(0.1) : AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: widget.isSigning
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.draw_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text('Firmar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(onPressed: widget.onReanalyze, icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 18), tooltip: 'Analizar con IA', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 6),
                IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ]),
          ),

          // Tabs
          TabBar(
            controller: _tabs,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.hint,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: const [Tab(text: 'Metadatos'), Tab(text: 'Análisis IA'), Tab(text: 'Editar')],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Tab metadatos
                ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
                  _MetaSection('Archivo', [
                    _MetaRow('Nombre', meta['original_name']),
                    _MetaRow('Tamaño', '${meta['size_mb']} MB (${meta['size_kb']} KB)'),
                    _MetaRow('Extensión', ext.toUpperCase()),
                    _MetaRow('Estado', bsDocStatusLabel(status)),
                    _MetaRow('Subido', widget.doc['created_at'] != null ? DateTime.parse(widget.doc['created_at']).toLocal().toString().substring(0, 16) : '-'),
                  ]),
                  if (isPdf) _MetaSection('Contenido PDF', [
                    _MetaRow('Páginas', meta['pages']?.toString()),
                    _MetaRow('Autor', meta['author']),
                    _MetaRow('Título interno', meta['doc_title']),
                    _MetaRow('Asunto', meta['subject']),
                    _MetaRow('Creado con', meta['creator']),
                    _MetaRow('Versión PDF', meta['pdf_version']),
                    _MetaRow('Fecha creación', meta['creation_date']),
                  ]),
                  _MetaSection('Texto', [
                    _MetaRow('Palabras', meta['word_count']?.toString()),
                    _MetaRow('Caracteres', meta['char_count']?.toString()),
                  ]),
                  _MetaSection('Seguridad', [
                    _MetaRow('Hash SHA-256', widget.doc['file_hash']?.toString(), mono: true, truncate: true),
                    if (widget.doc['blockchain_tx'] != null) _MetaRow('Tx blockchain', widget.doc['blockchain_tx']?.toString(), mono: true, truncate: true),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openDoc,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), foregroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Ver documento'),
                  ),
                ]),

                // Tab IA
                ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
                  if (meta['ai_description'] == null)
                    Center(child: Column(children: [
                      const SizedBox(height: 32),
                      const Icon(Icons.auto_awesome_outlined, color: AppTheme.hint, size: 36),
                      const SizedBox(height: 12),
                      const Text('Análisis pendiente', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('El documento está siendo analizado', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: widget.onReanalyze,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Analizar ahora'),
                      ),
                    ]))
                  else ...[
                    _AISection(icon: Icons.description_rounded, title: 'Descripción', content: meta['ai_description']),
                    const SizedBox(height: 14),
                    if (meta['ai_summary'] != null) _AISection(icon: Icons.summarize_rounded, title: 'Resumen', content: meta['ai_summary']),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _AIBadge(label: 'Categoría', value: meta['ai_category'] ?? '-', color: AppTheme.primary)),
                      const SizedBox(width: 10),
                      Expanded(child: _AIBadge(label: 'Confidencialidad', value: meta['ai_confidentiality'] ?? '-', color: _confColor(meta['ai_confidentiality']))),
                    ]),
                    if (meta['ai_tags'] != null) ...[
                      const SizedBox(height: 14),
                      const Text('Tags IA', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: (meta['ai_tags'] as List<dynamic>).map((t) =>
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.15))), child: Text('#$t', style: const TextStyle(color: AppTheme.primary, fontSize: 12)))).toList()),
                    ],
                    const SizedBox(height: 10),
                    Text('Analizado: ${meta['ai_analyzed_at']?.toString().substring(0, 16) ?? '-'}', style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                  ],
                ]),

                // Tab editar
                ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
                  const Text('Categoría', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: _cats.map((c) => GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _category == c ? AppTheme.primary.withOpacity(0.1) : AppTheme.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _category == c ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Text(c, style: TextStyle(color: _category == c ? AppTheme.primary : AppTheme.hint, fontSize: 12, fontWeight: _category == c ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  )).toList()),
                  const SizedBox(height: 20),
                  const Text('Tags', style: TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: _tags.map((t) => GestureDetector(
                    onTap: () => setState(() => _tags.remove(t)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('#$t', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded, color: AppTheme.primary, size: 12),
                      ]),
                    ),
                  )).toList()),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _tagCtrl,
                      onSubmitted: (v) { final t = v.trim().toLowerCase(); if (t.isNotEmpty && !_tags.contains(t)) { setState(() { _tags.add(t); _tagCtrl.clear(); }); } },
                      style: const TextStyle(color: AppTheme.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Agregar tag...', hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                        filled: true, fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () { final t = _tagCtrl.text.trim().toLowerCase(); if (t.isNotEmpty && !_tags.contains(t)) { setState(() { _tags.add(t); _tagCtrl.clear(); }); } },
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: ElevatedButton(
                      onPressed: () => widget.onUpdate(_category, _tags),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                      child: const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Color _confColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'público': case 'publico': return Colors.green;
      case 'interno': return Colors.blue;
      case 'confidencial': return Colors.orange;
      case 'secreto': return Colors.red;
      default: return AppTheme.hint;
    }
  }
}

// ── Widgets helpers ────────────────────────────────────────────────────────
class _AISection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? content;
  const _AISection({required this.icon, required this.title, this.content});

  @override
  Widget build(BuildContext context) {
    if (content == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.primary, size: 13),
          const SizedBox(width: 5),
          Text(title, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(content!, style: const TextStyle(color: AppTheme.text, fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

class _AIBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AIBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _MetaSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final valid = children.whereType<_MetaRow>().where((w) => w.value != null && w.value!.isNotEmpty).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.hint, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Container(decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)), child: Column(children: valid)),
    ]);
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool mono, truncate;
  const _MetaRow(this.label, this.value, {this.mono = false, this.truncate = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final display = truncate && value!.length > 24 ? '${value!.substring(0, 10)}...${value!.substring(value!.length - 8)}' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 12))),
        Expanded(child: Text(display, style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: mono ? 'monospace' : null))),
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
