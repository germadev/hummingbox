import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/instrument_tone.dart';
import 'package:voicerecorder/audio/piano_mix.dart';
import 'package:voicerecorder/audio/wav.dart';
import 'package:voicerecorder/models/instrument.dart';
import 'package:voicerecorder/models/piano_note.dart';
import 'package:voicerecorder/models/synth_patch.dart';
import 'package:voicerecorder/widgets/synth_controls.dart';

/// Periodo (en muestras) en el que más se parece [tone] a sí mismo, entre
/// [from] y [to], en la décima de segundo que empieza en [start].
int bestPeriod(Float32List tone, int from, int to, {int start = 2205}) {
  var best = from;
  var bestScore = double.negativeInfinity;
  for (var lag = from; lag <= to; lag++) {
    var score = 0.0;
    for (var i = start; i < start + 4410; i++) {
      score += tone[i] * tone[i + lag];
    }
    if (score > bestScore) {
      bestScore = score;
      best = lag;
    }
  }
  return best;
}

void main() {
  for (final instrument in Instrument.values) {
    group(instrument.name, () {
      final tone = instrumentTone(
        instrument,
        69,
        held: const Duration(milliseconds: 500),
      );

      test('suena a la frecuencia de la tecla', () {
        // La4: 44100 / 440 ≈ 100 muestras por periodo.
        expect(bestPeriod(tone, 70, 140), closeTo(100, 1));
      });

      test('sin saturar, y empieza y termina en silencio', () {
        final peak = tone.map((s) => s.abs()).reduce(math.max);
        expect(peak, closeTo(1, 1e-6));
        expect(tone.first.abs(), lessThan(0.01));
        expect(tone.last.abs(), lessThan(0.01));
      });

      test('dura lo que dice toneLength', () {
        final length = toneLength(
          instrument,
          const Duration(milliseconds: 500),
        );
        expect(tone.length, (44100 * length.inMicroseconds / 1e6).round());
      });
    });
  }

  test('las notas graves y agudas también están afinadas', () {
    for (final instrument in Instrument.values) {
      // La2 (110 Hz, ≈ 401 muestras) y La6 (1760 Hz, ≈ 25 muestras).
      final low = instrumentTone(instrument, 45, held: Duration(seconds: 1));
      expect(bestPeriod(low, 300, 500), closeTo(401, 3), reason: '$instrument');
      final high = instrumentTone(instrument, 93, held: Duration(seconds: 1));
      expect(bestPeriod(high, 20, 32), closeTo(25, 1), reason: '$instrument');
    }
  });

  test('los sostenidos suenan mientras se mantiene la tecla y se apagan al '
      'soltarla; los demás, igual los mantengas lo que los mantengas', () {
    for (final instrument in Instrument.values) {
      final short = toneLength(instrument, const Duration(milliseconds: 200));
      final long = toneLength(instrument, const Duration(seconds: 3));
      if (instrument.sustained) {
        expect(long - short, const Duration(milliseconds: 2800));
        final tone = instrumentTone(
          instrument,
          60,
          held: const Duration(seconds: 3),
        );
        // A los 2,5 s sigue sonando fuerte.
        final at = 44100 * 5 ~/ 2;
        final level = tone
            .sublist(at, at + 2000)
            .map((s) => s.abs())
            .reduce(math.max);
        expect(level, greaterThan(0.4), reason: '$instrument');
      } else {
        expect(long, short, reason: '$instrument');
      }
    }
  });

  test('cada nota suena con su instrumento al mezclar', () {
    const format = PcmFormat(sampleRate: 44100, channels: 1);
    PianoNote note(Instrument instrument) => PianoNote(
      key: 60,
      start: Duration.zero,
      duration: const Duration(milliseconds: 300),
      instrument: instrument,
    );
    Int16List mix(Instrument instrument) {
      final samples = Int16List(44100);
      PianoMixer(format, [note(instrument)], gain: 0.4).addTo(samples, 0);
      return samples;
    }

    final piano = mix(Instrument.piano);
    final organ = mix(Instrument.organ);
    var different = 0;
    for (var i = 0; i < piano.length; i++) {
      if ((piano[i] - organ[i]).abs() > 100) different++;
    }
    expect(different, greaterThan(10000));
    // El órgano deja de sonar poco después de soltarlo (300 + 80 ms).
    expect(organ.sublist(44100 * 400 ~/ 1000).every((s) => s == 0), isTrue);
  });

  group('al mezclar', () {
    const format = PcmFormat(sampleRate: 44100, channels: 1);

    /// Las [notes] mezcladas durante [seconds], en bloques como al escribir
    /// el archivo.
    Int16List mix(List<PianoNote> notes, double seconds) {
      final mixer = PianoMixer(format, notes, gain: pianoOnlyGain);
      final samples = Int16List((44100 * seconds).round());
      for (var frame = 0; frame < samples.length; frame += 32768) {
        final block = Int16List(math.min(32768, samples.length - frame));
        mixer.addTo(block, frame);
        samples.setRange(frame, frame + block.length, block);
      }
      return samples;
    }

    PianoNote note(int key, int startMs) => PianoNote(
      key: key,
      start: Duration(milliseconds: startMs),
      duration: const Duration(milliseconds: 100),
    );

    test('muchas notas a la vez no saturan (no suenan con ruido)', () {
      final samples = mix([
        // Notas rápidas, que se solapan mientras se apagan.
        for (var i = 0; i < 24; i++) note(60 + i % 12, i * 100),
        // Y acordes.
        for (var i = 0; i < 4; i++)
          for (final key in [48, 52, 55, 60]) note(key, 2500 + i * 300),
      ], 5);
      final peak = samples.map((s) => s.abs()).reduce(math.max);
      expect(peak, lessThanOrEqualTo(PianoMixer.ceiling * 32767 + 1));
      expect(peak, greaterThan(0.8 * 32767));
      // Sin saltos bruscos de volumen: como mucho los de la propia onda.
      var jump = 0;
      for (var i = 1; i < samples.length; i++) {
        jump = math.max(jump, (samples[i] - samples[i - 1]).abs());
      }
      expect(jump, lessThan(8000));
    });

    test('una nota sola suena igual que antes, sin limitar', () {
      final samples = mix([note(69, 0)], 1);
      final tone = instrumentTone(Instrument.piano, 69);
      for (final i in [100, 4410, 22050]) {
        expect(samples[i], closeTo(tone[i] * pianoOnlyGain * 32767, 1));
      }
    });

    test('al volver a tocar una tecla, la nota anterior se apaga', () {
      // Sola, la primera sigue sonando a los 0,5 s; con la tecla tocada de
      // nuevo a los 0,3 s, solo suena la segunda (que va 0,3 s por detrás).
      final once = mix([note(60, 0)], 1);
      final twice = mix([note(60, 0), note(60, 300)], 1);
      final second = mix([note(60, 300)], 1);
      final at = 44100 * 500 ~/ 1000;
      expect(once[at], isNot(0));
      for (var i = at; i < at + 100; i++) {
        expect(twice[i], closeTo(second[i], 1));
      }
    });
  });

  group('sintetizador', () {
    test('todas las ondas suenan afinadas y sin saturar', () {
      for (final wave in SynthWave.values) {
        final tone = instrumentTone(
          Instrument.synth,
          69,
          held: const Duration(milliseconds: 500),
          synth: SynthPatch(wave: wave),
        );
        expect(bestPeriod(tone, 70, 140), closeTo(100, 1), reason: '$wave');
        expect(tone.map((s) => s.abs()).reduce(math.max), closeTo(1, 1e-6));
      }
    });

    test('la relajación alarga la nota, y cada parámetro cambia el sonido', () {
      const held = Duration(milliseconds: 400);
      expect(
        toneLength(
          Instrument.synth,
          held,
          synth: const SynthPatch(release: Duration(seconds: 2)),
        ),
        const Duration(milliseconds: 2400),
      );
      final base = instrumentTone(Instrument.synth, 60, held: held);
      for (final patch in const [
        SynthPatch(wave: SynthWave.square),
        SynthPatch(attack: Duration(milliseconds: 300)),
        SynthPatch(decay: Duration(seconds: 1), sustain: 0.2),
        SynthPatch(brightness: 1),
        SynthPatch(resonance: 1),
        SynthPatch(detune: 40),
      ]) {
        final tone = instrumentTone(
          Instrument.synth,
          60,
          held: held,
          synth: patch,
        );
        var difference = 0.0;
        for (var i = 0; i < math.min(base.length, tone.length); i++) {
          difference += (base[i] - tone[i]).abs();
        }
        expect(difference / base.length, greaterThan(0.01), reason: patch.id);
      }
    });

    test('con un ataque largo, empieza flojo', () {
      final tone = instrumentTone(
        Instrument.synth,
        60,
        held: const Duration(seconds: 1),
        synth: const SynthPatch(attack: Duration(seconds: 1)),
      );
      double levelAt(double seconds) {
        final at = (44100 * seconds).round();
        return tone.sublist(at, at + 1000).map((s) => s.abs()).reduce(math.max);
      }

      expect(levelAt(0.1), lessThan(levelAt(0.9) / 3));
    });

    test('al mezclar, cada nota con el sonido que tenía', () {
      const format = PcmFormat(sampleRate: 44100, channels: 1);
      Int16List mix(SynthPatch patch) {
        final samples = Int16List(44100);
        PianoMixer(format, [
          PianoNote(
            key: 60,
            start: Duration.zero,
            duration: const Duration(milliseconds: 200),
            instrument: Instrument.synth,
            synth: patch,
          ),
        ], gain: 0.4).addTo(samples, 0);
        return samples;
      }

      // Con una relajación larga, sigue sonando a los 0,6 s.
      expect(mix(const SynthPatch())[26460], 0);
      expect(
        mix(const SynthPatch(release: Duration(seconds: 2)))
            .sublist(26460, 27460)
            .any((s) => s != 0),
        isTrue,
      );
    });

    test('en los ajustes: se guarda, y lo que se sale de los límites, al '
        'límite', () {
      const patch = SynthPatch(
        wave: SynthWave.triangle,
        attack: Duration(milliseconds: 120),
        decay: Duration(milliseconds: 900),
        sustain: 0.4,
        release: Duration(seconds: 1),
        brightness: 0.8,
        resonance: 0.6,
        detune: 20,
      );
      expect(SynthPatch.fromJson(patch.toJson()), patch);
      expect(
        SynthPatch.fromJson({
          'wave': 'noise',
          'attack': 999999,
          'sustain': 7,
          'detune': -3,
        }),
        SynthPatch(attack: SynthPatch.maxAttack, sustain: 1, detune: 0),
      );
      expect(SynthPatch.fromJson('x'), const SynthPatch());
      expect(patch.id, isNot(const SynthPatch().id));
    });
  });

  test('las ruedas: cada parámetro va y vuelve de su posición', () {
    const patch = SynthPatch(
      wave: SynthWave.triangle,
      attack: Duration(milliseconds: 500),
      sustain: 0.4,
      detune: 20,
    );
    for (final parameter in SynthParameter.values) {
      final position = parameter.positionIn(patch);
      expect(position, inInclusiveRange(0, 1), reason: parameter.name);
      expect(parameter.apply(patch, position), patch, reason: parameter.name);
      // En los extremos, los límites.
      expect(parameter.positionIn(parameter.apply(patch, 1)), 1);
      expect(parameter.positionIn(parameter.apply(patch, 0)), 0);
    }
    // Cada parámetro, en una sola pareja.
    expect({
      for (final (x, y) in SynthParameter.pairs) ...[x, y],
    }, SynthParameter.values.toSet());
  });
}
