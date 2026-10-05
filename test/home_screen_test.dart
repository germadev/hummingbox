import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:voicerecorder/app.dart';
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/services/transcriber.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/widgets/record_panel.dart';
import 'package:voicerecorder/widgets/piano.dart';

import 'fakes.dart';
import 'l10n_helpers.dart';
import 'waveform_helpers.dart';

void main() {
  late InMemoryRecordingsRepository repository;
  late FakeAudioRecorderService recorder;
  late FakeAudioPlayerService player;
  late FakeRecordingEditor editor;
  late InMemorySettingsStore store;
  late FakeFolderAccess folders;
  late FakeDriveService drive;
  late FakeScreenAwake screen;
  late FakeTranscriber transcriber;
  late FakeWhisperService whisper;
  late FakePianoSound piano;

  setUpAll(() => initializeDateFormatting('es'));

  /// Sin transcripción automática: los tests que no son suyos no esperan
  /// transcripciones ni `.txt` (ver el grupo «transcripción automática»).
  const manual = TranscriptionSettings(automatic: false);

  setUp(() {
    repository = InMemoryRecordingsRepository();
    recorder = FakeAudioRecorderService();
    player = FakeAudioPlayerService();
    store = InMemorySettingsStore(
      const AppSettings(folder: testFolder, transcription: manual),
    );
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    screen = FakeScreenAwake();
    whisper = FakeWhisperService();
    transcriber = FakeTranscriber(whisper: whisper);
    piano = FakePianoSound();
  });

  Recording sample(
    String id,
    String name, {
    List<double>? waveform,
    String folder = '',
    DateTime? createdAt,
  }) => Recording(
    id: id,
    path: '/fake/$id.m4a',
    name: name,
    createdAt: createdAt ?? DateTime(2026, 9, 28, 8, 30),
    duration: const Duration(seconds: 83),
    waveform: waveform,
    folder: folder,
  );

  Future<void> pumpApp(
    WidgetTester tester, [
    void Function(FakeRecordingEditor editor)? setUpEditor,
    bool Function(String path)? fileExists,
  ]) async {
    editor = FakeRecordingEditor(repository: repository);
    setUpEditor?.call(editor);
    await tester.pumpWidget(
      VoiceRecorderApp(
        locale: testLocale,
        repository: repository,
        recorderFactory: () => recorder,
        playerFactory: () => player,
        editor: editor,
        sync: fakeStorageSync(
          repository,
          store: store,
          folders: folders,
          drive: drive,
          fileExists: fileExists,
        ),
        transcriber: transcriber,
        whisper: fakeWhisperController(whisper),
        piano: piano,
        screen: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Avanza lo suficiente para terminar las animaciones mientras se graba
  /// (el cronómetro no deja que `pumpAndSettle` termine).
  Future<void> pumpAnimations(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder record() => find.byKey(const Key('record-button'));

  testWidgets('muestra un mensaje cuando no hay grabaciones', (tester) async {
    await pumpApp(tester);

    expect(find.text('Aún no hay grabaciones'), findsOneWidget);
    expect(find.byKey(const Key('pause-button')), findsNothing);
  });

  double panelHeight(WidgetTester tester) =>
      tester.getSize(find.byType(RecordPanel)).height;

  testWidgets('graba, pausa y guarda una grabación', (tester) async {
    await pumpApp(tester);
    final collapsed = panelHeight(tester);

    await tester.tap(record());
    await pumpAnimations(tester);
    expect(find.text('Grabando'), findsOneWidget);
    expect(find.byKey(const Key('elapsed-time')), findsOneWidget);
    // El panel se despliega al empezar a grabar.
    expect(panelHeight(tester), greaterThan(collapsed + 100));

    await tester.tap(find.byKey(const Key('pause-button')));
    await pumpAnimations(tester);
    expect(find.text('En pausa'), findsOneWidget);

    await tester.tap(record());
    await tester.pumpAndSettle();

    expect(find.text('Grabando'), findsNothing);
    expect(panelHeight(tester), collapsed);
    expect(find.text('2026-10-05 14.32'), findsOneWidget);
    expect(find.text('Guardada como «2026-10-05 14.32»'), findsOneWidget);
    expect(recorder.calls, ['hasPermission', 'start', 'pause', 'stop']);
  });

  testWidgets('mantiene la pantalla encendida mientras graba', (tester) async {
    await pumpApp(tester);
    expect(screen.calls, isEmpty);

    await tester.tap(record());
    await pumpAnimations(tester);
    expect(screen.calls, [true]);

    // En pausa sigue la grabación en curso.
    await tester.tap(find.byKey(const Key('pause-button')));
    await pumpAnimations(tester);
    expect(screen.calls, [true]);

    await tester.tap(record());
    await tester.pumpAndSettle();
    expect(screen.calls, [true, false]);
  });

  testWidgets('no mantiene la pantalla encendida si está desactivado', (
    tester,
  ) async {
    store.settings = store.settings.withKeepScreenOn(false);
    await pumpApp(tester);

    await tester.tap(record());
    await pumpAnimations(tester);
    await tester.tap(record());
    await tester.pumpAndSettle();

    expect(screen.calls, isEmpty);
  });

  testWidgets('avisa si no hay permiso de micrófono', (tester) async {
    recorder.permissionGranted = false;
    await pumpApp(tester);

    await tester.tap(record());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Permite el acceso al micrófono en los ajustes para poder grabar',
      ),
      findsOneWidget,
    );
    expect(find.text('Grabando'), findsNothing);
  });

  testWidgets('descarta una grabación tras confirmarlo', (tester) async {
    await pumpApp(tester);
    await tester.tap(record());
    await pumpAnimations(tester);

    await tester.tap(find.byKey(const Key('cancel-button')));
    await pumpAnimations(tester);
    expect(find.text('¿Descartar la grabación?'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Grabando'), findsNothing);
    expect(repository.recordings, isEmpty);
    expect(repository.discarded, [recorder.path]);
  });

  testWidgets('reproduce y pausa una grabación', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
    await pumpApp(tester);

    expect(find.text('Entrevista'), findsOneWidget);
    expect(find.text('28 sept 2026, 8:30 · 01:23'), findsOneWidget);

    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pumpAndSettle();
    expect(player.calls, ['play /fake/a.m4a @0']);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(find.byKey(const Key('playback-position')), findsOneWidget);

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'pause');
    expect(find.byTooltip('Reproducir'), findsOneWidget);
  });

  testWidgets('no reproduce mientras se graba', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
    await pumpApp(tester);
    await tester.tap(record());
    await pumpAnimations(tester);

    await tester.tap(find.byTooltip('Reproducir'));
    await pumpAnimations(tester);

    expect(player.calls, isNot(contains(startsWith('play'))));
    expect(
      find.text('Detén la grabación para poder reproducir'),
      findsOneWidget,
    );
  });

  testWidgets('renombra una grabación', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Grabación 1')]);
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Clase de historia');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Clase de historia'), findsOneWidget);
    expect(repository.recordings.single.name, 'Clase de historia');
  });

  testWidgets('tocar el nombre lo edita sin reproducir', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Grabación 1')]);
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('name-a')));
    await tester.pumpAndSettle();
    expect(find.text('Renombrar grabación'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Idea');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.recordings.single.name, 'Idea');
    expect(player.calls, isEmpty);
  });

  testWidgets('muestra el formato y la calidad de cada grabación', (
    tester,
  ) async {
    repository = InMemoryRecordingsRepository([
      Recording(
        id: 'a',
        path: '/fake/a.m4a',
        name: 'Con datos',
        createdAt: DateTime(2026, 9, 28),
        duration: const Duration(seconds: 5),
        waveform: const [0.5],
        audio: const AudioInfo(
          format: RecordingFormat.aac,
          sampleRate: 44100,
          channels: 1,
          bitRate: 128000,
        ),
      ),
      Recording(
        id: 'b',
        path: '/fake/b.wav',
        name: 'Antigua',
        createdAt: DateTime(2026, 9, 27),
        duration: const Duration(seconds: 5),
        waveform: const [0.5],
      ),
    ]);
    await pumpApp(tester);

    expect(find.text('AAC · 128 kbps · 44,1 kHz'), findsOneWidget);
    // Sin datos todavía (no se pudo leer), al menos el formato.
    expect(find.text('WAV'), findsOneWidget);
  });

  testWidgets('lee el formato de las grabaciones que no lo tienen', (
    tester,
  ) async {
    repository = InMemoryRecordingsRepository([
      sample('a', 'Antigua', waveform: const [0.5]),
    ]);
    await pumpApp(tester, (editor) {
      editor.probes['/fake/a.m4a'] = const AudioProbe(
        AudioInfo(
          format: RecordingFormat.aac,
          sampleRate: 16000,
          channels: 1,
          bitRate: 32000,
        ),
        Duration(seconds: 83),
      );
    });

    expect(find.text('AAC · 32 kbps · 16 kHz'), findsOneWidget);
    expect(repository.recordings.single.audio?.bitRate, 32000);
  });

  testWidgets('no permite un nombre vacío', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Grabación 1')]);
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('elimina una grabación tras confirmarlo', (tester) async {
    repository = InMemoryRecordingsRepository([
      sample('a', 'Entrevista'),
      sample('b', 'Notas'),
    ]);
    await pumpApp(tester);

    // Se está reproduciendo la grabación que se va a eliminar.
    await tester.tap(find.byTooltip('Reproducir').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más opciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Entrevista»?'), findsOneWidget);

    // Está guardada en la carpeta: se borra también de allí.
    expect(
      find.text(
        'También se borrará de «Grabaciones». Esta acción no se puede '
        'deshacer.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Entrevista'), findsNothing);
    expect(find.text('Notas'), findsOneWidget);
    expect(repository.recordings.map((r) => r.name), ['Notas']);
    expect(player.calls.last, 'stop');
    expect(folders.files.values, ['Notas.m4a']);
  });

  group('orden de la lista', () {
    /// Más de las que caben en la pantalla, de la más antigua a la más
    /// reciente.
    List<Recording> many() => [
      for (var i = 0; i < 20; i++)
        sample('r$i', 'Toma $i', createdAt: DateTime(2020, 1, 1 + i)),
    ];

    testWidgets('la más antigua arriba y las siguientes debajo', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        sample('new', 'Reciente', createdAt: DateTime(2020, 1, 2)),
        sample('old', 'Antigua', createdAt: DateTime(2020, 1, 1)),
      ]);
      await pumpApp(tester);

      expect(
        tester.getTopLeft(find.text('Antigua')).dy,
        lessThan(tester.getTopLeft(find.text('Reciente')).dy),
      );
    });

    testWidgets('al abrir la app, muestra el final de la lista', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository(many());
      await pumpApp(tester);

      expect(find.text('Toma 19').hitTestable(), findsOneWidget);
      expect(find.text('Toma 0').hitTestable(), findsNothing);
    });

    testWidgets('al añadir una grabación, baja hasta ella', (tester) async {
      repository = InMemoryRecordingsRepository(many());
      await pumpApp(tester);
      // Se sube hasta el principio.
      await tester.fling(find.text('Toma 19'), const Offset(0, 10000), 5000);
      await tester.pumpAndSettle();
      expect(find.text('Toma 0').hitTestable(), findsOneWidget);

      await tester.tap(record());
      await pumpAnimations(tester);
      await tester.tap(record());
      await tester.pumpAndSettle();

      expect(find.text('2026-10-05 14.32').hitTestable(), findsOneWidget);
      expect(find.text('Toma 0').hitTestable(), findsNothing);
    });
  });

  group('menú inicial', () {
    setUp(
      () => store = InMemorySettingsStore(
        const AppSettings(transcription: manual),
      ),
    );

    testWidgets('sin destino, pide elegirlo antes de grabar', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      expect(
        find.text('¿Dónde quieres guardar las grabaciones?'),
        findsOneWidget,
      );
      expect(record(), findsNothing);
      expect(find.text('Entrevista'), findsNothing);
      expect(folders.calls, isEmpty);
    });

    testWidgets('elige una carpeta y guarda en ella lo que había', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      folders.addFile('tree://music', 'Idea.m4a');
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('setup-folder')));
      await tester.pumpAndSettle();

      expect(store.settings.folder!.id, 'tree://music');
      expect(record(), findsOneWidget);
      expect(find.text('Entrevista'), findsOneWidget);
      expect(find.text('Idea'), findsOneWidget);
      // Ya está en la carpeta: su audio sale de la app.
      expect(folders.calls, contains('write Entrevista.m4a'));
      expect(repository.released, contains('a'));
    });

    testWidgets('elige Google Drive', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('setup-drive')));
      await tester.pumpAndSettle();

      expect(store.settings.storage, StorageKind.drive);
      expect(find.text('Aún no hay grabaciones'), findsOneWidget);

      await tester.tap(record());
      await pumpAnimations(tester);
      await tester.tap(record());
      await tester.pumpAndSettle();
      expect(drive.calls, ['upload 2026-10-05 14.32.m4a']);
    });

    testWidgets('sin Google Drive configurado, solo deja elegir carpeta', (
      tester,
    ) async {
      drive.isAvailable = false;
      await pumpApp(tester);

      expect(find.textContaining('No disponible'), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup-drive')));
      await tester.pumpAndSettle();
      expect(store.settings.storage, isNull);
    });

    testWidgets('vuelve a él al dejar de usar la carpeta', (tester) async {
      store.settings = const AppSettings(folder: testFolder);
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Dejar de usar la carpeta'),
        200,
      );
      await tester.tap(find.byTooltip('Dejar de usar la carpeta'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dejar de usar «Grabaciones»?'), findsOneWidget);
      await tester.tap(find.text('Dejar de usarla'));
      await tester.pumpAndSettle();

      expect(store.settings.storage, isNull);
      expect(
        find.text('¿Dónde quieres guardar las grabaciones?'),
        findsOneWidget,
      );
    });
  });

  group('panel de grabación', () {
    Finder handle() => find.byKey(const Key('panel-handle'));

    testWidgets('al grabar, la onda solo cambia de color desde el inicio', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(handle());
      await tester.pumpAndSettle();

      final waveform = find.byKey(const Key('recording-waveform'));
      final idle = Theme.of(tester.element(waveform))
          .colorScheme
          .onSurfaceVariant
          .withValues(alpha: 0.4);
      final bars = barColors(tester, waveform);
      expect(bars, hasLength(greaterThan(3)));
      expect(bars, everyElement(isSameColorAs(idle)));

      await tester.tap(record());
      await pumpAnimations(tester);
      // Aún sin muestras: nada cambia de color.
      expect(barColors(tester, waveform), everyElement(isSameColorAs(idle)));

      for (final db in [-30.0, -10.0, -20.0]) {
        recorder.amplitudeController.add(db);
      }
      await pumpAnimations(tester);
      expect(barColors(tester, waveform), [
        ...List.filled(3, isSameColorAs(recordRed)),
        ...List.filled(bars.length - 3, isSameColorAs(idle)),
      ]);

      // En pausa se atenúa lo grabado, pero el hueco sigue igual.
      await tester.tap(find.byKey(const Key('pause-button')));
      await pumpAnimations(tester);
      expect(barColors(tester, waveform), [
        ...List.filled(3, isSameColorAs(recordRed.withValues(alpha: 0.4))),
        ...List.filled(bars.length - 3, isSameColorAs(idle)),
      ]);

      await tester.tap(record());
      await tester.pumpAndSettle();
    });

    testWidgets('al deslizarlo hacia arriba se prepara sin grabar', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Lista para grabar'), findsNothing);

      await tester.drag(handle(), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Lista para grabar'), findsOneWidget);
      expect(find.text('00:00,0'), findsOneWidget);
      expect(recorder.calls, isEmpty);

      await tester.drag(handle(), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Lista para grabar'), findsNothing);
      expect(recorder.calls, isEmpty);
    });

    testWidgets('los botones de cuenta atrás y voz solo con el panel abierto', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('countdown-button')), findsNothing);
      expect(find.byKey(const Key('voice-button')), findsNothing);

      await tester.drag(handle(), const Offset(0, -300));
      await tester.pumpAndSettle();

      // En el lugar de «Descartar» y de «Pausar».
      expect(find.byKey(const Key('countdown-button')), findsOneWidget);
      expect(find.byKey(const Key('voice-button')), findsOneWidget);
      expect(recorder.calls, isEmpty);
    });

    testWidgets('graba al terminar la cuenta atrás', (tester) async {
      store.settings = const AppSettings(
        folder: testFolder,
        countdownSeconds: 5,
        transcription: manual,
      );
      await pumpApp(tester);
      await tester.drag(handle(), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('countdown-button')));
      await tester.pump();
      expect(find.text('Empieza a grabar en…'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(recorder.calls, ['hasPermission']);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await pumpAnimations(tester);

      expect(find.text('Grabando'), findsOneWidget);
      expect(recorder.calls, ['hasPermission', 'hasPermission', 'start']);

      await tester.tap(record());
      await tester.pumpAndSettle();
      expect(find.text('2026-10-05 14.32'), findsOneWidget);
    });

    testWidgets('cancela la cuenta atrás con la X', (tester) async {
      await pumpApp(tester);
      await tester.drag(handle(), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('countdown-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cancel-button')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Lista para grabar'), findsOneWidget);
      expect(recorder.calls, ['hasPermission']);
    });

    testWidgets('graba al detectar la voz y recorta la espera', (tester) async {
      await pumpApp(tester);
      await tester.drag(handle(), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voice-button')));
      await tester.pump();
      expect(find.text('Esperando a que hables…'), findsOneWidget);

      for (final db in [...List.filled(30, -55.0), -25.0, -25.0]) {
        recorder.amplitudeController.add(db);
      }
      await pumpAnimations(tester);
      expect(find.text('Grabando'), findsOneWidget);

      await tester.tap(record());
      await tester.pumpAndSettle();

      expect(find.text('2026-10-05 14.32'), findsOneWidget);
      expect(editor.trims, {
        recorder.path!: const Duration(milliseconds: 2200),
      });
    });

    testWidgets('un arrastre corto vuelve a su sitio', (tester) async {
      await pumpApp(tester);

      final gesture = await tester.startGesture(tester.getCenter(handle()));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Lista para grabar'), findsNothing);
    });

    testWidgets('el tirador lo despliega y, al grabar, sigue abierto', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(handle());
      await tester.pumpAndSettle();
      expect(find.text('Lista para grabar'), findsOneWidget);

      await tester.tap(record());
      await pumpAnimations(tester);
      expect(find.text('Grabando'), findsOneWidget);

      // Mientras se graba no se puede plegar.
      await tester.drag(
        find.byKey(const Key('elapsed-time')),
        const Offset(0, 300),
      );
      await pumpAnimations(tester);
      expect(find.text('Grabando'), findsOneWidget);

      await tester.tap(record());
      await tester.pumpAndSettle();
      expect(find.text('Grabando'), findsNothing);
      expect(find.text('Lista para grabar'), findsNothing);
    });
  });

  group('onda de las grabaciones', () {
    testWidgets('tocar la onda reproduce desde ese punto y luego salta', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', waveform: [0.2, 0.8, 0.4]),
      ]);
      await pumpApp(tester);
      final waveform = find.byKey(const Key('waveform-a'));
      expect(waveform, findsOneWidget);

      await tester.tap(waveform);
      await tester.pumpAndSettle();
      expect(player.calls, ['play /fake/a.m4a @41500']);
      expect(find.text('00:41'), findsOneWidget);
      expect(find.text('01:23'), findsOneWidget);

      final box = tester.getRect(waveform);
      await tester.tapAt(Offset(box.left + box.width / 4, box.top + 10));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'seek 20750');

      // Arrastrar sobre la onda salta, no abre el menú lateral.
      await tester.dragFrom(
        Offset(box.left + 10, box.top + 10),
        Offset(box.width / 2, 0),
      );
      await tester.pumpAndSettle();
      expect(player.calls.last, startsWith('seek'));
      expect(find.byKey(const Key('new-folder')), findsNothing);
    });

    testWidgets('calcula la onda de las grabaciones que no la tienen', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Antigua'),
        sample('b', 'Nueva', waveform: [0.5]),
      ]);
      await pumpApp(tester);

      expect(editor.extracted, ['a']);
      expect(repository.byId('a').waveform, [0.2, 0.6, 1.0]);
    });

    testWidgets('con Drive, no descarga nada para la onda hasta escucharla', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'a',
          path: '/fake/a.m4a',
          name: 'Idea',
          createdAt: DateTime(2026, 9, 28, 8, 30),
          duration: Duration.zero,
          copies: const {
            'drive': CopyState(
              destination: 'folder1',
              ref: 'file0',
              revision: 0,
              name: 'Idea',
            ),
          },
        ),
      ]);
      drive.addFile('Idea.m4a');
      store.settings = const AppSettings(
        drive: DriveSettings(email: 'ana@example.com', folderId: 'folder1'),
      );
      // Ningún audio está en el dispositivo.
      final local = <String>{};
      await pumpApp(tester, null, local.contains);

      expect(find.text('Idea'), findsOneWidget);
      expect(editor.extracted, isEmpty);
      expect(drive.calls, isEmpty);

      // Al escucharla se descarga (aquí, se simula que ya está).
      local.add('/fake/a.m4a');
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      expect(editor.extracted, ['a']);
    });
  });

  testWidgets('edita una grabación y reemplaza la original', (tester) async {
    repository = InMemoryRecordingsRepository([
      sample('a', 'Entrevista', waveform: [0.5]),
    ]);
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar grabación'), findsOneWidget);

    await tester.tap(find.text('Normalizar'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Editar grabación'), findsNothing);
    expect(find.text('Cambios guardados'), findsOneWidget);
    expect(editor.savedAsCopy, isFalse);
    expect(repository.byId('a').revision, 1);
    expect(editor.closedSessions, 1);
  });

  testWidgets('no deja editar mientras se graba', (tester) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
    await pumpApp(tester);
    await tester.tap(record());
    await pumpAnimations(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await pumpAnimations(tester);
    await tester.tap(find.text('Editar'));
    await pumpAnimations(tester);

    expect(find.text('Detén la grabación para poder editar'), findsOneWidget);
    expect(find.text('Editar grabación'), findsNothing);
  });

  group('transcripción', () {
    Future<void> chooseInMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
    }

    testWidgets('transcribe desde el menú y muestra el texto al escucharla', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pumpAndSettle();

      expect(transcriber.calls, [('a', TranscriptionEngine.system, 'es')]);
      expect(find.text('Transcripción lista'), findsOneWidget);
      expect(
        repository.byId('a').transcript!.text,
        'Hola, esto es una prueba.',
      );
      // El texto solo se ve mientras se escucha.
      expect(find.text('Hola, esto es una prueba.'), findsNothing);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, esto es una prueba.'), findsOneWidget);

      // Ahora el menú lleva a la transcripción.
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Transcribir'), findsNothing);
      expect(find.text('Ver transcripción'), findsOneWidget);
    });

    testWidgets('con Whisper, usa el idioma elegido', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      store.settings = const AppSettings(
        folder: testFolder,
        transcription: TranscriptionSettings(
          engine: TranscriptionEngine.whisper,
          language: TranscriptionSettings.detectLanguage,
          automatic: false,
        ),
      );
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pumpAndSettle();

      expect(transcriber.calls, [('a', TranscriptionEngine.whisper, 'auto')]);
    });

    testWidgets('muestra el progreso y deja cancelar', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      final gate = transcriber.gate = Completer<void>();
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Transcribiendo… 25\u00a0%'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancelar transcripción'));
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('transcription-progress')), findsNothing);
      expect(repository.byId('a').transcript, isNull);
      // Cancelar no es un error.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('si el sistema no puede, ofrece abrir las opciones', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      transcriber.error = const TranscriptionException(
        TranscriptionError.systemUnavailable,
      );
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pumpAndSettle();
      expect(
        find.text('El reconocimiento de voz no está disponible'),
        findsOneWidget,
      );
      await tester.tap(find.text('Abrir opciones'));
      await tester.pumpAndSettle();

      expect(find.text('Opciones'), findsOneWidget);
    });

    testWidgets('pide descargar el idioma si hace falta', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      transcriber.error = const TranscriptionException(
        TranscriptionError.needsDownload,
        language: 'es-ES',
      );
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pumpAndSettle();
      expect(find.text('¿Descargar «Español»?'), findsOneWidget);
      await tester.tap(find.text('Descargar'));
      await tester.pumpAndSettle();

      expect(transcriber.system.downloads, ['es-ES']);
    });

    testWidgets('sin Whisper instalado, ofrece abrir las opciones', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      transcriber.error = const TranscriptionException(
        TranscriptionError.whisperNotInstalled,
      );
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir');
      await tester.pumpAndSettle();

      expect(find.text('Whisper no está instalado'), findsOneWidget);
    });

    testWidgets('no deja transcribir mientras se graba', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(record());
      await pumpAnimations(tester);

      await tester.tap(find.byTooltip('Más opciones'));
      await pumpAnimations(tester);
      await tester.tap(find.text('Transcribir'));
      await pumpAnimations(tester);

      expect(
        find.text('Detén la grabación para poder transcribir'),
        findsOneWidget,
      );
      expect(transcriber.calls, isEmpty);
    });

    Recording transcribed({int revision = 0}) => Recording(
      id: 'a',
      path: '/fake/a.m4a',
      name: 'Entrevista',
      createdAt: DateTime(2026, 9, 28, 8, 30),
      duration: const Duration(seconds: 83),
      revision: revision,
      transcript: Transcript(
        text: 'Buenos días a todos.',
        engine: TranscriptionEngine.whisper,
        model: WhisperModel.base,
        language: 'es',
        revision: 0,
        createdAt: DateTime(2026, 9, 28, 9),
      ),
    );

    testWidgets('abre la transcripción y la elimina', (tester) async {
      repository = InMemoryRecordingsRepository([transcribed()]);
      await pumpApp(tester);
      // Al escucharla se ve su transcripción, que se abre al tocarla.
      expect(find.byKey(const Key('transcript-a')), findsNothing);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('transcript-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transcript-text')), findsOneWidget);
      expect(find.textContaining('Whisper (Base) · Español'), findsOneWidget);
      expect(
        find.text('La grabación ha cambiado desde que se transcribió.'),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar transcripción'));
      await tester.pumpAndSettle();

      expect(find.text('Transcripción eliminada'), findsOneWidget);
      expect(find.text('Buenos días a todos.'), findsNothing);
      expect(repository.byId('a').transcript, isNull);
      // No se vuelve a transcribir sola.
      expect(repository.byId('a').needsTranscript, isFalse);
    });

    testWidgets('avisa si la grabación cambió y deja volver a transcribir', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([transcribed(revision: 1)]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Ver transcripción');
      await tester.pumpAndSettle();
      expect(
        find.text('La grabación ha cambiado desde que se transcribió.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a transcribir'));
      await tester.pumpAndSettle();

      expect(transcriber.calls, hasLength(1));
      expect(repository.byId('a').transcript!.revision, 1);
      expect(
        repository.byId('a').transcript!.text,
        'Hola, esto es una prueba.',
      );
    });
  });

  group('transcripción automática', () {
    setUp(() => store.settings = const AppSettings(folder: testFolder));

    /// Sale de la app y vuelve a ella.
    void leaveAndReturn(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    Iterable<String> transcribed() => transcriber.calls.map((c) => c.$1);

    testWidgets('transcribe sola, en segundo plano, de la más reciente a la '
        'más antigua', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('old', 'Antigua', createdAt: DateTime(2026, 9, 1)),
        sample('new', 'Reciente', createdAt: DateTime(2026, 9, 30)),
      ]);
      final gate = transcriber.gate = Completer<void>();
      await pumpApp(tester);

      expect(transcribed(), ['new']);
      // En segundo plano no se ve el progreso, y se puede pedir.
      expect(find.byKey(const Key('transcription-progress')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(transcribed(), ['new', 'old']);
      expect(repository.byId('new').transcript, isNotNull);
      expect(repository.byId('old').transcript, isNotNull);
      // Se guarda junto al audio, sin avisos.
      expect(
        folders.files.values,
        containsAll(['Reciente.txt', 'Antigua.txt']),
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no transcribe si está desactivada', (tester) async {
      store.settings = const AppSettings(
        folder: testFolder,
        transcription: manual,
      );
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      expect(transcriber.calls, isEmpty);
    });

    testWidgets('al activarla en las opciones, empieza', (tester) async {
      store.settings = const AppSettings(
        folder: testFolder,
        transcription: manual,
      );
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();
      final option = find.byKey(const Key('auto-transcribe-option'));
      await tester.scrollUntilVisible(option, 200);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(store.settings.transcription.automatic, isTrue);
      expect(transcribed(), ['a']);
      expect(repository.byId('a').transcript, isNotNull);
    });

    testWidgets('la grabación nueva se transcribe al guardarla; mientras se '
        'graba, espera', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      final gate = transcriber.gate = Completer<void>();
      await pumpApp(tester);
      expect(transcribed(), ['a']);

      // Al grabar se interrumpe y no empieza ninguna otra.
      await tester.tap(record());
      await pumpAnimations(tester);
      gate.complete();
      await pumpAnimations(tester);
      expect(transcribed(), ['a']);
      expect(repository.byId('a').transcript, isNull);

      transcriber.gate = null;
      await tester.tap(record());
      await tester.pumpAndSettle();

      // Vuelve a empezar la interrumpida y sigue con la nueva.
      expect(transcribed(), ['a', 'a', 'rec_0']);
      expect(repository.byId('a').transcript, isNotNull);
      expect(repository.byId('rec_0').transcript, isNotNull);
    });

    testWidgets('sin palabras, no lo vuelve a intentar', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      transcriber.error = const TranscriptionException(
        TranscriptionError.noSpeech,
      );
      await pumpApp(tester);

      expect(repository.byId('a').needsTranscript, isFalse);
      expect(find.byType(SnackBar), findsNothing);
      // Ni al volver a la app.
      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(transcribed(), ['a']);
    });

    testWidgets('si no se puede, se detiene y avisa una vez de por qué', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', createdAt: DateTime(2026, 9, 30)),
        sample('b', 'Notas'),
      ]);
      transcriber.error = const TranscriptionException(
        TranscriptionError.systemUnavailable,
      );
      await pumpApp(tester);

      // No sigue con las demás.
      expect(transcribed(), ['a']);
      expect(
        find.text('No se pueden transcribir las grabaciones automáticamente'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(
        find.text('El reconocimiento de voz no está disponible'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Al volver a la app lo intenta otra vez, sin repetir el aviso.
      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(transcribed(), ['a', 'a']);
      expect(
        find.text('No se pueden transcribir las grabaciones automáticamente'),
        findsNothing,
      );
    });

    testWidgets('pedir la que va en segundo plano muestra su progreso', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      final gate = transcriber.gate = Completer<void>();
      await pumpApp(tester);
      expect(find.byKey(const Key('transcription-progress')), findsNothing);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transcribir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Transcribiendo… 25\u00a0%'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Transcripción lista'), findsOneWidget);
      // No se ha transcrito dos veces.
      expect(transcribed(), ['a']);
    });

    testWidgets('no vuelve a transcribir la que se ha eliminado', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      expect(repository.byId('a').transcript, isNotNull);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver transcripción'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar transcripción'));
      await tester.pumpAndSettle();

      expect(repository.byId('a').transcript, isNull);
      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(transcribed(), ['a']);
    });
  });

  group('idioma de cada grabación', () {
    Future<void> chooseInMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    Future<void> chooseLanguage(WidgetTester tester, String language) async {
      expect(find.text('Idioma de la grabación'), findsOneWidget);
      await tester.tap(find.text(language));
      await tester.pumpAndSettle();
    }

    /// Al volver a transcribirla, pregunta si se renombra: se deja como está.
    Future<void> keepName(WidgetTester tester) async {
      expect(find.text('¿Renombrar la grabación?'), findsOneWidget);
      await tester.tap(find.text('Mantener'));
      await tester.pumpAndSettle();
    }

    testWidgets('se transcribe en el idioma elegido para la grabación, también '
        'al volver a transcribir', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Interview')]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir en otro idioma');
      // Por defecto, el de las opciones.
      expect(find.text('Como en las opciones'), findsOneWidget);
      expect(find.text('El de la app (Español)'), findsOneWidget);
      await chooseLanguage(tester, 'English');
      await keepName(tester);

      expect(repository.byId('a').transcriptionLanguage, 'en');
      expect(transcriber.calls, [('a', TranscriptionEngine.system, 'en')]);
      expect(find.text('Transcripción lista'), findsOneWidget);
      expect(repository.byId('a').name, 'Interview');

      // «Volver a transcribir» lo respeta.
      await chooseInMenu(tester, 'Ver transcripción');
      await chooseInMenu(tester, 'Volver a transcribir');
      await keepName(tester);
      expect(transcriber.calls.last, ('a', TranscriptionEngine.system, 'en'));
    });

    testWidgets('al volver a transcribirla, puede pasar a llamarse como '
        'empieza la nueva transcripción', (tester) async {
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'a',
          path: '/fake/a.m4a',
          name: 'Interview',
          createdAt: DateTime(2026, 9, 28, 8, 30),
          duration: const Duration(seconds: 83),
          transcript: Transcript(
            text: 'Hello everyone.',
            revision: 0,
            createdAt: DateTime(2026, 9, 28, 9),
          ),
        ),
      ]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Ver transcripción');
      await chooseInMenu(tester, 'Volver a transcribir');

      expect(
        find.text(
          'Con la nueva transcripción, «Interview» pasaría a llamarse '
          '«2026-09-28.Hola, esto es una prueba».',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Renombrar'));
      await tester.pumpAndSettle();

      expect(repository.byId('a').name, '2026-09-28.Hola, esto es una prueba');
      // Se renombran también el audio y el .txt de la carpeta.
      expect(
        folders.calls,
        containsAll([
          'rename doc0 → 2026-09-28.Hola, esto es una prueba.m4a',
          'rename doc1 → 2026-09-28.Hola, esto es una prueba.txt',
        ]),
      );
    });

    testWidgets('si ya se llama así, no pregunta', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', '2026-09-28.Hola, esto es una prueba'),
      ]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Transcribir en otro idioma');
      await chooseLanguage(tester, 'English');

      expect(transcriber.calls, hasLength(1));
      expect(find.text('¿Renombrar la grabación?'), findsNothing);
    });

    testWidgets('desde la transcripción, y «Como en las opciones» vuelve al '
        'de las opciones', (tester) async {
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'a',
          path: '/fake/a.m4a',
          name: 'Interview',
          createdAt: DateTime(2026, 9, 28, 8, 30),
          duration: const Duration(seconds: 83),
          transcriptionLanguage: 'en',
          transcript: Transcript(
            text: 'Hello everyone.',
            engine: TranscriptionEngine.system,
            language: 'en-US',
            revision: 0,
            createdAt: DateTime(2026, 9, 28, 9),
          ),
        ),
      ]);
      await pumpApp(tester);

      await chooseInMenu(tester, 'Ver transcripción');
      await chooseInMenu(tester, 'Transcribir en otro idioma');
      await chooseLanguage(tester, 'Français');
      await keepName(tester);
      expect(transcriber.calls, [('a', TranscriptionEngine.system, 'fr')]);
      expect(repository.byId('a').transcriptionLanguage, 'fr');

      await chooseInMenu(tester, 'Transcribir en otro idioma');
      await chooseLanguage(tester, 'Como en las opciones');
      await keepName(tester);
      expect(repository.byId('a').transcriptionLanguage, isNull);
      expect(transcriber.calls.last, ('a', TranscriptionEngine.system, 'es'));
    });

    testWidgets('la transcripción automática usa el idioma de la grabación, y '
        'si no se puede, solo se salta esa', (tester) async {
      store.settings = const AppSettings(folder: testFolder);
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'de',
          path: '/fake/de.m4a',
          name: 'Gespräch',
          createdAt: DateTime(2026, 9, 30),
          duration: const Duration(seconds: 83),
          transcriptionLanguage: 'de',
        ),
        sample('es', 'Entrevista'),
      ]);
      transcriber.errorFor = (language) => language == 'de'
          ? const TranscriptionException(
              TranscriptionError.needsDownload,
              language: 'de-DE',
            )
          : null;
      await pumpApp(tester);

      expect(transcriber.calls, [
        ('de', TranscriptionEngine.system, 'de'),
        ('es', TranscriptionEngine.system, 'es'),
      ]);
      expect(repository.byId('es').transcript, isNotNull);
      expect(
        find.text('No se pueden transcribir las grabaciones automáticamente'),
        findsNothing,
      );
    });
  });

  group('barra superior y búsqueda', () {
    Recording withTranscript(
      String id,
      String name,
      String text, {
      String folder = '',
    }) => Recording(
      id: id,
      path: '/fake/$id.m4a',
      name: name,
      createdAt: DateTime(2026, 9, 28, 8, 30),
      duration: const Duration(seconds: 83),
      folder: folder,
      transcript: Transcript(
        text: text,
        engine: TranscriptionEngine.system,
        revision: 0,
        createdAt: DateTime(2026, 9, 28, 9),
      ),
    );

    Finder searchField() => find.byKey(const Key('search-field'));

    bool searchFocused(WidgetTester tester) =>
        tester.widget<TextField>(searchField()).focusNode!.hasFocus;

    testWidgets('el botón de carpetas abre el menú y no hay título', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('HummingBox'), findsNothing);

      await tester.tap(find.byTooltip('Carpetas'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new-folder')), findsOneWidget);
    });

    testWidgets('la lupa está en el centro de la barra', (tester) async {
      await pumpApp(tester);
      final search = tester.getCenter(find.byKey(const Key('search-button')));

      expect(search.dx, tester.getSize(find.byType(AppBar)).width / 2);
    });

    testWidgets('el campo tiene la lupa a la izquierda y la X a la derecha, '
        'alineados con los botones', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'reunión');
      await tester.pump();

      final folders = tester.getCenter(find.byKey(const Key('folders-button')));
      final settings = tester.getCenter(
        find.byKey(const Key('settings-button')),
      );
      final magnifier = tester.getCenter(
        find.descendant(of: searchField(), matching: find.byIcon(Icons.search)),
      );
      final text = tester.getRect(find.byType(EditableText));
      final clear = tester.getCenter(find.byTooltip('Borrar la búsqueda'));

      for (final y in [settings.dy, magnifier.dy, text.center.dy, clear.dy]) {
        expect(y, moreOrLessEquals(folders.dy, epsilon: 0.5));
      }
      expect(magnifier.dx, lessThan(text.left));
      expect(clear.dx, greaterThan(text.right));
      expect(clear.dx, lessThan(settings.dx));
      expect(
        tester.widget<TextField>(searchField()).textAlign,
        TextAlign.start,
      );
    });

    testWidgets('mientras se graba no se abre el menú de carpetas', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(record());
      await pumpAnimations(tester);

      final button = tester.widget<IconButton>(
        find.byKey(const Key('folders-button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('busca en los nombres y las transcripciones de todas las '
        'carpetas', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Reunión del lunes'),
        withTranscript(
          'b',
          'Tema 1',
          'Hoy vemos la reunión de Yalta y sus consecuencias.',
          folder: 'Clases',
        ),
        sample('c', 'Idea para el viaje'),
      ]);
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      // El campo ocupa la barra: sin la lupa ni el título.
      expect(searchField(), findsOneWidget);
      expect(searchFocused(tester), isTrue);
      expect(find.byKey(const Key('search-button')), findsNothing);

      await tester.enterText(searchField(), 'reunion');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      // También la de otra carpeta, por su transcripción y con su carpeta.
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(find.textContaining('Clases · '), findsOneWidget);
      expect(find.byKey(const ValueKey('c')), findsNothing);

      await tester.enterText(searchField(), 'mañana');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(
        find.text(
          'Ninguna grabación tiene «mañana» en el nombre ni en la '
          'transcripción.',
        ),
        findsOneWidget,
      );

      // La X borra la búsqueda y la cierra.
      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(searchField(), findsNothing);
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsNothing);
    });

    testWidgets('la transcripción se ve al escucharla o si tiene lo buscado', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        withTranscript('a', 'Entrevista', 'Buenos días a todos.'),
      ]);
      await pumpApp(tester);
      Finder transcript() => find.byKey(const Key('transcript-a'));
      expect(transcript(), findsNothing);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      // Solo en el nombre: no.
      await tester.enterText(searchField(), 'entrevista');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(transcript(), findsNothing);
      await tester.enterText(searchField(), 'buenos');
      await tester.pumpAndSettle();
      expect(transcript(), findsOneWidget);

      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(transcript(), findsNothing);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(transcript(), findsOneWidget);
    });

    testWidgets('encuentra palabras parecidas, después de las exactas', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        withTranscript('a', 'Clase', 'Hoy repasamos el presupuesto.'),
        withTranscript('b', 'Notas', 'El presupusto no cuadra.'),
        sample('c', 'Idea para el viaje'),
      ]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      await tester.enterText(searchField(), 'presupusto');
      await tester.pumpAndSettle();
      // Primero la que lo tiene tal cual, después la parecida.
      final exact = tester.getTopLeft(find.byKey(const ValueKey('b'))).dy;
      final similar = tester.getTopLeft(find.byKey(const ValueKey('a'))).dy;
      expect(exact, lessThan(similar));
      expect(find.byKey(const ValueKey('c')), findsNothing);
      // La parecida, resaltada.
      final snippet = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transcript-a')),
          matching: find.byType(Text),
        ),
      );
      final highlighted = [
        for (final span in (snippet.textSpan! as TextSpan).children!)
          if (span.style?.fontWeight == FontWeight.bold)
            (span as TextSpan).text,
      ];
      expect(highlighted, ['presupuesto']);
    });

    testWidgets('sin palabras parecidas, solo las exactas', (tester) async {
      store.settings = store.settings.withSearchSimilarWords(false);
      repository = InMemoryRecordingsRepository([
        withTranscript('a', 'Clase', 'Hoy repasamos el presupuesto.'),
        withTranscript('b', 'Notas', 'El presupusto no cuadra.'),
      ]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'presupusto');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('tocar el fondo de la lista quita el foco del campo', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      Future<void> tapBackground() async {
        await tester.tapAt(
          tester.getBottomLeft(find.byType(ListView)) + const Offset(400, -10),
        );
        await tester.pumpAndSettle();
      }

      // Sin nada escrito, se cierra.
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tapBackground();
      expect(searchField(), findsNothing);

      // Con algo escrito, se queda, sin foco ni teclado.
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'entre');
      await tester.pumpAndSettle();
      await tapBackground();
      expect(searchField(), findsOneWidget);
      expect(searchFocused(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('tocar el fondo deselecciona la grabación, salvo si suena', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        withTranscript('a', 'Entrevista', 'Buenos días a todos.'),
      ]);
      await pumpApp(tester);
      final background =
          tester.getBottomLeft(find.byType(ListView)) + const Offset(400, -10);
      Finder transcript() => find.byKey(const Key('transcript-a'));

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(transcript(), findsOneWidget);

      // Sonando, sigue sonando.
      await tester.tapAt(background);
      await tester.pumpAndSettle();
      expect(transcript(), findsOneWidget);
      expect(player.calls.last, isNot('stop'));

      // Un toque en un hueco de la tarjeta no la deselecciona.
      await tester.tap(find.byTooltip('Pausar'));
      await tester.pumpAndSettle();
      await tester.tapAt(
        Offset(
          tester.getTopLeft(find.byKey(const ValueKey('a'))).dx + 24,
          tester.getCenter(find.byKey(const Key('waveform-a'))).dy,
        ),
      );
      await tester.pumpAndSettle();
      expect(transcript(), findsOneWidget);

      // En pausa, se deselecciona.
      await tester.tapAt(background);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'stop');
      expect(transcript(), findsNothing);
    });

    testWidgets('el extracto de la transcripción muestra la coincidencia', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        withTranscript(
          'a',
          'Clase',
          'Empezamos repasando lo de la semana pasada, que fue bastante '
              'largo, y luego hablamos del examen final.',
        ),
      ]);
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'examen');
      await tester.pumpAndSettle();

      final snippet = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transcript-a')),
          matching: find.byType(Text),
        ),
      );
      expect(snippet.textSpan!.toPlainText(), startsWith('…'));
      expect(snippet.textSpan!.toPlainText(), contains('examen final'));
    });

    testWidgets('sin nada escrito, se cierra al perder el foco', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(searchField(), findsNothing);
      expect(find.byKey(const Key('search-button')), findsOneWidget);
    });

    testWidgets('«atrás» quita el foco de la búsqueda y después la cierra', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'nada');
      await tester.pumpAndSettle();

      // Primero quita el foco del campo (con algo escrito, sigue abierto).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(searchField(), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(searchField(), findsNothing);
      expect(find.text('Entrevista'), findsOneWidget);
    });

    testWidgets('tirar de la lista hacia abajo abre la búsqueda', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(searchField(), findsOneWidget);
      expect(searchFocused(tester), isTrue);
    });

    testWidgets('también sin grabaciones', (tester) async {
      await pumpApp(tester);

      await tester.drag(
        find.text('Aún no hay grabaciones'),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(searchField(), findsOneWidget);
    });

    testWidgets('un tirón corto no la abre', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.byType(ListView), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(searchField(), findsNothing);
    });

    testWidgets('al tirar aparece un fondo tras la lupa y un texto; al '
        'pasar el punto, el fondo se pone morado y vibra; se busca al '
        'soltar, y volviendo atrás se cancela', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpApp(tester);
      final colors = Theme.of(tester.element(find.byType(ListView)))
          .colorScheme;
      final background = find.byKey(const Key('pull-to-search'));
      final hint = find.byKey(const Key('pull-to-search-hint'));
      Color? color() =>
          (tester.widget<AnimatedContainer>(background).decoration!
                  as BoxDecoration)
              .color;
      String hintText() => tester.widget<Text>(hint).data!;
      final button = find.byKey(const Key('search-button'));
      final atRest = tester.getCenter(button);
      final barBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(background, findsNothing);
      expect(hint, findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      // Se tira poco a poco hasta pasar el punto.
      while (haptics.isEmpty) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
        // La lupa no se mueve; el fondo, gris claro, aparece detrás.
        expect(tester.getCenter(button), atRest);
        if (background.evaluate().isNotEmpty && haptics.isEmpty) {
          expect(tester.getCenter(background), atRest);
          expect(color(), colors.surfaceContainerHighest);
          // El texto, entre la barra y la primera grabación.
          expect(hintText(), 'Tira para buscar');
          final text = tester.getRect(find.text('Tira para buscar'));
          final visible = tester.getRect(
            find.ancestor(of: hint, matching: find.byType(ClipRect)).first,
          );
          expect(visible.top, greaterThanOrEqualTo(barBottom - 1e-6));
          expect(
            visible.bottom,
            lessThanOrEqualTo(
              tester.getTopLeft(find.byKey(const ValueKey('a'))).dy + 1e-6,
            ),
          );
          expect(text.center.dx, atRest.dx);
        }
      }
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(color(), colors.primary);
      expect(hintText(), 'Suelta para buscar');
      // Hasta soltar, no se busca.
      expect(searchField(), findsNothing);

      // Volviendo a subir antes del punto se cancela.
      while (color() == colors.primary) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump();
      }
      expect(color(), colors.surfaceContainerHighest);
      expect(hintText(), 'Tira para buscar');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(searchField(), findsNothing);
      expect(background, findsNothing);
      expect(hint, findsNothing);

      // Pasándolo y soltando, sí.
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(searchField(), findsOneWidget);
      expect(haptics, hasLength(2));
    });

    testWidgets('con la búsqueda ya enfocada, tirar vuelve a mostrar el '
        'teclado', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      // Se oculta el teclado (p. ej. con «atrás» en Android) sin perder el
      // foco.
      tester.testTextInput.hide();
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(searchFocused(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  group('carpetas', () {
    Future<void> openDrawer(WidgetTester tester) async {
      // Deslizando desde el borde izquierdo.
      await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
    }

    /// Título de la barra superior: la subcarpeta abierta o, en la
    /// principal, nada.
    String title(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
      );
      return texts.isEmpty ? '' : texts.single.data!;
    }

    testWidgets('el menú lateral muestra las subcarpetas y abre una', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'En la principal'),
        sample('b', 'Tema 1', folder: 'Clases'),
      ]);
      store.settings = const AppSettings(
        folder: testFolder,
        folders: ['Ideas'],
      );
      await pumpApp(tester);
      expect(title(tester), '');
      expect(find.text('Tema 1'), findsNothing);

      await openDrawer(tester);
      expect(find.text('Grabaciones'), findsOneWidget);
      expect(find.text('Clases'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);

      await tester.tap(find.text('Clases'));
      await tester.pumpAndSettle();

      // Su nombre arriba a la izquierda y solo sus grabaciones.
      expect(title(tester), 'Clases');
      expect(find.text('Tema 1'), findsOneWidget);
      expect(find.text('En la principal'), findsNothing);
      expect(store.settings.openFolder, 'Clases');
    });

    testWidgets('graba en la carpeta abierta', (tester) async {
      store.settings = const AppSettings(
        folder: testFolder,
        openFolder: 'Clases',
        transcription: manual,
      );
      await pumpApp(tester);
      expect(title(tester), 'Clases');
      expect(find.text('Esta carpeta está vacía'), findsOneWidget);

      await tester.tap(record());
      await pumpAnimations(tester);
      await tester.tap(record());
      await tester.pumpAndSettle();

      expect(repository.recordings.single.folder, 'Clases');
      expect(find.text('2026-10-05 14.32'), findsOneWidget);
    });

    testWidgets('el menú lateral se abre deslizando en la lista', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      expect(find.byKey(const Key('new-folder')), findsNothing);

      // Desde el centro de la tarjeta, no desde el borde.
      await tester.drag(find.text('Entrevista'), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new-folder')), findsOneWidget);
    });

    testWidgets('deslizar hacia la izquierda no abre el menú, sino el piano', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.drag(
        find.text('Aún no hay grabaciones'),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new-folder')), findsNothing);
      expect(find.byKey(const Key('piano-keyboard')), findsOneWidget);
    });

    testWidgets('crea una carpeta y la abre', (tester) async {
      await pumpApp(tester);
      await openDrawer(tester);

      await tester.tap(find.byKey(const Key('new-folder')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Reuniones ');
      await tester.pump();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(title(tester), 'Reuniones');
      expect(store.settings.folders, ['Reuniones']);
      expect(find.text('Esta carpeta está vacía'), findsOneWidget);
    });

    testWidgets('«atrás» en una subcarpeta vuelve a la principal', (
      tester,
    ) async {
      store.settings = const AppSettings(
        folder: testFolder,
        openFolder: 'Clases',
      );
      await pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(title(tester), '');
      expect(store.settings.openFolder, '');
    });

    testWidgets('«atrás» quita la selección de la grabación, después abre el '
        'menú de las carpetas y con él abierto sale de la app', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(player.calls.last, 'stop');
      expect(find.byKey(const Key('new-folder')), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-folder')), findsOneWidget);
      expect(calls, isNot(contains('SystemNavigator.pop')));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
    });

    testWidgets('muestra las grabaciones que había en la carpeta', (
      tester,
    ) async {
      const music = FolderSettings(id: 'tree://music', name: 'Music');
      store.settings = const AppSettings(folder: music);
      folders.addFile(music.id, 'Idea.m4a');
      folders.addFile(music.id, 'Tema 1.m4a', subfolder: 'Clases');
      await pumpApp(tester);

      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('Hay 2 grabaciones nuevas'), findsOneWidget);

      await openDrawer(tester);
      // La principal lleva el nombre de la carpeta del dispositivo.
      expect(find.text('Music'), findsOneWidget);
      await tester.tap(find.text('Clases'));
      await tester.pumpAndSettle();
      expect(find.text('Tema 1'), findsOneWidget);
    });
  });

  testWidgets('usa el tema elegido en las opciones', (tester) async {
    ThemeMode themeMode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    store.settings = const AppSettings(
      folder: testFolder,
      theme: AppTheme.dark,
    );
    await pumpApp(tester);
    expect(themeMode(), ThemeMode.dark);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    final option = find.byKey(const Key('theme-option'));
    await tester.scrollUntilVisible(option, 200);
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(themeMode(), ThemeMode.light);
    expect(Theme.of(tester.element(option)).brightness, Brightness.light);
  });

  testWidgets('abre las opciones desde la barra superior', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Opciones'), findsOneWidget);
    expect(find.text('Formato'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Carpeta del dispositivo'), 200);
    expect(find.text('Carpeta del dispositivo'), findsOneWidget);
  });

  group('piano', () {
    Finder keyboard() => find.byKey(const Key('piano-keyboard'));
    Finder overview() => find.byKey(const Key('piano-overview'));

    /// Centro de la tecla blanca [index] (desde la izquierda) del teclado.
    Offset whiteKey(WidgetTester tester, int index) {
      final rect = tester.getRect(keyboard());
      final width = rect.width / PianoPanel.visibleWhiteKeys;
      // Abajo, donde no hay negras.
      return Offset(rect.left + (index + 0.5) * width, rect.bottom - 20);
    }

    testWidgets('se abre con su botón y suena al tocar las teclas', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('piano-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Toca una tecla para oír su nota.\n'
          'Desliza sobre el teclado pequeño para moverte por él.',
        ),
        findsOneWidget,
      );
      // Desde el Do3, con las teclas a la vista preparadas.
      expect(piano.prepared, containsAll([48, 49, 65]));

      await tester.tapAt(whiteKey(tester, 0));
      await tester.pump();
      expect(piano.played, [48]);
      expect(find.text('Do3'), findsWidgets);
      expect(find.text('130.8 Hz'), findsOneWidget);

      // Una negra: arriba, entre el Do y el Re.
      final rect = tester.getRect(keyboard());
      final width = rect.width / PianoPanel.visibleWhiteKeys;
      await tester.tapAt(Offset(rect.left + width, rect.top + 20));
      await tester.pump();
      expect(piano.played.last, 49);
      expect(find.byKey(const Key('piano-note')), findsOneWidget);
      expect(find.text('Do♯3'), findsOneWidget);
    });

    testWidgets('deslizando el dedo por las teclas suenan todas y no se '
        'cierra', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('piano-button')));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(whiteKey(tester, 4));
      for (var i = 3; i >= 0; i--) {
        await gesture.moveTo(whiteKey(tester, i));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Sol3, Fa3, Mi3, Re3, Do3.
      expect(piano.played, [55, 53, 52, 50, 48]);
      expect(keyboard(), findsOneWidget);
    });

    testWidgets('deslizando sobre las octavas cambia la parte ampliada, y se '
        'conserva al cerrarlo', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('piano-button')));
      await tester.pumpAndSettle();

      // Hasta el final de la derecha: las 11 blancas más agudas.
      final strip = tester.getRect(overview());
      await tester.dragFrom(strip.center, Offset(strip.width, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(whiteKey(tester, PianoPanel.visibleWhiteKeys - 1));
      await tester.pump();
      expect(piano.played, [108]);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(keyboard(), findsNothing);

      await tester.tap(find.byKey(const Key('piano-button')));
      await tester.pumpAndSettle();
      await tester.tapAt(whiteKey(tester, PianoPanel.visibleWhiteKeys - 1));
      await tester.pump();
      expect(piano.played, [108, 108]);
    });

    testWidgets('se ve en horizontal: gira la pantalla al abrirlo y la '
        'deja como diga el sistema al cerrarlo', (tester) async {
      final orientations = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.text('Entrevista'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      expect(orientations, [
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      ]);

      // «Atrás» vuelve a la vista principal.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(keyboard(), findsNothing);
      expect(find.text('Entrevista'), findsOneWidget);
      expect(orientations.last, isEmpty);
    });

    testWidgets('mientras se graba no se abre', (tester) async {
      await pumpApp(tester);
      await tester.tap(record());
      await pumpAnimations(tester);

      final button = tester.widget<IconButton>(
        find.byKey(const Key('piano-button')),
      );
      expect(button.onPressed, isNull);
    });
  });
}
