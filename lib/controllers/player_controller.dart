import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import '../services/audio_player_service.dart';

/// Reproduce las grabaciones de una en una. Al terminar una, puede volver a
/// empezarla ([loop]) o seguir con la siguiente de la lista ([playlist]); con
/// las dos, al acabar la lista vuelve a la primera.
class PlayerController extends ChangeNotifier {
  /// [audioPath] da la ruta local del audio de cada grabación (ver
  /// `StorageSync.audioPath`); por defecto, la de dentro de la app. [queue]
  /// da las grabaciones de la lista, en orden, para seguir con la siguiente.
  PlayerController({
    required this._player,
    Future<String> Function(Recording recording)? audioPath,
    List<Recording> Function()? queue,
  }) : _audioPath = audioPath ?? _localPath,
       _queue = queue ?? _noQueue {
    _subscriptions = [
      _player.statusChanges.listen(_onStatus),
      _player.positionChanges.listen(_onPosition),
      _player.durationChanges.listen(_onDuration),
    ];
  }

  final AudioPlayerService _player;
  final Future<String> Function(Recording recording) _audioPath;
  final List<Recording> Function() _queue;

  static List<Recording> _noQueue() => const [];
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

  /// La grabación cargada, para saber cuál sigue.
  Recording? _current;

  bool _loop = false;

  /// Si al terminar se vuelve a empezar: la misma grabación o, con
  /// [playlist], la lista.
  bool get loop => _loop;

  bool _playlist = false;

  /// Si al terminar una grabación se sigue con la siguiente de la lista.
  bool get playlist => _playlist;

  void toggleLoop() {
    _loop = !_loop;
    _notify();
  }

  void togglePlaylist() {
    _playlist = !_playlist;
    _notify();
  }

  /// Indica si hay una grabación sonando o en pausa (no parada ni
  /// terminada).
  bool get isPlayingOrPaused =>
      _currentId != null &&
      (_status == PlaybackStatus.playing || _status == PlaybackStatus.paused);

  bool isPlaying(Recording recording) =>
      isCurrent(recording) && _status == PlaybackStatus.playing;

  bool _loading = false;

  /// Indica si se está leyendo el audio de [recording] para reproducirlo
  /// (p. ej. descargándolo de Google Drive).
  bool isLoading(Recording recording) => isCurrent(recording) && _loading;

  /// Indica si se está leyendo el audio de la grabación cargada.
  bool get loading => _currentId != null && _loading;

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

    _load(recording);
    await _play(recording);
  }

  /// Carga [recording] desde el principio.
  void _load(Recording recording, {Duration position = Duration.zero}) {
    _currentId = recording.id;
    _current = recording;
    _position = position;
    _duration = recording.duration;
    _notify();
  }

  /// Selecciona [recording] sin reproducirla (se ve seleccionada, con su
  /// transcripción; al tocarla suena desde el principio), salvo que haya
  /// otra sonando o en pausa.
  void select(Recording recording) {
    if (isPlayingOrPaused) return;
    _status = PlaybackStatus.stopped;
    _load(recording);
  }

  /// Selecciona [recording] sin reproducirla, en [position] (si ya estaba
  /// seleccionada y no se indica, donde estaba). Si sonaba otra, se para.
  Future<void> pick(Recording recording, {Duration? position}) async {
    if (isCurrent(recording)) {
      if (position != null) await seek(position);
      return;
    }
    final wasLoaded = isPlayingOrPaused || _loading;
    _status = PlaybackStatus.stopped;
    _loading = false;
    _load(recording, position: position ?? Duration.zero);
    if (wasLoaded) await _player.stop();
  }

  /// Carga [recording] y la reproduce desde [position].
  Future<void> playFrom(Recording recording, Duration position) async {
    if (isCurrent(recording)) {
      await seek(position);
      if (_status != PlaybackStatus.playing) await toggle(recording);
      return;
    }
    _load(recording, position: position);
    await _play(recording, position: position);
  }

  /// Lee el audio de [recording] (si está guardada fuera de la app, puede
  /// tardar) y lo reproduce, salvo que entretanto se haya elegido otra. Si no
  /// se puede leer, la descarga y lanza el error.
  Future<void> _play(Recording recording, {Duration? position}) async {
    final String path;
    final request = ++_playRequest;
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
    // Si entretanto se ha elegido otra o se ha parado, ya no suena.
    if (!isCurrent(recording) || request != _playRequest) return;
    await _player.play(path, position: position);
  }

  /// Cuenta las veces que se ha pedido reproducir (o parar con
  /// [stopPlayback]): mientras se lee el audio, si cambia, ya no suena.
  var _playRequest = 0;

  static Future<String> _localPath(Recording recording) async => recording.path;

  Future<void> seek(Duration position) async {
    if (_currentId == null) return;
    _position = position;
    _notify();
    // Mientras salta, el reproductor aún puede dar posiciones de antes: la
    // línea volvería atrás un momento.
    _seeking++;
    try {
      await _player.seek(position);
    } finally {
      _seeking--;
    }
  }

  /// Saltos en curso (ver [seek]).
  var _seeking = 0;

  /// Detiene la reproducción sin quitar la selección: la grabación sigue
  /// seleccionada y, con su botón, vuelve a sonar desde el principio.
  Future<void> stopPlayback() async {
    if (_currentId == null) return;
    final wasLoaded = isPlayingOrPaused || _loading;
    _playRequest++;
    _loading = false;
    _status = PlaybackStatus.stopped;
    _position = Duration.zero;
    _notify();
    if (wasLoaded) await _player.stop();
  }

  /// Detiene la reproducción y descarga la grabación actual.
  Future<void> stop() async {
    if (_currentId == null) return;
    _currentId = null;
    _current = null;
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
    if (status == PlaybackStatus.completed) {
      if (_next() case final next?) unawaited(_playNext(next));
    }
  }

  /// Si al terminar sigue con otra o vuelve a empezar (según [loop] y
  /// [playlist]). Se desactiva mientras se acompaña una grabación al piano,
  /// que termina con ella.
  bool autoAdvance = true;

  /// La que suena al terminar la actual, o `null` si se para.
  Recording? _next() {
    final current = _current;
    if (current == null || !autoAdvance) return null;
    if (!_playlist) return _loop ? current : null;
    final list = _queue();
    final index = list.indexWhere((r) => r.id == current.id);
    if (index == -1) return _loop ? current : null;
    if (index + 1 < list.length) return list[index + 1];
    return _loop ? list.first : null;
  }

  Future<void> _playNext(Recording next) async {
    _load(next);
    try {
      await _play(next);
    } catch (_) {
      // No se pudo leer (p. ej. sin conexión para descargarla): se para.
    }
  }

  void _onPosition(Duration position) {
    // En pausa también: al pausar, da por dónde se ha quedado de verdad.
    if (_status != PlaybackStatus.playing && _status != PlaybackStatus.paused) {
      return;
    }
    if (_seeking > 0) return;
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
