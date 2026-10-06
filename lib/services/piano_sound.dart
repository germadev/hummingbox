import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:voicerecorder_native/voicerecorder_native.dart';

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

/// Toca las notas con el mezclador nativo ([NativePiano]): todas salen por
/// un solo flujo de audio, que las suma sin pasarse del máximo, apaga la
/// nota anterior de una tecla al volver a tocarla y baja el volumen al
/// soltarla muestra a muestra.
///
/// (Con un reproductor de `audioplayers` por tecla, el sistema sumaba los
/// reproductores, cortaba en seco la nota al volver a tocar la tecla y los
/// cambios de volumen iban a saltos: sonaban chasquidos.)
///
/// El sonido de cada tecla se sintetiza la primera vez
/// ([instrumentToneWav]), a la frecuencia de la salida, y se guarda en un
/// archivo temporal que el mezclador lee una vez.
class NativePianoSound implements PianoSound {
  NativePianoSound({
    this._engine = const NativePiano(),
    Future<Directory> Function()? directory,
  }) : _directoryProvider = directory ?? getTemporaryDirectory;

  /// Sonidos cargados en el mezclador como mucho: más que las teclas que
  /// caben a la vista. Al pasarse, se olvida el usado hace más tiempo.
  static const maxLoaded = 96;

  /// Lo que puede sonar como mucho una nota sostenida mientras se mantiene
  /// la tecla.
  static const sustainedLength = Duration(seconds: 5);

  /// Cuánto tarda en apagarse el órgano al soltar la tecla.
  static const organFadeOut = Duration(milliseconds: 60);

  /// Versión del sonido en el nombre de los archivos (por si cambia).
  static const _version = 'v3';

  final NativePiano _engine;
  final Future<Directory> Function() _directoryProvider;

  /// La frecuencia de la salida, cuando se ha puesto en marcha.
  int? _sampleRate;

  /// La ruta del archivo de cada sonido, por su nombre (ver [_nameOf]).
  final _files = <String, Future<String>>{};

  /// Los sonidos cargados en el mezclador, por su ruta, del usado hace más
  /// tiempo al último.
  final _loaded = <String, Future<void>>{};

  /// El sonido del sintetizador de los archivos que hay: al cambiarlo, se
  /// borran.
  SynthPatch? _synth;

  /// Veces que se ha tocado (o parado) cada tecla: si se vuelve a tocar o
  /// se para mientras se prepara su sonido, la nota anterior ya no suena.
  final _presses = <int, int>{};

  /// La última pulsación de cada tecla que ha empezado a sonar.
  final _started = <int, int>{};

  /// Las teclas sostenidas que se mantienen pulsadas: su pulsación y lo que
  /// tardan en apagarse.
  final _held = <int, (int, Duration)>{};

  /// Si ya se han borrado los archivos de versiones anteriores.
  var _cleaned = false;

  /// Pone en marcha la salida (si se había parado) y devuelve su
  /// frecuencia.
  Future<int> _open() async {
    final sampleRate = _sampleRate = await _engine.open();
    if (!_cleaned) {
      _cleaned = true;
      unawaited(_deleteOldFiles());
    }
    return sampleRate;
  }

  /// Nombre del archivo de [key] con [instrument] a [sampleRate], con la
  /// versión del sonido y, con el sintetizador, su sonido.
  static String _nameOf(
    Instrument instrument,
    int key,
    SynthPatch synth,
    int sampleRate,
  ) => instrument == Instrument.synth
      ? '${_version}_${sampleRate}_synth_${synth.id}_$key.wav'
      : '${_version}_${sampleRate}_${instrument.name}_$key.wav';

  Future<String> _fileFor(
    Instrument instrument,
    int key,
    SynthPatch synth,
    int sampleRate,
  ) {
    if (instrument == Instrument.synth && synth != _synth) {
      _forgetSynth();
      _synth = synth;
    }
    final name = _nameOf(instrument, key, synth, sampleRate);
    final file = _files[name] ??= _write(
      name,
      instrument,
      key,
      synth,
      sampleRate,
    );
    // Si falla, se vuelve a intentar la próxima vez.
    unawaited(
      file.then(
        (_) {},
        onError: (_) {
          if (identical(_files[name], file)) _files.remove(name);
        },
      ),
    );
    return file;
  }

  /// Borra los archivos de un sonido anterior del sintetizador y los
  /// olvida en el mezclador.
  void _forgetSynth() {
    final old = [
      for (final name in _files.keys)
        if (name.contains('_synth_')) name,
    ];
    for (final name in old) {
      final file = _files.remove(name)!;
      unawaited(
        file
            .then((path) async {
              _loaded.remove(path);
              await _engine.unload([path]);
              await File(path).delete();
            })
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  Future<String> _write(
    String name,
    Instrument instrument,
    int key,
    SynthPatch synth,
    int sampleRate,
  ) async {
    final directory = await _directoryProvider();
    final file = File(p.join(directory.path, 'piano', name));
    if (await file.exists()) return file.path;
    await file.parent.create(recursive: true);
    // En otro hilo, para no parar la pantalla al preparar muchas teclas.
    final wav = await Isolate.run(
      () => instrumentToneWav(
        instrument,
        key,
        held: sustainedLength,
        synth: synth,
        sampleRate: sampleRate,
      ),
    );
    // Aparte y luego con su nombre: si la app se cierra a medias, no queda
    // un sonido cortado.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(wav, flush: true);
    await partial.rename(file.path);
    return file.path;
  }

  /// Borra los sonidos de versiones anteriores.
  Future<void> _deleteOldFiles() async {
    try {
      final directory = Directory(
        p.join((await _directoryProvider()).path, 'piano'),
      );
      if (!await directory.exists()) return;
      await for (final entry in directory.list()) {
        if (entry is File && !p.basename(entry.path).startsWith(_version)) {
          await entry.delete();
        }
      }
    } catch (_) {}
  }

  /// Carga en el mezclador el sonido de [path], si no lo está ya, y lo
  /// marca como el último usado.
  Future<void> _load(String path) {
    final loading = _loaded.remove(path) ?? _engine.load(path);
    _loaded[path] = loading;
    unawaited(
      loading.then(
        (_) {},
        onError: (_) {
          if (identical(_loaded[path], loading)) _loaded.remove(path);
        },
      ),
    );
    if (_loaded.length > maxLoaded) {
      final oldest = _loaded.keys.first;
      _loaded.remove(oldest);
      unawaited(_engine.unload([oldest]).then((_) {}, onError: (_) {}));
    }
    return loading;
  }

  @override
  Future<void> prepare(
    Iterable<int> keys,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  }) async {
    final int sampleRate;
    try {
      sampleRate = await _open();
    } catch (_) {
      // Se volverá a intentar al tocar.
      return;
    }
    for (final key in keys) {
      try {
        await _load(await _fileFor(instrument, key, synth, sampleRate));
      } catch (_) {
        // Se volverá a intentar al tocarla.
      }
    }
  }

  @override
  Future<void> play(
    int key,
    Instrument instrument, {
    SynthPatch synth = const SynthPatch(),
  }) async {
    final press = _presses[key] = (_presses[key] ?? 0) + 1;
    final fadeOut = instrument == Instrument.synth
        ? synth.release
        : organFadeOut;
    if (instrument.sustained) {
      _held[key] = (press, fadeOut);
    } else {
      _held.remove(key);
    }
    try {
      final sampleRate = _sampleRate ?? await _open();
      final path = await _fileFor(instrument, key, synth, sampleRate);
      await _load(path);
      if (_presses[key] != press) return;
      _started[key] = press;
      try {
        await _engine.play(key, path);
      } catch (_) {
        // Si el mezclador lo ha olvidado (p. ej. al cerrarlo), se vuelve a
        // cargar la próxima vez.
        _loaded.remove(path);
        rethrow;
      }
      // Si se ha soltado mientras se preparaba, se apaga ya.
      if (instrument.sustained && _held[key]?.$1 != press) {
        await _engine.release(key, fadeOut);
      }
    } catch (_) {
      // Sin sonido no pasa nada grave: la tecla se sigue viendo pulsada.
    }
  }

  @override
  Future<void> release(int key) async {
    final held = _held.remove(key);
    if (held == null) return;
    final (press, fadeOut) = held;
    // Si aún se está preparando, se apaga al empezar (ver [play]).
    if (_started[key] != press) return;
    try {
      await _engine.release(key, fadeOut);
    } catch (_) {}
  }

  @override
  Future<void> stop(int key) async {
    // Si aún se estaba preparando para sonar, ya no suena.
    _presses[key] = (_presses[key] ?? 0) + 1;
    _held.remove(key);
    try {
      await _engine.stop(key);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _files.clear();
    _loaded.clear();
    _held.clear();
    _sampleRate = null;
    try {
      await _engine.close();
    } catch (_) {}
  }
}
