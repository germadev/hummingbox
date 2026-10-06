import 'dart:math' as math;
import 'dart:typed_data';

import '../models/instrument.dart';
import '../models/piano_note.dart';
import '../models/synth_patch.dart';
import 'instrument_tone.dart';
import 'wav.dart';

/// Volumen de las notas en una grabación solo de piano (deja margen para
/// los acordes).
const pianoOnlyGain = 0.4;

/// Volumen de las notas sobre la voz.
const pianoOverVoiceGain = 0.3;

/// Escribe en [output] un WAV mono de [duration] en el que suenan [notes],
/// cada una cuando se tocó.
Future<void> renderPianoWav({
  required String output,
  required List<PianoNote> notes,
  required Duration duration,
  int sampleRate = 44100,
}) async {
  final format = PcmFormat(sampleRate: sampleRate, channels: 1);
  final mixer = PianoMixer(format, notes, gain: pianoOnlyGain);
  final total = format.framesIn(duration);
  final writer = await WavWriter.open(output, format);
  try {
    const block = 32768;
    for (var frame = 0; frame < total; frame += block) {
      final samples = Int16List(math.min(block, total - frame));
      mixer.addTo(samples, frame);
      await writer.write(samples);
    }
  } finally {
    await writer.close();
  }
}

/// Escribe en [output] el WAV de [input] (la voz) con [notes] sonando
/// encima, cada una cuando se tocó. La duración es la de [input].
Future<void> mixPianoIntoWav({
  required String input,
  required String output,
  required List<PianoNote> notes,
}) async {
  final info = await readWavInfo(input);
  final mixer = PianoMixer(info.format, notes, gain: pianoOverVoiceGain);
  final writer = await WavWriter.open(output, info.format);
  try {
    var frame = 0;
    await for (final samples in readWavSamples(input, info)) {
      mixer.addTo(samples, frame);
      await writer.write(samples);
      frame += samples.length ~/ info.format.channels;
    }
  } finally {
    await writer.close();
  }
}

/// Suma el sonido de unas notas a bloques de muestras, cada una con su
/// instrumento.
///
/// Como al tocar el piano, cada tecla suena una sola vez: al volver a
/// tocarla, la nota anterior se apaga (en [_cutFade], para que no
/// chasquee). Y lo que suenan juntas se limita a [ceiling] bajando el
/// volumen poco a poco ([_limitChunk]), en vez de recortar las muestras que
/// se pasan, que sonaba a ruido con acordes o notas rápidas.
///
/// Los bloques se piden en orden (como al escribir un archivo); si no, se
/// mezclan igual, pero el volumen puede volver antes de lo normal.
class PianoMixer {
  PianoMixer(this.format, List<PianoNote> notes, {required this.gain})
    : _fadeFrames = math.max(1, format.framesIn(_cutFade)),
      _releaseStep =
          _limitChunk /
          (format.sampleRate * _limitRelease.inMicroseconds / 1e6) {
    // Cada sonido se sintetiza una sola vez (en los sostenidos, cuánto se
    // mantuvo la tecla cambia el sonido).
    final tones = <(Instrument, int, Duration, SynthPatch?), Float32List>{};
    final sorted = [...notes]..sort((a, b) => a.start.compareTo(b.start));
    // Cuándo se vuelve a tocar cada tecla, de la última nota a la primera.
    final nextPress = <int, int>{};
    final mixed = <_MixedNote>[];
    for (final note in sorted.reversed) {
      final start = format.framesIn(note.start);
      final tone =
          tones[(
            note.instrument,
            note.key,
            note.instrument.sustained ? note.duration : Duration.zero,
            note.instrument == Instrument.synth ? note.synth : null,
          )] ??= _scaled(
            instrumentTone(
              note.instrument,
              note.key,
              held: note.duration,
              synth: note.synth,
              sampleRate: format.sampleRate,
            ),
            toneLevel(note.instrument),
          );
      final cut = nextPress[note.key];
      nextPress[note.key] = start;
      mixed.add(
        _MixedNote(
          start,
          tone,
          cut: cut,
          end: cut == null
              ? start + tone.length
              : math.min(start + tone.length, cut + _fadeFrames),
        ),
      );
    }
    _notes = mixed.reversed.toList();
  }

  /// Lo que tarda en apagarse una nota al volver a tocar su tecla.
  static const _cutFade = Duration(milliseconds: 10);

  /// Pico al que se limita el sonido de las notas (del máximo de la
  /// muestra).
  static const ceiling = 0.9;

  /// Fotogramas en los que el limitador mira el pico: el volumen baja a lo
  /// largo del trozo anterior a uno que se pasa (unos 6 ms a 44,1 kHz).
  static const _limitChunk = 256;

  /// Lo que tarda el volumen en volver del todo cuando deja de hacer falta
  /// limitarlo.
  static const _limitRelease = Duration(milliseconds: 300);

  static Float32List _scaled(Float32List tone, double level) {
    if (level == 1) return tone;
    for (var i = 0; i < tone.length; i++) {
      tone[i] *= level;
    }
    return tone;
  }

  final PcmFormat format;
  final double gain;

  final int _fadeFrames;

  /// Lo que puede subir el volumen de un trozo al siguiente.
  final double _releaseStep;

  /// Las notas, por orden de inicio.
  late final List<_MixedNote> _notes;

  /// Muestras (sin limitar) y volumen máximo de los últimos trozos.
  final _chunks = <int, (Float64List, double)>{};

  /// Volumen al principio de los últimos trozos.
  final _gains = <int, double>{};

  /// Suma las notas que suenan en [samples], que empieza en el fotograma
  /// [firstFrame] (en todos los canales por igual).
  void addTo(Int16List samples, int firstFrame) {
    final channels = format.channels;
    final frames = samples.length ~/ channels;
    if (frames == 0) return;
    final lastFrame = firstFrame + frames;
    for (
      var chunk = firstFrame ~/ _limitChunk;
      chunk * _limitChunk < lastFrame;
      chunk++
    ) {
      final chunkStart = chunk * _limitChunk;
      final (values, _) = _chunkAt(chunk);
      final from = math.max(chunkStart, firstFrame);
      final to = math.min(chunkStart + _limitChunk, lastFrame);
      // El volumen pasa del del principio del trozo al del siguiente.
      final startGain = _gainAt(chunk);
      final slope = (_gainAt(chunk + 1) - startGain) / _limitChunk;
      for (var frame = from; frame < to; frame++) {
        final offset = frame - chunkStart;
        final value = values[offset] * (startGain + slope * offset) * 32767;
        if (value == 0) continue;
        final base = (frame - firstFrame) * channels;
        for (var c = 0; c < channels; c++) {
          samples[base + c] = (samples[base + c] + value).round().clamp(
            -32768,
            32767,
          );
        }
      }
      // Solo hacen falta los trozos de alrededor del siguiente.
      _chunks.removeWhere((key, _) => key < chunk);
      _gains.removeWhere((key, _) => key < chunk);
    }
  }

  /// Muestras del trozo [chunk], ya con [gain], y su pico.
  (Float64List, double) _chunkAt(int chunk) => _chunks[chunk] ??= () {
    final chunkStart = chunk * _limitChunk;
    final chunkEnd = chunkStart + _limitChunk;
    final values = Float64List(_limitChunk);
    for (final note in _notes) {
      if (note.start >= chunkEnd) break;
      final from = math.max(note.start, chunkStart);
      final to = math.min(note.end, chunkEnd);
      final cut = note.cut;
      for (var frame = from; frame < to; frame++) {
        var value = note.tone[frame - note.start] * gain;
        if (cut != null && frame >= cut) {
          value *= 1 - (frame - cut) / _fadeFrames;
        }
        values[frame - chunkStart] += value;
      }
    }
    var peak = 0.0;
    for (final value in values) {
      peak = math.max(peak, value.abs());
    }
    return (values, peak);
  }();

  /// Volumen con el que se mezcla el trozo [chunk] para no pasar de
  /// [ceiling].
  double _limitOf(int chunk) {
    if (chunk < 0) return 1;
    final (_, peak) = _chunkAt(chunk);
    return peak > ceiling ? ceiling / peak : 1;
  }

  /// Volumen al principio del trozo [chunk]: no pasa del que necesitan
  /// este trozo y el anterior, y sube poco a poco.
  double _gainAt(int chunk) => _gains[chunk] ??= () {
    final limit = math.min(_limitOf(chunk - 1), _limitOf(chunk));
    final previous = _gains[chunk - 1];
    return previous == null ? limit : math.min(limit, previous + _releaseStep);
  }();
}

/// Una nota al mezclarla: su sonido desde el fotograma [start] hasta [end]
/// y, si se vuelve a tocar su tecla, desde cuándo se apaga ([cut]).
class _MixedNote {
  const _MixedNote(this.start, this.tone, {required this.end, this.cut});

  final int start;
  final int end;
  final int? cut;
  final Float32List tone;
}
