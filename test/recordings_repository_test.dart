import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
}
