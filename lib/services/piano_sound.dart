import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/piano_tone.dart';

/// Sonido de las teclas del piano. Abstraído para poder sustituirlo en los
/// tests.
abstract interface class PianoSound {
  /// Prepara el sonido de las teclas [keys] (números MIDI), para que suenen
  /// sin esperar al tocarlas.
  Future<void> prepare(Iterable<int> keys);

  /// Toca la tecla [key] (número MIDI). Varias pueden sonar a la vez.
  Future<void> play(int key);

  Future<void> dispose();
}

/// Toca las notas con `audioplayers`: el sonido de cada tecla se sintetiza
/// la primera vez ([pianoToneWav]) y se guarda en un archivo temporal.
class AudioplayersPianoSound implements PianoSound {
  AudioplayersPianoSound({Future<Directory> Function()? directory})
    : _directoryProvider = directory ?? getTemporaryDirectory;

  /// Notas que pueden sonar a la vez (al tocar otra, se corta la más
  /// antigua).
  static const voices = 6;

  final Future<Directory> Function() _directoryProvider;
  final _files = <int, Future<String>>{};
  final _players = <AudioPlayer>[];
  var _next = 0;

  Future<String> _fileFor(int key) => _files[key] ??= _write(key);

  Future<String> _write(int key) async {
    final directory = await _directoryProvider();
    // Con la versión del sonido, por si cambia.
    final file = File(p.join(directory.path, 'piano', 'v1_$key.wav'));
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(pianoToneWav(key), flush: true);
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
      await player.setReleaseMode(ReleaseMode.stop);
      _players.add(player);
      return player;
    }
    final player = _players[_next];
    _next = (_next + 1) % voices;
    return player;
  }

  @override
  Future<void> prepare(Iterable<int> keys) async {
    for (final key in keys) {
      try {
        await _fileFor(key);
      } catch (_) {
        // Se volverá a intentar al tocarla.
        _files.remove(key);
      }
    }
  }

  @override
  Future<void> play(int key) async {
    try {
      final path = await _fileFor(key);
      final player = await _nextPlayer();
      await player.stop();
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // Sin sonido no pasa nada grave: la tecla se sigue viendo pulsada.
      _files.remove(key);
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
  }
}
