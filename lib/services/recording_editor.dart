import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_edit.dart';
import '../audio/audio_info.dart';
import '../audio/levels.dart';
import '../audio/midi.dart';
import '../audio/piano_mix.dart';
import '../audio/instrument_tone.dart';
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
///
/// Las grabaciones solo de notas ([Recording.isNotesOnly]) no tienen audio:
/// su archivo es un `.mid`, y su sonido se genera con las notas para
/// escucharlas ([pianoAudio]) o editarlas. Al editarlas solo se recortan
/// las notas.
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

  /// Frecuencia de muestreo del sonido de las grabaciones solo de notas.
  static const pianoSampleRate = 44100;

  /// Lo que dura el sonido de [notes] tocadas durante [duration]: hasta que
  /// se apaga la última, si suena más allá.
  static Duration pianoLength(List<PianoNote> notes, Duration duration) {
    var length = duration;
    for (final note in notes) {
      final end =
          note.start +
          toneLength(note.instrument, note.duration, synth: note.synth);
      if (end > length) length = end;
    }
    return length;
  }

  Future<EditSession> open(Recording recording) async {
    final directory = await _createSessionDirectory();
    try {
      final source = p.join(directory.path, 'source.wav');
      if (recording.isNotesOnly) {
        await _renderNotes(recording, source);
      } else {
        await _decode(await _audioPath(recording), source);
      }
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
    if (recording.isNotesOnly) {
      return _saveNotes(session, edit, asCopy: asCopy, copyName: copyName);
    }
    final edited = p.join(session.directory.path, 'edited.wav');
    final result = await _process(session.sourcePath, edited, edit);

    // Se conserva el formato de la grabación y, en AAC, su tasa de bits.
    final format = recording.format;
    final String output;
    switch (format) {
      case RecordingFormat.wav || RecordingFormat.midi:
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

  /// Guarda en una grabación de notas ([Recording.isNotesOnly]) de la
  /// subcarpeta [folder] las [notes] tocadas en el piano (sin voz) durante
  /// [duration]: un `.mid`, sin audio. Si la última nota suena más allá,
  /// dura hasta que se apaga.
  Future<Recording> savePiano({
    required List<PianoNote> notes,
    required Duration duration,
    String folder = '',
  }) async {
    final path = await repository.createRecordingPath(
      format: RecordingFormat.midi,
    );
    await File(path).writeAsBytes(Midi.encode(notes), flush: true);
    final recording = await repository.add(
      path: path,
      duration: pianoLength(notes, duration),
      folder: folder,
      notes: notes,
      hasVoice: false,
    );
    if (recording == null) throw StateError('No se pudo registrar');
    return recording;
  }

  /// Guarda la edición de una grabación solo de notas: las notas que quedan
  /// entre el principio y el final de [edit] (el volumen y los fundidos no
  /// se aplican), en ella o, si [asCopy], en una nueva.
  Future<Recording> _saveNotes(
    EditSession session,
    AudioEdit edit, {
    required bool asCopy,
    String? copyName,
  }) async {
    final recording = session.recording;
    final notes = PianoNote.between(recording.notes, edit.start, edit.end);
    final output = p.join(session.directory.path, 'edited.mid');
    await File(output).writeAsBytes(Midi.encode(notes), flush: true);
    if (!asCopy) {
      final replaced = await repository.replaceAudio(
        recording,
        sourcePath: output,
        duration: edit.length,
      );
      return repository.setNotes(replaced, notes);
    }
    final path = await repository.createRecordingPath(
      format: RecordingFormat.midi,
    );
    await moveFile(output, path);
    final copy = await repository.add(
      path: path,
      duration: edit.length,
      name: copyName ?? '${recording.name}$copySuffix',
      folder: recording.folder,
      notes: notes,
      hasVoice: false,
    );
    if (copy == null) throw StateError('No se pudo registrar la copia');
    return copy;
  }

  /// Lee las notas del `.mid` de [recording], una grabación solo de notas
  /// añadida desde el destino o cambiada fuera de la app, y las guarda con
  /// la duración de su sonido.
  Future<Recording> readNotes(Recording recording) async {
    final bytes = await File(await _audioPath(recording)).readAsBytes();
    final notes = Midi.decode(bytes);
    final updated = await repository.setNotes(recording, notes);
    return repository.setDetails(
      updated,
      duration: pianoLength(notes, Duration.zero),
    );
  }

  /// Sonidos de las grabaciones solo de notas que se están generando, por
  /// ruta.
  final _renderingNotes = <String, Future<String>>{};

  /// Ruta de un WAV con el sonido de [recording], una grabación solo de
  /// notas ([Recording.isNotesOnly]), para escucharla o compartirla. Se
  /// genera la primera vez y se reutiliza mientras no cambien sus notas.
  Future<String> pianoAudio(Recording recording) async {
    final key = md5
        .convert(
          utf8.encode(
            jsonEncode([
              recording.duration.inMilliseconds,
              for (final note in recording.notes) note.toJson(),
            ]),
          ),
        )
        .toString();
    final directory = Directory(p.join((await _workDirectory()).path, 'piano'));
    final path = p.join(directory.path, '${recording.id}.$key.wav');
    if (File(path).existsSync()) return path;
    return _renderingNotes[path] ??= () async {
      try {
        await directory.create(recursive: true);
        final partial = '$path.part';
        await _renderNotes(recording, partial);
        await File(partial).rename(path);
        // Los de notas anteriores ya no sirven.
        for (final entity in directory.listSync()) {
          if (entity is File &&
              entity.path != path &&
              !entity.path.endsWith('.part') &&
              p.basename(entity.path).startsWith('${recording.id}.')) {
            try {
              await entity.delete();
            } on FileSystemException {
              // Es un temporal: lo borrará el sistema.
            }
          }
        }
        return path;
      } finally {
        _renderingNotes.remove(path);
      }
    }();
  }

  /// Escribe en [output] el sonido de las notas de [recording].
  Future<void> _renderNotes(Recording recording, String output) => _renderPiano(
    output,
    recording.notes,
    pianoLength(recording.notes, recording.duration),
    pianoSampleRate,
  );

  /// Añade al audio de [recording] las [notes] tocadas en el piano mientras
  /// se grababa (o mientras sonaba, al acompañarla), y las guarda con ella
  /// junto a las que ya tuviera. La onda sigue siendo la de antes.
  Future<Recording> addPiano(Recording recording, List<PianoNote> notes) async {
    if (notes.isEmpty) return recording;
    final all = [...recording.notes, ...notes]
      ..sort((a, b) => a.start.compareTo(b.start));
    final directory = await _createSessionDirectory();
    try {
      if (recording.isNotesOnly) {
        // Sin audio: solo se añaden las notas a su `.mid`.
        final output = p.join(directory.path, 'notes.mid');
        await File(output).writeAsBytes(Midi.encode(all), flush: true);
        final replaced = await repository.replaceAudio(
          recording,
          sourcePath: output,
          duration: pianoLength(all, recording.duration),
        );
        return await repository.setNotes(replaced, all);
      }
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
      return await repository.setNotes(replaced, all);
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
      case RecordingFormat.wav || RecordingFormat.midi:
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
        case RecordingFormat.aac || RecordingFormat.midi || null:
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
