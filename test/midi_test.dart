import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/midi.dart';
import 'package:voicerecorder/models/piano_note.dart';

void main() {
  PianoNote note(int key, int start, int duration) => PianoNote(
    key: key,
    start: Duration(milliseconds: start),
    duration: Duration(milliseconds: duration),
  );

  test('es un MIDI estándar de una pista', () {
    final bytes = Midi.encode([note(60, 0, 500)]);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'MThd');
    // Formato 0, una pista, 480 divisiones por negra.
    expect(bytes.sublist(8, 14), [0, 0, 0, 1, 1, 224]);
    expect(String.fromCharCodes(bytes.sublist(14, 18)), 'MTrk');
    expect(bytes.sublist(bytes.length - 3), [0xFF, 0x2F, 0x00]);
  });

  test('conserva las notas y sus tiempos', () {
    final notes = [
      note(60, 0, 500),
      note(64, 480, 1000),
      note(67, 480, 1000),
      // La misma tecla justo al soltarla.
      note(60, 500, 250),
      note(72, 61234, 3),
    ];

    final decoded = Midi.decode(Midi.encode(notes));

    expect(decoded, hasLength(notes.length));
    for (var i = 0; i < notes.length; i++) {
      expect(decoded[i].key, notes[i].key);
      expect(
        (decoded[i].start - notes[i].start).inMicroseconds.abs(),
        lessThan(1100),
      );
      expect(
        (decoded[i].duration - notes[i].duration).inMicroseconds.abs(),
        lessThan(2100),
      );
    }
  });

  test('lee el estado continuo, las sueltas con velocidad 0 y el tempo', () {
    final bytes = [
      ...'MThd'.codeUnits, 0, 0, 0, 6, 0, 0, 0, 1, 0, 96, //
      ...'MTrk'.codeUnits, 0, 0, 0, 18,
      // A 60 negras por minuto: una negra (96) es un segundo.
      0, 0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40,
      0, 0x90, 69, 100,
      96, 69, 0, // estado continuo, velocidad 0 = soltar
      0, 0xFF, 0x2F, 0x00,
    ];

    expect(Midi.decode(bytes), [note(69, 0, 1000)]);
  });

  test('si no es MIDI, lanza FormatException', () {
    expect(() => Midi.decode([1, 2, 3]), throwsFormatException);
  });
}
