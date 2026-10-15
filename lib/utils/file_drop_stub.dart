import 'dart:typed_data';

typedef DroppedFile = ({Uint8List bytes, String name});

const bool fileDropSupported = false;

void Function() listenFileDrop({
  required void Function(bool hovering) onHover,
  required void Function(DroppedFile file) onDrop,
}) =>
    () {};
