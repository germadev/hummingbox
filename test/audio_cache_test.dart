import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/services/audio_cache.dart';

void main() {
  late Directory directory;
  late AudioCache cache;

  Recording recording(String id, {int revision = 0}) => Recording(
    id: id,
    path: '/app/$id.m4a',
    name: id,
    createdAt: DateTime(2026),
    duration: Duration.zero,
    revision: revision,
  );

  Future<void> Function(String) writes(List<int> bytes) =>
      (destination) => File(destination).writeAsBytes(bytes);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cache_test');
    cache = AudioCache(
      directory: () async => Directory(p.join(directory.path, 'audio')),
      maxBytes: 10,
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('lee el audio una sola vez', () async {
    var reads = 0;
    Future<void> read(String destination) async {
      reads++;
      await File(destination).writeAsBytes([1, 2, 3]);
    }

    final path = await cache.fetch(recording('a'), read);
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
    expect(await cache.fetch(recording('a'), read), path);
    expect(reads, 1);
  });

  test('dos peticiones a la vez comparten la lectura', () async {
    final gate = Completer<void>();
    var reads = 0;
    Future<void> read(String destination) async {
      reads++;
      await gate.future;
      await File(destination).writeAsBytes([1]);
    }

    final first = cache.fetch(recording('a'), read);
    final second = cache.fetch(recording('a'), read);
    gate.complete();

    expect(await first, await second);
    expect(reads, 1);
  });

  test('si la lectura falla, no deja nada a medias', () async {
    await expectLater(
      cache.fetch(recording('a'), (destination) async {
        await File(destination).writeAsBytes([1]);
        throw const FileSystemException('sin conexión');
      }),
      throwsA(isA<FileSystemException>()),
    );

    expect(Directory(p.join(directory.path, 'audio')).listSync(), isEmpty);
  });

  test('una revisión nueva sustituye a la anterior', () async {
    final old = await cache.fetch(recording('a'), writes([1]));
    final current = await cache.fetch(recording('a', revision: 1), writes([2]));

    expect(current, isNot(old));
    expect(File(old).existsSync(), isFalse);
    expect(File(current).readAsBytesSync(), [2]);
  });

  test(
    'no pasa del tamaño máximo: borra lo que hace más tiempo que no se usa',
    () async {
      final a = await cache.fetch(recording('a'), writes(List.filled(4, 0)));
      File(a).setLastModifiedSync(DateTime(2020));
      final b = await cache.fetch(recording('b'), writes(List.filled(4, 0)));
      File(b).setLastModifiedSync(DateTime(2021));
      final c = await cache.fetch(recording('c'), writes(List.filled(4, 0)));

      expect(File(a).existsSync(), isFalse);
      expect(File(b).existsSync(), isTrue);
      expect(File(c).existsSync(), isTrue);
    },
  );

  test('olvida el audio de una grabación', () async {
    final path = await cache.fetch(recording('a'), writes([1]));
    final other = await cache.fetch(recording('a_1'), writes([1]));

    await cache.forget(recording('a'));

    expect(File(path).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue);
  });
}
