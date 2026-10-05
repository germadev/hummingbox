import 'dart:math' as math;
import 'dart:typed_data';

import '../models/piano_note.dart';
import 'piano_tone.dart';
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

/// Suma el sonido de unas notas a bloques de muestras.
class PianoMixer {
  PianoMixer(this.format, List<PianoNote> notes, {required this.gain}) {
    // Cada tecla se sintetiza una sola vez.
    final tones = <int, Float32List>{};
    _notes = [
      for (final note in notes)
        (
          format.framesIn(note.start),
          tones[note.key] ??= pianoTone(
            note.key,
            sampleRate: format.sampleRate,
          ),
        ),
    ];
  }

  final PcmFormat format;
  final double gain;

  /// Primer fotograma y sonido de cada nota.
  late final List<(int, Float32List)> _notes;

  /// Suma las notas que suenan en [samples], que empieza en el fotograma
  /// [firstFrame] (en todos los canales por igual).
  void addTo(Int16List samples, int firstFrame) {
    final channels = format.channels;
    final frames = samples.length ~/ channels;
    final lastFrame = firstFrame + frames;
    for (final (start, tone) in _notes) {
      final from = math.max(start, firstFrame);
      final to = math.min(start + tone.length, lastFrame);
      for (var frame = from; frame < to; frame++) {
        final value = tone[frame - start] * gain * 32767;
        final base = (frame - firstFrame) * channels;
        for (var c = 0; c < channels; c++) {
          samples[base + c] = (samples[base + c] + value).round().clamp(
            -32768,
            32767,
          );
        }
      }
    }
  }
}
