import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/models/instrument.dart';
import 'package:voicerecorder/models/piano_note.dart';
import 'package:voicerecorder/models/synth_patch.dart';

void main() {
  test('en los metadatos, el instrumento solo si no es el piano', () {
    const piano = PianoNote(
      key: 60,
      start: Duration(milliseconds: 1000),
      duration: Duration(milliseconds: 250),
    );
    const organ = PianoNote(
      key: 64,
      start: Duration(milliseconds: 1500),
      duration: Duration(milliseconds: 500),
      instrument: Instrument.organ,
    );
    expect(piano.toJson(), [60, 1000, 250]);
    expect(organ.toJson(), [64, 1500, 500, 'organ']);
    expect(PianoNote.listFromJson([organ.toJson(), piano.toJson()]), [
      piano,
      organ,
    ]);
    // Uno que no se conoce, el piano; lo que no se entiende, fuera.
    expect(
      PianoNote.listFromJson([
        [60, 0, 100, 'theremin'],
        [60, 0, 100, 'organ', 'extra', 'more'],
        [60, 0],
      ]),
      [
        const PianoNote(
          key: 60,
          start: Duration.zero,
          duration: Duration(milliseconds: 100),
        ),
      ],
    );
  });

  test('en los metadatos, el sonido del sintetizador si no es el de por '
      'defecto', () {
    const synth = SynthPatch(wave: SynthWave.square, sustain: 0.5);
    const custom = PianoNote(
      key: 60,
      start: Duration.zero,
      duration: Duration(milliseconds: 100),
      instrument: Instrument.synth,
      synth: synth,
    );
    const plain = PianoNote(
      key: 62,
      start: Duration(milliseconds: 100),
      duration: Duration(milliseconds: 100),
      instrument: Instrument.synth,
    );
    expect(plain.toJson(), [62, 100, 100, 'synth']);
    expect(custom.toJson(), hasLength(5));
    final read = PianoNote.listFromJson([custom.toJson(), plain.toJson()]);
    expect(read, [custom, plain]);
    expect(read.first.synth, synth);
    expect(read.last.synth, const SynthPatch());
  });

  test('al recortar, cada nota conserva su instrumento', () {
    const notes = [
      PianoNote(
        key: 60,
        start: Duration(milliseconds: 500),
        duration: Duration(milliseconds: 1000),
        instrument: Instrument.synth,
      ),
      PianoNote(
        key: 62,
        start: Duration(milliseconds: 2000),
        duration: Duration(milliseconds: 100),
        instrument: Instrument.guitar,
      ),
    ];
    expect(
      PianoNote.between(
        notes,
        const Duration(seconds: 1),
        const Duration(seconds: 3),
      ).map((note) => note.instrument),
      [Instrument.synth, Instrument.guitar],
    );
  });
}
