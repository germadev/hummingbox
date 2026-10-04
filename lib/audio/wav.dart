import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Formato PCM de 16 bits con signo y little endian, el único que se usa
/// para editar.
class PcmFormat {
  const PcmFormat({required this.sampleRate, required this.channels});

  final int sampleRate;
  final int channels;

  int get bytesPerFrame => channels * 2;

  Duration durationOf(int frames) => Duration(
    microseconds: frames * Duration.microsecondsPerSecond ~/ sampleRate,
  );

  int framesIn(Duration duration) =>
      duration.inMicroseconds * sampleRate ~/ Duration.microsecondsPerSecond;

  @override
  bool operator ==(Object other) =>
      other is PcmFormat &&
      other.sampleRate == sampleRate &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(sampleRate, channels);

  @override
  String toString() => 'PcmFormat($sampleRate Hz, $channels canales)';
}

/// Cabecera de un archivo WAV: formato y posición de las muestras.
class WavInfo {
  const WavInfo({
    required this.format,
    required this.dataOffset,
    required this.frameCount,
  });

  final PcmFormat format;

  /// Posición (en bytes) de la primera muestra.
  final int dataOffset;

  final int frameCount;

  Duration get duration => format.durationOf(frameCount);
}

/// Lee la cabecera de un WAV PCM de 16 bits.
///
/// Recorre todos los bloques del archivo, así que admite WAV con bloques
/// extra (`LIST`, `FLLR`, `JUNK`…) como los que genera iOS. Lanza
/// [FormatException] si el archivo no es un WAV PCM de 16 bits.
Future<WavInfo> readWavInfo(String path) async {
  final file = await File(path).open();
  try {
    final length = await file.length();
    final riff = await file.read(12);
    if (riff.length < 12 ||
        _fourCC(riff, 0) != 'RIFF' ||
        _fourCC(riff, 8) != 'WAVE') {
      throw const FormatException('No es un archivo WAV');
    }

    PcmFormat? format;
    var offset = 12;
    while (offset + 8 <= length) {
      await file.setPosition(offset);
      final header = await file.read(8);
      if (header.length < 8) break;
      final id = _fourCC(header, 0);
      final size = ByteData.sublistView(header).getUint32(4, Endian.little);
      final body = offset + 8;

      if (id == 'fmt ') {
        final fmt = ByteData.sublistView(await file.read(math.min(size, 40)));
        if (fmt.lengthInBytes < 16) {
          throw const FormatException('Bloque fmt incompleto');
        }
        final tag = fmt.getUint16(0, Endian.little);
        final channels = fmt.getUint16(2, Endian.little);
        final sampleRate = fmt.getUint32(4, Endian.little);
        final bits = fmt.getUint16(14, Endian.little);
        // 1 = PCM; 0xFFFE = WAVE_FORMAT_EXTENSIBLE, cuyo subformato está en
        // los dos primeros bytes del GUID.
        final isPcm =
            tag == 1 ||
            (tag == 0xFFFE &&
                fmt.lengthInBytes >= 26 &&
                fmt.getUint16(24, Endian.little) == 1);
        if (!isPcm || bits != 16 || channels < 1 || sampleRate < 1) {
          throw FormatException(
            'Formato WAV no admitido (formato $tag, $bits bits)',
          );
        }
        format = PcmFormat(sampleRate: sampleRate, channels: channels);
      } else if (id == 'data') {
        if (format == null) {
          throw const FormatException('El WAV no tiene bloque fmt');
        }
        // Si el tamaño no llegó a escribirse, se usa el resto del archivo.
        var dataSize = size;
        if (dataSize == 0 ||
            dataSize == 0xFFFFFFFF ||
            body + dataSize > length) {
          dataSize = length - body;
        }
        return WavInfo(
          format: format,
          dataOffset: body,
          frameCount: dataSize ~/ format.bytesPerFrame,
        );
      }
      // Los bloques están alineados a 2 bytes.
      offset = body + size + (size & 1);
    }
    throw const FormatException('El WAV no tiene datos de audio');
  } finally {
    await file.close();
  }
}

String _fourCC(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));

/// Lee las muestras de los fotogramas `[start, end)` en bloques de, como
/// mucho, [blockFrames] fotogramas. Las muestras de cada fotograma van
/// intercaladas por canal.
Stream<Int16List> readWavSamples(
  String path,
  WavInfo info, {
  int start = 0,
  int? end,
  int blockFrames = 32768,
}) async* {
  _checkHostEndian();
  final last = math.min(end ?? info.frameCount, info.frameCount);
  final bytesPerFrame = info.format.bytesPerFrame;
  final file = await File(path).open();
  try {
    await file.setPosition(info.dataOffset + start * bytesPerFrame);
    var frame = start;
    while (frame < last) {
      final frames = math.min(blockFrames, last - frame);
      final bytes = await file.read(frames * bytesPerFrame);
      final whole = bytes.length ~/ bytesPerFrame;
      if (whole == 0) break;
      // Se copia para garantizar la alineación de la vista de 16 bits.
      final samples = Int16List(whole * info.format.channels);
      samples.buffer.asUint8List().setRange(0, whole * bytesPerFrame, bytes);
      yield samples;
      frame += whole;
    }
  } finally {
    await file.close();
  }
}

/// Escribe un WAV PCM de 16 bits por bloques. La cabecera se completa al
/// cerrar, cuando ya se conoce el tamaño.
class WavWriter {
  WavWriter._(this._file, this.format);

  static Future<WavWriter> open(String path, PcmFormat format) async {
    _checkHostEndian();
    final file = await File(path).open(mode: FileMode.write);
    await file.writeFrom(wavHeader(format, 0));
    return WavWriter._(file, format);
  }

  final RandomAccessFile _file;
  final PcmFormat format;
  int _dataBytes = 0;

  int get frameCount => _dataBytes ~/ format.bytesPerFrame;

  Future<void> write(Int16List samples) async {
    final bytes = samples.buffer.asUint8List(
      samples.offsetInBytes,
      samples.lengthInBytes,
    );
    await _file.writeFrom(bytes);
    _dataBytes += bytes.length;
  }

  Future<void> close() async {
    await _file.setPosition(0);
    await _file.writeFrom(wavHeader(format, _dataBytes));
    await _file.close();
  }
}

/// Cabecera estándar de 44 bytes de un WAV PCM de 16 bits.
Uint8List wavHeader(PcmFormat format, int dataBytes) {
  final header = ByteData(44);
  void fourCC(int offset, String value) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  fourCC(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  fourCC(8, 'WAVE');
  fourCC(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, format.channels, Endian.little);
  header.setUint32(24, format.sampleRate, Endian.little);
  header.setUint32(28, format.sampleRate * format.bytesPerFrame, Endian.little);
  header.setUint16(32, format.bytesPerFrame, Endian.little);
  header.setUint16(34, 16, Endian.little);
  fourCC(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

/// Las muestras se leen y escriben con vistas `Int16List`, que usan el orden
/// de bytes del dispositivo. Todos los móviles compatibles son little endian,
/// como el formato WAV.
void _checkHostEndian() {
  if (Endian.host != Endian.little) {
    throw UnsupportedError('Solo se admiten dispositivos little endian');
  }
}
