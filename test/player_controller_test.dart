import 'dart:async';
import 'dart:io';

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

  test('selecciona sin reproducir, salvo que otra esté sonando', () async {
    controller.select(first);
    expect(controller.isCurrent(first), isTrue);
    expect(controller.status, PlaybackStatus.stopped);
    expect(player.calls, isEmpty);

    // Al tocarla, desde el principio.
    await controller.toggle(first);
    await flush();
    expect(controller.isPlaying(first), isTrue);
    expect(player.calls, ['play /a.m4a @0']);

    // Mientras suena, no se cambia.
    controller.select(second);
    expect(controller.isPlaying(first), isTrue);
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

  test('parar la reproducción la deja seleccionada, al principio', () async {
    await controller.toggle(first);
    player.statusController.add(PlaybackStatus.playing);
    player.positionController.add(const Duration(seconds: 3));
    await flush();

    await controller.stopPlayback();
    await flush();
    expect(controller.currentId, 'a');
    expect(controller.status, PlaybackStatus.stopped);
    expect(controller.position, Duration.zero);
    expect(controller.isPlayingOrPaused, isFalse);
    expect(player.calls.last, 'stop');

    // Vuelve a sonar desde el principio.
    await controller.toggle(first);
    expect(player.calls.last, 'play /a.m4a @0');
  });

  test('parar mientras se lee el audio no la deja sonar', () async {
    final gate = Completer<String>();
    controller.dispose();
    controller = PlayerController(
      player: player,
      audioPath: (_) => gate.future,
    );

    final loading = controller.toggle(first);
    await controller.stopPlayback();
    gate.complete('/cache/a.m4a');
    await loading;

    expect(player.calls, ['stop']);
    expect(controller.currentId, 'a');
    expect(controller.isLoading(first), isFalse);
  });

  test('libera el reproductor al desecharse', () {
    final service = FakeAudioPlayerService();
    PlayerController(player: service).dispose();

    expect(service.disposed, isTrue);
  });

  group('audio guardado fuera de la app', () {
    test('reproduce la ruta que da audioPath', () async {
      controller.dispose();
      controller = PlayerController(
        player: player,
        audioPath: (recording) async => '/cache/${recording.id}.m4a',
      );

      await controller.toggle(first);

      expect(player.calls, ['play /cache/a.m4a @0']);
    });

    test('si no se puede leer, la descarga y lanza el error', () async {
      controller.dispose();
      controller = PlayerController(
        player: player,
        audioPath: (_) async => throw const FileSystemException('sin red'),
      );

      await expectLater(controller.toggle(first), throwsA(anything));

      expect(controller.currentId, isNull);
      expect(controller.isLoading(first), isFalse);
      expect(player.calls, isEmpty);
    });

    test('si se elige otra mientras se lee, no reproduce la primera', () async {
      final gate = Completer<String>();
      controller.dispose();
      controller = PlayerController(
        player: player,
        audioPath: (recording) =>
            recording.id == 'a' ? gate.future : Future.value(recording.path),
      );

      final loading = controller.toggle(first);
      expect(controller.isLoading(first), isTrue);
      await controller.toggle(second);
      gate.complete('/cache/a.m4a');
      await loading;

      expect(player.calls, ['play /b.m4a @0']);
      expect(controller.isCurrent(second), isTrue);
    });
  });

  group('al terminar', () {
    final third = Recording(
      id: 'c',
      path: '/c.m4a',
      name: 'C',
      createdAt: DateTime(2026),
      duration: const Duration(seconds: 5),
    );

    setUp(() {
      controller.dispose();
      player = FakeAudioPlayerService();
      controller = PlayerController(
        player: player,
        queue: () => [first, second, third],
      );
    });

    Future<void> finish() async {
      player.statusController.add(PlaybackStatus.completed);
      await flush();
      await flush();
    }

    test('sin bucle ni lista, se para', () async {
      await controller.toggle(first);
      await finish();

      expect(player.calls, ['play /a.m4a @0']);
      expect(controller.isPlayingOrPaused, isFalse);
      expect(controller.currentId, 'a');
    });

    test('en bucle, vuelve a empezar la misma', () async {
      controller.toggleLoop();
      await controller.toggle(second);
      await finish();

      expect(player.calls, ['play /b.m4a @0', 'play /b.m4a @0']);
      expect(controller.isPlaying(second), isTrue);
    });

    test('con la lista, sigue con la siguiente y se para al final', () async {
      controller.togglePlaylist();
      await controller.toggle(second);
      await finish();
      expect(controller.isPlaying(third), isTrue);
      expect(controller.duration, third.duration);

      await finish();
      expect(player.calls, ['play /b.m4a @0', 'play /c.m4a @0']);
      expect(controller.isPlayingOrPaused, isFalse);
    });

    test('con la lista en bucle, al final vuelve a la primera', () async {
      controller
        ..togglePlaylist()
        ..toggleLoop();
      await controller.toggle(third);
      await finish();

      expect(player.calls.last, 'play /a.m4a @0');
      expect(controller.isPlaying(first), isTrue);
    });

    test('los interruptores se conservan al parar', () async {
      controller.toggleLoop();
      await controller.toggle(first);
      await controller.stop();
      expect(controller.loop, isTrue);
      expect(controller.playlist, isFalse);
    });
  });
}
