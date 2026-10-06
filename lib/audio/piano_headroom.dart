import 'dart:math' as math;
import 'dart:typed_data';

/// Cómo suena una nota a lo largo del tiempo: el pico de cada trozo de
/// [block], en fracción del máximo de la muestra.
class ToneEnvelope {
  ToneEnvelope(this.peaks);

  /// De las muestras de un WAV de 16 bits (de todos sus canales).
  factory ToneEnvelope.ofWav(Uint8List wav) {
    final data = ByteData.sublistView(wav);
    var channels = 1;
    var sampleRate = 44100;
    var offset = 12;
    while (offset + 8 <= wav.length) {
      final id = String.fromCharCodes(wav, offset, offset + 4);
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ' && body + 8 <= wav.length) {
        channels = math.max(1, data.getUint16(body + 2, Endian.little));
        sampleRate = data.getUint32(body + 4, Endian.little);
      } else if (id == 'data') {
        final end = math.min(wav.length, body + size);
        final samples = (end - body) ~/ 2;
        final perBlock = math.max(
          1,
          (sampleRate * block.inMicroseconds / 1e6).round() * channels,
        );
        final peaks = Float32List((samples + perBlock - 1) ~/ perBlock);
        for (var i = 0; i < samples; i++) {
          final value =
              data.getInt16(body + 2 * i, Endian.little).abs() / 32768;
          final index = i ~/ perBlock;
          if (value > peaks[index]) peaks[index] = value;
        }
        return ToneEnvelope(peaks);
      }
      offset = body + size + (size & 1);
    }
    return ToneEnvelope(Float32List(0));
  }

  /// Lo que dura cada trozo.
  static const block = Duration(milliseconds: 10);

  final Float32List peaks;

  /// Lo que suena la nota.
  Duration get length => block * peaks.length;

  /// El pico más alto entre [from] y [from] más [span] (desde que empieza a
  /// sonar la nota).
  double peakIn(Duration from, Duration span) {
    final first = math.max(0, from.inMicroseconds ~/ block.inMicroseconds);
    final last = math.min(
      peaks.length - 1,
      (from + span).inMicroseconds ~/ block.inMicroseconds,
    );
    var peak = 0.0;
    for (var i = first; i <= last; i++) {
      peak = math.max(peak, peaks[i]);
    }
    return peak;
  }
}

/// El volumen de las teclas que suenan a la vez al tocar el piano, para que
/// juntas no pasen de [ceiling].
///
/// Cada tecla suena con su reproductor y el sistema los suma: lo que se pasa
/// del máximo lo recorta, y eso suena a ruido (con acordes o notas rápidas,
/// que se solapan mientras se apagan). Como un limitador: con lo que van a
/// sonar las notas en [lookahead], si se pasarían, el volumen de todas baja
/// lo justo enseguida, y vuelve poco a poco ([recovery]) a medida que se
/// apagan. Una nota sola suena con todo su volumen.
///
/// Las notas se identifican por su tecla: al volver a tocarla, la nueva
/// sustituye a la anterior (que deja de sonar).
class PianoHeadroom {
  /// Pico al que se limita lo que suenan juntas (del máximo de la muestra).
  static const ceiling = 0.9;

  /// Lo que se mira por delante: hasta que se vuelve a calcular el volumen
  /// ([update]) y el cambio llega a oírse.
  static const lookahead = Duration(milliseconds: 120);

  /// Lo que tarda el volumen en volver de nada a todo.
  static const recovery = Duration(milliseconds: 400);

  final _notes = <int, _Note>{};

  double _gain = 1;

  /// Volumen de todas las notas, de 0 a 1.
  double get gain => _gain;

  Duration? _updatedAt;

  /// Las teclas que suenan.
  Iterable<int> get keys => _notes.keys;

  bool get isEmpty => _notes.isEmpty;

  /// Empieza a sonar la tecla [key], con el sonido de [envelope], en [now]
  /// (un reloj cualquiera que no vuelva atrás).
  void start(int key, ToneEnvelope envelope, Duration now) {
    _notes[key] = _Note(envelope, now);
    update(now);
  }

  /// La tecla [key] suena a [level] de su volumen (al apagarse, de 1 a 0).
  void fade(int key, double level) => _notes[key]?.level = level;

  /// La tecla [key] deja de sonar.
  void end(int key) => _notes.remove(key);

  /// Recalcula el volumen en [now]: baja enseguida lo que haga falta y sube
  /// poco a poco. Olvida las notas que ya han terminado.
  double update(Duration now) {
    _notes.removeWhere((_, note) => now - note.start >= note.envelope.length);
    var peak = 0.0;
    for (final note in _notes.values) {
      peak += note.level * note.envelope.peakIn(now - note.start, lookahead);
    }
    final target = peak > ceiling ? ceiling / peak : 1.0;
    final elapsed = switch (_updatedAt) {
      final updatedAt? => now - updatedAt,
      null => recovery,
    };
    _updatedAt = now;
    _gain = target <= _gain
        ? target
        : math.min(
            target,
            _gain + elapsed.inMicroseconds / recovery.inMicroseconds,
          );
    return _gain;
  }

  /// Volumen con el que tiene que sonar el reproductor de [key].
  double volumeOf(int key) => (_notes[key]?.level ?? 1) * _gain;
}

class _Note {
  _Note(this.envelope, this.start);

  final ToneEnvelope envelope;
  final Duration start;

  /// Lo que suena de su volumen: menos al apagarse.
  double level = 1;
}
