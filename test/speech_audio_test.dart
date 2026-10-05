import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/speech_audio.dart';

import 'wav_helpers.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('speech_audio_test');
  });

  tearDown(() => directory.delete(recursive: true));

  String output() => p.join(directory.path, 'speech.wav');

  group('conversión a 16 kHz y un canal', () {
    test('reduce la frecuencia y mezcla los canales', () async {
      // Un segundo a 44,1 kHz en estéreo: un canal a 1000 y otro a 3000.
      final input = await writeWav(
        directory,
        'in.wav',
        [
          for (var i = 0; i < 44100; i++) ...[1000, 3000],
        ],
        sampleRate: 44100,
        channels: 2,
      );

      final speech = await convertToSpeechAudio(input, output());

      expect(speech.info.format, speechFormat);
      expect(speech.info.frameCount, closeTo(16000, 1));
      expect(speech.duration.inMilliseconds, closeTo(1000, 1));
      final samples = await readSamples(speech.path);
      expect(samples.every((s) => s == 2000), isTrue);
      // Diez bloques de 100 ms.
      expect(speech.energies, hasLength(10));
      expect(speech.energies.first, closeTo(math.pow(2000 / 32768, 2), 1e-9));
    });

    test('aumenta la frecuencia interpolando', () async {
      final input = await writeWav(directory, 'in.wav', [
        0,
        1000,
        2000,
        3000,
      ], sampleRate: 8000);

      final speech = await convertToSpeechAudio(input, output());

      expect(await readSamples(speech.path), [
        0,
        500,
        1000,
        1500,
        2000,
        2500,
        3000,
      ]);
    });

    test('a 16 kHz y un canal, copia las muestras', () async {
      final input = await writeWav(directory, 'in.wav', [
        5,
        -5,
        7,
      ], sampleRate: 16000);

      final speech = await convertToSpeechAudio(input, output());

      expect(await readSamples(speech.path), [5, -5, 7]);
    });
  });

  group('división en tramos', () {
    const second = speechSampleRate;

    test('un audio corto va entero', () {
      expect(
        planSpeechChunks(
          List.filled(300, 0.5),
          30 * second,
          maxLength: const Duration(minutes: 1),
        ),
        [(start: 0, end: 30 * second)],
      );
    });

    test('corta en el silencio más cercano antes del límite', () {
      // 150 s con voz, salvo un silencio a los 52,3 s y otro a los 20 s
      // (fuera de la ventana de búsqueda).
      final energies = List.filled(1500, 0.5);
      energies[523] = 0.001;
      energies[200] = 0;

      final chunks = planSpeechChunks(
        energies,
        150 * second,
        maxLength: const Duration(seconds: 55),
      );

      const firstCut = 523 * speechBlockFrames + speechBlockFrames ~/ 2;
      expect(chunks.first, (start: 0, end: firstCut));
      expect(chunks.last.end, 150 * second);
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].start, chunks[i - 1].end);
        expect(chunks[i].end - chunks[i].start, lessThanOrEqualTo(55 * second));
      }
    });

    test('sin silencios, corta igualmente dentro del límite', () {
      final chunks = planSpeechChunks(
        List.filled(1200, 0.5),
        120 * second,
        maxLength: const Duration(seconds: 55),
      );

      expect(chunks, hasLength(3));
      expect(chunks.every((c) => c.end - c.start <= 55 * second), isTrue);
    });
  });

  test('lee las muestras de un tramo entre -1 y 1', () async {
    final input = await writeWav(directory, 'in.wav', [
      0,
      16384,
      -32768,
      8192,
    ], sampleRate: 16000);
    final speech = await convertToSpeechAudio(input, output());

    final samples = await readSpeechSamples(
      speech.path,
      speech.info,
      start: 1,
      end: 3,
    );

    expect(samples, [0.5, -1.0]);
  });

  test('copia un tramo a otro WAV', () async {
    final input = await writeWav(directory, 'in.wav', [
      1,
      2,
      3,
      4,
    ], sampleRate: 16000);
    final speech = await convertToSpeechAudio(input, output());

    final chunk = p.join(directory.path, 'chunk.wav');
    final info = await writeSpeechChunk(
      speech.path,
      speech.info,
      chunk,
      start: 1,
      end: 3,
    );

    expect(info.frameCount, 2);
    expect(await readSamples(chunk), [2, 3]);
  });
}
