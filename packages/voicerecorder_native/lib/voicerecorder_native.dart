import 'package:flutter/services.dart';

/// Convierte audio con los códecs del sistema (MediaCodec en Android y
/// AVFoundation en iOS). El trabajo se hace fuera del hilo principal.
class NativeAudioCodec {
  const NativeAudioCodec();

  static const _channel = MethodChannel('es.germade.voicerecorder/audio_codec');

  /// Decodifica el audio de [input] (p. ej. un `.m4a`) a un WAV PCM de 16 bits
  /// en [output].
  Future<void> decodeToWav(String input, String output) {
    return _channel.invokeMethod<void>('decodeToWav', {
      'input': input,
      'output': output,
    });
  }

  /// Codifica el WAV PCM de 16 bits de [input] en AAC-LC dentro de un `.m4a`
  /// en [output].
  Future<void> encodeToM4a(
    String input,
    String output, {
    int bitRate = 128000,
  }) {
    return _channel.invokeMethod<void>('encodeToM4a', {
      'input': input,
      'output': output,
      'bitRate': bitRate,
    });
  }
}

/// Carpeta elegida por el usuario con el selector del sistema.
class NativeFolder {
  const NativeFolder({required this.id, required this.name});

  /// Identificador persistente de la carpeta: el URI del árbol en Android y
  /// un marcador de seguridad (bookmark) en base64 en iOS.
  final String id;

  /// Nombre visible de la carpeta.
  final String name;
}

/// Acceso a carpetas fuera de la app (almacenamiento del dispositivo, iCloud
/// Drive, tarjeta SD…) elegidas por el usuario.
class NativeFolders {
  const NativeFolders();

  static const _channel = MethodChannel('es.germade.voicerecorder/folders');

  /// Abre el selector de carpetas del sistema. Devuelve `null` si el usuario
  /// lo cancela. El permiso de escritura se conserva entre sesiones.
  Future<NativeFolder?> pickFolder() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickFolder',
    );
    if (result == null) return null;
    return NativeFolder(
      id: result['id']! as String,
      name: result['name']! as String,
    );
  }

  /// Copia el archivo de [source] a la carpeta [folder].
  ///
  /// Si [ref] apunta a un archivo que sigue existiendo, se sobrescribe; si no,
  /// se crea uno nuevo llamado [name] (o con un sufijo si ya existe).
  /// Devuelve la referencia del archivo escrito.
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String? ref,
  }) async {
    final result = await _channel.invokeMethod<String>('writeFile', {
      'folder': folder,
      'source': source,
      'name': name,
      'ref': ref,
    });
    return result!;
  }

  /// Renombra el archivo [ref] de la carpeta [folder]. Devuelve su nueva
  /// referencia.
  Future<String> renameFile({
    required String folder,
    required String ref,
    required String name,
  }) async {
    final result = await _channel.invokeMethod<String>('renameFile', {
      'folder': folder,
      'ref': ref,
      'name': name,
    });
    return result!;
  }
}
