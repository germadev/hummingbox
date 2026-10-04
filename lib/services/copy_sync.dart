import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' show ClientException;

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
  FolderCopyTarget(this._folders, this._folder);

  final FolderAccess _folders;
  final FolderSettings _folder;

  static const targetKey = 'folder';

  @override
  String get key => targetKey;

  @override
  String get destination => _folder.id;

  @override
  Future<String> upload(Recording recording, String fileName, {String? ref}) {
    return _folders.writeFile(
      folder: _folder.id,
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
        folder: _folder.id,
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

/// Mantiene una copia de cada grabación en los destinos activados en las
/// opciones (una carpeta del dispositivo y Google Drive). También carga y
/// guarda el resto de las opciones de la app.
///
/// Cada grabación guarda qué revisión y qué nombre se copiaron a cada destino,
/// así que sincronizar es idempotente: solo se sube lo que ha cambiado y, si
/// algo falla (p. ej. sin conexión), se reintenta en la siguiente pasada.
/// Las copias no se borran al eliminar una grabación en la app.
class CopySync extends ChangeNotifier {
  CopySync({
    required this.repository,
    required this.store,
    required this.folders,
    required this.drive,
  });

  final RecordingsRepository repository;
  final SettingsStore store;
  final FolderAccess folders;
  final DriveService drive;

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

  Map<String, String> _errors = const {};

  /// Error de la última pasada por destino ([FolderCopyTarget.targetKey],
  /// [DriveCopyTarget.targetKey]).
  Map<String, String> get errors => _errors;

  /// Carga las opciones guardadas. Se puede llamar varias veces.
  Future<void> load() {
    return _loading ??= store.load().then((settings) {
      _settings = settings;
      _notify();
    });
  }

  Future<void> setFolder(FolderSettings? folder) => _changeTarget(
    (settings) => settings.withFolder(folder),
    FolderCopyTarget.targetKey,
  );

  Future<void> setDrive(DriveSettings? drive) => _changeTarget(
    (settings) => settings.withDrive(drive),
    DriveCopyTarget.targetKey,
  );

  /// Cambia el formato y la calidad de las grabaciones nuevas.
  Future<void> setRecordingOptions(RecordingOptions options) =>
      _change((settings) => settings.withRecording(options));

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

  /// Copia lo que falte. Si ya hay una pasada en curso, se repite al
  /// terminar para recoger los cambios que hayan llegado mientras tanto.
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
      if (_errors.isNotEmpty) {
        _errors = const {};
        _notify();
      }
      return;
    }

    _syncing = true;
    _notify();
    final errors = <String, String>{};
    try {
      // De la más antigua a la más reciente, para que se copien en orden.
      final recordings = (await repository.loadAll()).reversed;
      for (final target in targets) {
        var failed = 0;
        Object? lastError;
        for (final recording in recordings) {
          if (_disposed || !_isCurrent(target)) break;
          try {
            await _syncRecording(recording, target);
          } on DriveAuthException catch (e) {
            errors[target.key] = e.message;
            break;
          } catch (e) {
            failed++;
            lastError = e;
          }
        }
        if (failed > 0) {
          errors[target.key] = _describeFailure(failed, lastError);
        }
      }
    } catch (e) {
      for (final target in targets) {
        errors[target.key] = 'No se pudieron leer las grabaciones';
      }
    } finally {
      _errors = errors;
      _syncing = false;
      _notify();
    }
  }

  Future<void> _syncRecording(Recording recording, CopyTarget target) async {
    // Se pudo borrar mientras se copiaban otras.
    if (!await File(recording.path).exists()) return;

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

  static String _describeFailure(int failed, Object? error) {
    final count = failed == 1
        ? 'No se pudo copiar 1 grabación'
        : 'No se pudieron copiar $failed grabaciones';
    final detail = switch (error) {
      PlatformException(:final message?) => message,
      DriveException(:final message) => message,
      SocketException() || ClientException() => 'Sin conexión',
      _ => null,
    };
    return detail == null ? count : '$count: $detail';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
