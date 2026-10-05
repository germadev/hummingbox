import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_info.dart';
import '../audio/levels.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import '../utils/files.dart';

/// Almacén de las grabaciones del usuario.
abstract interface class RecordingsRepository {
  /// Nombre de las grabaciones nuevas, seguido de un número («Grabación 3»).
  /// Lo fija la interfaz según el idioma.
  abstract String defaultNamePrefix;

  /// Devuelve una ruta libre donde guardar una nueva grabación en [format].
  Future<String> createRecordingPath({
    RecordingFormat format = RecordingFormat.aac,
  });

  /// Devuelve todas las grabaciones, de la más reciente a la más antigua.
  Future<List<Recording>> loadAll();

  /// Registra el archivo de audio de [path] como una nueva grabación de la
  /// subcarpeta [folder], con [name] o, si no se indica, el siguiente nombre
  /// libre ("Grabación N"), y con fecha [createdAt] o, si no se indica, la
  /// actual.
  ///
  /// Devuelve `null` si el archivo no existe.
  Future<Recording?> add({
    required String path,
    required Duration duration,
    List<double>? waveform,
    String? name,
    DateTime? createdAt,
    AudioInfo? audio,
    Map<String, CopyState> copies = const {},
    String folder = '',
  });

  Future<Recording> rename(Recording recording, String name);

  /// Sustituye el audio de [recording] por el archivo de [sourcePath], que se
  /// mueve a su sitio, y aumenta su revisión.
  Future<Recording> replaceAudio(
    Recording recording, {
    required String sourcePath,
    required Duration duration,
    List<double>? waveform,
    AudioInfo? audio,
  });

  /// Guarda los datos de [recording] calculados después de registrarla: la
  /// onda, la duración o el formato. Los que son `null` no cambian.
  Future<Recording> setDetails(
    Recording recording, {
    List<double>? waveform,
    Duration? duration,
    AudioInfo? audio,
  });

  /// Guarda (o borra, si [state] es `null`) el estado de la copia de
  /// [recording] en el destino [target].
  Future<Recording> setCopy(
    Recording recording,
    String target,
    CopyState? state,
  );

  Future<void> delete(Recording recording);

  /// Elimina un archivo de audio que no llegó a registrarse.
  Future<void> discard(String path);
}

/// Guarda los audios en una carpeta del dispositivo y sus metadatos
/// (nombre, fecha y duración) en un índice JSON dentro de la misma carpeta.
class FileRecordingsRepository implements RecordingsRepository {
  FileRecordingsRepository({Future<Directory> Function()? directory})
    : _directoryProvider = directory ?? _defaultDirectory;

  static const _indexFileName = 'recordings.json';
  @override
  String defaultNamePrefix = 'Grabación';

  final Future<Directory> Function() _directoryProvider;
  Directory? _directory;

  /// Serializa las escrituras del índice para que dos cambios simultáneos
  /// (p. ej. renombrar mientras se sincroniza una copia) no se pisen.
  Future<void> _lock = Future.value();

  static Future<Directory> _defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'recordings'));
  }

  Future<Directory> _getDirectory() async {
    final directory = _directory ??= await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  @override
  Future<String> createRecordingPath({
    RecordingFormat format = RecordingFormat.aac,
  }) async {
    final directory = await _getDirectory();
    final baseId =
        'rec_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    // El id es el nombre sin extensión: no puede repetirse en otro formato.
    Future<bool> taken(String id) async {
      for (final other in RecordingFormat.values) {
        if (await File(_pathFor(directory, id, other)).exists()) return true;
      }
      return false;
    }

    var id = baseId;
    var suffix = 1;
    while (await taken(id)) {
      id = '${baseId}_${suffix++}';
    }
    return _pathFor(directory, id, format);
  }

  @override
  Future<List<Recording>> loadAll() async {
    final directory = await _getDirectory();
    final index = await _readIndex(directory);

    final recordings = <Recording>[];
    await for (final entity in directory.list()) {
      if (entity is! File || RecordingFormat.fromPath(entity.path) == null) {
        continue;
      }
      final id = p.basenameWithoutExtension(entity.path);
      final metadata = index[id];
      recordings.add(
        metadata != null
            ? Recording.fromMetadata(id: id, path: entity.path, json: metadata)
            // Archivo sin metadatos (p. ej. si el índice se perdió).
            : Recording(
                id: id,
                path: entity.path,
                name: id,
                createdAt: await entity.lastModified(),
                duration: Duration.zero,
              ),
      );
    }

    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recordings;
  }

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
    if (!await File(path).exists()) return null;

    return _synchronized(() async {
      final directory = await _getDirectory();
      final index = await _readIndex(directory);
      final recording = Recording(
        id: p.basenameWithoutExtension(path),
        path: path,
        name:
            name ??
            nextDefaultName(
              index.values.map((m) => m['name'] as String?),
              prefix: defaultNamePrefix,
            ),
        createdAt: createdAt ?? DateTime.now(),
        duration: duration,
        waveform: waveform,
        audio: audio,
        copies: copies,
        folder: folder,
      );
      index[recording.id] = recording.toMetadata();
      await _writeIndex(directory, index);
      return recording;
    });
  }

  @override
  Future<Recording> rename(Recording recording, String name) {
    return _update(recording, (metadata) => metadata['name'] = name.trim());
  }

  @override
  Future<Recording> replaceAudio(
    Recording recording, {
    required String sourcePath,
    required Duration duration,
    List<double>? waveform,
    AudioInfo? audio,
  }) async {
    await moveFile(sourcePath, recording.path);
    return _update(recording, (metadata) {
      metadata['durationMs'] = duration.inMilliseconds;
      metadata['revision'] = (metadata['revision'] as int? ?? 0) + 1;
      if (waveform != null) {
        metadata['waveform'] = encodeWaveform(waveform);
      } else {
        metadata.remove('waveform');
      }
      if (audio != null) {
        metadata['audio'] = audio.toJson();
      } else {
        metadata.remove('audio');
      }
    });
  }

  @override
  Future<Recording> setDetails(
    Recording recording, {
    List<double>? waveform,
    Duration? duration,
    AudioInfo? audio,
  }) {
    return _update(recording, (metadata) {
      if (waveform != null) metadata['waveform'] = encodeWaveform(waveform);
      if (duration != null) metadata['durationMs'] = duration.inMilliseconds;
      if (audio != null) metadata['audio'] = audio.toJson();
    });
  }

  @override
  Future<Recording> setCopy(
    Recording recording,
    String target,
    CopyState? state,
  ) {
    return _update(recording, (metadata) {
      final copies = {...?(metadata['copies'] as Map<String, dynamic>?)};
      if (state == null) {
        copies.remove(target);
      } else {
        copies[target] = state.toJson();
      }
      if (copies.isEmpty) {
        metadata.remove('copies');
      } else {
        metadata['copies'] = copies;
      }
    });
  }

  @override
  Future<void> delete(Recording recording) async {
    await discard(recording.path);
    await _synchronized(() async {
      final directory = await _getDirectory();
      final index = await _readIndex(directory);
      if (index.remove(recording.id) != null) {
        await _writeIndex(directory, index);
      }
    });
  }

  @override
  Future<void> discard(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Siguiente nombre libre del tipo "Grabación N".
  static String nextDefaultName(
    Iterable<String?> existingNames, {
    String prefix = 'Grabación',
  }) {
    final pattern = RegExp('^${RegExp.escape(prefix)} (\\d+)\$');
    var highest = 0;
    for (final name in existingNames) {
      final match = name == null ? null : pattern.firstMatch(name);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > highest) highest = number;
      }
    }
    return '$prefix ${highest + 1}';
  }

  /// Modifica los metadatos de [recording] partiendo de los guardados (y no
  /// de [recording], que puede estar desactualizada) y devuelve el resultado.
  ///
  /// Si el audio se ha borrado entretanto (p. ej. mientras se copiaba o se
  /// calculaba su onda), no hace nada para no dejar una entrada huérfana.
  Future<Recording> _update(
    Recording recording,
    void Function(Map<String, dynamic> metadata) change,
  ) {
    return _synchronized(() async {
      if (!await File(recording.path).exists()) return recording;
      final directory = await _getDirectory();
      final index = await _readIndex(directory);
      final metadata = {...(index[recording.id] ?? recording.toMetadata())};
      change(metadata);
      index[recording.id] = metadata;
      await _writeIndex(directory, index);
      return Recording.fromMetadata(
        id: recording.id,
        path: recording.path,
        json: metadata,
      );
    });
  }

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  String _pathFor(Directory directory, String id, RecordingFormat format) =>
      p.join(directory.path, '$id${format.extension}');

  Future<Map<String, Map<String, dynamic>>> _readIndex(
    Directory directory,
  ) async {
    final file = File(p.join(directory.path, _indexFileName));
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: entry.value as Map<String, dynamic>,
      };
    } on FormatException {
      // Índice corrupto: las grabaciones siguen apareciendo, sin metadatos.
      return {};
    }
  }

  Future<void> _writeIndex(
    Directory directory,
    Map<String, Map<String, dynamic>> index,
  ) async {
    final file = File(p.join(directory.path, _indexFileName));
    // Escritura atómica: primero a un temporal y luego se renombra.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(index), flush: true);
    await temp.rename(file.path);
  }
}
