import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

typedef DroppedFile = ({Uint8List bytes, String name});

const bool fileDropSupported = true;

/// Escucha archivos arrastrados sobre la ventana. Devuelve la función para dejar de escuchar.
void Function() listenFileDrop({
  required void Function(bool hovering) onHover,
  required void Function(DroppedFile file) onDrop,
}) {
  var depth = 0;

  bool hasFiles(web.DragEvent e) {
    final t = e.dataTransfer;
    if (t == null) return false;
    return t.types.toDart.any((x) => x.toDart == 'Files');
  }

  final over = ((web.Event ev) {
    final e = ev as web.DragEvent;
    if (hasFiles(e)) e.preventDefault();
  }).toJS;
  final enter = ((web.Event ev) {
    final e = ev as web.DragEvent;
    if (!hasFiles(e)) return;
    e.preventDefault();
    depth++;
    onHover(true);
  }).toJS;
  final leave = ((web.Event ev) {
    depth--;
    if (depth <= 0) {
      depth = 0;
      onHover(false);
    }
  }).toJS;
  final drop = ((web.Event ev) {
    final e = ev as web.DragEvent;
    if (!hasFiles(e)) return;
    e.preventDefault();
    depth = 0;
    onHover(false);
    final files = e.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    final f = files.item(0);
    if (f == null) return;
    final name = f.name;
    f.arrayBuffer().toDart.then((buf) => onDrop((bytes: buf.toDart.asUint8List(), name: name)));
  }).toJS;

  web.window.addEventListener('dragover', over);
  web.window.addEventListener('dragenter', enter);
  web.window.addEventListener('dragleave', leave);
  web.window.addEventListener('drop', drop);
  return () {
    web.window.removeEventListener('dragover', over);
    web.window.removeEventListener('dragenter', enter);
    web.window.removeEventListener('dragleave', leave);
    web.window.removeEventListener('drop', drop);
  };
}
