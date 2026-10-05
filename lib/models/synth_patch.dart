/// Forma de la onda de los osciladores del sintetizador.
enum SynthWave { saw, square, triangle, sine }

/// Cómo suena el sintetizador: la onda, la envolvente del volumen, el filtro
/// y cuánto se desafinan entre sí sus dos osciladores.
class SynthPatch {
  const SynthPatch({
    this.wave = SynthWave.saw,
    this.attack = const Duration(milliseconds: 8),
    this.decay = const Duration(milliseconds: 150),
    this.sustain = 0.75,
    this.release = const Duration(milliseconds: 300),
    this.brightness = 0.5,
    this.resonance = 0.3,
    this.detune = 6,
  });

  final SynthWave wave;

  /// Lo que tarda en llegar al máximo al pulsar la tecla.
  final Duration attack;

  /// Lo que tarda en bajar del máximo al nivel de [sustain].
  final Duration decay;

  /// Nivel mientras se mantiene la tecla, de 0 a 1.
  final double sustain;

  /// Lo que tarda en apagarse al soltar la tecla.
  final Duration release;

  /// Lo abierto que está el filtro, de 0 (apagado) a 1 (brillante).
  final double brightness;

  /// Lo que resuena el filtro en su frecuencia de corte, de 0 a 1.
  final double resonance;

  /// Desafinación entre los dos osciladores, en centésimas de semitono (de
  /// 0 a 50): engorda el sonido.
  final double detune;

  /// Límites de cada parámetro.
  static const minTime = Duration(milliseconds: 2);
  static const maxAttack = Duration(seconds: 2);
  static const maxDecay = Duration(seconds: 3);
  static const maxRelease = Duration(seconds: 3);
  static const maxDetune = 50.0;

  /// Identifica el sonido (p. ej. en el nombre de los archivos temporales):
  /// cambia si cambia cualquier parámetro.
  String get id => [
    wave.name,
    attack.inMilliseconds,
    decay.inMilliseconds,
    (sustain * 100).round(),
    release.inMilliseconds,
    (brightness * 100).round(),
    (resonance * 100).round(),
    detune.round(),
  ].join('-');

  SynthPatch copyWith({
    SynthWave? wave,
    Duration? attack,
    Duration? decay,
    double? sustain,
    Duration? release,
    double? brightness,
    double? resonance,
    double? detune,
  }) => SynthPatch(
    wave: wave ?? this.wave,
    attack: attack ?? this.attack,
    decay: decay ?? this.decay,
    sustain: sustain ?? this.sustain,
    release: release ?? this.release,
    brightness: brightness ?? this.brightness,
    resonance: resonance ?? this.resonance,
    detune: detune ?? this.detune,
  );

  Map<String, dynamic> toJson() => {
    'wave': wave.name,
    'attack': attack.inMilliseconds,
    'decay': decay.inMilliseconds,
    'sustain': sustain,
    'release': release.inMilliseconds,
    'brightness': brightness,
    'resonance': resonance,
    'detune': detune,
  };

  /// Lo que no se entiende o se sale de los límites, por defecto o en el
  /// límite.
  static SynthPatch fromJson(Object? json) {
    const defaults = SynthPatch();
    if (json is! Map) return defaults;
    Duration time(Object? value, Duration max, Duration fallback) =>
        value is int
        ? Duration(
            milliseconds: value.clamp(
              minTime.inMilliseconds,
              max.inMilliseconds,
            ),
          )
        : fallback;
    double level(Object? value, double max, double fallback) =>
        value is num ? value.toDouble().clamp(0, max) : fallback;
    return SynthPatch(
      wave: SynthWave.values.asNameMap()[json['wave']] ?? defaults.wave,
      attack: time(json['attack'], maxAttack, defaults.attack),
      decay: time(json['decay'], maxDecay, defaults.decay),
      sustain: level(json['sustain'], 1, defaults.sustain),
      release: time(json['release'], maxRelease, defaults.release),
      brightness: level(json['brightness'], 1, defaults.brightness),
      resonance: level(json['resonance'], 1, defaults.resonance),
      detune: level(json['detune'], maxDetune, defaults.detune),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SynthPatch &&
      other.wave == wave &&
      other.attack == attack &&
      other.decay == decay &&
      other.sustain == sustain &&
      other.release == release &&
      other.brightness == brightness &&
      other.resonance == resonance &&
      other.detune == detune;

  @override
  int get hashCode => Object.hash(
    wave,
    attack,
    decay,
    sustain,
    release,
    brightness,
    resonance,
    detune,
  );
}
