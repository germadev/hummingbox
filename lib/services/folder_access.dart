import 'package:voicerecorder_native/voicerecorder_native.dart';

import 'settings_store.dart';

/// Archivo o subcarpeta de la carpeta elegida por el usuario.
class FolderEntry {
  const FolderEntry({
    required this.ref,
    required this.name,
    this.isDirectory = false,
    this.size,
    this.modified,
    this.checksum,
  });

  /// Referencia persistente del archivo (ver [FolderAccess.writeFile]).
  final String ref;
  final String name;
  final bool isDirectory;

  /// Tamaño en bytes, si se conoce.
  final int? size;

  /// Fecha de la última modificación, si se conoce.
  final DateTime? modified;

  /// Suma MD5 del contenido (en hexadecimal), si el destino la da al listar
  /// (Google Drive sí; la carpeta del dispositivo, no).
  final String? checksum;
}

/// Acceso a una carpeta del dispositivo elegida por el usuario y a sus
/// subcarpetas. Abstraído para poder sustituirlo en los tests.
abstract interface class FolderAccess {
  /// Abre el selector de carpetas. Devuelve `null` si se cancela.
  Future<FolderSettings?> pickFolder();

  /// Copia [source] a la carpeta o a su subcarpeta [subfolder]: sobrescribe
  /// [ref] si existe o crea un archivo llamado [name]. Devuelve la
  /// referencia del archivo.
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String subfolder = '',
    String? ref,
  });

  /// Renombra [ref] a [name] y devuelve su nueva referencia.
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  });

  /// Archivos y subcarpetas de la carpeta o de su subcarpeta [subfolder].
  Future<List<FolderEntry>> listFiles({
    required String folder,
    String subfolder = '',
  });

  /// Copia el archivo [ref] de la carpeta a la ruta local [destination].
  Future<void> readFile({
    required String folder,
    required String ref,
    required String destination,
  });

  /// Crea la subcarpeta [name], si no existe.
  Future<void> createFolder({required String folder, required String name});

  /// Borra el archivo [ref]. Si ya no existe, no hace nada.
  Future<void> deleteFile({required String folder, required String ref});
}

/// Implementación con el selector y los permisos del sistema.
class PlatformFolderAccess implements FolderAccess {
  const PlatformFolderAccess();

  final _native = const NativeFolders();

  @override
  Future<FolderSettings?> pickFolder() async {
    final folder = await _native.pickFolder();
    if (folder == null) return null;
    return FolderSettings(id: folder.id, name: folder.name);
  }

  @override
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String subfolder = '',
    String? ref,
  }) => _native.writeFile(
    folder: folder,
    source: source,
    name: name,
    subfolder: subfolder,
    ref: ref,
  );

  @override
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  }) => _native.renameFile(folder: folder, ref: ref, name: name);

  @override
  Future<List<FolderEntry>> listFiles({
    required String folder,
    String subfolder = '',
  }) async => [
    for (final entry in await _native.listFiles(
      folder: folder,
      subfolder: subfolder,
    ))
      FolderEntry(
        ref: entry.ref,
        name: entry.name,
        isDirectory: entry.isDirectory,
        size: entry.size,
        modified: entry.modified,
      ),
  ];

  @override
  Future<void> readFile({
    required String folder,
    required String ref,
    required String destination,
  }) => _native.readFile(folder: folder, ref: ref, destination: destination);

  @override
  Future<void> createFolder({required String folder, required String name}) =>
      _native.createFolder(folder: folder, name: name);

  @override
  Future<void> deleteFile({required String folder, required String ref}) =>
      _native.deleteFile(folder: folder, ref: ref);
}
