import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/instrument_tone.dart';
import 'package:voicerecorder/audio/piano_tone.dart';
import 'package:voicerecorder/audio/piano_headroom.dart';
import 'package:voicerecorder/audio/wav.dart';
import 'package:voicerecorder/models/instrument.dart';

void main() {
  const sampleRate = 44100;

  /// Las muestras (de −1 a 1) y la envolvente del archivo de una tecla, como
  /// las que suenan al tocar el piano.
  final tones = <(Instrument, int), (Float32List, ToneEnvelope)>{};
  (Float32List, ToneEnvelope) toneOf(Instrument instrument, int key) =>
      tones[(instrument, key)] ??= () {
        final wav = instrumentToneWav(
          instrument,
          key,
          held: const Duration(seconds: 5),
        );
        final data = ByteData.sublistView(wav);
        const header = 44;
        final samples = Float32List((wav.length - header) ~/ 2);
        for (var i = 0; i < samples.length; i++) {
          samples[i] = data.getInt16(header + 2 * i, Endian.little) / 32768;
        }
        return (samples, ToneEnvelope.ofWav(wav));
      }();

  Duration at(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

  /// El pico de lo que suenan juntas las notas [notes] (tecla y cuándo se
  /// toca) con [instrument], como al tocar el piano: cada una con su
  /// reproductor, que el sistema suma, y al volver a tocar una tecla la nota
  /// anterior se corta. Con [limit], el volumen de todas es el de
  /// [PianoHeadroom], que se recalcula al tocar cada una y cada 40 ms y se
  /// mantiene hasta el siguiente cálculo.
  double peakOf(
    Instrument instrument,
    List<(int, double)> notes, {
    required bool limit,
  }) {
    const step = Duration(milliseconds: 40);
    const length = Duration(seconds: 4);
    final headroom = PianoHeadroom();
    final frames = sampleRate * length.inSeconds;
    final gains = Float32List(frames)..fillRange(0, frames, 1);
    // Cuándo se recalcula el volumen: al tocar cada nota y cada 40 ms.
    final events = <(Duration, int?)>[
      for (var t = Duration.zero; t < length; t += step) (t, null),
      for (final (key, start) in notes) (at(start), key),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (limit) {
      for (var i = 0; i < events.length; i++) {
        final (time, key) = events[i];
        if (key != null) {
          headroom.start(key, toneOf(instrument, key).$2, time);
        } else {
          headroom.update(time);
        }
        final from = (time.inMicroseconds * sampleRate / 1e6).round();
        gains.fillRange(from, frames, headroom.gain);
      }
    }
    final mix = Float32List(frames);
    for (var n = 0; n < notes.length; n++) {
      final (key, start) = notes[n];
      final samples = toneOf(instrument, key).$1;
      final from = (start * sampleRate).round();
      // Hasta que se vuelve a tocar su tecla.
      final next = notes
          .skip(n + 1)
          .where((note) => note.$1 == key)
          .map((note) => (note.$2 * sampleRate).round())
          .firstOrNull;
      final to = math.min(
        frames,
        math.min(from + samples.length, next ?? frames),
      );
      for (var i = from; i < to; i++) {
        mix[i] += samples[i - from] * gains[i];
      }
    }
    var peak = 0.0;
    for (final value in mix) {
      peak = math.max(peak, value.abs());
    }
    return peak;
  }

  final chord = [(60, 0.0), (64, 0.0), (67, 0.0)];
  final fast = [
    for (var i = 0; i < 24; i++)
      (60 + const [0, 2, 4, 5, 7, 9, 11, 12][i % 8], i * 0.1),
  ];
  final chordAndMelody = [
    (48, 0.0),
    (52, 0.02),
    (55, 0.04),
    (72, 0.1),
    (74, 0.25),
    (76, 0.4),
    (77, 0.55),
    (79, 0.7),
    (60, 1.0),
    (64, 1.0),
    (67, 1.0),
    (72, 1.0),
  ];
  final sameKey = [for (var i = 0; i < 12; i++) (60, i * 0.08)];

  group('ToneEnvelope', () {
    test('tiene el pico de cada trozo de 10 ms del WAV', () {
      final samples = Int16List(4410)
        ..[0] = 16384
        ..[500] = -32768
        ..[1000] = 100;
      final wav = Uint8List.fromList([
        ...wavHeader(
          const PcmFormat(sampleRate: 44100, channels: 1),
          samples.lengthInBytes,
        ),
        ...samples.buffer.asUint8List(),
      ]);
      final envelope = ToneEnvelope.ofWav(wav);

      expect(envelope.peaks, hasLength(10));
      expect(envelope.length, const Duration(milliseconds: 100));
      expect(envelope.peaks[0], 0.5);
      expect(envelope.peaks[1], 1);
      expect(envelope.peaks[2], closeTo(100 / 32768, 1e-6));
      expect(envelope.peaks[3], 0);
      expect(
        envelope.peakIn(
          const Duration(milliseconds: 20),
          const Duration(milliseconds: 15),
        ),
        closeTo(100 / 32768, 1e-6),
      );
      expect(
        envelope.peakIn(Duration.zero, const Duration(milliseconds: 15)),
        1,
      );
      expect(envelope.peakIn(const Duration(seconds: 1), Duration.zero), 0);
    });

    test('la del sonido de una tecla empieza fuerte y se apaga', () {
      final envelope = toneOf(Instrument.piano, 60).$2;
      expect(
        envelope.peakIn(Duration.zero, const Duration(milliseconds: 50)),
        closeTo(0.7, 0.01),
      );
      expect(
        envelope.length.inMilliseconds,
        closeTo(pianoToneLength.inMilliseconds, 10),
      );
      expect(envelope.peaks.last, lessThan(0.1));
    });
  });

  group('PianoHeadroom', () {
    test('una nota sola suena con todo su volumen', () {
      final headroom = PianoHeadroom()
        ..start(60, toneOf(Instrument.piano, 60).$2, Duration.zero);
      expect(headroom.gain, 1);
      expect(headroom.volumeOf(60), 1);
      expect(
        peakOf(Instrument.piano, [(60, 0)], limit: true),
        closeTo(0.7, 1e-3),
      );
    });

    test('con un acorde, el volumen de todas baja lo justo enseguida', () {
      final headroom = PianoHeadroom();
      for (final (key, _) in chord) {
        headroom.start(key, toneOf(Instrument.piano, key).$2, Duration.zero);
      }
      // Los tres picos suman unos 2,1.
      expect(headroom.gain, closeTo(PianoHeadroom.ceiling / 2.1, 0.03));
      expect(headroom.volumeOf(64), headroom.gain);
    });

    test('vuelve poco a poco a medida que se apagan, y del todo al '
        'terminar', () {
      final headroom = PianoHeadroom();
      for (final (key, _) in chord) {
        headroom.start(key, toneOf(Instrument.piano, key).$2, Duration.zero);
      }
      var previous = headroom.gain;
      for (var ms = 40; ms <= 1600; ms += 40) {
        final gain = headroom.update(Duration(milliseconds: ms));
        expect(gain, greaterThanOrEqualTo(previous - 1e-9));
        // Nunca más de lo que cabe en 40 ms de [PianoHeadroom.recovery].
        expect(gain - previous, lessThanOrEqualTo(40 / 400 + 1e-9));
        previous = gain;
      }
      expect(headroom.isEmpty, isTrue);
      expect(headroom.update(const Duration(seconds: 2)), 1);
    });

    test('una nota que se apaga cuenta menos, y la que termina nada', () {
      final headroom = PianoHeadroom();
      for (final (key, _) in chord) {
        headroom.start(key, toneOf(Instrument.piano, key).$2, Duration.zero);
      }
      final all = headroom.gain;
      headroom.fade(60, 0.1);
      expect(
        headroom.update(const Duration(milliseconds: 10)),
        greaterThan(all),
      );
      expect(headroom.volumeOf(60), closeTo(0.1 * headroom.gain, 1e-9));
      headroom.end(60);
      expect(headroom.keys, unorderedEquals([64, 67]));
    });

    test('volver a tocar una tecla sustituye a la nota anterior', () {
      final headroom = PianoHeadroom();
      final envelope = toneOf(Instrument.piano, 60).$2;
      headroom
        ..start(60, envelope, Duration.zero)
        ..start(60, envelope, const Duration(milliseconds: 50));
      expect(headroom.keys, [60]);
      expect(headroom.gain, 1);
    });

    for (final instrument in [
      Instrument.piano,
      Instrument.guitar,
      Instrument.marimba,
      Instrument.organ,
      Instrument.synth,
    ]) {
      test('con ${instrument.name}, acordes y notas rápidas no pasan del '
          'máximo (sin el limitador se pasaban)', () {
        for (final notes in [chord, fast, chordAndMelody, sameKey]) {
          final peak = peakOf(instrument, notes, limit: true);
          expect(peak, lessThanOrEqualTo(PianoHeadroom.ceiling + 1e-3));
        }
        expect(
          peakOf(instrument, chordAndMelody, limit: false),
          greaterThan(1),
        );
      });
    }
  });
}
