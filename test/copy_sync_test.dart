import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/copy_sync.dart';
import 'package:voicerecorder/services/google_drive.dart';
import 'package:voicerecorder/services/recordings_repository.dart';
import 'package:voicerecorder/services/settings_store.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FileRecordingsRepository repository;
  late InMemorySettingsStore store;
  late FakeFolderAccess folders;
  late FakeDriveService drive;
  late CopySync sync;

  const folder = FolderSettings(id: 'tree://music', name: 'Music');
  const driveSettings = DriveSettings(
    email: 'ana@example.com',
    folderId: 'folder1',
  );

  Future<Recording> addRecording({String folder = ''}) async {
    final path = await repository.createRecordingPath();
    await File(path).writeAsBytes([1, 2, 3]);
    // Nombres de archivo distintos aunque se creen en el mismo segundo.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return (await repository.add(
      path: path,
      duration: Duration.zero,
      folder: folder,
    ))!;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_test');
    repository = FileRecordingsRepository(
      directory: () async => Directory(p.join(directory.path, 'recordings')),
    );
    store = InMemorySettingsStore();
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    sync = CopySync(
      repository: repository,
      store: store,
      folders: folders,
      drive: drive,
    );
  });

  tearDown(() async {
    sync.dispose();
    await directory.delete(recursive: true);
  });

  test('no copia nada si no hay destinos', () async {
    await addRecording();
    await sync.sync();

    expect(folders.calls, isEmpty);
    expect(drive.calls, isEmpty);
    expect(sync.errors, isEmpty);
  });

  test('copia las grabaciones a la carpeta y a Drive una sola vez', () async {
    await addRecording();
    await addRecording();
    store.settings = const AppSettings(folder: folder, drive: driveSettings);

    await sync.sync();

    expect(folders.calls, ['write Grabación 1.m4a', 'write Grabación 2.m4a']);
    expect(drive.calls, ['upload Grabación 1.m4a', 'upload Grabación 2.m4a']);
    final saved = await repository.loadAll();
    expect(saved.map((r) => r.copies.keys.toSet()), [
      {'folder', 'drive'},
      {'folder', 'drive'},
    ]);

    await sync.sync();
    expect(folders.calls, hasLength(2));
    expect(drive.calls, hasLength(2));
  });

  test('renombra las copias al renombrar la grabación', () async {
    final recording = await addRecording();
    store.settings = const AppSettings(folder: folder, drive: driveSettings);
    await sync.sync();

    await repository.rename(recording, 'Clase: tema 3');
    await sync.sync();

    expect(folders.calls.last, 'rename doc0 → Clase_ tema 3.m4a');
    expect(drive.calls.last, 'rename file0 → Clase_ tema 3.m4a');
    expect(folders.files, {'doc0': 'Clase_ tema 3.m4a'});
    final copies = (await repository.loadAll()).single.copies;
    expect(copies['drive']!.name, 'Clase: tema 3');
  });

  test('vuelve a subir el audio editado sobre la copia anterior', () async {
    final recording = await addRecording();
    store.settings = const AppSettings(folder: folder, drive: driveSettings);
    await sync.sync();

    final edited = p.join(directory.path, 'edited.m4a');
    await File(edited).writeAsBytes([4, 5]);
    await repository.replaceAudio(
      recording,
      sourcePath: edited,
      duration: Duration.zero,
    );
    await sync.sync();

    expect(folders.calls.last, 'write Grabación 1.m4a (doc0)');
    expect(drive.calls.last, 'upload Grabación 1.m4a (file0)');
    final copies = (await repository.loadAll()).single.copies;
    expect(copies['folder']!.revision, 1);
    expect(copies['drive']!.revision, 1);
  });

  test('vuelve a copiar todo al elegir otra carpeta', () async {
    await addRecording();
    await sync.setFolder(folder);
    await sync.sync();

    await sync.setFolder(const FolderSettings(id: 'tree://sd', name: 'SD'));
    await sync.sync();

    expect(folders.calls, ['write Grabación 1.m4a', 'write Grabación 1.m4a']);
    expect(
      (await repository.loadAll()).single.copies['folder']!.destination,
      'tree://sd',
    );
    expect(store.settings.folder!.name, 'SD');
  });

  test('si la copia se borró, la vuelve a crear al renombrar', () async {
    final recording = await addRecording();
    store.settings = const AppSettings(folder: folder, drive: driveSettings);
    await sync.sync();
    drive.files.clear();
    folders.files.clear();

    await repository.rename(recording, 'Notas');
    await sync.sync();

    expect(drive.calls.sublist(1), [
      'rename file0 → Notas.m4a',
      'upload Notas.m4a',
    ]);
    expect(folders.calls.sublist(1), [
      'rename doc0 → Notas.m4a',
      'write Notas.m4a',
    ]);
  });

  test('informa de los errores y reintenta en la siguiente pasada', () async {
    await addRecording();
    store.settings = const AppSettings(folder: folder);
    folders.writeError = PlatformException(
      code: 'no_permission',
      message: 'Sin permiso',
    );

    await sync.sync();
    expect(sync.errors, {
      'folder': const CopyError(
        CopyErrorKind.copy,
        count: 1,
        noPermission: true,
      ),
    });
    expect((await repository.loadAll()).single.copies, isEmpty);

    folders.writeError = null;
    await sync.sync();
    expect(sync.errors, isEmpty);
    expect((await repository.loadAll()).single.copies.keys, ['folder']);
  });

  test('pide volver a conectar Drive si la sesión caducó', () async {
    await addRecording();
    await addRecording();
    store.settings = const AppSettings(drive: driveSettings);
    drive.uploadError = const DriveAuthException();

    await sync.sync();

    expect(sync.errors, {'drive': const CopyError(CopyErrorKind.driveAuth)});
    // Se deja de intentar con el resto.
    expect(drive.calls, hasLength(1));
  });

  test('las copias de un WAV llevan la extensión .wav', () async {
    final path = await repository.createRecordingPath(
      format: RecordingFormat.wav,
    );
    await File(path).writeAsBytes([1, 2, 3]);
    await repository.add(path: path, duration: Duration.zero);
    store.settings = const AppSettings(folder: folder, drive: driveSettings);

    await sync.sync();

    expect(folders.calls, ['write Grabación 1.wav']);
    expect(drive.calls, ['upload Grabación 1.wav']);
  });

  test('cambiar la calidad la guarda sin copiar nada', () async {
    await addRecording();
    store.settings = const AppSettings(folder: folder);
    const options = RecordingOptions(quality: RecordingQuality.low);

    await sync.setRecordingOptions(options);

    expect(store.settings.recording, options);
    expect(store.settings.folder, folder);
    expect(sync.settings.recording, options);
    expect(folders.calls, isEmpty);
  });

  group('grabaciones de la carpeta', () {
    test('añade los audios de la carpeta y de sus subcarpetas', () async {
      final imported = <List<Recording>>[];
      sync.imports.listen(imported.add);
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
      store.settings = const AppSettings(folder: folder);

      await sync.sync();

      final all = await repository.loadAll();
      expect(all.map((r) => (r.name, r.folder)).toSet(), {
        ('Idea', ''),
        ('Tema 1', 'Clases'),
      });
      final idea = all.firstWhere((r) => r.name == 'Idea');
      expect(idea.createdAt, date);
      expect(idea.copies['folder']!.ref, root);
      final tema = all.firstWhere((r) => r.name == 'Tema 1');
      expect(tema.format, RecordingFormat.wav);
      expect(File(tema.path).readAsBytesSync(), [4, 5, 6, 7]);
      expect(tema.copies['folder']!.ref, lesson);
      expect(sync.deviceFolders, ['Clases']);
      expect(imported.single, hasLength(2));
      // Ya están enlazadas a sus archivos: no se vuelven a subir.
      expect(folders.calls.where((c) => c.startsWith('write')), isEmpty);

      await sync.sync();
      expect(await repository.loadAll(), hasLength(2));
      expect(imported, hasLength(1));
    });

    test('no vuelve a añadir una grabación eliminada en la app', () async {
      folders.addFile(folder.id, 'Idea.m4a');
      store.settings = const AppSettings(folder: folder);
      await sync.sync();
      final idea = (await repository.loadAll()).single;

      await sync.delete(idea);
      await sync.sync();

      expect(await repository.loadAll(), isEmpty);
      // El archivo de la carpeta se conserva.
      expect(folders.files.values, ['Idea.m4a']);
      expect(store.settings.folder!.ignored, {idea.copies['folder']!.ref});
    });

    test('reconoce sus copias al volver a elegir la carpeta', () async {
      await addRecording();
      await sync.setFolder(folder);
      await sync.sync();
      await sync.setFolder(const FolderSettings(id: 'tree://sd', name: 'SD'));
      await sync.sync();
      folders.calls.clear();

      await sync.setFolder(folder);
      await sync.sync();

      // Mismo nombre y tamaño: es su copia, no hay que subirla ni añadirla.
      expect(folders.calls, isEmpty);
      final recording = (await repository.loadAll()).single;
      expect(recording.copies['folder']!.destination, folder.id);
    });

    test('si se desactiva, solo copia', () async {
      folders.addFile(folder.id, 'Idea.m4a', subfolder: 'Clases');
      store.settings = AppSettings(folder: folder.withImportFiles(false));

      await sync.sync();

      expect(await repository.loadAll(), isEmpty);
      expect(sync.deviceFolders, ['Clases']);

      await sync.setImportFiles(true);
      await sync.sync();
      expect(await repository.loadAll(), hasLength(1));
    });

    test('cuenta lo que añadiría una carpeta antes de elegirla', () async {
      folders.addFile(folder.id, 'Idea.m4a', bytes: List.filled(1000, 0));
      folders.addFile(folder.id, 'Tema.wav', subfolder: 'Clases');
      folders.addFile(folder.id, 'portada.jpg');

      final scan = await sync.scanFolder(folder);

      expect(scan.count, 2);
      expect(scan.bytes, 1003);
      expect(await repository.loadAll(), isEmpty);
    });

    test('informa si no puede leer la carpeta', () async {
      await addRecording();
      store.settings = const AppSettings(folder: folder);
      folders.listError = PlatformException(
        code: 'failed',
        message: 'Sin permiso',
      );

      await sync.sync();

      expect(sync.errors['folder'], const CopyError(CopyErrorKind.readFolder));
      // Las copias se intentan igualmente.
      expect(folders.calls, ['write Grabación 1.m4a']);
    });
  });

  group('subcarpetas', () {
    test('copia cada grabación en su subcarpeta', () async {
      await addRecording(folder: 'Clases');
      store.settings = const AppSettings(folder: folder, drive: driveSettings);

      await sync.sync();

      expect(folders.calls, ['write Clases/Grabación 1.m4a']);
      expect(drive.calls, ['upload Clases/Grabación 1.m4a']);
    });

    test('crea subcarpetas y recuerda la abierta', () async {
      store.settings = const AppSettings(folder: folder);

      await sync.createFolder('Reuniones');
      await sync.openFolder('Reuniones');

      expect(folders.calls, ['mkdir Reuniones']);
      expect(store.settings.folders, ['Reuniones']);
      expect(store.settings.openFolder, 'Reuniones');
      expect(sync.deviceFolders, ['Reuniones']);
    });

    test('sin carpeta del dispositivo, las crea solo en la app', () async {
      await sync.createFolder('Ideas');

      expect(folders.calls, isEmpty);
      expect(store.settings.folders, ['Ideas']);
    });
  });

  test('agrupa las peticiones que llegan durante una pasada', () async {
    await addRecording();
    store.settings = const AppSettings(drive: driveSettings);

    await Future.wait([sync.sync(), sync.sync(), sync.sync()]);

    expect(drive.calls, ['upload Grabación 1.m4a']);
    expect(sync.syncing, isFalse);
  });
}
