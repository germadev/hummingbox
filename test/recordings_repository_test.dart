import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/recordings_repository.dart';

void main() {
  late Directory directory;
  late FileRecordingsRepository repository;

  FileRecordingsRepository newRepository() =>
      FileRecordingsRepository(directory: () async => directory);

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

  test('añade grabaciones numeradas y las lista de la más nueva a la más '
      'antigua', () async {
    final first = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await repository.add(
      path: await createAudioFile(),
      duration: const Duration(seconds: 12),
    );

    expect(first!.name, 'Grabación 1');
    expect(second!.name, 'Grabación 2');

    final all = await repository.loadAll();
    expect(all.map((r) => r.id), [second.id, first.id]);
    expect(all.first.duration, const Duration(seconds: 12));
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

  test('nextDefaultName continúa tras el número más alto', () {
    expect(FileRecordingsRepository.nextDefaultName([]), 'Grabación 1');
    expect(
      FileRecordingsRepository.nextDefaultName([
        'Grabación 2',
        'Entrevista',
        'Grabación 7',
        null,
        'Grabación 3 bis',
      ]),
      'Grabación 8',
    );
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
          file.withSize(10),
          audioChanged: true,
        );

        expect(recording.revision, 1);
        expect(recording.waveform, isNull);
        expect(recording.duration, Duration.zero);
        expect(recording.copies['folder']!.size, 10);
        expect(recording.isSavedIn('folder'), isTrue);
      },
    );

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
