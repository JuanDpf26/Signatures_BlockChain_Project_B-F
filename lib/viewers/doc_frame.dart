/// Marco que muestra una página web dentro de la app: iframe en web y
/// WebView en Android/iOS. Se usa para el visor de PDF (pdf.js) y de Word.
export 'doc_frame_web.dart' if (dart.library.io) 'doc_frame_io.dart';
