import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/audio_cache.dart';
import 'package:voicerecorder/services/google_drive.dart';
import 'package:voicerecorder/services/recordings_repository.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/services/storage_sync.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FileRecordingsRepository repository;
  late InMemorySettingsStore store;
  late FakeFolderAccess folders;
  late FakeDriveService drive;
  late AudioCache cache;
  late StorageSync sync;
  late List<int> changes;

  const folder = FolderSettings(id: 'tree://music', name: 'Music');
  const driveSettings = DriveSettings(
    email: 'ana@example.com',
    folderId: 'folder1',
  );

  Future<Recording> addRecording({
    String folder = '',
    List<int> bytes = const [1, 2, 3],
  }) async {
    final path = await repository.createRecordingPath();
    await File(path).writeAsBytes(bytes);
    // Nombres de archivo distintos aunque se creen en el mismo segundo.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return (await repository.add(
      path: path,
      duration: Duration.zero,
      folder: folder,
    ))!;
  }

  Future<List<Recording>> all() => repository.loadAll();

  Future<Recording> single() async => (await all()).single;

  List<String> writes() =>
      folders.calls.where((c) => c.startsWith('write')).toList();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_test');
    repository = FileRecordingsRepository(
      directory: () async => Directory(p.join(directory.path, 'recordings')),
    );
    store = InMemorySettingsStore();
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    cache = AudioCache(
      directory: () async => Directory(p.join(directory.path, 'cache')),
    );
    sync = StorageSync(
      repository: repository,
      store: store,
      folders: folders,
      drive: drive,
      cache: cache,
    );
    changes = [];
    sync.changes.listen(changes.add);
  });

  tearDown(() async {
    sync.dispose();
    await directory.delete(recursive: true);
  });

  test('sin destino no hace nada', () async {
    final recording = await addRecording();
    await sync.sync();

    expect(folders.calls, isEmpty);
    expect(drive.calls, isEmpty);
    expect(sync.errors, isEmpty);
    expect(File(recording.path).existsSync(), isTrue);
  });

  group('carpeta del dispositivo', () {
    setUp(() => store.settings = const AppSettings(folder: folder));

    test('guarda las grabaciones en ella y saca su audio de la app', () async {
      final first = await addRecording();
      await addRecording();

      await sync.sync();

      expect(writes(), ['write Grabación 1.m4a', 'write Grabación 2.m4a']);
      final saved = await all();
      expect(saved, hasLength(2));
      expect(saved.map((r) => r.copies['folder']!.size), [3, 3]);
      // Ya no está dentro de la app: queda en la caché.
      expect(File(first.path).existsSync(), isFalse);
      expect(File(await cache.pathFor(first)).readAsBytesSync(), [1, 2, 3]);

      await sync.sync();
      expect(writes(), hasLength(2));
    });

    test('lee el audio de la carpeta cuando no está en la caché', () async {
      final recording = await addRecording(bytes: [7, 8, 9]);
      await sync.sync();
      await cache.forget(recording);

      final path = await sync.audioPath(await single());

      expect(folders.calls.last, 'read doc0');
      expect(File(path).readAsBytesSync(), [7, 8, 9]);
      await sync.audioPath(await single());
      expect(folders.calls.where((c) => c.startsWith('read')), hasLength(1));
    });

    test('muestra sus audios y los de sus subcarpetas sin copiarlos', () async {
      final date = DateTime(2026, 3, 2, 9, 15);
      final root = folders.addFile(folder.id, 'Idea.m4a', modified: date);
      final lesson = folders.addFile(
        folder.id,
        'Tema 1.wav',
        subfolder: 'Clases',
        bytes: [4, 5, 6, 7],
      );
      folders.addFile(folder.id, 'notas.txt');
      folders.addFile('tree://otra', 'Ajena.m4a');

      await sync.sync();

      final recordings = await all();
      expect(recordings.map((r) => (r.name, r.folder)).toSet(), {
        ('Idea', ''),
        ('Tema 1', 'Clases'),
      });
      final idea = recordings.firstWhere((r) => r.name == 'Idea');
      expect(idea.createdAt, date);
      expect(idea.copies['folder']!.ref, root);
      final tema = recordings.firstWhere((r) => r.name == 'Tema 1');
      expect(tema.format, RecordingFormat.wav);
      expect(tema.copies['folder']!.ref, lesson);
      expect(tema.copies['folder']!.size, 4);
      // No se ha copiado nada a la app.
      expect(File(tema.path).existsSync(), isFalse);
      expect(folders.calls, isEmpty);
      expect(sync.storageFolders, ['Clases']);
      expect(changes, [2]);

      await sync.sync();
      expect(await all(), hasLength(2));
      expect(changes, [2]);
    });

    test('si se borra en la carpeta, desaparece de la app', () async {
      final ref = folders.addFile(folder.id, 'Idea.m4a');
      await sync.sync();
      final idea = await single();
      await sync.audioPath(idea);

      folders.files.remove(ref);
      await sync.sync();

      expect(await all(), isEmpty);
      expect(File(await cache.pathFor(idea)).existsSync(), isFalse);
      expect(changes, [1, 0]);
    });

    test('si falta en la carpeta pero la app tiene el audio, la vuelve a '
        'guardar', () async {
      // Como las copias de versiones anteriores: el audio sigue en la app.
      final recording = await addRecording();
      await repository.setCopy(
        recording,
        'folder',
        CopyState(
          destination: folder.id,
          ref: 'borrado',
          revision: 0,
          name: recording.name,
        ),
      );

      await sync.sync();

      expect(writes(), ['write Grabación 1.m4a']);
      expect((await single()).copies['folder']!.ref, 'doc0');
      expect(File(await cache.pathFor(recording)).existsSync(), isTrue);
    });

    test('la grabación de la lista puede ser de antes de guardarla', () async {
      final stale = await addRecording(bytes: [7]);
      await sync.sync();
      await cache.forget(stale);

      // Sin el archivo de la carpeta, pero se busca el estado actual.
      expect(stale.copies, isEmpty);
      final path = await sync.audioPath(stale);

      expect(File(path).readAsBytesSync(), [7]);
    });

    test('si se cambia en la carpeta, vuelve a leer sus datos', () async {
      final ref = folders.addFile(folder.id, 'Idea.m4a');
      await sync.sync();
      await repository.setDetails(
        await single(),
        waveform: const [0.5],
        duration: const Duration(seconds: 3),
      );

      folders.sizes[ref] = 10;
      await sync.sync();

      final idea = await single();
      expect(idea.revision, 1);
      expect(idea.waveform, isNull);
      expect(idea.duration, Duration.zero);
      expect(idea.copies['folder']!.size, 10);
      expect(idea.isSavedIn('folder'), isTrue);
      expect(writes(), isEmpty);
    });

    test('si se renombra en la carpeta, conserva sus datos', () async {
      final ref = folders.addFile(folder.id, 'Idea.m4a');
      await sync.sync();
      await repository.setDetails(await single(), waveform: const [0.5]);

      folders.files.remove(ref);
      final renamed = folders.addFile(folder.id, 'Idea buena.m4a');
      await sync.sync();

      final idea = await single();
      expect(idea.name, 'Idea buena');
      expect(idea.waveform, [0.5]);
      expect(idea.copies['folder']!.ref, renamed);
      expect(folders.calls, isEmpty);
    });

    test('eliminarla la borra de la carpeta', () async {
      folders.addFile(folder.id, 'Idea.m4a');
      await sync.sync();

      await sync.delete(await single());

      expect(folders.calls, ['delete doc0']);
      expect(folders.files, isEmpty);
      expect(await all(), isEmpty);
    });

    test('si no se puede borrar de la carpeta, no la elimina', () async {
      folders.addFile(folder.id, 'Idea.m4a');
      await sync.sync();
      folders.deleteError = PlatformException(code: 'no_permission');

      await expectLater(sync.delete(await single()), throwsA(anything));

      expect(await all(), hasLength(1));
    });

    test('renombrarla en la app renombra su archivo', () async {
      final recording = await addRecording();
      await sync.sync();

      await repository.rename(recording, 'Clase: tema 3');
      await sync.sync();

      expect(folders.calls.last, 'rename doc0 → Clase_ tema 3.m4a');
      expect(folders.files, {'doc0': 'Clase_ tema 3.m4a'});
      expect((await single()).isSavedIn('folder'), isTrue);
    });

    test('al editarla, guarda el audio nuevo sobre su archivo', () async {
      final recording = await addRecording();
      await sync.sync();

      final edited = p.join(directory.path, 'edited.m4a');
      await File(edited).writeAsBytes([4, 5]);
      await repository.replaceAudio(
        recording,
        sourcePath: edited,
        duration: Duration.zero,
      );
      // Hasta guardarla en la carpeta, el audio nuevo está en la app.
      expect(File(recording.path).existsSync(), isTrue);
      await sync.sync();

      expect(writes().last, 'write Grabación 1.m4a (doc0)');
      expect(folders.contents['doc0'], [4, 5]);
      final saved = await single();
      expect(saved.copies['folder']!.revision, 1);
      expect(saved.copies['folder']!.size, 2);
      expect(File(recording.path).existsSync(), isFalse);
    });

    test(
      'si se borró en la carpeta con cambios sin guardar, la recrea',
      () async {
        final recording = await addRecording();
        await sync.sync();
        await repository.rename(recording, 'Notas');
        final edited = p.join(directory.path, 'edited.m4a');
        await File(edited).writeAsBytes([4, 5]);
        await repository.replaceAudio(
          await single(),
          sourcePath: edited,
          duration: Duration.zero,
        );
        folders.files.clear();

        await sync.sync();

        expect(writes().last, 'write Notas.m4a (doc0)');
        expect(folders.files.values, ['Notas.m4a']);
        expect(await all(), hasLength(1));
      },
    );

    test('al elegir otra, las de la anterior se quedan en ella', () async {
      await addRecording();
      await sync.sync();

      await sync.setFolder(const FolderSettings(id: 'tree://sd', name: 'SD'));
      // Hecha antes de que se haya guardado en la nueva.
      final pending = await addRecording();
      await sync.sync();

      final recording = await single();
      expect(recording.id, pending.id);
      expect(recording.copies['folder']!.destination, 'tree://sd');
      // La de la carpeta anterior sigue allí.
      expect(folders.owners.values, ['tree://music', 'tree://sd']);
      expect(changes, contains(0));
    });

    test('reconoce sus archivos al volver a elegir la carpeta', () async {
      await addRecording();
      await sync.sync();
      await repository.setDetails(await single(), waveform: const [0.5]);
      folders.calls.clear();

      // En iOS, la misma carpeta tiene otro identificador cada vez.
      folders.owners['doc0'] = 'tree://music2';
      await sync.setFolder(
        const FolderSettings(id: 'tree://music2', name: 'Music'),
      );
      await sync.sync();

      expect(folders.calls, isEmpty);
      final recording = await single();
      expect(recording.copies['folder']!.destination, 'tree://music2');
      expect(recording.waveform, [0.5]);
    });

    test('informa de los errores y reintenta en la siguiente pasada', () async {
      final recording = await addRecording();
      folders.writeError = PlatformException(
        code: 'no_permission',
        message: 'Sin permiso',
      );

      await sync.sync();
      expect(sync.errors, {
        'folder': const SyncError(
          SyncErrorKind.upload,
          count: 1,
          noPermission: true,
        ),
      });
      expect((await single()).copies, isEmpty);
      expect(File(recording.path).existsSync(), isTrue);

      folders.writeError = null;
      await sync.sync();
      expect(sync.errors, isEmpty);
      expect((await single()).copies.keys, ['folder']);
    });

    test(
      'si no puede leer la carpeta, guarda igualmente y no quita nada',
      () async {
        folders.addFile(folder.id, 'Idea.m4a');
        await sync.sync();
        await addRecording();
        folders.listError = PlatformException(code: 'failed');

        await sync.sync();

        expect(sync.errors['folder'], const SyncError(SyncErrorKind.read));
        expect(writes(), ['write Grabación 1.m4a']);
        expect(await all(), hasLength(2));
      },
    );

    test('un WAV se guarda con la extensión .wav', () async {
      final path = await repository.createRecordingPath(
        format: RecordingFormat.wav,
      );
      await File(path).writeAsBytes([1, 2, 3]);
      await repository.add(path: path, duration: Duration.zero);

      await sync.sync();

      expect(writes(), ['write Grabación 1.wav']);
      expect((await single()).format, RecordingFormat.wav);
    });

    test('cada grabación va a su subcarpeta', () async {
      await addRecording(folder: 'Clases');

      await sync.sync();

      expect(writes(), ['write Clases/Grabación 1.m4a']);
      expect(sync.storageFolders, isEmpty);
      await sync.sync();
      expect(sync.storageFolders, ['Clases']);
    });

    test('crea subcarpetas y recuerda la abierta', () async {
      await sync.createFolder('Reuniones');
      await sync.openFolder('Reuniones');

      expect(folders.calls, ['mkdir Reuniones']);
      expect(store.settings.folders, ['Reuniones']);
      expect(store.settings.openFolder, 'Reuniones');
      expect(sync.storageFolders, ['Reuniones']);
    });
  });

  group('Google Drive como destino', () {
    setUp(() => store.settings = const AppSettings(drive: driveSettings));

    test(
      'sube las grabaciones, saca su audio y lo descarga para oírlas',
      () async {
        final recording = await addRecording(bytes: [5, 6]);

        await sync.sync();

        expect(drive.calls, ['upload Grabación 1.m4a']);
        expect(File(recording.path).existsSync(), isFalse);
        await cache.forget(recording);

        final path = await sync.audioPath(await single());
        expect(drive.calls.last, 'download file0');
        expect(File(path).readAsBytesSync(), [5, 6]);
      },
    );

    test('muestra lo que hay en Drive', () async {
      drive.addFile('Idea.m4a', subfolder: 'Clases');

      await sync.sync();

      final idea = await single();
      expect((idea.name, idea.folder), ('Idea', 'Clases'));
      expect(idea.copies['drive']!.ref, 'file0');
      expect(drive.calls, isEmpty);
      expect(sync.storageFolders, ['Clases']);
    });

    test('eliminarla la manda a la papelera de Drive', () async {
      drive.addFile('Idea.m4a');
      await sync.sync();

      await sync.delete(await single());

      expect(drive.calls, ['delete file0']);
      expect(await all(), isEmpty);
    });

    test('sin conexión, la deja en la app hasta poder subirla', () async {
      final recording = await addRecording();
      drive.uploadError = const SocketException('Sin conexión');

      await sync.sync();

      expect(sync.errors['drive']!.offline, isTrue);
      expect(sync.errors['drive']!.kind, SyncErrorKind.upload);
      expect(File(recording.path).existsSync(), isTrue);

      drive.uploadError = null;
      await sync.sync();
      expect(sync.errors, isEmpty);
      expect(File(recording.path).existsSync(), isFalse);
    });

    test('pide volver a conectar Drive si la sesión caducó', () async {
      await addRecording();
      await addRecording();
      drive.uploadError = const DriveAuthException();

      await sync.sync();

      expect(sync.errors, {'drive': const SyncError(SyncErrorKind.driveAuth)});
      // Se deja de intentar con el resto.
      expect(drive.calls, hasLength(1));
    });

    test('agrupa las peticiones que llegan durante una pasada', () async {
      await addRecording();

      await Future.wait([sync.sync(), sync.sync(), sync.sync()]);

      expect(drive.calls, ['upload Grabación 1.m4a']);
      expect(sync.syncing, isFalse);
    });
  });

  group('carpeta con copia en Drive', () {
    setUp(
      () => store.settings = const AppSettings(
        folder: folder,
        drive: driveSettings,
      ),
    );

    test('guarda en la carpeta y una copia en Drive', () async {
      await addRecording(folder: 'Clases');

      await sync.sync();

      expect(writes(), ['write Clases/Grabación 1.m4a']);
      expect(drive.calls, ['upload Clases/Grabación 1.m4a']);
      expect((await single()).copies.keys.toSet(), {'folder', 'drive'});
    });

    test('al eliminarla, la copia de Drive se conserva', () async {
      await addRecording();
      await sync.sync();

      await sync.delete(await single());

      expect(folders.files, isEmpty);
      expect(drive.files.values, ['Grabación 1.m4a']);
    });

    test('renombra también la copia', () async {
      final recording = await addRecording();
      await sync.sync();

      await repository.rename(recording, 'Notas');
      await sync.sync();

      expect(folders.calls.last, 'rename doc0 → Notas.m4a');
      expect(drive.calls.last, 'rename file0 → Notas.m4a');
    });

    test('al dejar la carpeta, pasa a usar las de Drive', () async {
      await addRecording();
      await sync.sync();

      await sync.setFolder(null);
      await sync.sync();

      final recording = await single();
      expect(store.settings.storage, StorageKind.drive);
      expect(drive.calls, ['upload Grabación 1.m4a']);
      await cache.forget(recording);
      await sync.audioPath(recording);
      expect(drive.calls.last, 'download file0');
    });
  });

  test(
    'al pasar de Drive a una carpeta, lleva a ella las grabaciones',
    () async {
      store.settings = const AppSettings(drive: driveSettings);
      final recording = await addRecording(bytes: [3, 4]);
      await sync.sync();
      await cache.forget(recording);

      await sync.setFolder(folder);
      await sync.sync();

      expect(drive.calls, ['upload Grabación 1.m4a', 'download file0']);
      expect(writes(), ['write Grabación 1.m4a']);
      expect(folders.contents['doc0'], [3, 4]);
      expect((await single()).copies.keys.toSet(), {'folder', 'drive'});
    },
  );

  test('cambiar la calidad la guarda sin tocar el destino', () async {
    store.settings = const AppSettings(folder: folder);
    const options = RecordingOptions(quality: RecordingQuality.low);

    await sync.setRecordingOptions(options);

    expect(store.settings.recording, options);
    expect(store.settings.folder, folder);
    expect(sync.settings.recording, options);
    expect(folders.calls, isEmpty);
  });

  test('sin destino, las subcarpetas se crean solo en la app', () async {
    await sync.createFolder('Ideas');

    expect(folders.calls, isEmpty);
    expect(store.settings.folders, ['Ideas']);
  });
}
