import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/document_detail.dart';
import '../widgets/sign_ia_assistant.dart';
import '../viewers/doc_frame.dart';

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
  bool _showPanel = true;
  /// 0 = visor propio (pdf.js) / Office para Word, 1 = visor de Google
  int _engine = 0;

  late final DocView _d = DocView.fromMeta({
    ...widget.metadata,
    'title': widget.metadata['title'] ?? widget.title,
    'file_url': widget.fileUrl,
  });

  bool get _isPdf => widget.extension.toLowerCase() == 'pdf';

  String get _frameUrl {
    if (_engine == 1) return AppConfig.visorGoogle(widget.fileUrl);
    return _isPdf ? AppConfig.visorPdf(widget.fileUrl) : AppConfig.visorOffice(widget.fileUrl);
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
          decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
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
            pagesLabel: null,
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
                      decoration: BoxDecoration(color: BSColors.page, border: Border(left: BorderSide(color: AppTheme.border))),
                      child: _showPanel
                          ? ListView(padding: const EdgeInsets.all(16), children: _panelChildren())
                          : const SizedBox.shrink(),
                    ),
                  ])
                : _buildViewer(),
          ),
        ]),
      ),
    );
  }

  Widget _buildViewer() {
    final labels = _isPdf ? const ['Visor', 'Google'] : const ['Office', 'Google'];
    final hint = _engine == 1
        ? 'Visor de Google: puede tardar unos segundos'
        : (_isPdf ? 'Pellizca o usa + y − para hacer zoom' : 'Vista de Word con el visor de Microsoft Office');
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.card, border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          _Segment(options: labels, selected: _engine, onChanged: (i) => setState(() => _engine = i)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 11.5)),
          ),
        ]),
      ),
      Expanded(
        child: Container(
          color: const Color(0xFFE5E7EB),
          child: DocFrame(key: ValueKey(_frameUrl), url: _frameUrl),
        ),
      ),
    ]);
  }
}

class _Segment extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const _Segment({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < options.length; i++)
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i == selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: i == selected ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
              ),
              child: Text(options[i],
                  style: TextStyle(
                    color: i == selected ? AppTheme.primary : AppTheme.hint,
                    fontSize: 12,
                    fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          ),
      ]),
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
      decoration: BoxDecoration(color: AppTheme.card, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        IconButton(
          tooltip: 'Volver',
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text),
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
                style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.hint, fontSize: 12)),
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
          IconButton(tooltip: 'Abrir externamente', onPressed: onOpenExternal, icon: Icon(Icons.open_in_new_rounded, color: AppTheme.hint)),
          IconButton(tooltip: 'Información', onPressed: onInfo, icon: Icon(Icons.info_outline_rounded, color: AppTheme.primary)),
        ],
      ]),
    );
  }
}
