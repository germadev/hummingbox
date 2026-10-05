import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' show ClientException;
import 'package:path/path.dart' as p;

import '../models/recording.dart';
import '../models/recording_options.dart';
import 'audio_cache.dart';
import 'folder_access.dart';
import 'google_drive.dart';
import 'recordings_repository.dart';
import 'settings_store.dart';
import 'share_service.dart';

/// Sitio fuera de la app donde se guardan las grabaciones (la carpeta del
/// dispositivo o Google Drive) o una copia de ellas (Google Drive).
abstract interface class SyncTarget {
  /// Clave del archivo de cada grabación en [Recording.copies].
  String get key;

  /// Carpeta concreta. Si cambia, los archivos de la anterior ya no cuentan.
  String get destination;

  /// Guarda el audio de [source] en la subcarpeta [subfolder] con el nombre
  /// [fileName], sobrescribiendo [ref] si existe. Devuelve la referencia del
  /// archivo.
  Future<String> upload(
    String source,
    String fileName, {
    String subfolder = '',
    String? ref,
  });

  /// Renombra el archivo [ref]. Devuelve su nueva referencia o `null` si ya
  /// no existe.
  Future<String?> rename(String ref, String fileName);

  /// Archivos y subcarpetas de la carpeta o de su subcarpeta [subfolder].
  Future<List<FolderEntry>> list({String subfolder = ''});

  /// Copia el archivo [ref] a la ruta local [destination].
  Future<void> download(String ref, String destination);

  /// Borra el archivo [ref] (en Drive, lo mueve a la papelera). Si ya no
  /// existe, no hace nada.
  Future<void> delete(String ref);

  /// Crea la subcarpeta [name], si no existe.
  Future<void> createFolder(String name);
}

class FolderTarget implements SyncTarget {
  FolderTarget(this._folders, this.folder);

  final FolderAccess _folders;
  final FolderSettings folder;

  static const targetKey = Recording.folderKey;

  @override
  String get key => targetKey;

  @override
  String get destination => folder.id;

  @override
  Future<String> upload(
    String source,
    String fileName, {
    String subfolder = '',
    String? ref,
  }) => _folders.writeFile(
    folder: folder.id,
    subfolder: subfolder,
    source: source,
    name: fileName,
    ref: ref,
  );

  @override
  Future<String?> rename(String ref, String fileName) async {
    try {
      return await _folders.renameFile(
        folder: folder.id,
        ref: ref,
        name: fileName,
      );
    } on PlatformException catch (e) {
      // Sin permiso no se sabe si existe.
      if (e.code == 'no_permission') rethrow;
      // Se borró o se movió fuera de la app.
      return null;
    }
  }

  @override
  Future<List<FolderEntry>> list({String subfolder = ''}) =>
      _folders.listFiles(folder: folder.id, subfolder: subfolder);

  @override
  Future<void> download(String ref, String destination) =>
      _folders.readFile(folder: folder.id, ref: ref, destination: destination);

  @override
  Future<void> delete(String ref) =>
      _folders.deleteFile(folder: folder.id, ref: ref);

  @override
  Future<void> createFolder(String name) =>
      _folders.createFolder(folder: folder.id, name: name);
}

class DriveTarget implements SyncTarget {
  DriveTarget(this._drive, this._settings);

  final DriveService _drive;
  final DriveSettings _settings;

  static const targetKey = Recording.driveKey;

  @override
  String get key => targetKey;

  @override
  String get destination => _settings.folderId;

  @override
  Future<String> upload(
    String source,
    String fileName, {
    String subfolder = '',
    String? ref,
  }) => _drive.upload(
    folderId: _settings.folderId,
    path: source,
    name: fileName,
    subfolder: subfolder,
    fileId: ref,
  );

  @override
  Future<String?> rename(String ref, String fileName) async {
    try {
      await _drive.rename(fileId: ref, name: fileName);
      return ref;
    } on DriveException catch (e) {
      if (e.statusCode != 404) rethrow;
      return null;
    }
  }

  @override
  Future<List<FolderEntry>> list({String subfolder = ''}) =>
      _drive.list(folderId: _settings.folderId, subfolder: subfolder);

  @override
  Future<void> download(String ref, String destination) =>
      _drive.download(fileId: ref, destination: destination);

  @override
  Future<void> delete(String ref) => _drive.delete(fileId: ref);

  @override
  Future<void> createFolder(String name) =>
      _drive.createFolder(folderId: _settings.folderId, name: name);
}

/// Qué falló al guardar las grabaciones o al leer el destino.
enum SyncErrorKind {
  /// No se pudieron guardar [SyncError.count] grabaciones.
  upload,

  /// No se pudieron añadir [SyncError.count] grabaciones del destino.
  import,

  /// No se pudo leer la carpeta del dispositivo o Google Drive.
  read,

  /// No se pudieron leer las grabaciones de la app.
  readRecordings,

  /// Hay que volver a conectar la cuenta de Google Drive.
  driveAuth,
}

/// Error de la última pasada en un destino.
class SyncError {
  const SyncError(
    this.kind, {
    this.count = 0,
    this.detail,
    this.offline = false,
    this.noPermission = false,
  });

  /// Describe [error], que afectó a [count] grabaciones.
  factory SyncError.from(SyncErrorKind kind, Object? error, {int count = 0}) {
    if (error is DriveAuthException) {
      return const SyncError(SyncErrorKind.driveAuth);
    }
    return SyncError(
      kind,
      count: count,
      // Los mensajes de Google Drive dan detalles útiles; los del sistema,
      // no (y no están traducidos), salvo la falta de permiso.
      detail: switch (error) {
        DriveException(:final message) => message,
        _ => null,
      },
      offline: error is SocketException || error is ClientException,
      noPermission: error is PlatformException && error.code == 'no_permission',
    );
  }

  final SyncErrorKind kind;
  final int count;

  /// Mensaje de Google Drive, si lo hay.
  final String? detail;

  /// Si falló por no haber conexión.
  final bool offline;

  /// Si se retiró el permiso sobre la carpeta del dispositivo.
  final bool noPermission;

  @override
  bool operator ==(Object other) =>
      other is SyncError &&
      other.kind == kind &&
      other.count == count &&
      other.detail == detail &&
      other.offline == offline &&
      other.noPermission == noPermission;

  @override
  int get hashCode => Object.hash(kind, count, detail, offline, noPermission);

  @override
  String toString() =>
      'SyncError($kind, count: $count, detail: $detail, offline: $offline, '
      'noPermission: $noPermission)';
}

/// Archivo de audio del destino y la subcarpeta en la que está.
typedef _StoredFile = ({String subfolder, FolderEntry entry});

/// Guarda las grabaciones en el destino elegido (la carpeta del dispositivo
/// o, si no hay, Google Drive), muestra en la app lo que hay en él y, si las
/// grabaciones van a la carpeta, guarda además una copia en Google Drive si
/// está conectado. También carga y guarda el resto de las opciones de la app.
///
/// Las grabaciones viven en el destino: las que hay en él (también en sus
/// subcarpetas) aparecen en la app sin copiarlas, y las que se borran o
/// cambian en él fuera de la app desaparecen o se actualizan. Dentro de la
/// app solo queda el audio que falta guardar allí (p. ej. al grabar, al
/// editar o sin conexión); una vez guardado pasa a la caché ([AudioCache]),
/// de donde se puede borrar. Para escucharlas o editarlas, [audioPath] las
/// lee del destino.
///
/// Cada grabación guarda qué revisión y qué nombre tiene el archivo de cada
/// destino, así que sincronizar es idempotente: solo se sube lo que ha
/// cambiado y, si algo falla (p. ej. sin conexión), se reintenta en la
/// siguiente pasada. Las copias de Drive no se borran al eliminar una
/// grabación.
class StorageSync extends ChangeNotifier {
  StorageSync({
    required this.repository,
    required this.store,
    required this.folders,
    required this.drive,
    AudioCache? cache,
    this.fileExists = _fileExists,
  }) : cache = cache ?? AudioCache();

  final RecordingsRepository repository;
  final SettingsStore store;
  final FolderAccess folders;
  final DriveService drive;
  final AudioCache cache;

  /// Indica si existe el archivo local de una ruta (se sustituye en los
  /// tests de widgets, que no usan archivos de verdad).
  final bool Function(String path) fileExists;

  static bool _fileExists(String path) => File(path).existsSync();

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void>? _loading;
  bool _loaded = false;

  /// Indica si ya se han cargado las opciones.
  bool get isLoaded => _loaded;

  /// Último cambio de las opciones pendiente de guardar, si hay alguno.
  Future<void>? _saving;
  Future<void>? _running;
  bool _rerun = false;
  bool _disposed = false;

  /// Grabaciones eliminadas en esta sesión, por si se estaban guardando.
  final _deleted = <String>{};

  bool _syncing = false;

  /// Indica si se están guardando grabaciones o leyendo el destino.
  bool get syncing => _syncing;

  Map<String, SyncError> _errors = const {};

  /// Error de la última pasada por destino ([FolderTarget.targetKey],
  /// [DriveTarget.targetKey]).
  Map<String, SyncError> get errors => _errors;

  List<String> _storageFolders = const [];

  /// Subcarpetas del destino la última vez que se leyó.
  List<String> get storageFolders => _storageFolders;

  final _changes = StreamController<int>.broadcast();

  /// Avisa cuando cambian las grabaciones al leer el destino (las hay nuevas,
  /// borradas o cambiadas fuera de la app) o al elegir otro destino. El valor
  /// es cuántas son nuevas.
  Stream<int> get changes => _changes.stream;

  /// Carga las opciones guardadas. Se puede llamar varias veces.
  Future<void> load() {
    return _loading ??= store.load().then((settings) {
      _settings = settings;
      _loaded = true;
      _notify();
    });
  }

  /// Elige la carpeta del dispositivo donde se guardan las grabaciones (o
  /// deja de usarla, si es `null`).
  Future<void> setFolder(FolderSettings? folder) =>
      _changeTarget((settings) => settings.withFolder(folder));

  /// Conecta (o desconecta, si es `null`) Google Drive.
  Future<void> setDrive(DriveSettings? drive) =>
      _changeTarget((settings) => settings.withDrive(drive));

  /// Cambia el formato y la calidad de las grabaciones nuevas.
  Future<void> setRecordingOptions(RecordingOptions options) =>
      _change((settings) => settings.withRecording(options));

  /// Cambia la duración de la cuenta atrás antes de grabar.
  Future<void> setCountdown(int seconds) =>
      _change((settings) => settings.withCountdown(seconds));

  /// Elige si la pantalla se mantiene encendida mientras se graba.
  Future<void> setKeepScreenOn(bool keepScreenOn) =>
      _change((settings) => settings.withKeepScreenOn(keepScreenOn));

  /// Abre la subcarpeta [name] (vacío para la principal).
  Future<void> openFolder(String name) =>
      _change((settings) => settings.withOpenFolder(name));

  /// Crea la subcarpeta [name] en la app y en el destino.
  Future<void> createFolder(String name) async {
    await _change(
      (settings) => settings.folders.contains(name)
          ? settings
          : settings.withFolders([...settings.folders, name]),
    );
    if (_storage case final storage?) {
      try {
        await storage.createFolder(name);
        if (!_storageFolders.contains(name)) {
          _storageFolders = [..._storageFolders, name];
          _notify();
        }
      } catch (_) {
        // Se creará al guardar la primera grabación.
      }
    }
  }

  /// Elimina [recording] de la app y de donde está guardada (en Drive, va a
  /// la papelera). Las copias de Drive se conservan.
  Future<void> delete(Recording recording) async {
    await load();
    // La lista de la pantalla puede no tener el estado de los archivos al día.
    final current =
        (await repository.loadAll())
            .where((r) => r.id == recording.id)
            .firstOrNull ??
        recording;
    if (_storage case final storage?) {
      final stored = current.copies[storage.key];
      if (stored != null && stored.destination == storage.destination) {
        await storage.delete(stored.ref);
      }
    }
    _deleted.add(current.id);
    await repository.delete(current);
    await cache.forget(current);
  }

  /// Ruta local con el audio de [recording]. Si no está dentro de la app, lo
  /// lee de donde está guardada (o de su copia) y lo deja en la caché.
  Future<String> audioPath(Recording recording) async {
    if (fileExists(recording.path)) return recording.path;
    // La de la pantalla puede ser de antes de guardarla fuera de la app.
    recording =
        (await repository.loadAll())
            .where((r) => r.id == recording.id)
            .firstOrNull ??
        recording;
    if (fileExists(recording.path)) return recording.path;
    Object? error;
    for (final target in [_storage, _copy].nonNulls) {
      final file = recording.copies[target.key];
      if (file == null || file.destination != target.destination) continue;
      try {
        return await cache.fetch(
          recording,
          (destination) => target.download(file.ref, destination),
        );
      } catch (e) {
        error = e;
      }
    }
    if (error != null) throw error;
    return recording.path;
  }

  Future<void> _changeTarget(
    AppSettings Function(AppSettings settings) change,
  ) async {
    final storage = _storage;
    await _change(change);
    if (_storage?.destination != storage?.destination ||
        _storage?.key != storage?.key) {
      _storageFolders = const [];
      if (!_disposed) _changes.add(0);
    }
    _errors = const {};
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

  /// Lee el destino y guarda lo que falte. Si ya hay una pasada en curso, se
  /// repite al terminar para recoger los cambios que hayan llegado mientras
  /// tanto.
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

  /// Donde se guardan las grabaciones, si ya se ha elegido.
  SyncTarget? get _storage => switch (_settings.storage) {
    StorageKind.folder => FolderTarget(folders, _settings.folder!),
    StorageKind.drive => DriveTarget(drive, _settings.drive!),
    null => null,
  };

  /// Donde se guarda una copia: Google Drive, si las grabaciones van a la
  /// carpeta del dispositivo.
  SyncTarget? get _copy =>
      _settings.copiesToDrive ? DriveTarget(drive, _settings.drive!) : null;

  /// Indica si [target] sigue siendo el destino (o la copia) [role].
  bool _isCurrent(SyncTarget target, SyncTarget? Function() role) {
    final current = role();
    return current != null &&
        current.key == target.key &&
        current.destination == target.destination;
  }

  Future<void> _syncOnce() async {
    final storage = _storage;
    final copy = _copy;
    if (storage == null) {
      // Lo que haya dentro de la app espera a que se elija un destino.
      if (_errors.isNotEmpty || _storageFolders.isNotEmpty) {
        _errors = const {};
        _storageFolders = const [];
        _notify();
      }
      return;
    }

    _syncing = true;
    _notify();
    final errors = <String, SyncError>{};
    try {
      // Primero se lee el destino, para no volver a subir lo que ya está.
      try {
        await _reconcile(storage, copy);
      } on _ImportFailure catch (e) {
        errors[storage.key] = SyncError.from(
          SyncErrorKind.import,
          e.error,
          count: e.count,
        );
      } catch (e) {
        errors[storage.key] = SyncError.from(SyncErrorKind.read, e);
      }

      for (final (target, role) in [
        (storage, () => _storage),
        if (copy != null) (copy, () => _copy),
      ]) {
        var failed = 0;
        Object? lastError;
        // De la más antigua a la más reciente, para que se guarden en orden.
        for (final recording in (await repository.loadAll()).reversed) {
          if (_disposed || !_isCurrent(target, role)) break;
          try {
            await _save(
              recording,
              target,
              isStorage: identical(target, storage),
            );
          } on DriveAuthException {
            errors[target.key] = const SyncError(SyncErrorKind.driveAuth);
            failed = 0;
            break;
          } catch (e) {
            failed++;
            lastError = e;
          }
        }
        if (failed > 0) {
          errors[target.key] = SyncError.from(
            SyncErrorKind.upload,
            lastError,
            count: failed,
          );
        }
      }
    } catch (e) {
      for (final target in [storage, ?copy]) {
        errors[target.key] = const SyncError(SyncErrorKind.readRecordings);
      }
    } finally {
      _errors = errors;
      _syncing = false;
      _notify();
    }
  }

  /// Compara lo que hay en el destino con las grabaciones de la app: añade
  /// las nuevas, quita las que se borraron allí y actualiza las que se
  /// cambiaron o renombraron.
  Future<void> _reconcile(SyncTarget storage, SyncTarget? copy) async {
    final root = await storage.list();
    final subfolders = [
      for (final entry in root)
        if (entry.isDirectory && !entry.name.startsWith('.')) entry.name,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final files =
        <_StoredFile>[
          for (final entry in root) (subfolder: '', entry: entry),
          for (final subfolder in subfolders)
            for (final entry in await storage.list(subfolder: subfolder))
              (subfolder: subfolder, entry: entry),
        ]..retainWhere(
          (file) =>
              !file.entry.isDirectory &&
              RecordingFormat.fromPath(file.entry.name) != null,
        );
    if (_disposed || !_isCurrent(storage, () => _storage)) return;
    if (!listEquals(subfolders, _storageFolders)) {
      _storageFolders = subfolders;
      _notify();
    }

    final key = storage.key;
    final byRef = {for (final file in files) file.entry.ref: file};
    final seen = <String>{};
    // Las que estaban guardadas en el destino y ya no están.
    final missing = <Recording>[];
    // Las que no están guardadas en el destino (todavía).
    final others = <Recording>[];
    var changed = 0;

    for (final recording in await repository.loadAll()) {
      final stored = recording.copies[key];
      if (stored == null || stored.destination != storage.destination) {
        others.add(recording);
        continue;
      }
      // Con cambios sin guardar, lo de la app sustituye a lo del destino (y
      // si se borró allí, se vuelve a crear).
      final pending = fileExists(recording.path) && !recording.isSavedIn(key);
      final file = byRef[stored.ref];
      if (file != null) seen.add(stored.ref);
      if (pending) continue;
      if (file == null) {
        if (fileExists(recording.path)) {
          // Falta en el destino, pero la app aún tiene el audio (p. ej. de
          // cuando la carpeta solo guardaba copias): se vuelve a guardar en
          // vez de perderlo.
          others.add(await repository.setCopy(recording, key, null));
        } else {
          missing.add(recording);
        }
        continue;
      }
      final size = file.entry.size;
      if (size != null && stored.size != null && size != stored.size) {
        // Se cambió fuera de la app.
        if (fileExists(recording.path)) {
          await repository.discard(recording.path);
        }
        await repository.updateStoredFile(
          recording,
          key,
          stored.withSize(size),
          audioChanged: true,
        );
        await cache.forget(recording);
        changed++;
      } else if (size != null && stored.size == null) {
        await repository.setCopy(recording, key, stored.withSize(size));
      }
    }

    var added = 0;
    var failed = 0;
    Object? lastError;
    for (final file in files) {
      if (seen.contains(file.entry.ref)) continue;
      if (_disposed || !_isCurrent(storage, () => _storage)) return;
      final entry = file.entry;
      final found = CopyState(
        destination: storage.destination,
        ref: entry.ref,
        revision: 0,
        name: '',
        size: entry.size,
      );

      // Renombrada fuera de la app: falta una con el mismo tamaño.
      final renamed = missing
          .where(
            (r) =>
                entry.size != null &&
                r.folder == file.subfolder &&
                r.format == RecordingFormat.fromPath(entry.name) &&
                r.copies[key]!.size == entry.size,
          )
          .firstOrNull;
      if (renamed != null) {
        missing.remove(renamed);
        await repository.updateStoredFile(
          renamed,
          key,
          found,
          name: p.basenameWithoutExtension(entry.name),
        );
        changed++;
        continue;
      }

      // Su propio archivo, aunque no estuviera enlazado (p. ej. al volver a
      // elegir la misma carpeta): mismo nombre, subcarpeta y tamaño.
      final own = others
          .where(
            (r) =>
                entry.size != null &&
                r.folder == file.subfolder &&
                fileNameFor(r) == entry.name &&
                _sizeOf(r) == entry.size,
          )
          .firstOrNull;
      if (own != null) {
        others.remove(own);
        await repository.updateStoredFile(own, key, found);
        changed++;
        continue;
      }

      try {
        await _import(storage, file);
        added++;
      } catch (e) {
        failed++;
        lastError = e;
      }
    }

    // Se borraron fuera de la app.
    for (final recording in missing) {
      await _forget(recording);
      changed++;
    }
    // Están guardadas en un destino que ya no se usa (se quedan allí) y no
    // hay de dónde guardarlas en este.
    for (final recording in others) {
      if (!_canSave(recording, copy)) {
        await _forget(recording);
        changed++;
      }
    }

    if ((added > 0 || changed > 0) && !_disposed) _changes.add(added);
    if (failed > 0) throw _ImportFailure(failed, lastError);
  }

  /// Indica si se puede guardar [recording] en el destino: si tiene el audio
  /// dentro de la app o en la copia de Drive.
  bool _canSave(Recording recording, SyncTarget? copy) {
    if (fileExists(recording.path)) return true;
    final copied = copy == null ? null : recording.copies[copy.key];
    return copied != null && copied.destination == copy!.destination;
  }

  /// Tamaño del audio de [recording], si se conoce.
  int? _sizeOf(Recording recording) {
    if (_lengthOf(recording.path) case final size?) return size;
    for (final file in recording.copies.values) {
      if (file.revision == recording.revision && file.size != null) {
        return file.size;
      }
    }
    return null;
  }

  static int? _lengthOf(String path) {
    try {
      return File(path).lengthSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Quita [recording] de la app, sin tocar su archivo en el destino.
  Future<void> _forget(Recording recording) async {
    await repository.delete(recording);
    await cache.forget(recording);
  }

  /// Registra el audio [file] del destino como una grabación, sin copiarlo.
  /// La duración, el formato y la onda se leen después (ver
  /// `HomeScreen`).
  Future<void> _import(SyncTarget storage, _StoredFile file) async {
    final entry = file.entry;
    final format = RecordingFormat.fromPath(entry.name)!;
    final name = p.basenameWithoutExtension(entry.name);
    await repository.add(
      path: await repository.createRecordingPath(format: format),
      duration: Duration.zero,
      name: name,
      createdAt: entry.modified,
      folder: file.subfolder,
      copies: {
        storage.key: CopyState(
          destination: storage.destination,
          ref: entry.ref,
          revision: 0,
          name: name,
          size: entry.size,
        ),
      },
    );
  }

  /// Guarda en [target] el audio y el nombre actuales de [recording], si no
  /// los tiene ya. Si [isStorage], después saca su audio de la app.
  Future<void> _save(
    Recording recording,
    SyncTarget target, {
    required bool isStorage,
  }) async {
    if (_deleted.contains(recording.id)) return;
    final stored = recording.copies[target.key];
    final sameDestination = stored?.destination == target.destination;
    final fileName = fileNameFor(recording);

    /// Sube el audio y devuelve la referencia y el tamaño del archivo, o
    /// `null` si no hay de dónde leer el audio (ver [_reconcile]).
    Future<(String, int?)?> upload({String? ref}) async {
      final source = await audioPath(recording);
      if (!fileExists(source)) return null;
      return (
        await target.upload(
          source,
          fileName,
          subfolder: recording.folder,
          ref: ref,
        ),
        _lengthOf(source),
      );
    }

    final (String, int?)? result;
    if (!sameDestination) {
      result = await upload();
    } else if (stored!.revision != recording.revision) {
      result = switch (await upload(ref: stored.ref)) {
        (final ref, final size) when stored.name != recording.name => (
          await target.rename(ref, fileName) ?? ref,
          size,
        ),
        final uploaded => uploaded,
      };
    } else if (stored.name != recording.name) {
      result = switch (await target.rename(stored.ref, fileName)) {
        final renamed? => (renamed, stored.size),
        // Ya no existe: se vuelve a crear.
        null => await upload(),
      };
    } else {
      if (isStorage) await _release(recording, target);
      return;
    }
    if (result == null) return;
    final (ref, size) = result;

    if (_deleted.contains(recording.id)) {
      // Se eliminó mientras se guardaba: que no quede en el destino.
      if (isStorage) await target.delete(ref);
      return;
    }
    final saved = await repository.setCopy(
      recording,
      target.key,
      CopyState(
        destination: target.destination,
        ref: ref,
        revision: recording.revision,
        name: recording.name,
        size: size,
      ),
    );
    if (isStorage) await _release(saved, target);
  }

  /// Saca de la app el audio de [recording], ya guardado en [storage], y lo
  /// deja en la caché.
  Future<void> _release(Recording recording, SyncTarget storage) async {
    if (!fileExists(recording.path)) return;
    final cached = await cache.pathFor(recording);
    if (await repository.releaseAudio(
      recording,
      key: storage.key,
      moveTo: cached,
    )) {
      await cache.trim(keep: cached);
    }
  }

  /// Nombre del archivo de una grabación: el que le dio el usuario, con la
  /// extensión de su formato.
  static String fileNameFor(Recording recording) =>
      '${safeFileName(recording.name, fallback: recording.id)}'
      '${recording.format.extension}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes.close();
    super.dispose();
  }
}

/// No se pudieron añadir [count] grabaciones del destino.
class _ImportFailure implements Exception {
  const _ImportFailure(this.count, this.error);

  final int count;
  final Object? error;
}
