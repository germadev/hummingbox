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

  Recording sample(String id) => Recording(
    id: id,
    path: '/fake/$id.m4a',
    name: 'Grabación $id',
    createdAt: DateTime(2026, 10, 5),
    duration: const Duration(seconds: 5),
  );

  setUp(() {
    repository = InMemoryRecordingsRepository([sample('a'), sample('b')]);
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
}
