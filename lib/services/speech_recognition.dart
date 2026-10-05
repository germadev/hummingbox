import 'dart:io';

import 'package:voicerecorder_native/voicerecorder_native.dart';

import '../audio/wav.dart';

/// Si el reconocimiento de voz del sistema puede transcribir un idioma.
enum SystemSpeechStatus {
  /// Sí, en el dispositivo.
  available,

  /// Sí, en los servidores de Apple (iOS, para los idiomas que no admite en
  /// el dispositivo).
  online,

  /// El reconocedor no lo dice: se intenta.
  unknown,

  /// Hay que descargar el idioma (Android).
  download,

  /// Se está descargando el idioma (Android).
  downloading,

  /// No admite el idioma.
  unsupportedLanguage,

  /// No se ha dado permiso para usarlo (iOS).
  denied,

  /// No hay reconocedor en el dispositivo o la versión del sistema no
  /// permite transcribir archivos (Android 12 o anterior).
  unavailable,
}

/// Resultado de comprobar un idioma.
class SystemSpeechSupport {
  const SystemSpeechSupport(this.status, {this.language});

  final SystemSpeechStatus status;

  /// Variante del idioma que se usará (p. ej. «es-ES» para «es»).
  final String? language;
}

/// Reconocimiento de voz del sistema, para transcribir archivos. Abstraído
/// para poder sustituirlo en los tests.
abstract interface class SystemSpeech {
  /// Duración máxima de cada archivo que se transcribe (los más largos se
  /// dividen), o `null` si no hay límite.
  Duration? get maxLength;

  /// Indica si se puede transcribir en [language] (p. ej. «es»).
  Future<SystemSpeechSupport> check(String language);

  /// Pide al sistema que descargue [language] (Android).
  Future<void> download(String language);

  /// Transcribe el WAV de 16 kHz y un canal de [path] en [language] (la
  /// variante que dio [check]). Lanza `PlatformException` si falla.
  Future<String> transcribe(
    String path, {
    required WavInfo info,
    required String language,
  });

  /// Parte del audio de la transcripción en curso que ya se ha procesado
  /// (0–1).
  Future<double> progress();

  /// Cancela la transcripción en curso.
  Future<void> cancel();
}

/// Implementación con el reconocedor de Android o iOS.
class PlatformSystemSpeech implements SystemSpeech {
  const PlatformSystemSpeech();

  final _native = const NativeSpeech();

  /// En iOS, los idiomas que no admite en el dispositivo se reconocen en los
  /// servidores de Apple, con un límite de un minuto por archivo. En Android
  /// el reconocedor admite audios de cualquier duración.
  @override
  Duration? get maxLength =>
      Platform.isIOS ? const Duration(seconds: 55) : null;

  @override
  Future<SystemSpeechSupport> check(String language) async {
    final support = await _native.check(language);
    return SystemSpeechSupport(switch (support.status) {
      'available' => SystemSpeechStatus.available,
      'online' => SystemSpeechStatus.online,
      'unknown' => SystemSpeechStatus.unknown,
      'download' => SystemSpeechStatus.download,
      'downloading' => SystemSpeechStatus.downloading,
      'language' => SystemSpeechStatus.unsupportedLanguage,
      'denied' => SystemSpeechStatus.denied,
      _ => SystemSpeechStatus.unavailable,
    }, language: support.language);
  }

  @override
  Future<void> download(String language) => _native.download(language);

  @override
  Future<String> transcribe(
    String path, {
    required WavInfo info,
    required String language,
  }) => _native.transcribe(
    path: path,
    language: language,
    dataOffset: info.dataOffset,
    sampleRate: info.format.sampleRate,
    duration: info.duration,
  );

  @override
  Future<double> progress() => _native.progress();

  @override
  Future<void> cancel() => _native.cancel();
}
