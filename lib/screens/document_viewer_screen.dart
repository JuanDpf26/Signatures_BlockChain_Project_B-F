import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../viewers//pdf_viewer_web.dart' if (dart.library.io) 'pdf_viewer_stub.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String title;
  final String extension;
  final Map<String, dynamic> metadata;

  const DocumentViewerScreen({
    super.key,
    required this.fileUrl,
    required this.title,
    required this.extension,
    required this.metadata,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';
  double _downloadProgress = 0;
  int _currentPage = 1;
  int _totalPages = 0;
  final FocusNode _focusNode = FocusNode();

  bool get _isPdf => widget.extension.toLowerCase() == 'pdf';

  @override
  void initState() {
    super.initState();
    _loadDocument();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    // Web usa iframe — no necesita cargar nada
    if (kIsWeb) { setState(() => _isLoading = false); return; }

    // Word — solo mostrar info
    if (!_isPdf) { setState(() => _isLoading = false); return; }

    // Móvil/Desktop con pdfx
    try {
      setState(() { _isLoading = true; _hasError = false; _downloadProgress = 0; });
      final file = await _downloadFile(widget.fileUrl);
      final doc = await PdfDocument.openFile(file.path);
      _pdfController = PdfControllerPinch(document: Future.value(doc));
      setState(() { _totalPages = doc.pagesCount; _isLoading = false; });
    } catch (e) {
      setState(() { _hasError = true; _errorMsg = e.toString(); _isLoading = false; });
    }
  }

  Future<File> _downloadFile(String url) async {
    final dio = Dio();
    final dir = await getTemporaryDirectory();
    final fileName = 'doc_${url.hashCode}.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    if (await file.exists()) return file;
    await dio.download(url, filePath, onReceiveProgress: (r, t) {
      if (t > 0) setState(() => _downloadProgress = r / t);
    });
    return file;
  }

  void _prevPage() { if (_currentPage > 1) _pdfController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }
  void _nextPage() { if (_currentPage < _totalPages) _pdfController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.fileUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_totalPages > 0) Text('$_currentPage de $_totalPages páginas', style: const TextStyle(color: AppTheme.hint, fontSize: 11)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded, color: AppTheme.hint, size: 20), onPressed: _showInfo, tooltip: 'Información'),
          IconButton(icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.hint, size: 20), onPressed: _openExternal, tooltip: 'Abrir externamente'),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: !kIsWeb && _isPdf && !_isLoading && !_hasError && _totalPages > 0 ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    // Loading
    if (_isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, color: AppTheme.primary, strokeWidth: 3, backgroundColor: AppTheme.border)),
        const SizedBox(height: 20),
        Text(_downloadProgress > 0 ? 'Descargando... ${(_downloadProgress * 100).toStringAsFixed(0)}%' : 'Preparando documento...', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        if (_downloadProgress > 0) ...[
          const SizedBox(height: 16),
          SizedBox(width: 200, child: LinearProgressIndicator(value: _downloadProgress, color: AppTheme.primary, backgroundColor: AppTheme.border, borderRadius: BorderRadius.circular(4))),
        ],
      ]));
    }

    // Error
    if (_hasError) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32)),
        const SizedBox(height: 16),
        const Text('No se pudo cargar el documento', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_errorMsg, style: const TextStyle(color: AppTheme.hint, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(onPressed: _loadDocument, style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), foregroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Reintentar')),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: _openExternal, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('Abrir externamente')),
        ]),
      ])));
    }

    // Web — iframe con Google Docs viewer
    if (kIsWeb && _isPdf) {
      return PdfViewerWeb(fileUrl: widget.fileUrl);
    }

    // Word — info + botón
    if (!_isPdf) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.article_rounded, color: AppTheme.primary, size: 40)),
        const SizedBox(height: 20),
        Text(widget.title, style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${widget.metadata['size_mb'] ?? '?'} MB · ${widget.extension.toUpperCase()}', style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
        const SizedBox(height: 32),
        _DocInfoRow(icon: Icons.person_outline_rounded, label: 'Autor', value: widget.metadata['author']?.toString()),
        _DocInfoRow(icon: Icons.format_list_numbered_rounded, label: 'Palabras', value: widget.metadata['word_count']?.toString()),
        _DocInfoRow(icon: Icons.pages_rounded, label: 'Páginas', value: widget.metadata['pages']?.toString()),
        _DocInfoRow(icon: Icons.tag_rounded, label: 'Categoría', value: widget.metadata['ai_category']?.toString() ?? widget.metadata['category']?.toString()),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _openExternal,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Abrir en Word', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        )),
        const SizedBox(height: 12),
        const Text('Los archivos Word se abren con la aplicación instalada en tu dispositivo', style: TextStyle(color: AppTheme.hint, fontSize: 11), textAlign: TextAlign.center),
      ])));
    }

    // Móvil/Desktop — pdfx con navegación por teclado
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.space) _nextPage();
          else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                   event.logicalKey == LogicalKeyboardKey.pageUp) _prevPage();
        }
      },
      child: PdfViewPinch(
        controller: _pdfController!,
        onPageChanged: (page) => setState(() => _currentPage = page),
        scrollDirection: Axis.vertical,
        padding: 8,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
          errorBuilder: (_, e) => Center(child: Text(e.toString(), style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: _currentPage > 1 ? _prevPage : null),
        const SizedBox(width: 12),
        Expanded(child: SliderTheme(
          data: SliderThemeData(activeTrackColor: AppTheme.primary, inactiveTrackColor: AppTheme.border, thumbColor: AppTheme.primary, overlayColor: AppTheme.primary.withOpacity(0.1), trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
          child: Slider(
            value: _currentPage.toDouble(), min: 1, max: _totalPages.toDouble(),
            onChanged: (v) { final p = v.round(); _pdfController?.jumpToPage(p); setState(() => _currentPage = p); },
          ),
        )),
        const SizedBox(width: 12),
        _NavBtn(icon: Icons.chevron_right_rounded, onTap: _currentPage < _totalPages ? _nextPage : null),
        const SizedBox(width: 12),
        Text('$_currentPage / $_totalPages', style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
      ]),
    );
  }

  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(margin: const EdgeInsets.only(bottom: 16), width: 36, height: 3, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const Text('Información del documento', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _DocInfoRow(icon: Icons.title_rounded, label: 'Nombre', value: widget.title),
          _DocInfoRow(icon: Icons.insert_drive_file_outlined, label: 'Tipo', value: widget.extension.toUpperCase()),
          _DocInfoRow(icon: Icons.storage_rounded, label: 'Tamaño', value: '${widget.metadata['size_mb']} MB'),
          _DocInfoRow(icon: Icons.pages_rounded, label: 'Páginas', value: _totalPages > 0 ? '$_totalPages' : widget.metadata['pages']?.toString()),
          _DocInfoRow(icon: Icons.person_outline_rounded, label: 'Autor', value: widget.metadata['author']?.toString()),
          _DocInfoRow(icon: Icons.tag_rounded, label: 'Hash SHA-256', value: widget.metadata['file_hash'] != null ? '${widget.metadata['file_hash'].toString().substring(0, 16)}...' : null, mono: true),
          if (widget.metadata['ai_description'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 12), SizedBox(width: 4), Text('Descripción IA', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 6),
                Text(widget.metadata['ai_description'], style: const TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4)),
              ]),
            ),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: onTap != null ? AppTheme.primary.withOpacity(0.1) : AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: onTap != null ? AppTheme.primary.withOpacity(0.2) : AppTheme.border)),
        child: Icon(icon, color: onTap != null ? AppTheme.primary : AppTheme.hint, size: 20),
      ),
    );
  }
}

class _DocInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool mono;
  const _DocInfoRow({required this.icon, required this.label, this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppTheme.hint, size: 15),
        const SizedBox(width: 10),
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 12))),
        Expanded(child: Text(value!, style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: mono ? 'monospace' : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}