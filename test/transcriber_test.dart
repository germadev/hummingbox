import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/services/speech_recognition.dart';
import 'package:voicerecorder/services/transcriber.dart';

import 'fakes.dart';
import 'wav_helpers.dart';

void main() {
  late Directory directory;
  late CopyingAudioCodec codec;
  late FakeSystemSpeech system;
  late FakeWhisperService whisper;
  late Transcriber transcriber;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('transcriber_test');
    codec = CopyingAudioCodec();
    system = FakeSystemSpeech();
    whisper = FakeWhisperService();
    transcriber = Transcriber(
      codec: codec,
      system: system,
      whisper: whisper,
      workDirectory: () async => directory,
      useIsolates: false,
    );
  });

  tearDown(() => directory.delete(recursive: true));

  /// Grabación WAV de [seconds] segundos a 44,1 kHz, con silencio en los
  /// tramos de [silences] (en segundos).
  Future<Recording> recording({
    double seconds = 2,
    String name = 'rec.wav',
    int revision = 0,
    List<(double, double)> silences = const [],
  }) async {
    bool silent(int i) =>
        silences.any((s) => i >= s.$1 * 44100 && i < s.$2 * 44100);
    final path = await writeWav(directory, name, [
      for (var i = 0; i < (44100 * seconds).round(); i++)
        silent(i) ? 0 : (i % 200) * 50,
    ], sampleRate: 44100);
    return Recording(
      id: 'rec',
      path: path,
      name: 'Idea',
      createdAt: DateTime(2026, 10, 5),
      duration: Duration(milliseconds: (seconds * 1000).round()),
      revision: revision,
    );
  }

  Future<TranscriptionError> errorOf(Future<Object?> future) async {
    try {
      await future;
    } on TranscriptionException catch (e) {
      return e.error;
    }
    fail('No ha fallado');
  }

  bool sessionsCleaned() {
    final root = Directory(p.join(directory.path, 'transcription'));
    return !root.existsSync() || root.listSync().isEmpty;
  }

  group('reconocimiento del sistema', () {
    test('convierte el audio a 16 kHz y lo transcribe', () async {
      final progress = <double?>[];

      final transcript = await transcriber.transcribe(
        await recording(revision: 3),
        engine: TranscriptionEngine.system,
        language: 'es',
        onProgress: progress.add,
      );

      expect(system.checked, ['es']);
      // La variante que dio el sistema.
      expect(system.transcribed, [(32000, 'es-ES')]);
      expect(transcript.text, 'Hola');
      expect(transcript.engine, TranscriptionEngine.system);
      expect(transcript.language, 'es-ES');
      expect(transcript.revision, 3);
      expect(progress.first, isNull);
      expect(progress.last, 1);
      // Un WAV de 16 bits no hace falta decodificarlo.
      expect(codec.calls, isEmpty);
      expect(sessionsCleaned(), isTrue);
    });

    test('decodifica primero un m4a', () async {
      final wav = await recording();
      final m4a = p.join(directory.path, 'rec.m4a');
      await File(wav.path).copy(m4a);

      await transcriber.transcribe(
        Recording(
          id: 'rec',
          path: m4a,
          name: 'Idea',
          createdAt: DateTime(2026),
          duration: Duration.zero,
        ),
        engine: TranscriptionEngine.system,
        language: 'es',
      );

      expect(codec.calls, ['decode rec.m4a']);
      expect(system.transcribed.single.$1, 32000);
    });

    test('divide los audios largos si el sistema tiene un límite', () async {
      system
        ..maxLength = const Duration(seconds: 1)
        ..texts.addAll(['Uno,', 'dos', 'y tres.']);

      final transcript = await transcriber.transcribe(
        // Se corta en los silencios.
        await recording(seconds: 2.5, silences: [(0.8, 0.9), (1.6, 1.7)]),
        engine: TranscriptionEngine.system,
        language: 'es',
      );

      expect(system.transcribed, hasLength(3));
      expect(system.transcribed.first.$1, closeTo(0.85 * 16000, 800));
      expect(system.transcribed.fold<int>(0, (sum, t) => sum + t.$1), 40000);
      expect(transcript.text, 'Uno, dos y tres.');
    });

    test('si hay que descargar el idioma, lo dice sin preparar el '
        'audio', () async {
      system.support = const SystemSpeechSupport(
        SystemSpeechStatus.download,
        language: 'es-ES',
      );

      try {
        await transcriber.transcribe(
          await recording(),
          engine: TranscriptionEngine.system,
          language: 'es',
        );
        fail('No ha fallado');
      } on TranscriptionException catch (e) {
        expect(e.error, TranscriptionError.needsDownload);
        expect(e.language, 'es-ES');
      }
      expect(system.transcribed, isEmpty);
      expect(sessionsCleaned(), isTrue);
    });

    test('explica por qué no puede', () async {
      final cases = {
        SystemSpeechStatus.downloading: TranscriptionError.downloading,
        SystemSpeechStatus.unsupportedLanguage:
            TranscriptionError.unsupportedLanguage,
        SystemSpeechStatus.denied: TranscriptionError.denied,
        SystemSpeechStatus.unavailable: TranscriptionError.systemUnavailable,
      };
      final rec = await recording();
      for (final MapEntry(key: status, value: error) in cases.entries) {
        system.support = SystemSpeechSupport(status);
        expect(
          await errorOf(
            transcriber.transcribe(
              rec,
              engine: TranscriptionEngine.system,
              language: 'ja',
            ),
          ),
          error,
          reason: '$status',
        );
      }
    });

    test('traduce los errores del reconocedor', () async {
      system.error = PlatformException(code: 'permission');

      expect(
        await errorOf(
          transcriber.transcribe(
            await recording(),
            engine: TranscriptionEngine.system,
            language: 'es',
          ),
        ),
        TranscriptionError.microphone,
      );
      expect(sessionsCleaned(), isTrue);
    });

    test('sin palabras reconocidas, no da una transcripción vacía', () async {
      system.texts.add('  ');

      expect(
        await errorOf(
          transcriber.transcribe(
            await recording(),
            engine: TranscriptionEngine.system,
            language: 'es',
          ),
        ),
        TranscriptionError.noSpeech,
      );
    });

    test('se puede cancelar', () async {
      system.gate = Completer<void>();
      final cancel = TranscriptionCancel();

      final result = errorOf(
        transcriber.transcribe(
          await recording(),
          engine: TranscriptionEngine.system,
          language: 'es',
          cancel: cancel,
        ),
      );
      while (system.transcribed.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      cancel.cancel();

      expect(await result, TranscriptionError.canceled);
      expect(system.cancelled, isTrue);
      expect(sessionsCleaned(), isTrue);
    });
  });

  group('Whisper', () {
    test('sin modelo instalado, lo dice', () async {
      expect(
        await errorOf(
          transcriber.transcribe(
            await recording(),
            engine: TranscriptionEngine.whisper,
            language: 'es',
          ),
        ),
        TranscriptionError.whisperNotInstalled,
      );
      expect(whisper.opened, 0);
    });

    test('transcribe con el modelo instalado y detecta el idioma', () async {
      whisper
        ..installed = WhisperModel.base
        ..texts.add(' Hola, mundo. ');

      final transcript = await transcriber.transcribe(
        await recording(),
        engine: TranscriptionEngine.whisper,
        language: 'auto',
      );

      expect(whisper.chunks, [32000]);
      expect(whisper.languages, ['auto']);
      expect(transcript.text, 'Hola, mundo.');
      expect(transcript.engine, TranscriptionEngine.whisper);
      expect(transcript.model, WhisperModel.base);
      // El que ha detectado.
      expect(transcript.language, 'es');
      expect(whisper.closed, 1);
      expect(system.checked, isEmpty);
    });

    test('si falla, cierra el modelo', () async {
      whisper
        ..installed = WhisperModel.tiny
        ..error = Exception('sin memoria');

      expect(
        await errorOf(
          transcriber.transcribe(
            await recording(),
            engine: TranscriptionEngine.whisper,
            language: 'es',
          ),
        ),
        TranscriptionError.failed,
      );
      expect(whisper.closed, 1);
      expect(sessionsCleaned(), isTrue);
    });
  });
}
