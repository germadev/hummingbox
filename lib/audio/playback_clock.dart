/// Por dónde va la reproducción en cada fotograma, sin los tirones de la
/// posición que da el reproductor.
///
/// El reproductor la da a destiempo (se le pregunta en cada fotograma y la
/// respuesta llega cuando llega), a saltos y, en Android, a veces un poco
/// hacia atrás. Mientras suena, aquí la posición avanza al ritmo del reloj
/// desde una referencia que se acerca poco a poco ([correction]) a lo que
/// dice el reproductor, así que la línea va a velocidad constante y nunca
/// retrocede. Si el reproductor se aleja mucho ([maxDrift], p. ej. al saltar
/// a otro punto), se pasa a lo que dice. Empieza a avanzar cuando lo hace el
/// reproductor (no mientras arranca) y, sin noticias suyas durante
/// [timeout], se para.
///
/// Los tiempos (`now`) son de un reloj cualquiera que no vuelva atrás (en la
/// app, el de los fotogramas).
class PlaybackClock {
  /// Diferencia con el reproductor a partir de la que se pasa a su posición.
  static const maxDrift = Duration(milliseconds: 300);

  /// Parte de la diferencia con el reproductor que se corrige con cada
  /// posición que da.
  static const correction = 0.1;

  /// Lo que se sigue avanzando sin que el reproductor dé otra posición.
  static const timeout = Duration(milliseconds: 500);

  /// La última posición que ha dado el reproductor, y cuándo.
  Duration _reported = Duration.zero;
  Duration _reportedAt = Duration.zero;

  /// Mientras avanza: la posición en [_anchorTime].
  Duration _anchor = Duration.zero;
  Duration _anchorTime = Duration.zero;
  bool _running = false;

  /// La última posición que se ha mostrado: mientras avanza, no se baja de
  /// ella.
  Duration _shown = Duration.zero;

  /// Si avanza con el reloj.
  bool get isRunning => _running;

  /// La última posición que se ha mostrado.
  Duration get shown => _shown;

  /// Sin sonar, la posición es [position] (al cargar, saltar o parar).
  void reset(Duration position) {
    _reported = position;
    _shown = position;
    _running = false;
  }

  /// Deja de sonar y el reproductor dice que va por [position]. Si es poco
  /// distinta de la que se ve (la última posición que dio llega con algo de
  /// retraso), la línea se queda donde está; si vuelve al principio (al
  /// parar) o es muy distinta, va a [position].
  void pause(Duration position) {
    _running = false;
    _reported = position;
    if (position == Duration.zero || (position - _shown).abs() > maxDrift) {
      _shown = position;
    }
  }

  /// Mientras suena, el reproductor dice que va por [position] en [now].
  void report(Duration position, Duration now) {
    final previous = _reported;
    final predicted = _running ? _predictedAt(now) : null;
    _reported = position;
    _reportedAt = now;
    if (predicted == null) {
      // Empieza a avanzar cuando avanza el reproductor; si salta hacia
      // atrás, se va con él.
      if (position > previous) {
        _running = true;
        _anchor = position;
        _anchorTime = now;
        if (position - _shown > maxDrift) _shown = position;
      } else if (position < previous) {
        _shown = position;
      }
      return;
    }
    final error = position - predicted;
    if (error.abs() > maxDrift) {
      // Ha saltado a otro punto (o se ha atascado): se va con él. Hacia
      // atrás, se espera a que vuelva a avanzar.
      _anchor = position;
      _anchorTime = now;
      _shown = position;
      _running = error > Duration.zero;
      return;
    }
    // Poco a poco hacia lo que dice el reproductor.
    _anchor = predicted + error * correction;
    _anchorTime = now;
  }

  /// Por dónde va en [now].
  Duration positionAt(Duration now) {
    if (!_running) return _shown;
    final position = _predictedAt(now);
    if (position > _shown) _shown = position;
    return _shown;
  }

  /// Si en [now] sigue avanzando (para dibujarla en cada fotograma).
  bool isAdvancingAt(Duration now) => _running && now - _reportedAt < timeout;

  /// La posición en [now] contando desde la referencia, sin pasar de
  /// [timeout] desde la última que dio el reproductor.
  Duration _predictedAt(Duration now) {
    final limit = _reportedAt + timeout;
    final until = now < limit ? now : limit;
    final elapsed = until - _anchorTime;
    return elapsed > Duration.zero ? _anchor + elapsed : _anchor;
  }
}
