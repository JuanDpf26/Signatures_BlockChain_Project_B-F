import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

class DocFrame extends StatefulWidget {
  final String url;
  const DocFrame({super.key, required this.url});

  @override
  State<DocFrame> createState() => _DocFrameState();
}

class _DocFrameState extends State<DocFrame> {
  bool _loading = true;
  String? _error;

  late final WebViewController _c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFFE5E7EB))
    ..setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) {
        if (mounted) setState(() => _loading = false);
      },
      onWebResourceError: (e) {
        if (mounted && (e.isForMainFrame ?? true)) {
          setState(() {
            _loading = false;
            _error = e.description;
          });
        }
      },
    ))
    ..loadRequest(Uri.parse(widget.url));

  @override
  void didUpdateWidget(covariant DocFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      setState(() {
        _loading = true;
        _error = null;
      });
      _c.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: WebViewWidget(controller: _c)),
      if (_loading)
        Positioned.fill(
          child: ColoredBox(
            color: Color(0xFFE5E7EB),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          ),
        ),
      if (_error != null)
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFFE5E7EB),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar el visor: $_error\nRevisa tu conexión o abre el archivo en otra aplicación.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
              ),
            ),
          ),
        ),
    ]);
  }
}
