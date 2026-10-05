import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/piano_tone.dart';
import 'package:voicerecorder/widgets/piano.dart';

void main() {
  group('teclas', () {
    test('88 teclas, 52 blancas, de La0 a Do8', () {
      expect(PianoKeys.whiteKeys, hasLength(52));
      expect(PianoKeys.whiteKeys.first, 21);
      expect(PianoKeys.whiteKeys.last, 108);
    });

    test('el La4 está a 440 Hz y el Do4 es el central', () {
      expect(PianoKeys.frequency(69), 440);
      expect(PianoKeys.frequency(81), closeTo(880, 1e-9));
      expect(PianoKeys.octave(60), 4);
    });

    test('nombres de las notas, en solfeo o con letras', () {
      final solfeo = noteNames('Do Re Mi Fa Sol La Si');
      expect(noteName(69, solfeo), 'La4');
      expect(noteName(61, solfeo), 'Do♯4');
      expect(noteName(21, noteNames('C D E F G A B')), 'A0');
      // Si la traducción no tiene siete, con letras.
      expect(noteName(60, noteNames('Do Re')), 'C4');
    });
  });

  group('sonido', () {
    test('es un WAV mono de 16 bits sin saturar', () {
      final wav = pianoToneWav(69, duration: const Duration(seconds: 1));
      final header = ByteData.sublistView(wav, 0, 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 44100);
      expect(wav.length, 44 + 44100 * 2);

      final samples = Int16List.sublistView(wav, 44);
      final peak = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(peak, inInclusiveRange(20000, 32767));
      // Empieza y termina en silencio, sin chasquidos.
      expect(samples.first, 0);
      expect(samples.last.abs(), lessThan(100));
    });

    test('suena a la frecuencia de la tecla', () {
      final wav = pianoToneWav(69, duration: const Duration(seconds: 1));
      final samples = Int16List.sublistView(wav, 44);
      // Cruces por cero hacia arriba en la primera décima de segundo, donde
      // domina la fundamental.
      var crossings = 0;
      for (var i = 1; i < 4410; i++) {
        if (samples[i - 1] < 0 && samples[i] >= 0) crossings++;
      }
      expect(crossings, closeTo(44, 3));
    });
  });
}
