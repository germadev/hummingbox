import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart'
    as whisper;

import '../models/transcription.dart';

/// Texto que da Whisper de un tramo de audio.
class WhisperText {
  const WhisperText(this.text, {this.language});

  final String text;

  /// Idioma en el que lo ha reconocido (el pedido o el que ha detectado).
  final String? language;
}

/// Whisper en el dispositivo: descarga de los modelos y transcripción.
/// Abstraído para poder sustituirlo en los tests.
abstract interface class WhisperService {
  /// Modelo instalado, si hay alguno.
  Future<WhisperModel?> installedModel();

  /// Descarga [model] (y lo que necesita) y borra el que hubiera. Emite la
  /// parte descargada (0–1), o `null` si no se sabe. Si se cancela la
  /// suscripción, la descarga se reanuda la próxima vez.
  Stream<double?> install(WhisperModel model);

  /// Borra los modelos descargados.
  Future<void> uninstall();

  /// Carga el modelo instalado para transcribir. Hay que cerrar la sesión al
  /// terminar, porque ocupa mucha memoria.
  Future<WhisperSession> open();
}

/// Modelo cargado en memoria.
abstract interface class WhisperSession {
  WhisperModel get model;

  /// Transcribe [samples] (16 kHz, un canal, de -1 a 1) en [language] (un
  /// código ISO 639-1 o «auto» para detectarlo).
  Future<WhisperText> transcribe(
    Float32List samples, {
    required String language,
    void Function(double fraction)? onProgress,
  });

  /// Cancela la transcripción en curso, que falla.
  void cancel();

  Future<void> close();
}

/// Implementación con whisper.cpp. Los modelos se descargan de Hugging Face
/// en una versión fija y se comprueba su suma SHA-256.
class PluginWhisperService implements WhisperService {
  PluginWhisperService({whisper.WhisperModelManager? models})
    : _models = models ?? whisper.WhisperModelManager();

  final whisper.WhisperModelManager _models;

  /// Detector de voz (menos de 1 MB): con él, Whisper solo transcribe donde
  /// hay voz y no se inventa texto en los silencios.
  static const _vad = whisper.WhisperModelCatalog.sileroVad;

  static whisper.WhisperModelDescriptor _descriptor(WhisperModel model) =>
      switch (model) {
        WhisperModel.tiny => whisper.WhisperModelCatalog.tiny,
        WhisperModel.base => whisper.WhisperModelCatalog.base,
      };

  @override
  Future<WhisperModel?> installedModel() async {
    for (final model in WhisperModel.values.reversed) {
      if (await _models.find(_descriptor(model).fileName) != null) {
        return model;
      }
    }
    return null;
  }

  @override
  Stream<double?> install(WhisperModel model) async* {
    yield 0;
    if (await _models.find(_vad.fileName) == null) {
      await _models.downloadCatalogModel(_vad).drain<void>();
    }
    yield* _models
        .downloadCatalogModel(_descriptor(model))
        .map((progress) => progress.fraction);
    for (final other in WhisperModel.values) {
      if (other != model) await _delete(_descriptor(other).fileName);
    }
  }

  @override
  Future<void> uninstall() async {
    final directory = await _models.directory;
    for (final entity in directory.listSync()) {
      // Los modelos y las descargas a medias.
      if (entity is File && entity.uri.pathSegments.last.startsWith('ggml-')) {
        try {
          entity.deleteSync();
        } on FileSystemException {
          // Se volverá a intentar la próxima vez.
        }
      }
    }
  }

  Future<void> _delete(String name) async {
    if (await _models.find(name) == null) return;
    try {
      await _models.delete(name);
    } on FileSystemException {
      // Ocupa espacio, pero no impide usar el nuevo.
    }
  }

  @override
  Future<WhisperSession> open() async {
    final model = await installedModel();
    if (model == null) throw StateError('No hay ningún modelo de Whisper');
    final file = await _models.find(_descriptor(model).fileName);
    final vad = await _models.find(_vad.fileName);
    final engine = await whisper.WhisperEngine.load(file!.path);
    return _PluginWhisperSession(model, engine, vad?.path);
  }
}

class _PluginWhisperSession implements WhisperSession {
  _PluginWhisperSession(this.model, this._engine, this._vadPath);

  @override
  final WhisperModel model;
  final whisper.WhisperEngine _engine;
  final String? _vadPath;
  whisper.WhisperTask? _task;

  @override
  Future<WhisperText> transcribe(
    Float32List samples, {
    required String language,
    void Function(double fraction)? onProgress,
  }) async {
    final task = _engine.transcribe(
      samples,
      options: whisper.TranscribeOptions(
        language: language,
        threads: math.max(1, math.min(4, Platform.numberOfProcessors)),
        tokenTimestamps: false,
        enableVad: _vadPath != null,
        vadModelPath: _vadPath,
      ),
    );
    _task = task;
    final progress = task.progress.listen(
      (percent) => onProgress?.call(percent / 100),
    );
    try {
      final result = await task.result;
      return WhisperText(result.text.trim(), language: result.language);
    } finally {
      await progress.cancel();
      _task = null;
    }
  }

  @override
  void cancel() => _task?.cancel();

  @override
  Future<void> close() async => _engine.dispose();
}
