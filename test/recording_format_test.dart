import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/utils/formatters.dart';

import 'mp4_helpers.dart';
import 'wav_helpers.dart';

void main() {
  group('opciones de grabación', () {
    test('por defecto, AAC a 44,1 kHz y 128 kbps, como antes', () {
      const options = RecordingOptions();
      expect(options.format, RecordingFormat.aac);
      expect(options.sampleRate, 44100);
      expect(options.bitRate, 128000);
      expect(options.bytesPerMinute, 960000);
    });

    test('cada calidad fija la frecuencia y, en AAC, la tasa de bits', () {
      const aac = RecordingOptions();
      expect(
        [
          for (final quality in RecordingQuality.values)
            (
              aac.copyWith(quality: quality).sampleRate,
              aac.copyWith(quality: quality).bitRate,
            ),
        ],
        [(16000, 32000), (22050, 64000), (44100, 128000)],
      );

      const wav = RecordingOptions(
        format: RecordingFormat.wav,
        quality: RecordingQuality.low,
      );
      // Sin comprimir: 16 bits por muestra.
      expect(wav.bitRate, 256000);
      expect(wav.bytesPerMinute, 1920000);
    });

    test('se guardan y se recuperan, tolerando valores desconocidos', () {
      const options = RecordingOptions(
        format: RecordingFormat.wav,
        quality: RecordingQuality.medium,
      );
      expect(RecordingOptions.fromJson(options.toJson()), options);
      expect(
        RecordingOptions.fromJson({'format': 'flac', 'quality': 'low'}),
        const RecordingOptions(quality: RecordingQuality.low),
      );
      expect(RecordingOptions.fromJson(null), const RecordingOptions());
    });

    test('el formato se deduce de la extensión', () {
      expect(RecordingFormat.fromPath('/a/b.m4a'), RecordingFormat.aac);
      expect(RecordingFormat.fromPath('/a/B.WAV'), RecordingFormat.wav);
      expect(RecordingFormat.fromPath('/a/b.mp3'), isNull);
    });

    test('se describen con el formato de número español', () {
      expect(formatSampleRate(44100), '44,1 kHz');
      expect(formatSampleRate(22050), '22,05 kHz');
      expect(formatSampleRate(16000), '16 kHz');
      expect(formatBitRate(128000), '128 kbps');
      expect(formatMegabytes(240000), '0,2 MB');
      expect(formatMegabytes(960000), '1 MB');
      expect(
        formatAudioInfo(
          const AudioInfo(
            format: RecordingFormat.wav,
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 24,
          ),
        ),
        'WAV · 24 bits · 48 kHz · estéreo',
      );
    });
  });

  group('lectura de la cabecera', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('probe_test');
    });

    tearDown(() => directory.delete(recursive: true));

    test('WAV: frecuencia, canales, bits y duración', () async {
      final path = await writeWav(
        directory,
        'a.wav',
        List.filled(16000, 0),
        sampleRate: 8000,
        channels: 2,
      );

      final probe = await probeAudio(path);

      expect(
        probe!.info,
        const AudioInfo(
          format: RecordingFormat.wav,
          sampleRate: 8000,
          channels: 2,
          bitsPerSample: 16,
        ),
      );
      expect(probe.duration, const Duration(seconds: 1));
    });

    test('M4A: lee la tasa de bits de la cabecera esds', () async {
      final path = await writeM4a(
        directory,
        'a.m4a',
        sampleRate: 22050,
        timescale: 22050,
        durationUnits: 22050 * 90,
        averageBitRate: 63800,
      );

      final probe = await probeAudio(path);

      expect(
        probe!.info,
        const AudioInfo(
          format: RecordingFormat.aac,
          sampleRate: 22050,
          channels: 1,
          bitRate: 64000,
        ),
      );
      expect(probe.duration, const Duration(seconds: 90));
    });

    test('M4A: sin esds, la estima por el tamaño del audio', () async {
      final path = await writeM4a(
        directory,
        'a.m4a',
        averageBitRate: null,
        durationUnits: 44100 * 2,
        // 2 s a 32 kbps.
        mediaBytes: 8000,
        moovFirst: true,
        longMdhd: true,
      );

      final probe = await probeAudio(path);

      expect(probe!.info.bitRate, 32000);
      expect(probe.duration, const Duration(seconds: 2));
    });

    test('devuelve null si no lo reconoce o no existe', () async {
      final notAudio = p.join(directory.path, 'a.m4a');
      await File(notAudio).writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      expect(await probeAudio(notAudio), isNull);
      expect(await probeAudio(p.join(directory.path, 'no.wav')), isNull);
      expect(await probeAudio(p.join(directory.path, 'a.mp3')), isNull);
    });

    test('redondea la tasa de bits a la habitual más cercana', () {
      expect(roundBitRate(127400), 128000);
      expect(roundBitRate(33100), 32000);
      expect(roundBitRate(110000), 110000);
    });
  });
}
