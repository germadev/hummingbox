import '../audio/audio_info.dart';
import '../audio/levels.dart';
import 'recording_options.dart';

/// Una grabación de audio guardada en el dispositivo.
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

  /// Ruta absoluta del archivo de audio.
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

  /// Copias guardadas fuera de la app, por destino (carpeta, Google Drive…).
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

  Map<String, dynamic> toMetadata() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
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

/// Estado de la copia de una grabación en un destino externo.
class CopyState {
  const CopyState({
    required this.destination,
    required this.ref,
    required this.revision,
    required this.name,
  });

  /// Carpeta de destino en la que se hizo la copia. Si el usuario elige otra,
  /// la copia se vuelve a hacer.
  final String destination;

  /// Referencia del archivo copiado en el destino (URI, id de Drive…).
  final String ref;

  /// Revisión del audio que se copió.
  final int revision;

  /// Nombre de la grabación cuando se copió.
  final String name;

  static CopyState? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final destination = json['destination'];
    final ref = json['ref'];
    final revision = json['revision'];
    final name = json['name'];
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
    );
  }

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'ref': ref,
    'revision': revision,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      other is CopyState &&
      other.destination == destination &&
      other.ref == ref &&
      other.revision == revision &&
      other.name == name;

  @override
  int get hashCode => Object.hash(destination, ref, revision, name);
}
