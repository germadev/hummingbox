import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/services/recordings_repository.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FileRecordingsRepository repository;

  /// Fecha de las grabaciones nuevas.
  var now = testNow;

  FileRecordingsRepository newRepository() => FileRecordingsRepository(
    directory: () async => directory,
    clock: () => now,
  );

  /// Crea un archivo de audio de prueba en una ruta nueva.
  Future<String> createAudioFile() async {
    final path = await repository.createRecordingPath();
    await File(path).writeAsBytes([1, 2, 3]);
    return path;
  }

  setUp(() async {
    final root = await Directory.systemTemp.createTemp('recordings_test');
    // La carpeta todavía no existe: el repositorio debe crearla.
    directory = Directory(p.join(root.path, 'recordings'));
    now = testNow;
    repository = newRepository();
  });

  tearDown(() async {
    await directory.parent.delete(recursive: true);
  });

  test('crea rutas .m4a únicas dentro de su carpeta', () async {
    final first = await createAudioFile();
    final second = await repository.createRecordingPath();

    expect(p.dirname(first), directory.path);
    expect(p.extension(first), '.m4a');
    expect(second, isNot(first));
  });

  test('crea rutas .wav y no repite el id de otro formato', () async {
    final m4a = await createAudioFile();
    final wav = await repository.createRecordingPath(
      format: RecordingFormat.wav,
    );

    expect(p.extension(wav), '.wav');
    expect(
      p.basenameWithoutExtension(wav),
      isNot(p.basenameWithoutExtension(m4a)),
    );
  });

  test('lista las grabaciones de los dos formatos', () async {
    final m4a = await createAudioFile();
    final wav = await repository.createRecordingPath(
      format: RecordingFormat.wav,
    );
    await File(wav).writeAsBytes([1]);

    final all = await repository.loadAll();

    expect(all.map((r) => r.path).toSet(), {m4a, wav});
    expect(all.firstWhere((r) => r.path == wav).format, RecordingFormat.wav);
  });

  test('guarda el formato, la fecha y los detalles calculados', () async {
    const audio = AudioInfo(
      format: RecordingFormat.aac,
      sampleRate: 16000,
      channels: 1,
      bitRate: 32000,
    );
    final createdAt = DateTime(2026, 5, 1, 10, 30);
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: Duration.zero,
      createdAt: createdAt,
      audio: audio,
      folder: 'Clases',
    );
    expect(recording!.audio, audio);

    await repository.setDetails(
      recording,
      waveform: [0.5],
      duration: const Duration(seconds: 7),
    );

    final reloaded = (await newRepository().loadAll()).single;
    expect(reloaded.createdAt, createdAt);
    expect(reloaded.audio, audio);
    expect(reloaded.folder, 'Clases');
    expect(reloaded.waveform, [0.5]);
    expect(reloaded.duration, const Duration(seconds: 7));
  });

  test('no registra archivos que no existen', () async {
    final path = await repository.createRecordingPath();

    expect(await repository.add(path: path, duration: Duration.zero), isNull);
    expect(await repository.loadAll(), isEmpty);
  });

  test('añade grabaciones con la fecha y la hora y las lista de la más '
      'antigua a la más nueva', () async {
    final first = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 5),
    );
    now = DateTime(2026, 10, 5, 14, 33);
    final second = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 12),
    );

    expect(first!.name, '2026-10-05 14.32');
    expect(first.provisionalName, isTrue);
    expect(second!.name, '2026-10-05 14.33');

    final all = await repository.loadAll();
    expect(all.map((r) => r.id), [first.id, second.id]);
    expect(all.last.duration, const Duration(seconds: 12));
  });

  test('conserva los metadatos entre sesiones', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(milliseconds: 4321),
    );
    await repository.rename(recording!, '  Entrevista  ');

    final reloaded = await newRepository().loadAll();
    expect(reloaded.single.name, 'Entrevista');
    expect(reloaded.single.duration, const Duration(milliseconds: 4321));
    expect(reloaded.single.createdAt, recording.createdAt);
  });

  test('elimina el archivo y sus metadatos', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: Duration.zero,
    );

    await repository.delete(recording!);

    expect(File(recording.path).existsSync(), isFalse);
    expect(await repository.loadAll(), isEmpty);
    final index = File(p.join(directory.path, 'recordings.json'));
    expect(index.readAsStringSync(), isNot(contains(recording.id)));
  });

  test('descarta archivos sin registrar', () async {
    final path = await createAudioFile();

    await repository.discard(path);

    expect(File(path).existsSync(), isFalse);
  });

  test('lista los audios sin metadatos e ignora otros archivos', () async {
    final path = await createAudioFile();
    await File(p.join(directory.path, 'notas.txt')).writeAsString('hola');

    final all = await repository.loadAll();

    expect(all.single.path, path);
    expect(all.single.name, p.basenameWithoutExtension(path));
    expect(all.single.duration, Duration.zero);
  });

  test('tolera un índice corrupto', () async {
    await repository.add(
      path: await createAudioFile(),
      duration: Duration.zero,
    );
    await File(p.join(directory.path, 'recordings.json'))
        .writeAsString('{no es json');

    expect(await newRepository().loadAll(), hasLength(1));
  });

  test('guarda la onda, la revisión y las copias', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 3),
      waveform: [0, 0.5, 1],
      name: 'Entrevista',
    );
    expect(recording!.name, 'Entrevista');

    const copy = CopyState(
      destination: 'tree://music',
      ref: 'doc1',
      revision: 0,
      name: 'Entrevista',
    );
    await repository.setCopy(recording, 'folder', copy);

    final reloaded = (await newRepository().loadAll()).single;
    expect(reloaded.waveform, [0, 0.5, 1]);
    expect(reloaded.revision, 0);
    expect(reloaded.copies, {'folder': copy});

    await repository.setCopy(reloaded, 'folder', null);
    expect((await newRepository().loadAll()).single.copies, isEmpty);
  });

  test('sustituye el audio y aumenta la revisión', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 5),
      waveform: [1],
    );
    final edited = p.join(directory.parent.path, 'edited.m4a');
    await File(edited).writeAsBytes([9, 9]);

    final replaced = await repository.replaceAudio(
      recording!,
      sourcePath: edited,
      duration: const Duration(seconds: 2),
      waveform: [0.5, 0.5],
    );

    expect(replaced.revision, 1);
    expect(replaced.duration, const Duration(seconds: 2));
    expect(replaced.waveform, [0.5, 0.5]);
    expect(File(recording.path).readAsBytesSync(), [9, 9]);
    expect(File(edited).existsSync(), isFalse);
    expect((await newRepository().loadAll()).single.revision, 1);
  });

  test('los cambios simultáneos no se pisan', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: Duration.zero,
    );

    // Se parte de la misma copia (desactualizada) de la grabación.
    await Future.wait([
      repository.rename(recording!, 'Nuevo nombre'),
      repository.setDetails(recording, waveform: [0.3]),
      repository.setCopy(
        recording,
        'drive',
        const CopyState(
          destination: 'f',
          ref: 'id',
          revision: 0,
          name: 'Grabación 1',
        ),
      ),
    ]);

    final reloaded = (await newRepository().loadAll()).single;
    expect(reloaded.name, 'Nuevo nombre');
    expect(reloaded.waveform, [0.3]);
    expect(reloaded.copies.keys, ['drive']);
  });

  test('no vuelve a añadir al índice una grabación borrada', () async {
    final recording = await repository.add(
      path: await createAudioFile(),
      duration: Duration.zero,
    );
    await repository.delete(recording!);

    await repository.setCopy(
      recording,
      'drive',
      const CopyState(destination: 'f', ref: 'id', revision: 0, name: 'x'),
    );
    await repository.setDetails(recording, waveform: [0.5]);
    await repository.rename(recording, 'Fantasma');

    final index = File(p.join(directory.path, 'recordings.json'));
    expect(index.readAsStringSync(), isNot(contains(recording.id)));
  });

  group('nombres', () {
    Transcript transcript(String text) =>
        Transcript(text: text, revision: 0, createdAt: testNow);

    Future<Recording> addNew({String folder = ''}) async =>
        (await repository.add(
          path: await createAudioFile(),
          duration: Duration.zero,
          folder: folder,
        ))!;

    test('en la misma carpeta y el mismo minuto, con un número', () async {
      final first = await addNew();
      final second = await addNew();
      final other = await addNew(folder: 'Clases');

      expect(first.name, '2026-10-05 14.32');
      expect(second.name, '2026-10-05 14.32 (2)');
      expect(other.name, '2026-10-05 14.32');
    });

    test('al transcribirla, se llama como empieza la transcripción, y se '
        'conserva entre sesiones', () async {
      final recording = await addNew();

      final transcribed = await repository.setTranscript(
        recording,
        transcript(' ¿Hola, qué tal? Esto es una prueba de nombres largos.'),
      );

      // Sin lo que no vale en un nombre de archivo («?») ni la puntuación
      // del principio.
      expect(
        transcribed.name,
        '2026-10-05.Hola, qué tal Esto es una prueba de nombres largos',
      );
      expect(transcribed.provisionalName, isFalse);
      final reloaded = (await newRepository().loadAll()).single;
      expect(reloaded.name, transcribed.name);
      expect(reloaded.provisionalName, isFalse);
    });

    test('solo la primera vez: al volver a transcribirla no cambia', () async {
      final recording = await repository.setTranscript(
        await addNew(),
        transcript('Primera'),
      );

      final again = await repository.setTranscript(
        recording,
        transcript('Segunda'),
      );

      expect(again.name, '2026-10-05.Primera');
    });

    test('sin palabras se queda con la fecha y la hora', () async {
      final recording = await addNew();

      final silent = await repository.setTranscript(recording, null);
      expect(silent.name, '2026-10-05 14.32');
      expect(silent.provisionalName, isTrue);

      final symbols = await repository.setTranscript(
        recording,
        transcript(' … '),
      );
      expect(symbols.name, '2026-10-05 14.32');
    });

    test('no repite el nombre de otra de la carpeta', () async {
      await repository.setTranscript(await addNew(), transcript('Hola'));
      final second = await repository.setTranscript(
        await addNew(),
        transcript('hola.'),
      );

      expect(second.name, '2026-10-05.hola (2)');
    });

    test('si se renombra, ya no cambia al transcribirla', () async {
      final renamed = await repository.rename(await addNew(), 'Idea');
      expect(renamed.provisionalName, isFalse);

      final transcribed = await repository.setTranscript(
        renamed,
        transcript('Hola'),
      );

      expect(transcribed.name, 'Idea');
    });

    test('las que tienen nombre no lo cambian al transcribirlas', () async {
      final recording = (await repository.add(
        path: await createAudioFile(),
        duration: Duration.zero,
        name: 'Entrevista',
      ))!;

      final transcribed = await repository.setTranscript(
        recording,
        transcript('Hola'),
      );

      expect(transcribed.name, 'Entrevista');
    });
  });

  group('guardadas fuera de la app', () {
    const file = CopyState(
      destination: 'tree://music',
      ref: 'doc1',
      revision: 0,
      name: 'Idea',
      size: 3,
    );

    test('aparecen aunque su audio no esté en la app', () async {
      final path = await repository.createRecordingPath(
        format: RecordingFormat.wav,
      );
      final added = await repository.add(
        path: path,
        duration: Duration.zero,
        name: 'Idea',
        copies: {'folder': file},
      );

      expect(added, isNotNull);
      expect(File(path).existsSync(), isFalse);
      final loaded = (await newRepository().loadAll()).single;
      expect(loaded.name, 'Idea');
      expect(loaded.path, path);
      expect(loaded.format, RecordingFormat.wav);
      expect(loaded.copies['folder'], file);
    });

    test('las rutas nuevas no repiten su id', () async {
      final path = await repository.createRecordingPath();
      await repository.add(
        path: path,
        duration: Duration.zero,
        copies: {'folder': file},
      );

      expect(await repository.createRecordingPath(), isNot(path));
    });

    test('saca el audio de la app solo si ya está guardado', () async {
      final path = await createAudioFile();
      var recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;
      final cache = p.join(directory.parent.path, 'cache', 'a.m4a');

      expect(
        await repository.releaseAudio(recording, key: 'folder', moveTo: cache),
        isFalse,
      );
      recording = await repository.setCopy(
        recording,
        'folder',
        CopyState(
          destination: 'tree://music',
          ref: 'doc1',
          revision: recording.revision,
          name: recording.name,
        ),
      );
      expect(
        await repository.releaseAudio(recording, key: 'folder', moveTo: cache),
        isTrue,
      );

      expect(File(path).existsSync(), isFalse);
      expect(File(cache).readAsBytesSync(), [1, 2, 3]);
      expect((await repository.loadAll()).single.id, recording.id);
    });

    test('no saca el audio si se ha editado entretanto', () async {
      final path = await createAudioFile();
      var recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;
      recording = await repository.setCopy(
        recording,
        'folder',
        CopyState(
          destination: 'tree://music',
          ref: 'doc1',
          revision: 0,
          name: recording.name,
        ),
      );
      final edited = p.join(directory.parent.path, 'edited.m4a');
      await File(edited).writeAsBytes([9]);
      await repository.replaceAudio(
        recording,
        sourcePath: edited,
        duration: Duration.zero,
      );

      final cache = p.join(directory.parent.path, 'cache', 'a.m4a');
      expect(
        await repository.releaseAudio(recording, key: 'folder', moveTo: cache),
        isFalse,
      );
      expect(File(path).readAsBytesSync(), [9]);
    });

    test(
      'al cambiar fuera de la app, olvida la onda y sube la revisión',
      () async {
        var recording = (await repository.add(
          path: await repository.createRecordingPath(),
          duration: const Duration(seconds: 4),
          waveform: const [0.5],
          name: 'Idea',
          copies: {'folder': file},
        ))!;

        recording = await repository.updateStoredFile(
          recording,
          'folder',
          file.copyWith(size: 10),
          audioChanged: true,
        );

        expect(recording.revision, 1);
        expect(recording.waveform, isNull);
        expect(recording.duration, Duration.zero);
        expect(recording.copies['folder']!.size, 10);
        expect(recording.isSavedIn('folder'), isTrue);
      },
    );

    test('guarda la transcripción y la conserva al editar', () async {
      final transcript = Transcript(
        text: 'Hola',
        engine: TranscriptionEngine.whisper,
        model: WhisperModel.base,
        language: 'es',
        revision: 0,
        createdAt: DateTime(2026, 10, 5, 10, 30),
      );
      final path = await repository.createRecordingPath();
      await File(path).writeAsBytes([1]);
      var recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;

      recording = await repository.setTranscript(recording, transcript);
      expect((await repository.loadAll()).single.transcript, transcript);
      expect(recording.isTranscriptOutdated, isFalse);

      final edited = p.join(directory.path, 'edited.m4a');
      await File(edited).writeAsBytes([2]);
      recording = await repository.replaceAudio(
        recording,
        sourcePath: edited,
        duration: Duration.zero,
      );
      expect(recording.transcript, transcript);
      expect(recording.isTranscriptOutdated, isTrue);

      recording = await repository.setTranscript(recording, null);
      expect((await repository.loadAll()).single.transcript, isNull);
    });

    test('sin transcripción, esa versión no se transcribe sola', () async {
      final path = await repository.createRecordingPath();
      await File(path).writeAsBytes([1]);
      var recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;
      expect(recording.needsTranscript, isTrue);

      await repository.setTranscript(recording, null);
      recording = (await repository.loadAll()).single;
      expect(recording.noAutoTranscript, 0);
      expect(recording.needsTranscript, isFalse);

      // Al editar el audio, sí.
      final edited = p.join(directory.path, 'edited.m4a');
      await File(edited).writeAsBytes([2]);
      recording = await repository.replaceAudio(
        recording,
        sourcePath: edited,
        duration: Duration.zero,
      );
      expect(recording.needsTranscript, isTrue);

      // Y al transcribirla, se olvida.
      recording = await repository.setTranscript(
        recording,
        Transcript(text: 'Hola', revision: 1, createdAt: DateTime(2026, 10, 5)),
      );
      expect(recording.noAutoTranscript, isNull);
    });

    test('guarda el idioma elegido para la grabación', () async {
      final path = await repository.createRecordingPath();
      await File(path).writeAsBytes([1]);
      final recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;
      expect(recording.transcriptionLanguage, isNull);

      final chosen = await repository.setTranscriptionLanguage(recording, 'en');
      expect(chosen.transcriptionLanguage, 'en');
      expect((await repository.loadAll()).single.transcriptionLanguage, 'en');

      // Se conserva al guardar la transcripción.
      await repository.setTranscript(
        chosen,
        Transcript(text: 'Hi', revision: 0, createdAt: DateTime(2026, 10, 5)),
      );
      expect((await repository.loadAll()).single.transcriptionLanguage, 'en');

      await repository.setTranscriptionLanguage(chosen, null);
      expect((await repository.loadAll()).single.transcriptionLanguage, isNull);
    });

    test('puede no sustituir la transcripción que ya tiene', () async {
      final path = await repository.createRecordingPath();
      await File(path).writeAsBytes([1]);
      final recording = (await repository.add(
        path: path,
        duration: Duration.zero,
      ))!;
      Transcript text(String text) =>
          Transcript(text: text, revision: 0, createdAt: DateTime(2026, 10, 5));
      await repository.setTranscript(recording, text('Del .txt'));

      final kept = await repository.setTranscript(
        recording,
        text('Automática'),
        keepExisting: true,
      );

      expect(kept.transcript!.text, 'Del .txt');
      expect((await repository.loadAll()).single.transcript!.text, 'Del .txt');
    });

    test('guarda el .txt de la transcripción y una sin motor', () async {
      final text = TranscriptFile(
        ref: 'doc9',
        name: 'Idea.txt',
        size: 4,
        checksum: 'abc',
        modified: DateTime(2026, 10, 5, 12),
      );
      final added = (await repository.add(
        path: await repository.createRecordingPath(),
        duration: Duration.zero,
        name: 'Idea',
        copies: {'folder': file.withTranscript(text)},
      ))!;
      await repository.setTranscript(
        added,
        Transcript(text: 'Hola', revision: 0, createdAt: DateTime(2026, 10, 5)),
      );

      final loaded = (await repository.loadAll()).single;

      expect(loaded.copies['folder']!.transcript, text);
      expect(loaded.transcript!.text, 'Hola');
      expect(loaded.transcript!.engine, isNull);
    });

    test('guarda la suma MD5 y la fecha de cada archivo', () async {
      final modified = DateTime(2026, 10, 5, 12, 30);
      final added = (await repository.add(
        path: await repository.createRecordingPath(),
        duration: Duration.zero,
        name: 'Idea',
        copies: {
          'folder': file.copyWith(checksum: 'abc123', modified: modified),
        },
      ))!;

      final loaded = (await repository.loadAll()).single;

      expect(loaded.copies['folder'], added.copies['folder']);
      expect(loaded.copies['folder']!.checksum, 'abc123');
      expect(loaded.copies['folder']!.modified, modified);
    });

    test(
      'al renombrarse fuera de la app, cambia el nombre y el archivo',
      () async {
        var recording = (await repository.add(
          path: await repository.createRecordingPath(),
          duration: Duration.zero,
          waveform: const [0.5],
          name: 'Idea',
          copies: {'folder': file},
        ))!;

        recording = await repository.updateStoredFile(
          recording,
          'folder',
          const CopyState(
            destination: 'tree://music',
            ref: 'doc2',
            revision: 0,
            name: '',
          ),
          name: 'Idea buena',
        );

        expect(recording.name, 'Idea buena');
        expect(recording.waveform, [0.5]);
        expect(recording.copies['folder']!.ref, 'doc2');
        expect(recording.isSavedIn('folder'), isTrue);
      },
    );

    test('eliminarla quita sus metadatos', () async {
      final recording = (await repository.add(
        path: await repository.createRecordingPath(),
        duration: Duration.zero,
        copies: {'folder': file},
      ))!;

      await repository.delete(recording);

      expect(await newRepository().loadAll(), isEmpty);
    });
  });
}
