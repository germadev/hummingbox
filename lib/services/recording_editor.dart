import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_edit.dart';
import '../audio/audio_info.dart';
import '../audio/levels.dart';
import '../audio/piano_mix.dart';
import '../audio/piano_tone.dart';
import '../audio/wav.dart';
import '../models/piano_note.dart';
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
    Future<String> Function(Recording recording)? audioPath,
    Future<Directory> Function()? workDirectory,
    this.useIsolates = true,
  }) : _audioPath = audioPath ?? _localPath,
       _workDirectory = workDirectory ?? getTemporaryDirectory;

  final AudioCodec codec;
  final RecordingsRepository repository;

  /// Ruta local del audio de cada grabación (ver `StorageSync.audioPath`);
  /// por defecto, la de dentro de la app.
  final Future<String> Function(Recording recording) _audioPath;
  final Future<Directory> Function() _workDirectory;

  static Future<String> _localPath(Recording recording) async => recording.path;

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
      await _decode(await _audioPath(recording), source);
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
  /// si [asCopy] es `true`, como una grabación nueva llamada [copyName] (por
  /// defecto, el nombre del original seguido de [copySuffix]).
  Future<Recording> save(
    EditSession session,
    AudioEdit edit, {
    required bool asCopy,
    String? copyName,
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
    // Las notas del piano que quedan, desde el nuevo principio.
    final notes = PianoNote.between(recording.notes, edit.start, edit.end);

    if (!asCopy) {
      final replaced = await repository.replaceAudio(
        recording,
        sourcePath: output,
        duration: result.duration,
        waveform: result.levels,
        audio: audio,
      );
      if (recording.notes.isEmpty) return replaced;
      return repository.setNotes(replaced, notes);
    }

    final path = await repository.createRecordingPath(format: format);
    await moveFile(output, path);
    final copy = await repository.add(
      path: path,
      duration: result.duration,
      waveform: result.levels,
      name: copyName ?? '${recording.name}$copySuffix',
      audio: audio,
      folder: recording.folder,
      notes: notes,
      hasVoice: recording.hasVoice,
    );
    if (copy == null) throw StateError('No se pudo registrar la copia');
    return copy;
  }

  /// Guarda como grabación nueva de la subcarpeta [folder] las [notes]
  /// tocadas en el piano (sin voz) durante [duration], con el formato y la
  /// calidad de [options]. Si la última nota suena más allá, dura hasta que
  /// se apaga.
  Future<Recording> savePiano({
    required List<PianoNote> notes,
    required Duration duration,
    required RecordingOptions options,
    String folder = '',
  }) async {
    final directory = await _createSessionDirectory();
    try {
      var length = duration;
      for (final note in notes) {
        final end = note.start + pianoToneLength;
        if (end > length) length = end;
      }
      final wav = p.join(directory.path, 'piano.wav');
      await _renderPiano(wav, notes, length, options.sampleRate);
      final analysis = await _analyze(wav, waveformResolution);
      final output = await _encode(
        wav,
        options.format,
        options.bitRate,
        directory,
      );
      final path = await repository.createRecordingPath(format: options.format);
      await moveFile(output, path);
      final recording = await repository.add(
        path: path,
        duration: analysis.duration,
        waveform: analysis.levels,
        audio: (await probe(path))?.info,
        folder: folder,
        notes: notes,
        hasVoice: false,
      );
      if (recording == null) throw StateError('No se pudo registrar');
      return recording;
    } finally {
      await deleteQuietly(directory);
    }
  }

  /// Añade al audio de [recording] (la voz) las [notes] tocadas en el piano
  /// mientras se grababa, y las guarda con ella. La onda sigue siendo la de
  /// la voz.
  Future<Recording> addPiano(Recording recording, List<PianoNote> notes) async {
    if (notes.isEmpty) return recording;
    final directory = await _createSessionDirectory();
    try {
      final source = p.join(directory.path, 'voice.wav');
      await _decode(await _audioPath(recording), source);
      final mixed = p.join(directory.path, 'mixed.wav');
      await _mixPiano(source, mixed, notes);
      final output = await _encode(
        mixed,
        recording.format,
        await _bitRateOf(recording),
        directory,
      );
      final replaced = await repository.replaceAudio(
        recording,
        sourcePath: output,
        duration: recording.duration,
        waveform: recording.waveform,
        audio: (await probe(output))?.info ?? recording.audio,
      );
      return await repository.setNotes(replaced, notes);
    } finally {
      await deleteQuietly(directory);
    }
  }

  /// El WAV de [wav] en [format]: tal cual o codificado en AAC con
  /// [bitRate].
  Future<String> _encode(
    String wav,
    RecordingFormat format,
    int bitRate,
    Directory directory,
  ) async {
    switch (format) {
      case RecordingFormat.wav:
        return wav;
      case RecordingFormat.aac:
        final output = p.join(
          directory.path,
          '${p.basenameWithoutExtension(wav)}.m4a',
        );
        await codec.encodeToM4a(wav, output, bitRate: bitRate);
        return output;
    }
  }

  Future<void> close(EditSession session) => deleteQuietly(session.directory);

  /// Quita de la grabación de [path] lo anterior a [start] (p. ej. la espera
  /// hasta que se empezó a hablar). Un `.m4a` se recorta sin volver a
  /// codificarlo; un WAV, en Dart.
  Future<void> trimStart(String path, Duration start) async {
    final directory = await _createSessionDirectory();
    try {
      final trimmed = p.join(directory.path, 'trimmed${p.extension(path)}');
      switch (RecordingFormat.fromPath(path)) {
        case RecordingFormat.wav:
          final info = await readWavInfo(path);
          await _process(
            path,
            trimmed,
            AudioEdit(start: start, end: info.duration),
          );
        case RecordingFormat.aac || null:
          await codec.trimStart(path, trimmed, start);
      }
      await moveFile(trimmed, path);
    } finally {
      await deleteQuietly(directory);
    }
  }

  int _previews = 0;

  /// Genera un WAV con la selección de [edit] y su volumen y fundidos
  /// aplicados, para escucharlo antes de guardar. Cada llamada usa un archivo
  /// nuevo (el anterior puede seguir sonando); se borran al cerrar la sesión.
  Future<String> renderPreview(EditSession session, AudioEdit edit) async {
    final path = p.join(session.directory.path, 'preview_${_previews++}.wav');
    await _process(session.sourcePath, path, edit);
    return path;
  }

  /// Lee el formato y la duración del archivo de [path] en su cabecera.
  Future<AudioProbe?> probe(String path) => probeAudio(path);

  /// Tasa de bits con la que se vuelve a codificar un AAC: la que indica su
  /// cabecera o, si no se puede leer, la de la calidad alta.
  Future<int> _bitRateOf(Recording recording) async {
    final known =
        recording.audio?.bitRate ??
        (await probe(await _audioPath(recording)))?.info.bitRate;
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
  /// una versión anterior de la app o se añadió desde el destino).
  Future<List<double>> extractWaveform(Recording recording) async {
    final directory = await _createSessionDirectory();
    try {
      final wav = p.join(directory.path, 'waveform.wav');
      await _decode(await _audioPath(recording), wav);
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

  Future<void> _renderPiano(
    String output,
    List<PianoNote> notes,
    Duration duration,
    int sampleRate,
  ) {
    if (!useIsolates) {
      return renderPianoWav(
        output: output,
        notes: notes,
        duration: duration,
        sampleRate: sampleRate,
      );
    }
    return _renderPianoInIsolate(output, notes, duration, sampleRate);
  }

  Future<void> _mixPiano(String input, String output, List<PianoNote> notes) {
    if (!useIsolates) {
      return mixPianoIntoWav(input: input, output: output, notes: notes);
    }
    return _mixPianoInIsolate(input, output, notes);
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

  static Future<void> _renderPianoInIsolate(
    String output,
    List<PianoNote> notes,
    Duration duration,
    int sampleRate,
  ) => Isolate.run(
    () => renderPianoWav(
      output: output,
      notes: notes,
      duration: duration,
      sampleRate: sampleRate,
    ),
  );

  static Future<void> _mixPianoInIsolate(
    String input,
    String output,
    List<PianoNote> notes,
  ) => Isolate.run(
    () => mixPianoIntoWav(input: input, output: output, notes: notes),
  );

  static Future<WavAnalysis> _processInIsolate(
    String input,
    String output,
    AudioEdit edit,
  ) => Isolate.run(() => processWav(input: input, output: output, edit: edit));
}
