import 'package:record/record.dart';

/// Estado del grabador.
enum RecorderStatus { idle, recording, paused }

/// Acceso al micrófono. Abstraído para poder sustituirlo en los tests.
abstract interface class AudioRecorderService {
  /// Comprueba el permiso del micrófono y lo solicita si hace falta.
  Future<bool> hasPermission();

  /// Empieza a grabar en el archivo [path].
  Future<void> start(String path);

  Future<void> pause();

  Future<void> resume();

  /// Detiene la grabación y devuelve la ruta del archivo generado.
  Future<String?> stop();

  /// Detiene la grabación y descarta el archivo.
  Future<void> cancel();

  /// Cambios de estado originados por la plataforma (p. ej. una llamada
  /// entrante que pausa la grabación).
  Stream<RecorderStatus> statusChanges();

  /// Nivel de entrada en dBFS (de -160 a 0), muestreado cada [interval].
  Stream<double> amplitudeChanges(Duration interval);

  Future<void> dispose();
}

/// Implementación basada en el paquete `record`.
class RecordAudioRecorderService implements AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// AAC-LC en contenedor .m4a, mono: buena calidad de voz y archivos ligeros
  /// que se reproducen en cualquier dispositivo.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,
    sampleRate: 44100,
    numChannels: 1,
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<RecorderStatus> statusChanges() {
    return _recorder.onStateChanged().map(
      (state) => switch (state) {
        RecordState.record => RecorderStatus.recording,
        RecordState.pause => RecorderStatus.paused,
        RecordState.stop => RecorderStatus.idle,
      },
    );
  }

  @override
  Stream<double> amplitudeChanges(Duration interval) {
    return _recorder
        .onAmplitudeChanged(interval)
        .map((amplitude) => amplitude.current);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
