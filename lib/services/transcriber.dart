import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/speech_audio.dart';
import '../audio/wav.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import '../models/transcription.dart';
import '../utils/files.dart';
import 'audio_codec.dart';
import 'speech_recognition.dart';
import 'whisper_service.dart';

/// Por qué no se pudo transcribir una grabación.
enum TranscriptionError {
  canceled,

  /// El reconocimiento de voz del sistema no está disponible en el
  /// dispositivo (en Android, necesita la versión 13 o superior).
  systemUnavailable,

  /// El reconocimiento del sistema no admite el idioma.
  unsupportedLanguage,

  /// Hay que descargar el idioma para el reconocimiento del sistema.
  needsDownload,

  /// Se está descargando el idioma.
  downloading,

  /// No se ha dado permiso para usar el reconocimiento de voz.
  denied,

  /// Falta el permiso del micrófono (Android lo pide también para
  /// transcribir).
  microphone,

  /// Whisper no está instalado.
  whisperNotInstalled,

  /// No se ha reconocido ninguna palabra.
  noSpeech,

  failed,
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.error, {this.language, this.cause});

  final TranscriptionError error;

  /// Idioma afectado (p. ej. el que hay que descargar), si lo hay.
  final String? language;

  /// Error original, si lo hay.
  final Object? cause;

  @override
  String toString() => 'TranscriptionException($error, $language, $cause)';
}

/// Permite cancelar una transcripción en curso.
class TranscriptionCancel {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }
}

/// Transcribe grabaciones con el reconocimiento de voz del sistema o con
/// Whisper.
///
/// El audio se convierte a 16 kHz y un canal (lo que usan los
/// reconocedores) en un isolate aparte, y los audios largos se dividen en
/// tramos, cortando en los silencios: con Whisper, para no cargar en memoria
/// más de [whisperChunk] de una vez; con el reconocimiento del sistema, si
/// tiene un límite (ver [SystemSpeech.maxLength]).
class Transcriber {
  Transcriber({
    required this.codec,
    required this.system,
    required this.whisper,
    Future<String> Function(Recording recording)? audioPath,
    Future<Directory> Function()? workDirectory,
    this.useIsolates = true,
  }) : _audioPath = audioPath ?? _localPath,
       _workDirectory = workDirectory ?? getTemporaryDirectory;

  final AudioCodec codec;
  final SystemSpeech system;
  final WhisperService whisper;

  /// Ruta local del audio de cada grabación (ver `StorageSync.audioPath`).
  final Future<String> Function(Recording recording) _audioPath;
  final Future<Directory> Function() _workDirectory;

  /// Si es `false`, el audio se procesa en el isolate actual (para tests).
  final bool useIsolates;

  /// Tramo más largo que se transcribe de una vez con Whisper (unos 40 MB de
  /// muestras).
  static const whisperChunk = Duration(minutes: 10);

  static Future<String> _localPath(Recording recording) async => recording.path;

  /// Transcribe [recording] con [engine] en [language] (un código ISO 639-1
  /// o, con Whisper, «auto» para detectarlo).
  ///
  /// [onProgress] recibe la parte transcrita (0–1), o `null` mientras se
  /// prepara el audio. Lanza [TranscriptionException] si no se puede.
  Future<Transcript> transcribe(
    Recording recording, {
    required TranscriptionEngine engine,
    required String language,
    void Function(double? progress)? onProgress,
    TranscriptionCancel? cancel,
  }) async {
    final token = cancel ?? TranscriptionCancel();
    void checkCancelled() {
      if (token.isCancelled) {
        throw const TranscriptionException(TranscriptionError.canceled);
      }
    }

    // Antes de preparar el audio, se comprueba que se puede transcribir.
    var recognitionLanguage = language;
    switch (engine) {
      case TranscriptionEngine.system:
        recognitionLanguage = await _checkSystem(language);
      case TranscriptionEngine.whisper:
        if (await whisper.installedModel() == null) {
          throw const TranscriptionException(
            TranscriptionError.whisperNotInstalled,
          );
        }
    }

    onProgress?.call(null);
    final directory = await _createSessionDirectory();
    try {
      final source = await _audioPath(recording);
      checkCancelled();
      final speech = await _prepare(source, directory);
      checkCancelled();

      final String text;
      WhisperModel? model;
      String? detected;
      switch (engine) {
        case TranscriptionEngine.system:
          text = await _transcribeWithSystem(
            speech,
            directory,
            recognitionLanguage,
            onProgress,
            token,
          );
        case TranscriptionEngine.whisper:
          (text, detected, model) = await _transcribeWithWhisper(
            speech,
            language,
            onProgress,
            token,
          );
      }
      checkCancelled();
      if (text.trim().isEmpty) {
        throw const TranscriptionException(TranscriptionError.noSpeech);
      }
      return Transcript(
        text: text.trim(),
        engine: engine,
        model: model,
        language: switch (engine) {
          TranscriptionEngine.system => recognitionLanguage,
          TranscriptionEngine.whisper =>
            language == TranscriptionSettings.detectLanguage
                ? detected
                : language,
        },
        revision: recording.revision,
        createdAt: DateTime.now(),
      );
    } finally {
      await deleteQuietly(directory);
    }
  }

  /// Comprueba que el reconocimiento del sistema admite [language] y
  /// devuelve la variante que se usará.
  Future<String> _checkSystem(String language) async {
    final SystemSpeechSupport support;
    try {
      support = await system.check(language);
    } on PlatformException catch (e) {
      throw TranscriptionException(TranscriptionError.failed, cause: e);
    } on MissingPluginException {
      throw const TranscriptionException(TranscriptionError.systemUnavailable);
    }
    final resolved = support.language ?? language;
    final error = switch (support.status) {
      SystemSpeechStatus.available ||
      SystemSpeechStatus.online ||
      SystemSpeechStatus.unknown => null,
      SystemSpeechStatus.download => TranscriptionError.needsDownload,
      SystemSpeechStatus.downloading => TranscriptionError.downloading,
      SystemSpeechStatus.unsupportedLanguage =>
        TranscriptionError.unsupportedLanguage,
      SystemSpeechStatus.denied => TranscriptionError.denied,
      SystemSpeechStatus.unavailable => TranscriptionError.systemUnavailable,
    };
    if (error != null) {
      throw TranscriptionException(error, language: resolved);
    }
    return resolved;
  }

  /// Decodifica el audio de [source] y lo convierte a 16 kHz y un canal.
  Future<SpeechAudio> _prepare(String source, Directory directory) async {
    var wav = source;
    if (!await _isPcm16Wav(source)) {
      wav = p.join(directory.path, 'decoded.wav');
      try {
        await codec.decodeToWav(source, wav);
      } catch (e) {
        throw TranscriptionException(TranscriptionError.failed, cause: e);
      }
    }
    final output = p.join(directory.path, 'speech.wav');
    try {
      if (!useIsolates) return await convertToSpeechAudio(wav, output);
      return await Isolate.run(() => convertToSpeechAudio(wav, output));
    } catch (e) {
      throw TranscriptionException(TranscriptionError.failed, cause: e);
    }
  }

  static Future<bool> _isPcm16Wav(String path) async {
    if (RecordingFormat.fromPath(path) != RecordingFormat.wav) return false;
    try {
      await readWavInfo(path);
      return true;
    } on FormatException {
      // Otro tipo de WAV (p. ej. de 24 bits): lo convierte el sistema.
      return false;
    }
  }

  Future<String> _transcribeWithSystem(
    SpeechAudio speech,
    Directory directory,
    String language,
    void Function(double? progress)? onProgress,
    TranscriptionCancel cancel,
  ) async {
    final total = speech.info.frameCount;
    final maxLength = system.maxLength;
    final chunks = maxLength == null
        ? [(start: 0, end: total)]
        : planSpeechChunks(speech.energies, total, maxLength: maxLength);
    final texts = <String>[];
    cancel._onCancel = () => unawaited(system.cancel());
    try {
      for (final (index, chunk) in chunks.indexed) {
        if (cancel.isCancelled) {
          throw const TranscriptionException(TranscriptionError.canceled);
        }
        var path = speech.path;
        var info = speech.info;
        if (chunks.length > 1) {
          path = p.join(directory.path, 'chunk_$index.wav');
          info = await _writeChunk(speech, path, chunk);
        }
        void report(double fraction) => onProgress?.call(
          total == 0
              ? fraction
              : (chunk.start + fraction * (chunk.end - chunk.start)) / total,
        );
        // El reconocedor no avisa de cuánto lleva: se le pregunta.
        final poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
          system.progress().then(report, onError: (_) {});
        });
        try {
          texts.add(
            await system.transcribe(path, info: info, language: language),
          );
        } on PlatformException catch (e) {
          throw _fromPlatform(e, cancel);
        } finally {
          poll.cancel();
        }
        report(1);
      }
    } finally {
      cancel._onCancel = null;
    }
    return _join(texts);
  }

  static TranscriptionException _fromPlatform(
    PlatformException e,
    TranscriptionCancel cancel,
  ) {
    if (cancel.isCancelled) {
      return const TranscriptionException(TranscriptionError.canceled);
    }
    return TranscriptionException(switch (e.code) {
      'canceled' => TranscriptionError.canceled,
      'language' => TranscriptionError.unsupportedLanguage,
      'denied' => TranscriptionError.denied,
      'permission' => TranscriptionError.microphone,
      'unavailable' => TranscriptionError.systemUnavailable,
      _ => TranscriptionError.failed,
    }, cause: e);
  }

  Future<(String, String?, WhisperModel)> _transcribeWithWhisper(
    SpeechAudio speech,
    String language,
    void Function(double? progress)? onProgress,
    TranscriptionCancel cancel,
  ) async {
    final WhisperSession session;
    try {
      session = await whisper.open();
    } on StateError {
      throw const TranscriptionException(
        TranscriptionError.whisperNotInstalled,
      );
    } catch (e) {
      // P. ej., el dispositivo no puede cargar el motor.
      throw TranscriptionException(TranscriptionError.failed, cause: e);
    }
    cancel._onCancel = session.cancel;
    try {
      final total = speech.info.frameCount;
      final texts = <String>[];
      String? detected;
      for (final chunk in planSpeechChunks(
        speech.energies,
        total,
        maxLength: whisperChunk,
      )) {
        if (cancel.isCancelled) {
          throw const TranscriptionException(TranscriptionError.canceled);
        }
        final samples = await _readSamples(speech, chunk);
        try {
          final result = await session.transcribe(
            samples,
            language: language,
            onProgress: (fraction) => onProgress?.call(
              total == 0
                  ? fraction
                  : (chunk.start + fraction * (chunk.end - chunk.start)) /
                        total,
            ),
          );
          texts.add(result.text);
          detected ??= result.language;
        } catch (e) {
          if (cancel.isCancelled) {
            throw const TranscriptionException(TranscriptionError.canceled);
          }
          throw TranscriptionException(TranscriptionError.failed, cause: e);
        }
        onProgress?.call(total == 0 ? 1 : chunk.end / total);
      }
      return (_join(texts), detected, session.model);
    } finally {
      cancel._onCancel = null;
      await session.close();
    }
  }

  static String _join(List<String> texts) => [
    for (final text in texts)
      if (text.trim().isNotEmpty) text.trim(),
  ].join(' ');

  Future<WavInfo> _writeChunk(
    SpeechAudio speech,
    String output,
    SpeechChunk chunk,
  ) {
    final path = speech.path;
    final info = speech.info;
    Future<WavInfo> write() => writeSpeechChunk(
      path,
      info,
      output,
      start: chunk.start,
      end: chunk.end,
    );
    return useIsolates ? Isolate.run(write) : write();
  }

  Future<Float32List> _readSamples(SpeechAudio speech, SpeechChunk chunk) {
    final path = speech.path;
    final info = speech.info;
    Future<Float32List> read() =>
        readSpeechSamples(path, info, start: chunk.start, end: chunk.end);
    return useIsolates ? Isolate.run(read) : read();
  }

  Future<Directory> _createSessionDirectory() async {
    final root = await _workDirectory();
    final parent = await Directory(p.join(root.path, 'transcription'))
        .create(recursive: true);
    return parent.createTemp('session_');
  }
}
