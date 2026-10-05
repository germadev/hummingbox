import '../audio/audio_info.dart';
import '../audio/levels.dart';
import 'recording_options.dart';

/// Una grabación de audio: dentro de la app o, si se eligió una, en la
/// carpeta del dispositivo.
class Recording {
  const Recording({
    required this.id,
    required this.path,
    required this.name,
    required this.createdAt,
    required this.duration,
    this.waveform,
    this.revision = 0,
    this.copies = const {},
    this.audio,
    this.folder = '',
  });

  /// Clave de [copies] del archivo de la carpeta del dispositivo.
  static const folderKey = 'folder';

  /// Clave de [copies] del archivo de Google Drive.
  static const driveKey = 'drive';

  /// Construye una grabación a partir de los metadatos guardados en el índice.
  factory Recording.fromMetadata({
    required String id,
    required String path,
    required Map<String, dynamic> json,
  }) {
    final copies = json['copies'];
    return Recording(
      id: id,
      path: path,
      name: json['name'] as String? ?? id,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      waveform: decodeWaveform(json['waveform']),
      revision: json['revision'] as int? ?? 0,
      audio: AudioInfo.fromJson(json['audio']),
      folder: json['folder'] as String? ?? '',
      copies: {
        if (copies is Map<String, dynamic>)
          for (final entry in copies.entries)
            entry.key: ?CopyState.fromJson(entry.value),
      },
    );
  }

  /// Identificador único: el nombre del archivo sin extensión.
  final String id;

  /// Ruta absoluta del audio dentro de la app. Si la grabación está guardada
  /// fuera (en la carpeta del dispositivo o en Google Drive, ver [copies]),
  /// el archivo solo existe mientras falta guardarla allí: para leer el audio
  /// se usa `StorageSync.audioPath`.
  final String path;

  /// Nombre visible, editable por el usuario.
  final String name;

  final DateTime createdAt;

  /// Duración de la grabación. Es [Duration.zero] si no se conoce.
  final Duration duration;

  /// Niveles (0–1) de la onda de toda la grabación, o `null` si todavía no se
  /// han calculado.
  final List<double>? waveform;

  /// Aumenta cada vez que se edita el audio, para saber qué copias están
  /// desactualizadas.
  final int revision;

  /// Archivos guardados fuera de la app, por destino ([folderKey],
  /// [driveKey]): donde se guarda la grabación y, si la hay, su copia.
  final Map<String, CopyState> copies;

  /// Formato y calidad del audio, leídos del archivo, o `null` si todavía no
  /// se han leído.
  final AudioInfo? audio;

  /// Subcarpeta en la que está (en la app y en la carpeta del dispositivo);
  /// vacío si está en la principal.
  final String folder;

  /// Formato del archivo según su extensión.
  RecordingFormat get format =>
      RecordingFormat.fromPath(path) ?? RecordingFormat.aac;

  /// Indica si el archivo del destino [key] tiene el audio y el nombre
  /// actuales (si no, falta guardarlos allí).
  bool isSavedIn(String key) => switch (copies[key]) {
    final file? => file.revision == revision && file.name == name,
    null => false,
  };

  /// Formato guardado en los metadatos de [json] (para las grabaciones cuyo
  /// audio no está dentro de la app).
  static RecordingFormat formatIn(Map<String, dynamic> json) =>
      RecordingFormat.values.asNameMap()[json['format']] ?? RecordingFormat.aac;

  Map<String, dynamic> toMetadata() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    if (format != RecordingFormat.aac) 'format': format.name,
    if (waveform != null) 'waveform': encodeWaveform(waveform!),
    if (revision != 0) 'revision': revision,
    if (audio != null) 'audio': audio!.toJson(),
    if (folder.isNotEmpty) 'folder': folder,
    if (copies.isNotEmpty)
      'copies': {
        for (final entry in copies.entries) entry.key: entry.value.toJson(),
      },
  };

  Recording copyWith({
    String? name,
    Duration? duration,
    List<double>? waveform,
    int? revision,
    Map<String, CopyState>? copies,
    AudioInfo? audio,
  }) {
    return Recording(
      id: id,
      path: path,
      name: name ?? this.name,
      createdAt: createdAt,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      revision: revision ?? this.revision,
      copies: copies ?? this.copies,
      audio: audio ?? this.audio,
      folder: folder,
    );
  }
}

/// Archivo de una grabación fuera de la app: en la carpeta del dispositivo
/// (donde se guarda) o la copia de Google Drive.
class CopyState {
  const CopyState({
    required this.destination,
    required this.ref,
    required this.revision,
    required this.name,
    this.size,
  });

  /// Carpeta en la que está el archivo (la del dispositivo o la de Drive).
  final String destination;

  /// Referencia del archivo en el destino (URI, id de Drive…).
  final String ref;

  /// Revisión del audio que tiene el archivo.
  final int revision;

  /// Nombre de la grabación cuando se guardó el archivo.
  final String name;

  /// Tamaño del archivo la última vez que se guardó o se leyó la carpeta, si
  /// se conoce. Si cambia, es que se ha modificado fuera de la app.
  final int? size;

  CopyState withSize(int? size) => CopyState(
    destination: destination,
    ref: ref,
    revision: revision,
    name: name,
    size: size,
  );

  static CopyState? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final destination = json['destination'];
    final ref = json['ref'];
    final revision = json['revision'];
    final name = json['name'];
    final size = json['size'];
    if (destination is! String ||
        ref is! String ||
        revision is! int ||
        name is! String) {
      return null;
    }
    return CopyState(
      destination: destination,
      ref: ref,
      revision: revision,
      name: name,
      size: size is int ? size : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'ref': ref,
    'revision': revision,
    'name': name,
    if (size != null) 'size': size,
  };

  @override
  bool operator ==(Object other) =>
      other is CopyState &&
      other.destination == destination &&
      other.ref == ref &&
      other.revision == revision &&
      other.name == name &&
      other.size == size;

  @override
  int get hashCode => Object.hash(destination, ref, revision, name, size);
}
