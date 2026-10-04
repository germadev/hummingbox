import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_info.dart';
import '../audio/levels.dart';
import '../audio/voice_detector.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import '../services/audio_recorder_service.dart';
import '../services/recordings_repository.dart';

/// Cómo se va a empezar a grabar mientras se espera.
enum PendingStart {
  /// Al terminar una cuenta atrás.
  countdown,

  /// Cuando se detecte la voz.
  voice,
}

/// Gestiona una sesión de grabación: estado, tiempo transcurrido y niveles
/// de entrada para dibujar la onda.
///
/// Además de empezar al momento, puede empezar tras una cuenta atrás o al
/// detectar la voz. En este caso el micrófono graba desde que se pide (para
/// tener el audio de justo antes) y, al terminar, se recorta el principio
/// dejando [preRoll] antes del momento en que se detectó la voz.
class RecorderController extends ChangeNotifier {
  RecorderController({
    required this._recorder,
    required this._repository,
    this.maxAmplitudeSamples = 300,
    this.preRoll = const Duration(seconds: 1),
    this._probe = probeAudio,
    this._trimStart,
  }) {
    _statusSubscription = _recorder.statusChanges().listen(_onPlatformStatus);
  }

  /// Número de muestras de amplitud que se conservan para la onda. Tienen que
  /// sobrar para llenar el ancho de la pantalla: las barras sin muestra se
  /// dibujan como el hueco anterior al inicio de la grabación.
  final int maxAmplitudeSamples;

  /// Margen que se conserva antes de la voz al empezar por voz.
  final Duration preRoll;

  static const _tick = Duration(milliseconds: 100);

  final AudioRecorderService _recorder;
  final RecordingsRepository _repository;

  /// Lee el formato y la duración del archivo grabado.
  final Future<AudioProbe?> Function(String path) _probe;

  /// Quita el principio de un archivo grabado. Sin él, al empezar por voz
  /// se conserva toda la espera.
  final Future<void> Function(String path, Duration start)? _trimStart;
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _amplitudes = [];

  /// Todos los niveles de la grabación en curso, para guardar su onda.
  final List<double> _history = [];

  late final StreamSubscription<RecorderStatus> _statusSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _ticker;
  String? _currentPath;

  /// Subcarpeta en la que se guarda la grabación en curso.
  String _folder = '';
  bool _busy = false;
  bool _disposed = false;

  // --- Inicio diferido ---

  PendingStart? _pending;
  Timer? _countdownTimer;
  Completer<bool>? _countdownDone;
  int _countdown = 0;

  /// Con qué y dónde se grabará al acabar la cuenta atrás.
  RecordingOptions _countdownOptions = const RecordingOptions();
  String _countdownFolder = '';
  VoiceDetector? _detector;

  /// Niveles grabados mientras se espera la voz (uno por [_tick]).
  int _waitTicks = 0;

  /// Niveles del último [preRoll] de la espera.
  final List<double> _preRollLevels = [];

  /// Parte del principio del archivo que se quita al terminar.
  Duration _trim = Duration.zero;

  /// Audio previo a la voz que se conserva, para el cronómetro.
  Duration _kept = Duration.zero;

  RecorderStatus _status = RecorderStatus.idle;

  /// Estado de la grabación. Mientras se espera para empezar es
  /// [RecorderStatus.idle] (ver [pending]).
  RecorderStatus get status => _status;

  /// Indica si hay una grabación en curso (grabando o en pausa).
  bool get isActive => _status != RecorderStatus.idle;

  /// Cómo se va a empezar, si se está esperando a una cuenta atrás o a la
  /// voz.
  PendingStart? get pending => _pending;

  /// Indica si se está grabando o esperando para empezar.
  bool get isBusy => isActive || _pending != null;

  /// Segundos que le quedan a la cuenta atrás.
  int get countdown => _countdown;

  Duration get elapsed => _stopwatch.elapsed + _kept;

  /// Niveles normalizados (0–1) de las últimas muestras, de más antigua a
  /// más reciente.
  List<double> get amplitudes => List.unmodifiable(_amplitudes);

  /// Empieza una nueva grabación con el formato y la calidad de [options],
  /// que se guardará en la subcarpeta [folder].
  ///
  /// Devuelve `false` si el usuario no concedió el permiso del micrófono.
  Future<bool> start({
    RecordingOptions options = const RecordingOptions(),
    String folder = '',
  }) async {
    if (isBusy || _busy) return true;
    _busy = true;
    try {
      if (!await _recorder.hasPermission()) return false;
      await _startRecorder(options, folder);
      _setRecording();
      return true;
    } finally {
      _busy = false;
    }
  }

  /// Empieza a grabar al terminar una cuenta atrás de [seconds] segundos.
  ///
  /// El permiso del micrófono se pide antes de empezar la cuenta: devuelve
  /// `false` si no se concede. Si no, se completa al empezar a grabar (o al
  /// cancelar la cuenta) con `true`.
  Future<bool> startAfterCountdown({
    required int seconds,
    RecordingOptions options = const RecordingOptions(),
    String folder = '',
  }) async {
    if (isBusy || _busy) return true;
    _busy = true;
    try {
      if (!await _recorder.hasPermission()) return false;
    } finally {
      _busy = false;
    }
    if (isBusy) return true;

    final done = _countdownDone = Completer<bool>();
    _pending = PendingStart.countdown;
    _countdown = seconds;
    _countdownOptions = options;
    _countdownFolder = folder;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _countdown--;
      if (_countdown > 0) {
        _notify();
      } else {
        _finishCountdown();
      }
    });
    _notify();
    return done.future;
  }

  void _finishCountdown() {
    final done = _countdownDone;
    final options = _countdownOptions;
    final folder = _countdownFolder;
    _clearPending();
    done?.complete(start(options: options, folder: folder));
  }

  /// Empieza a grabar en cuanto se detecte la voz, conservando [preRoll]
  /// antes de ella para que no empiece cortada.
  ///
  /// Devuelve `false` si el usuario no concedió el permiso del micrófono.
  Future<bool> startWhenVoice({
    RecordingOptions options = const RecordingOptions(),
    String folder = '',
  }) async {
    if (isBusy || _busy) return true;
    _busy = true;
    try {
      if (!await _recorder.hasPermission()) return false;
      _detector = VoiceDetector();
      _waitTicks = 0;
      _preRollLevels.clear();
      _pending = PendingStart.voice;
      await _startRecorder(options, folder);
      _notify();
      return true;
    } catch (_) {
      _clearPending();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  /// Empieza a grabar ya, sin esperar a que acabe la cuenta atrás o a que se
  /// hable. En la espera por voz se conserva también [preRoll].
  Future<void> startNow() async {
    switch (_pending) {
      case PendingStart.countdown:
        _finishCountdown();
      case PendingStart.voice:
        _beginAfterVoice();
      case null:
        return;
    }
  }

  /// Abre el micrófono y empieza a escribir el archivo.
  Future<void> _startRecorder(RecordingOptions options, String folder) async {
    final path = await _repository.createRecordingPath(format: options.format);
    await _recorder.start(path, options);
    _currentPath = path;
    _folder = folder;
    _amplitudes.clear();
    _history.clear();
    _trim = Duration.zero;
    _kept = Duration.zero;
    _stopwatch.reset();
    _amplitudeSubscription = _recorder
        .amplitudeChanges(_tick)
        .listen(_onAmplitude);
  }

  /// Se ha detectado la voz (o se pidió empezar ya): la grabación empieza
  /// [preRoll] antes.
  void _beginAfterVoice() {
    final heard = _tick * _waitTicks;
    _kept = heard < preRoll ? heard : preRoll;
    _trim = heard - _kept;
    // La onda empieza con el audio previo que se conserva.
    _amplitudes
      ..clear()
      ..addAll(_preRollLevels);
    _history
      ..clear()
      ..addAll(_preRollLevels);
    _detector = null;
    _pending = null;
    _stopwatch.reset();
    _setRecording();
  }

  void _clearPending() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownDone = null;
    _countdown = 0;
    _detector = null;
    _waitTicks = 0;
    _preRollLevels.clear();
    _pending = null;
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
      var duration = elapsed;
      final trim = _trim;
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
      final trimStart = _trimStart;
      if (trim > Duration.zero) {
        try {
          if (trimStart == null) throw StateError('Sin recorte');
          await trimStart(path, trim);
        } catch (_) {
          // Se guarda con la espera del principio antes que perderla.
          duration += trim;
        }
      }
      // La duración del archivo es más exacta que la del cronómetro.
      final probe = await _probe(path);
      return await _repository.add(
        path: path,
        duration: probe != null && probe.duration > Duration.zero
            ? probe.duration
            : duration,
        waveform: waveform,
        audio: probe?.info,
        folder: _folder,
      );
    } finally {
      _busy = false;
    }
  }

  /// Detiene la grabación (o la espera para empezar) y descarta el audio.
  Future<void> cancel() async {
    if (_pending == PendingStart.countdown) {
      final done = _countdownDone;
      _clearPending();
      done?.complete(true);
      _notify();
      return;
    }
    if (!isBusy || _busy) return;
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
    if (_pending == PendingStart.voice) {
      _onWaitingAmplitude(dbfs);
      return;
    }
    if (_status != RecorderStatus.recording) return;
    final level = normalizeAmplitude(dbfs);
    _amplitudes.add(level);
    _history.add(level);
    if (_amplitudes.length > maxAmplitudeSamples) {
      _amplitudes.removeRange(0, _amplitudes.length - maxAmplitudeSamples);
    }
  }

  /// Mientras se espera la voz: muestra el nivel (en gris), guarda el último
  /// [preRoll] y empieza al detectarla.
  void _onWaitingAmplitude(double dbfs) {
    final level = normalizeAmplitude(dbfs);
    _waitTicks++;
    _amplitudes.add(level);
    if (_amplitudes.length > maxAmplitudeSamples) {
      _amplitudes.removeRange(0, _amplitudes.length - maxAmplitudeSamples);
    }
    _preRollLevels.add(level);
    final keep = preRoll.inMicroseconds ~/ _tick.inMicroseconds;
    if (_preRollLevels.length > keep) {
      _preRollLevels.removeRange(0, _preRollLevels.length - keep);
    }
    if (_detector?.add(dbfs) ?? false) {
      _beginAfterVoice();
    } else {
      _notify();
    }
  }

  /// Sincroniza el estado cuando la plataforma pausa o reanuda la grabación
  /// por su cuenta (p. ej. por una llamada entrante).
  void _onPlatformStatus(RecorderStatus platformStatus) {
    if (_pending == PendingStart.voice &&
        platformStatus != RecorderStatus.recording) {
      // Una interrupción durante la espera: se deja de esperar.
      unawaited(cancel());
      return;
    }
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
    _trim = Duration.zero;
    _kept = Duration.zero;
    _clearPending();
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
    _countdownTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _statusSubscription.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
