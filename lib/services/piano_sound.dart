import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/instrument_tone.dart';
import '../audio/piano_headroom.dart';
import '../models/instrument.dart';
import '../models/synth_patch.dart';

/// Sonido de las teclas del piano. Abstraído para poder sustituirlo en los
/// tests.
abstract interface class PianoSound {
  /// Prepara el sonido de las teclas [keys] (números MIDI) con
  /// [instrument] (con el sintetizador, con el sonido de [synth]), para que
  /// suenen sin esperar al tocarlas.
  Future<void> prepare(
    Iterable<int> keys,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  });

  /// Toca la tecla [key] (número MIDI) con [instrument] (con el
  /// sintetizador, con el sonido de [synth]). Varias pueden sonar a la vez.
  Future<void> play(
    int key,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  });

  /// Se ha soltado la tecla [key]: si su instrumento es sostenido, deja de
  /// sonar.
  Future<void> release(int key);

  /// La tecla [key] deja de sonar ya, sea cual sea su instrumento.
  Future<void> stop(int key);

  Future<void> dispose();
}

/// Toca las notas con `audioplayers`: el sonido de cada tecla se sintetiza
/// la primera vez ([instrumentToneWav]) y se guarda en un archivo temporal.
///
/// Cada tecla tiene su reproductor, con su sonido ya cargado desde que se
/// prepara: al tocarla solo hay que empezar a sonar. (Con unos pocos
/// reproductores para todas, al tocar una tecla nueva había que cargar su
/// archivo, y en Android eso retrasaba la nota.)
///
/// El sistema suma los reproductores y recorta lo que se pasa del máximo,
/// que suena a ruido: el volumen de cada uno lo decide un limitador
/// ([PianoHeadroom]) con lo que suenan todas a la vez.
class AudioplayersPianoSound implements PianoSound {
  AudioplayersPianoSound({Future<Directory> Function()? directory})
    : _directoryProvider = directory ?? getTemporaryDirectory;

  /// Teclas con reproductor como mucho: más que las que caben a la vista.
  /// Al pasarse, se libera el de la que lleva más tiempo sin usarse.
  static const maxPlayers = 64;

  /// Se puede tocar mientras se graba la voz (en iOS, la sesión de audio
  /// es de grabar y reproducir) y junto a otra reproducción (sin quitarle el
  /// foco de audio en Android).
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.defaultToSpeaker,
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.allowBluetoothA2DP,
      },
    ),
  );

  /// Lo que puede sonar como mucho una nota sostenida mientras se mantiene
  /// la tecla.
  static const sustainedLength = Duration(seconds: 5);

  /// Cuánto tarda en apagarse el órgano al soltar la tecla.
  static const _organFadeOut = Duration(milliseconds: 60);

  /// Cada cuánto se baja el volumen al apagarse una nota.
  static const _fadeStep = Duration(milliseconds: 30);

  /// Cada cuánto se recalcula el volumen mientras suena alguna nota: menos
  /// que lo que mira por delante el limitador ([PianoHeadroom.lookahead]).
  static const _limitStep = Duration(milliseconds: 40);

  final Future<Directory> Function() _directoryProvider;

  /// El archivo de cada sonido, por su nombre (ver [_nameOf]).
  final _files = <String, Future<_Tone>>{};

  /// El volumen de las notas que suenan, para que juntas no saturen.
  final _headroom = PianoHeadroom();

  /// El reloj del limitador.
  final _clock = Stopwatch()..start();

  /// Recalcula el volumen mientras suena alguna nota.
  Timer? _limiter;

  /// El reproductor de cada tecla, de la usada hace más tiempo a la última.
  final _players = <int, _KeyPlayer>{};

  /// El sonido del sintetizador de los archivos que hay: al cambiarlo, se
  /// borran.
  SynthPatch? _synth;

  /// Las notas sostenidas que suenan: la pulsación de la tecla (si se
  /// vuelve a tocar, ya no es la misma) y lo que tarda en apagarse.
  final _sounding = <int, (int, Duration)>{};

  /// Nombre del archivo de [key] con [instrument], con la versión del
  /// sonido (por si cambia) y, con el sintetizador, su sonido.
  static String _nameOf(Instrument instrument, int key, SynthPatch synth) =>
      instrument == Instrument.synth
      ? 'v2_synth_${synth.id}_$key.wav'
      : 'v2_${instrument.name}_$key.wav';

  Future<_Tone> _fileFor(Instrument instrument, int key, SynthPatch synth) {
    if (instrument == Instrument.synth && synth != _synth) {
      _forgetSynth();
      _synth = synth;
    }
    return _files[_nameOf(instrument, key, synth)] ??= _write(
      instrument,
      key,
      synth,
    );
  }

  /// Borra los archivos de un sonido anterior del sintetizador.
  void _forgetSynth() {
    final old = [
      for (final name in _files.keys)
        if (name.startsWith('v2_synth_')) name,
    ];
    for (final name in old) {
      final file = _files.remove(name)!;
      unawaited(
        file
            .then((tone) => File(tone.path).delete())
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  Future<_Tone> _write(Instrument instrument, int key, SynthPatch synth) async {
    final directory = await _directoryProvider();
    final file = File(
      p.join(directory.path, 'piano', _nameOf(instrument, key, synth)),
    );
    final path = file.path;
    // En otro hilo, para no parar la pantalla al preparar muchas teclas.
    if (await file.exists()) {
      final envelope = await Isolate.run(
        () async => ToneEnvelope.ofWav(await File(path).readAsBytes()),
      );
      return _Tone(path, envelope);
    }
    await file.parent.create(recursive: true);
    final (wav, envelope) = await Isolate.run(() {
      final wav = instrumentToneWav(
        instrument,
        key,
        held: sustainedLength,
        synth: synth,
      );
      return (wav, ToneEnvelope.ofWav(wav));
    });
    await file.writeAsBytes(wav, flush: true);
    return _Tone(path, envelope);
  }

  /// Pone a cada reproductor de las teclas que suenan su volumen.
  void _applyVolumes() {
    for (final key in _headroom.keys) {
      final sound = _players[key];
      if (sound != null && !sound.disposed) {
        sound.setVolume(_headroom.volumeOf(key));
      }
    }
  }

  /// Mientras suena alguna nota, recalcula el volumen cada [_limitStep]:
  /// vuelve poco a poco a medida que se apagan.
  void _startLimiter() {
    _limiter ??= Timer.periodic(_limitStep, (_) {
      _headroom.update(_clock.elapsed);
      _applyVolumes();
      if (_headroom.isEmpty) {
        _limiter?.cancel();
        _limiter = null;
      }
    });
  }

  /// El reproductor de [key], que pasa a ser el último usado.
  _KeyPlayer _playerFor(int key) {
    final existing = _players.remove(key);
    if (existing != null) return _players[key] = existing;
    if (_players.length >= maxPlayers) {
      final oldest = _players.keys.first;
      _sounding.remove(oldest);
      _headroom.end(oldest);
      unawaited(_players.remove(oldest)!.dispose());
    }
    return _players[key] = _KeyPlayer(_context);
  }

  @override
  Future<void> prepare(
    Iterable<int> keys,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  }) async {
    for (final key in keys) {
      try {
        final tone = await _fileFor(instrument, key, synth);
        await _playerFor(key).load(tone.path);
      } catch (_) {
        // Se volverá a intentar al tocarla.
        _files.remove(_nameOf(instrument, key, synth));
      }
    }
  }

  @override
  Future<void> play(
    int key,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  }) async {
    final sound = _playerFor(key);
    final press = ++sound.presses;
    if (instrument.sustained) {
      _sounding[key] = (
        press,
        instrument == Instrument.synth ? synth.release : _organFadeOut,
      );
    } else {
      _sounding.remove(key);
    }
    try {
      final tone = await _fileFor(instrument, key, synth);
      await sound.load(tone.path);
      if (sound.presses != press || sound.disposed) return;
      // Con la nueva, el volumen de todas (antes de que empiece a sonar).
      _headroom.start(key, tone.envelope, _clock.elapsed);
      _applyVolumes();
      _startLimiter();
      await sound.start(press);
    } catch (_) {
      // Sin sonido no pasa nada grave: la tecla se sigue viendo pulsada.
      _files.remove(_nameOf(instrument, key, synth));
    }
  }

  @override
  Future<void> release(int key) async {
    final sounding = _sounding.remove(key);
    final sound = _players[key];
    if (sounding == null || sound == null) return;
    final (press, fadeOut) = sounding;
    // Se baja el volumen poco a poco (lo que tarda en apagarse) antes de
    // parar, para que no chasquee. Si se vuelve a tocar, se deja.
    final steps = (fadeOut.inMilliseconds / _fadeStep.inMilliseconds)
        .ceil()
        .clamp(2, 100);
    for (var step = steps - 1; step >= 0; step--) {
      if (sound.presses != press || sound.disposed) return;
      try {
        if (step == 0) {
          _headroom.end(key);
          await sound.player.stop();
        } else {
          // Como la relajación del sonido, que baja más deprisa al
          // principio.
          final left = step / steps;
          _headroom.fade(key, left * left);
          sound.setVolume(_headroom.volumeOf(key));
        }
      } catch (_) {}
      if (step > 0) {
        await Future<void>.delayed(fadeOut ~/ steps);
      }
    }
  }

  @override
  Future<void> stop(int key) async {
    _sounding.remove(key);
    _headroom.end(key);
    final sound = _players[key];
    if (sound == null || sound.disposed) return;
    // Si aún se estaba preparando para sonar, ya no suena.
    sound.presses++;
    try {
      await sound.player.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    final players = [..._players.values];
    _players.clear();
    _sounding.clear();
    _limiter?.cancel();
    _limiter = null;
    for (final sound in players) {
      await sound.dispose();
    }
  }
}

/// El archivo con el sonido de una tecla y cómo suena a lo largo del tiempo.
class _Tone {
  _Tone(this.path, this.envelope);

  final String path;
  final ToneEnvelope envelope;
}

/// El reproductor de una tecla, con el archivo de su sonido cargado.
class _KeyPlayer {
  _KeyPlayer(AudioContext context) {
    _queue = _setUp(context);
  }

  final player = AudioPlayer();

  /// Archivo que tiene (o va a tener) cargado.
  String? _path;

  /// Lo último que se le ha pedido (configurarlo o cargar un archivo): lo
  /// siguiente espera a que termine.
  late Future<void> _queue;

  /// Veces que se ha tocado (o parado: ver [AudioplayersPianoSound.stop]).
  var presses = 0;

  /// El último volumen que se le ha puesto.
  var _volume = 1.0;

  var disposed = false;

  Future<void> _setUp(AudioContext context) async {
    try {
      // Suena antes al tocar (en Android); si no se puede, en el normal.
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
    try {
      await player.setAudioContext(context);
    } catch (_) {}
    await player.setReleaseMode(ReleaseMode.stop);
  }

  /// Si ya se le ha cargado algún archivo.
  var _hasSource = false;

  /// Carga [path], si no lo tiene ya.
  ///
  /// Al cambiarlo (p. ej. al cambiar de instrumento), antes se libera: si
  /// no, al terminar de cargar el nuevo empezaría a sonar solo si el
  /// reproductor aún se tiene por sonando (en Android no se entera de que
  /// una nota ha terminado; en iOS, mientras no termina), y en Android, al
  /// volver a un sonido de antes, se quedaría con el último.
  Future<void> load(String path) {
    if (path != _path) {
      _path = path;
      _queue = _queue.catchError((_) {}).then((_) async {
        if (_hasSource) await player.release();
        _hasSource = true;
        await player.setSource(DeviceFileSource(path));
      });
      // Si falla, se vuelve a intentar la próxima vez.
      _queue.catchError((_) {
        if (_path == path) _path = null;
      });
    }
    return _queue;
  }

  /// Suena desde el principio, con el volumen que tenga, si sigue siendo la
  /// pulsación [press] (si se ha parado mientras se preparaba, no).
  Future<void> start(int press) async {
    if (presses != press) return;
    // Si aún suena, `resume` no haría nada.
    if (player.state == PlayerState.playing) await player.stop();
    if (presses != press) return;
    await player.resume();
  }

  /// Le pone el volumen [volume], si no lo tiene ya (se queda para las
  /// siguientes notas). Llega antes que lo que se le pida después: van en
  /// orden.
  void setVolume(double volume) {
    if ((volume - _volume).abs() < 0.005) return;
    _volume = volume;
    unawaited(player.setVolume(volume).then((_) {}, onError: (_) {}));
  }

  Future<void> dispose() async {
    disposed = true;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
