import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_service.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;

  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedExt;

  final List<String> _categories = [
    'Todos', 'Contrato', 'Factura', 'Informe', 'Propuesta',
    'Acta', 'Comunicado', 'Certificado', 'Autorización',
    'Manual', 'Presupuesto', 'Documento',
  ];
  final List<String> _statuses = ['Todos', 'pending', 'signed', 'verified', 'rejected'];
  final List<String> _exts = ['Todos', 'pdf', 'docx', 'doc'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final res = await DocumentService.getDocuments(
        search: _searchController.text.trim(),
        category: (_selectedCategory == 'Todos' || _selectedCategory == null) ? null : _selectedCategory,
        status: (_selectedStatus == 'Todos' || _selectedStatus == null) ? null : _selectedStatus,
        ext: (_selectedExt == 'Todos' || _selectedExt == null) ? null : _selectedExt,
      );
      if (!mounted) return;
      if (res.containsKey('documents')) {
        setState(() => _documents = List<Map<String, dynamic>>.from(res['documents']));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        showBS(context, 'No se pudo leer el archivo', isError: true);
        return;
      }

      final mimeType = file.extension == 'pdf'
          ? 'application/pdf'
          : file.extension == 'doc'
              ? 'application/msword'
              : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      setState(() => _isUploading = true);
      final res = await DocumentService.uploadDocument(
        fileBytes: file.bytes!,
        fileName: file.name,
        mimeType: mimeType,
      );

      if (!mounted) return;
      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(context, '✓ Documento subido. Analizando con IA...');
        await _loadDocuments();
        // Recargar después de 5s para mostrar análisis IA
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _loadDocuments();
        });
      }
    } catch (e) {
      if (mounted) showBS(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showDetail(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentDetailSheet(
        doc: doc,
        onDelete: () {
          Navigator.pop(context);
          _delete(doc['id'].toString(), doc['title'] ?? '');
        },
        onReanalyze: () async {
          Navigator.pop(context);
          final res = await DocumentService.reanalyzeDocument(doc['id'].toString());
          if (!mounted) return;
          showBS(context, res.containsKey('error') ? res['error'] : 'Análisis iniciado...');
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) _loadDocuments();
          });
        },
        onUpdate: (category, tags) async {
          final res = await DocumentService.updateDocumentMeta(
            docId: doc['id'].toString(),
            category: category,
            tags: tags,
          );
          if (!mounted) return;
          Navigator.pop(context);
          showBS(context, res.containsKey('error') ? res['error'] : 'Actualizado');
          if (!res.containsKey('error')) await _loadDocuments();
        },
      ),
    );
  }

  Future<void> _delete(String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar documento',
            style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "$title"? Esta acción no se puede deshacer.',
            style: const TextStyle(color: AppTheme.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      final res = await DocumentService.deleteDocument(docId);
      if (!mounted) return;
      showBS(context, res.containsKey('error') ? res['error'] : 'Eliminado');
      if (!res.containsKey('error')) await _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(isWeb ? 28 : 16, 20, isWeb ? 28 : 16, 0),
          child: Row(
            children: [
              const Text('Documentos',
                  style: TextStyle(color: AppTheme.text, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const Spacer(),
              if (_documents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_documents.length} archivos',
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),

        // Búsqueda
        Padding(
          padding: EdgeInsets.fromLTRB(isWeb ? 28 : 16, 14, isWeb ? 28 : 16, 0),
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _loadDocuments(),
            onChanged: (v) { if (v.isEmpty) _loadDocuments(); },
            style: const TextStyle(color: AppTheme.text),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, autor, descripción IA...',
              hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hint, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppTheme.hint, size: 18),
                      onPressed: () { _searchController.clear(); _loadDocuments(); })
                  : null,
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Filtros
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(isWeb ? 28 : 16, 10, isWeb ? 28 : 16, 0),
            children: [
              _FilterDropdown(
                label: 'Tipo', icon: Icons.insert_drive_file_rounded,
                value: _selectedExt ?? 'Todos', options: _exts,
                onChanged: (v) { setState(() => _selectedExt = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                label: 'Categoría', icon: Icons.category_rounded,
                value: _selectedCategory ?? 'Todos', options: _categories,
                onChanged: (v) { setState(() => _selectedCategory = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                label: 'Estado', icon: Icons.flag_rounded,
                value: _selectedStatus ?? 'Todos', options: _statuses,
                onChanged: (v) { setState(() => _selectedStatus = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              if (_selectedCategory != null || _selectedStatus != null || _selectedExt != null)
                GestureDetector(
                  onTap: () {
                    setState(() { _selectedCategory = null; _selectedStatus = null; _selectedExt = null; });
                    _loadDocuments();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.close_rounded, color: Colors.red, size: 14),
                      SizedBox(width: 4),
                      Text('Limpiar', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _documents.isEmpty
                  ? _EmptyState(onUpload: _pickAndUpload)
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _loadDocuments,
                      child: ListView.builder(
                        padding: EdgeInsets.all(isWeb ? 28 : 16),
                        itemCount: _documents.length,
                        itemBuilder: (ctx, i) => _DocumentCard(
                          doc: _documents[i],
                          onTap: () => _showDetail(_documents[i]),
                          onDelete: () => _delete(
                              _documents[i]['id'].toString(),
                              _documents[i]['title'] ?? ''),
                        ),
                      ),
                    ),
        ),

        // Botón subir
        Padding(
          padding: EdgeInsets.fromLTRB(isWeb ? 28 : 16, 0, isWeb ? 28 : 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: _isUploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(_isUploading ? 'Subiendo...' : 'Subir PDF o Word',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// DOCUMENT CARD
// ─────────────────────────────────────────
class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({required this.doc, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = (meta['extension'] ?? 'pdf').toString().toLowerCase();
    final isPdf = ext == 'pdf';
    final sizeMb = meta['size_mb']?.toString() ?? '?';
    final pages = meta['pages']?.toString();
    final category = meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
    final status = doc['status'] ?? 'pending';
    final author = meta['author']?.toString();
    final aiDescription = meta['ai_description']?.toString();
    final aiConfidentiality = meta['ai_confidentiality']?.toString();
    final tags = (meta['ai_tags'] as List<dynamic>?) ?? (meta['tags'] as List<dynamic>?);

    final createdAt = doc['created_at'] != null
        ? DateTime.parse(doc['created_at']).toLocal()
        : DateTime.now();
    final dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono tipo
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isPdf ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                    color: isPdf ? Colors.red : Colors.blue, size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title'] ?? 'Sin nombre',
                          style: const TextStyle(color: AppTheme.text,
                              fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5, runSpacing: 4,
                        children: [
                          _Chip(label: ext.toUpperCase(),
                              color: isPdf ? Colors.red : Colors.blue),
                          _Chip(label: '$sizeMb MB', color: AppTheme.hint),
                          if (pages != null && pages != '0')
                            _Chip(label: '$pages págs', color: AppTheme.hint),
                          _Chip(label: category, color: AppTheme.primary),
                          _Chip(label: dateStr, color: AppTheme.hint),
                          if (aiConfidentiality != null)
                            _Chip(
                              label: aiConfidentiality,
                              color: _confidentialityColor(aiConfidentiality),
                            ),
                        ],
                      ),
                      if (author != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              color: AppTheme.hint, size: 12),
                          const SizedBox(width: 4),
                          Text(author,
                              style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                        ]),
                      ],
                    ],
                  ),
                ),

                // Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(status: status),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 18),
                    ),
                  ],
                ),
              ],
            ),

            // Descripción IA
            if (aiDescription != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppTheme.primary, size: 12),
                      SizedBox(width: 4),
                      Text('Análisis IA',
                          style: TextStyle(color: AppTheme.primary,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    Text(aiDescription,
                        style: const TextStyle(
                            color: AppTheme.hint, fontSize: 12, height: 1.4)),
                    if (tags != null && tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: tags.take(5).map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('#$t',
                              style: const TextStyle(
                                  color: AppTheme.hint, fontSize: 10)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.hourglass_empty_rounded,
                    color: AppTheme.hint, size: 12),
                const SizedBox(width: 4),
                const Text('Análisis IA pendiente...',
                    style: TextStyle(color: AppTheme.hint, fontSize: 11)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Color _confidentialityColor(String level) {
    switch (level.toLowerCase()) {
      case 'público': case 'publico': return Colors.green;
      case 'interno': return Colors.blue;
      case 'confidencial': return Colors.orange;
      case 'secreto': return Colors.red;
      default: return AppTheme.hint;
    }
  }
}

// ─────────────────────────────────────────
// MODAL DETALLE
// ─────────────────────────────────────────
class _DocumentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final VoidCallback onReanalyze;
  final void Function(String category, List<String> tags) onUpdate;

  const _DocumentDetailSheet({
    required this.doc, required this.onDelete,
    required this.onReanalyze, required this.onUpdate,
  });

  @override
  State<_DocumentDetailSheet> createState() => _DocumentDetailSheetState();
}

class _DocumentDetailSheetState extends State<_DocumentDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _category;
  final _tagController = TextEditingController();
  late List<String> _tags;

  final List<String> _categories = [
    'Documento', 'Contrato', 'Factura', 'Informe', 'Propuesta',
    'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    _category = meta['ai_category']?.toString() ?? meta['category']?.toString() ?? 'Documento';
    final rawTags = (meta['ai_tags'] as List<dynamic>?) ?? (meta['tags'] as List<dynamic>?) ?? [];
    _tags = rawTags.map((t) => t.toString()).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 8) {
      setState(() => _tags.add(t));
      _tagController.clear();
    }
  }

  Future<void> _openDocument() async {
    final url = widget.doc['file_url']?.toString();
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = (meta['extension'] ?? 'pdf').toString().toLowerCase();
    final isPdf = ext == 'pdf';
    final aiSummary = meta['ai_summary']?.toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),

            // Header del modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isPdf ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                        color: isPdf ? Colors.red : Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.doc['title'] ?? 'Sin nombre',
                            style: const TextStyle(color: AppTheme.text,
                                fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(ext.toUpperCase(),
                            style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onReanalyze,
                    icon: const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.primary, size: 20),
                    tooltip: 'Re-analizar con IA',
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.hint,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(text: 'Metadatos'),
                Tab(text: 'Análisis IA'),
                Tab(text: 'Editar'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: Metadatos
                  ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _MetaSection('Archivo', [
                        _MetaRow('Nombre original', meta['original_name']),
                        _MetaRow('Tamaño', '${meta['size_mb']} MB (${meta['size_kb']} KB)'),
                        _MetaRow('Extensión', ext.toUpperCase()),
                        _MetaRow('Estado', widget.doc['status']),
                        _MetaRow('Subido', widget.doc['created_at'] != null
                            ? DateTime.parse(widget.doc['created_at']).toLocal().toString().substring(0, 16)
                            : '-'),
                      ]),
                      if (isPdf) _MetaSection('Documento PDF', [
                        _MetaRow('Páginas', meta['pages']?.toString()),
                        _MetaRow('Autor', meta['author']),
                        _MetaRow('Título interno', meta['doc_title']),
                        _MetaRow('Asunto', meta['subject']),
                        _MetaRow('Creado con', meta['creator']),
                        _MetaRow('Productor', meta['producer']),
                        _MetaRow('Versión PDF', meta['pdf_version']),
                        _MetaRow('Fecha creación', meta['creation_date']),
                        _MetaRow('Última modificación', meta['modification_date']),
                      ]),
                      _MetaSection('Contenido', [
                        _MetaRow('Palabras', meta['word_count']?.toString()),
                        _MetaRow('Caracteres', meta['char_count']?.toString()),
                        _MetaRow('Tiene texto', meta['has_text'] == true ? 'Sí' : 'No'),
                      ]),
                      _MetaSection('Seguridad', [
                        _MetaRow('Hash SHA-256', meta['file_hash'] ?? widget.doc['file_hash'],
                            mono: true, truncate: true),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _openDocument,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primary),
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Ver documento',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),

                  // TAB 2: Análisis IA
                  ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (meta['ai_description'] == null) ...[
                        Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 32),
                              const Icon(Icons.auto_awesome_rounded,
                                  color: AppTheme.hint, size: 40),
                              const SizedBox(height: 12),
                              const Text('Análisis pendiente',
                                  style: TextStyle(color: AppTheme.text,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text('El documento está siendo analizado por IA',
                                  style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: widget.onReanalyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Analizar ahora'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Descripción
                        _AISection(
                          icon: Icons.description_rounded,
                          title: 'Descripción',
                          content: meta['ai_description'],
                        ),
                        const SizedBox(height: 16),

                        // Resumen
                        if (aiSummary != null)
                          _AISection(
                            icon: Icons.summarize_rounded,
                            title: 'Resumen',
                            content: aiSummary,
                          ),
                        const SizedBox(height: 16),

                        // Categoría y confidencialidad
                        Row(children: [
                          Expanded(child: _AIBadge(
                            label: 'Categoría',
                            value: meta['ai_category'] ?? '-',
                            color: AppTheme.primary,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _AIBadge(
                            label: 'Confidencialidad',
                            value: meta['ai_confidentiality'] ?? '-',
                            color: _confColor(meta['ai_confidentiality']),
                          )),
                        ]),
                        const SizedBox(height: 16),

                        // Tags IA
                        if (meta['ai_tags'] != null) ...[
                          const Text('Tags generados por IA',
                              style: TextStyle(color: AppTheme.hint,
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: (meta['ai_tags'] as List<dynamic>).map((t) =>
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.primary.withOpacity(0.2)),
                                ),
                                child: Text('#$t',
                                    style: const TextStyle(
                                        color: AppTheme.primary, fontSize: 12)),
                              )
                            ).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text('Analizado: ${meta['ai_analyzed_at']?.toString().substring(0, 16) ?? '-'}',
                            style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                      ],
                    ],
                  ),

                  // TAB 3: Editar
                  ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('Categoría',
                          style: TextStyle(color: AppTheme.hint,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _categories.map((cat) => GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _category == cat
                                  ? AppTheme.primary.withOpacity(0.15)
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _category == cat
                                    ? AppTheme.primary : AppTheme.border,
                              ),
                            ),
                            child: Text(cat, style: TextStyle(
                              color: _category == cat ? AppTheme.primary : AppTheme.hint,
                              fontSize: 12, fontWeight: FontWeight.w600,
                            )),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),

                      const Text('Tags personalizados',
                          style: TextStyle(color: AppTheme.hint,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _tags.map((tag) => GestureDetector(
                          onTap: () => setState(() => _tags.remove(tag)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('#$tag', style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 12)),
                              const SizedBox(width: 4),
                              const Icon(Icons.close_rounded,
                                  color: AppTheme.primary, size: 12),
                            ]),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            onSubmitted: _addTag,
                            style: const TextStyle(color: AppTheme.text, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Agregar tag...',
                              hintStyle: const TextStyle(
                                  color: AppTheme.hint, fontSize: 13),
                              filled: true, fillColor: AppTheme.background,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.border)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.primary)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _addTag(_tagController.text),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: () => widget.onUpdate(_category, _tags),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Guardar cambios',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _AISection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? content;
  const _AISection({required this.icon, required this.title, this.content});

  @override
  Widget build(BuildContext context) {
    if (content == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.primary, size: 14),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(
                color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(content!, style: const TextStyle(
              color: AppTheme.text, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _AIBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AIBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _MetaSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    final validChildren = children.whereType<_MetaRow>()
        .where((w) => w.value != null && w.value!.isNotEmpty).toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title.toUpperCase(), style: const TextStyle(
            color: AppTheme.hint, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: validChildren),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool mono;
  final bool truncate;

  const _MetaRow(this.label, this.value, {this.mono = false, this.truncate = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final display = truncate && value!.length > 24
        ? '${value!.substring(0, 10)}...${value!.substring(value!.length - 8)}'
        : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(
                color: AppTheme.hint, fontSize: 12)),
          ),
          Expanded(
            child: Text(display, style: TextStyle(
              color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500,
              fontFamily: mono ? 'monospace' : null,
            )),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label, required this.icon,
    required this.value, required this.options, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'Todos';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive ? AppTheme.primary.withOpacity(0.4) : AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isActive ? AppTheme.primary : AppTheme.hint, size: 16),
          dropdownColor: AppTheme.surface,
          style: TextStyle(
            color: isActive ? AppTheme.primary : AppTheme.hint,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o, style: const TextStyle(fontSize: 12)),
          )).toList(),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange, 'signed': AppTheme.primary,
      'verified': Colors.green, 'rejected': Colors.red,
    };
    final labels = {
      'pending': 'Pendiente', 'signed': 'Firmado',
      'verified': 'Verificado', 'rejected': 'Rechazado',
    };
    final color = colors[status] ?? AppTheme.hint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(labels[status] ?? status, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.description_outlined,
                color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Sin documentos aún',
              style: TextStyle(color: AppTheme.text,
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Sube tu primer PDF o Word',
              style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Subir documento',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}