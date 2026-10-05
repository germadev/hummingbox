import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_edit.dart';
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/audio/levels.dart';
import 'package:voicerecorder/models/piano_note.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/recording_editor.dart';
import 'package:voicerecorder/services/recordings_repository.dart';

import 'fakes.dart';
import 'wav_helpers.dart';

void main() {
  late Directory root;
  late Directory library;
  late Directory temp;
  late CopyingAudioCodec codec;
  late FileRecordingsRepository repository;
  late Recording recording;

  RecordingEditor newEditor({bool useIsolates = false}) => RecordingEditor(
    codec: codec,
    repository: repository,
    workDirectory: () async => temp,
    useIsolates: useIsolates,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('editor_test');
    library = Directory(p.join(root.path, 'recordings'));
    temp = await Directory(p.join(root.path, 'tmp')).create();
    codec = CopyingAudioCodec();
    repository = FileRecordingsRepository(
      directory: () async => library,
      clock: () => testNow,
    );

    // El "m4a" de la grabación es un WAV: el códec de prueba solo copia.
    final path = await repository.createRecordingPath();
    final source = await writeWav(root, 'source.wav', [
      for (var i = 0; i < 4000; i++) 1000,
    ]);
    await File(source).rename(path);
    recording = (await repository.add(
      path: path,
      duration: const Duration(seconds: 4),
    ))!;
  });

  tearDown(() => root.delete(recursive: true));

  test('abre la grabación y calcula su onda detallada', () async {
    final editor = newEditor();
    final session = await editor.open(recording);

    expect(session.duration, const Duration(seconds: 4));
    expect(session.analysis.peaks, hasLength(RecordingEditor.editorResolution));
    expect(session.analysis.peak, closeTo(1000 / 32768, 1e-9));
    expect(File(session.sourcePath).existsSync(), isTrue);

    await editor.close(session);
    expect(session.directory.existsSync(), isFalse);
  });

  test('reemplaza el audio original y aumenta la revisión', () async {
    final editor = newEditor();
    final session = await editor.open(recording);

    final edited = await editor.save(
      session,
      const AudioEdit(
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        gainDb: 6.0206,
      ),
      asCopy: false,
    );
    await editor.close(session);

    expect(edited.id, recording.id);
    expect(edited.path, recording.path);
    expect(edited.revision, 1);
    expect(edited.duration, const Duration(seconds: 2));
    expect(edited.waveform, hasLength(waveformResolution));
    final samples = await readSamples(recording.path);
    expect(samples, hasLength(2000));
    expect(samples.toSet(), {2000});
    expect(codec.calls, [
      'decode ${p.basename(recording.path)}',
      'encode edited.wav',
    ]);

    final reloaded = (await repository.loadAll()).single;
    expect(reloaded.revision, 1);
    expect(reloaded.duration, const Duration(seconds: 2));
    expect(reloaded.name, recording.name);
  });

  test('guarda la edición como una grabación nueva', () async {
    final editor = newEditor();
    final session = await editor.open(recording);

    final copy = await editor.save(
      session,
      const AudioEdit(start: Duration.zero, end: Duration(seconds: 1)),
      asCopy: true,
    );
    await editor.close(session);

    expect(copy.id, isNot(recording.id));
    expect(copy.name, '2026-10-05 14.32 (editada)');
    expect(copy.duration, const Duration(seconds: 1));
    expect(await readSamples(copy.path), hasLength(1000));
    // El original no cambia.
    expect(await readSamples(recording.path), hasLength(4000));
    expect(await repository.loadAll(), hasLength(2));
  });

  test('procesa en un isolate aparte', () async {
    final editor = newEditor(useIsolates: true);
    final session = await editor.open(recording);
    final edited = await editor.save(
      session,
      const AudioEdit(start: Duration.zero, end: Duration(seconds: 2)),
      asCopy: false,
    );
    await editor.close(session);

    expect(edited.duration, const Duration(seconds: 2));
  });

  test('calcula la onda de una grabación sin ella', () async {
    final levels = await newEditor().extractWaveform(recording);

    expect(levels, hasLength(waveformResolution));
    expect(levels.toSet(), {closeTo(levelFromPeak(1000 / 32768), 1e-9)});
    // No deja archivos temporales.
    expect(Directory(p.join(temp.path, 'editor')).listSync(), isEmpty);
  });

  test('vuelve a codificar el AAC con su tasa de bits', () async {
    final low = await repository.setDetails(
      recording,
      audio: const AudioInfo(
        format: RecordingFormat.aac,
        sampleRate: 16000,
        channels: 1,
        bitRate: 32000,
      ),
    );
    final editor = newEditor();
    final session = await editor.open(low);
    await editor.save(
      session,
      const AudioEdit(start: Duration.zero, end: Duration(seconds: 1)),
      asCopy: false,
    );
    await editor.close(session);

    expect(codec.bitRate, 32000);
  });

  test('un WAV se edita y se guarda como WAV, sin códecs', () async {
    final path = await repository.createRecordingPath(
      format: RecordingFormat.wav,
    );
    await File(
      await writeWav(root, 'voz.wav', [for (var i = 0; i < 3000; i++) 500]),
    ).rename(path);
    final wav = (await repository.add(
      path: path,
      duration: const Duration(seconds: 3),
    ))!;

    final editor = newEditor();
    final session = await editor.open(wav);
    final copy = await editor.save(
      session,
      const AudioEdit(start: Duration.zero, end: Duration(seconds: 2)),
      asCopy: true,
    );
    await editor.close(session);

    expect(codec.calls, isEmpty);
    expect(p.extension(copy.path), '.wav');
    expect(await readSamples(copy.path), hasLength(2000));
    expect(copy.audio?.format, RecordingFormat.wav);
    expect(copy.audio?.sampleRate, 1000);
  });

  test('genera la escucha previa con el volumen aplicado', () async {
    final editor = newEditor();
    final session = await editor.open(recording);

    final first = await editor.renderPreview(
      session,
      const AudioEdit(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        gainDb: 6.0206,
      ),
    );
    final second = await editor.renderPreview(
      session,
      const AudioEdit(start: Duration.zero, end: Duration(seconds: 4)),
    );

    expect(second, isNot(first));
    final samples = await readSamples(first);
    expect(samples, hasLength(1000));
    expect(samples.toSet(), {2000});
    // El original no cambia y los archivos se borran al cerrar.
    expect(await readSamples(recording.path), hasLength(4000));
    await editor.close(session);
    expect(File(first).existsSync(), isFalse);
  });

  test('borra los temporales si no se puede abrir', () async {
    codec.decodedSource = p.join(root.path, 'no_existe.wav');

    await expectLater(newEditor().open(recording), throwsA(anything));
    expect(Directory(p.join(temp.path, 'editor')).listSync(), isEmpty);
  });

  group('piano', () {
    const notes = [
      PianoNote(
        key: 60,
        start: Duration(milliseconds: 500),
        duration: Duration(milliseconds: 300),
      ),
      PianoNote(
        key: 64,
        start: Duration(milliseconds: 1500),
        duration: Duration(milliseconds: 300),
      ),
    ];

    /// Índice de la primera muestra que no es silencio.
    int firstSound(List<int> samples) =>
        samples.indexWhere((s) => s.abs() > 50);

    test('guarda solo el piano: cada nota suena cuando se tocó', () async {
      final editor = newEditor();
      final saved = await editor.savePiano(
        notes: notes,
        duration: const Duration(seconds: 2),
        options: const RecordingOptions(format: RecordingFormat.wav),
        folder: 'Ideas',
      );

      expect(saved.hasVoice, isFalse);
      expect(saved.notes, notes);
      expect(saved.folder, 'Ideas');
      expect(saved.format, RecordingFormat.wav);
      // Dura hasta que se apaga la última nota.
      expect(saved.duration, const Duration(milliseconds: 3100));

      final samples = await readSamples(saved.path);
      final rate = const RecordingOptions(format: RecordingFormat.wav)
          .sampleRate;
      expect(firstSound(samples), closeTo(rate * 0.5, rate * 0.01));
      // Entre que empieza la primera y la segunda pasa un segundo, como al
      // tocarlas.
      final second = firstSound(samples.sublist(rate * 1495 ~/ 1000));
      expect(second, lessThan(rate * 0.02));
    });

    test('añade el piano a la voz y conserva la onda de la voz', () async {
      final editor = newEditor();
      final voice = await repository.setDetails(recording, waveform: [0.5]);

      final mixed = await editor.addPiano(voice, notes);

      expect(mixed.notes, notes);
      expect(mixed.hasVoice, isTrue);
      expect(mixed.revision, 1);
      expect(mixed.waveform, [0.5]);
      expect(mixed.duration, const Duration(seconds: 4));
      final samples = await readSamples(mixed.path);
      expect(samples, hasLength(4000));
      // Antes de la primera nota, solo la voz.
      expect(samples.take(500), everyElement(1000));
      expect(samples.skip(505).take(100), anyElement(isNot(1000)));
    });

    test('al añadir piano otra vez, se suman a las que tenía', () async {
      final editor = newEditor();
      final first = await editor.addPiano(recording, [notes[1]]);

      final second = await editor.addPiano(first, [notes[0]]);

      expect(second.notes, notes);
      expect(second.revision, 2);
    });

    test(
      'al recortar, las notas que quedan van desde el nuevo principio',
      () async {
        final editor = newEditor();
        final withNotes = await repository.setNotes(recording, notes);
        final session = await editor.open(withNotes);

        final edited = await editor.save(
          session,
          const AudioEdit(
            start: Duration(milliseconds: 1000),
            end: Duration(seconds: 4),
          ),
          asCopy: false,
        );
        await editor.close(session);

        expect(edited.notes, [
          const PianoNote(
            key: 64,
            start: Duration(milliseconds: 500),
            duration: Duration(milliseconds: 300),
          ),
        ]);
      },
    );
  });
}
