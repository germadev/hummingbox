import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/recorder_controller.dart';
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
