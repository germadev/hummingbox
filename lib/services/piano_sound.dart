import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/instrument_tone.dart';
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

  final Future<Directory> Function() _directoryProvider;

  /// El archivo de cada sonido, por su nombre (ver [_nameOf]).
  final _files = <String, Future<String>>{};

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

  Future<String> _fileFor(Instrument instrument, int key, SynthPatch synth) {
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
        file.then((path) => File(path).delete()).then((_) {}, onError: (_) {}),
      );
    }
  }

  Future<String> _write(
    Instrument instrument,
    int key,
    SynthPatch synth,
  ) async {
    final directory = await _directoryProvider();
    final file = File(
      p.join(directory.path, 'piano', _nameOf(instrument, key, synth)),
    );
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      // En otro hilo, para no parar la pantalla al preparar muchas teclas.
      final wav = await Isolate.run(
        () => instrumentToneWav(
          instrument,
          key,
          held: sustainedLength,
          synth: synth,
        ),
      );
      await file.writeAsBytes(wav, flush: true);
    }
    return file.path;
  }

  /// El reproductor de [key], que pasa a ser el último usado.
  _KeyPlayer _playerFor(int key) {
    final existing = _players.remove(key);
    if (existing != null) return _players[key] = existing;
    if (_players.length >= maxPlayers) {
      final oldest = _players.keys.first;
      _sounding.remove(oldest);
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
        final path = await _fileFor(instrument, key, synth);
        await _playerFor(key).load(path);
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
      await sound.load(await _fileFor(instrument, key, synth));
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
          await sound.player.stop();
        } else {
          // Como la relajación del sonido, que baja más deprisa al
          // principio.
          final left = step / steps;
          sound.faded = true;
          await sound.player.setVolume(left * left);
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
    for (final sound in players) {
      await sound.dispose();
    }
  }
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

  /// Si se le ha bajado el volumen al apagar una nota.
  var faded = false;

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

  /// Carga [path], si no lo tiene ya.
  Future<void> load(String path) {
    if (path != _path) {
      _path = path;
      _queue = _queue
          .catchError((_) {})
          .then((_) => player.setSource(DeviceFileSource(path)));
      // Si falla, se vuelve a intentar la próxima vez.
      _queue.catchError((_) {
        if (_path == path) _path = null;
      });
    }
    return _queue;
  }

  /// Suena desde el principio, con todo el volumen, si sigue siendo la
  /// pulsación [press] (si se ha parado mientras se preparaba, no).
  Future<void> start(int press) async {
    if (presses != press) return;
    // Si aún suena, `resume` no haría nada.
    if (player.state == PlayerState.playing) await player.stop();
    if (presses != press) return;
    if (faded) {
      faded = false;
      // Llega antes que `resume`: van en orden.
      unawaited(player.setVolume(1));
    }
    await player.resume();
  }

  Future<void> dispose() async {
    disposed = true;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
