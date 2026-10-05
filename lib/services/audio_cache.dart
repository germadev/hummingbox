import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recording.dart';

/// Caché del audio de las grabaciones guardadas fuera de la app (en la
/// carpeta del dispositivo o en Google Drive).
///
/// Los reproductores y los códecs necesitan un archivo local, así que el
/// audio se lee de donde está guardado cuando hace falta y se deja aquí.
/// La caché no pasa de [maxBytes]: cuando se llena, se borra lo que hace más
/// tiempo que no se usa. El sistema también puede vaciarla.
class AudioCache {
  AudioCache({
    Future<Directory> Function()? directory,
    this.maxBytes = 100 << 20,
  }) : _directoryProvider = directory ?? _defaultDirectory;

  /// Tamaño máximo; por defecto, 100 MB (unos 100 minutos de AAC en calidad
  /// alta).
  final int maxBytes;
  final Future<Directory> Function() _directoryProvider;

  /// Lecturas en curso por archivo, para no leer el mismo dos veces a la vez.
  final _reading = <String, Future<String>>{};

  static Future<Directory> _defaultDirectory() async {
    final cache = await getApplicationCacheDirectory();
    return Directory(p.join(cache.path, 'audio'));
  }

  /// Archivo de la caché para el audio actual de [recording].
  Future<String> pathFor(Recording recording) async => p.join(
    (await _directoryProvider()).path,
    '${recording.id}.${recording.revision}${recording.format.extension}',
  );

  /// Ruta local del audio actual de [recording]. Si no está en la caché, lo
  /// guarda en ella con [read], que lo copia a la ruta que se le indica.
  Future<String> fetch(
    Recording recording,
    Future<void> Function(String destination) read,
  ) async {
    final path = await pathFor(recording);
    // Las consultas de si existe un archivo son instantáneas: se hacen
    // síncronas.
    if (File(path).existsSync()) {
      _touch(path);
      return path;
    }
    return _reading[path] ??= _read(recording, path, read).whenComplete(() {
      // Sin devolver nada: `remove` devuelve esta misma lectura, y
      // `whenComplete` esperaría a que terminara.
      _reading.remove(path);
    });
  }

  Future<String> _read(
    Recording recording,
    String path,
    Future<void> Function(String destination) read,
  ) async {
    Directory(p.dirname(path)).createSync(recursive: true);
    final partial = '$path.part';
    try {
      await read(partial);
      File(partial).renameSync(path);
    } catch (_) {
      _deleteQuietly(File(partial));
      rethrow;
    }
    // Las revisiones anteriores ya no sirven.
    await _forget(recording, except: path);
    await trim(keep: path);
    return path;
  }

  /// Borra de la caché el audio de [recording].
  Future<void> forget(Recording recording) => _forget(recording);

  Future<void> _forget(Recording recording, {String? except}) async {
    final directory = await _directoryProvider();
    if (!directory.existsSync()) return;
    final prefix = '${recording.id}.';
    for (final entity in directory.listSync()) {
      if (entity is File &&
          entity.path != except &&
          !entity.path.endsWith('.part') &&
          p.basename(entity.path).startsWith(prefix)) {
        _deleteQuietly(entity);
      }
    }
  }

  /// Borra lo que hace más tiempo que no se usa hasta que la caché ocupa como
  /// mucho [maxBytes]. El archivo [keep] no se borra.
  Future<void> trim({String? keep}) async {
    final directory = await _directoryProvider();
    if (!directory.existsSync()) return;
    final files = [
      for (final entity in directory.listSync())
        if (entity is File && !entity.path.endsWith('.part'))
          (file: entity, stat: entity.statSync()),
    ]..sort((a, b) => b.stat.modified.compareTo(a.stat.modified));

    var total = 0;
    for (final (:file, :stat) in files) {
      total += stat.size;
      if (total > maxBytes && file.path != keep) _deleteQuietly(file);
    }
  }

  /// Marca [path] como recién usado, para que sea lo último que se borre.
  static void _touch(String path) {
    try {
      File(path).setLastModifiedSync(DateTime.now());
    } on FileSystemException {
      // Solo afecta al orden en que se vacía la caché.
    }
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Se volverá a intentar al vaciar la caché (o lo hará el sistema).
    }
  }
}
