import 'package:voicerecorder_native/voicerecorder_native.dart';

import 'settings_store.dart';

/// Acceso a una carpeta del dispositivo elegida por el usuario. Abstraído
/// para poder sustituirlo en los tests.
abstract interface class FolderAccess {
  /// Abre el selector de carpetas. Devuelve `null` si se cancela.
  Future<FolderSettings?> pickFolder();

  /// Copia [source] a la carpeta: sobrescribe [ref] si existe o crea un
  /// archivo llamado [name]. Devuelve la referencia del archivo.
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String? ref,
  });

  /// Renombra [ref] a [name] y devuelve su nueva referencia.
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  });
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
    String? ref,
  }) => _native.writeFile(folder: folder, source: source, name: name, ref: ref);

  @override
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  }) => _native.renameFile(folder: folder, ref: ref, name: name);
}
