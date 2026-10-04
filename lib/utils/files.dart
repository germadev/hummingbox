import 'dart:io';

/// Mueve un archivo, aunque el destino esté en otro sistema de archivos.
/// Si el destino existe, se sustituye.
Future<void> moveFile(String source, String target) async {
  try {
    await File(source).rename(target);
  } on FileSystemException {
    await File(source).copy(target);
    await File(source).delete();
  }
}

/// Borra [directory] y su contenido, ignorando los errores.
Future<void> deleteQuietly(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException {
    // Es una carpeta temporal: si no se puede borrar, lo hará el sistema.
  }
}
