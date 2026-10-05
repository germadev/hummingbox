import 'dart:convert';
import 'dart:typed_data';

import '../models/piano_note.dart';

/// Archivos MIDI estándar (`.mid`) con las notas del piano de una grabación,
/// para abrirlas en otras aplicaciones.
///
/// Se escriben en formato 0 (una sola pista), a 120 negras por minuto con
/// 480 divisiones por negra, de modo que los tiempos se conservan al
/// milisegundo aproximadamente.
abstract final class Midi {
  /// Divisiones por negra.
  static const ticksPerQuarter = 480;

  /// Microsegundos por negra (120 por minuto).
  static const microsecondsPerQuarter = 500000;

  /// Fuerza con la que se tocan las notas (no se mide en la pantalla).
  static const velocity = 90;

  static int _ticksOf(Duration time) =>
      (time.inMicroseconds * ticksPerQuarter / microsecondsPerQuarter).round();

  /// El archivo con [notes].
  static Uint8List encode(List<PianoNote> notes, {String? name}) {
    // Pulsaciones y sueltas en orden; con el mismo tiempo, primero las
    // sueltas (para repetir una tecla sin que se solapen).
    final events =
        <(int, bool, int)>[
          for (final note in notes) ...[
            (_ticksOf(note.start), true, note.key),
            (_ticksOf(note.end), false, note.key),
          ],
        ]..sort((a, b) {
          final byTime = a.$1.compareTo(b.$1);
          if (byTime != 0) return byTime;
          return (a.$2 ? 1 : 0).compareTo(b.$2 ? 1 : 0);
        });

    final track = BytesBuilder();
    if (name != null && name.isNotEmpty) {
      final text = utf8.encode(name);
      track
        ..add(_varLength(0))
        ..add([0xFF, 0x03])
        ..add(_varLength(text.length))
        ..add(text);
    }
    track
      ..add(_varLength(0))
      ..add([0xFF, 0x51, 0x03])
      ..add([
        microsecondsPerQuarter >> 16 & 0xFF,
        microsecondsPerQuarter >> 8 & 0xFF,
        microsecondsPerQuarter & 0xFF,
      ]);
    var last = 0;
    for (final (tick, on, key) in events) {
      track
        ..add(_varLength(tick - last))
        ..add([on ? 0x90 : 0x80, key & 0x7F, on ? velocity : 0]);
      last = tick;
    }
    track
      ..add(_varLength(0))
      ..add([0xFF, 0x2F, 0x00]);
    final body = track.takeBytes();

    return (BytesBuilder()
          ..add('MThd'.codeUnits)
          ..add(_uint32(6))
          ..add(_uint16(0))
          ..add(_uint16(1))
          ..add(_uint16(ticksPerQuarter))
          ..add('MTrk'.codeUnits)
          ..add(_uint32(body.length))
          ..add(body))
        .takeBytes();
  }

  /// Las notas de un archivo MIDI (de cualquier canal y pista), con sus
  /// cambios de tempo. Lanza [FormatException] si no es un archivo MIDI.
  static List<PianoNote> decode(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    if (bytes.length < 14 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      throw const FormatException('No es un archivo MIDI');
    }
    final headerLength = data.getUint32(4);
    final tracks = data.getUint16(10);
    final division = data.getUint16(12);
    if (division & 0x8000 != 0) {
      throw const FormatException('Tiempo SMPTE no admitido');
    }

    // Todos los eventos de todas las pistas, con su tiempo en divisiones.
    final tempos = <(int, int)>[(0, microsecondsPerQuarter)];
    final noteEvents = <(int, bool, int)>[];
    var offset = 8 + headerLength;
    for (var t = 0; t < tracks && offset + 8 <= bytes.length; t++) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final length = data.getUint32(offset + 4);
      final start = offset + 8;
      final end = (start + length).clamp(start, bytes.length);
      offset = end;
      if (id != 'MTrk') continue;
      var position = start;
      var tick = 0;
      var status = 0;
      int readVar() {
        var value = 0;
        while (position < end) {
          final byte = bytes[position++];
          value = (value << 7) | (byte & 0x7F);
          if (byte & 0x80 == 0) break;
        }
        return value;
      }

      while (position < end) {
        tick += readVar();
        if (position >= end) break;
        final byte = bytes[position];
        if (byte & 0x80 != 0) {
          status = byte;
          position++;
        }
        if (status == 0xFF) {
          final type = bytes[position++];
          final size = readVar();
          if (type == 0x51 && size == 3 && position + 3 <= end) {
            tempos.add((
              tick,
              bytes[position] << 16 |
                  bytes[position + 1] << 8 |
                  bytes[position + 2],
            ));
          }
          position += size;
          // Los metaeventos no cuentan para el estado continuo.
          status = 0;
          continue;
        }
        if (status == 0xF0 || status == 0xF7) {
          position += readVar();
          status = 0;
          continue;
        }
        final kind = status & 0xF0;
        final dataBytes = kind == 0xC0 || kind == 0xD0 ? 1 : 2;
        if (position + dataBytes > end) break;
        final first = bytes[position];
        final second = dataBytes == 2 ? bytes[position + 1] : 0;
        position += dataBytes;
        if (kind == 0x90 && second > 0) {
          noteEvents.add((tick, true, first));
        } else if (kind == 0x80 || (kind == 0x90 && second == 0)) {
          noteEvents.add((tick, false, first));
        }
      }
    }

    tempos.sort((a, b) => a.$1.compareTo(b.$1));
    Duration timeOf(int tick) {
      var micros = 0.0;
      var previousTick = 0;
      var tempo = microsecondsPerQuarter;
      for (final (at, value) in tempos) {
        if (at >= tick) break;
        micros += (at - previousTick) * tempo / division;
        previousTick = at;
        tempo = value;
      }
      micros += (tick - previousTick) * tempo / division;
      return Duration(microseconds: micros.round());
    }

    noteEvents.sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      if (byTime != 0) return byTime;
      return (a.$2 ? 1 : 0).compareTo(b.$2 ? 1 : 0);
    });
    final open = <int, int>{};
    final notes = <PianoNote>[];
    for (final (tick, on, key) in noteEvents) {
      if (on) {
        open[key] ??= tick;
      } else if (open.remove(key) case final start?) {
        final from = timeOf(start);
        notes.add(
          PianoNote(key: key, start: from, duration: timeOf(tick) - from),
        );
      }
    }
    return notes..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<int> _varLength(int value) {
    final bytes = [value & 0x7F];
    value >>= 7;
    while (value > 0) {
      bytes.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }
    return bytes;
  }

  static List<int> _uint32(int value) => [
    value >> 24 & 0xFF,
    value >> 16 & 0xFF,
    value >> 8 & 0xFF,
    value & 0xFF,
  ];

  static List<int> _uint16(int value) => [value >> 8 & 0xFF, value & 0xFF];
}
