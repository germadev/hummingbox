import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import '../models/transcription.dart';
import '../services/recordings_repository.dart';
import '../services/transcriber.dart';

/// Transcribe grabaciones de una en una y guarda el texto con cada grabación.
///
/// Primero las que se piden, en el orden en que se piden, y después las de
/// segundo plano (las que se transcriben solas), de la más reciente a la más
/// antigua.
class TranscriptionController extends ChangeNotifier {
  TranscriptionController({
    required this.transcriber,
    required this._repository,
  });

  final Transcriber transcriber;
  final RecordingsRepository _repository;

  final _queue = <_Job>[];
  _Job? _current;

  /// Si se están transcribiendo las de la cola (aunque entre una y otra no
  /// haya ninguna en curso).
  bool _processing = false;
  bool _backgroundPaused = false;
  bool _disposed = false;

  _Job? _jobOf(Recording recording) => [
    ?_current,
    ..._queue,
  ].where((job) => job.recording.id == recording.id).firstOrNull;

  /// Indica si [recording] se está transcribiendo o espera a hacerlo (también
  /// en segundo plano).
  bool isTranscribing(Recording recording) => _jobOf(recording) != null;

  /// Indica si se ha pedido transcribir [recording] (y no es solo en segundo
  /// plano) y aún no ha terminado.
  bool isRequested(Recording recording) =>
      _jobOf(recording)?.background == false;

  /// Indica si [recording] se está transcribiendo (y no esperando su turno).
  bool isRunning(Recording recording) => _current?.recording.id == recording.id;

  /// Parte transcrita de [recording] (0–1), o `null` si espera su turno o se
  /// está preparando su audio.
  double? progressOf(Recording recording) =>
      _current?.recording.id == recording.id ? _current!.progress : null;

  /// Transcribe [recording] con [engine] en [language] (ver
  /// [Transcriber.transcribe]) y devuelve la grabación con su texto. Si ya
  /// se está transcribiendo, espera a que termine esa misma petición (si era
  /// en segundo plano, pasa delante de las demás de segundo plano; si era con
  /// otro motor u otro idioma, vuelve a empezar con estos).
  Future<Recording> transcribe(
    Recording recording, {
    required TranscriptionEngine engine,
    required String language,
  }) {
    final existing = _jobOf(recording);
    if (existing == null) {
      final job = _Job(recording, engine, language, background: false);
      _queue.insert(_requestedCount, job);
      _start();
      return _resultOf(job);
    }
    if (existing.background) {
      // Quien la pidió en segundo plano ya no recibe el resultado.
      existing.completer.complete(null);
      existing.completer = Completer();
      existing.background = false;
      if (existing != _current) {
        _queue
          ..remove(existing)
          ..insert(_requestedCount, existing);
      }
    }
    if (existing.engine != engine || existing.language != language) {
      // P. ej. si se ha elegido otro idioma para la grabación: si ya había
      // empezado, vuelve a empezar.
      existing
        ..engine = engine
        ..language = language;
      if (existing == _current) {
        existing
          ..interrupted = true
          ..cancel.cancel();
      }
    }
    _start();
    return _resultOf(existing);
  }

  static Future<Recording> _resultOf(_Job job) =>
      job.completer.future.then((recording) => recording!);

  /// Pone [recording] a transcribir en segundo plano, detrás de las pedidas
  /// (ver [transcribe]). Devuelve la grabación con su texto o `null` si
  /// entretanto se pidió transcribirla (el resultado va a quien la pidió) o
  /// se retiró con [cancelBackground]. Si ya se está transcribiendo, no hace
  /// nada y devuelve `null`.
  Future<Recording?> transcribeInBackground(
    Recording recording, {
    required TranscriptionEngine engine,
    required String language,
  }) {
    if (_jobOf(recording) != null) return Future.value();
    final job = _Job(recording, engine, language, background: true);
    // De la más reciente a la más antigua.
    var index = _requestedCount;
    while (index < _queue.length &&
        !_queue[index].recording.createdAt.isBefore(recording.createdAt)) {
      index++;
    }
    _queue.insert(index, job);
    _start();
    return job.completer.future;
  }

  /// Número de transcripciones pedidas en la cola (van delante).
  int get _requestedCount => _queue.where((job) => !job.background).length;

  /// Retira las transcripciones en segundo plano, también la que esté en
  /// curso: su resultado es `null`.
  void cancelBackground() {
    final withdrawn = _queue.where((job) => job.background).toList();
    for (final job in withdrawn) {
      _queue.remove(job);
      job.completer.complete(null);
    }
    if (_current case final job? when job.background) {
      job.withdrawn = true;
      job.cancel.cancel();
    }
    if (withdrawn.isNotEmpty) _notify();
  }

  /// Mientras es `true` (p. ej. mientras se graba), las transcripciones en
  /// segundo plano esperan: la que esté en curso se interrumpe y vuelve a
  /// empezar después.
  bool get backgroundPaused => _backgroundPaused;
  set backgroundPaused(bool paused) {
    if (paused == _backgroundPaused) return;
    _backgroundPaused = paused;
    if (paused) {
      if (_current case final job? when job.background) {
        job.interrupted = true;
        job.cancel.cancel();
      }
    } else {
      _start();
    }
  }

  /// Cancela la transcripción de [recording], en curso o pendiente. La
  /// petición falla con [TranscriptionError.canceled].
  void cancel(Recording recording) {
    if (_current case final job? when job.recording.id == recording.id) {
      job
        ..interrupted = false
        ..withdrawn = false
        ..cancel.cancel();
      return;
    }
    final pending = _queue
        .where((job) => job.recording.id == recording.id)
        .toList();
    for (final job in pending) {
      _queue.remove(job);
      job.completer.completeError(
        const TranscriptionException(TranscriptionError.canceled),
      );
    }
    if (pending.isNotEmpty) _notify();
  }

  void _start() {
    _notify();
    if (!_processing) unawaited(_next());
  }

  /// La siguiente que se puede empezar: la primera de la cola, salvo que sea
  /// de segundo plano y estén en pausa.
  _Job? get _nextJob {
    final job = _queue.firstOrNull;
    if (job == null || (job.background && _backgroundPaused)) return null;
    return job;
  }

  Future<void> _next() async {
    _processing = true;
    while (!_disposed) {
      final job = _nextJob;
      // En el mismo paso en que se ve que no queda nada, para que lo que se
      // pida justo después la vuelva a poner en marcha.
      if (job == null) break;
      _queue.remove(job);
      _current = job;
      job.progress = null;
      _notify();
      try {
        final transcript = await transcriber.transcribe(
          job.recording,
          engine: job.engine,
          language: job.language,
          cancel: job.cancel,
          onProgress: (progress) {
            job.progress = progress;
            _notify();
          },
        );
        job.completer.complete(
          await _repository.setTranscript(
            job.recording,
            transcript,
            // En segundo plano no se pisa la que haya llegado entretanto (p.
            // ej. de su .txt).
            keepExisting: job.background,
          ),
        );
      } catch (e, stack) {
        if (job.withdrawn && job.background) {
          job.completer.complete(null);
        } else if ((job.interrupted || job.withdrawn) && !_disposed) {
          // Se ha puesto en pausa (o se ha pedido mientras se retiraba):
          // vuelve a la cola, delante de las demás de su clase.
          job
            ..interrupted = false
            ..withdrawn = false
            ..cancel = TranscriptionCancel();
          _queue.insert(job.background ? _requestedCount : 0, job);
        } else {
          job.completer.completeError(e, stack);
        }
      }
      _current = null;
      _notify();
      // Quien esperaba el resultado reacciona antes de que empiece la
      // siguiente (p. ej. retirando las de segundo plano si no se puede
      // transcribir).
      await Future<void>.value();
    }
    _processing = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _current?.cancel.cancel();
    super.dispose();
  }
}

class _Job {
  _Job(this.recording, this.engine, this.language, {required this.background});

  final Recording recording;
  TranscriptionEngine engine;
  String language;

  /// Si es en segundo plano (no se ha pedido).
  bool background;

  /// El resultado; `null` para quien la puso en segundo plano si se retira o
  /// se pide después.
  Completer<Recording?> completer = Completer();
  TranscriptionCancel cancel = TranscriptionCancel();
  double? progress;

  /// Se ha cancelado para ponerla en pausa (y volver a empezarla después).
  bool interrupted = false;

  /// Se ha cancelado al retirar las de segundo plano.
  bool withdrawn = false;
}
