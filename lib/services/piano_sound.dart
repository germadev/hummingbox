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

  Future<void> dispose();
}

/// Toca las notas con `audioplayers`: el sonido de cada tecla se sintetiza
/// la primera vez ([instrumentToneWav]) y se guarda en un archivo temporal.
class AudioplayersPianoSound implements PianoSound {
  AudioplayersPianoSound({Future<Directory> Function()? directory})
    : _directoryProvider = directory ?? getTemporaryDirectory;

  /// Notas que pueden sonar a la vez (al tocar otra, se corta la más
  /// antigua).
  static const voices = 6;

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
  final _players = <AudioPlayer>[];
  var _next = 0;

  /// El sonido del sintetizador de los archivos que hay: al cambiarlo, se
  /// borran.
  SynthPatch? _synth;

  /// Las notas sostenidas que suenan: el reproductor de cada una, la vez que
  /// se usó (si se reutiliza para otra nota, ya no es suya) y lo que tarda
  /// en apagarse.
  final _sounding = <int, List<(AudioPlayer, int, Duration)>>{};
  final _uses = <AudioPlayer, int>{};

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

  Future<AudioPlayer> _nextPlayer() async {
    if (_players.length < voices) {
      final player = AudioPlayer();
      try {
        // Suena antes al tocar (en Android); si no se puede, en el normal.
        await player.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
      try {
        await player.setAudioContext(_context);
      } catch (_) {}
      await player.setReleaseMode(ReleaseMode.stop);
      _players.add(player);
      return player;
    }
    final player = _players[_next];
    _next = (_next + 1) % voices;
    return player;
  }

  @override
  Future<void> prepare(
    Iterable<int> keys,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  }) async {
    for (final key in keys) {
      try {
        await _fileFor(instrument, key, synth);
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
    try {
      final path = await _fileFor(instrument, key, synth);
      final player = await _nextPlayer();
      final use = (_uses[player] ?? 0) + 1;
      _uses[player] = use;
      await player.stop();
      await player.setVolume(1);
      if (instrument.sustained) {
        final fadeOut = instrument == Instrument.synth
            ? synth.release
            : _organFadeOut;
        (_sounding[key] ??= []).add((player, use, fadeOut));
      }
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // Sin sonido no pasa nada grave: la tecla se sigue viendo pulsada.
      _files.remove(_nameOf(instrument, key, synth));
    }
  }

  @override
  Future<void> release(int key) async {
    final sounding = _sounding.remove(key);
    if (sounding == null) return;
    // Se baja el volumen poco a poco (lo que tarda en apagarse) antes de
    // parar, para que no chasquee.
    final fadeOut = sounding
        .map((sound) => sound.$3)
        .reduce((a, b) => a > b ? a : b);
    final steps = (fadeOut.inMilliseconds / _fadeStep.inMilliseconds)
        .ceil()
        .clamp(2, 100);
    for (var step = steps - 1; step >= 0; step--) {
      for (final (player, use, _) in sounding) {
        if (_uses[player] != use) continue;
        try {
          if (step == 0) {
            await player.stop();
          } else {
            // Como la relajación del sonido, que baja más deprisa al
            // principio.
            final left = step / steps;
            await player.setVolume(left * left);
          }
        } catch (_) {}
      }
      if (step > 0) {
        await Future<void>.delayed(fadeOut ~/ steps);
      }
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    _sounding.clear();
  }
}
