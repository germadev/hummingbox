import 'dart:math' as math;

/// Detecta cuándo alguien empieza a hablar a partir del nivel del micrófono
/// (en dBFS, uno cada 100 ms).
///
/// Compara cada nivel con el ruido de fondo, que se estima sobre la marcha:
/// durante los primeros [warmUp] niveles se ajusta deprisa (el micrófono tarda
/// en estabilizarse y no se detecta nada); después baja enseguida con los
/// niveles más bajos y sube despacio con los altos, para que la propia voz no
/// lo arrastre. Hay voz cuando [requiredLoud] niveles seguidos superan el
/// ruido en [marginDb] y, además, el mínimo absoluto [minimumDb] (así, en una
/// habitación muy silenciosa, un roce no basta).
class VoiceDetector {
  VoiceDetector({
    this.marginDb = 12,
    this.minimumDb = -45,
    this.requiredLoud = 2,
    this.warmUp = 5,
  });

  final double marginDb;
  final double minimumDb;
  final int requiredLoud;
  final int warmUp;

  /// Por debajo de este nivel no hay datos (el micrófono aún no da señal).
  static const _floorDb = -100.0;

  double? _noise;
  int _count = 0;
  int _loud = 0;

  /// Ruido de fondo estimado, en dBFS.
  double? get noiseDb => _noise;

  /// Añade un nivel. Devuelve `true` cuando detecta voz.
  bool add(double dbfs) {
    if (dbfs.isNaN || dbfs <= _floorDb) return false;
    final level = math.min(dbfs, 0.0);
    _count++;

    final noise = _noise ?? level;
    final warmingUp = _count <= warmUp;
    if (!warmingUp && level >= math.max(noise + marginDb, minimumDb)) {
      _loud++;
      if (_loud >= requiredLoud) return true;
    } else {
      _loud = 0;
    }

    final rate = warmingUp || level < noise ? 0.5 : 0.05;
    _noise = noise + (level - noise) * rate;
    return false;
  }
}
