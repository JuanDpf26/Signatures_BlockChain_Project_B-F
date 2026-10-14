import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class DocFrame extends StatelessWidget {
  final String url;
  const DocFrame({super.key, required this.url});

  static final Set<String> _registered = {};

  @override
  Widget build(BuildContext context) {
    final type = 'doc-frame-${url.hashCode}';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int id) {
        return web.HTMLIFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
      });
    }
    return HtmlElementView(key: ValueKey(type), viewType: type);
  }
}
