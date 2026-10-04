import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_edit.dart';
import 'package:voicerecorder/audio/levels.dart';
import 'package:voicerecorder/models/recording.dart';
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
    repository = FileRecordingsRepository(directory: () async => library);

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
    expect(copy.name, 'Grabación 1 (editada)');
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

  test('borra los temporales si no se puede abrir', () async {
    codec.decodedSource = p.join(root.path, 'no_existe.wav');

    await expectLater(newEditor().open(recording), throwsA(anything));
    expect(Directory(p.join(temp.path, 'editor')).listSync(), isEmpty);
  });
}
