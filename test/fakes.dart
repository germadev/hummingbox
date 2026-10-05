import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_edit.dart';
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/audio_cache.dart';
import 'package:voicerecorder/services/audio_codec.dart';
import 'package:voicerecorder/services/audio_player_service.dart';
import 'package:voicerecorder/services/audio_recorder_service.dart';
import 'package:voicerecorder/services/folder_access.dart';
import 'package:voicerecorder/services/google_drive.dart';
import 'package:voicerecorder/services/recording_editor.dart';
import 'package:voicerecorder/services/recordings_repository.dart';
import 'package:voicerecorder/services/screen_awake.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/services/storage_sync.dart';

class FakeAudioRecorderService implements AudioRecorderService {
  FakeAudioRecorderService({
    this.permissionGranted = true,
    this.writeFiles = false,
  });

  bool permissionGranted;

  /// Si es `true`, `start` crea un archivo real en la ruta indicada.
  final bool writeFiles;

  final calls = <String>[];
  final statusController = StreamController<RecorderStatus>.broadcast();
  final amplitudeController = StreamController<double>.broadcast();
  String? path;
  RecordingOptions? options;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return permissionGranted;
  }

  @override
  Future<void> start(String path, RecordingOptions options) async {
    calls.add('start');
    this.path = path;
    this.options = options;
    if (writeFiles) File(path).writeAsBytesSync([0, 1, 2, 3]);
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return path;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Stream<RecorderStatus> statusChanges() => statusController.stream;

  @override
  Stream<double> amplitudeChanges(Duration interval) =>
      amplitudeController.stream;

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeAudioPlayerService implements AudioPlayerService {
  final calls = <String>[];
  final statusController = StreamController<PlaybackStatus>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  bool disposed = false;

  @override
  Stream<PlaybackStatus> get statusChanges => statusController.stream;

  @override
  Stream<Duration> get positionChanges => positionController.stream;

  @override
  Stream<Duration> get durationChanges => durationController.stream;

  @override
  Future<void> play(String path, {Duration? position}) async {
    calls.add('play $path @${position?.inMilliseconds ?? 0}');
    statusController.add(PlaybackStatus.playing);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    statusController.add(PlaybackStatus.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    statusController.add(PlaybackStatus.playing);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    statusController.add(PlaybackStatus.stopped);
  }

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMilliseconds}');

  @override
  Future<void> dispose() async => disposed = true;
}

class InMemoryRecordingsRepository implements RecordingsRepository {
  InMemoryRecordingsRepository([List<Recording> initial = const []])
    : recordings = [...initial];

  final List<Recording> recordings;
  final discarded = <String>[];

  /// Grabaciones cuyo audio se ha sacado de la app (ids).
  final released = <String>[];

  @override
  String defaultNamePrefix = 'Grabación';
  var _counter = 0;

  Recording byId(String id) => recordings.firstWhere((r) => r.id == id);

  @override
  Future<String> createRecordingPath({
    RecordingFormat format = RecordingFormat.aac,
  }) async => '/fake/rec_${_counter++}${format.extension}';

  @override
  Future<List<Recording>> loadAll() async =>
      [...recordings]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Recording?> add({
    required String path,
    required Duration duration,
    List<double>? waveform,
    String? name,
    DateTime? createdAt,
    AudioInfo? audio,
    Map<String, CopyState> copies = const {},
    String folder = '',
  }) async {
    final recording = Recording(
      id: p.basenameWithoutExtension(path),
      path: path,
      name:
          name ??
          FileRecordingsRepository.nextDefaultName(
            recordings.map((r) => r.name),
            prefix: defaultNamePrefix,
          ),
      createdAt: createdAt ?? DateTime.now(),
      duration: duration,
      waveform: waveform,
      audio: audio,
      copies: copies,
      folder: folder,
    );
    recordings.add(recording);
    return recording;
  }

  @override
  Future<Recording> rename(Recording recording, String name) async =>
      _replace(byId(recording.id).copyWith(name: name));

  @override
  Future<Recording> replaceAudio(
    Recording recording, {
    required String sourcePath,
    required Duration duration,
    List<double>? waveform,
    AudioInfo? audio,
  }) async {
    final current = byId(recording.id);
    return _replace(
      Recording(
        id: current.id,
        path: current.path,
        name: current.name,
        createdAt: current.createdAt,
        duration: duration,
        waveform: waveform,
        revision: current.revision + 1,
        copies: current.copies,
        audio: audio,
        folder: current.folder,
      ),
    );
  }

  @override
  Future<Recording> setDetails(
    Recording recording, {
    List<double>? waveform,
    Duration? duration,
    AudioInfo? audio,
  }) async => _replace(
    byId(recording.id)
        .copyWith(waveform: waveform, duration: duration, audio: audio),
  );

  @override
  Future<Recording> setCopy(
    Recording recording,
    String target,
    CopyState? state,
  ) async {
    final current = byId(recording.id);
    final copies = {...current.copies};
    if (state == null) {
      copies.remove(target);
    } else {
      copies[target] = state;
    }
    return _replace(current.copyWith(copies: copies));
  }

  @override
  Future<Recording> updateStoredFile(
    Recording recording,
    String key,
    CopyState file, {
    String? name,
    bool audioChanged = false,
  }) async {
    final current = byId(recording.id);
    final revision = current.revision + (audioChanged ? 1 : 0);
    final newName = name ?? current.name;
    return _replace(
      Recording(
        id: current.id,
        path: current.path,
        name: newName,
        createdAt: current.createdAt,
        duration: audioChanged ? Duration.zero : current.duration,
        waveform: audioChanged ? null : current.waveform,
        revision: revision,
        copies: {
          ...current.copies,
          key: CopyState(
            destination: file.destination,
            ref: file.ref,
            revision: revision,
            name: newName,
            size: file.size,
            checksum: file.checksum,
            modified: file.modified,
          ),
        },
        audio: audioChanged ? null : current.audio,
        folder: current.folder,
      ),
    );
  }

  @override
  Future<bool> releaseAudio(
    Recording recording, {
    required String key,
    required String moveTo,
  }) async {
    final current = recordings.where((r) => r.id == recording.id).firstOrNull;
    if (current == null || !current.isSavedIn(key)) return false;
    released.add(recording.id);
    return true;
  }

  @override
  Future<void> delete(Recording recording) async =>
      recordings.removeWhere((r) => r.id == recording.id);

  @override
  Future<void> discard(String path) async => discarded.add(path);

  Recording _replace(Recording recording) {
    final index = recordings.indexWhere((r) => r.id == recording.id);
    recordings[index] = recording;
    return recording;
  }
}

/// Códec que no convierte nada: copia los bytes tal cual. Sirve para probar
/// el editor con WAV de verdad, ya que el "m4a" resultante es un WAV.
class CopyingAudioCodec implements AudioCodec {
  final calls = <String>[];

  /// Si se indica, `decodeToWav` copia este archivo en vez de la entrada.
  String? decodedSource;

  @override
  Future<void> decodeToWav(String input, String output) async {
    calls.add('decode ${p.basename(input)}');
    await File(decodedSource ?? input).copy(output);
  }

  /// Tasa de bits de la última codificación.
  int? bitRate;

  @override
  Future<void> trimStart(String input, String output, Duration start) async {
    calls.add('trim ${p.basename(input)} @${start.inMilliseconds}');
    await File(input).copy(output);
  }

  @override
  Future<void> encodeToM4a(
    String input,
    String output, {
    int bitRate = 128000,
  }) async {
    calls.add('encode ${p.basename(input)}');
    this.bitRate = bitRate;
    await File(input).copy(output);
  }
}

/// Editor que no toca archivos, para los tests de widgets.
class FakeRecordingEditor extends RecordingEditor {
  FakeRecordingEditor({required super.repository})
    : super(codec: CopyingAudioCodec());

  /// Onda que devuelve [extractWaveform]; si es `null`, falla.
  List<double>? waveform = const [0.2, 0.6, 1.0];
  final extracted = <String>[];

  /// Lo que devuelve [probe] para cada ruta; si no está, `null`.
  final probes = <String, AudioProbe>{};

  @override
  Future<AudioProbe?> probe(String path) async => probes[path];

  Duration duration = const Duration(seconds: 10);
  double peak = 0.25;

  /// Picos de la onda del editor; por defecto, todos iguales a [peak].
  List<double>? peaks;
  AudioEdit? savedEdit;
  bool? savedAsCopy;
  int closedSessions = 0;

  @override
  Future<List<double>> extractWaveform(Recording recording) async {
    extracted.add(recording.id);
    return waveform ?? (throw Exception('sin onda'));
  }

  /// Si se indica, [open] falla con este error.
  Object? openError;

  @override
  Future<EditSession> open(Recording recording) async {
    if (openError case final error?) throw error;
    return _session(recording);
  }

  EditSession _session(Recording recording) => EditSession(
    recording: recording,
    directory: Directory('/fake/editor'),
    sourcePath: '/fake/editor/source.wav',
    analysis: WavAnalysis(
      duration: duration,
      peaks: peaks ?? List.filled(RecordingEditor.editorResolution, peak),
    ),
  );

  @override
  Future<Recording> save(
    EditSession session,
    AudioEdit edit, {
    required bool asCopy,
    String? copyName,
  }) async {
    savedEdit = edit;
    savedAsCopy = asCopy;
    if (asCopy) {
      return (await repository.add(
        path: await repository.createRecordingPath(),
        duration: edit.length,
        name:
            copyName ??
            '${session.recording.name}${RecordingEditor.copySuffix}',
      ))!;
    }
    return repository.replaceAudio(
      session.recording,
      sourcePath: '/fake/editor/edited.m4a',
      duration: edit.length,
    );
  }

  @override
  Future<void> close(EditSession session) async => closedSessions++;

  /// Recortes del principio pedidos: ruta → inicio.
  final trims = <String, Duration>{};

  @override
  Future<void> trimStart(String path, Duration start) async =>
      trims[path] = start;

  /// Ediciones con las que se ha generado la escucha previa.
  final previews = <AudioEdit>[];

  @override
  Future<String> renderPreview(EditSession session, AudioEdit edit) async {
    previews.add(edit);
    return '/fake/editor/preview_${previews.length - 1}.wav';
  }
}

class FakeScreenAwake implements ScreenAwake {
  /// Valores pedidos, en orden.
  final calls = <bool>[];

  bool get isKeptOn => calls.isNotEmpty && calls.last;

  @override
  Future<void> keepOn(bool on) async => calls.add(on);
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;
}

class FakeFolderAccess implements FolderAccess {
  /// Carpeta que devuelve el selector; `null` simula que se cancela.
  FolderSettings? picked = const FolderSettings(
    id: 'tree://music',
    name: 'Music',
  );

  /// Archivos: referencia → nombre.
  final files = <String, String>{};

  /// Carpeta (id) de cada archivo.
  final owners = <String, String>{};

  /// Subcarpeta de cada archivo; si no está, la principal.
  final fileFolders = <String, String>{};

  /// Tamaño de cada archivo, si se conoce.
  final sizes = <String, int>{};

  /// Contenido de los archivos que se pueden leer.
  final contents = <String, List<int>>{};
  final modified = <String, DateTime>{};

  /// Subcarpetas de cada carpeta (id).
  final subfolders = <String, Set<String>>{};
  final calls = <String>[];

  /// Si se indica, las escrituras fallan con este error.
  PlatformException? writeError;

  /// Si se indica, leer la carpeta falla con este error.
  PlatformException? listError;

  /// Si se indica, borrar falla con este error.
  PlatformException? deleteError;
  var _counter = 0;

  /// Añade un archivo a la carpeta [folder] (o a su [subfolder]).
  String addFile(
    String folder,
    String name, {
    String subfolder = '',
    List<int> bytes = const [1, 2, 3],
    DateTime? modified,
  }) {
    final ref = 'doc${_counter++}';
    files[ref] = name;
    owners[ref] = folder;
    if (subfolder.isNotEmpty) {
      fileFolders[ref] = subfolder;
      subfolders.putIfAbsent(folder, () => {}).add(subfolder);
    }
    sizes[ref] = bytes.length;
    contents[ref] = bytes;
    if (modified != null) this.modified[ref] = modified;
    return ref;
  }

  @override
  Future<FolderSettings?> pickFolder() async => picked;

  @override
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String subfolder = '',
    String? ref,
  }) async {
    final path = subfolder.isEmpty ? name : '$subfolder/$name';
    calls.add('write $path${ref == null ? '' : ' ($ref)'}');
    if (writeError case final error?) throw error;
    final target = ref != null && files.containsKey(ref)
        ? ref
        : 'doc${_counter++}';
    files.putIfAbsent(target, () => name);
    owners.putIfAbsent(target, () => folder);
    if (subfolder.isNotEmpty) {
      fileFolders.putIfAbsent(target, () => subfolder);
      subfolders.putIfAbsent(folder, () => {}).add(subfolder);
    }
    final file = File(source);
    if (file.existsSync()) {
      sizes[target] = file.lengthSync();
      contents[target] = file.readAsBytesSync();
    }
    // Como en el sistema, escribir cambia la fecha de modificación.
    modified[target] = DateTime.fromMillisecondsSinceEpoch(1000 * ++_writes);
    return target;
  }

  var _writes = 0;

  /// Cambia el contenido de [ref] fuera de la app, como haría otra app: con
  /// otra fecha de modificación.
  void changeFile(String ref, List<int> bytes) {
    contents[ref] = bytes;
    sizes[ref] = bytes.length;
    modified[ref] = DateTime.fromMillisecondsSinceEpoch(1000 * ++_writes);
  }

  @override
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  }) async {
    calls.add('rename $ref → $name');
    if (!files.containsKey(ref)) {
      throw PlatformException(code: 'failed', message: 'No existe');
    }
    files[ref] = name;
    return ref;
  }

  @override
  Future<List<FolderEntry>> listFiles({
    required String folder,
    String subfolder = '',
  }) async {
    if (listError case final error?) throw error;
    return [
      if (subfolder.isEmpty)
        for (final name in subfolders[folder] ?? const <String>{})
          FolderEntry(ref: 'dir:$name', name: name, isDirectory: true),
      for (final MapEntry(key: ref, value: name) in files.entries)
        if (owners[ref] == folder && (fileFolders[ref] ?? '') == subfolder)
          FolderEntry(
            ref: ref,
            name: name,
            size: sizes[ref],
            modified: modified[ref],
          ),
    ];
  }

  @override
  Future<void> readFile({
    required String folder,
    required String ref,
    required String destination,
  }) async {
    calls.add('read $ref');
    final bytes = contents[ref];
    if (bytes == null) {
      throw PlatformException(code: 'failed', message: 'No se puede leer');
    }
    // En los tests de widgets las rutas son falsas: no se escribe nada.
    if (Directory(p.dirname(destination)).existsSync()) {
      File(destination).writeAsBytesSync(bytes);
    }
  }

  @override
  Future<void> createFolder({
    required String folder,
    required String name,
  }) async {
    calls.add('mkdir $name');
    subfolders.putIfAbsent(folder, () => {}).add(name);
  }

  @override
  Future<void> deleteFile({required String folder, required String ref}) async {
    calls.add('delete $ref');
    if (deleteError case final error?) throw error;
    files.remove(ref);
  }
}

class FakeDriveService implements DriveService {
  FakeDriveService({this.isAvailable = true});

  @override
  bool isAvailable;

  /// Lo que devuelve [connect]; `null` simula que el usuario cancela.
  DriveSettings? account = const DriveSettings(
    email: 'ana@example.com',
    folderId: 'folder1',
  );

  /// Archivos: id → nombre.
  final files = <String, String>{};

  /// Subcarpeta de cada archivo; si no está, la principal.
  final fileFolders = <String, String>{};
  final sizes = <String, int>{};
  final contents = <String, List<int>>{};

  /// Subcarpetas creadas.
  final subfolders = <String>{};
  final calls = <String>[];
  Object? uploadError;

  /// Si se indica, leer la carpeta falla con este error.
  Object? listError;
  bool disconnected = false;
  var _counter = 0;

  /// Añade un archivo creado por la app (en otro dispositivo, p. ej.).
  String addFile(
    String name, {
    String subfolder = '',
    List<int> bytes = const [1, 2, 3],
  }) {
    final id = 'file${_counter++}';
    files[id] = name;
    if (subfolder.isNotEmpty) {
      fileFolders[id] = subfolder;
      subfolders.add(subfolder);
    }
    sizes[id] = bytes.length;
    contents[id] = bytes;
    return id;
  }

  @override
  Future<DriveSettings?> connect({required String folderName}) async => account;

  @override
  Future<void> disconnect() async => disconnected = true;

  @override
  Future<String> upload({
    required String folderId,
    required String path,
    required String name,
    String subfolder = '',
    String? fileId,
  }) async {
    final file = subfolder.isEmpty ? name : '$subfolder/$name';
    calls.add('upload $file${fileId == null ? '' : ' ($fileId)'}');
    if (uploadError case final error?) throw error;
    final id = fileId != null && files.containsKey(fileId)
        ? fileId
        : 'file${_counter++}';
    files[id] = name;
    if (subfolder.isNotEmpty) {
      fileFolders[id] = subfolder;
      subfolders.add(subfolder);
    }
    final source = File(path);
    if (source.existsSync()) {
      sizes[id] = source.lengthSync();
      contents[id] = source.readAsBytesSync();
    }
    return id;
  }

  @override
  Future<void> rename({required String fileId, required String name}) async {
    calls.add('rename $fileId → $name');
    if (!files.containsKey(fileId)) {
      throw const DriveException(404, 'File not found');
    }
    files[fileId] = name;
  }

  @override
  Future<List<FolderEntry>> list({
    required String folderId,
    String subfolder = '',
  }) async {
    if (listError case final error?) throw error;
    return [
      if (subfolder.isEmpty)
        for (final name in subfolders)
          FolderEntry(ref: 'dir:$name', name: name, isDirectory: true),
      for (final MapEntry(key: id, value: name) in files.entries)
        if ((fileFolders[id] ?? '') == subfolder)
          FolderEntry(
            ref: id,
            name: name,
            size: sizes[id],
            checksum: switch (contents[id]) {
              final bytes? => md5.convert(bytes).toString(),
              null => null,
            },
          ),
    ];
  }

  @override
  Future<void> download({
    required String fileId,
    required String destination,
  }) async {
    calls.add('download $fileId');
    final bytes = contents[fileId];
    if (bytes == null) throw const DriveException(404, 'File not found');
    if (Directory(p.dirname(destination)).existsSync()) {
      File(destination).writeAsBytesSync(bytes);
    }
  }

  @override
  Future<void> delete({required String fileId}) async {
    calls.add('delete $fileId');
    files.remove(fileId);
  }

  @override
  Future<void> createFolder({
    required String folderId,
    required String name,
  }) async {
    calls.add('mkdir $name');
    subfolders.add(name);
  }
}

/// Carpeta del dispositivo de los tests de widgets.
const testFolder = FolderSettings(
  id: 'tree://grabaciones',
  name: 'Grabaciones',
);

/// Sincronización para los tests de widgets: sin archivos de verdad (todas
/// las rutas «existen») y, si no se indica otra cosa, con las grabaciones
/// guardadas en [testFolder].
StorageSync fakeStorageSync(
  RecordingsRepository repository, {
  SettingsStore? store,
  FolderAccess? folders,
  DriveService? drive,
  bool Function(String path)? fileExists,
}) {
  return StorageSync(
    repository: repository,
    store:
        store ?? InMemorySettingsStore(const AppSettings(folder: testFolder)),
    folders: folders ?? FakeFolderAccess(),
    drive: drive ?? FakeDriveService(),
    cache: AudioCache(directory: () async => Directory('/fake/cache')),
    fileExists: fileExists ?? (_) => true,
  );
}
