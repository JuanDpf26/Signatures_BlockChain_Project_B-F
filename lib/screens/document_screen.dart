import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/skeleton.dart';
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
import '../widgets/proof_ui.dart';
import '../widgets/send_document_dialog.dart';
import '../widgets/sign_ia_assistant.dart' show SignIaFab;
import '../theme/app_theme.dart';
import 'document_viewer_screen.dart';
import '../utils/file_drop.dart';

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

  // Paginación, orden y selección múltiple
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  String _sort = 'recent';
  static const _sorts = {
    'recent': 'Más recientes',
    'oldest': 'Más antiguos',
    'name': 'Nombre (A–Z)',
    'name_desc': 'Nombre (Z–A)',
  };
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  // Arrastrar y soltar (web)
  bool _dragging = false;
  void Function()? _stopDrop;

  String? _selCategory;
  String? _selStatus;
  String? _selExt;
  String _selDate = 'Todo'; // Todo · Últimos 7 días · Últimos 30 días · Últimos 90 días
  static const _dates = ['Todo', 'Últimos 7 días', 'Últimos 30 días', 'Últimos 90 días'];
  Map<String, dynamic> _stats = {};

  final _categories = ['Todos', 'Contrato', 'Factura', 'Informe', 'Propuesta', 'Acta', 'Comunicado', 'Certificado', 'Autorización', 'Manual', 'Presupuesto', 'Documento'];
  final _statuses = ['Todos', 'pending', 'signed', 'verified', 'rejected'];
  final _exts = ['Todos', 'pdf', 'docx', 'doc'];

  bool get _hasFilters => _selCategory != null || _selStatus != null || _selExt != null || _selDate != 'Todo' || _searchCtrl.text.trim().isNotEmpty;

  String? get _dateFrom {
    final days = {'Últimos 7 días': 7, 'Últimos 30 días': 30, 'Últimos 90 días': 90}[_selDate];
    if (days == null) return null;
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) _searchCtrl.text = widget.initialSearch!;
    if (widget.initialStatus != null) _selStatus = widget.initialStatus;
    _load();
    _stopDrop = listenFileDrop(
      onHover: (v) { if (mounted && v != _dragging) setState(() => _dragging = v); },
      onDrop: (f) { if (mounted && !_isUploading) _uploadBytes(f.bytes, f.name); },
    );
  }

  @override
  void dispose() {
    _stopDrop?.call();
    SignIaFab.visible.value = true;
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
        dateFrom: _dateFrom,
        page: _page,
        sort: _sort,
      );
      if (!mounted) return;
      if (res.containsKey('documents')) {
        final pg = (res['pagination'] as Map?) ?? {};
        final docs = List<Map<String, dynamic>>.from(res['documents']);
        setState(() {
          _docs = docs;
          _total = int.tryParse('${pg['total'] ?? docs.length}') ?? docs.length;
          final pages = int.tryParse('${pg['pages'] ?? 1}') ?? 1;
          _pages = pages < 1 ? 1 : pages;
          // Solo se conservan seleccionados los que siguen en pantalla
          _selected.retainWhere((id) => docs.any((d) => d['id']?.toString() == id));
        });
        // Si la página quedó vacía (por ejemplo, tras eliminar), vuelve a la anterior
        if (docs.isEmpty && _page > 1) {
          _page = (_page - 1 < _pages) ? _page - 1 : _pages;
          return _load();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Al cambiar filtros u orden se vuelve a la primera página
  void _reload() {
    _page = 1;
    _selected.clear();
    _load();
  }

  void _goPage(int p) {
    if (p < 1 || p > _pages || p == _page) return;
    setState(() { _page = p; _selected.clear(); });
    _load();
  }

  void _clearFilters() {
    _page = 1;
    setState(() {
      _selCategory = null;
      _selStatus = null;
      _selExt = null;
      _selDate = 'Todo';
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
      await _uploadBytes(file.bytes!, file.name);
    } catch (e) {
      if (mounted) await SweetAlert.error(context, title: 'Error al subir', text: '$e');
    }
  }

  Future<void> _uploadBytes(Uint8List bytes, String name) async {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!['pdf', 'doc', 'docx'].contains(ext)) {
      showToast(context, title: 'Solo PDF o Word', text: '"$name" no es un archivo que se pueda firmar.', type: SweetAlertType.warning);
      return;
    }
    if (bytes.length > 20 * 1024 * 1024) {
      showToast(context, title: 'Archivo muy grande', text: 'El límite es 20 MB.', type: SweetAlertType.warning);
      return;
    }
    try {
      final mimeType = ext == 'pdf' ? 'application/pdf' : ext == 'doc' ? 'application/msword' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      setState(() => _isUploading = true);
      // Muestra el proceso completo: subida → huella → texto → IA → resultado
      final r = await showAnalysisProgress(context, bytes: bytes, fileName: name, mimeType: mimeType);
      if (!mounted) return;
      setState(() => _isUploading = false);
      _page = 1;
      await _load();
      if (!mounted) return;
      if (r.ok) {
        SweetAlert.success(context, title: 'Análisis guardado', autoClose: const Duration(milliseconds: 1600));
      } else if (r.background && r.docId != null) {
        _watchAnalysis(r.docId!, title: name);
      }
    } catch (e) {
      if (mounted) await SweetAlert.error(context, title: 'Error al subir', text: '$e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Acciones sobre varios documentos ──
  List<Map<String, dynamic>> get _selectedDocs =>
      _docs.where((d) => _selected.contains(d['id']?.toString())).toList();

  void _toggle(String id) {
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
    SignIaFab.visible.value = _selected.isEmpty;
  }

  void _toggleAll() => setState(() {
        if (_selected.length == _docs.length) {
          _selected.clear();
        } else {
          _selected..clear()..addAll(_docs.map((d) => d['id'].toString()));
        }
      });

  Future<void> _bulkSign() async {
    final toSign = _selectedDocs.where((d) => _DocInfo.from(d).status == 'pending').toList();
    if (toSign.isEmpty) return;
    final sig = await ProfileService.getSignature();
    if (!mounted) return;
    if (!sig.containsKey('signature')) {
      await SweetAlert.warning(context, title: 'Primero crea tu firma', text: 'Ve a Configuración → Firma manuscrita y dibújala una vez.');
      return;
    }
    final n = toSign.length;
    final ok = await SweetAlert.confirm(
      context,
      title: 'Firmar $n ${n == 1 ? 'documento' : 'documentos'}',
      text: 'Cada uno se registra en la blockchain con tu firma. Puede tardar unos segundos por documento.',
      confirmText: 'Firmar',
    );
    if (!ok || !mounted) return;
    final errors = <String>[];
    var done = 0;
    final progress = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BulkProgress(total: n, done: progress, verb: 'Firmando'),
    );
    setState(() => _bulkBusy = true);
    for (final d in toSign) {
      final r = await DocumentService.signDocument(d['id'].toString());
      if (r.containsKey('error')) errors.add('${_DocInfo.from(d).title}: ${r['error']}');
      progress.value = ++done;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() { _bulkBusy = false; _selected.clear(); });
    SignIaFab.visible.value = true;
    await _load();
    if (!mounted) return;
    final sent = n - errors.length;
    if (errors.isEmpty) {
      showToast(context, title: '$sent ${sent == 1 ? 'documento enviado' : 'documentos enviados'} a firmar',
          text: 'Verás la confirmación de la blockchain en cada uno.');
    } else {
      await SweetAlert.error(context,
          title: sent == 0 ? 'No se pudo firmar' : 'Se firmaron $sent de $n',
          text: errors.take(4).join('\n'));
    }
  }

  Future<void> _bulkDelete() async {
    final list = _selectedDocs;
    final n = list.length;
    if (n == 0) return;
    final ok = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: 'Eliminar $n ${n == 1 ? 'documento' : 'documentos'}',
      text: 'Esta acción no se puede deshacer. Los registros que ya están en blockchain se conservan allá.',
      confirmText: 'Sí, eliminar',
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    var failed = 0;
    for (final d in list) {
      final r = await DocumentService.deleteDocument(d['id'].toString());
      if (r.containsKey('error')) failed++;
    }
    if (!mounted) return;
    setState(() { _bulkBusy = false; _selected.clear(); });
    SignIaFab.visible.value = true;
    await _load();
    if (!mounted) return;
    if (failed == 0) {
      showToast(context, title: n == 1 ? 'Documento eliminado' : '$n documentos eliminados');
    } else {
      await SweetAlert.error(context, title: 'No se pudieron eliminar $failed', text: 'Inténtalo de nuevo en un momento.');
    }
  }

  Future<void> _sign(String docId, String docTitle) async {
    // Si tiene firmantes, la firma se hace desde la pestaña de firmas
    final d0 = _docs.cast<Map<String, dynamic>?>().firstWhere((d) => d?['id']?.toString() == docId, orElse: () => null);
    final cs = ((d0?['metadata'] as Map?)?['cosign'] as Map?)?['status'];
    if (d0 != null && (cs == 'collecting' || cs == 'completed')) {
      _showDetail(d0, tab: 1);
      return;
    }
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
            title: 'Análisis completado',
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
            text: '${meta['ai_error'] ?? 'El servicio de análisis no respondió.'}\n\nPuedes intentarlo de nuevo desde el detalle del documento.',
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
      builder: (_) => Dialog(
        backgroundColor: AppTheme.card,
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

    return Stack(children: [
      Positioned.fill(child: Container(
      color: BSColors.page,
      child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, (!isTable && _selected.isNotEmpty) ? 96 : 28),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado
            BSPageHeader(
              breadcrumb: const ['Inicio', 'Documentos'],
              title: 'Documentos',
              subtitle: fileDropSupported && isWeb
                  ? 'Sube tus archivos (o arrástralos a esta pantalla), revisa su análisis y fírmalos con registro en blockchain.'
                  : 'Sube tus archivos, revisa su análisis y fírmalos con registro en blockchain.',
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
              onSelect: (v) { setState(() => _selStatus = v); _reload(); },
            ),
            const SizedBox(height: 16),

            // Filtros
            BSCard(
              padding: const EdgeInsets.all(16),
              child: Builder(builder: (context) {
                final search = SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _reload(),
                    onChanged: (v) { setState(() {}); if (v.isEmpty) _reload(); },
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, autor, etiqueta o descripción…',
                      hintStyle: TextStyle(color: AppTheme.hint, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.hint, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(tooltip: 'Borrar búsqueda', icon: Icon(Icons.close_rounded, color: AppTheme.hint, size: 16), onPressed: () { _searchCtrl.clear(); _reload(); })
                          : null,
                      filled: true,
                      fillColor: AppTheme.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primary, width: 1.6)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                );
                final category = BSFilterDropdown(
                  stacked: true,
                  label: 'Categoría',
                  value: _selCategory ?? 'Todos',
                  options: _categories,
                  display: (s) => s == 'Todos' ? 'Todas' : s,
                  onChanged: (v) { setState(() => _selCategory = v == 'Todos' ? null : v); _reload(); },
                );
                final type = BSFilterDropdown(
                  stacked: true,
                  label: 'Tipo',
                  value: _selExt ?? 'Todos',
                  options: _exts,
                  display: (s) => s == 'Todos' ? (width > 980 ? 'PDF y Word' : 'Todos') : s.toUpperCase(),
                  onChanged: (v) { setState(() => _selExt = v == 'Todos' ? null : v); _reload(); },
                );
                final date = BSFilterDropdown(
                  stacked: true,
                  label: 'Fecha',
                  value: _selDate == 'Todo' ? 'Todos' : _selDate,
                  options: ['Todos', ..._dates.skip(1)],
                  display: (s) => s == 'Todos' ? 'Todo' : s,
                  onChanged: (v) { setState(() => _selDate = v == 'Todos' ? 'Todo' : v); _reload(); },
                );
                final clear = TextButton(
                  onPressed: _hasFilters ? _clearFilters : null,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary, minimumSize: const Size(0, 44)),
                  child: const Text('Limpiar', style: TextStyle(fontWeight: FontWeight.w700)),
                );
                if (width > 980) {
                  return Row(children: [
                    Expanded(flex: 5, child: search),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: category),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: type),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: date),
                    const SizedBox(width: 6),
                    clear,
                  ]);
                }
                // Celular y tableta: buscador arriba y los tres filtros del mismo ancho
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  search,
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: category),
                    const SizedBox(width: 8),
                    Expanded(child: type),
                    const SizedBox(width: 8),
                    Expanded(child: date),
                  ]),
                  if (_hasFilters) Align(alignment: Alignment.centerRight, child: clear),
                ]);
              }),
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
      )),
      if (_dragging) const Positioned.fill(child: IgnorePointer(child: _DropOverlay())),
      // Celular: las acciones de la selección quedan fijas abajo, siempre visibles
      if (!isTable && _selected.isNotEmpty)
        Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: _toolbar(false, floating: true))),
    ]);
  }

  Widget _buildList(bool isTable) {
    if (_isLoading && _docs.isEmpty) {
      return const SkeletonList(rows: 6);
    }
    if (_docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: _EmptyState(onUpload: _upload, filtered: _hasFilters, onClear: _clearFilters),
      );
    }

    final rows = <Widget>[_toolbar(isTable)];
    if (isTable) rows.add(_TableHeader(allSelected: _selected.length == _docs.length, someSelected: _selected.isNotEmpty, onToggleAll: _toggleAll));
    final selecting = _selected.isNotEmpty;
    for (var i = 0; i < _docs.length; i++) {
      final doc = _docs[i];
      final docId = doc['id']?.toString() ?? '';
      final info = _DocInfo.from(doc);
      final isSel = _selected.contains(docId);
      final actions = _DocActions(
        info: info,
        isSigning: _signingDocId == docId,
        onSign: () => _sign(docId, info.title),
        onOpen: () => _openViewer(doc),
        onDetail: () => _showDetail(doc),
        onEdit: () => _showDetail(doc, tab: 4),
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
          child: Container(
            color: isSel ? AppTheme.primary.withOpacity(AppTheme.isDark ? 0.16 : 0.06) : null,
            child: isTable
                ? _DocRow(
                    info: info,
                    actions: actions,
                    selected: isSel,
                    onSelect: () => _toggle(docId),
                    onTap: () => selecting ? _toggle(docId) : _showDetail(doc),
                  )
                : _DocTile(
                    info: info,
                    menu: _DocActions(
                      info: info,
                      isSigning: _signingDocId == docId,
                      onSign: () => _sign(docId, info.title),
                      onOpen: () => _openViewer(doc),
                      onDetail: () => _showDetail(doc),
                      onEdit: () => _showDetail(doc, tab: 4),
                      onSend: () => _sendByEmail(doc),
                      onReanalyze: () => _reanalyze(docId),
                      onDelete: () => _delete(docId, info.title),
                      menuOnly: true,
                    ),
                    isSigning: _signingDocId == docId,
                    selected: isSel,
                    selecting: selecting,
                    onLongPress: () => _toggle(docId),
                    onTap: () => selecting ? _toggle(docId) : _showDetail(doc),
                    onOpen: () => _openViewer(doc),
                    onSign: () => _sign(docId, info.title),
                    onSend: () => _sendByEmail(doc),
                  ),
          ),
        ),
      ));
      if (i < _docs.length - 1) rows.add(Divider(height: 1, color: AppTheme.border));
    }
    rows.add(_pager());
    return Stack(children: [
      Column(children: rows),
      if (_isLoading)
        Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2, color: AppTheme.primary, backgroundColor: Colors.transparent)),
    ]);
  }

  /// Barra superior de la lista: total y orden, o las acciones de la selección
  Widget _toolbar(bool isTable, {bool floating = false}) {
    final n = _selected.length;
    if (n > 0 && (isTable || floating)) {
      final toSign = _selectedDocs.where((d) => _DocInfo.from(d).status == 'pending').length;
      final narrow = MediaQuery.of(context).size.width < 600;
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
        decoration: floating
            ? BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 20, offset: const Offset(0, 6))],
              )
            : BoxDecoration(
                color: AppTheme.primary.withOpacity(AppTheme.isDark ? 0.18 : 0.07),
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
        child: Row(children: [
          IconButton(
            tooltip: 'Cancelar selección',
            onPressed: _bulkBusy ? null : () { setState(_selected.clear); SignIaFab.visible.value = true; },
            icon: Icon(Icons.close_rounded, color: AppTheme.text, size: 20),
          ),
          Expanded(
            child: Text(narrow ? '$n' : '$n ${n == 1 ? 'seleccionado' : 'seleccionados'}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (!isTable)
            TextButton(
              onPressed: _bulkBusy ? null : _toggleAll,
              child: Text(_selected.length == _docs.length ? 'Ninguno' : 'Todos'),
            ),
          if (toSign > 0) ...[
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _bulkBusy ? null : _bulkSign,
              style: FilledButton.styleFrom(backgroundColor: BSColors.success, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
              icon: const Icon(Icons.draw_rounded, size: 16),
              label: Text(narrow ? 'Firmar ($toSign)' : 'Firmar $toSign'),
            ),
          ],
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _bulkBusy ? null : _bulkDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: BSColors.danger,
              side: BorderSide(color: BSColors.danger.withOpacity(0.5)),
              minimumSize: const Size(0, 38),
              padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 12),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(narrow ? '' : 'Eliminar'),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 10, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        Expanded(
          child: Text('$_total ${_total == 1 ? 'documento' : 'documentos'}',
              style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          color: AppTheme.card,
          initialValue: _sort,
          onSelected: (v) {
            if (v == _sort) return;
            setState(() => _sort = v);
            _reload();
          },
          itemBuilder: (_) => [
            for (final e in _sorts.entries)
              PopupMenuItem(
                value: e.key,
                child: Row(children: [
                  SizedBox(width: 22, child: e.key == _sort ? Icon(Icons.check_rounded, size: 18, color: AppTheme.primary) : null),
                  const SizedBox(width: 6),
                  Text(e.value, style: TextStyle(color: AppTheme.text, fontSize: 14)),
                ]),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sort_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(_sorts[_sort]!, style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Pie con "1–20 de 45" y botones de página
  Widget _pager() {
    const per = 20;
    final from = _total == 0 ? 0 : (_page - 1) * per + 1;
    final to = from == 0 ? 0 : from + _docs.length - 1;
    final label = Text(
      _pages > 1 ? '$from–$to de $_total' : 'Mostrando $_total ${_total == 1 ? 'documento' : 'documentos'}',
      style: TextStyle(color: AppTheme.hint, fontSize: 12),
    );
    Widget nav(IconData icon, String tip, int target, bool enabled) => IconButton(
          tooltip: tip,
          onPressed: enabled && !_isLoading ? () => _goPage(target) : null,
          icon: Icon(icon, size: 20),
          color: AppTheme.primary,
          disabledColor: AppTheme.hint.withOpacity(0.4),
          visualDensity: VisualDensity.compact,
        );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, _pages > 1 ? 6 : 14, 10, _pages > 1 ? 6 : 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: _pages <= 1
          ? label
          : Row(children: [
              Expanded(child: label),
              nav(Icons.first_page_rounded, 'Primera página', 1, _page > 1),
              nav(Icons.chevron_left_rounded, 'Anterior', _page - 1, _page > 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('Página $_page de $_pages', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              nav(Icons.chevron_right_rounded, 'Siguiente', _page + 1, _page < _pages),
              nav(Icons.last_page_rounded, 'Última página', _pages, _page < _pages),
            ]),
    );
  }
}

/// Velo que aparece al arrastrar un archivo sobre la pantalla
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.upload_file_rounded, size: 40, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text('Suelta el archivo para subirlo', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('PDF o Word, hasta 20 MB', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// Progreso de una acción sobre varios documentos
class _BulkProgress extends StatelessWidget {
  final int total;
  final ValueNotifier<int> done;
  final String verb;
  const _BulkProgress({required this.total, required this.done, required this.verb});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: ValueListenableBuilder<int>(
            valueListenable: done,
            builder: (_, d, __) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$verb ${d < total ? d + 1 : total} de $total…', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('No cierres esta ventana.', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: total == 0 ? null : d / total, minHeight: 6, color: AppTheme.primary, backgroundColor: AppTheme.border),
              ),
            ]),
          ),
        ),
      ),
    );
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
    Widget tab((String, String?, int, Color) t, {bool fill = false}) =>
        _StatusTab(label: t.$1, count: t.$3, color: t.$4, selected: selected == t.$2, onTap: () => onSelect(t.$2), fill: fill);
    if (MediaQuery.of(context).size.width < 600) {
      return Column(children: [
        for (var i = 0; i < tabs.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(children: [
            Expanded(child: tab(tabs[i], fill: true)),
            const SizedBox(width: 10),
            Expanded(child: tab(tabs[i + 1], fill: true)),
          ]),
        ],
      ]);
    }
    return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tabs) tab(t)]);
  }
}

class _StatusTab extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  /// true → ocupa todo el ancho y centra el contenido (cuadrícula del celular)
  final bool fill;
  const _StatusTab({required this.label, required this.count, required this.color, required this.selected, required this.onTap, this.fill = false});

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
      child: BSFocusable(onTap: widget.onTap, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppTheme.primary : (_hover ? AppTheme.primary.withOpacity(0.35) : AppTheme.border)),
            boxShadow: sel ? [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))] : null,
          ),
          child: Row(mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label, style: TextStyle(color: sel ? Colors.white : AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withOpacity(0.2) : widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${widget.count}', style: TextStyle(color: sel ? Colors.white : widget.color, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      )),
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
    final ext = meta['extension']?.toString() ?? 'pdf';
    var title = doc['title']?.toString() ?? 'Sin nombre';
    // La extensión ya se ve en el ícono: el nombre se muestra sin ".pdf" / ".docx"
    if (title.toLowerCase().endsWith('.$ext') && title.length > ext.length + 1) {
      title = title.substring(0, title.length - ext.length - 1);
    }
    return _DocInfo(
      title: title,
      ext: meta['extension']?.toString() ?? 'pdf',
      status: _visibleStatus(doc['status']?.toString() ?? 'pending', meta),
      category: docCategoryOf(meta),
      aiDesc: meta['user_description']?.toString().trim().isNotEmpty == true ? meta['user_description'].toString() : meta['ai_description']?.toString(),
      dateStr: '${two(created.day)}/${two(created.month)}/${created.year}',
      sizeStr: _sizeLabel(meta),
      pages: (pages != null && pages > 0) ? pages : null,
    );
  }
}

String _sizeLabel(Map<String, dynamic> meta) {
  double? mb = double.tryParse('${meta['size_mb'] ?? ''}');
  final bytes = double.tryParse('${meta['size_bytes'] ?? meta['size'] ?? ''}');
  if (mb == null && bytes != null) mb = bytes / 1048576;
  if (mb == null) return '—';
  if (mb < 0.1) return '${(mb * 1024).toStringAsFixed(0)} KB';
  return '${mb.toStringAsFixed(2).replaceAll('.', ',')} MB';
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
  final bool allSelected, someSelected;
  final VoidCallback onToggleAll;
  const _TableHeader({required this.allSelected, required this.someSelected, required this.onToggleAll});

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(color: AppTheme.hint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: (_) => onToggleAll(),
            activeColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.hint),
          ),
        ),
        Expanded(flex: 5, child: Text('DOCUMENTO', style: s)),
        Expanded(flex: 2, child: Text('CATEGORÍA', style: s)),
        Expanded(flex: 2, child: Text('TAMAÑO', style: s)),
        Expanded(flex: 2, child: Text('FECHA', style: s)),
        Expanded(flex: 2, child: Text('ESTADO', style: s)),
        SizedBox(width: 236, child: Text('ACCIONES', style: s)),
      ]),
    );
  }
}

// ── Fila de tabla (web) ────────────────────────────────────────────────────
class _DocRow extends StatelessWidget {
  final _DocInfo info;
  final Widget actions;
  final VoidCallback onTap, onSelect;
  final bool selected;
  const _DocRow({required this.info, required this.actions, required this.onTap, required this.onSelect, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final cell = TextStyle(color: AppTheme.text, fontSize: 14);
    return InkWell(
      onTap: onTap,
      hoverColor: BSColors.selected.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 22, 14),
        child: Row(children: [
          SizedBox(
            width: 44,
            child: Checkbox(
              value: selected,
              onChanged: (_) => onSelect(),
              activeColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.hint),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(children: [
              _typeBox(info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  info.aiDesc != null
                      ? Text(info.aiDesc!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.hint, fontSize: 12))
                      : Row(children: [
                          Icon(Icons.hourglass_empty_rounded, color: AppTheme.hint, size: 12),
                          SizedBox(width: 4),
                          Text('Análisis pendiente…', style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        ]),
                ]),
              ),
            ]),
          ),
          Expanded(flex: 2, child: Text(info.category, style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(info.sizeStr, style: cell)),
          Expanded(flex: 2, child: Text(info.dateStr, style: cell)),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: BSPill.docStatus(info.status))),
          SizedBox(width: 236, child: Align(alignment: Alignment.centerLeft, child: actions)),
        ]),
      ),
    );
  }
}

// ── Tarjeta (móvil) ────────────────────────────────────────────────────────
/// Diseño simétrico: encabezado (tipo · nombre · menú), datos en una línea,
/// descripción de la IA y dos botones del mismo ancho.
class _DocTile extends StatelessWidget {
  final _DocInfo info;
  final Widget menu;
  final bool isSigning, selected, selecting;
  final VoidCallback onTap, onSign, onSend, onOpen, onLongPress;
  const _DocTile({required this.info, required this.menu, required this.isSigning, required this.onTap, required this.onSign, required this.onSend, required this.onOpen, required this.onLongPress, this.selected = false, this.selecting = false});

  @override
  Widget build(BuildContext context) {
    final meta = [info.ext.toUpperCase(), info.sizeStr, if (info.pages != null) '${info.pages} pág.', info.dateStr].join(' · ');
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final second = info.canSign
        ? ElevatedButton.icon(
            onPressed: isSigning ? null : onSign,
            style: ElevatedButton.styleFrom(
              backgroundColor: BSColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BSColors.success.withOpacity(0.5),
              elevation: 0,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: btnShape,
            ),
            icon: isSigning
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                : const Icon(Icons.draw_rounded, size: 16),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Firmar', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800))),
          )
        : ElevatedButton.icon(
            onPressed: onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.featureCyan,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: btnShape,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Enviar', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800))),
          );
    Widget outline(IconData icon, String label, VoidCallback onPressed) => OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.border),
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape: btnShape,
          ),
          icon: Icon(icon, size: 16),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700))),
        );
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // En modo selección el ícono del tipo se vuelve una casilla
            selecting
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: 1.5),
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                  )
                : _typeBox(info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 4),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.hint, fontSize: 12)),
              ]),
            ),
            if (!selecting) menu else const SizedBox(width: 10),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              Row(children: [
                BSPill.docStatus(info.status),
                const SizedBox(width: 8),
                Flexible(child: _Chip(label: info.category, color: AppTheme.primary)),
              ]),
              if (info.aiDesc != null) ...[
                const SizedBox(height: 10),
                Text(info.aiDesc!, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4)),
              ],
              const SizedBox(height: 12),
              // Ver el archivo · Ver la ficha · Acción principal
              Row(children: [
                Expanded(child: outline(Icons.visibility_outlined, 'Ver', onOpen)),
                const SizedBox(width: 8),
                Expanded(child: outline(Icons.info_outline_rounded, 'Detalles', onTap)),
                const SizedBox(width: 8),
                Expanded(child: second),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Acciones de un documento: botón Firmar + menú ⋯ ────────────────────────
class _DocActions extends StatelessWidget {
  final _DocInfo info;
  final bool isSigning;
  final VoidCallback onSign, onOpen, onDetail, onEdit, onSend, onReanalyze, onDelete;
  /// En la tabla de escritorio se muestran accesos rápidos (ver / detalles / enviar)
  final bool quick;
  /// Solo el menú ⋯ (la tarjeta del celular tiene sus propios botones)
  final bool menuOnly;

  const _DocActions({required this.info, required this.isSigning, required this.onSign, required this.onOpen, required this.onDetail, required this.onEdit, required this.onSend, required this.onReanalyze, required this.onDelete, this.quick = false, this.menuOnly = false});

  Widget _quick(IconData icon, String tip, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: tip,
          child: Material(
            color: AppTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppTheme.border)),
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
      if (quick) ...[
        _quick(Icons.visibility_outlined, 'Ver documento', onOpen),
        _quick(Icons.info_outline_rounded, 'Ver detalles', onDetail),
        if (!info.canSign) _quick(Icons.send_outlined, 'Enviar o pedir revisión', onSend),
      ],
      if (info.canSign && !menuOnly)
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
        color: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        icon: Icon(Icons.more_horiz_rounded, color: AppTheme.hint),
        onSelected: (v) {
          if (v == 'open') onOpen();
          if (v == 'detail') onDetail();
          if (v == 'edit') onEdit();
          if (v == 'send') onSend();
          if (v == 'ai') onReanalyze();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'open', child: _MenuItem(Icons.visibility_outlined, 'Ver documento', AppTheme.text)),
          PopupMenuItem(value: 'detail', child: _MenuItem(Icons.info_outline_rounded, 'Ver detalles', AppTheme.text)),
          PopupMenuItem(value: 'edit', child: _MenuItem(Icons.edit_outlined, 'Editar datos', AppTheme.text)),
          PopupMenuItem(value: 'send', child: _MenuItem(Icons.send_outlined, 'Enviar o pedir revisión', AppTheme.text)),
          PopupMenuItem(value: 'ai', child: _MenuItem(Icons.manage_search_rounded, 'Analizar contenido', AppTheme.text)),
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
      fmtTamano(meta),
      if (pages != null && pages > 0) '$pages ${pages == 1 ? 'página' : 'páginas'}',
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
              decoration: BoxDecoration(color: BSColors.selected, shape: BoxShape.circle),
              child: Text('$n', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.4))),
          ]),
        );

    return Dialog(
      backgroundColor: AppTheme.card,
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
                  child: Icon(Icons.draw_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Confirmar firma', style: TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Revisa los datos antes de firmar', style: TextStyle(color: AppTheme.hint, fontSize: 13)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close_rounded, color: AppTheme.hint),
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
                            style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(info, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        if (hash != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.fingerprint_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('Huella ${fmtHuella(hash)}',
                                  style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
                  Text('Tu firma', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (hasSig) const BSPill(label: 'Registrada en tu perfil', color: BSColors.success),
                ]),
                const SizedBox(height: 8),
                Container(
                  height: narrow ? 110 : 130,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
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
                Text('Qué va a pasar', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                step(1, 'Tu firma une la huella del archivo con tu identidad y la hora exacta.'),
                step(2, 'La firma se registra en la blockchain de Ethereum; verás cada paso en vivo.'),
                step(3, 'Cuando la red la confirme, recibirás el comprobante por correo.'),
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
                      Expanded(
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
              decoration: BoxDecoration(color: BSColors.page, border: Border(top: BorderSide(color: AppTheme.border))),
              child: narrow
                  ? Row(children: [
                      Expanded(
                        child: BSOutlineButton(
                            label: 'Cancelar', icon: Icons.close_rounded, color: AppTheme.hint, onPressed: () => Navigator.pop(context, false)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BSPrimaryButton(
                          label: 'Firmar',
                          icon: Icons.draw_rounded,
                          onPressed: hasSig && _agree ? () => Navigator.pop(context, true) : null,
                        ),
                      ),
                    ])
                  : Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
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
    return Center(
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
          style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(filtered ? 'Ningún documento coincide con la búsqueda o los filtros.' : 'Sube tu primer PDF o Word para analizarlo y firmarlo.',
          textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
      const SizedBox(height: 20),
      filtered
          ? BSOutlineButton(label: 'Limpiar filtros', icon: Icons.close_rounded, onPressed: onClear)
          : BSPrimaryButton(label: 'Subir documento', icon: Icons.upload_file_rounded, onPressed: onUpload),
    ]));
  }
}
