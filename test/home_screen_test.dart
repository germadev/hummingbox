import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:voicerecorder/app.dart';
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/widgets/record_panel.dart';

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

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() {
    repository = InMemoryRecordingsRepository();
    recorder = FakeAudioRecorderService();
    player = FakeAudioPlayerService();
    store = InMemorySettingsStore(const AppSettings(folder: testFolder));
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    screen = FakeScreenAwake();
  });

  Recording sample(
    String id,
    String name, {
    List<double>? waveform,
    String folder = '',
  }) => Recording(
    id: id,
    path: '/fake/$id.m4a',
    name: name,
    createdAt: DateTime(2026, 9, 28, 8, 30),
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
    expect(find.text('Grabación 1'), findsOneWidget);
    expect(find.text('Guardada como «Grabación 1»'), findsOneWidget);
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

  group('menú inicial', () {
    setUp(() => store = InMemorySettingsStore());

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
      expect(drive.calls, ['upload Grabación 1.m4a']);
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
      expect(find.text('Grabación 1'), findsOneWidget);
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

      expect(find.text('Grabación 1'), findsOneWidget);
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

  group('carpetas', () {
    Future<void> openDrawer(WidgetTester tester) async {
      // Deslizando desde el borde izquierdo.
      await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
    }

    String title(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
        )
        .data!;

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
      expect(title(tester), 'Grabadora');
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
      );
      await pumpApp(tester);
      expect(title(tester), 'Clases');
      expect(find.text('Esta carpeta está vacía'), findsOneWidget);

      await tester.tap(record());
      await pumpAnimations(tester);
      await tester.tap(record());
      await tester.pumpAndSettle();

      expect(repository.recordings.single.folder, 'Clases');
      expect(find.text('Grabación 1'), findsOneWidget);
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

    testWidgets('deslizar hacia la izquierda no abre el menú', (tester) async {
      await pumpApp(tester);

      await tester.drag(
        find.text('Aún no hay grabaciones'),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new-folder')), findsNothing);
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

      expect(title(tester), 'Grabadora');
      expect(store.settings.openFolder, '');
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

  testWidgets('abre las opciones desde la barra superior', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Opciones'), findsOneWidget);
    expect(find.text('Formato'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Carpeta del dispositivo'), 200);
    expect(find.text('Carpeta del dispositivo'), findsOneWidget);
  });
}
