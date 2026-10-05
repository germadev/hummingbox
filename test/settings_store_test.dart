import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/settings_store.dart';

void main() {
  late Directory directory;
  late FileSettingsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings_test');
    store = FileSettingsStore(
      file: () async => File(p.join(directory.path, 'sub', 'settings.json')),
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('sin archivo devuelve las opciones por defecto', () async {
    expect(await store.load(), const AppSettings());
  });

  test('guarda y recupera las opciones', () async {
    const settings = AppSettings(
      folder: FolderSettings(id: 'tree://music', name: 'Music'),
      drive: DriveSettings(email: 'ana@example.com', folderId: 'f1'),
    );
    await store.save(settings);

    expect(await store.load(), settings);
    await store.save(settings.withDrive(null));
    expect(await store.load(), settings.withDrive(null));
  });

  test('guarda el formato y la calidad de grabación', () async {
    const recording = RecordingOptions(
      format: RecordingFormat.wav,
      quality: RecordingQuality.medium,
    );
    await store.save(const AppSettings().withRecording(recording));

    final loaded = await store.load();
    expect(loaded.recording, recording);
    // Cambiar otra opción no la pierde.
    expect(
      loaded.withFolder(const FolderSettings(id: 'x', name: 'X')).recording,
      recording,
    );
  });

  test('guarda las carpetas, la abierta y la cuenta atrás', () async {
    const settings = AppSettings(
      folder: FolderSettings(id: 'tree://music', name: 'Music'),
      folders: ['Clases', 'Ideas'],
      openFolder: 'Clases',
      countdownSeconds: 10,
    );
    await store.save(settings);

    expect(await store.load(), settings);
  });

  test('las grabaciones van a la carpeta y, si no hay, a Drive', () {
    const folder = FolderSettings(id: 'tree://music', name: 'Music');
    const drive = DriveSettings(email: 'ana@example.com', folderId: 'f1');

    expect(const AppSettings().storage, isNull);
    expect(const AppSettings(folder: folder).storage, StorageKind.folder);
    expect(const AppSettings(drive: drive).storage, StorageKind.drive);
    const both = AppSettings(folder: folder, drive: drive);
    expect(both.storage, StorageKind.folder);
    expect(both.copiesToDrive, isTrue);
    expect(const AppSettings(drive: drive).copiesToDrive, isFalse);
  });

  test('lee las opciones de la carpeta de versiones anteriores', () async {
    final file = File(p.join(directory.path, 'sub', 'settings.json'));
    await file.create(recursive: true);
    await file.writeAsString(
      '{"folder": {"id": "tree://music", "name": "Music", "import": false, '
      '"ignored": ["doc1"]}}',
    );

    expect(
      (await store.load()).folder,
      const FolderSettings(id: 'tree://music', name: 'Music'),
    );
  });

  test('tolera un archivo corrupto', () async {
    final file = File(p.join(directory.path, 'sub', 'settings.json'));
    await file.create(recursive: true);
    await file.writeAsString('{roto');

    expect(await store.load(), const AppSettings());
  });
}
