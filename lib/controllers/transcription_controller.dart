import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recording.dart';
import '../models/transcription.dart';
import '../services/recordings_repository.dart';
import '../services/transcriber.dart';

/// Transcribe grabaciones de una en una, en el orden en que se piden, y
/// guarda el texto con cada grabación.
class TranscriptionController extends ChangeNotifier {
  TranscriptionController({
    required this.transcriber,
    required this._repository,
  });

  final Transcriber transcriber;
  final RecordingsRepository _repository;

  final _queue = <_Job>[];
  _Job? _current;
  bool _disposed = false;

  /// Indica si [recording] se está transcribiendo o espera a hacerlo.
  bool isTranscribing(Recording recording) =>
      _current?.recording.id == recording.id ||
      _queue.any((job) => job.recording.id == recording.id);

  /// Indica si [recording] se está transcribiendo (y no esperando su turno).
  bool isRunning(Recording recording) => _current?.recording.id == recording.id;

  /// Parte transcrita de [recording] (0–1), o `null` si espera su turno o se
  /// está preparando su audio.
  double? progressOf(Recording recording) =>
      _current?.recording.id == recording.id ? _current!.progress : null;

  /// Transcribe [recording] con [engine] en [language] (ver
  /// [Transcriber.transcribe]) y devuelve la grabación con su texto. Si ya
  /// se está transcribiendo, espera a que termine esa misma petición.
  Future<Recording> transcribe(
    Recording recording, {
    required TranscriptionEngine engine,
    required String language,
  }) {
    final existing = [
      ?_current,
      ..._queue,
    ].where((job) => job.recording.id == recording.id).firstOrNull;
    if (existing != null) return existing.completer.future;
    final job = _Job(recording, engine, language);
    _queue.add(job);
    _notify();
    if (_current == null) unawaited(_next());
    return job.completer.future;
  }

  /// Cancela la transcripción de [recording], en curso o pendiente. La
  /// petición falla con [TranscriptionError.canceled].
  void cancel(Recording recording) {
    if (_current case final job? when job.recording.id == recording.id) {
      job.cancel.cancel();
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

  Future<void> _next() async {
    while (_queue.isNotEmpty && !_disposed) {
      final job = _current = _queue.removeAt(0);
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
          await _repository.setTranscript(job.recording, transcript),
        );
      } catch (e, stack) {
        job.completer.completeError(e, stack);
      }
      _current = null;
      _notify();
    }
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
  _Job(this.recording, this.engine, this.language);

  final Recording recording;
  final TranscriptionEngine engine;
  final String language;
  final completer = Completer<Recording>();
  final cancel = TranscriptionCancel();
  double? progress;
}
