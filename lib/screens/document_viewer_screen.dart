import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/document_detail.dart';
import '../widgets/sign_ia_assistant.dart';
import '../viewers/pdf_viewer_web.dart' if (dart.library.io) '../viewers/pdf_viewer_stub.dart';

/// Visor de documentos.
/// - Computador (> 1000 px): documento a la izquierda y panel de información a la derecha.
/// - Celular: documento a pantalla completa; la información se abre desde el botón ⓘ.
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
  bool _showPanel = true;
  final FocusNode _focusNode = FocusNode();

  late final DocView _d = DocView.fromMeta({
    ...widget.metadata,
    'title': widget.metadata['title'] ?? widget.title,
    'file_url': widget.fileUrl,
  });

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
    // Web usa el visor del navegador (iframe) — no hay que descargar nada
    if (kIsWeb || !_isPdf) {
      setState(() => _isLoading = false);
      return;
    }
    // Móvil / escritorio con pdfx
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _downloadProgress = 0;
      });
      final file = await _downloadFile(widget.fileUrl);
      final doc = await PdfDocument.openFile(file.path);
      _pdfController = PdfControllerPinch(document: Future.value(doc));
      setState(() {
        _totalPages = doc.pagesCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<File> _downloadFile(String url) async {
    final dio = Dio();
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/doc_${url.hashCode}.pdf';
    final file = File(filePath);
    if (await file.exists()) return file;
    await dio.download(url, filePath, onReceiveProgress: (r, t) {
      if (t > 0 && mounted) setState(() => _downloadProgress = r / t);
    });
    return file;
  }

  void _prevPage() {
    if (_currentPage > 1) _pdfController?.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  void _nextPage() {
    if (_currentPage < _totalPages) _pdfController?.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.fileUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ..._panelChildren(),
          ]),
        ),
      ),
    );
  }

  List<Widget> _panelChildren() => [
        DocIntegrityCard(d: _d),
        const SizedBox(height: 12),
        DocFichaCard(d: _d),
        const SizedBox(height: 12),
        DocAiCard(d: _d),
        const SizedBox(height: 12),
        DocSecurityCard(d: _d),
      ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 1000;

    final docId = widget.metadata['id']?.toString();
    return Scaffold(
      backgroundColor: BSColors.page,
      // Sign IA: preguntar sobre este documento
      floatingActionButton: docId == null
          ? null
          : SignIaFab(
              extended: wide,
              onTap: () => showSignIa(
                context,
                onNavigate: (_) => Navigator.of(context).popUntil((r) => r.isFirst),
                documentId: docId,
                documentTitle: widget.title,
              ),
            ),
      body: SafeArea(
        child: Column(children: [
          _TopBar(
            d: _d,
            pagesLabel: _totalPages > 0 ? 'Página $_currentPage de $_totalPages' : null,
            wide: wide,
            panelOpen: _showPanel,
            onBack: () => Navigator.pop(context),
            onInfo: wide ? () => setState(() => _showPanel = !_showPanel) : _showInfoSheet,
            onOpenExternal: _openExternal,
          ),
          Expanded(
            child: wide
                ? Row(children: [
                    Expanded(child: _buildViewer()),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: _showPanel ? 390 : 0,
                      decoration: const BoxDecoration(color: BSColors.page, border: Border(left: BorderSide(color: AppTheme.border))),
                      child: _showPanel
                          ? ListView(padding: const EdgeInsets.all(16), children: _panelChildren())
                          : const SizedBox.shrink(),
                    ),
                  ])
                : _buildViewer(),
          ),
        ]),
      ),
      bottomNavigationBar: !kIsWeb && _isPdf && !_isLoading && !_hasError && _totalPages > 0 ? _buildBottomBar() : null,
    );
  }

  Widget _buildViewer() {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              color: AppTheme.primary,
              strokeWidth: 3,
              backgroundColor: AppTheme.border,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _downloadProgress > 0 ? 'Descargando… ${(_downloadProgress * 100).toStringAsFixed(0)}%' : 'Preparando documento…',
            style: const TextStyle(color: AppTheme.hint, fontSize: 13),
          ),
        ]),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: BSCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: BSColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.error_outline_rounded, color: BSColors.danger, size: 30),
                ),
                const SizedBox(height: 14),
                const Text('No se pudo cargar el documento', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_errorMsg, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                const SizedBox(height: 18),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  BSOutlineButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _loadDocument),
                  BSPrimaryButton(label: 'Abrir externamente', icon: Icons.open_in_new_rounded, onPressed: _openExternal),
                ]),
              ]),
            ),
          ),
        ),
      );
    }

    // Web — visor del navegador / Google
    if (kIsWeb && _isPdf) return PdfViewerWeb(fileUrl: widget.fileUrl);

    // Word
    if (!_isPdf) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: BSCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.article_rounded, color: AppTheme.primary, size: 38),
                ),
                const SizedBox(height: 16),
                Text(_d.title, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${widget.extension.toUpperCase()} · ${_d.sizeLabel}${_d.pages != null ? ' · ${_d.pages} págs' : ''}',
                    style: const TextStyle(color: AppTheme.hint, fontSize: 13)),
                const SizedBox(height: 18),
                const BSInfoBanner(
                  title: 'Vista previa no disponible para Word',
                  text: 'Ábrelo con Word u otra aplicación de tu dispositivo. Sus metadatos y el análisis con IA están en el panel de información.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: BSPrimaryButton(label: 'Abrir / descargar', icon: Icons.download_rounded, onPressed: _openExternal),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    // Móvil / escritorio — pdfx con teclado
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.space) {
            _nextPage();
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.pageUp) {
            _prevPage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: const Color(0xFFE5E7EB),
        child: PdfViewPinch(
          controller: _pdfController!,
          onPageChanged: (page) => setState(() => _currentPage = page),
          scrollDirection: Axis.vertical,
          padding: 10,
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
            errorBuilder: (_, e) => Center(child: Text(e.toString(), style: const TextStyle(color: BSColors.danger))),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          _NavBtn(icon: Icons.chevron_left_rounded, onTap: _currentPage > 1 ? _prevPage : null),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.primary,
                overlayColor: AppTheme.primary.withOpacity(0.1),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _currentPage.clamp(1, _totalPages < 2 ? 2 : _totalPages).toDouble(),
                min: 1,
                max: (_totalPages < 2 ? 2 : _totalPages).toDouble(),
                onChanged: _totalPages < 2
                    ? null
                    : (v) {
                        final p = v.round();
                        _pdfController?.jumpToPage(p);
                        setState(() => _currentPage = p);
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: _currentPage < _totalPages ? _nextPage : null),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: Text('$_currentPage / $_totalPages', style: const TextStyle(color: AppTheme.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// BARRA SUPERIOR
// ─────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final DocView d;
  final String? pagesLabel;
  final bool wide, panelOpen;
  final VoidCallback onBack, onInfo, onOpenExternal;

  const _TopBar({
    required this.d,
    required this.pagesLabel,
    required this.wide,
    required this.panelOpen,
    required this.onBack,
    required this.onInfo,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    final sub = [
      d.ext.toUpperCase(),
      d.sizeLabel.split(' (').first,
      if (pagesLabel != null) pagesLabel! else if (d.pages != null) '${d.pages} págs',
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(4, 8, wide ? 16 : 6, 8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        IconButton(
          tooltip: 'Volver',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
        ),
        BSInitialBox(
          text: d.ext.toUpperCase(),
          color: d.isPdf ? BSColors.danger : AppTheme.primary,
          icon: d.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
          ]),
        ),
        if (wide) ...[
          BSPill.docStatus(d.status),
          const SizedBox(width: 12),
          BSOutlineButton(label: 'Abrir externamente', icon: Icons.open_in_new_rounded, onPressed: onOpenExternal),
          const SizedBox(width: 8),
          BSPrimaryButton(
            label: panelOpen ? 'Ocultar información' : 'Ver información',
            icon: panelOpen ? Icons.view_sidebar_outlined : Icons.info_outline_rounded,
            onPressed: onInfo,
          ),
        ] else ...[
          IconButton(tooltip: 'Abrir externamente', onPressed: onOpenExternal, icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.hint)),
          IconButton(tooltip: 'Información', onPressed: onInfo, icon: const Icon(Icons.info_outline_rounded, color: AppTheme.primary)),
        ],
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Material(
      color: on ? AppTheme.primary.withOpacity(0.08) : BSColors.page,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: on ? AppTheme.primary.withOpacity(0.25) : AppTheme.border)),
          child: Icon(icon, color: on ? AppTheme.primary : AppTheme.hint, size: 22),
        ),
      ),
    );
  }
}
