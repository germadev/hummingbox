/// Una grabación de audio guardada en el dispositivo.
class Recording {
  const Recording({
    required this.id,
    required this.path,
    required this.name,
    required this.createdAt,
    required this.duration,
  });

  /// Construye una grabación a partir de los metadatos guardados en el índice.
  factory Recording.fromMetadata({
    required String id,
    required String path,
    required Map<String, dynamic> json,
  }) {
    return Recording(
      id: id,
      path: path,
      name: json['name'] as String? ?? id,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
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

  Map<String, dynamic> toMetadata() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
  };

  Recording copyWith({String? name, Duration? duration}) {
    return Recording(
      id: id,
      path: path,
      name: name ?? this.name,
      createdAt: createdAt,
      duration: duration ?? this.duration,
    );
  }
}
