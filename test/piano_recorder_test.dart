import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/piano_recorder.dart';
import 'package:voicerecorder/controllers/recorder_controller.dart';
import 'package:voicerecorder/models/recording_options.dart';

import 'fakes.dart';

void main() {
  late InMemoryRecordingsRepository repository;
  late FakeAudioRecorderService recorder;
  late RecorderController voice;
  late FakeRecordingEditor editor;
  late PianoRecorder piano;

  setUp(() {
    repository = InMemoryRecordingsRepository();
    recorder = FakeAudioRecorderService();
    voice = RecorderController(recorder: recorder, repository: repository);
    editor = FakeRecordingEditor(repository: repository);
    piano = PianoRecorder(voice: voice, editor: editor);
  });

  tearDown(() {
    piano.dispose();
    voice.dispose();
  });

  Future<void> wait(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  test(
    'solo piano: guarda las notas con la cadencia con que se tocaron',
    () async {
      expect(
        await piano.start(
          PianoRecordingMode.piano,
          options: const RecordingOptions(),
          folder: 'Ideas',
        ),
        isTrue,
      );
      expect(piano.isRecording, isTrue);
      expect(recorder.calls, isEmpty);

      piano.noteOn(60);
      await wait(40);
      piano.noteOff(60);
      await wait(80);
      piano.noteOn(64);
      // Se para con la tecla pulsada: la nota termina al parar.
      await wait(20);
      final saved = await piano.stop();

      expect(piano.isRecording, isFalse);
      expect(saved!.hasVoice, isFalse);
      expect(saved.folder, 'Ideas');
      final notes = saved.notes;
      expect(notes.map((n) => n.key), [60, 64]);
      expect(notes[0].duration.inMilliseconds, greaterThanOrEqualTo(40));
      final gap = notes[1].start - notes[0].start;
      expect(gap.inMilliseconds, inInclusiveRange(120, 300));
      expect(notes[1].duration.inMilliseconds, greaterThanOrEqualTo(20));
      expect(editor.pianoSaves.single.$1, notes);
    },
  );

  test('solo piano sin notas no guarda nada', () async {
    await piano.start(
      PianoRecordingMode.piano,
      options: const RecordingOptions(),
    );
    expect(await piano.stop(), isNull);
    expect(editor.pianoSaves, isEmpty);
    expect(repository.recordings, isEmpty);
  });

  test('con voz: graba con el micrófono y añade las notas', () async {
    await piano.start(
      PianoRecordingMode.pianoAndVoice,
      options: const RecordingOptions(),
    );
    expect(recorder.calls, ['hasPermission', 'start']);
    expect(voice.isActive, isTrue);

    await wait(30);
    piano.noteOn(69);
    await wait(30);
    piano.noteOff(69);
    final saved = await piano.stop();

    expect(voice.isActive, isFalse);
    expect(saved!.hasVoice, isTrue);
    expect(saved.notes.single.key, 69);
    // Desde que empezó la grabación de la voz.
    expect(saved.notes.single.start.inMilliseconds, greaterThanOrEqualTo(30));
    expect(editor.pianoAdded[saved.id], saved.notes);
  });

  test('con voz y sin permiso del micrófono no empieza', () async {
    recorder.permissionGranted = false;
    expect(
      await piano.start(
        PianoRecordingMode.pianoAndVoice,
        options: const RecordingOptions(),
      ),
      isFalse,
    );
    expect(piano.isRecording, isFalse);
  });

  test('sin grabar no registra notas', () async {
    piano.noteOn(60);
    piano.noteOff(60);
    expect(await piano.stop(), isNull);
  });
}
