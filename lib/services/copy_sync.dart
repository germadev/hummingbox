import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' show ClientException;
import 'package:path/path.dart' as p;

import '../audio/audio_info.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import 'folder_access.dart';
import 'google_drive.dart';
import 'recordings_repository.dart';
import 'settings_store.dart';
import 'share_service.dart';

/// Destino externo al que se copian las grabaciones.
abstract interface class CopyTarget {
  /// Clave con la que se guarda el estado de la copia en cada grabación.
  String get key;

  /// Carpeta concreta de destino. Si cambia, se vuelve a copiar todo.
  String get destination;

  /// Copia el audio de [recording] con el nombre de archivo [fileName],
  /// sobrescribiendo [ref] si existe. Devuelve la referencia de la copia.
  Future<String> upload(Recording recording, String fileName, {String? ref});

  /// Renombra la copia [ref]. Si ya no existe, la vuelve a copiar. Devuelve
  /// la referencia de la copia.
  Future<String> rename(Recording recording, String ref, String fileName);
}

class FolderCopyTarget implements CopyTarget {
  FolderCopyTarget(this._folders, this.folder);

  final FolderAccess _folders;
  final FolderSettings folder;

  static const targetKey = 'folder';

  @override
  String get key => targetKey;

  @override
  String get destination => folder.id;

  @override
  Future<String> upload(Recording recording, String fileName, {String? ref}) {
    return _folders.writeFile(
      folder: folder.id,
      subfolder: recording.folder,
      source: recording.path,
      name: fileName,
      ref: ref,
    );
  }

  @override
  Future<String> rename(
    Recording recording,
    String ref,
    String fileName,
  ) async {
    try {
      return await _folders.renameFile(
        folder: folder.id,
        ref: ref,
        name: fileName,
      );
    } on PlatformException {
      // La copia se borró o se movió fuera de la app: se hace otra.
      return upload(recording, fileName);
    }
  }
}

class DriveCopyTarget implements CopyTarget {
  DriveCopyTarget(this._drive, this._settings);

  final DriveService _drive;
  final DriveSettings _settings;

  static const targetKey = 'drive';

  @override
  String get key => targetKey;

  @override
  String get destination => _settings.folderId;

  @override
  Future<String> upload(Recording recording, String fileName, {String? ref}) {
    return _drive.upload(
      folderId: _settings.folderId,
      path: recording.path,
      name: fileName,
      subfolder: recording.folder,
      fileId: ref,
    );
  }

  @override
  Future<String> rename(
    Recording recording,
    String ref,
    String fileName,
  ) async {
    try {
      await _drive.rename(fileId: ref, name: fileName);
      return ref;
    } on DriveException catch (e) {
      if (e.statusCode != 404) rethrow;
      return upload(recording, fileName);
    }
  }
}

/// Qué falló al copiar o al leer la carpeta.
enum CopyErrorKind {
  /// No se pudieron copiar [CopyError.count] grabaciones.
  copy,

  /// No se pudieron añadir [CopyError.count] grabaciones de la carpeta.
  import,

  /// No se pudo leer la carpeta del dispositivo.
  readFolder,

  /// No se pudieron leer las grabaciones de la app.
  readRecordings,

  /// Hay que volver a conectar la cuenta de Google Drive.
  driveAuth,
}

/// Error de la última pasada en un destino.
class CopyError {
  const CopyError(
    this.kind, {
    this.count = 0,
    this.detail,
    this.offline = false,
  });

  /// Describe [error], que afectó a [count] grabaciones.
  factory CopyError.from(CopyErrorKind kind, Object? error, {int count = 0}) {
    return CopyError(
      kind,
      count: count,
      detail: switch (error) {
        PlatformException(:final message?) => message,
        DriveException(:final message) => message,
        _ => null,
      },
      offline: error is SocketException || error is ClientException,
    );
  }

  final CopyErrorKind kind;
  final int count;

  /// Mensaje del sistema o de Google Drive, si lo hay.
  final String? detail;

  /// Si falló por no haber conexión.
  final bool offline;

  @override
  bool operator ==(Object other) =>
      other is CopyError &&
      other.kind == kind &&
      other.count == count &&
      other.detail == detail &&
      other.offline == offline;

  @override
  int get hashCode => Object.hash(kind, count, detail, offline);

  @override
  String toString() =>
      'CopyError($kind, count: $count, detail: $detail, offline: $offline)';
}

/// Audios de la carpeta del dispositivo que la app todavía no tiene.
class FolderScan {
  const FolderScan({required this.count, required this.bytes});

  final int count;

  /// Tamaño total de los que lo indican.
  final int bytes;
}

/// Archivo de la carpeta del dispositivo y la subcarpeta en la que está.
typedef _FolderFile = ({String subfolder, FolderEntry entry});

/// Lo que hay que hacer con los audios de la carpeta del dispositivo.
class _FolderPlan {
  const _FolderPlan({
    required this.subfolders,
    required this.adopt,
    required this.import,
  });

  /// Subcarpetas de la carpeta.
  final List<String> subfolders;

  /// Copias de grabaciones de la app cuyo enlace se perdió (p. ej. al
  /// volver a elegir la misma carpeta): se reconocen por la subcarpeta, el
  /// nombre y el tamaño.
  final List<(Recording, _FolderFile)> adopt;

  /// Audios que la app no tiene.
  final List<_FolderFile> import;
}

/// Mantiene una copia de cada grabación en los destinos activados en las
/// opciones (una carpeta del dispositivo y Google Drive) y añade a la app las
/// grabaciones que ya había en la carpeta y en sus subcarpetas. También
/// carga y guarda el resto de las opciones de la app.
///
/// Cada grabación guarda qué revisión y qué nombre se copiaron a cada destino,
/// así que sincronizar es idempotente: solo se sube lo que ha cambiado y, si
/// algo falla (p. ej. sin conexión), se reintenta en la siguiente pasada.
/// Las copias no se borran al eliminar una grabación en la app (ni se
/// vuelven a añadir).
class CopySync extends ChangeNotifier {
  CopySync({
    required this.repository,
    required this.store,
    required this.folders,
    required this.drive,
    this.probe = probeAudio,
  });

  final RecordingsRepository repository;
  final SettingsStore store;
  final FolderAccess folders;
  final DriveService drive;

  /// Lee el formato y la duración de los audios que se importan.
  final Future<AudioProbe?> Function(String path) probe;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void>? _loading;

  /// Último cambio de las opciones pendiente de guardar, si hay alguno.
  Future<void>? _saving;
  Future<void>? _running;
  bool _rerun = false;
  bool _disposed = false;

  bool _syncing = false;

  /// Indica si se están copiando grabaciones ahora mismo.
  bool get syncing => _syncing;

  Map<String, CopyError> _errors = const {};

  /// Error de la última pasada por destino ([FolderCopyTarget.targetKey],
  /// [DriveCopyTarget.targetKey]).
  Map<String, CopyError> get errors => _errors;

  List<String> _deviceFolders = const [];

  /// Subcarpetas de la carpeta del dispositivo la última vez que se leyó.
  List<String> get deviceFolders => _deviceFolders;

  final _imports = StreamController<List<Recording>>.broadcast();

  /// Grabaciones que se acaban de añadir desde la carpeta del dispositivo.
  Stream<List<Recording>> get imports => _imports.stream;

  /// Carga las opciones guardadas. Se puede llamar varias veces.
  Future<void> load() {
    return _loading ??= store.load().then((settings) {
      _settings = settings;
      _notify();
    });
  }

  Future<void> setFolder(FolderSettings? folder) {
    _deviceFolders = const [];
    return _changeTarget((settings) {
      // Si se vuelve a elegir la misma carpeta, se conserva lo ignorado.
      final previous = settings.folder;
      if (folder != null && previous != null && previous.id == folder.id) {
        return settings.withFolder(
          FolderSettings(
            id: folder.id,
            name: folder.name,
            importFiles: folder.importFiles,
            ignored: previous.ignored,
          ),
        );
      }
      return settings.withFolder(folder);
    }, FolderCopyTarget.targetKey);
  }

  /// Activa o desactiva que se añadan a la app las grabaciones de la carpeta.
  Future<void> setImportFiles(bool importFiles) => _changeTarget(
    (settings) => switch (settings.folder) {
      final folder? => settings.withFolder(folder.withImportFiles(importFiles)),
      null => settings,
    },
    FolderCopyTarget.targetKey,
  );

  Future<void> setDrive(DriveSettings? drive) => _changeTarget(
    (settings) => settings.withDrive(drive),
    DriveCopyTarget.targetKey,
  );

  /// Cambia el formato y la calidad de las grabaciones nuevas.
  Future<void> setRecordingOptions(RecordingOptions options) =>
      _change((settings) => settings.withRecording(options));

  /// Cambia la duración de la cuenta atrás antes de grabar.
  Future<void> setCountdown(int seconds) =>
      _change((settings) => settings.withCountdown(seconds));

  /// Abre la subcarpeta [name] (vacío para la principal).
  Future<void> openFolder(String name) =>
      _change((settings) => settings.withOpenFolder(name));

  /// Crea la subcarpeta [name] en la app y, si hay una, en la carpeta del
  /// dispositivo.
  Future<void> createFolder(String name) async {
    await _change(
      (settings) => settings.folders.contains(name)
          ? settings
          : settings.withFolders([...settings.folders, name]),
    );
    if (_settings.folder case final folder?) {
      try {
        await folders.createFolder(folder: folder.id, name: name);
        if (!_deviceFolders.contains(name)) {
          _deviceFolders = [..._deviceFolders, name];
          _notify();
        }
      } catch (_) {
        // Se creará al copiar la primera grabación.
      }
    }
  }

  /// Elimina [recording] de la app. Si tiene copia en la carpeta del
  /// dispositivo, el archivo se conserva, pero ya no se vuelve a añadir.
  Future<void> delete(Recording recording) async {
    // La lista de la pantalla puede no tener el estado de las copias al día.
    final current =
        (await repository.loadAll())
            .where((r) => r.id == recording.id)
            .firstOrNull ??
        recording;
    await repository.delete(current);
    if (current.copies[FolderCopyTarget.targetKey] case final copy?) {
      await _ignore(copy.destination, copy.ref);
    }
  }

  /// No vuelve a añadir el archivo [ref] de la carpeta [destination].
  Future<void> _ignore(String destination, String ref) => _change((settings) {
    final folder = settings.folder;
    if (folder == null || folder.id != destination) return settings;
    return settings.withFolder(folder.ignoring(ref));
  });

  /// Cuenta los audios de [folder] que se añadirían a la app al elegirla.
  Future<FolderScan> scanFolder(FolderSettings folder) async {
    final plan = await _plan(folder);
    return FolderScan(
      count: plan.import.length,
      bytes: plan.import.fold(0, (sum, file) => sum + (file.entry.size ?? 0)),
    );
  }

  Future<void> _changeTarget(
    AppSettings Function(AppSettings settings) change,
    String changedTarget,
  ) async {
    await _change(change);
    _errors = {..._errors}..remove(changedTarget);
    _notify();
    unawaited(sync());
  }

  /// Aplica [change] a las opciones actuales y las guarda. Los cambios se
  /// encadenan, así que dos seguidos no se pisan.
  Future<void> _change(AppSettings Function(AppSettings settings) change) {
    Future<void> apply() async {
      await load();
      final settings = change(_settings);
      if (settings == _settings) return;
      await store.save(settings);
      _settings = settings;
      _notify();
    }

    final previous = _saving;
    final result = previous == null ? apply() : previous.then((_) => apply());
    final done = result.then((_) {}, onError: (_) {});
    _saving = done;
    done.then((_) {
      if (identical(_saving, done)) _saving = null;
    });
    return result;
  }

  /// Añade las grabaciones nuevas de la carpeta y copia lo que falte. Si ya
  /// hay una pasada en curso, se repite al terminar para recoger los cambios
  /// que hayan llegado mientras tanto.
  Future<void> sync() {
    if (_running case final running?) {
      _rerun = true;
      return running;
    }
    final running = _loop().whenComplete(() => _running = null);
    _running = running;
    return running;
  }

  Future<void> _loop() async {
    await load();
    do {
      _rerun = false;
      await _syncOnce();
    } while (_rerun && !_disposed);
  }

  List<CopyTarget> _targets() => [
    if (_settings.folder case final folder?) FolderCopyTarget(folders, folder),
    if (_settings.drive case final settings?) DriveCopyTarget(drive, settings),
  ];

  /// Indica si [target] sigue activado con el mismo destino.
  bool _isCurrent(CopyTarget target) => _targets().any(
    (t) => t.key == target.key && t.destination == target.destination,
  );

  Future<void> _syncOnce() async {
    final targets = _targets();
    if (targets.isEmpty) {
      if (_errors.isNotEmpty || _deviceFolders.isNotEmpty) {
        _errors = const {};
        _deviceFolders = const [];
        _notify();
      }
      return;
    }

    _syncing = true;
    _notify();
    final errors = <String, CopyError>{};
    try {
      // Primero se añade lo que hay en la carpeta, para no volver a subir
      // copias que ya están allí.
      for (final target in targets.whereType<FolderCopyTarget>()) {
        try {
          await _importFrom(target);
        } on _ImportFailure catch (e) {
          errors[target.key] = CopyError.from(
            CopyErrorKind.import,
            e.error,
            count: e.count,
          );
        } catch (e) {
          errors[target.key] = CopyError.from(CopyErrorKind.readFolder, e);
        }
      }

      // De la más antigua a la más reciente, para que se copien en orden.
      final recordings = (await repository.loadAll()).reversed;
      for (final target in targets) {
        var failed = 0;
        Object? lastError;
        for (final recording in recordings) {
          if (_disposed || !_isCurrent(target)) break;
          try {
            await _syncRecording(recording, target);
          } on DriveAuthException {
            errors[target.key] = const CopyError(CopyErrorKind.driveAuth);
            break;
          } catch (e) {
            failed++;
            lastError = e;
          }
        }
        if (failed > 0) {
          errors[target.key] = CopyError.from(
            CopyErrorKind.copy,
            lastError,
            count: failed,
          );
        }
      }
    } catch (e) {
      for (final target in targets) {
        errors[target.key] = const CopyError(CopyErrorKind.readRecordings);
      }
    } finally {
      _errors = errors;
      _syncing = false;
      _notify();
    }
  }

  /// Lee la carpeta del dispositivo y sus subcarpetas, y añade a la app las
  /// grabaciones que todavía no tiene.
  Future<void> _importFrom(FolderCopyTarget target) async {
    final folder = target.folder;
    final plan = await _plan(folder);
    if (!_isCurrent(target)) return;
    if (!listEquals(plan.subfolders, _deviceFolders)) {
      _deviceFolders = plan.subfolders;
      _notify();
    }

    for (final (recording, file) in plan.adopt) {
      await repository.setCopy(
        recording,
        target.key,
        CopyState(
          destination: target.destination,
          ref: file.entry.ref,
          revision: recording.revision,
          name: recording.name,
        ),
      );
    }

    final imported = <Recording>[];
    var failed = 0;
    Object? lastError;
    for (final file in plan.import) {
      if (_disposed || !_isCurrent(target)) break;
      try {
        if (await _import(target, file) case final recording?) {
          imported.add(recording);
        }
      } catch (e) {
        failed++;
        lastError = e;
      }
    }
    if (imported.isNotEmpty && !_disposed) _imports.add(imported);
    if (failed > 0) throw _ImportFailure(failed, lastError);
  }

  /// Compara lo que hay en [folder] con las grabaciones de la app.
  Future<_FolderPlan> _plan(FolderSettings folder) async {
    final root = await folders.listFiles(folder: folder.id);
    final subfolders = [
      for (final entry in root)
        if (entry.isDirectory && !entry.name.startsWith('.')) entry.name,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!folder.importFiles) {
      return _FolderPlan(
        subfolders: subfolders,
        adopt: const [],
        import: const [],
      );
    }

    final files = <_FolderFile>[
      for (final entry in root)
        if (!entry.isDirectory) (subfolder: '', entry: entry),
      for (final subfolder in subfolders)
        for (final entry in await folders.listFiles(
          folder: folder.id,
          subfolder: subfolder,
        ))
          if (!entry.isDirectory) (subfolder: subfolder, entry: entry),
    ];

    final recordings = await repository.loadAll();
    const key = FolderCopyTarget.targetKey;
    final known = {
      for (final recording in recordings)
        if (recording.copies[key] case final copy?
            when copy.destination == folder.id)
          copy.ref,
    };
    final unlinked = [
      for (final recording in recordings)
        if (recording.copies[key]?.destination != folder.id) recording,
    ];

    final adopt = <(Recording, _FolderFile)>[];
    final import = <_FolderFile>[];
    for (final file in files) {
      final ref = file.entry.ref;
      if (RecordingFormat.fromPath(file.entry.name) == null ||
          known.contains(ref) ||
          folder.ignored.contains(ref)) {
        continue;
      }
      final original = await _findOriginal(unlinked, file);
      if (original != null) {
        unlinked.remove(original);
        adopt.add((original, file));
      } else {
        import.add(file);
      }
    }
    return _FolderPlan(subfolders: subfolders, adopt: adopt, import: import);
  }

  /// La grabación de [candidates] de la que [file] es la copia: en la misma
  /// subcarpeta, con el mismo nombre de archivo y el mismo tamaño.
  static Future<Recording?> _findOriginal(
    List<Recording> candidates,
    _FolderFile file,
  ) async {
    final size = file.entry.size;
    if (size == null) return null;
    for (final recording in candidates) {
      if (recording.folder != file.subfolder ||
          copyFileName(recording) != file.entry.name) {
        continue;
      }
      try {
        if (File(recording.path).lengthSync() == size) return recording;
      } on FileSystemException {
        // El audio ya no está.
      }
    }
    return null;
  }

  /// Copia [file] a la app y lo registra como una grabación enlazada a él.
  Future<Recording?> _import(FolderCopyTarget target, _FolderFile file) async {
    final entry = file.entry;
    final format = RecordingFormat.fromPath(entry.name)!;
    final path = await repository.createRecordingPath(format: format);
    try {
      await folders.readFile(
        folder: target.folder.id,
        ref: entry.ref,
        destination: path,
      );
      final details = await probe(path);
      final name = p.basenameWithoutExtension(entry.name);
      return await repository.add(
        path: path,
        duration: details?.duration ?? Duration.zero,
        name: name,
        createdAt: entry.modified,
        audio: details?.info,
        folder: file.subfolder,
        copies: {
          target.key: CopyState(
            destination: target.destination,
            ref: entry.ref,
            revision: 0,
            name: name,
          ),
        },
      );
    } catch (_) {
      await repository.discard(path);
      rethrow;
    }
  }

  Future<void> _syncRecording(Recording recording, CopyTarget target) async {
    // Se pudo borrar mientras se copiaban otras. (Las consultas de si existe
    // un archivo son instantáneas: se hacen síncronas.)
    if (!File(recording.path).existsSync()) return;

    final state = recording.copies[target.key];
    final fileName = copyFileName(recording);
    String ref;
    if (state == null || state.destination != target.destination) {
      ref = await target.upload(recording, fileName);
    } else if (state.revision != recording.revision) {
      ref = await target.upload(recording, fileName, ref: state.ref);
      if (state.name != recording.name) {
        ref = await target.rename(recording, ref, fileName);
      }
    } else if (state.name != recording.name) {
      ref = await target.rename(recording, state.ref, fileName);
    } else {
      return;
    }

    if (!File(recording.path).existsSync()) {
      // Se eliminó mientras se copiaba: que la copia no vuelva a la app.
      if (target is FolderCopyTarget) await _ignore(target.destination, ref);
      return;
    }
    await repository.setCopy(
      recording,
      target.key,
      CopyState(
        destination: target.destination,
        ref: ref,
        revision: recording.revision,
        name: recording.name,
      ),
    );
  }

  /// Nombre del archivo de la copia: el que le dio el usuario, con la
  /// extensión de su formato.
  static String copyFileName(Recording recording) =>
      '${safeFileName(recording.name, fallback: recording.id)}'
      '${recording.format.extension}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _imports.close();
    super.dispose();
  }
}

/// No se pudieron añadir [count] grabaciones de la carpeta.
class _ImportFailure implements Exception {
  const _ImportFailure(this.count, this.error);

  final int count;
  final Object? error;
}
