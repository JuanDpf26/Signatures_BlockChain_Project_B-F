import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../theme/app_theme.dart';

/// Visor de PDF para web.
/// - "Navegador": el visor nativo de Chrome/Edge (rápido, con zoom, búsqueda e impresión).
/// - "Google": visor de Google Docs, útil si el navegador no muestra el PDF.
class PdfViewerWeb extends StatefulWidget {
  final String fileUrl;
  const PdfViewerWeb({super.key, required this.fileUrl});

  @override
  State<PdfViewerWeb> createState() => _PdfViewerWebState();
}

class _PdfViewerWebState extends State<PdfViewerWeb> {
  static final Set<String> _registered = {};
  bool _useGoogle = false;

  String get _nativeType => 'pdf-native-${widget.fileUrl.hashCode}';
  String get _googleType => 'pdf-google-${widget.fileUrl.hashCode}';

  @override
  void initState() {
    super.initState();
    _register(_nativeType, '${widget.fileUrl}#toolbar=1&navpanes=0&view=FitH');
    _register(_googleType, 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.fileUrl)}&embedded=true');
  }

  void _register(String type, String src) {
    if (_registered.contains(type)) return;
    _registered.add(type);
    ui_web.platformViewRegistry.registerViewFactory(type, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          _Segment(
            options: const ['Navegador', 'Google'],
            selected: _useGoogle ? 1 : 0,
            onChanged: (i) => setState(() => _useGoogle = i == 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _useGoogle
                  ? 'Visor de Google Docs — puede tardar unos segundos'
                  : 'Usa la barra del visor para hacer zoom, buscar o imprimir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.hint, fontSize: 11.5),
            ),
          ),
        ]),
      ),
      Expanded(
        child: Container(
          color: const Color(0xFFE5E7EB),
          child: HtmlElementView(
            key: ValueKey(_useGoogle),
            viewType: _useGoogle ? _googleType : _nativeType,
          ),
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
      decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
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
