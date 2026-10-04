import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/player_controller.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/services/audio_player_service.dart';

import 'fakes.dart';

void main() {
  late FakeAudioPlayerService player;
  late PlayerController controller;

  final first = Recording(
    id: 'a',
    path: '/a.m4a',
    name: 'A',
    createdAt: DateTime(2026),
    duration: const Duration(seconds: 10),
  );
  final second = Recording(
    id: 'b',
    path: '/b.m4a',
    name: 'B',
    createdAt: DateTime(2026),
    duration: const Duration(seconds: 20),
  );

  /// Deja que se entreguen los eventos pendientes de los streams.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    player = FakeAudioPlayerService();
    controller = PlayerController(player: player);
  });

  tearDown(() => controller.dispose());

  test('reproduce, pausa y reanuda la misma grabación', () async {
    await controller.toggle(first);
    await flush();
    expect(controller.isPlaying(first), isTrue);
    expect(controller.duration, first.duration);

    await controller.toggle(first);
    await flush();
    expect(controller.status, PlaybackStatus.paused);
    expect(controller.isCurrent(first), isTrue);

    await controller.toggle(first);
    await flush();
    expect(controller.isPlaying(first), isTrue);
    expect(player.calls, ['play /a.m4a @0', 'pause', 'resume']);
  });

  test('cambia de grabación', () async {
    await controller.toggle(first);
    await controller.toggle(second);
    await flush();

    expect(controller.isCurrent(first), isFalse);
    expect(controller.isPlaying(second), isTrue);
    expect(controller.duration, second.duration);
    expect(player.calls.last, 'play /b.m4a @0');
  });

  test('sigue la posición y la duración reales', () async {
    await controller.toggle(first);
    await flush();

    player.positionController.add(const Duration(seconds: 3));
    player.durationController.add(const Duration(milliseconds: 10500));
    await flush();

    expect(controller.position, const Duration(seconds: 3));
    expect(controller.duration, const Duration(milliseconds: 10500));
  });

  test('al terminar vuelve al principio y se puede repetir', () async {
    await controller.toggle(first);
    player.statusController.add(PlaybackStatus.completed);
    await flush();
    expect(controller.status, PlaybackStatus.completed);
    expect(controller.position, Duration.zero);

    // Las posiciones que llegan tras terminar no mueven la barra.
    player.positionController.add(const Duration(seconds: 10));
    await flush();
    expect(controller.position, Duration.zero);

    await controller.seek(const Duration(seconds: 4));
    await controller.toggle(first);
    expect(player.calls.sublist(1), ['seek 4000', 'play /a.m4a @4000']);
  });

  test('detener descarga la grabación actual', () async {
    await controller.toggle(first);
    await controller.stop();
    await flush();

    expect(controller.currentId, isNull);
    expect(controller.status, PlaybackStatus.stopped);
    expect(player.calls.last, 'stop');
  });

  test('libera el reproductor al desecharse', () {
    final service = FakeAudioPlayerService();
    PlayerController(player: service).dispose();

    expect(service.disposed, isTrue);
  });
}
