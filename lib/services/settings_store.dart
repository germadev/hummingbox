import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Carpeta del dispositivo elegida para guardar las grabaciones.
class FolderSettings {
  const FolderSettings({required this.id, required this.name});

  /// Identificador persistente de la carpeta (ver `NativeFolder.id`).
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static FolderSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return FolderSettings(id: id, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is FolderSettings && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Cuenta de Google Drive conectada y carpeta donde se guardan las copias.
class DriveSettings {
  const DriveSettings({required this.email, required this.folderId});

  final String email;
  final String folderId;

  Map<String, dynamic> toJson() => {'email': email, 'folderId': folderId};

  static DriveSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final email = json['email'];
    final folderId = json['folderId'];
    if (email is! String || folderId is! String) return null;
    return DriveSettings(email: email, folderId: folderId);
  }

  @override
  bool operator ==(Object other) =>
      other is DriveSettings &&
      other.email == email &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(email, folderId);
}

/// Opciones de la app.
class AppSettings {
  const AppSettings({this.folder, this.drive});

  /// Carpeta del dispositivo donde se guarda una copia de cada grabación, o
  /// `null` si solo se guardan dentro de la app.
  final FolderSettings? folder;

  /// Google Drive, si está conectado.
  final DriveSettings? drive;

  AppSettings withFolder(FolderSettings? folder) =>
      AppSettings(folder: folder, drive: drive);

  AppSettings withDrive(DriveSettings? drive) =>
      AppSettings(folder: folder, drive: drive);

  Map<String, dynamic> toJson() => {
    if (folder != null) 'folder': folder!.toJson(),
    if (drive != null) 'drive': drive!.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    folder: FolderSettings.fromJson(json['folder']),
    drive: DriveSettings.fromJson(json['drive']),
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.folder == folder && other.drive == drive;

  @override
  int get hashCode => Object.hash(folder, drive);
}

/// Guarda las opciones en un archivo JSON.
abstract interface class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class FileSettingsStore implements SettingsStore {
  FileSettingsStore({Future<File> Function()? file})
    : _fileProvider = file ?? _defaultFile;

  final Future<File> Function() _fileProvider;

  static Future<File> _defaultFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'settings.json'));
  }

  @override
  Future<AppSettings> load() async {
    final file = await _fileProvider();
    if (!await file.exists()) return const AppSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic>
          ? AppSettings.fromJson(decoded)
          : const AppSettings();
    } on FormatException {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
