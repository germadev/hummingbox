import 'instrument.dart';
import 'synth_patch.dart';

/// Una nota tocada en el piano mientras se grababa: qué tecla, cuándo, desde
/// el principio de la grabación, y con qué instrumento.
class PianoNote {
  const PianoNote({
    required this.key,
    required this.start,
    required this.duration,
    this.instrument = Instrument.piano,
    this.synth = const SynthPatch(),
  });

  /// Tecla, por su número MIDI (el La4, a 440 Hz, es 69).
  final int key;

  /// Cuándo se pulsó, desde el principio de la grabación.
  final Duration start;

  /// Cuánto se mantuvo pulsada.
  final Duration duration;

  /// Con qué sonó.
  final Instrument instrument;

  /// Cómo sonaba el sintetizador, si sonó con él, para generar su sonido (al
  /// terminar de grabar o, en las grabaciones solo de notas, al
  /// escucharlas). No cuenta al comparar notas.
  final SynthPatch synth;

  Duration get end => start + duration;

  /// La misma nota [offset] antes (p. ej. al quitar el principio de la
  /// grabación).
  PianoNote shiftedBy(Duration offset) => PianoNote(
    key: key,
    start: start - offset,
    duration: duration,
    instrument: instrument,
    synth: synth,
  );

  /// En los metadatos, en poco espacio: `[tecla, inicio, duración]`, en
  /// milisegundos, el nombre del instrumento si no es el piano y, con el
  /// sintetizador, su sonido si no es el de por defecto.
  List<Object> toJson() => [
    key,
    start.inMilliseconds,
    duration.inMilliseconds,
    if (instrument != Instrument.piano) instrument.name,
    if (instrument == Instrument.synth && synth != const SynthPatch())
      synth.toJson(),
  ];

  static PianoNote? fromJson(Object? json) {
    if (json
        case [final int key, final int start, final int duration, ...final rest]
        when rest.length <= 2) {
      // Un instrumento que no se conoce (de una versión más nueva), piano.
      final instrument = rest.isEmpty
          ? Instrument.piano
          : Instrument.byName(rest.first) ?? Instrument.piano;
      return PianoNote(
        key: key,
        start: Duration(milliseconds: start),
        duration: Duration(milliseconds: duration),
        instrument: instrument,
        synth: instrument == Instrument.synth && rest.length == 2
            ? SynthPatch.fromJson(rest.last)
            : const SynthPatch(),
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
                instrument: note.instrument,
                synth: note.synth,
              ),
  ];

  @override
  bool operator ==(Object other) =>
      other is PianoNote &&
      other.key == key &&
      other.start == start &&
      other.duration == duration &&
      other.instrument == instrument;

  @override
  int get hashCode => Object.hash(key, start, duration, instrument);

  @override
  String toString() =>
      'PianoNote($key, ${start.inMilliseconds} ms, '
      '${duration.inMilliseconds} ms, ${instrument.name})';
}
