import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/instrument.dart';
import 'package:voicerecorder/models/synth_patch.dart';
import 'package:voicerecorder/services/piano_sound.dart';
import 'package:voicerecorder_native/voicerecorder_native.dart';

/// El mezclador nativo, de mentira: apunta lo que se le pide.
class FakeNativePiano implements NativePiano {
  FakeNativePiano({this.sampleRate = 48000});

  final int sampleRate;

  /// Lo que se le ha pedido, en orden (con el nombre de los archivos).
  final calls = <String>[];

  /// Los sonidos cargados, por su ruta.
  final loaded = <String>{};

  /// Si se pone, `open` falla con él.
  Object? openError;

  /// Si se pone, las cargas esperan a que se complete.
  Completer<void>? loadGate;

  @override
  Future<int> open() async {
    calls.add('open');
    if (openError case final error?) throw error;
    return sampleRate;
  }

  @override
  Future<void> load(String path) async {
    await loadGate?.future;
    calls.add('load ${p.basename(path)}');
    loaded.add(path);
  }

  @override
  Future<void> unload(Iterable<String> paths) async {
    for (final path in paths) {
      calls.add('unload ${p.basename(path)}');
      loaded.remove(path);
    }
  }

  @override
  Future<void> play(int key, String path) async {
    if (!loaded.contains(path)) {
      throw PlatformException(code: 'not_loaded');
    }
    calls.add('play $key ${p.basename(path)}');
  }

  @override
  Future<void> release(int key, Duration fade) async =>
      calls.add('release $key ${fade.inMilliseconds}ms');

  @override
  Future<void> stop(int key) async => calls.add('stop $key');

  @override
  Future<void> close() async => calls.add('close');
}

void main() {
  late Directory directory;
  late FakeNativePiano engine;
  late NativePianoSound sound;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('piano_sound_test');
    engine = FakeNativePiano();
    sound = NativePianoSound(engine: engine, directory: () async => directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  /// Las llamadas de un tipo (`play`, `release`…).
  List<String> callsOf(String kind) => [
    for (final call in engine.calls)
      if (call.startsWith('$kind ')) call,
  ];

  test(
    'prepara cada tecla con su sonido a la frecuencia de la salida',
    () async {
      await sound.prepare([60, 61], Instrument.piano);

      expect(engine.calls, [
        'open',
        'load v3_48000_piano_60.wav',
        'load v3_48000_piano_61.wav',
      ]);
      final wav = File(
        p.join(directory.path, 'piano', 'v3_48000_piano_60.wav'),
      );
      final header = ByteData.sublistView(wav.readAsBytesSync());
      expect(header.getUint32(24, Endian.little), 48000);
      expect(header.getUint16(22, Endian.little), 1);
    },
  );

  test('cada frecuencia y cada instrumento tienen su sonido', () async {
    final other = FakeNativePiano(sampleRate: 44100);
    await NativePianoSound(
      engine: other,
      directory: () async => directory,
    ).prepare([60], Instrument.organ);

    expect(other.calls, ['open', 'load v3_44100_organ_60.wav']);
  });

  test('toca la tecla; el piano sigue sonando al soltarla', () async {
    await sound.play(60, Instrument.piano);
    await sound.release(60);

    expect(callsOf('play'), ['play 60 v3_48000_piano_60.wav']);
    expect(callsOf('release'), isEmpty);
  });

  test('el órgano y el sintetizador se apagan al soltar la tecla', () async {
    const synth = SynthPatch(release: Duration(milliseconds: 500));
    await sound.play(60, Instrument.organ);
    await sound.release(60);
    await sound.play(62, Instrument.synth, synth: synth);
    await sound.release(62);

    expect(callsOf('release'), ['release 60 60ms', 'release 62 500ms']);
    // Soltar otra vez no hace nada.
    await sound.release(62);
    expect(callsOf('release'), hasLength(2));
  });

  test('si se suelta mientras se prepara, empieza y se apaga', () async {
    engine.loadGate = Completer();
    final playing = sound.play(64, Instrument.organ);
    await sound.release(64);
    engine.loadGate!.complete();
    await playing;

    expect(engine.calls.sublist(engine.calls.length - 2), [
      'play 64 v3_48000_organ_64.wav',
      'release 64 60ms',
    ]);
  });

  test('si se para mientras se prepara, no suena', () async {
    engine.loadGate = Completer();
    final playing = sound.play(65, Instrument.piano);
    await sound.stop(65);
    engine.loadGate!.complete();
    await playing;

    expect(callsOf('play'), isEmpty);
    expect(engine.calls, contains('stop 65'));
  });

  test(
    'si se vuelve a tocar mientras se prepara, suena solo la última',
    () async {
      engine.loadGate = Completer();
      final first = sound.play(67, Instrument.piano);
      final second = sound.play(67, Instrument.piano);
      engine.loadGate!.complete();
      await Future.wait([first, second]);

      expect(callsOf('play'), ['play 67 v3_48000_piano_67.wav']);
    },
  );

  test('al cambiar el sonido del sintetizador, olvida el anterior', () async {
    const before = SynthPatch();
    const after = SynthPatch(wave: SynthWave.square);
    await sound.play(60, Instrument.synth, synth: before);
    final old = File(
      p.join(directory.path, 'piano', 'v3_48000_synth_${before.id}_60.wav'),
    );
    expect(old.existsSync(), isTrue);

    await sound.play(60, Instrument.synth, synth: after);
    await pumpEventQueue();

    expect(engine.calls, contains('unload v3_48000_synth_${before.id}_60.wav'));
    expect(old.existsSync(), isFalse);
    expect(callsOf('play').last, 'play 60 v3_48000_synth_${after.id}_60.wav');
  });

  test('sin salida no falla, y lo vuelve a intentar al tocar', () async {
    engine.openError = PlatformException(code: 'failed');
    await sound.prepare([60], Instrument.piano);
    await sound.play(60, Instrument.piano);
    expect(callsOf('load'), isEmpty);
    expect(callsOf('play'), isEmpty);

    engine.openError = null;
    await sound.play(60, Instrument.piano);

    expect(callsOf('play'), ['play 60 v3_48000_piano_60.wav']);
  });

  test('si el mezclador olvida un sonido, lo vuelve a cargar', () async {
    await sound.play(60, Instrument.piano);
    engine.loaded.clear();

    // La primera vez falla (sin ruido) y la siguiente lo carga otra vez.
    await sound.play(60, Instrument.piano);
    await sound.play(60, Instrument.piano);

    expect(callsOf('load'), hasLength(2));
    expect(callsOf('play'), hasLength(2));
  });

  test('olvida los sonidos usados hace más tiempo', () async {
    const count = NativePianoSound.maxLoaded + 2;
    await sound.prepare([
      for (var key = 0; key < count; key++) key,
    ], Instrument.piano);

    expect(callsOf('unload'), [
      'unload v3_48000_piano_0.wav',
      'unload v3_48000_piano_1.wav',
    ]);
    expect(engine.loaded, hasLength(NativePianoSound.maxLoaded));
  });

  test('borra los sonidos de versiones anteriores', () async {
    final old = File(p.join(directory.path, 'piano', 'v2_piano_60.wav'))
      ..createSync(recursive: true);
    await sound.prepare([60], Instrument.piano);
    await pumpEventQueue();

    expect(old.existsSync(), isFalse);
    expect(
      File(p.join(directory.path, 'piano', 'v3_48000_piano_60.wav'))
          .existsSync(),
      isTrue,
    );
  });

  test('al cerrarlo, cierra la salida', () async {
    await sound.play(60, Instrument.piano);
    await sound.dispose();

    expect(engine.calls.last, 'close');
  });
}
