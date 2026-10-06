import '../audio/audio_info.dart';
import '../audio/levels.dart';
import 'piano_note.dart';
import 'recording_options.dart';
import 'transcription.dart';

/// Una grabación de audio: dentro de la app o, si se eligió una, en la
/// carpeta del dispositivo.
class Recording {
  const Recording({
    required this.id,
    required this.path,
    required this.name,
    required this.createdAt,
    required this.duration,
    this.waveform,
    this.revision = 0,
    this.copies = const {},
    this.audio,
    this.folder = '',
    this.transcript,
    this.noAutoTranscript,
    this.transcriptionLanguage,
    this.provisionalName = false,
    this.notes = const [],
    bool hasVoice = true,
  }) : _voice = hasVoice;

  /// Clave de [copies] del archivo de la carpeta del dispositivo.
  static const folderKey = 'folder';

  /// Clave de [copies] del archivo de Google Drive.
  static const driveKey = 'drive';

  /// Construye una grabación a partir de los metadatos guardados en el índice.
  factory Recording.fromMetadata({
    required String id,
    required String path,
    required Map<String, dynamic> json,
  }) {
    final copies = json['copies'];
    return Recording(
      id: id,
      path: path,
      name: json['name'] as String? ?? id,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      waveform: decodeWaveform(json['waveform']),
      revision: json['revision'] as int? ?? 0,
      audio: AudioInfo.fromJson(json['audio']),
      folder: json['folder'] as String? ?? '',
      transcript: Transcript.fromJson(json['transcript']),
      noAutoTranscript: json['noAutoTranscript'] as int?,
      transcriptionLanguage: json['transcriptionLanguage'] as String?,
      provisionalName: json['provisionalName'] == true,
      notes: PianoNote.listFromJson(json['notes']),
      hasVoice: json['voice'] != false,
      copies: {
        if (copies is Map<String, dynamic>)
          for (final entry in copies.entries)
            entry.key: ?CopyState.fromJson(entry.value),
      },
    );
  }

  /// Identificador único: el nombre del archivo sin extensión.
  final String id;

  /// Ruta absoluta del audio dentro de la app. Si la grabación está guardada
  /// fuera (en la carpeta del dispositivo o en Google Drive, ver [copies]),
  /// el archivo solo existe mientras falta guardarla allí: para leer el audio
  /// se usa `StorageSync.audioPath`.
  final String path;

  /// Nombre visible, editable por el usuario.
  final String name;

  final DateTime createdAt;

  /// Duración de la grabación. Es [Duration.zero] si no se conoce.
  final Duration duration;

  /// Niveles (0–1) de la onda de toda la grabación, o `null` si todavía no se
  /// han calculado.
  final List<double>? waveform;

  /// Aumenta cada vez que se edita el audio, para saber qué copias están
  /// desactualizadas.
  final int revision;

  /// Archivos guardados fuera de la app, por destino ([folderKey],
  /// [driveKey]): donde se guarda la grabación y, si la hay, su copia.
  final Map<String, CopyState> copies;

  /// Formato y calidad del audio, leídos del archivo, o `null` si todavía no
  /// se han leído.
  final AudioInfo? audio;

  /// Subcarpeta en la que está (en la app y en la carpeta del dispositivo);
  /// vacío si está en la principal.
  final String folder;

  /// Texto de la grabación, si se ha transcrito.
  final Transcript? transcript;

  /// Revisión del audio que no se transcribe automáticamente: aquella en la
  /// que no se reconoció ninguna palabra o cuya transcripción se eliminó (en
  /// la app o borrando su `.txt`). Si se edita el audio, ya no cuenta.
  final int? noAutoTranscript;

  /// Idioma en que se transcribe, si se ha elegido para esta grabación: un
  /// código ISO 639-1 («es», «en»…) o `TranscriptionSettings.detectLanguage`.
  /// Si es `null`, el de las opciones.
  final String? transcriptionLanguage;

  /// Indica si [name] es el provisional que se le dio al crearla (la fecha y
  /// la hora, ver `RecordingNames`): al transcribirla por primera vez pasa a
  /// llamarse como empieza su transcripción. Si el usuario la renombra, ya
  /// no.
  final bool provisionalName;

  /// Notas tocadas en el piano mientras se grababa, en orden. Su sonido está
  /// en el audio, salvo si es solo de notas ([isNotesOnly]): entonces se
  /// genera con ellas al escucharla.
  final List<PianoNote> notes;

  final bool _voice;

  /// Indica si se grabó la voz (con el micrófono). Si no, es solo el piano.
  bool get hasVoice => _voice && !isNotesOnly;

  /// Indica si es solo de notas: se grabó solo el piano y su archivo es el
  /// `.mid` con las notas, sin audio.
  bool get isNotesOnly => format == RecordingFormat.midi;

  /// Indica si se debe transcribir automáticamente: tiene voz, no tiene
  /// transcripción y no se ha quedado sin ella a propósito (ver
  /// [noAutoTranscript]).
  bool get needsTranscript =>
      hasVoice && transcript == null && noAutoTranscript != revision;

  /// Indica si la transcripción es de otra versión del audio (si se editó o
  /// se cambió fuera de la app después de transcribirla).
  bool get isTranscriptOutdated =>
      transcript != null && transcript!.revision != revision;

  /// Formato del archivo según su extensión.
  RecordingFormat get format =>
      RecordingFormat.fromPath(path) ?? RecordingFormat.aac;

  /// Indica si el archivo del destino [key] tiene el audio y el nombre
  /// actuales (si no, falta guardarlos allí).
  bool isSavedIn(String key) => switch (copies[key]) {
    final file? => file.revision == revision && file.name == name,
    null => false,
  };

  /// Formato guardado en los metadatos de [json] (para las grabaciones cuyo
  /// audio no está dentro de la app).
  static RecordingFormat formatIn(Map<String, dynamic> json) =>
      RecordingFormat.values.asNameMap()[json['format']] ?? RecordingFormat.aac;

  Map<String, dynamic> toMetadata() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    if (format != RecordingFormat.aac) 'format': format.name,
    if (waveform != null) 'waveform': encodeWaveform(waveform!),
    if (revision != 0) 'revision': revision,
    if (audio != null) 'audio': audio!.toJson(),
    if (folder.isNotEmpty) 'folder': folder,
    if (transcript != null) 'transcript': transcript!.toJson(),
    if (noAutoTranscript != null) 'noAutoTranscript': noAutoTranscript,
    if (transcriptionLanguage != null)
      'transcriptionLanguage': transcriptionLanguage,
    if (provisionalName) 'provisionalName': true,
    if (notes.isNotEmpty) 'notes': [for (final note in notes) note.toJson()],
    if (!hasVoice) 'voice': false,
    if (copies.isNotEmpty)
      'copies': {
        for (final entry in copies.entries) entry.key: entry.value.toJson(),
      },
  };

  Recording copyWith({
    String? name,
    Duration? duration,
    List<double>? waveform,
    int? revision,
    Map<String, CopyState>? copies,
    AudioInfo? audio,
    Transcript? Function()? transcript,
    bool? provisionalName,
    List<PianoNote>? notes,
  }) {
    return Recording(
      id: id,
      path: path,
      name: name ?? this.name,
      createdAt: createdAt,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      revision: revision ?? this.revision,
      copies: copies ?? this.copies,
      audio: audio ?? this.audio,
      folder: folder,
      transcript: transcript == null ? this.transcript : transcript(),
      noAutoTranscript: noAutoTranscript,
      transcriptionLanguage: transcriptionLanguage,
      provisionalName: provisionalName ?? this.provisionalName,
      notes: notes ?? this.notes,
      hasVoice: hasVoice,
    );
  }
}

/// Archivo de una grabación fuera de la app: en la carpeta del dispositivo
/// (donde se guarda) o la copia de Google Drive.
class CopyState {
  const CopyState({
    required this.destination,
    required this.ref,
    required this.revision,
    required this.name,
    this.size,
    this.checksum,
    this.modified,
    this.transcript,
    this.midi,
  });

  /// Carpeta en la que está el archivo (la del dispositivo o la de Drive).
  final String destination;

  /// Referencia del archivo en el destino (URI, id de Drive…).
  final String ref;

  /// Revisión del audio que tiene el archivo.
  final int revision;

  /// Nombre de la grabación cuando se guardó el archivo.
  final String name;

  /// Tamaño del archivo la última vez que se guardó o se leyó la carpeta, si
  /// se conoce. Si cambia, es que se ha modificado fuera de la app.
  final int? size;

  /// Suma MD5 (en hexadecimal) del contenido del archivo, si se conoce. Si
  /// cambia, es que se ha modificado fuera de la app aunque tenga el mismo
  /// tamaño.
  final String? checksum;

  /// Fecha de modificación del archivo la última vez que se leyó el destino,
  /// si se conoce. En la carpeta del dispositivo, que no da la suma MD5 al
  /// listarla, si cambia se lee el archivo para comprobar si cambió [checksum].
  final DateTime? modified;

  /// Archivo `.txt` con la transcripción, junto al audio en el mismo
  /// destino, si se ha guardado o leído.
  final TranscriptFile? transcript;

  /// Archivo `.mid` con las notas del piano, junto al audio en el mismo
  /// destino, si se ha guardado o leído.
  final TranscriptFile? midi;

  /// El mismo archivo con los datos indicados cambiados.
  CopyState copyWith({
    String? ref,
    int? size,
    String? checksum,
    DateTime? modified,
  }) => CopyState(
    destination: destination,
    ref: ref ?? this.ref,
    revision: revision,
    name: name,
    size: size ?? this.size,
    checksum: checksum ?? this.checksum,
    modified: modified ?? this.modified,
    transcript: transcript,
    midi: midi,
  );

  /// El mismo archivo con [file] como archivo de la transcripción (o sin él,
  /// si es `null`).
  CopyState withTranscript(TranscriptFile? file) => CopyState(
    destination: destination,
    ref: ref,
    revision: revision,
    name: name,
    size: size,
    checksum: checksum,
    modified: modified,
    transcript: file,
    midi: midi,
  );

  /// El mismo archivo con [file] como archivo `.mid` de las notas (o sin él,
  /// si es `null`).
  CopyState withMidi(TranscriptFile? file) => CopyState(
    destination: destination,
    ref: ref,
    revision: revision,
    name: name,
    size: size,
    checksum: checksum,
    modified: modified,
    transcript: transcript,
    midi: file,
  );

  static CopyState? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final destination = json['destination'];
    final ref = json['ref'];
    final revision = json['revision'];
    final name = json['name'];
    final size = json['size'];
    final checksum = json['md5'];
    final modified = json['modified'];
    if (destination is! String ||
        ref is! String ||
        revision is! int ||
        name is! String) {
      return null;
    }
    return CopyState(
      destination: destination,
      ref: ref,
      revision: revision,
      name: name,
      size: size is int ? size : null,
      checksum: checksum is String ? checksum : null,
      modified: modified is int
          ? DateTime.fromMillisecondsSinceEpoch(modified)
          : null,
      transcript: TranscriptFile.fromJson(json['transcript']),
      midi: TranscriptFile.fromJson(json['midi']),
    );
  }

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'ref': ref,
    'revision': revision,
    'name': name,
    if (size != null) 'size': size,
    if (checksum != null) 'md5': checksum,
    if (modified != null) 'modified': modified!.millisecondsSinceEpoch,
    if (transcript != null) 'transcript': transcript!.toJson(),
    if (midi != null) 'midi': midi!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is CopyState &&
      other.destination == destination &&
      other.ref == ref &&
      other.revision == revision &&
      other.name == name &&
      other.size == size &&
      other.checksum == checksum &&
      other.modified?.millisecondsSinceEpoch ==
          modified?.millisecondsSinceEpoch &&
      other.transcript == transcript &&
      other.midi == midi;

  @override
  int get hashCode => Object.hash(
    destination,
    ref,
    revision,
    name,
    size,
    checksum,
    modified?.millisecondsSinceEpoch,
    transcript,
    midi,
  );
}

/// Archivo que acompaña al audio de una grabación en el destino, con su
/// mismo nombre: el `.txt` con la transcripción («Idea.txt» junto a
/// «Idea.m4a») o el `.mid` con las notas del piano («Idea.mid»).
class TranscriptFile {
  const TranscriptFile({
    required this.ref,
    required this.name,
    this.size,
    this.checksum,
    this.modified,
  });

  /// Referencia del archivo en el destino.
  final String ref;

  /// Nombre con el que se guardó, con la extensión.
  final String name;

  /// Tamaño, suma MD5 y fecha de modificación del archivo la última vez que
  /// se guardó o se leyó (para saber si se ha cambiado fuera de la app).
  final int? size;
  final String? checksum;
  final DateTime? modified;

  TranscriptFile copyWith({
    String? ref,
    String? name,
    int? size,
    String? checksum,
    DateTime? modified,
  }) => TranscriptFile(
    ref: ref ?? this.ref,
    name: name ?? this.name,
    size: size ?? this.size,
    checksum: checksum ?? this.checksum,
    modified: modified ?? this.modified,
  );

  static TranscriptFile? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final ref = json['ref'];
    final name = json['name'];
    final size = json['size'];
    final checksum = json['md5'];
    final modified = json['modified'];
    if (ref is! String || name is! String) return null;
    return TranscriptFile(
      ref: ref,
      name: name,
      size: size is int ? size : null,
      checksum: checksum is String ? checksum : null,
      modified: modified is int
          ? DateTime.fromMillisecondsSinceEpoch(modified)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'ref': ref,
    'name': name,
    if (size != null) 'size': size,
    if (checksum != null) 'md5': checksum,
    if (modified != null) 'modified': modified!.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is TranscriptFile &&
      other.ref == ref &&
      other.name == name &&
      other.size == size &&
      other.checksum == checksum &&
      other.modified?.millisecondsSinceEpoch ==
          modified?.millisecondsSinceEpoch;

  @override
  int get hashCode =>
      Object.hash(ref, name, size, checksum, modified?.millisecondsSinceEpoch);
}
