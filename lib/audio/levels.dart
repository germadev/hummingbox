import 'dart:math' as math;

/// Nivel (en dBFS) que se considera silencio al normalizar la amplitud.
const silenceDb = -50.0;

/// Nivel (0–1) por debajo del cual se considera que no hay sonido: unos
/// -42 dBFS, el ruido de fondo de un micrófono.
const audibleLevel = 0.15;

/// Si [levels] (la onda de una grabación) tiene algo que se oiga. Sin onda
/// (`null`, si aún no se conoce o no se pudo leer), no.
bool hasAudio(List<double>? levels) =>
    levels != null && levels.any((level) => level >= audibleLevel);

/// Número de niveles que se guardan de la onda de cada grabación.
const waveformResolution = 100;

/// Convierte un nivel en dBFS a un valor entre 0 (silencio) y 1 (máximo).
double levelFromDb(double dbfs) {
  if (dbfs.isNaN) return 0;
  return ((dbfs - silenceDb) / -silenceDb).clamp(0.0, 1.0);
}

/// Convierte un pico lineal (0–1, donde 1 es el fondo de escala) a la misma
/// escala que [levelFromDb], para que la onda de un archivo se vea igual que
/// la que se dibuja mientras se graba.
double levelFromPeak(double peak) {
  if (peak <= 0 || peak.isNaN) return 0;
  return levelFromDb(20 * math.log(peak) / math.ln10);
}

/// Ajusta [levels] a [count] valores: si sobran, cada valor es el máximo de
/// su tramo (para no perder picos); si faltan, se interpola linealmente.
List<double> resampleLevels(List<double> levels, int count) {
  if (count <= 0) return const [];
  if (levels.isEmpty) return List.filled(count, 0);
  if (levels.length == count) return List.of(levels);

  if (levels.length > count) {
    return List.generate(count, (i) {
      final start = i * levels.length ~/ count;
      final end = math.max(start + 1, (i + 1) * levels.length ~/ count);
      var highest = 0.0;
      for (var j = start; j < end; j++) {
        if (levels[j] > highest) highest = levels[j];
      }
      return highest;
    });
  }

  if (levels.length == 1) return List.filled(count, levels.first);
  return List.generate(count, (i) {
    final position = i * (levels.length - 1) / (count - 1);
    final index = position.floor();
    if (index >= levels.length - 1) return levels.last;
    final fraction = position - index;
    return levels[index] + (levels[index + 1] - levels[index]) * fraction;
  });
}

/// Codifica la onda para guardarla en el índice: enteros de 0 a 100.
List<int> encodeWaveform(List<double> levels) => [
  for (final level in levels) (level.clamp(0.0, 1.0) * 100).round(),
];

/// Inverso de [encodeWaveform]. Devuelve `null` si el valor no es válido.
List<double>? decodeWaveform(Object? json) {
  if (json is! List || json.isEmpty) return null;
  final levels = <double>[];
  for (final value in json) {
    if (value is! num) return null;
    levels.add((value / 100).clamp(0.0, 1.0).toDouble());
  }
  return levels;
}
