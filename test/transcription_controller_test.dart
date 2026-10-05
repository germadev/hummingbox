import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/transcription_controller.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/services/transcriber.dart';

import 'fakes.dart';

void main() {
  late InMemoryRecordingsRepository repository;
  late FakeTranscriber transcriber;
  late TranscriptionController controller;

  Recording sample(String id, {int day = 5}) => Recording(
    id: id,
    path: '/fake/$id.m4a',
    name: 'Grabación $id',
    createdAt: DateTime(2026, 10, day),
    duration: const Duration(seconds: 5),
  );

  setUp(() {
    repository = InMemoryRecordingsRepository([
      sample('a'),
      sample('b'),
      sample('old', day: 1),
      sample('new', day: 9),
    ]);
    transcriber = FakeTranscriber();
    controller = TranscriptionController(
      transcriber: transcriber,
      repository: repository,
    );
  });

  tearDown(() => controller.dispose());

  test('guarda la transcripción con la grabación', () async {
    final result = await controller.transcribe(
      sample('a'),
      engine: TranscriptionEngine.system,
      language: 'es',
    );

    expect(result.transcript!.text, 'Hola, esto es una prueba.');
    expect(repository.byId('a').transcript, result.transcript);
    expect(transcriber.calls, [('a', TranscriptionEngine.system, 'es')]);
    expect(controller.isTranscribing(sample('a')), isFalse);
  });

  test('transcribe de una en una y muestra el progreso', () async {
    final gate = transcriber.gate = Completer<void>();

    final first = controller.transcribe(
      sample('a'),
      engine: TranscriptionEngine.whisper,
      language: 'auto',
    );
    final second = controller.transcribe(
      sample('b'),
      engine: TranscriptionEngine.whisper,
      language: 'auto',
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.isRunning(sample('a')), isTrue);
    expect(controller.progressOf(sample('a')), 0.25);
    // La segunda espera su turno.
    expect(controller.isTranscribing(sample('b')), isTrue);
    expect(controller.isRunning(sample('b')), isFalse);
    expect(controller.progressOf(sample('b')), isNull);
    expect(transcriber.calls, hasLength(1));

    // Pedir otra vez la misma no la repite.
    final again = controller.transcribe(
      sample('a'),
      engine: TranscriptionEngine.whisper,
      language: 'auto',
    );

    gate.complete();
    await first;
    await second;
    await again;
    expect(transcriber.calls.map((c) => c.$1), ['a', 'b']);
  });

  test('cancela la que espera y la que está en curso', () async {
    final gate = transcriber.gate = Completer<void>();
    final first = controller.transcribe(
      sample('a'),
      engine: TranscriptionEngine.system,
      language: 'es',
    );
    final second = controller.transcribe(
      sample('b'),
      engine: TranscriptionEngine.system,
      language: 'es',
    );
    await Future<void>.delayed(Duration.zero);

    controller.cancel(sample('b'));
    await expectLater(
      second,
      throwsA(
        isA<TranscriptionException>().having(
          (e) => e.error,
          'error',
          TranscriptionError.canceled,
        ),
      ),
    );

    controller.cancel(sample('a'));
    gate.complete();
    await expectLater(first, throwsA(isA<TranscriptionException>()));
    expect(transcriber.calls.map((c) => c.$1), ['a']);
    expect(repository.byId('a').transcript, isNull);
  });

  test('si falla, sigue con la siguiente', () async {
    transcriber.error = const TranscriptionException(
      TranscriptionError.noSpeech,
    );
    final first = controller.transcribe(
      sample('a'),
      engine: TranscriptionEngine.system,
      language: 'es',
    );
    await expectLater(first, throwsA(isA<TranscriptionException>()));

    transcriber.error = null;
    final second = await controller.transcribe(
      sample('b'),
      engine: TranscriptionEngine.system,
      language: 'es',
    );
    expect(second.transcript, isNotNull);
  });

  group('en segundo plano', () {
    Future<Recording?> inBackground(Recording recording) =>
        controller.transcribeInBackground(
          recording,
          engine: TranscriptionEngine.system,
          language: 'es',
        );

    Future<Recording> requested(Recording recording) => controller.transcribe(
      recording,
      engine: TranscriptionEngine.system,
      language: 'es',
    );

    Iterable<String> ids() => transcriber.calls.map((c) => c.$1);

    test(
      'después de las pedidas y de la más reciente a la más antigua',
      () async {
        final gate = transcriber.gate = Completer<void>();
        final first = requested(sample('a'));
        await Future<void>.delayed(Duration.zero);
        final results = [
          inBackground(sample('old', day: 1)),
          inBackground(sample('new', day: 9)),
        ];
        final second = requested(sample('b'));

        // Sin progreso a la vista: no se ha pedido.
        expect(controller.isTranscribing(sample('new', day: 9)), isTrue);
        expect(controller.isRequested(sample('new', day: 9)), isFalse);
        expect(controller.isRequested(sample('b')), isTrue);

        gate.complete();
        await first;
        await second;
        final [old, recent] = await Future.wait(results);
        expect(ids(), ['a', 'b', 'new', 'old']);
        expect(old!.transcript, isNotNull);
        expect(recent!.transcript, isNotNull);
      },
    );

    test('al pedirla se adelanta y el resultado va a quien la pidió', () async {
      final gate = transcriber.gate = Completer<void>();
      final running = inBackground(sample('new', day: 9));
      final waiting = inBackground(sample('old', day: 1));
      await Future<void>.delayed(Duration.zero);
      final other = inBackground(sample('a'));

      final asked = requested(sample('old', day: 1));
      expect(controller.isRequested(sample('old', day: 1)), isTrue);
      expect(await waiting, isNull);

      gate.complete();
      expect((await asked).transcript, isNotNull);
      expect(await running, isNotNull);
      expect(await other, isNotNull);
      // La pedida pasa delante de la otra de segundo plano.
      expect(ids(), ['new', 'old', 'a']);
    });

    test(
      'en pausa, interrumpe la que está en curso y la repite después',
      () async {
        final gate = transcriber.gate = Completer<void>();
        final result = inBackground(sample('a'));
        await Future<void>.delayed(Duration.zero);
        expect(controller.isRunning(sample('a')), isTrue);

        controller.backgroundPaused = true;
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        expect(controller.isRunning(sample('a')), isFalse);
        expect(controller.isTranscribing(sample('a')), isTrue);
        expect(ids(), ['a']);

        // Las pedidas no esperan.
        expect((await requested(sample('b'))).transcript, isNotNull);
        expect(ids(), ['a', 'b']);

        controller.backgroundPaused = false;
        expect((await result)!.transcript, isNotNull);
        expect(ids(), ['a', 'b', 'a']);
      },
    );

    test('se retiran todas, también la que está en curso', () async {
      final gate = transcriber.gate = Completer<void>();
      final running = inBackground(sample('a'));
      final waiting = inBackground(sample('b'));
      final asked = requested(sample('new', day: 9));
      await Future<void>.delayed(Duration.zero);

      controller.cancelBackground();
      gate.complete();

      expect(await running, isNull);
      expect(await waiting, isNull);
      expect((await asked).transcript, isNotNull);
      // La de segundo plano ya había empezado.
      expect(ids(), ['a', 'new']);
      expect(repository.byId('a').transcript, isNull);
    });

    test('no pisa la transcripción que llega entretanto', () async {
      final gate = transcriber.gate = Completer<void>();
      final result = inBackground(sample('a'));
      await Future<void>.delayed(Duration.zero);
      // P. ej. leída de su .txt al sincronizar.
      final fromFile = Transcript(
        text: 'Del .txt',
        revision: 0,
        createdAt: DateTime(2026, 10, 5),
      );
      await repository.setTranscript(sample('a'), fromFile);

      gate.complete();
      expect((await result)!.transcript, fromFile);
      expect(repository.byId('a').transcript, fromFile);
    });

    test('si ya se está transcribiendo, no la repite', () async {
      final asked = requested(sample('a'));
      expect(await inBackground(sample('a')), isNull);
      await asked;
      expect(ids(), ['a']);
    });

    test('los errores llegan a quien la puso en segundo plano', () async {
      transcriber.error = const TranscriptionException(
        TranscriptionError.systemUnavailable,
      );
      await expectLater(
        inBackground(sample('a')),
        throwsA(isA<TranscriptionException>()),
      );
    });
  });
}
