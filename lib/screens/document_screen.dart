import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_service.dart';
import '../services/profile_service.dart';
import '../widgets/widgets.dart';
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

  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) { showBS(context, 'No se pudo leer el archivo', isError: true); return; }
      final mimeType = file.extension == 'pdf' ? 'application/pdf' : file.extension == 'doc' ? 'application/msword' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      setState(() => _isUploading = true);
      final res = await DocumentService.uploadDocument(fileBytes: file.bytes!, fileName: file.name, mimeType: mimeType);
      if (!mounted) return;
      if (res.containsKey('error')) { showBS(context, res['error'], isError: true); } else {
        showBS(context, '✓ Documento subido. Analizando con IA...');
        await _load();
        Future.delayed(const Duration(seconds: 6), () { if (mounted) _load(); });
      }
    } catch (e) {
      if (mounted) showBS(context, 'Error: $e', isError: true);
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
        showBS(context, res['error'], isError: true);
      } else {
        final txHash = res['signature']?['blockchain']?['txHash'];
        showBS(context, txHash != null ? '✓ Firmado y registrado en blockchain' : '✓ Documento firmado exitosamente');
        await _load();
      }
    } finally {
      if (mounted) setState(() => _signingDocId = null);
    }
  }

  Future<void> _delete(String docId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar documento', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 15)),
        content: Text('¿Eliminar "$title"? Esta acción no se puede deshacer.', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      final res = await DocumentService.deleteDocument(docId);
      if (!mounted) return;
      showBS(context, res.containsKey('error') ? res['error'] : 'Documento eliminado');
      if (!res.containsKey('error')) await _load();
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
        onReanalyze: () async {
          Navigator.pop(context);
          final res = await DocumentService.reanalyzeDocument(doc['id'].toString());
          if (!mounted) return;
          showBS(context, res.containsKey('error') ? res['error'] : 'Análisis iniciado...');
          Future.delayed(const Duration(seconds: 6), () { if (mounted) _load(); });
        },
        onUpdate: (category, tags) async {
          final res = await DocumentService.updateDocumentMeta(docId: doc['id'].toString(), category: category, tags: tags);
          if (!mounted) return;
          Navigator.pop(context);
          showBS(context, res.containsKey('error') ? res['error'] : 'Actualizado');
          if (!res.containsKey('error')) await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final pad = isWeb ? 28.0 : 16.0;

    return Column(children: [
      // Header
      Padding(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
        child: Row(children: [
          const Text('Documentos', style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_docs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${_docs.length} archivos', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
        ]),
      ),

      // Búsqueda
      Padding(
        padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
        child: TextField(
          controller: _searchCtrl,
          onSubmitted: (_) => _load(),
          onChanged: (v) { if (v.isEmpty) _load(); },
          style: const TextStyle(color: AppTheme.text, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, autor, descripción IA...',
            hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.hint, size: 16), onPressed: () { _searchCtrl.clear(); _load(); })
                : null,
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),

      // Filtros
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
          children: [
            _Filter(value: _selExt ?? 'Todos', options: _exts, onChanged: (v) { setState(() => _selExt = v); _load(); }),
            const SizedBox(width: 8),
            _Filter(value: _selCategory ?? 'Todos', options: _categories, onChanged: (v) { setState(() => _selCategory = v); _load(); }),
            const SizedBox(width: 8),
            _Filter(value: _selStatus ?? 'Todos', options: _statuses, onChanged: (v) { setState(() => _selStatus = v); _load(); }),
            if (_selCategory != null || _selStatus != null || _selExt != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { setState(() { _selCategory = null; _selStatus = null; _selExt = null; }); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.2))),
                  child: const Row(children: [Icon(Icons.close_rounded, color: Colors.red, size: 12), SizedBox(width: 4), Text('Limpiar', style: TextStyle(color: Colors.red, fontSize: 11))]),
                ),
              ),
            ],
          ],
        ),
      ),

      // Lista
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _docs.isEmpty
                ? _EmptyState(onUpload: _upload)
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.all(pad),
                      itemCount: _docs.length,
                      itemBuilder: (ctx, i) {
                        final doc = _docs[i];
                        final docId = doc['id']?.toString() ?? '';
                        final isSigning = _signingDocId == docId;
                        return _DocCard(
                          doc: doc,
                          isSigning: isSigning,
                          onTap: () => _showDetail(doc),
                          onSign: doc['status'] == 'pending' ? () => _sign(docId, doc['title'] ?? '') : null,
                          onDelete: () => _delete(docId, doc['title'] ?? ''),
                        );
                      },
                    ),
                  ),
      ),

      // Botón subir
      Padding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
        child: SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _upload,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_isUploading ? 'Subiendo...' : 'Subir PDF o Word', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ),
    ]);
  }
}

// ── Doc Card ───────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool isSigning;
  final VoidCallback onTap;
  final VoidCallback? onSign;
  final VoidCallback onDelete;

  const _DocCard({required this.doc, required this.isSigning, required this.onTap, this.onSign, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = meta['extension']?.toString() ?? 'pdf';
    final isPdf = ext == 'pdf';
    final status = doc['status']?.toString() ?? 'pending';
    final category = meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
    final aiDesc = meta['ai_description']?.toString();
    final created = doc['created_at'] != null ? DateTime.parse(doc['created_at']).toLocal() : DateTime.now();
    final dateStr = '${created.day}/${created.month}/${created.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSigning ? AppTheme.primary.withOpacity(0.4) : AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ícono tipo
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded, color: isPdf ? Colors.red : AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['title'] ?? 'Sin nombre', style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                _Chip(label: ext.toUpperCase(), color: isPdf ? Colors.red : AppTheme.primary),
                _Chip(label: '${meta['size_mb']} MB', color: AppTheme.hint),
                if (meta['pages'] != null && meta['pages'] != 0) _Chip(label: '${meta['pages']} págs', color: AppTheme.hint),
                _Chip(label: category, color: AppTheme.primary),
                _Chip(label: dateStr, color: AppTheme.hint),
              ]),
            ])),

            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _StatusBadge(status: status),
              const SizedBox(height: 8),
              Row(children: [
                // Botón firmar en lista
                if (status == 'pending' && onSign != null)
                  GestureDetector(
                    onTap: isSigning ? null : onSign,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSigning ? AppTheme.hint.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSigning ? AppTheme.border : AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: isSigning
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.draw_rounded, color: AppTheme.primary, size: 12),
                              SizedBox(width: 3),
                              Text('Firmar', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16)),
              ]),
            ]),
          ]),

          // Descripción IA
          if (aiDesc != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 11),
                  SizedBox(width: 4),
                  Text('Análisis IA', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text(aiDesc, style: const TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4)),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.hourglass_empty_rounded, color: AppTheme.hint, size: 11),
              SizedBox(width: 4),
              Text('Análisis IA pendiente...', style: TextStyle(color: AppTheme.hint, fontSize: 11)),
            ]),
          ],
        ]),
      ),
    );
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
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.border), foregroundColor: AppTheme.hint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: signatureUrl == null ? null : () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
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
                    _MetaRow('Estado', status),
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
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
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
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
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

class _Filter extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _Filter({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = value != 'Todos';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary.withOpacity(0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTheme.primary.withOpacity(0.3) : AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: active ? AppTheme.primary : AppTheme.hint, size: 16),
          dropdownColor: AppTheme.surface,
          style: TextStyle(color: active ? AppTheme.primary : AppTheme.hint, fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {'pending': (Colors.orange, 'Pendiente'), 'signed': (AppTheme.primary, 'Firmado'), 'verified': (Colors.green, 'Verificado'), 'rejected': (Colors.red, 'Rechazado')};
    final (color, label) = map[status] ?? (AppTheme.hint, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)), child: const Icon(Icons.description_outlined, color: AppTheme.hint, size: 28)),
      const SizedBox(height: 16),
      const Text('Sin documentos aún', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('Sube tu primer PDF o Word', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onUpload,
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Subir documento', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    ]));
  }
}