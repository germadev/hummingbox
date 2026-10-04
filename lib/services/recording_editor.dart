import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_edit.dart';
import '../audio/audio_info.dart';
import '../audio/levels.dart';
import '../audio/wav.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
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
/// aparte para no bloquear la interfaz y las vuelve a guardar en su formato
/// (`.m4a` o `.wav`).
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
      await _decode(recording.path, source);
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
    final recording = session.recording;
    final edited = p.join(session.directory.path, 'edited.wav');
    final result = await _process(session.sourcePath, edited, edit);

    // Se conserva el formato de la grabación y, en AAC, su tasa de bits.
    final format = recording.format;
    final String output;
    switch (format) {
      case RecordingFormat.wav:
        output = edited;
      case RecordingFormat.aac:
        output = p.join(session.directory.path, 'edited.m4a');
        await codec.encodeToM4a(
          edited,
          output,
          bitRate: await _bitRateOf(recording),
        );
    }
    final audio = (await probe(output))?.info;

    if (!asCopy) {
      return repository.replaceAudio(
        recording,
        sourcePath: output,
        duration: result.duration,
        waveform: result.levels,
        audio: audio,
      );
    }

    final path = await repository.createRecordingPath(format: format);
    await moveFile(output, path);
    final copy = await repository.add(
      path: path,
      duration: result.duration,
      waveform: result.levels,
      name: '${recording.name}$copySuffix',
      audio: audio,
      folder: recording.folder,
    );
    if (copy == null) throw StateError('No se pudo registrar la copia');
    return copy;
  }

  Future<void> close(EditSession session) => deleteQuietly(session.directory);

  /// Lee el formato y la duración del archivo de [path] en su cabecera.
  Future<AudioProbe?> probe(String path) => probeAudio(path);

  /// Tasa de bits con la que se vuelve a codificar un AAC: la que indica su
  /// cabecera o, si no se puede leer, la de la calidad alta.
  Future<int> _bitRateOf(Recording recording) async {
    final known =
        recording.audio?.bitRate ?? (await probe(recording.path))?.info.bitRate;
    return known ?? const RecordingOptions().bitRate;
  }

  /// Los WAV de 16 bits se usan tal cual; el resto se decodifica con el
  /// códec del sistema.
  Future<void> _decode(String input, String output) async {
    if (RecordingFormat.fromPath(input) == RecordingFormat.wav) {
      try {
        await readWavInfo(input);
        await File(input).copy(output);
        return;
      } on FormatException {
        // Otro tipo de WAV (p. ej. de 24 bits): lo convierte el sistema.
      }
    }
    await codec.decodeToWav(input, output);
  }

  /// Calcula la onda de una grabación que no la tiene (p. ej. si se hizo con
  /// una versión anterior de la app).
  Future<List<double>> extractWaveform(Recording recording) async {
    final directory = await _createSessionDirectory();
    try {
      final wav = p.join(directory.path, 'waveform.wav');
      await _decode(recording.path, wav);
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
