import 'package:path/path.dart' as p;

/// Formato de archivo de las grabaciones.
enum RecordingFormat {
  /// AAC-LC en un contenedor MPEG-4: comprimido y compatible con cualquier
  /// dispositivo.
  aac('.m4a', 'audio/mp4'),

  /// PCM de 16 bits sin comprimir: la máxima fidelidad, pero ocupa mucho.
  wav('.wav', 'audio/wav'),

  /// MIDI estándar: solo las notas, sin audio. Es el archivo de las
  /// grabaciones hechas solo con el piano (ver `Recording.isNotesOnly`); su
  /// sonido se genera al escucharlas. No se graba en este formato.
  midi('.mid', 'audio/midi');

  const RecordingFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  /// Los formatos de audio, en los que se puede grabar.
  static const audio = [aac, wav];

  /// Indica si es de audio (no [midi]).
  bool get isAudio => this != midi;

  /// Formato de un archivo según su extensión, o `null` si no es de los que
  /// usa la app.
  static RecordingFormat? fromPath(String path) {
    final extension = p.extension(path).toLowerCase();
    for (final format in values) {
      if (format.extension == extension) return format;
    }
    return null;
  }
}

/// Calidad de las grabaciones, de la más baja a la más alta: cuanto más
/// alta, más ocupan.
enum RecordingQuality { minimum, low, medium, high, veryHigh, maximum }

/// Formato y calidad con los que se graban las grabaciones nuevas.
class RecordingOptions {
  const RecordingOptions({
    this.format = RecordingFormat.aac,
    this.quality = RecordingQuality.high,
  });

  final RecordingFormat format;
  final RecordingQuality quality;

  /// Se graba siempre en mono: es lo adecuado para voz y ocupa la mitad.
  static const channels = 1;

  /// Frecuencia de muestreo en hercios.
  int get sampleRate => switch (quality) {
    RecordingQuality.minimum => 8000,
    RecordingQuality.low => 16000,
    RecordingQuality.medium => 22050,
    RecordingQuality.high => 44100,
    RecordingQuality.veryHigh || RecordingQuality.maximum => 48000,
  };

  /// Tasa de bits por segundo. En WAV es la del audio sin comprimir.
  int get bitRate => switch (format) {
    RecordingFormat.aac => switch (quality) {
      RecordingQuality.minimum => 16000,
      RecordingQuality.low => 32000,
      RecordingQuality.medium => 64000,
      RecordingQuality.high => 128000,
      RecordingQuality.veryHigh => 192000,
      RecordingQuality.maximum => 256000,
    },
    RecordingFormat.wav => sampleRate * channels * 16,
    RecordingFormat.midi => 0,
  };

  /// Bytes que ocupa, aproximadamente, un minuto de grabación.
  int get bytesPerMinute => bitRate * 60 ~/ 8;

  RecordingOptions copyWith({
    RecordingFormat? format,
    RecordingQuality? quality,
  }) => RecordingOptions(
    format: format ?? this.format,
    quality: quality ?? this.quality,
  );

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'quality': quality.name,
  };

  /// Lee las opciones guardadas; lo que falte o no se reconozca toma el
  /// valor por defecto.
  factory RecordingOptions.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const RecordingOptions();
    final format = RecordingFormat.values.asNameMap()[json['format']];
    return RecordingOptions(
      format: format != null && format.isAudio ? format : RecordingFormat.aac,
      quality:
          RecordingQuality.values.asNameMap()[json['quality']] ??
          RecordingQuality.high,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecordingOptions &&
      other.format == format &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(format, quality);
}
