/// Con qué se transcriben las grabaciones.
enum TranscriptionEngine {
  /// El reconocimiento de voz del sistema (en Android, 13 o superior).
  system,

  /// Whisper, en el dispositivo, con un modelo que hay que descargar.
  whisper,
}

/// Modelos de Whisper que se pueden descargar.
enum WhisperModel {
  /// El más rápido y el menos preciso.
  tiny(bytes: 77691713),

  /// Más preciso, algo más lento.
  base(bytes: 147951465);

  const WhisperModel({required this.bytes});

  /// Tamaño de la descarga.
  final int bytes;
}

/// Opciones de la transcripción.
class TranscriptionSettings {
  const TranscriptionSettings({
    this.engine = TranscriptionEngine.system,
    this.language = appLanguage,
    this.automatic = true,
  });

  /// Valor de [language] para usar el idioma de la app.
  static const appLanguage = '';

  /// Valor de [language] para que Whisper lo detecte (el reconocimiento del
  /// sistema usa entonces el de la app).
  static const detectLanguage = 'auto';

  final TranscriptionEngine engine;

  /// Idioma de las grabaciones: [appLanguage], [detectLanguage] o un código
  /// ISO 639-1 («es», «en»…).
  final String language;

  /// Si se transcriben solas, en segundo plano, las grabaciones que no
  /// tienen transcripción.
  final bool automatic;

  TranscriptionSettings copyWith({
    TranscriptionEngine? engine,
    String? language,
    bool? automatic,
  }) => TranscriptionSettings(
    engine: engine ?? this.engine,
    language: language ?? this.language,
    automatic: automatic ?? this.automatic,
  );

  Map<String, dynamic> toJson() => {
    'engine': engine.name,
    if (language != appLanguage) 'language': language,
    if (!automatic) 'automatic': false,
  };

  factory TranscriptionSettings.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const TranscriptionSettings();
    final language = json['language'];
    return TranscriptionSettings(
      engine:
          TranscriptionEngine.values.asNameMap()[json['engine']] ??
          TranscriptionEngine.system,
      language: language is String ? language : appLanguage,
      automatic: json['automatic'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TranscriptionSettings &&
      other.engine == engine &&
      other.language == language &&
      other.automatic == automatic;

  @override
  int get hashCode => Object.hash(engine, language, automatic);
}

/// Texto de una grabación, obtenido con el reconocimiento de voz.
class Transcript {
  const Transcript({
    required this.text,
    required this.revision,
    required this.createdAt,
    this.engine,
    this.model,
    this.language,
  });

  final String text;

  /// Con qué se transcribió, o `null` si no se sabe (p. ej. si se leyó del
  /// archivo `.txt` del destino).
  final TranscriptionEngine? engine;

  /// Modelo de Whisper con el que se transcribió, si fue con Whisper.
  final WhisperModel? model;

  /// Idioma con el que se transcribió (p. ej. «es-ES» o, si Whisper lo
  /// detectó, «es»), si se conoce.
  final String? language;

  /// Revisión del audio que se transcribió: si la grabación se ha editado o
  /// cambiado después, el texto puede no corresponder.
  final int revision;

  final DateTime createdAt;

  static Transcript? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final text = json['text'];
    final engine = TranscriptionEngine.values.asNameMap()[json['engine']];
    final revision = json['revision'];
    final language = json['language'];
    if (text is! String || revision is! int) return null;
    return Transcript(
      text: text,
      engine: engine,
      model: WhisperModel.values.asNameMap()[json['model']],
      language: language is String ? language : null,
      revision: revision,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (engine != null) 'engine': engine!.name,
    if (model != null) 'model': model!.name,
    if (language != null) 'language': language,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Transcript &&
      other.text == text &&
      other.engine == engine &&
      other.model == model &&
      other.language == language &&
      other.revision == revision &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(text, engine, model, language, revision, createdAt);
}
