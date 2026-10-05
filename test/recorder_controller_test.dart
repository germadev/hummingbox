import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/controllers/recorder_controller.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/audio_recorder_service.dart';
import 'package:voicerecorder/services/recordings_repository.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FakeAudioRecorderService recorder;
  late RecorderController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recorder_test');
    recorder = FakeAudioRecorderService(writeFiles: true);
    controller = RecorderController(
      recorder: recorder,
      repository: FileRecordingsRepository(directory: () async => directory),
      maxAmplitudeSamples: 3,
    );
  });

  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });

  /// Deja que se entreguen los eventos pendientes de los streams.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('no graba sin permiso del micrófono', () async {
    recorder.permissionGranted = false;

    expect(await controller.start(), isFalse);
    expect(controller.status, RecorderStatus.idle);
    expect(recorder.calls, ['hasPermission']);
  });

  test('graba, pausa, reanuda y guarda la grabación', () async {
    expect(await controller.start(), isTrue);
    expect(controller.status, RecorderStatus.recording);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await controller.pause();
    expect(controller.status, RecorderStatus.paused);
    final pausedAt = controller.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.elapsed, pausedAt);

    await controller.resume();
    expect(controller.status, RecorderStatus.recording);

    final recording = await controller.stop();
    expect(controller.status, RecorderStatus.idle);
    expect(controller.elapsed, Duration.zero);
    expect(recording, isNotNull);
    expect(recording!.name, 'Grabación 1');
    expect(recording.path, recorder.path);
    expect(File(recording.path).existsSync(), isTrue);
    expect(recording.duration, greaterThanOrEqualTo(pausedAt));
    expect(recorder.calls, [
      'hasPermission',
      'start',
      'pause',
      'resume',
      'stop',
    ]);
  });

  test('graba con el formato y la calidad elegidos', () async {
    const options = RecordingOptions(
      format: RecordingFormat.wav,
      quality: RecordingQuality.low,
    );
    const info = AudioInfo(
      format: RecordingFormat.wav,
      sampleRate: 16000,
      channels: 1,
      bitsPerSample: 16,
    );
    final probed = <String>[];
    final probing = RecorderController(
      recorder: recorder,
      repository: FileRecordingsRepository(directory: () async => directory),
      probe: (path) async {
        probed.add(path);
        return const AudioProbe(info, Duration(milliseconds: 1234));
      },
    );
    addTearDown(probing.dispose);

    await probing.start(options: options);
    final recording = await probing.stop();

    expect(recorder.options, options);
    expect(p.extension(recorder.path!), '.wav');
    expect(probed, [recorder.path]);
    // La duración y el formato salen del archivo.
    expect(recording!.duration, const Duration(milliseconds: 1234));
    expect(recording.audio, info);
  });

  group('al detectar la voz', () {
    late Map<String, Duration> trims;
    late RecorderController voice;

    setUp(() {
      trims = {};
      voice = RecorderController(
        recorder: recorder,
        repository: FileRecordingsRepository(directory: () async => directory),
        trimStart: (path, start) async => trims[path] = start,
      );
    });

    tearDown(() => voice.dispose());

    /// Envía niveles al controlador, uno por cada 100 ms de grabación.
    Future<void> levels(List<double> dbfs) async {
      for (final db in dbfs) {
        recorder.amplitudeController.add(db);
      }
      await flush();
    }

    test('espera grabando y empieza al hablar, con margen previo', () async {
      expect(await voice.startWhenVoice(), isTrue);
      expect(voice.pending, PendingStart.voice);
      expect(voice.status, RecorderStatus.idle);
      expect(voice.isBusy, isTrue);
      // El micrófono ya graba, para tener el audio de antes de la voz.
      expect(recorder.calls, ['hasPermission', 'start']);

      await levels(List.filled(30, -55));
      expect(voice.pending, PendingStart.voice);
      expect(voice.amplitudes, hasLength(30));

      await levels([-25, -25]);
      expect(voice.pending, isNull);
      expect(voice.status, RecorderStatus.recording);
      // Se conserva 1 s antes de la voz: cuenta en el cronómetro.
      expect(voice.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(voice.amplitudes, hasLength(10));

      final recording = await voice.stop();

      // Se detectó a los 3,2 s: se quita todo hasta 1 s antes.
      expect(trims, {recorder.path!: const Duration(milliseconds: 2200)});
      expect(recording!.waveform, isNotNull);
    });

    test('«empezar ya» deja de esperar y conserva el margen', () async {
      await voice.startWhenVoice();
      await levels(List.filled(5, -55));

      await voice.startNow();

      expect(voice.status, RecorderStatus.recording);
      expect(voice.elapsed, greaterThanOrEqualTo(Duration(milliseconds: 500)));
      await voice.stop();
      // Hubo menos espera que el margen: no hay nada que recortar.
      expect(trims, isEmpty);
    });

    test('si no se puede recortar, la duración incluye la espera', () async {
      final untrimmed = RecorderController(
        recorder: recorder,
        repository: FileRecordingsRepository(directory: () async => directory),
        trimStart: (path, start) async => throw Exception('códec'),
      );
      addTearDown(untrimmed.dispose);
      await untrimmed.startWhenVoice();
      await levels([...List.filled(30, -55), -25, -25]);

      final recording = await untrimmed.stop();

      expect(
        recording!.duration,
        greaterThanOrEqualTo(const Duration(milliseconds: 3200)),
      );
    });

    test('cancelar la espera descarta el audio', () async {
      await voice.startWhenVoice();
      final path = recorder.path!;

      await voice.cancel();

      expect(voice.isBusy, isFalse);
      expect(recorder.calls.last, 'cancel');
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('cuenta atrás', () {
    test('cancelarla no graba nada', () async {
      final started = controller.startAfterCountdown(seconds: 3);
      await flush();
      expect(controller.pending, PendingStart.countdown);
      expect(controller.countdown, 3);

      await controller.cancel();

      expect(await started, isTrue);
      expect(controller.isBusy, isFalse);
      expect(recorder.calls, ['hasPermission']);
    });

    test('«empezar ya» graba sin esperar', () async {
      final started = controller.startAfterCountdown(
        seconds: 10,
        options: const RecordingOptions(format: RecordingFormat.wav),
        folder: 'Clases',
      );
      await flush();

      await controller.startNow();

      expect(await started, isTrue);
      expect(controller.status, RecorderStatus.recording);
      expect(recorder.options!.format, RecordingFormat.wav);
      final recording = await controller.stop();
      expect(recording!.folder, 'Clases');
    });

    test('sin permiso no empieza la cuenta', () async {
      recorder.permissionGranted = false;

      expect(await controller.startAfterCountdown(seconds: 3), isFalse);
      expect(controller.pending, isNull);
    });
  });

  test('descartar borra el audio', () async {
    await controller.start();
    final path = recorder.path!;

    await controller.cancel();

    expect(controller.status, RecorderStatus.idle);
    expect(recorder.calls.last, 'cancel');
    expect(File(path).existsSync(), isFalse);
  });

  test('se sincroniza cuando la plataforma pausa o reanuda', () async {
    await controller.start();

    recorder.statusController.add(RecorderStatus.paused);
    await flush();
    expect(controller.status, RecorderStatus.paused);

    recorder.statusController.add(RecorderStatus.recording);
    await flush();
    expect(controller.status, RecorderStatus.recording);
  });

  test('guarda las últimas amplitudes mientras graba', () async {
    await controller.start();

    for (final db in [-50.0, -25.0, 0.0, -10.0]) {
      recorder.amplitudeController.add(db);
    }
    await flush();
    expect(controller.amplitudes, [0.5, 1.0, 0.8]);

    await controller.pause();
    recorder.amplitudeController.add(-40);
    await flush();
    expect(controller.amplitudes, [0.5, 1.0, 0.8]);

    await controller.stop();
    expect(controller.amplitudes, isEmpty);
  });

  test('ignora detener o pausar si no está grabando', () async {
    expect(await controller.stop(), isNull);
    await controller.pause();
    await controller.cancel();

    expect(recorder.calls, isEmpty);
  });

  test('libera el grabador al desecharse', () {
    final service = FakeAudioRecorderService();
    RecorderController(
      recorder: service,
      repository: InMemoryRecordingsRepository(),
    ).dispose();

    expect(service.disposed, isTrue);
  });
}
