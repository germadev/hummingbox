import 'package:path/path.dart' as p;

/// Formato de archivo de las grabaciones.
enum RecordingFormat {
  /// AAC-LC en un contenedor MPEG-4: comprimido y compatible con cualquier
  /// dispositivo.
  aac('.m4a', 'audio/mp4'),

  /// PCM de 16 bits sin comprimir: la máxima fidelidad, pero ocupa mucho.
  wav('.wav', 'audio/wav');

  const RecordingFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

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

/// Calidad de las grabaciones: cuanto más alta, más ocupan.
enum RecordingQuality { low, medium, high }

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
    RecordingQuality.low => 16000,
    RecordingQuality.medium => 22050,
    RecordingQuality.high => 44100,
  };

  /// Tasa de bits por segundo. En WAV es la del audio sin comprimir.
  int get bitRate => switch (format) {
    RecordingFormat.aac => switch (quality) {
      RecordingQuality.low => 32000,
      RecordingQuality.medium => 64000,
      RecordingQuality.high => 128000,
    },
    RecordingFormat.wav => sampleRate * channels * 16,
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
    return RecordingOptions(
      format:
          RecordingFormat.values.asNameMap()[json['format']] ??
          RecordingFormat.aac,
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
