/// Una nota tocada en el piano mientras se grababa: qué tecla y cuándo, desde
/// el principio de la grabación.
class PianoNote {
  const PianoNote({
    required this.key,
    required this.start,
    required this.duration,
  });

  /// Tecla, por su número MIDI (el La4, a 440 Hz, es 69).
  final int key;

  /// Cuándo se pulsó, desde el principio de la grabación.
  final Duration start;

  /// Cuánto se mantuvo pulsada.
  final Duration duration;

  Duration get end => start + duration;

  /// La misma nota [offset] antes (p. ej. al quitar el principio de la
  /// grabación).
  PianoNote shiftedBy(Duration offset) =>
      PianoNote(key: key, start: start - offset, duration: duration);

  /// En los metadatos, en poco espacio: `[tecla, inicio, duración]`, en
  /// milisegundos.
  List<int> toJson() => [key, start.inMilliseconds, duration.inMilliseconds];

  static PianoNote? fromJson(Object? json) {
    if (json case [final int key, final int start, final int duration]) {
      return PianoNote(
        key: key,
        start: Duration(milliseconds: start),
        duration: Duration(milliseconds: duration),
      );
    }
    return null;
  }

  /// Las notas de [json] (una lista), en orden; las que no se entienden se
  /// ignoran.
  static List<PianoNote> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ]..sort((a, b) => a.start.compareTo(b.start));

  /// Las notas de [notes] que suenan entre [start] y [end], contadas desde
  /// [start] (las que empiezan antes, desde el principio).
  static List<PianoNote> between(
    List<PianoNote> notes,
    Duration start,
    Duration end,
  ) => [
    for (final note in notes)
      if (note.start < end && note.end > start)
        note.start >= start
            ? note.shiftedBy(start)
            : PianoNote(
                key: note.key,
                start: Duration.zero,
                duration: note.end - start,
              ),
  ];

  @override
  bool operator ==(Object other) =>
      other is PianoNote &&
      other.key == key &&
      other.start == start &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(key, start, duration);

  @override
  String toString() =>
      'PianoNote($key, ${start.inMilliseconds} ms, '
      '${duration.inMilliseconds} ms)';
}
