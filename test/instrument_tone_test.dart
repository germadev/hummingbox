import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/instrument_tone.dart';
import 'package:voicerecorder/audio/piano_mix.dart';
import 'package:voicerecorder/audio/wav.dart';
import 'package:voicerecorder/models/instrument.dart';
import 'package:voicerecorder/models/piano_note.dart';

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
}
