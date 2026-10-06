import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/instrument.dart';
import '../models/piano_note.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import '../models/synth_patch.dart';
import '../services/recording_editor.dart';
import 'recorder_controller.dart';

/// Qué se graba desde el piano.
enum PianoRecordingMode {
  /// Solo las notas: se guardan en un `.mid`, sin audio (su sonido se
  /// genera al escucharlas).
  piano,

  /// La voz con el micrófono y, encima, las notas.
  pianoAndVoice,

  /// Las notas sobre una grabación que ya existe, mientras suena (ver
  /// [PianoRecorder.startOver]).
  accompaniment,
}

/// Graba lo que se toca en el piano, con el momento en que se pulsa y se
/// suelta cada tecla, y si se elige, también la voz. Al terminar, con voz o
/// al acompañar una grabación, el sonido de las notas se añade a su audio
/// ([RecordingEditor.addPiano]); solo con el piano, se guardan las notas sin
/// audio ([RecordingEditor.savePiano]). Se guardan con la grabación para
/// dibujarlas.
class PianoRecorder extends ChangeNotifier {
  PianoRecorder({required this.voice, required this.editor});

  /// Graba la voz (la misma grabadora que la de la pantalla principal).
  final RecorderController voice;
  final RecordingEditor editor;

  static const _tick = Duration(milliseconds: 100);

  final _stopwatch = Stopwatch();
  final _notes = <PianoNote>[];

  /// Teclas pulsadas, cuándo se pulsaron y con qué instrumento (y sonido
  /// del sintetizador).
  final _held = <int, (Duration, Instrument, SynthPatch)>{};

  PianoRecordingMode? _mode;

  /// La grabación que se acompaña, con [PianoRecordingMode.accompaniment].
  Recording? _target;
  String _folder = '';
  bool _saving = false;
  Timer? _ticker;

  /// Lo que se está grabando, o `null` si no se graba.
  PianoRecordingMode? get mode => _mode;

  bool get isRecording => _mode != null;

  /// La grabación que se está acompañando, si se acompaña una.
  Recording? get target => _target;

  /// Indica si se está guardando lo grabado (generando el audio).
  bool get isSaving => _saving;

  /// Tiempo grabado. Con voz, el de la grabadora, para que las notas
  /// coincidan con el audio.
  Duration get elapsed => _mode == PianoRecordingMode.pianoAndVoice
      ? voice.elapsed
      : _stopwatch.elapsed;

  /// Empieza a grabar [mode] para guardarlo en la subcarpeta [folder] (con
  /// voz, con el formato y la calidad de [options]). Devuelve `false` si hace
  /// falta el micrófono y no se concedió el permiso.
  Future<bool> start(
    PianoRecordingMode mode, {
    required RecordingOptions options,
    String folder = '',
  }) async {
    if (isRecording || _saving) return true;
    if (mode == PianoRecordingMode.pianoAndVoice) {
      if (!await voice.start(options: options, folder: folder)) return false;
    } else {
      _stopwatch
        ..reset()
        ..start();
    }
    _mode = mode;
    _folder = folder;
    _notes.clear();
    _held.clear();
    _ticker = Timer.periodic(_tick, (_) => notifyListeners());
    notifyListeners();
    return true;
  }

  /// Empieza a grabar notas sobre [target], una grabación que ya existe.
  /// [play] la empieza a reproducir desde el principio, y las notas cuentan
  /// desde que empieza a sonar.
  Future<void> startOver(
    Recording target, {
    required Future<void> Function() play,
  }) async {
    if (isRecording || _saving) return;
    await play();
    _stopwatch
      ..reset()
      ..start();
    _mode = PianoRecordingMode.accompaniment;
    _target = target;
    _notes.clear();
    _held.clear();
    _ticker = Timer.periodic(_tick, (_) => notifyListeners());
    notifyListeners();
  }

  /// Se ha pulsado la tecla [key], que suena con [instrument] (y, si es el
  /// sintetizador, con el sonido de [synth]).
  void noteOn(
    int key, {
    Instrument instrument = Instrument.piano,
    SynthPatch synth = const SynthPatch(),
  }) {
    if (!isRecording) return;
    noteOff(key);
    _held[key] = (elapsed, instrument, synth);
  }

  /// Se ha soltado la tecla [key].
  void noteOff(int key) {
    if (_held.remove(key) case (final start, final instrument, final synth)) {
      _notes.add(
        PianoNote(
          key: key,
          start: start,
          duration: elapsed - start,
          instrument: instrument,
          synth: synth,
        ),
      );
    }
  }

  /// Termina y guarda la grabación. Devuelve `null` si no hay nada que
  /// guardar (solo piano o acompañamiento sin notas) o no se pudo guardar la
  /// voz. Si no se puede añadir el piano a la voz, se guarda solo la voz. Al
  /// acompañar, devuelve la grabación acompañada con las notas añadidas.
  Future<Recording?> stop() async {
    final mode = _mode;
    if (mode == null) return null;
    for (final key in [..._held.keys]) {
      noteOff(key);
    }
    final duration = elapsed;
    final notes = [..._notes]..sort((a, b) => a.start.compareTo(b.start));
    final target = _target;
    _ticker?.cancel();
    _stopwatch.stop();
    _mode = null;
    _target = null;
    _saving = true;
    notifyListeners();
    try {
      switch (mode) {
        case PianoRecordingMode.piano:
          if (notes.isEmpty) return null;
          return await editor.savePiano(
            notes: notes,
            duration: duration,
            folder: _folder,
          );
        case PianoRecordingMode.accompaniment:
          if (notes.isEmpty || target == null) return null;
          return await editor.addPiano(target, notes);
        case PianoRecordingMode.pianoAndVoice:
          final recorded = await voice.stop();
          if (recorded == null) return null;
          try {
            return await editor.addPiano(recorded, notes);
          } catch (_) {
            return recorded;
          }
      }
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
