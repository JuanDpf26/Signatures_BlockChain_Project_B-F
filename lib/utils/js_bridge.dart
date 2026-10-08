/// Acceso a JavaScript solo en web.
///
/// `dart:js` no existe en Android/iOS: importarlo directamente impide compilar
/// el APK. Este archivo elige la versión web o una versión vacía según la
/// plataforma, igual que se hace con el visor de PDF.
export 'js_bridge_web.dart' if (dart.library.io) 'js_bridge_stub.dart';
