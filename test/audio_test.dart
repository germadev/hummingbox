import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_edit.dart';
import 'package:voicerecorder/audio/levels.dart';
import 'package:voicerecorder/audio/wav.dart';

import 'wav_helpers.dart';

void main() {
  group('niveles', () {
    test('convierten dBFS y picos lineales a la misma escala', () {
      expect(levelFromDb(-50), 0);
      expect(levelFromDb(-25), 0.5);
      expect(levelFromDb(0), 1);
      expect(levelFromPeak(1), 1);
      expect(levelFromPeak(0), 0);
      // −25 dBFS ≈ 0,0562 de amplitud.
      expect(levelFromPeak(0.0562), closeTo(0.5, 0.01));
    });

    test('al reducir conservan el pico de cada tramo', () {
      expect(resampleLevels([0.1, 0.9, 0.2, 0.3, 0.5, 0.4], 3), [
        0.9,
        0.3,
        0.5,
      ]);
    });

    test('al ampliar interpolan', () {
      expect(resampleLevels([0, 1], 3), [0, 0.5, 1]);
      expect(resampleLevels([0.4], 2), [0.4, 0.4]);
      expect(resampleLevels([], 2), [0, 0]);
    });

    test('se guardan como enteros y se recuperan', () {
      final encoded = encodeWaveform([0, 0.333, 1]);
      expect(encoded, [0, 33, 100]);
      expect(decodeWaveform(encoded), [0, 0.33, 1]);
      expect(decodeWaveform('no'), isNull);
      expect(decodeWaveform([]), isNull);
    });
  });

  group('WAV', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('wav_test');
    });

    tearDown(() => directory.delete(recursive: true));

    test('escribe y lee las muestras', () async {
      final path = await writeWav(directory, 'a.wav', [0, 1000, -1000, 32767]);

      final info = await readWavInfo(path);
      expect(info.format, const PcmFormat(sampleRate: 1000, channels: 1));
      expect(info.dataOffset, 44);
      expect(info.frameCount, 4);
      expect(info.duration, const Duration(milliseconds: 4));
      expect(await readSamples(path), [0, 1000, -1000, 32767]);
    });

    test('admite bloques extra y WAVE_FORMAT_EXTENSIBLE', () async {
      // Cabecera como la de iOS: fmt extensible de 40 bytes y un bloque
      // FLLR de relleno antes de los datos.
      final bytes = BytesBuilder();
      void fourCC(String id) => bytes.add(id.codeUnits);
      void u32(int value) => bytes.add(
        (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
      );
      void u16(int value) => bytes.add(
        (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List(),
      );

      fourCC('RIFF');
      u32(0);
      fourCC('WAVE');
      fourCC('fmt ');
      u32(40);
      u16(0xFFFE);
      u16(2);
      u32(8000);
      u32(8000 * 4);
      u16(4);
      u16(16);
      u16(22);
      u16(16);
      u32(3);
      u16(1); // Subformato PCM.
      bytes.add(List.filled(14, 0));
      fourCC('FLLR');
      u32(3); // Tamaño impar: lleva un byte de relleno.
      bytes.add([0, 0, 0, 0]);
      fourCC('data');
      u32(0xFFFFFFFF); // Tamaño sin escribir.
      bytes.add(Int16List.fromList([1, 2, 3, 4]).buffer.asUint8List());
      final path = p.join(directory.path, 'ios.wav');
      await File(path).writeAsBytes(bytes.takeBytes());

      final info = await readWavInfo(path);
      expect(info.format, const PcmFormat(sampleRate: 8000, channels: 2));
      expect(info.frameCount, 2);
      expect(await readSamples(path), [1, 2, 3, 4]);
    });

    test('rechaza lo que no es un WAV PCM de 16 bits', () async {
      final path = p.join(directory.path, 'x.wav');
      await File(path).writeAsString('no es audio');
      expect(readWavInfo(path), throwsFormatException);
    });
  });

  group('edición', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('edit_test');
    });

    tearDown(() => directory.delete(recursive: true));

    Future<(WavAnalysis, List<int>)> process(
      List<int> samples,
      AudioEdit edit, {
      int buckets = 4,
    }) async {
      final input = await writeWav(directory, 'in.wav', samples);
      final output = p.join(directory.path, 'out.wav');
      final analysis = await processWav(
        input: input,
        output: output,
        edit: edit,
        buckets: buckets,
      );
      return (analysis, await readSamples(output));
    }

    test('recorta la selección', () async {
      // 1000 Hz: cada muestra dura 1 ms.
      final (analysis, samples) = await process(
        [for (var i = 0; i < 10; i++) i * 100],
        const AudioEdit(
          start: Duration(milliseconds: 2),
          end: Duration(milliseconds: 6),
        ),
      );
      expect(samples, [200, 300, 400, 500]);
      expect(analysis.duration, const Duration(milliseconds: 4));
      expect(analysis.peaks, [
        200 / 32768,
        300 / 32768,
        400 / 32768,
        500 / 32768,
      ]);
    });

    test('aplica la ganancia y recorta lo que se sale de rango', () async {
      final (_, louder) = await process(
        [1000, -1000, 20000, -20000],
        const AudioEdit(
          start: Duration.zero,
          end: Duration(milliseconds: 4),
          gainDb: 6.0206, // ×2
        ),
      );
      expect(louder, [2000, -2000, 32767, -32768]);

      final (_, quieter) = await process(
        [1000, -1000],
        const AudioEdit(
          start: Duration.zero,
          end: Duration(milliseconds: 2),
          gainDb: -6.0206, // ×0,5
        ),
      );
      expect(quieter, [500, -500]);
    });

    test('aplica los fundidos de entrada y salida', () async {
      final (_, samples) = await process(
        List.filled(8, 1000),
        const AudioEdit(
          start: Duration.zero,
          end: Duration(milliseconds: 8),
          fadeIn: Duration(milliseconds: 4),
          fadeOut: Duration(milliseconds: 2),
        ),
      );
      expect(samples, [0, 250, 500, 750, 1000, 1000, 500, 0]);
    });

    test(
      'procesa por bloques sin cambiar el audio si no hay cambios',
      () async {
        final original = [for (var i = 0; i < 70000; i++) (i % 2000) - 1000];
        final input = await writeWav(directory, 'long.wav', original);
        final output = p.join(directory.path, 'long_out.wav');
        final analysis = await processWav(
          input: input,
          output: output,
          edit: const AudioEdit(
            start: Duration.zero,
            end: Duration(seconds: 70),
          ),
        );
        expect(await readSamples(output), original);
        expect(analysis.peaks, hasLength(waveformResolution));
      },
    );

    test('analiza los picos por tramos', () async {
      final path = await writeWav(directory, 'peaks.wav', [
        100, -200, // Tramo 1
        3000, 10, // Tramo 2
        0, 0, // Tramo 3
        -32768, 5, // Tramo 4
      ]);
      final analysis = await analyzeWav(path, buckets: 4);
      expect(analysis.duration, const Duration(milliseconds: 8));
      expect(analysis.peaks, [200 / 32768, 3000 / 32768, 0, 1]);
      expect(analysis.peak, 1);
      expect(
        analysis.peakBetween(
          const Duration(milliseconds: 1),
          const Duration(milliseconds: 5),
        ),
        3000 / 32768,
      );
      expect(analysis.levels.last, 1);
    });

    test('convierte entre decibelios y ganancia', () {
      expect(gainFromDb(0), 1);
      expect(gainFromDb(20), closeTo(10, 1e-9));
      expect(dbFromGain(0.5), closeTo(-6.0206, 1e-4));
      expect(
        const AudioEdit(
          start: Duration.zero,
          end: Duration(seconds: 3),
        ).changes(const Duration(seconds: 3)),
        isFalse,
      );
      expect(
        const AudioEdit(
          start: Duration.zero,
          end: Duration(seconds: 3),
          gainDb: 1,
        ).changes(const Duration(seconds: 3)),
        isTrue,
      );
    });
  });
}
