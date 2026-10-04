import 'package:voicerecorder_native/voicerecorder_native.dart';

/// Conversión entre audio comprimido (`.m4a`) y WAV PCM de 16 bits, que es
/// con lo que trabaja el editor. Abstraída para poder sustituirla en los
/// tests.
abstract interface class AudioCodec {
  Future<void> decodeToWav(String input, String output);

  /// Codifica en AAC con una tasa de [bitRate] bits por segundo (o la más
  /// cercana que admita el codificador).
  Future<void> encodeToM4a(String input, String output, {int bitRate});

  /// Copia el `.m4a` de [input] en [output] sin lo anterior a [start], sin
  /// volver a codificarlo.
  Future<void> trimStart(String input, String output, Duration start);
}

/// Implementación con los códecs del sistema.
class PlatformAudioCodec implements AudioCodec {
  const PlatformAudioCodec();

  final _native = const NativeAudioCodec();

  @override
  Future<void> decodeToWav(String input, String output) =>
      _native.decodeToWav(input, output);

  @override
  Future<void> encodeToM4a(
    String input,
    String output, {
    int bitRate = 128000,
  }) => _native.encodeToM4a(input, output, bitRate: bitRate);

  @override
  Future<void> trimStart(String input, String output, Duration start) =>
      _native.trimStart(input, output, start);
}
