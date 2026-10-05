import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/midi.dart';
import 'package:voicerecorder/models/instrument.dart';
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

  test('cada instrumento en su canal y con su programa', () {
    PianoNote played(int key, int start, Instrument instrument) => PianoNote(
      key: key,
      start: Duration(milliseconds: start),
      duration: const Duration(milliseconds: 400),
      instrument: instrument,
    );
    final notes = [
      played(60, 0, Instrument.piano),
      // La misma tecla a la vez con otro instrumento.
      played(60, 0, Instrument.synth),
      played(64, 200, Instrument.organ),
      played(67, 300, Instrument.guitar),
      played(72, 400, Instrument.marimba),
    ];

    final bytes = Midi.encode(notes);
    // Los cambios de programa, al principio.
    for (final instrument in Instrument.values) {
      expect(
        _contains(bytes, [0, 0xC0 | instrument.index, instrument.program]),
        isTrue,
        reason: '$instrument',
      );
    }
    final decoded = Midi.decode(bytes);
    expect(
      {for (final note in decoded) (note.key, note.instrument)},
      {for (final note in notes) (note.key, note.instrument)},
    );
  });

  test('los programas de otros archivos, al instrumento más parecido', () {
    expect(Instrument.forProgram(1), Instrument.piano);
    expect(Instrument.forProgram(19), Instrument.organ);
    expect(Instrument.forProgram(27), Instrument.guitar);
    expect(Instrument.forProgram(11), Instrument.marimba);
    expect(Instrument.forProgram(90), Instrument.synth);
    expect(Instrument.forProgram(56), Instrument.piano);
    final bytes = [
      ...'MThd'.codeUnits, 0, 0, 0, 6, 0, 0, 0, 1, 0, 96, //
      ...'MTrk'.codeUnits, 0, 0, 0, 14,
      0, 0xC3, 19, // canal 4: un órgano
      0, 0x93, 60, 100,
      96, 0x83, 60, 0,
      0, 0xFF, 0x2F, 0x00,
    ];
    expect(Midi.decode(bytes).single.instrument, Instrument.organ);
  });
}

bool _contains(List<int> bytes, List<int> part) {
  for (var i = 0; i + part.length <= bytes.length; i++) {
    var all = true;
    for (var j = 0; j < part.length && all; j++) {
      all = bytes[i + j] == part[j];
    }
    if (all) return true;
  }
  return false;
}
