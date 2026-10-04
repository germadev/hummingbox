import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_edit.dart';
import '../audio/levels.dart';
import '../models/recording.dart';
import '../utils/files.dart';
import 'audio_codec.dart';
import 'recordings_repository.dart';

/// Grabación decodificada y lista para editar.
class EditSession {
  const EditSession({
    required this.recording,
    required this.directory,
    required this.sourcePath,
    required this.analysis,
  });

  final Recording recording;

  /// Carpeta temporal de la sesión; se borra al cerrarla.
  final Directory directory;

  /// Audio original decodificado a WAV.
  final String sourcePath;

  /// Picos del audio original, para dibujar la onda y normalizar.
  final WavAnalysis analysis;

  Duration get duration => analysis.duration;
}

/// Edita grabaciones: las decodifica a WAV, aplica los cambios en un isolate
/// aparte para no bloquear la interfaz y vuelve a codificarlas en `.m4a`.
class RecordingEditor {
  RecordingEditor({
    required this.codec,
    required this.repository,
    Future<Directory> Function()? workDirectory,
    this.useIsolates = true,
  }) : _workDirectory = workDirectory ?? getTemporaryDirectory;

  final AudioCodec codec;
  final RecordingsRepository repository;
  final Future<Directory> Function() _workDirectory;

  /// Si es `false`, el procesado se hace en el isolate actual (para tests).
  final bool useIsolates;

  /// Tramos de la onda que se muestra en el editor.
  static const editorResolution = 400;

  /// Sufijo del nombre de las copias editadas.
  static const copySuffix = ' (editada)';

  Future<EditSession> open(Recording recording) async {
    final directory = await _createSessionDirectory();
    try {
      final source = p.join(directory.path, 'source.wav');
      await codec.decodeToWav(recording.path, source);
      final analysis = await _analyze(source, editorResolution);
      return EditSession(
        recording: recording,
        directory: directory,
        sourcePath: source,
        analysis: analysis,
      );
    } catch (_) {
      await deleteQuietly(directory);
      rethrow;
    }
  }

  /// Aplica [edit] y guarda el resultado, sustituyendo el audio original o,
  /// si [asCopy] es `true`, como una grabación nueva.
  Future<Recording> save(
    EditSession session,
    AudioEdit edit, {
    required bool asCopy,
  }) async {
    final edited = p.join(session.directory.path, 'edited.wav');
    final encoded = p.join(session.directory.path, 'edited.m4a');
    final result = await _process(session.sourcePath, edited, edit);
    await codec.encodeToM4a(edited, encoded);

    if (!asCopy) {
      return repository.replaceAudio(
        session.recording,
        sourcePath: encoded,
        duration: result.duration,
        waveform: result.levels,
      );
    }

    final path = await repository.createRecordingPath();
    await moveFile(encoded, path);
    final copy = await repository.add(
      path: path,
      duration: result.duration,
      waveform: result.levels,
      name: '${session.recording.name}$copySuffix',
    );
    if (copy == null) throw StateError('No se pudo registrar la copia');
    return copy;
  }

  Future<void> close(EditSession session) => deleteQuietly(session.directory);

  /// Calcula la onda de una grabación que no la tiene (p. ej. si se hizo con
  /// una versión anterior de la app).
  Future<List<double>> extractWaveform(Recording recording) async {
    final directory = await _createSessionDirectory();
    try {
      final wav = p.join(directory.path, 'waveform.wav');
      await codec.decodeToWav(recording.path, wav);
      final analysis = await _analyze(wav, waveformResolution);
      return analysis.levels;
    } finally {
      await deleteQuietly(directory);
    }
  }

  Future<Directory> _createSessionDirectory() async {
    final root = await _workDirectory();
    final parent = await Directory(p.join(root.path, 'editor'))
        .create(recursive: true);
    return parent.createTemp('session_');
  }

  Future<WavAnalysis> _analyze(String path, int buckets) {
    if (!useIsolates) return analyzeWav(path, buckets: buckets);
    return _analyzeInIsolate(path, buckets);
  }

  Future<WavAnalysis> _process(String input, String output, AudioEdit edit) {
    if (!useIsolates) {
      return processWav(input: input, output: output, edit: edit);
    }
    return _processInIsolate(input, output, edit);
  }

  // Funciones estáticas para que los cierres que se envían al isolate solo
  // capturen sus argumentos.
  static Future<WavAnalysis> _analyzeInIsolate(String path, int buckets) =>
      Isolate.run(() => analyzeWav(path, buckets: buckets));

  static Future<WavAnalysis> _processInIsolate(
    String input,
    String output,
    AudioEdit edit,
  ) => Isolate.run(() => processWav(input: input, output: output, edit: edit));
}
