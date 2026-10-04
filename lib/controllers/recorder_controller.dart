import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/levels.dart';
import '../models/recording.dart';
import '../services/audio_recorder_service.dart';
import '../services/recordings_repository.dart';

/// Gestiona una sesión de grabación: estado, tiempo transcurrido y niveles
/// de entrada para dibujar la onda.
class RecorderController extends ChangeNotifier {
  RecorderController({
    required this._recorder,
    required this._repository,
    this.maxAmplitudeSamples = 300,
  }) {
    _statusSubscription = _recorder.statusChanges().listen(_onPlatformStatus);
  }

  /// Número de muestras de amplitud que se conservan para la onda. Tienen que
  /// sobrar para llenar el ancho de la pantalla: las barras sin muestra se
  /// dibujan como el hueco anterior al inicio de la grabación.
  final int maxAmplitudeSamples;

  static const _tick = Duration(milliseconds: 100);

  final AudioRecorderService _recorder;
  final RecordingsRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _amplitudes = [];

  /// Todos los niveles de la grabación en curso, para guardar su onda.
  final List<double> _history = [];

  late final StreamSubscription<RecorderStatus> _statusSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _ticker;
  String? _currentPath;
  bool _busy = false;
  bool _disposed = false;

  RecorderStatus _status = RecorderStatus.idle;
  RecorderStatus get status => _status;

  bool get isActive => _status != RecorderStatus.idle;

  Duration get elapsed => _stopwatch.elapsed;

  /// Niveles normalizados (0–1) de las últimas muestras, de más antigua a
  /// más reciente.
  List<double> get amplitudes => List.unmodifiable(_amplitudes);

  /// Empieza una nueva grabación.
  ///
  /// Devuelve `false` si el usuario no concedió el permiso del micrófono.
  Future<bool> start() async {
    if (isActive || _busy) return true;
    _busy = true;
    try {
      if (!await _recorder.hasPermission()) return false;

      final path = await _repository.createRecordingPath();
      await _recorder.start(path);
      _currentPath = path;
      _amplitudes.clear();
      _history.clear();
      _amplitudeSubscription = _recorder
          .amplitudeChanges(_tick)
          .listen(_onAmplitude);
      _stopwatch.reset();
      _setRecording();
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<void> pause() async {
    if (_status != RecorderStatus.recording || _busy) return;
    await _recorder.pause();
    _setPaused();
  }

  Future<void> resume() async {
    if (_status != RecorderStatus.paused || _busy) return;
    await _recorder.resume();
    _setRecording();
  }

  /// Detiene la grabación y la guarda. Devuelve la grabación creada.
  Future<Recording?> stop() async {
    if (!isActive || _busy) return null;
    _busy = true;
    try {
      final duration = _stopwatch.elapsed;
      final waveform = _history.isEmpty
          ? null
          : resampleLevels(_history, waveformResolution);
      var path = _currentPath;
      try {
        path = await _recorder.stop() ?? path;
      } finally {
        _reset();
      }
      if (path == null) return null;
      return await _repository.add(
        path: path,
        duration: duration,
        waveform: waveform,
      );
    } finally {
      _busy = false;
    }
  }

  /// Detiene la grabación y descarta el audio.
  Future<void> cancel() async {
    if (!isActive || _busy) return;
    _busy = true;
    try {
      final path = _currentPath;
      try {
        await _recorder.cancel();
      } finally {
        _reset();
      }
      if (path != null) await _repository.discard(path);
    } finally {
      _busy = false;
    }
  }

  /// Convierte un nivel en dBFS a un valor entre 0 (silencio) y 1 (máximo).
  static double normalizeAmplitude(double dbfs) => levelFromDb(dbfs);

  void _onAmplitude(double dbfs) {
    if (_status != RecorderStatus.recording) return;
    final level = normalizeAmplitude(dbfs);
    _amplitudes.add(level);
    _history.add(level);
    if (_amplitudes.length > maxAmplitudeSamples) {
      _amplitudes.removeRange(0, _amplitudes.length - maxAmplitudeSamples);
    }
  }

  /// Sincroniza el estado cuando la plataforma pausa o reanuda la grabación
  /// por su cuenta (p. ej. por una llamada entrante).
  void _onPlatformStatus(RecorderStatus platformStatus) {
    if (_status == RecorderStatus.recording &&
        platformStatus == RecorderStatus.paused) {
      _setPaused();
    } else if (_status == RecorderStatus.paused &&
        platformStatus == RecorderStatus.recording) {
      _setRecording();
    }
  }

  void _setRecording() {
    _stopwatch.start();
    _ticker ??= Timer.periodic(_tick, (_) => _notify());
    _status = RecorderStatus.recording;
    _notify();
  }

  void _setPaused() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _status = RecorderStatus.paused;
    _notify();
  }

  void _reset() {
    _stopwatch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _amplitudes.clear();
    _history.clear();
    _currentPath = null;
    _status = RecorderStatus.idle;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _amplitudeSubscription?.cancel();
    _statusSubscription.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
