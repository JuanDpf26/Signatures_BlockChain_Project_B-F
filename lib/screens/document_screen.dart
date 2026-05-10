import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
    'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual',
    'Presupuesto', 'Documento',
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
        showBS(context, '✓ Documento subido con metadatos extraídos');
        await _loadDocuments();
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
        onUpdate: (category, tags) async {
          final res = await DocumentService.updateDocumentMeta(
            docId: doc['id'].toString(),
            category: category,
            tags: tags,
          );
          if (!mounted) return;
          Navigator.pop(context);
          if (res.containsKey('error')) {
            showBS(context, res['error'], isError: true);
          } else {
            showBS(context, 'Documento actualizado');
            await _loadDocuments();
          }
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
              child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      final res = await DocumentService.deleteDocument(docId);
      if (!mounted) return;
      if (res.containsKey('error')) {
        showBS(context, res['error'], isError: true);
      } else {
        showBS(context, 'Documento eliminado');
        await _loadDocuments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Text('Documentos',
                  style: TextStyle(color: AppTheme.text, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const Spacer(),
              if (_documents.isNotEmpty)
                Text('${_documents.length} archivos',
                    style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
            ],
          ),
        ),

        // Búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _loadDocuments(),
            onChanged: (v) { if (v.isEmpty) _loadDocuments(); },
            style: const TextStyle(color: AppTheme.text),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, autor, categoría...',
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            children: [
              // Tipo archivo
              _FilterDropdown(
                label: 'Tipo',
                icon: Icons.insert_drive_file_rounded,
                value: _selectedExt ?? 'Todos',
                options: _exts,
                onChanged: (v) { setState(() => _selectedExt = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              // Categoría
              _FilterDropdown(
                label: 'Categoría',
                icon: Icons.category_rounded,
                value: _selectedCategory ?? 'Todos',
                options: _categories,
                onChanged: (v) { setState(() => _selectedCategory = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              // Estado
              _FilterDropdown(
                label: 'Estado',
                icon: Icons.flag_rounded,
                value: _selectedStatus ?? 'Todos',
                options: _statuses,
                onChanged: (v) { setState(() => _selectedStatus = v); _loadDocuments(); },
              ),
              const SizedBox(width: 8),
              // Limpiar filtros
              if (_selectedCategory != null || _selectedStatus != null || _selectedExt != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _selectedStatus = null;
                      _selectedExt = null;
                    });
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (ctx, i) => _DocumentCard(
                          doc: _documents[i],
                          onTap: () => _showDetail(_documents[i]),
                          onDelete: () => _delete(_documents[i]['id'].toString(), _documents[i]['title'] ?? ''),
                        ),
                      ),
                    ),
        ),

        // Botón subir
        Padding(
          padding: const EdgeInsets.all(16),
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
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final category = meta['category']?.toString() ?? 'Documento';
    final status = doc['status'] ?? 'pending';
    final author = meta['author']?.toString();
    final tags = meta['tags'] as List<dynamic>?;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                color: isPdf ? Colors.red : Colors.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['title'] ?? 'Sin nombre',
                      style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Chip(label: ext.toUpperCase(), color: isPdf ? Colors.red : Colors.blue),
                      _Chip(label: '$sizeMb MB', color: AppTheme.hint),
                      if (pages != null) _Chip(label: '$pages págs', color: AppTheme.hint),
                      _Chip(label: category, color: AppTheme.primary),
                      _Chip(label: dateStr, color: AppTheme.hint),
                    ],
                  ),
                  if (author != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, color: AppTheme.hint, size: 12),
                      const SizedBox(width: 4),
                      Text(author, style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
                    ]),
                  ],
                  if (tags != null && tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: tags.take(4).map((t) => Text('#$t',
                          style: const TextStyle(color: AppTheme.hint, fontSize: 10))).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Status + acciones
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status: status),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MODAL DETALLE DOCUMENTO
// ─────────────────────────────────────────
class _DocumentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final void Function(String category, List<String> tags) onUpdate;

  const _DocumentDetailSheet({required this.doc, required this.onDelete, required this.onUpdate});

  @override
  State<_DocumentDetailSheet> createState() => _DocumentDetailSheetState();
}

class _DocumentDetailSheetState extends State<_DocumentDetailSheet> {
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
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    _category = meta['category']?.toString() ?? 'Documento';
    _tags = List<String>.from(meta['tags'] ?? []);
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final meta = (widget.doc['metadata'] as Map<String, dynamic>?) ?? {};
    final ext = (meta['extension'] ?? 'pdf').toString().toLowerCase();
    final isPdf = ext == 'pdf';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // Título + tipo
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
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
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(ext.toUpperCase(),
                                style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Metadatos extraídos
                  const Text('METADATOS', style: TextStyle(color: AppTheme.hint,
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 10),

                  _MetaRow('Tamaño', '${meta['size_mb']} MB (${meta['size_kb']} KB)'),
                  if (meta['pages'] != null) _MetaRow('Páginas', '${meta['pages']}'),
                  if (meta['word_count'] != null) _MetaRow('Palabras', '${meta['word_count']}'),
                  if (meta['char_count'] != null) _MetaRow('Caracteres', '${meta['char_count']}'),
                  if (meta['author'] != null) _MetaRow('Autor', meta['author']),
                  if (meta['doc_title'] != null) _MetaRow('Título PDF', meta['doc_title']),
                  if (meta['subject'] != null) _MetaRow('Asunto', meta['subject']),
                  if (meta['creator'] != null) _MetaRow('Creado con', meta['creator']),
                  if (meta['producer'] != null) _MetaRow('Productor', meta['producer']),
                  if (meta['pdf_version'] != null) _MetaRow('Versión PDF', meta['pdf_version']),
                  if (meta['creation_date'] != null) _MetaRow('Fecha creación', meta['creation_date']),
                  if (meta['modification_date'] != null) _MetaRow('Última modificación', meta['modification_date']),
                  _MetaRow('Hash SHA-256', widget.doc['file_hash'] ?? '-',
                      mono: true, truncate: true),
                  _MetaRow('Subido', widget.doc['created_at'] != null
                      ? DateTime.parse(widget.doc['created_at']).toLocal().toString().substring(0, 16)
                      : '-'),

                  const SizedBox(height: 20),

                  // Categoría editable
                  const Text('CATEGORÍA', style: TextStyle(color: AppTheme.hint,
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) => GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _category == cat
                              ? AppTheme.primary.withOpacity(0.15)
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _category == cat ? AppTheme.primary : AppTheme.border,
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

                  // Tags editables
                  const Text('TAGS', style: TextStyle(color: AppTheme.hint,
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._tags.map((tag) => GestureDetector(
                        onTap: () => setState(() => _tags.remove(tag)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('#$tag', style: const TextStyle(
                                color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                            const Icon(Icons.close_rounded, color: AppTheme.primary, size: 12),
                          ]),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(color: AppTheme.text, fontSize: 13),
                          onSubmitted: _addTag,
                          decoration: InputDecoration(
                            hintText: 'Agregar tag...',
                            hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.primary)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => widget.onUpdate(_category, _tags),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Guardar cambios',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ver documento
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final url = widget.doc['file_url'];
                        if (url != null) {
                          // En web abre directo, en móvil necesita url_launcher
                          // ignore: avoid_web_libraries_in_flutter
                          if (kIsWeb) {
                            // js.context.callMethod('open', [url, '_blank']);
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        foregroundColor: AppTheme.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Ver documento', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              truncate && value!.length > 20
                  ? '${value!.substring(0, 16)}...${value!.substring(value!.length - 8)}'
                  : value!,
              style: TextStyle(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'Todos';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppTheme.primary.withOpacity(0.4) : AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {'pending': Colors.orange, 'signed': AppTheme.primary,
        'verified': Colors.green, 'rejected': Colors.red};
    final labels = {'pending': 'Pendiente', 'signed': 'Firmado',
        'verified': 'Verificado', 'rejected': 'Rechazado'};
    final color = colors[status] ?? AppTheme.hint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(labels[status] ?? status,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
            child: const Icon(Icons.description_outlined, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Sin documentos aún',
              style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
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
            label: const Text('Subir documento', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}