import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/transcription.dart';
import '../services/whisper_service.dart';

/// Estado de la instalación de Whisper: qué modelo hay y la descarga en
/// curso. Vive mientras la app está abierta, así que la descarga sigue
/// aunque se cierre la pantalla de opciones.
class WhisperController extends ChangeNotifier {
  WhisperController(this.service);

  final WhisperService service;

  WhisperModel? _installed;

  /// Modelo instalado, si hay alguno.
  WhisperModel? get installed => _installed;

  bool _loaded = false;

  /// Indica si ya se sabe qué modelo hay instalado.
  bool get isLoaded => _loaded;

  WhisperModel? _downloading;

  /// Modelo que se está descargando, si hay alguno.
  WhisperModel? get downloading => _downloading;

  double? _progress;

  /// Parte descargada (0–1), o `null` si no se sabe.
  double? get progress => _progress;

  StreamSubscription<double?>? _download;
  Completer<void>? _done;
  bool _disposed = false;

  /// Lee qué modelo hay instalado. Se puede llamar varias veces.
  Future<void> load() async {
    try {
      _installed = await service.installedModel();
    } catch (_) {
      _installed = null;
    }
    _loaded = true;
    _notify();
  }

  /// Descarga [model]. Termina al acabar la descarga y falla si no se ha
  /// podido completar. Si se cancela con [cancelInstall], termina sin error.
  Future<void> install(WhisperModel model) {
    if (_done case final done?) return done.future;
    final done = _done = Completer<void>();
    _downloading = model;
    _progress = 0;
    _notify();
    void finish([Object? error]) {
      _download = null;
      _done = null;
      _downloading = null;
      _progress = null;
      _notify();
      if (error == null) {
        done.complete();
      } else {
        done.completeError(error);
      }
    }

    _download = service
        .install(model)
        .listen(
          (progress) {
            // Llega un aviso por cada bloque descargado: solo se redibuja
            // cuando cambia el porcentaje.
            final changed = _percent(progress) != _percent(_progress);
            _progress = progress;
            if (changed) _notify();
          },
          onDone: () {
            _installed = model;
            finish();
          },
          onError: (Object error) {
            unawaited(_download?.cancel());
            finish(error);
          },
          cancelOnError: true,
        );
    return done.future;
  }

  static int? _percent(double? progress) =>
      progress == null ? null : (progress * 100).floor();

  /// Detiene la descarga en curso. Lo descargado se conserva y la próxima
  /// descarga sigue desde ahí.
  Future<void> cancelInstall() async {
    final download = _download;
    final done = _done;
    if (download == null || done == null) return;
    _download = null;
    _done = null;
    _downloading = null;
    _progress = null;
    _notify();
    await download.cancel();
    done.complete();
  }

  /// Borra el modelo instalado.
  Future<void> uninstall() async {
    await cancelInstall();
    await service.uninstall();
    _installed = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_download?.cancel());
    super.dispose();
  }
}
