import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import '../services/audio_player_service.dart';

/// Reproduce las grabaciones de una en una.
class PlayerController extends ChangeNotifier {
  /// [audioPath] da la ruta local del audio de cada grabación (ver
  /// `StorageSync.audioPath`); por defecto, la de dentro de la app.
  PlayerController({
    required this._player,
    Future<String> Function(Recording recording)? audioPath,
  }) : _audioPath = audioPath ?? _localPath {
    _subscriptions = [
      _player.statusChanges.listen(_onStatus),
      _player.positionChanges.listen(_onPosition),
      _player.durationChanges.listen(_onDuration),
    ];
  }

  final AudioPlayerService _player;
  final Future<String> Function(Recording recording) _audioPath;
  late final List<StreamSubscription<Object?>> _subscriptions;
  bool _disposed = false;

  String? _currentId;

  /// Id de la grabación cargada en el reproductor, si hay alguna.
  String? get currentId => _currentId;

  PlaybackStatus _status = PlaybackStatus.stopped;
  PlaybackStatus get status => _status;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  bool isCurrent(Recording recording) => recording.id == _currentId;

  bool isPlaying(Recording recording) =>
      isCurrent(recording) && _status == PlaybackStatus.playing;

  bool _loading = false;

  /// Indica si se está leyendo el audio de [recording] para reproducirlo
  /// (p. ej. descargándolo de Google Drive).
  bool isLoading(Recording recording) => isCurrent(recording) && _loading;

  /// Reproduce [recording] o, si ya es la actual, alterna entre reproducir y
  /// pausar.
  Future<void> toggle(Recording recording) async {
    if (isCurrent(recording)) {
      switch (_status) {
        case PlaybackStatus.playing:
          await _player.pause();
          return;
        case PlaybackStatus.paused:
          await _player.resume();
          return;
        case PlaybackStatus.stopped:
        case PlaybackStatus.completed:
          // Vuelve a cargar el audio desde la posición elegida.
          await _play(recording, position: _position);
          return;
      }
    }

    _currentId = recording.id;
    _position = Duration.zero;
    _duration = recording.duration;
    _notify();
    await _play(recording);
  }

  /// Carga [recording] y la reproduce desde [position].
  Future<void> playFrom(Recording recording, Duration position) async {
    if (isCurrent(recording)) {
      await seek(position);
      if (_status != PlaybackStatus.playing) await toggle(recording);
      return;
    }
    _currentId = recording.id;
    _position = position;
    _duration = recording.duration;
    _notify();
    await _play(recording, position: position);
  }

  /// Lee el audio de [recording] (si está guardada fuera de la app, puede
  /// tardar) y lo reproduce, salvo que entretanto se haya elegido otra. Si no
  /// se puede leer, la descarga y lanza el error.
  Future<void> _play(Recording recording, {Duration? position}) async {
    final String path;
    _loading = true;
    _notify();
    try {
      path = await _audioPath(recording);
    } catch (_) {
      if (isCurrent(recording)) {
        _currentId = null;
        _status = PlaybackStatus.stopped;
        _position = Duration.zero;
      }
      rethrow;
    } finally {
      if (isCurrent(recording) || _currentId == null) _loading = false;
      _notify();
    }
    if (!isCurrent(recording)) return;
    await _player.play(path, position: position);
  }

  static Future<String> _localPath(Recording recording) async => recording.path;

  Future<void> seek(Duration position) async {
    if (_currentId == null) return;
    _position = position;
    _notify();
    await _player.seek(position);
  }

  /// Detiene la reproducción y descarga la grabación actual.
  Future<void> stop() async {
    if (_currentId == null) return;
    _currentId = null;
    _loading = false;
    _status = PlaybackStatus.stopped;
    _position = Duration.zero;
    _notify();
    await _player.stop();
  }

  void _onStatus(PlaybackStatus status) {
    _status = status;
    if (status == PlaybackStatus.completed) _position = Duration.zero;
    _notify();
  }

  void _onPosition(Duration position) {
    if (_status != PlaybackStatus.playing) return;
    _position = position;
    _notify();
  }

  void _onDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _duration = duration;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
