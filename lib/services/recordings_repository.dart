import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recording.dart';

/// Almacén de las grabaciones del usuario.
abstract interface class RecordingsRepository {
  /// Devuelve una ruta libre donde guardar una nueva grabación.
  Future<String> createRecordingPath();

  /// Devuelve todas las grabaciones, de la más reciente a la más antigua.
  Future<List<Recording>> loadAll();

  /// Registra el archivo de audio de [path] como una nueva grabación.
  ///
  /// Devuelve `null` si el archivo no existe.
  Future<Recording?> add({required String path, required Duration duration});

  Future<Recording> rename(Recording recording, String name);

  Future<void> delete(Recording recording);

  /// Elimina un archivo de audio que no llegó a registrarse.
  Future<void> discard(String path);
}

/// Guarda los audios en una carpeta del dispositivo y sus metadatos
/// (nombre, fecha y duración) en un índice JSON dentro de la misma carpeta.
class FileRecordingsRepository implements RecordingsRepository {
  FileRecordingsRepository({Future<Directory> Function()? directory})
    : _directoryProvider = directory ?? _defaultDirectory;

  static const fileExtension = '.m4a';
  static const _indexFileName = 'recordings.json';
  static const defaultNamePrefix = 'Grabación';

  final Future<Directory> Function() _directoryProvider;
  Directory? _directory;

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
  Future<String> createRecordingPath() async {
    final directory = await _getDirectory();
    final baseId =
        'rec_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    var id = baseId;
    var suffix = 1;
    while (await File(_pathFor(directory, id)).exists()) {
      id = '${baseId}_${suffix++}';
    }
    return _pathFor(directory, id);
  }

  @override
  Future<List<Recording>> loadAll() async {
    final directory = await _getDirectory();
    final index = await _readIndex(directory);

    final recordings = <Recording>[];
    await for (final entity in directory.list()) {
      if (entity is! File || p.extension(entity.path) != fileExtension) {
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
  }) async {
    if (!await File(path).exists()) return null;

    final directory = await _getDirectory();
    final index = await _readIndex(directory);
    final recording = Recording(
      id: p.basenameWithoutExtension(path),
      path: path,
      name: nextDefaultName(index.values.map((m) => m['name'] as String?)),
      createdAt: DateTime.now(),
      duration: duration,
    );
    index[recording.id] = recording.toMetadata();
    await _writeIndex(directory, index);
    return recording;
  }

  @override
  Future<Recording> rename(Recording recording, String name) async {
    final renamed = recording.copyWith(name: name.trim());
    final directory = await _getDirectory();
    final index = await _readIndex(directory);
    index[recording.id] = renamed.toMetadata();
    await _writeIndex(directory, index);
    return renamed;
  }

  @override
  Future<void> delete(Recording recording) async {
    await discard(recording.path);
    final directory = await _getDirectory();
    final index = await _readIndex(directory);
    if (index.remove(recording.id) != null) {
      await _writeIndex(directory, index);
    }
  }

  @override
  Future<void> discard(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Siguiente nombre libre del tipo "Grabación N".
  static String nextDefaultName(Iterable<String?> existingNames) {
    final pattern = RegExp('^$defaultNamePrefix (\\d+)\$');
    var highest = 0;
    for (final name in existingNames) {
      final match = name == null ? null : pattern.firstMatch(name);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > highest) highest = number;
      }
    }
    return '$defaultNamePrefix ${highest + 1}';
  }

  String _pathFor(Directory directory, String id) =>
      p.join(directory.path, '$id$fileExtension');

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
