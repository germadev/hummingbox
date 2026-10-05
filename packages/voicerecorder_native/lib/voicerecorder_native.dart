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

  /// Copia el `.m4a` de [input] en [output] sin lo que hay antes de [start],
  /// sin volver a codificar el audio.
  Future<void> trimStart(String input, String output, Duration start) {
    return _channel.invokeMethod<void>('trimStart', {
      'input': input,
      'output': output,
      'startUs': start.inMicroseconds,
    });
  }
}

/// Pantalla del dispositivo.
class NativeScreen {
  const NativeScreen();

  static const _channel = MethodChannel('es.germade.voicerecorder/screen');

  /// Mantiene la pantalla encendida mientras la app está abierta si [on] es
  /// `true`; si no, deja que se apague como siempre.
  Future<void> keepOn(bool on) =>
      _channel.invokeMethod<void>('keepOn', {'on': on});
}

/// Si el reconocimiento de voz del sistema puede transcribir un idioma.
class NativeSpeechSupport {
  const NativeSpeechSupport({required this.status, this.language});

  /// `available` (en el dispositivo), `online` (en los servidores de Apple,
  /// solo iOS), `download` (hay que descargar el idioma, solo Android),
  /// `downloading`, `language` (no lo admite), `denied` (sin permiso, solo
  /// iOS), `unknown` (el reconocedor no lo dice) o `unavailable` (no hay
  /// reconocedor o la versión del sistema no lo permite).
  final String status;

  /// Variante del idioma que se usará (p. ej. «es-ES»), si se admite.
  final String? language;
}

/// Reconocimiento de voz del sistema, para transcribir archivos: en Android
/// 13 o superior, con el reconocedor del dispositivo; en iOS, con
/// SFSpeechRecognizer.
class NativeSpeech {
  const NativeSpeech();

  static const _channel = MethodChannel('es.germade.voicerecorder/speech');

  /// Indica si se puede transcribir en [language] (p. ej. «es» o «es-ES»).
  Future<NativeSpeechSupport> check(String language) async {
    final result = await _channel.invokeMapMethod<String, Object?>('check', {
      'language': language,
    });
    return NativeSpeechSupport(
      status: result?['status'] as String? ?? 'unavailable',
      language: result?['language'] as String?,
    );
  }

  /// Pide al sistema que descargue [language] (solo Android; el sistema
  /// muestra su propio aviso).
  Future<void> download(String language) =>
      _channel.invokeMethod<void>('download', {'language': language});

  /// Transcribe el WAV PCM de 16 bits y un canal de [path], cuyas muestras
  /// empiezan en el byte [dataOffset] y duran [duration], en [language].
  ///
  /// Falla con un código: `canceled`, `language`, `denied`, `permission`,
  /// `busy`, `unavailable` o `failed`.
  Future<String> transcribe({
    required String path,
    required String language,
    required int dataOffset,
    required int sampleRate,
    required Duration duration,
  }) async {
    final text = await _channel.invokeMethod<String>('transcribe', {
      'path': path,
      'language': language,
      'dataOffset': dataOffset,
      'sampleRate': sampleRate,
      'durationMs': duration.inMilliseconds,
    });
    return text ?? '';
  }

  /// Parte del audio de la transcripción en curso que ya se ha procesado
  /// (0–1).
  Future<double> progress() async =>
      (await _channel.invokeMethod<num>('progress'))?.toDouble() ?? 0;

  /// Cancela la transcripción en curso.
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
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

/// Archivo o subcarpeta de una carpeta elegida por el usuario.
class NativeFolderEntry {
  const NativeFolderEntry({
    required this.ref,
    required this.name,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  /// Referencia persistente: el URI del documento en Android y la ruta
  /// relativa a la carpeta en iOS.
  final String ref;
  final String name;
  final bool isDirectory;

  /// Tamaño en bytes, si se conoce.
  final int? size;

  /// Fecha de la última modificación, si se conoce.
  final DateTime? modified;
}

/// Acceso a carpetas fuera de la app (almacenamiento del dispositivo, iCloud
/// Drive, tarjeta SD…) elegidas por el usuario: listar, leer, escribir,
/// renombrar y borrar archivos.
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

  /// Copia el archivo de [source] a la carpeta [folder] o, si se indica, a
  /// su subcarpeta [subfolder] (que se crea si no existe).
  ///
  /// Si [ref] apunta a un archivo que sigue existiendo, se sobrescribe; si no,
  /// se crea uno nuevo llamado [name] (o con un sufijo si ya existe).
  /// Devuelve la referencia del archivo escrito.
  Future<String> writeFile({
    required String folder,
    required String source,
    required String name,
    String subfolder = '',
    String? ref,
  }) async {
    final result = await _channel.invokeMethod<String>('writeFile', {
      'folder': folder,
      'subfolder': subfolder,
      'source': source,
      'name': name,
      'ref': ref,
    });
    return result!;
  }

  /// Archivos y subcarpetas de [folder] o, si se indica, de su subcarpeta
  /// [subfolder]. Si la subcarpeta no existe, devuelve una lista vacía.
  Future<List<NativeFolderEntry>> listFiles({
    required String folder,
    String subfolder = '',
  }) async {
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listFiles',
      {'folder': folder, 'subfolder': subfolder},
    );
    return [
      for (final entry in result ?? const <Map<Object?, Object?>>[])
        NativeFolderEntry(
          ref: entry['ref']! as String,
          name: entry['name']! as String,
          isDirectory: entry['isDirectory'] == true,
          size: (entry['size'] as num?)?.toInt(),
          modified: switch (entry['modified']) {
            final num millis => DateTime.fromMillisecondsSinceEpoch(
              millis.toInt(),
            ),
            _ => null,
          },
        ),
    ];
  }

  /// Copia el archivo [ref] de la carpeta [folder] a la ruta local
  /// [destination]. En iCloud Drive lo descarga si hace falta.
  Future<void> readFile({
    required String folder,
    required String ref,
    required String destination,
  }) {
    return _channel.invokeMethod<void>('readFile', {
      'folder': folder,
      'ref': ref,
      'destination': destination,
    });
  }

  /// Crea la subcarpeta [name] en [folder], si no existe ya.
  Future<void> createFolder({required String folder, required String name}) {
    return _channel.invokeMethod<void>('createFolder', {
      'folder': folder,
      'name': name,
    });
  }

  /// Borra el archivo [ref] de la carpeta [folder]. Si ya no existe, no hace
  /// nada.
  Future<void> deleteFile({required String folder, required String ref}) {
    return _channel.invokeMethod<void>('deleteFile', {
      'folder': folder,
      'ref': ref,
    });
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
