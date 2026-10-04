import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recording_options.dart';

/// Carpeta del dispositivo elegida para guardar las grabaciones.
class FolderSettings {
  const FolderSettings({
    required this.id,
    required this.name,
    this.importFiles = true,
    this.ignored = const {},
  });

  /// Identificador persistente de la carpeta (ver `NativeFolder.id`).
  final String id;
  final String name;

  /// Si las grabaciones que hay en la carpeta (y en sus subcarpetas) se
  /// añaden a la app.
  final bool importFiles;

  /// Referencias de los archivos de la carpeta que no se importan: los de
  /// las grabaciones que se eliminaron en la app.
  final Set<String> ignored;

  /// La misma carpeta, ignorando además el archivo [ref].
  FolderSettings ignoring(String ref) => FolderSettings(
    id: id,
    name: name,
    importFiles: importFiles,
    ignored: {...ignored, ref},
  );

  FolderSettings withImportFiles(bool importFiles) => FolderSettings(
    id: id,
    name: name,
    importFiles: importFiles,
    ignored: ignored,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (!importFiles) 'import': false,
    if (ignored.isNotEmpty) 'ignored': ignored.toList(),
  };

  static FolderSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    final ignored = json['ignored'];
    if (id is! String || name is! String) return null;
    return FolderSettings(
      id: id,
      name: name,
      importFiles: json['import'] != false,
      ignored: {
        if (ignored is List)
          for (final ref in ignored)
            if (ref is String) ref,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FolderSettings &&
      other.id == id &&
      other.name == name &&
      other.importFiles == importFiles &&
      setEquals(other.ignored, ignored);

  @override
  int get hashCode =>
      Object.hash(id, name, importFiles, Object.hashAllUnordered(ignored));
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
  const AppSettings({
    this.folder,
    this.drive,
    this.recording = const RecordingOptions(),
    this.folders = const [],
    this.openFolder = '',
    this.countdownSeconds = defaultCountdown,
  });

  /// Duraciones de la cuenta atrás que se pueden elegir, en segundos.
  static const countdownChoices = [3, 5, 10];
  static const defaultCountdown = 3;

  /// Carpeta del dispositivo donde se guarda una copia de cada grabación, o
  /// `null` si solo se guardan dentro de la app.
  final FolderSettings? folder;

  /// Google Drive, si está conectado.
  final DriveSettings? drive;

  /// Formato y calidad de las grabaciones nuevas.
  final RecordingOptions recording;

  /// Subcarpetas creadas en la app, aunque todavía estén vacías.
  final List<String> folders;

  /// Subcarpeta abierta en la pantalla principal, en la que se graba; vacío
  /// para la principal.
  final String openFolder;

  /// Segundos de la cuenta atrás antes de empezar a grabar.
  final int countdownSeconds;

  AppSettings withFolder(FolderSettings? folder) => _copy(folder: () => folder);

  AppSettings withDrive(DriveSettings? drive) => _copy(drive: () => drive);

  AppSettings withRecording(RecordingOptions recording) =>
      _copy(recording: recording);

  AppSettings withFolders(List<String> folders) => _copy(folders: folders);

  AppSettings withOpenFolder(String openFolder) =>
      _copy(openFolder: openFolder);

  AppSettings withCountdown(int seconds) => _copy(countdownSeconds: seconds);

  AppSettings _copy({
    FolderSettings? Function()? folder,
    DriveSettings? Function()? drive,
    RecordingOptions? recording,
    List<String>? folders,
    String? openFolder,
    int? countdownSeconds,
  }) => AppSettings(
    folder: folder == null ? this.folder : folder(),
    drive: drive == null ? this.drive : drive(),
    recording: recording ?? this.recording,
    folders: folders ?? this.folders,
    openFolder: openFolder ?? this.openFolder,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
  );

  Map<String, dynamic> toJson() => {
    if (folder != null) 'folder': folder!.toJson(),
    if (drive != null) 'drive': drive!.toJson(),
    'recording': recording.toJson(),
    if (folders.isNotEmpty) 'folders': folders,
    if (openFolder.isNotEmpty) 'openFolder': openFolder,
    if (countdownSeconds != defaultCountdown) 'countdown': countdownSeconds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final folders = json['folders'];
    final openFolder = json['openFolder'];
    final countdown = json['countdown'];
    return AppSettings(
      folder: FolderSettings.fromJson(json['folder']),
      drive: DriveSettings.fromJson(json['drive']),
      recording: RecordingOptions.fromJson(json['recording']),
      folders: [
        if (folders is List)
          for (final name in folders)
            if (name is String) name,
      ],
      openFolder: openFolder is String ? openFolder : '',
      countdownSeconds: countdownChoices.contains(countdown)
          ? countdown as int
          : defaultCountdown,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.folder == folder &&
      other.drive == drive &&
      other.recording == recording &&
      listEquals(other.folders, folders) &&
      other.openFolder == openFolder &&
      other.countdownSeconds == countdownSeconds;

  @override
  int get hashCode => Object.hash(
    folder,
    drive,
    recording,
    Object.hashAll(folders),
    openFolder,
    countdownSeconds,
  );
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
