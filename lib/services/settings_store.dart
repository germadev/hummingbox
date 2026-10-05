import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/instrument.dart';
import '../models/recording_options.dart';
import '../models/transcription.dart';

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

/// Cuenta de Google Drive conectada y carpeta de la app en Drive.
class DriveSettings {
  const DriveSettings({
    required this.email,
    required this.folderId,
    this.folderName = defaultFolderName,
  });

  /// Nombre de la carpeta en las versiones en las que siempre se llamaba
  /// igual.
  static const defaultFolderName = 'Grabadora';

  final String email;
  final String folderId;

  /// Nombre que tenía la carpeta al conectar (el de la app en su idioma).
  final String folderName;

  Map<String, dynamic> toJson() => {
    'email': email,
    'folderId': folderId,
    'folderName': folderName,
  };

  static DriveSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final email = json['email'];
    final folderId = json['folderId'];
    final folderName = json['folderName'];
    if (email is! String || folderId is! String) return null;
    return DriveSettings(
      email: email,
      folderId: folderId,
      folderName: folderName is String ? folderName : defaultFolderName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DriveSettings &&
      other.email == email &&
      other.folderId == folderId &&
      other.folderName == folderName;

  @override
  int get hashCode => Object.hash(email, folderId, folderName);
}

/// Dónde se guardan las grabaciones.
enum StorageKind { folder, drive }

/// Tema de la app.
enum AppTheme {
  /// Claro u oscuro según el sistema.
  system,
  light,
  dark,
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
    this.keepScreenOn = true,
    this.transcription = const TranscriptionSettings(),
    this.searchSimilarWords = true,
    this.theme = AppTheme.system,
    this.compactList = false,
    this.instrument = Instrument.piano,
  });

  /// Duraciones de la cuenta atrás que se pueden elegir, en segundos.
  static const countdownChoices = [3, 5, 10];
  static const defaultCountdown = 3;

  /// Carpeta del dispositivo donde se guardan las grabaciones, si se eligió
  /// una.
  final FolderSettings? folder;

  /// Google Drive, si está conectado: donde se guardan las grabaciones si no
  /// hay [folder] o, si la hay, donde se guarda una copia de cada una.
  final DriveSettings? drive;

  /// Dónde se guardan las grabaciones: en la carpeta del dispositivo si se
  /// eligió una y, si no, en Google Drive. `null` si todavía no se ha
  /// elegido.
  StorageKind? get storage => folder != null
      ? StorageKind.folder
      : (drive != null ? StorageKind.drive : null);

  /// Indica si se guarda una copia de cada grabación en Google Drive (además
  /// de en la carpeta del dispositivo).
  bool get copiesToDrive => folder != null && drive != null;

  /// Formato y calidad de las grabaciones nuevas.
  final RecordingOptions recording;

  /// Subcarpetas creadas en la app, aunque todavía estén vacías.
  final List<String> folders;

  /// Subcarpeta abierta en la pantalla principal, en la que se graba; vacío
  /// para la principal.
  final String openFolder;

  /// Segundos de la cuenta atrás antes de empezar a grabar.
  final int countdownSeconds;

  /// Si la pantalla se mantiene encendida mientras se graba (o se espera para
  /// empezar), para que el sistema no pare la app al apagarse.
  final bool keepScreenOn;

  /// Con qué y en qué idioma se transcriben las grabaciones.
  final TranscriptionSettings transcription;

  /// Si la búsqueda encuentra también palabras parecidas (con erratas o
  /// variantes).
  final bool searchSimilarWords;

  /// Tema de la app: el del sistema, claro u oscuro.
  final AppTheme theme;

  /// Si la lista es compacta: cada grabación en poco espacio, con su onda
  /// solo mientras está seleccionada.
  final bool compactList;

  /// Con qué suenan las teclas del piano.
  final Instrument instrument;

  AppSettings withFolder(FolderSettings? folder) => _copy(folder: () => folder);

  AppSettings withDrive(DriveSettings? drive) => _copy(drive: () => drive);

  AppSettings withRecording(RecordingOptions recording) =>
      _copy(recording: recording);

  AppSettings withFolders(List<String> folders) => _copy(folders: folders);

  AppSettings withOpenFolder(String openFolder) =>
      _copy(openFolder: openFolder);

  AppSettings withCountdown(int seconds) => _copy(countdownSeconds: seconds);

  AppSettings withKeepScreenOn(bool keepScreenOn) =>
      _copy(keepScreenOn: keepScreenOn);

  AppSettings withTranscription(TranscriptionSettings transcription) =>
      _copy(transcription: transcription);

  AppSettings withSearchSimilarWords(bool similar) =>
      _copy(searchSimilarWords: similar);

  AppSettings withTheme(AppTheme theme) => _copy(theme: theme);

  AppSettings withCompactList(bool compact) => _copy(compactList: compact);

  AppSettings withInstrument(Instrument instrument) =>
      _copy(instrument: instrument);

  AppSettings _copy({
    FolderSettings? Function()? folder,
    DriveSettings? Function()? drive,
    RecordingOptions? recording,
    List<String>? folders,
    String? openFolder,
    int? countdownSeconds,
    bool? keepScreenOn,
    TranscriptionSettings? transcription,
    bool? searchSimilarWords,
    AppTheme? theme,
    bool? compactList,
    Instrument? instrument,
  }) => AppSettings(
    folder: folder == null ? this.folder : folder(),
    drive: drive == null ? this.drive : drive(),
    recording: recording ?? this.recording,
    folders: folders ?? this.folders,
    openFolder: openFolder ?? this.openFolder,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    transcription: transcription ?? this.transcription,
    searchSimilarWords: searchSimilarWords ?? this.searchSimilarWords,
    theme: theme ?? this.theme,
    compactList: compactList ?? this.compactList,
    instrument: instrument ?? this.instrument,
  );

  Map<String, dynamic> toJson() => {
    if (folder != null) 'folder': folder!.toJson(),
    if (drive != null) 'drive': drive!.toJson(),
    'recording': recording.toJson(),
    if (folders.isNotEmpty) 'folders': folders,
    if (openFolder.isNotEmpty) 'openFolder': openFolder,
    if (countdownSeconds != defaultCountdown) 'countdown': countdownSeconds,
    if (!keepScreenOn) 'keepScreenOn': false,
    if (transcription != const TranscriptionSettings())
      'transcription': transcription.toJson(),
    if (!searchSimilarWords) 'searchSimilarWords': false,
    if (theme != AppTheme.system) 'theme': theme.name,
    if (compactList) 'compactList': true,
    if (instrument != Instrument.piano) 'instrument': instrument.name,
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
      keepScreenOn: json['keepScreenOn'] != false,
      transcription: TranscriptionSettings.fromJson(json['transcription']),
      searchSimilarWords: json['searchSimilarWords'] != false,
      theme: AppTheme.values.asNameMap()[json['theme']] ?? AppTheme.system,
      compactList: json['compactList'] == true,
      instrument: Instrument.byName(json['instrument']) ?? Instrument.piano,
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
      other.countdownSeconds == countdownSeconds &&
      other.keepScreenOn == keepScreenOn &&
      other.transcription == transcription &&
      other.searchSimilarWords == searchSimilarWords &&
      other.theme == theme &&
      other.compactList == compactList &&
      other.instrument == instrument;

  @override
  int get hashCode => Object.hash(
    folder,
    drive,
    recording,
    Object.hashAll(folders),
    openFolder,
    countdownSeconds,
    keepScreenOn,
    transcription,
    searchSimilarWords,
    theme,
    compactList,
    instrument,
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
