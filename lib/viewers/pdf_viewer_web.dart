import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PdfViewerWeb extends StatefulWidget {
  final String fileUrl;
  const PdfViewerWeb({super.key, required this.fileUrl});

  @override
  State<PdfViewerWeb> createState() => _PdfViewerWebState();
}

class _PdfViewerWebState extends State<PdfViewerWeb> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${widget.fileUrl.hashCode}';
    final googleDocsUrl =
        'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.fileUrl)}&embedded=true';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..src = googleDocsUrl
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF1E1E2E),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF6b7280), size: 14),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Visor Google Docs — puede tardar unos segundos',
              style: TextStyle(color: Color(0xFF6b7280), fontSize: 11),
            ),
          ),
        ]),
      ),
      Expanded(child: HtmlElementView(viewType: _viewType)),
    ]);
  }
}