import 'package:flutter/services.dart';
import 'package:voicerecorder_native/voicerecorder_native.dart';

/// Mantiene la pantalla encendida (p. ej. mientras se graba, para que el
/// sistema no pare la app al apagarla). Abstraído para poder sustituirlo en
/// los tests.
abstract interface class ScreenAwake {
  /// Mantiene la pantalla encendida si [on] es `true`; si no, deja que se
  /// apague como siempre.
  Future<void> keepOn(bool on);
}

/// Implementación con la ventana de la app (Android) o el temporizador de
/// reposo del sistema (iOS).
class PlatformScreenAwake implements ScreenAwake {
  const PlatformScreenAwake();

  final _native = const NativeScreen();

  @override
  Future<void> keepOn(bool on) async {
    try {
      await _native.keepOn(on);
    } on PlatformException {
      // Solo afecta a si la pantalla se apaga sola.
    } on MissingPluginException {
      // Plataforma sin implementación (p. ej. en los tests).
    }
  }
}
