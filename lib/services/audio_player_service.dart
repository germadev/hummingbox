import 'package:audioplayers/audioplayers.dart';

/// Estado del reproductor.
enum PlaybackStatus { stopped, playing, paused, completed }

/// Reproducción de audio. Abstraída para poder sustituirla en los tests.
abstract interface class AudioPlayerService {
  Stream<PlaybackStatus> get statusChanges;

  Stream<Duration> get positionChanges;

  Stream<Duration> get durationChanges;

  /// Reproduce el archivo de [path], opcionalmente desde [position].
  Future<void> play(String path, {Duration? position});

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> dispose();
}

/// Implementación basada en el paquete `audioplayers`.
class AudioplayersPlayerService implements AudioPlayerService {
  AudioplayersPlayerService() {
    // Al terminar conserva el audio cargado para poder volver a buscar en él.
    _player.setReleaseMode(ReleaseMode.stop);
  }

  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<PlaybackStatus> get statusChanges => _player.onPlayerStateChanged
      .where((state) => state != PlayerState.disposed)
      .map(
        (state) => switch (state) {
          PlayerState.playing => PlaybackStatus.playing,
          PlayerState.paused => PlaybackStatus.paused,
          PlayerState.completed => PlaybackStatus.completed,
          PlayerState.stopped || PlayerState.disposed => PlaybackStatus.stopped,
        },
      );

  @override
  Stream<Duration> get positionChanges => _player.onPositionChanged;

  @override
  Stream<Duration> get durationChanges => _player.onDurationChanged;

  @override
  Future<void> play(String path, {Duration? position}) =>
      _player.play(DeviceFileSource(path), position: position);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
