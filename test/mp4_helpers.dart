import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Crea un `.m4a` mínimo con una pista AAC: solo las cajas que lee
/// `probeAudio`, sin audio real.
Future<String> writeM4a(
  Directory directory,
  String name, {
  int sampleRate = 44100,
  int channels = 1,
  int timescale = 44100,
  int durationUnits = 44100 * 10,
  int? averageBitRate = 128000,
  int mediaBytes = 1000,
  bool moovFirst = false,
  bool longMdhd = false,
}) async {
  final esds = averageBitRate == null
      ? <int>[]
      : _fullBox('esds', 0, [
          0x03, 0x19, 0x00, 0x01, 0x00, // ES_Descriptor, ES_ID y flags
          0x04, 0x11, 0x40, 0x15, 0x00, 0x00, 0x00, // DecoderConfig
          ..._u32(averageBitRate), // tasa máxima
          ..._u32(averageBitRate), // tasa media
          0x05, 0x02, 0x12, 0x10, 0x06, 0x01, 0x02,
        ]);
  final mp4a = _box('mp4a', [
    0, 0, 0, 0, 0, 0, 0, 1, // reservado e índice de datos
    0, 0, 0, 0, 0, 0, 0, 0, // versión, revisión y fabricante
    ..._u16(channels),
    ..._u16(16),
    0, 0, 0, 0,
    ..._u32(sampleRate << 16),
    ...esds,
  ]);
  final mdhd = longMdhd
      ? _fullBox('mdhd', 1, [
          ...List.filled(16, 0),
          ..._u32(timescale),
          ..._u64(durationUnits),
          0,
          0,
          0,
          0,
        ])
      : _fullBox('mdhd', 0, [
          ...List.filled(8, 0),
          ..._u32(timescale),
          ..._u32(durationUnits),
          0,
          0,
          0,
          0,
        ]);
  final moov = _box('moov', [
    ..._box('mvhd', List.filled(100, 0)),
    ..._box('trak', [
      ..._box('tkhd', List.filled(84, 0)),
      ..._box('mdia', [
        ...mdhd,
        ..._box('minf', [
          ..._box('stbl', [
            ..._fullBox('stsd', 0, [..._u32(1), ...mp4a]),
          ]),
        ]),
      ]),
    ]),
  ]);
  final ftyp = _box('ftyp', 'M4A \x00\x00\x00\x00isomM4A '.codeUnits);
  final mdat = _box('mdat', List.filled(mediaBytes, 0));

  final path = p.join(directory.path, name);
  await File(path).writeAsBytes([
    ...ftyp,
    if (moovFirst) ...moov,
    ...mdat,
    if (!moovFirst) ...moov,
  ]);
  return path;
}

List<int> _box(String type, List<int> body) => [
  ..._u32(8 + body.length),
  ...type.codeUnits,
  ...body,
];

List<int> _fullBox(String type, int version, List<int> body) =>
    _box(type, [version, 0, 0, 0, ...body]);

List<int> _u16(int value) =>
    (ByteData(2)..setUint16(0, value)).buffer.asUint8List();

List<int> _u32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

List<int> _u64(int value) =>
    (ByteData(8)..setUint64(0, value)).buffer.asUint8List();
