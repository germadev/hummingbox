import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/instrument_tone.dart';
import '../models/instrument.dart';

/// Sonido de las teclas del piano. Abstraído para poder sustituirlo en los
/// tests.
abstract interface class PianoSound {
  /// Prepara el sonido de las teclas [keys] (números MIDI) con
  /// [instrument], para que suenen sin esperar al tocarlas.
  Future<void> prepare(Iterable<int> keys, Instrument instrument);

  /// Toca la tecla [key] (número MIDI) con [instrument]. Varias pueden sonar
  /// a la vez.
  Future<void> play(int key, Instrument instrument);

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

  /// Cuánto tarda en apagarse una nota sostenida al soltar la tecla.
  static const _fadeOut = Duration(milliseconds: 60);

  final Future<Directory> Function() _directoryProvider;
  final _files = <(Instrument, int), Future<String>>{};
  final _players = <AudioPlayer>[];
  var _next = 0;

  /// Las notas sostenidas que suenan: el reproductor de cada una y la vez
  /// que se usó (si se reutiliza para otra nota, ya no es suya).
  final _sounding = <int, List<(AudioPlayer, int)>>{};
  final _uses = <AudioPlayer, int>{};

  Future<String> _fileFor(Instrument instrument, int key) =>
      _files[(instrument, key)] ??= _write(instrument, key);

  Future<String> _write(Instrument instrument, int key) async {
    final directory = await _directoryProvider();
    // Con la versión del sonido, por si cambia.
    final file = File(
      p.join(directory.path, 'piano', 'v2_${instrument.name}_$key.wav'),
    );
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        instrumentToneWav(instrument, key, held: sustainedLength),
        flush: true,
      );
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
  Future<void> prepare(Iterable<int> keys, Instrument instrument) async {
    for (final key in keys) {
      try {
        await _fileFor(instrument, key);
      } catch (_) {
        // Se volverá a intentar al tocarla.
        _files.remove((instrument, key));
      }
    }
  }

  @override
  Future<void> play(int key, Instrument instrument) async {
    try {
      final path = await _fileFor(instrument, key);
      final player = await _nextPlayer();
      final use = (_uses[player] ?? 0) + 1;
      _uses[player] = use;
      await player.stop();
      await player.setVolume(1);
      if (instrument.sustained) {
        (_sounding[key] ??= []).add((player, use));
      }
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // Sin sonido no pasa nada grave: la tecla se sigue viendo pulsada.
      _files.remove((instrument, key));
    }
  }

  @override
  Future<void> release(int key) async {
    final sounding = _sounding.remove(key);
    if (sounding == null) return;
    // Se baja el volumen en unos pasos antes de parar, para que no chasquee.
    const steps = 4;
    for (var step = steps - 1; step >= 0; step--) {
      for (final (player, use) in sounding) {
        if (_uses[player] != use) continue;
        try {
          if (step == 0) {
            await player.stop();
          } else {
            await player.setVolume(step / steps);
          }
        } catch (_) {}
      }
      if (step > 0) {
        await Future<void>.delayed(_fadeOut ~/ steps);
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
