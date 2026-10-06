import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/recording_options.dart';

/// Formato y calidad reales de un archivo de audio.
class AudioInfo {
  const AudioInfo({
    required this.format,
    required this.sampleRate,
    required this.channels,
    this.bitRate,
    this.bitsPerSample,
  });

  final RecordingFormat format;

  /// Frecuencia de muestreo en hercios.
  final int sampleRate;
  final int channels;

  /// Tasa de bits del audio comprimido (AAC), en bits por segundo.
  final int? bitRate;

  /// Bits por muestra del audio sin comprimir (WAV).
  final int? bitsPerSample;

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'sampleRate': sampleRate,
    'channels': channels,
    if (bitRate != null) 'bitRate': bitRate,
    if (bitsPerSample != null) 'bits': bitsPerSample,
  };

  static AudioInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final format = RecordingFormat.values.asNameMap()[json['format']];
    final sampleRate = json['sampleRate'];
    final channels = json['channels'];
    final bitRate = json['bitRate'];
    final bits = json['bits'];
    if (format == null || sampleRate is! int || channels is! int) return null;
    return AudioInfo(
      format: format,
      sampleRate: sampleRate,
      channels: channels,
      bitRate: bitRate is int ? bitRate : null,
      bitsPerSample: bits is int ? bits : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioInfo &&
      other.format == format &&
      other.sampleRate == sampleRate &&
      other.channels == channels &&
      other.bitRate == bitRate &&
      other.bitsPerSample == bitsPerSample;

  @override
  int get hashCode =>
      Object.hash(format, sampleRate, channels, bitRate, bitsPerSample);
}

/// Resultado de [probeAudio].
class AudioProbe {
  const AudioProbe(this.info, this.duration);

  final AudioInfo info;
  final Duration duration;
}

/// Lee el formato y la duración de un `.m4a` (AAC) o un `.wav` en su
/// cabecera, sin decodificar el audio. Devuelve `null` si el archivo no
/// existe o no se reconoce.
Future<AudioProbe?> probeAudio(String path) async {
  final format = RecordingFormat.fromPath(path);
  if (format == null || !format.isAudio) return null;
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    return switch (format) {
      RecordingFormat.aac => await _probeMp4(file),
      RecordingFormat.wav => await _probeWav(file),
      RecordingFormat.midi => null,
    };
  } catch (_) {
    // Archivo inexistente, truncado o con una estructura inesperada.
    return null;
  } finally {
    await file?.close();
  }
}

// --- WAV ---

Future<AudioProbe?> _probeWav(RandomAccessFile file) async {
  final length = await file.length();
  final riff = await file.read(12);
  if (riff.length < 12 ||
      _ascii(riff, 0) != 'RIFF' ||
      _ascii(riff, 8) != 'WAVE') {
    return null;
  }

  int? channels, sampleRate, blockAlign, bits;
  var offset = 12;
  while (offset + 8 <= length) {
    await file.setPosition(offset);
    final header = await file.read(8);
    if (header.length < 8) break;
    final id = _ascii(header, 0);
    final size = ByteData.sublistView(header).getUint32(4, Endian.little);
    final body = offset + 8;

    if (id == 'fmt ') {
      final fmt = ByteData.sublistView(await file.read(math.min(size, 16)));
      if (fmt.lengthInBytes < 16) return null;
      channels = fmt.getUint16(2, Endian.little);
      sampleRate = fmt.getUint32(4, Endian.little);
      blockAlign = fmt.getUint16(12, Endian.little);
      bits = fmt.getUint16(14, Endian.little);
    } else if (id == 'data') {
      if (channels == null ||
          sampleRate == null ||
          blockAlign == null ||
          bits == null ||
          sampleRate == 0 ||
          blockAlign == 0) {
        return null;
      }
      // Si el tamaño no llegó a escribirse, se usa el resto del archivo.
      var dataSize = size;
      if (dataSize == 0 || dataSize == 0xFFFFFFFF || body + dataSize > length) {
        dataSize = length - body;
      }
      final frames = dataSize ~/ blockAlign;
      return AudioProbe(
        AudioInfo(
          format: RecordingFormat.wav,
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bits,
        ),
        Duration(
          microseconds: frames * Duration.microsecondsPerSecond ~/ sampleRate,
        ),
      );
    }
    // Los bloques están alineados a 2 bytes.
    offset = body + size + (size & 1);
  }
  return null;
}

// --- MP4 (.m4a) ---

/// Caja de un archivo MP4: su tipo y dónde empieza y acaba su contenido.
class _Box {
  const _Box(this.type, this.start, this.end);

  final String type;
  final int start;
  final int end;

  int get size => end - start;
}

/// Cajas contenidas entre [start] y [end].
Future<List<_Box>> _boxes(RandomAccessFile file, int start, int end) async {
  final boxes = <_Box>[];
  var offset = start;
  while (offset + 8 <= end) {
    await file.setPosition(offset);
    final header = await file.read(16);
    if (header.length < 8) break;
    final data = ByteData.sublistView(header);
    final type = _ascii(header, 4);
    var size = data.getUint32(0);
    var body = offset + 8;
    if (size == 1) {
      // Tamaño de 64 bits.
      if (header.length < 16) break;
      size = data.getUint64(8);
      body += 8;
    } else if (size == 0) {
      // Llega hasta el final.
      size = end - offset;
    }
    if (offset + size < body) break;
    boxes.add(_Box(type, body, math.min(offset + size, end)));
    offset += size;
  }
  return boxes;
}

/// Sigue la ruta de cajas [path] desde [box]. Devuelve `null` si falta
/// alguna.
Future<_Box?> _descend(
  RandomAccessFile file,
  _Box box,
  List<String> path,
) async {
  _Box? current = box;
  for (final type in path) {
    final children = await _boxes(file, current!.start, current.end);
    current = children.where((b) => b.type == type).firstOrNull;
    if (current == null) return null;
  }
  return current;
}

Future<Uint8List> _read(RandomAccessFile file, _Box box, {int? max}) async {
  await file.setPosition(box.start);
  return file.read(max == null ? box.size : math.min(box.size, max));
}

Future<AudioProbe?> _probeMp4(RandomAccessFile file) async {
  final top = await _boxes(file, 0, await file.length());
  final moov = top.where((b) => b.type == 'moov').firstOrNull;
  if (moov == null) return null;
  final mediaBytes = top
      .where((b) => b.type == 'mdat')
      .fold<int>(0, (sum, b) => sum + b.size);

  for (final trak in await _boxes(file, moov.start, moov.end)) {
    if (trak.type != 'trak') continue;
    final mdia = await _descend(file, trak, ['mdia']);
    if (mdia == null) continue;
    final mdhd = await _descend(file, mdia, ['mdhd']);
    final stsd = await _descend(file, mdia, ['minf', 'stbl', 'stsd']);
    if (mdhd == null || stsd == null) continue;

    // Primera descripción de muestra: tiene que ser AAC ('mp4a').
    final entries = await _read(file, stsd, max: 4096);
    final description = ByteData.sublistView(entries);
    if (entries.length < 8 + 36 || _ascii(entries, 12) != 'mp4a') continue;
    const entry = 8;
    final version = description.getUint16(entry + 16);
    final channels = description.getUint16(entry + 24);
    var sampleRate = description.getUint32(entry + 32) >> 16;

    final header = ByteData.sublistView(await _read(file, mdhd, max: 32));
    final longFields = header.getUint8(0) == 1;
    final timescale = header.getUint32(longFields ? 20 : 12);
    final length = longFields ? header.getUint64(24) : header.getUint32(16);
    if (timescale == 0) continue;
    // Frecuencias por encima de 65535 Hz no caben en el campo de 16.16.
    if (sampleRate == 0) sampleRate = timescale;
    final duration = Duration(
      microseconds: length * Duration.microsecondsPerSecond ~/ timescale,
    );

    // Tasa de bits: la de la cabecera (esds) o, si no viene, la que sale
    // del tamaño del audio.
    var bitRate = version <= 1
        ? _averageBitRate(entries, entry + 36 + (version == 1 ? 16 : 0))
        : null;
    if (bitRate == null && duration > Duration.zero && mediaBytes > 0) {
      bitRate =
          mediaBytes *
          8 *
          Duration.microsecondsPerSecond ~/
          duration.inMicroseconds;
    }

    return AudioProbe(
      AudioInfo(
        format: RecordingFormat.aac,
        sampleRate: sampleRate,
        channels: channels,
        bitRate: bitRate == null ? null : roundBitRate(bitRate),
      ),
      duration,
    );
  }
  return null;
}

/// Tasa de bits media que indica la caja `esds` de una descripción 'mp4a'
/// cuyas cajas hijas empiezan en [offset], o `null` si no la indica.
int? _averageBitRate(Uint8List entries, int offset) {
  try {
    final data = ByteData.sublistView(entries);
    var position = offset;
    while (position + 8 <= entries.length) {
      final size = data.getUint32(position);
      if (size < 8) return null;
      if (_ascii(entries, position + 4) == 'esds') {
        // Versión y flags, y después el ES_Descriptor (etiqueta 3).
        var i = position + 12;
        if (entries[i++] != 0x03) return null;
        i = _skipDescriptorLength(entries, i);
        i += 2; // ES_ID
        final flags = entries[i++];
        if (flags & 0x80 != 0) i += 2;
        if (flags & 0x40 != 0) i += 1 + entries[i];
        if (flags & 0x20 != 0) i += 2;
        // DecoderConfigDescriptor (etiqueta 4): tipo (1), flujo (1),
        // búfer (3), tasa máxima (4) y tasa media (4).
        if (entries[i++] != 0x04) return null;
        i = _skipDescriptorLength(entries, i);
        final average = data.getUint32(i + 9);
        return average > 0 ? average : null;
      }
      position += size;
    }
  } on RangeError {
    // Caja truncada.
  }
  return null;
}

/// La longitud de un descriptor ocupa de 1 a 4 bytes; el bit alto indica que
/// sigue otro.
int _skipDescriptorLength(Uint8List data, int i) {
  for (var n = 0; n < 4; n++) {
    if (data[i++] & 0x80 == 0) break;
  }
  return i;
}

/// Tasas de bits habituales de AAC.
const _commonBitRates = [
  16000,
  24000,
  32000,
  48000,
  64000,
  96000,
  128000,
  160000,
  192000,
  256000,
  320000,
];

/// Redondea [bitRate] a la tasa habitual más cercana si se parece (el
/// contenedor y la codificación variable la desvían un poco) o, si no, al
/// kbps.
int roundBitRate(int bitRate) {
  for (final common in _commonBitRates) {
    if ((bitRate - common).abs() <= common * 0.08) return common;
  }
  return (bitRate / 1000).round() * 1000;
}

String _ascii(List<int> bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
