/// Arrastrar y soltar archivos sobre la ventana (solo en la web).
/// En celular no hace nada: allá se sube con el botón.
export 'file_drop_web.dart' if (dart.library.io) 'file_drop_stub.dart';
