import 'dart:math' as math;
import 'dart:typed_data';

import 'wav.dart';

/// Teclas de un piano de 88 teclas, de La0 a Do8, por su número MIDI (Do4,
/// el do central, es 60; La4, a 440 Hz, es 69).
abstract final class PianoKeys {
  static const lowest = 21;
  static const highest = 108;

  /// Las teclas blancas, de la más grave a la más aguda (52).
  static final whiteKeys = [
    for (var midi = lowest; midi <= highest; midi++)
      if (!isBlack(midi)) midi,
  ];

  static bool isBlack(int midi) => const {1, 3, 6, 8, 10}.contains(midi % 12);

  /// Octava en notación científica (el do central es Do4).
  static int octave(int midi) => midi ~/ 12 - 1;

  /// Frecuencia en Hz, con el La4 a 440 Hz.
  static double frequency(int midi) =>
      440 * math.pow(2, (midi - 69) / 12).toDouble();

  /// Posición entre las blancas ([whiteKeys]) de la tecla blanca [midi] o,
  /// si es negra, de la blanca que tiene a la izquierda.
  static int whiteIndexOf(int midi) =>
      whiteKeys.lastIndexWhere((white) => white <= midi);
}

/// Lo que suena cada tecla: al tocarla y en las grabaciones.
const pianoToneLength = Duration(milliseconds: 1600);

/// Sonido de una tecla de piano: muestras entre −1 y 1, con el pico en 1.
///
/// Es sintetizado: unos cuantos armónicos que se apagan antes cuanto más
/// agudos son, con un ataque rápido. No suena como un piano de verdad, pero
/// sirve para dar la nota.
Float32List pianoTone(
  int midi, {
  int sampleRate = 44100,
  Duration duration = pianoToneLength,
}) {
  final frames = PcmFormat(
    sampleRate: sampleRate,
    channels: 1,
  ).framesIn(duration);
  final frequency = PianoKeys.frequency(midi);
  // Las notas agudas se apagan antes, como en un piano.
  final decay = 1.6 + frequency / 400;
  final attackFrames = sampleRate * 0.004;
  final releaseFrames = sampleRate * 0.05;

  // Armónicos por debajo de la frecuencia de Nyquist.
  final harmonics = <(double, double, double)>[
    for (var n = 1; n <= 8 && frequency * n < sampleRate / 2.2; n++)
      (
        2 * math.pi * frequency * n / sampleRate,
        1 / math.pow(n, 1.4),
        decay * (1 + (n - 1) * 0.5),
      ),
  ];

  final tone = Float32List(frames);
  var peak = 0.0;
  for (var i = 0; i < frames; i++) {
    final t = i / sampleRate;
    var value = 0.0;
    for (final (step, amplitude, harmonicDecay) in harmonics) {
      value += amplitude * math.exp(-harmonicDecay * t) * math.sin(step * i);
    }
    final envelope =
        math.min(1.0, i / attackFrames) *
        math.min(1.0, (frames - 1 - i) / releaseFrames);
    value *= envelope;
    tone[i] = value;
    peak = math.max(peak, value.abs());
  }
  if (peak > 0) {
    for (var i = 0; i < frames; i++) {
      tone[i] /= peak;
    }
  }
  return tone;
}

/// Sonido de una tecla de piano ([pianoTone]) como WAV mono de 16 bits.
Uint8List pianoToneWav(
  int midi, {
  int sampleRate = 44100,
  Duration duration = pianoToneLength,
}) {
  final format = PcmFormat(sampleRate: sampleRate, channels: 1);
  final tone = pianoTone(midi, sampleRate: sampleRate, duration: duration);
  final samples = Int16List(tone.length);
  for (var i = 0; i < tone.length; i++) {
    samples[i] = (tone[i] * 0.7 * 32767).round();
  }
  final data = samples.buffer.asUint8List();
  return Uint8List.fromList([...wavHeader(format, data.length), ...data]);
}
