import 'package:voicerecorder_native/voicerecorder_native.dart';

/// Conversión entre el formato de las grabaciones (`.m4a`) y WAV PCM de
/// 16 bits, que es con lo que trabaja el editor. Abstraída para poder
/// sustituirla en los tests.
abstract interface class AudioCodec {
  Future<void> decodeToWav(String input, String output);

  Future<void> encodeToM4a(String input, String output);
}

/// Implementación con los códecs del sistema.
class PlatformAudioCodec implements AudioCodec {
  const PlatformAudioCodec();

  final _native = const NativeAudioCodec();

  @override
  Future<void> decodeToWav(String input, String output) =>
      _native.decodeToWav(input, output);

  /// Usa la misma calidad que las grabaciones (128 kbps).
  @override
  Future<void> encodeToM4a(String input, String output) =>
      _native.encodeToM4a(input, output, bitRate: 128000);
}
