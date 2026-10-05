import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/whisper_controller.dart';
import 'package:voicerecorder/models/transcription.dart';

import 'fakes.dart';

void main() {
  late FakeWhisperService service;
  late WhisperController controller;

  setUp(() {
    service = FakeWhisperService();
    controller = WhisperController(service);
  });

  tearDown(() => controller.dispose());

  test('lee qué modelo hay instalado', () async {
    service.installed = WhisperModel.tiny;

    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.installed, WhisperModel.tiny);
  });

  test('descarga un modelo mostrando el progreso', () async {
    final install = controller.install(WhisperModel.base);
    expect(controller.downloading, WhisperModel.base);

    service.installing!.add(0.5);
    await Future<void>.delayed(Duration.zero);
    expect(controller.progress, 0.5);

    await service.finishInstall();
    await install;
    expect(controller.installed, WhisperModel.base);
    expect(controller.downloading, isNull);
    expect(controller.progress, isNull);
  });

  test('cancelar la descarga no la da por fallida', () async {
    final install = controller.install(WhisperModel.base);

    await controller.cancelInstall();
    await install;

    expect(service.cancelledInstalls, 1);
    expect(controller.downloading, isNull);
    expect(controller.installed, isNull);
  });

  test('si la descarga falla, lo dice y se puede volver a intentar', () async {
    final install = controller.install(WhisperModel.tiny);
    service.installing!.addError(const FormatException('SHA-256'));

    await expectLater(install, throwsFormatException);
    expect(controller.downloading, isNull);

    final again = controller.install(WhisperModel.tiny);
    await service.finishInstall();
    await again;
    expect(controller.installed, WhisperModel.tiny);
  });

  test('borra el modelo', () async {
    service.installed = WhisperModel.base;
    await controller.load();

    await controller.uninstall();

    expect(service.uninstalls, 1);
    expect(controller.installed, isNull);
  });
}
