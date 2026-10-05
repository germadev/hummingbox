import 'dart:math' as math;
import 'dart:typed_data';

import '../models/instrument.dart';
import '../models/synth_patch.dart';
import 'piano_tone.dart';
import 'wav.dart';

/// Lo que suena una nota de [instrument] mantenida [held]: los que se apagan
/// solos, siempre lo mismo; los sostenidos ([Instrument.sustained]), lo que
/// se mantuvo más lo que tardan en apagarse (el sintetizador, según
/// [synth]).
Duration toneLength(
  Instrument instrument,
  Duration held, {
  SynthPatch synth = const SynthPatch(),
}) => switch (instrument) {
  Instrument.piano => pianoToneLength,
  Instrument.guitar => const Duration(milliseconds: 2000),
  Instrument.marimba => const Duration(milliseconds: 1200),
  Instrument.organ => _heldOf(held) + _organRelease,
  Instrument.synth => _heldOf(held) + synth.release,
};

/// Volumen de cada instrumento respecto al piano, para que suenen parecido
/// de fuertes (los sostenidos suenan más con el mismo pico).
double toneLevel(Instrument instrument) => switch (instrument) {
  Instrument.piano => 1,
  Instrument.guitar => 1,
  Instrument.marimba => 0.9,
  Instrument.organ => 0.55,
  Instrument.synth => 0.5,
};

/// Lo que se mantienen como poco las notas sostenidas, para que se oigan.
const _minHeld = Duration(milliseconds: 60);

Duration _heldOf(Duration held) => held < _minHeld ? _minHeld : held;

const _organRelease = Duration(milliseconds: 80);

/// Sonido de la tecla [midi] con [instrument], mantenida [held] (solo
/// cuenta en los sostenidos) y, con el sintetizador, con el sonido de
/// [synth]: muestras entre −1 y 1, con el pico en 1.
///
/// Todos son sintetizados, sin muestras grabadas: dan la nota con un timbre
/// que recuerda al instrumento.
Float32List instrumentTone(
  Instrument instrument,
  int midi, {
  Duration held = Duration.zero,
  SynthPatch synth = const SynthPatch(),
  int sampleRate = 44100,
}) {
  final duration = toneLength(instrument, held, synth: synth);
  final frames = PcmFormat(
    sampleRate: sampleRate,
    channels: 1,
  ).framesIn(duration);
  final heldFrames = (sampleRate * _heldOf(held).inMicroseconds / 1e6).round();
  final tone = switch (instrument) {
    Instrument.piano => pianoTone(
      midi,
      sampleRate: sampleRate,
      duration: duration,
    ),
    Instrument.organ => _organ(midi, sampleRate, frames, heldFrames),
    Instrument.guitar => _guitar(midi, sampleRate, frames),
    Instrument.marimba => _marimba(midi, sampleRate, frames),
    Instrument.synth => _synth(midi, sampleRate, frames, heldFrames, synth),
  };
  return _normalized(tone);
}

/// Sonido de [instrumentTone] como WAV mono de 16 bits, con el volumen del
/// instrumento ([toneLevel]).
Uint8List instrumentToneWav(
  Instrument instrument,
  int midi, {
  Duration held = Duration.zero,
  SynthPatch synth = const SynthPatch(),
  int sampleRate = 44100,
}) {
  final tone = instrumentTone(
    instrument,
    midi,
    held: held,
    synth: synth,
    sampleRate: sampleRate,
  );
  return toneWav(tone, sampleRate: sampleRate, gain: toneLevel(instrument));
}

/// Órgano: armónicos que no se apagan mientras se mantiene la tecla, como
/// los tiradores de un órgano Hammond.
Float32List _organ(int midi, int sampleRate, int frames, int heldFrames) {
  const drawbars = [
    (1, 1.0),
    (2, 0.75),
    (3, 0.5),
    (4, 0.5),
    (6, 0.3),
    (8, 0.3),
  ];
  final frequency = PianoKeys.frequency(midi);
  final steps = [
    for (final (n, amplitude) in drawbars)
      if (frequency * n < sampleRate / 2.2)
        (2 * math.pi * frequency * n / sampleRate, amplitude),
  ];
  final tone = Float32List(frames);
  final attack = sampleRate * 0.008;
  final release = math.max(1, frames - heldFrames);
  for (var i = 0; i < frames; i++) {
    var value = 0.0;
    for (final (step, amplitude) in steps) {
      value += amplitude * math.sin(step * i);
    }
    final envelope =
        math.min(1.0, i / attack) *
        (i < heldFrames ? 1.0 : 1 - (i - heldFrames) / release);
    tone[i] = value * envelope;
  }
  return tone;
}

/// Guitarra de nailon: una cuerda pulsada (Karplus-Strong), un ruido que se
/// repite cada periodo de la nota y se suaviza cada vez, de modo que los
/// agudos se apagan antes.
Float32List _guitar(int midi, int sampleRate, int frames) {
  final frequency = PianoKeys.frequency(midi);
  final period = sampleRate / frequency;
  // El promedio de dos muestras retrasa media muestra: se descuenta para
  // que la nota quede afinada.
  final delay = period - 0.5;
  // Pérdida en cada vuelta para que se apague en unos 3 segundos.
  final loss = math.pow(10, -3 / (3.0 * frequency)).toDouble();
  final tone = Float32List(frames);

  // El ruido inicial, suavizado (cuerdas de nailon, pulsadas con el dedo) y
  // sin componente continua. Siempre el mismo para cada tecla.
  final random = math.Random(midi);
  final start = math.min(frames, period.ceil() + 1);
  var smooth = 0.0;
  for (var i = 0; i < start; i++) {
    smooth += 0.5 * (random.nextDouble() * 2 - 1 - smooth);
    tone[i] = smooth;
  }
  var mean = 0.0;
  for (var i = 0; i < start; i++) {
    mean += tone[i];
  }
  mean /= start;
  for (var i = 0; i < start; i++) {
    tone[i] -= mean;
  }

  double at(double position) {
    final index = position.floor();
    final fraction = position - index;
    return tone[index] * (1 - fraction) + tone[index + 1] * fraction;
  }

  for (var i = start; i < frames; i++) {
    final back = i - delay;
    tone[i] = loss * 0.5 * (at(back) + at(back - 1));
  }
  _fadeEdges(tone, sampleRate, attackSeconds: 0.002, releaseSeconds: 0.05);
  return tone;
}

/// Marimba: una láminas de madera golpeadas, con la fundamental y dos
/// parciales (a 4 y a 10 veces) que se apagan muy deprisa.
Float32List _marimba(int midi, int sampleRate, int frames) {
  final frequency = PianoKeys.frequency(midi);
  final decay = 2.5 + frequency / 300;
  final partials = [
    for (final (ratio, amplitude, decayFactor) in const [
      (1.0, 1.0, 1.0),
      (4.0, 0.35, 3.5),
      (10.0, 0.12, 8.0),
    ])
      if (frequency * ratio < sampleRate / 2.2)
        (
          2 * math.pi * frequency * ratio / sampleRate,
          amplitude,
          decay * decayFactor,
        ),
  ];
  final tone = Float32List(frames);
  for (var i = 0; i < frames; i++) {
    final t = i / sampleRate;
    var value = 0.0;
    for (final (step, amplitude, partialDecay) in partials) {
      value += amplitude * math.exp(-partialDecay * t) * math.sin(step * i);
    }
    tone[i] = value;
  }
  _fadeEdges(tone, sampleRate, attackSeconds: 0.0015, releaseSeconds: 0.05);
  return tone;
}

/// Sintetizador: dos osciladores con la onda de [patch], desafinados entre
/// sí, por un filtro paso bajo que se abre al pulsar y se va cerrando, con
/// una envolvente de ataque, caída, sostenido y relajación.
Float32List _synth(
  int midi,
  int sampleRate,
  int frames,
  int heldFrames,
  SynthPatch patch,
) {
  final frequency = PianoKeys.frequency(midi);
  final detune = math.pow(2, patch.detune / 2 / 1200).toDouble();
  final steps = [
    frequency * detune / sampleRate,
    frequency / detune / sampleRate,
  ];
  final phases = [0.0, 0.37];
  double framesOf(Duration time) =>
      math.max(1, sampleRate * time.inMicroseconds / 1e6);
  final attack = framesOf(patch.attack);
  final decay = framesOf(patch.decay);
  final sustain = patch.sustain;
  final release = math.max(1, frames - heldFrames);
  // El filtro: la frecuencia de corte, en veces la de la nota, se abre al
  // doble al pulsar y baja a la del brillo; la resonancia, menos
  // amortiguación (sin llegar a oscilar sola).
  final cutoffTimes = 1 + patch.brightness * 15;
  final damping = 2 - 1.8 * patch.resonance;
  final maxCutoff = sampleRate / 7;

  final tone = Float32List(frames);
  var low = 0.0;
  var band = 0.0;
  var releasedAt = 0.0;
  for (var i = 0; i < frames; i++) {
    var value = 0.0;
    for (var o = 0; o < 2; o++) {
      final step = steps[o];
      var phase = phases[o];
      value += _oscillator(patch.wave, phase, step);
      phase += step;
      if (phase >= 1) phase -= 1;
      phases[o] = phase;
    }
    value /= 2;

    // Filtro de estado variable (Chamberlin).
    final opening = 1 + math.exp(-i / (attack + decay));
    final cutoff = math.min(maxCutoff, frequency * cutoffTimes * opening);
    final f = 2 * math.sin(math.pi * cutoff / sampleRate);
    low += f * band;
    final high = value - low - damping * band;
    band += f * high;

    double envelope;
    if (i < heldFrames) {
      envelope = i < attack
          ? i / attack
          : sustain + (1 - sustain) * math.exp(-(i - attack) / decay);
      releasedAt = envelope;
    } else {
      envelope = releasedAt * (1 - (i - heldFrames) / release);
    }
    tone[i] = low * envelope;
  }
  // Sin chasquido al empezar aunque el ataque sea muy corto.
  _fadeEdges(tone, sampleRate, attackSeconds: 0.002, releaseSeconds: 0.002);
  return tone;
}

/// Una muestra de la onda [wave] en la fase [phase] (de 0 a 1), que avanza
/// [step] por muestra.
double _oscillator(SynthWave wave, double phase, double step) => switch (wave) {
  SynthWave.saw => 2 * phase - 1 - _polyBlep(phase, step),
  SynthWave.square =>
    (phase < 0.5 ? 1.0 : -1.0) +
        _polyBlep(phase, step) -
        _polyBlep((phase + 0.5) % 1, step),
  SynthWave.triangle => 1 - 4 * (phase - 0.5).abs(),
  SynthWave.sine => math.sin(2 * math.pi * phase),
};

/// Corrección PolyBLEP del salto de una onda de sierra, para que no suene
/// áspera por encima de la frecuencia de Nyquist.
double _polyBlep(double phase, double step) {
  if (phase < step) {
    final t = phase / step;
    return t + t - t * t - 1;
  }
  if (phase > 1 - step) {
    final t = (phase - 1) / step;
    return t * t + t + t + 1;
  }
  return 0;
}

/// Sube el principio y baja el final de [tone], para que no chasquee.
void _fadeEdges(
  Float32List tone,
  int sampleRate, {
  required double attackSeconds,
  required double releaseSeconds,
}) {
  final attack = sampleRate * attackSeconds;
  final release = sampleRate * releaseSeconds;
  for (var i = 0; i < tone.length; i++) {
    tone[i] *=
        math.min(1.0, i / attack) *
        math.min(1.0, (tone.length - 1 - i) / release);
  }
}

/// [tone] con el pico en 1.
Float32List _normalized(Float32List tone) {
  var peak = 0.0;
  for (final value in tone) {
    peak = math.max(peak, value.abs());
  }
  if (peak > 0) {
    for (var i = 0; i < tone.length; i++) {
      tone[i] /= peak;
    }
  }
  return tone;
}
