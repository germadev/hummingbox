import 'dart:math' as math;
import 'dart:typed_data';

import 'levels.dart';
import 'wav.dart';

/// Cambios que se aplican a una grabación en el modo de edición.
class AudioEdit {
  const AudioEdit({
    required this.start,
    required this.end,
    this.gainDb = 0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });

  /// Parte de la grabación que se conserva.
  final Duration start;
  final Duration end;

  /// Ganancia en decibelios: positiva sube el volumen y negativa lo baja.
  final double gainDb;

  /// Duración de la entrada y la salida progresivas.
  final Duration fadeIn;
  final Duration fadeOut;

  Duration get length => end - start;

  /// Factor lineal equivalente a [gainDb].
  double get gain => gainFromDb(gainDb);

  /// Indica si la edición cambia algo de una grabación de [total] de duración.
  bool changes(Duration total) =>
      start > Duration.zero ||
      end < total ||
      gainDb != 0 ||
      fadeIn > Duration.zero ||
      fadeOut > Duration.zero;

  AudioEdit copyWith({
    Duration? start,
    Duration? end,
    double? gainDb,
    Duration? fadeIn,
    Duration? fadeOut,
  }) {
    return AudioEdit(
      start: start ?? this.start,
      end: end ?? this.end,
      gainDb: gainDb ?? this.gainDb,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioEdit &&
      other.start == start &&
      other.end == end &&
      other.gainDb == gainDb &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut;

  @override
  int get hashCode => Object.hash(start, end, gainDb, fadeIn, fadeOut);
}

double gainFromDb(double db) => math.pow(10, db / 20).toDouble();

double dbFromGain(double gain) =>
    gain <= 0 ? double.negativeInfinity : 20 * math.log(gain) / math.ln10;

/// Picos de un audio, divididos en tramos de igual duración.
class WavAnalysis {
  const WavAnalysis({required this.duration, required this.peaks});

  final Duration duration;

  /// Pico lineal (0–1) de cada tramo, de principio a fin.
  final List<double> peaks;

  /// Niveles para dibujar la onda, en la misma escala que durante la
  /// grabación.
  List<double> get levels => [for (final peak in peaks) levelFromPeak(peak)];

  /// Pico de todo el audio.
  double get peak => peaks.fold(0, math.max);

  /// Pico de los tramos que se solapan con `[start, end)`. Como incluye los
  /// tramos enteros de los extremos, nunca se queda por debajo del real.
  double peakBetween(Duration start, Duration end) {
    if (peaks.isEmpty || duration <= Duration.zero) return 0;
    final total = duration.inMicroseconds;
    int bucketAt(Duration time) => (time.inMicroseconds * peaks.length ~/ total)
        .clamp(0, peaks.length - 1);
    final first = bucketAt(start);
    final last = end <= start ? first : bucketAt(end - _epsilon);
    var highest = 0.0;
    for (var i = first; i <= last; i++) {
      highest = math.max(highest, peaks[i]);
    }
    return highest;
  }

  static const _epsilon = Duration(microseconds: 1);
}

/// Calcula los picos de un WAV en [buckets] tramos.
Future<WavAnalysis> analyzeWav(String path, {int buckets = 400}) async {
  final info = await readWavInfo(path);
  final peaks = _PeakCollector(info.frameCount, buckets);
  await for (final samples in readWavSamples(path, info)) {
    peaks.add(samples, info.format.channels);
  }
  return WavAnalysis(duration: info.duration, peaks: peaks.result());
}

/// Aplica [edit] al WAV de [input] y guarda el resultado en [output].
///
/// Trabaja por bloques, así que no carga el audio entero en memoria. Las
/// muestras que superan el máximo tras subir la ganancia se recortan.
/// Devuelve los picos del resultado en [buckets] tramos.
Future<WavAnalysis> processWav({
  required String input,
  required String output,
  required AudioEdit edit,
  int buckets = waveformResolution,
}) async {
  final info = await readWavInfo(input);
  final format = info.format;
  final channels = format.channels;
  final start = format.framesIn(edit.start).clamp(0, info.frameCount);
  final end = format.framesIn(edit.end).clamp(start, info.frameCount);
  final length = end - start;
  final fadeIn = format.framesIn(edit.fadeIn).clamp(0, length);
  final fadeOut = format.framesIn(edit.fadeOut).clamp(0, length);
  final gain = edit.gain;

  final writer = await WavWriter.open(output, format);
  final peaks = _PeakCollector(length, buckets);
  try {
    var position = 0;
    await for (final samples in readWavSamples(
      input,
      info,
      start: start,
      end: end,
    )) {
      final frames = samples.length ~/ channels;
      for (var i = 0; i < frames; i++) {
        final t = position + i;
        var factor = gain;
        if (t < fadeIn) factor *= t / fadeIn;
        final remaining = length - 1 - t;
        if (remaining < fadeOut) factor *= remaining / fadeOut;
        if (factor == 1) continue;
        for (var c = 0; c < channels; c++) {
          final index = i * channels + c;
          samples[index] = (samples[index] * factor).round().clamp(
            -32768,
            32767,
          );
        }
      }
      peaks.add(samples, channels);
      await writer.write(samples);
      position += frames;
    }
  } finally {
    await writer.close();
  }
  return WavAnalysis(
    duration: format.durationOf(writer.frameCount),
    peaks: peaks.result(),
  );
}

/// Acumula el pico de cada tramo a medida que llegan las muestras.
class _PeakCollector {
  _PeakCollector(this._totalFrames, int buckets)
    : _peaks = Int32List(math.max(0, math.min(buckets, _totalFrames)));

  final int _totalFrames;
  final Int32List _peaks;
  int _frame = 0;

  void add(Int16List samples, int channels) {
    if (_peaks.isEmpty) return;
    final frames = samples.length ~/ channels;
    for (var i = 0; i < frames; i++) {
      final bucket = (_frame + i) * _peaks.length ~/ _totalFrames;
      if (bucket >= _peaks.length) break;
      for (var c = 0; c < channels; c++) {
        final value = samples[i * channels + c].abs();
        if (value > _peaks[bucket]) _peaks[bucket] = value;
      }
    }
    _frame += frames;
  }

  List<double> result() => [for (final peak in _peaks) peak / 32768];
}
