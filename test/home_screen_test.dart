import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:voicerecorder/app.dart';
import 'package:voicerecorder/audio/piano_tone.dart';
import 'package:voicerecorder/controllers/piano_recorder.dart';
import 'package:voicerecorder/audio/audio_info.dart';
import 'package:voicerecorder/models/instrument.dart';
import 'package:voicerecorder/models/piano_note.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/synth_patch.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/services/audio_player_service.dart';
import 'package:voicerecorder/services/transcriber.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/widgets/record_panel.dart';
import 'package:voicerecorder/widgets/recording_tile.dart';
import 'package:voicerecorder/widgets/waveform_seek_bar.dart';
import 'package:voicerecorder/widgets/folder_drawer.dart';
import 'package:voicerecorder/utils/recording_names.dart';
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
    // En la vista detallada, salvo en los tests de la compacta (la de por
    // defecto).
    store = InMemorySettingsStore(
      const AppSettings(
        folder: testFolder,
        transcription: manual,
        compactList: false,
      ),
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

  /// El campo de texto del diálogo abierto (no el de búsqueda de la barra).
  Finder dialogField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  /// Toca la tarjeta de la grabación de [duration] fuera del nombre, del
  /// botón y de la onda.
  Future<void> tapCard(WidgetTester tester, String duration) async {
    await tester.tap(find.textContaining(duration));
    await tester.pumpAndSettle();
  }

  /// El botón con [tooltip] de la tarjeta de la grabación [id] (no el del
  /// panel de abajo).
  Finder tileButton(String id, String tooltip) => find.descendant(
    of: find.ancestor(
      of: find.byKey(Key('name-$id')),
      matching: find.byType(RecordingTile),
    ),
    matching: find.byTooltip(tooltip),
  );

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
    expect(find.text('14.32'), findsOneWidget);
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
    expect(tileButton('a', 'Reproducir'), findsOneWidget);
  });

  testWidgets('mientras suena, una línea fina marca por dónde va', (
    tester,
  ) async {
    repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
    await pumpApp(tester);
    PlayheadPainter? playhead() =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const Key('waveform-a')),
                    matching: find.byKey(const Key('playhead')),
                  ),
                )
                .foregroundPainter
            as PlayheadPainter?;
    expect(playhead(), isNull);

    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pumpAndSettle();
    expect(playhead()?.progress, 0);

    // Tocando la onda en la mitad y en un cuarto, la línea va con ella.
    final box = tester.getRect(find.byKey(const Key('waveform-a')));
    await tester.tapAt(Offset(box.left + box.width / 2, box.top + 10));
    await tester.pumpAndSettle();
    expect(playhead()?.progress, closeTo(0.5, 0.01));
    await tester.tapAt(Offset(box.left + box.width / 4, box.top + 10));
    await tester.pumpAndSettle();
    expect(playhead()?.progress, closeTo(0.25, 0.01));
  });

  testWidgets('en la vista compacta, las grabaciones con notas del piano '
      'llevan un piano a la izquierda del botón de reproducir', (tester) async {
    store.settings = const AppSettings(
      folder: testFolder,
      compactList: true,
      transcription: manual,
    );
    repository = InMemoryRecordingsRepository([
      sample('a', 'Solo voz'),
      sample('b', 'Con piano').copyWith(
        notes: const [
          PianoNote(
            key: 60,
            start: Duration.zero,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    ]);
    await pumpApp(tester);

    Finder pianoIn(String id) => find.descendant(
      of: find.byKey(Key('notes-icon-$id')),
      matching: find.byIcon(Icons.piano),
    );
    expect(pianoIn('b'), findsOneWidget);
    expect(pianoIn('a'), findsNothing);
    final play = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('notes-icon-b')),
        matching: find.byTooltip('Reproducir'),
      ),
    );
    final icon = tester.getRect(pianoIn('b'));
    expect(icon.center.dx, lessThan(play.center.dx));
    expect(icon.center.dy, moreOrLessEquals(play.center.dy, epsilon: 1));

    // En la detallada se ven las notas: sin el piano.
    await tester.tap(find.byKey(const Key('view-mode-button')));
    await tester.pumpAndSettle();
    expect(pianoIn('b'), findsNothing);
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

    await tester.enterText(dialogField(), 'Clase de historia');
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

    await tester.enterText(dialogField(), 'Idea');
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
    await tester.enterText(dialogField(), '   ');
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

      expect(find.text('14.32').hitTestable(), findsOneWidget);
      expect(find.text('Toma 0').hitTestable(), findsNothing);
    });
  });

  testWidgets('la grabación nueva sale seleccionada, sin sonar, y el aviso '
      'no la tapa', (tester) async {
    repository = InMemoryRecordingsRepository([
      for (var i = 0; i < 20; i++)
        sample('r$i', 'Toma $i', createdAt: DateTime(2020, 1, 1 + i)),
    ]);
    await pumpApp(tester);

    await tester.tap(record());
    await pumpAnimations(tester);
    await tester.tap(record());
    await tester.pumpAndSettle();

    final saved = repository.recordings.last;
    final tile = find.byKey(ValueKey(saved.id));
    final snackBar = find.byType(SnackBar);
    expect(snackBar, findsOneWidget);
    expect(
      tester.getRect(tile).bottom,
      lessThanOrEqualTo(tester.getRect(snackBar).top),
    );
    // Seleccionada (como al escucharla), pero sin sonar.
    final card = tester.widget<Card>(
      find.descendant(of: tile, matching: find.byType(Card)),
    );
    final colors = Theme.of(tester.element(tile)).colorScheme;
    expect(card.color, colors.secondaryContainer);
    expect(player.calls.where((c) => c.startsWith('play')), isEmpty);

    // Al tocarla, suena desde el principio.
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Reproducir')),
    );
    await tester.pump();
    expect(player.calls.last, 'play ${saved.path} @0');
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
      expect(find.text('14.32'), findsOneWidget);
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

      expect(find.text('14.32'), findsOneWidget);
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

  group('selección', () {
    testWidgets('tocar una grabación la selecciona sin reproducirla; suena '
        'con su botón, y al seleccionar otra se para', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', waveform: [0.5]),
        Recording(
          id: 'b',
          path: '/fake/b.m4a',
          name: 'Idea',
          createdAt: DateTime(2026, 9, 29),
          duration: const Duration(seconds: 12),
          waveform: const [0.5],
        ),
      ]);
      await pumpApp(tester);

      await tapCard(tester, '01:23');
      expect(player.calls, isEmpty);
      // Seleccionada: con sus tiempos.
      expect(find.text('00:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Reproducir').first);
      await tester.pumpAndSettle();
      expect(player.calls, ['play /fake/a.m4a @0']);

      await tapCard(tester, '00:12');
      expect(player.calls, ['play /fake/a.m4a @0', 'stop']);
      expect(find.byTooltip('Pausar'), findsNothing);
    });

    testWidgets('con una seleccionada, el panel desplegado muestra sus '
        'acciones en lugar de lo de grabar', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', waveform: [0.5]),
      ]);
      await pumpApp(tester);
      await tapCard(tester, '01:23');

      await tester.drag(
        find.byKey(const Key('panel-handle')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lista para grabar'), findsNothing);
      expect(find.byKey(const Key('countdown-button')), findsNothing);
      expect(find.byKey(const Key('voice-button')), findsNothing);
      for (final action in [
        'edit',
        'addPiano',
        'rename',
        'transcribe',
        'transcribeInLanguage',
        'share',
        'delete',
      ]) {
        expect(find.byKey(Key('action-$action')), findsOneWidget);
      }
      // Solo el icono, con su nombre como ayuda.
      expect(find.byTooltip('Renombrar'), findsWidgets);

      await tester.tap(find.byKey(const Key('action-rename')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Sin selección, lo de grabar.
      await tester.tap(find.byKey(const Key('list-background')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-rename')), findsNothing);
      expect(find.text('Lista para grabar'), findsOneWidget);
      expect(find.byKey(const Key('countdown-button')), findsOneWidget);
    });

    testWidgets('sin audio que se oiga, no se dibuja la onda', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', waveform: [0.5, 0.2]),
        Recording(
          id: 'b',
          path: '/fake/b.m4a',
          name: 'Silencio',
          createdAt: DateTime(2026, 9, 29),
          duration: const Duration(seconds: 12),
          waveform: const [0.02, 0.05, 0.1],
        ),
      ]);
      await pumpApp(tester);

      CustomPainter? painterOf(String id) => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(Key('waveform-$id')),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((paint) => paint.painter)
          .nonNulls
          .firstOrNull;

      expect(painterOf('a'), isA<SeekWaveformPainter>());
      // Sin onda ni notas, no ocupa sitio hasta seleccionarla.
      expect(find.byKey(const Key('waveform-b')), findsNothing);
      await tapCard(tester, '00:12');
      expect(find.byKey(const Key('waveform-b')), findsOneWidget);
      expect(painterOf('b'), isNull);
    });
  });

  group('onda de las grabaciones', () {
    testWidgets('tocar la onda la selecciona en ese punto, sin reproducirla; '
        'el botón la reproduce desde ahí, y luego salta', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', waveform: [0.2, 0.8, 0.4]),
      ]);
      await pumpApp(tester);
      final waveform = find.byKey(const Key('waveform-a'));
      expect(waveform, findsOneWidget);

      await tester.tap(waveform);
      await tester.pumpAndSettle();
      expect(player.calls, isEmpty);
      expect(find.text('00:41'), findsOneWidget);
      expect(find.text('01:23'), findsOneWidget);

      // El de la tarjeta (el otro está en el panel de abajo).
      await tester.tap(tileButton('a', 'Reproducir'));
      await tester.pumpAndSettle();
      expect(player.calls, ['play /fake/a.m4a @41500']);

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

    /// Si no se está buscando: el campo, sin foco ni nada escrito, y a su
    /// derecha los botones.
    void expectNotSearching(WidgetTester tester) {
      expect(searchField(), findsOneWidget);
      expect(searchFocused(tester), isFalse);
      expect(tester.widget<TextField>(searchField()).controller!.text, '');
      expect(find.byKey(const Key('view-mode-button')), findsOneWidget);
    }

    testWidgets('el botón de carpetas abre el menú y no hay título', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('HummingBox'), findsNothing);

      await tester.tap(find.byTooltip('Carpetas'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('new-folder')), findsOneWidget);
    });

    testWidgets('el campo de búsqueda está siempre a la vista, con «Buscar», '
        'la lupa a la izquierda, junto a las carpetas, y en una subcarpeta su '
        'nombre a la derecha', (tester) async {
      store.settings = const AppSettings(
        folder: testFolder,
        openFolder: 'Clases',
        transcription: manual,
      );
      await pumpApp(tester);
      expectNotSearching(tester);
      expect(
        tester.widget<TextField>(searchField()).decoration!.hintText,
        'Buscar',
      );
      final folders = tester.getRect(find.byKey(const Key('folders-button')));
      final search = tester.getCenter(find.byKey(const Key('search-icon')));
      final text = tester.getRect(find.byType(EditableText));
      final title = tester.getRect(find.byKey(const Key('folder-title')));
      final view = tester.getRect(find.byKey(const Key('view-mode-button')));

      expect(search.dx, greaterThan(folders.right));
      expect(search.dx, lessThan(text.left));
      expect(title.left, greaterThanOrEqualTo(text.right));
      expect(title.right, lessThanOrEqualTo(view.left));
      expect(search.dy, moreOrLessEquals(folders.center.dy, epsilon: 0.5));
      expect(title.center.dy, moreOrLessEquals(folders.center.dy, epsilon: 1));
      // Sin la búsqueda abierta, no hay teclado.
      expect(tester.testTextInput.isVisible, isFalse);

      // Al tocarlo se busca: la lupa sigue en su sitio y, en lugar del
      // nombre de la carpeta, la X.
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(searchFocused(tester), isTrue);
      expect(tester.getCenter(find.byKey(const Key('search-icon'))), search);
      expect(find.byKey(const Key('folder-title')), findsNothing);
      expect(find.byTooltip('Borrar la búsqueda'), findsOneWidget);
    });

    testWidgets('el campo tiene la lupa a la izquierda y la X a la derecha, '
        'alineados con los botones', (tester) async {
      await pumpApp(tester);
      await tester.tap(searchField());
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

    testWidgets('al seleccionar una grabación cortada por abajo, la lista se '
        'desplaza para que se vea entera', (tester) async {
      repository = InMemoryRecordingsRepository([
        for (var i = 0; i < 20; i++)
          sample(
            '$i',
            'Grabación $i',
            createdAt: DateTime(2026, 9, 1).add(Duration(days: i)),
          ),
      ]);
      await pumpApp(tester);
      final list = tester.getRect(find.byType(ListView));
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      Rect tile() => tester.getRect(find.byKey(const ValueKey('2')));
      // Cuando ha terminado de bajar hasta el final, arriba del todo: la
      // tercera asoma por abajo.
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }
      position.jumpTo(0);
      await tester.pump();
      expect(tile().bottom, greaterThan(list.bottom));

      await tester.tap(tileButton('2', 'Reproducir'));
      // Al crecer con la onda, y cuando acaba de crecer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('waveform-2')), findsOneWidget);
      // Con el panel de abajo, que con una seleccionada puede crecer.
      final visible = tester.getRect(find.byType(ListView));
      expect(tile().bottom, lessThanOrEqualTo(visible.bottom + 0.5));
      expect(tile().top, greaterThanOrEqualTo(visible.top));

      // Si ya se ve entera, la lista no se mueve.
      final before = position.pixels;
      await tester.tap(tileButton('2', 'Pausar'));
      await tester.pumpAndSettle();
      await tester.tap(tileButton('1', 'Reproducir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(position.pixels, before);
    });

    testWidgets('la vista es compacta por defecto; el botón de la vista, a '
        'la izquierda de las opciones, cambia a la detallada y vuelve, y se '
        'recuerda', (tester) async {
      store.settings = const AppSettings(folder: testFolder);
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      final view = find.byKey(const Key('view-mode-button'));
      final settings = tester.getRect(find.byKey(const Key('settings-button')));
      expect(tester.getRect(view).right, settings.left);
      // Compacta: sin el formato ni la onda.
      expect(find.byKey(const Key('audio-info-a')), findsNothing);
      expect(find.byKey(const Key('waveform-a')), findsNothing);
      expect(find.byTooltip('Vista detallada'), findsOneWidget);

      await tester.tap(find.byTooltip('Vista detallada'));
      await tester.pumpAndSettle();

      expect(store.settings.compactList, isFalse);
      expect(find.byKey(const Key('audio-info-a')), findsOneWidget);
      expect(find.byKey(const Key('waveform-a')), findsOneWidget);

      await tester.tap(find.byTooltip('Vista compacta'));
      await tester.pumpAndSettle();

      expect(store.settings.compactList, isTrue);
      expect(find.byKey(const Key('audio-info-a')), findsNothing);
      expect(find.byKey(const Key('waveform-a')), findsNothing);

      // La seleccionada sí tiene la onda, para saltar.
      await tester.tap(tileButton('a', 'Reproducir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('waveform-a')), findsOneWidget);

      // Al buscar, en su sitio está la X del campo.
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(view, findsNothing);
      final clear = tester.getCenter(find.byTooltip('Borrar la búsqueda'));
      expect(clear.dx, lessThan(settings.left));
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

      await tester.tap(searchField());
      await tester.pumpAndSettle();
      // El campo ocupa la barra hasta las opciones.
      expect(searchFocused(tester), isTrue);
      expect(find.byKey(const Key('view-mode-button')), findsNothing);

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

      // La X borra la búsqueda y quita el foco.
      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expectNotSearching(tester);
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

      await tester.tap(searchField());
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
      await tester.tap(searchField());
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
      await tester.tap(searchField());
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

      // Sin nada escrito, vuelven los botones.
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tapBackground();
      expectNotSearching(tester);

      // Con algo escrito, se queda, sin foco ni teclado.
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'entre');
      await tester.pumpAndSettle();
      await tapBackground();
      expect(tester.widget<TextField>(searchField()).controller!.text, 'entre');
      expect(searchFocused(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets(
      'tocar el dock quita el foco del campo y, fuera de los botones, '
      'la selección',
      (tester) async {
        repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
        await pumpApp(tester);
        await tester.tap(searchField());
        await tester.pumpAndSettle();
        await tester.enterText(searchField(), 'entre');
        await tester.pumpAndSettle();
        expect(searchFocused(tester), isTrue);

        // Una zona vacía del dock, a la izquierda.
        final dock = tester.getRect(find.byType(RecordPanel));
        final empty = Offset(dock.left + 10, dock.center.dy);
        await tester.tapAt(empty);
        await tester.pumpAndSettle();
        expect(searchFocused(tester), isFalse);
        expect(searchField(), findsOneWidget);

        // Con una grabación en pausa, también se deselecciona.
        await tester.tap(find.byTooltip('Reproducir'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Pausar'));
        await tester.pumpAndSettle();
        await tester.tapAt(empty);
        await tester.pumpAndSettle();
        expect(player.calls.last, 'stop');
      },
    );

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

      await tester.tap(searchField());
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

    testWidgets('sin nada escrito, al perder el foco vuelven los botones', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('view-mode-button')), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expectNotSearching(tester);
    });

    testWidgets('«atrás» quita el foco de la búsqueda y después la borra', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(searchField());
      await tester.pumpAndSettle();
      await tester.enterText(searchField(), 'nada');
      await tester.pumpAndSettle();

      // Primero quita el foco del campo (con algo escrito, sigue abierto).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(searchField()).controller!.text, 'nada');
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expectNotSearching(tester);
      expect(find.text('Entrevista'), findsOneWidget);
    });

    testWidgets('tirar de la lista hacia abajo da el foco a la búsqueda', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(searchFocused(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('también sin grabaciones', (tester) async {
      await pumpApp(tester);

      await tester.drag(
        find.text('Aún no hay grabaciones'),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(searchFocused(tester), isTrue);
    });

    testWidgets('solo si se empieza a tirar con la lista arriba del todo', (
      tester,
    ) async {
      repository = InMemoryRecordingsRepository([
        for (var i = 0; i < 20; i++)
          sample(
            '$i',
            'Grabación $i',
            createdAt: DateTime(2026, 9, 1).add(Duration(days: i)),
          ),
      ]);
      await pumpApp(tester);
      // Empieza abajo del todo: subiendo y tirando con el mismo arrastre,
      // no se busca.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      for (var i = 0; i < 100; i++) {
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
      }
      expect(scrollable.position.pixels, lessThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(searchFocused(tester), isFalse);

      // Ya arriba, sí.
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(searchFocused(tester), isTrue);
    });

    testWidgets('un tirón corto no la abre', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.byType(ListView), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(searchFocused(tester), isFalse);
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
      final button = find.byKey(const Key('search-icon'));
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
          expect(text.center.dx, tester.getSize(find.byType(AppBar)).width / 2);
        }
      }
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(color(), colors.primary);
      expect(hintText(), 'Suelta para buscar');
      // Hasta soltar, no se busca.
      expect(searchFocused(tester), isFalse);

      // Volviendo a subir antes del punto se cancela.
      while (color() == colors.primary) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump();
      }
      expect(color(), colors.surfaceContainerHighest);
      expect(hintText(), 'Tira para buscar');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(searchFocused(tester), isFalse);
      expect(background, findsNothing);
      expect(hint, findsNothing);

      // Pasándolo y soltando, sí, y la lupa pasa directamente a no tener
      // fondo (sin seguir a la lista mientras vuelve a su sitio).
      final again = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await again.moveBy(const Offset(0, 150));
      await tester.pump();
      await again.moveBy(const Offset(0, 150));
      await tester.pump();
      expect(color(), colors.primary);
      await again.up();
      // Desde el primer fotograma tras soltar, y mientras la lista vuelve.
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(background, findsNothing);
        expect(hint, findsNothing);
      }
      await tester.pumpAndSettle();
      expect(searchFocused(tester), isTrue);
      expect(haptics, hasLength(2));
    });

    testWidgets('con la búsqueda ya enfocada, tirar vuelve a mostrar el '
        'teclado', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(searchField());
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
      // Deslizando hacia la derecha en la lista, lejos del borde.
      await tester.dragFrom(const Offset(100, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
    }

    /// Título de la barra superior: la subcarpeta abierta o, en la
    /// principal, nada.
    String title(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.byKey(const Key('folder-title')),
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
      expect(find.text('14.32'), findsOneWidget);
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

    testWidgets('deslizar desde el borde derecho (para ir atrás) no abre el '
        'piano', (tester) async {
      await pumpApp(tester);
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      await tester.dragFrom(Offset(width - 10, 300), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-keyboard')), findsNothing);
      // Ni hacia el otro lado abre las carpetas.
      await tester.dragFrom(Offset(width - 10, 300), const Offset(-30, 0));
      await tester.dragFrom(Offset(width - 40, 300), const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-folder')), findsNothing);

      await tester.dragFrom(Offset(width - 60, 300), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-keyboard')), findsOneWidget);
    });

    testWidgets('deslizar desde el borde izquierdo (para ir atrás) no abre '
        'las carpetas', (tester) async {
      await pumpApp(tester);

      for (final x in [2.0, 10.0, 30.0]) {
        await tester.dragFrom(Offset(x, 300), const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('new-folder')), findsNothing);
      }

      await tester.dragFrom(const Offset(60, 300), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-folder')), findsOneWidget);
    });

    testWidgets('crea una carpeta y la abre', (tester) async {
      await pumpApp(tester);
      await openDrawer(tester);

      await tester.tap(find.byKey(const Key('new-folder')));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), '  Reuniones ');
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

  group('dock mientras se reproduce', () {
    testWidgets('parar en el centro, lista a la izquierda y repetir a la '
        'derecha; con la lista sigue con la de debajo', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Primera', createdAt: DateTime(2026, 9, 1)),
        sample('b', 'Segunda', createdAt: DateTime(2026, 9, 2)),
      ]);
      await pumpApp(tester);
      expect(find.byKey(const Key('stop-playback-button')), findsNothing);

      await tester.tap(find.byTooltip('Reproducir').first);
      await tester.pumpAndSettle();

      expect(record(), findsNothing);
      final stop = tester.getCenter(
        find.byKey(const Key('stop-playback-button')),
      );
      final list = tester.getCenter(find.byKey(const Key('playlist-button')));
      final loop = tester.getCenter(find.byKey(const Key('loop-button')));
      expect(list.dx, lessThan(stop.dx));
      expect(loop.dx, greaterThan(stop.dx));

      await tester.tap(find.byTooltip('Reproducir una detrás de otra'));
      await tester.pump();
      player.statusController.add(PlaybackStatus.completed);
      await tester.pumpAndSettle();
      expect(player.calls.last, 'play /fake/b.m4a @0');

      await tester.tap(find.byKey(const Key('stop-playback-button')));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'stop');
      expect(record(), findsOneWidget);
    });

    testWidgets('con una seleccionada, sin sonar: reproducir en el centro, '
        'con la lista y repetir', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      expect(find.byKey(const Key('play-selected-button')), findsNothing);

      await tapCard(tester, '01:23');
      expect(player.calls, isEmpty);
      expect(record(), findsNothing);
      expect(find.byKey(const Key('stop-playback-button')), findsNothing);
      final play = tester.getCenter(
        find.byKey(const Key('play-selected-button')),
      );
      expect(
        tester.getCenter(find.byKey(const Key('playlist-button'))).dx,
        lessThan(play.dx),
      );
      expect(
        tester.getCenter(find.byKey(const Key('loop-button'))).dx,
        greaterThan(play.dx),
      );

      // Reproduce la seleccionada, y el centro pasa a parar.
      await tester.tap(find.byKey(const Key('play-selected-button')));
      await tester.pumpAndSettle();
      expect(player.calls, ['play /fake/a.m4a @0']);
      expect(find.byKey(const Key('play-selected-button')), findsNothing);
      expect(find.byKey(const Key('stop-playback-button')), findsOneWidget);

      // En pausa, reproducir sigue.
      await tester.tap(tileButton('a', 'Pausar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('play-selected-button')));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'resume');

      // Parar la quita, y vuelve el botón de grabar.
      await tester.tap(find.byKey(const Key('stop-playback-button')));
      await tester.pumpAndSettle();
      expect(record(), findsOneWidget);
      expect(find.byKey(const Key('playlist-button')), findsNothing);
    });

    testWidgets('repetir vuelve a empezar la misma', (tester) async {
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Repetir'));
      await tester.pump();
      final button = tester.widget<IconButton>(
        find.byKey(const Key('loop-button')),
      );
      expect(button.isSelected, isTrue);
      player.statusController.add(PlaybackStatus.completed);
      await tester.pumpAndSettle();

      expect(player.calls.where((c) => c.startsWith('play')), hasLength(2));
    });
  });

  group('piano', () {
    Finder keyboard() => find.byKey(const Key('piano-keyboard'));

    /// Abre el piano con su botón, al pie del menú de las carpetas.
    Future<void> openPiano(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('folders-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('piano-button')));
    }

    Finder overview() => find.byKey(const Key('piano-overview'));

    /// Centro de la tecla blanca [index] (desde la izquierda) del teclado.
    Offset whiteKey(WidgetTester tester, int index) {
      final rect = tester.getRect(keyboard());
      final width = rect.width / PianoPanel.initialKeyCount;
      // Abajo, donde no hay negras.
      return Offset(rect.left + (index + 0.5) * width, rect.bottom - 20);
    }

    testWidgets('se abre con su botón y suena al tocar las teclas', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPiano(tester);
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
      final width = rect.width / PianoPanel.initialKeyCount;
      await tester.tapAt(Offset(rect.left + width, rect.top + 20));
      await tester.pump();
      expect(piano.played.last, 49);
      expect(find.byKey(const Key('piano-note')), findsOneWidget);
      expect(find.text('Do♯3'), findsOneWidget);
    });

    testWidgets('deslizando el dedo por las teclas suenan todas y no se '
        'cierra', (tester) async {
      await pumpApp(tester);
      await openPiano(tester);
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
      await openPiano(tester);
      await tester.pumpAndSettle();

      // Hasta el final de la derecha: las 11 blancas más agudas.
      final strip = tester.getRect(overview());
      await tester.dragFrom(strip.center, Offset(strip.width, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(
        whiteKey(tester, PianoPanel.initialKeyCount.toInt() - 1),
      );
      await tester.pump();
      expect(piano.played, [108]);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(keyboard(), findsNothing);

      await openPiano(tester);
      await tester.pumpAndSettle();
      await tester.tapAt(
        whiteKey(tester, PianoPanel.initialKeyCount.toInt() - 1),
      );
      await tester.pump();
      expect(piano.played, [108, 108]);
    });

    /// Guarda las orientaciones que pide la app.
    List<Object?> watchOrientations(WidgetTester tester) {
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
      return orientations;
    }

    /// El umbral de los arrastres de Android (8 puntos), menor que el de
    /// por defecto en los tests.
    void androidTouchSlop(WidgetTester tester) {
      tester.view.gestureSettings = ui.GestureSettings(
        physicalTouchSlop: 8 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetGestureSettings);
    }

    /// Pantalla de un móvil en vertical.
    void portraitScreen(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('en horizontal se ve sin girar, y la pantalla gira como '
        'siempre', (tester) async {
      final orientations = watchOrientations(tester);
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      await tester.drag(find.text('Entrevista'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      // Sin fijar la orientación de la pantalla.
      expect(orientations, isEmpty);
      // Sin girar.
      expect(
        tester.widget<RotatedBox>(find.byKey(const Key('piano-rotation'))),
        isA<RotatedBox>().having((box) => box.quarterTurns, 'turns', 0),
      );
      expect(find.byKey(const Key('piano-turn')), findsNothing);

      // «Atrás» vuelve a la vista principal.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(keyboard(), findsNothing);
      expect(find.text('Entrevista'), findsOneWidget);
      expect(orientations, isEmpty);
    });

    testWidgets('en vertical se ve girado desde que se desliza, y al girar '
        'la pantalla se ve sin girar', (tester) async {
      portraitScreen(tester);
      final orientations = watchOrientations(tester);
      repository = InMemoryRecordingsRepository([sample('a', 'Entrevista')]);
      await pumpApp(tester);

      // A mitad de deslizar ya se ve girado.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Entrevista')),
      );
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<RotatedBox>(find.byKey(const Key('piano-rotation'))),
        isA<RotatedBox>().having((box) => box.quarterTurns, 'turns', 1),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      // Las teclas, a lo largo de la pantalla: de grave (arriba) a agudo
      // (abajo).
      final rect = tester.getRect(keyboard());
      expect(rect.height, greaterThan(rect.width));
      expect(orientations, isEmpty);
      final height = rect.height / PianoPanel.initialKeyCount;
      await tester.tapAt(Offset(rect.left + 20, rect.top + height / 2));
      await tester.tapAt(Offset(rect.left + 20, rect.bottom - height / 2));
      await tester.pump();
      expect(piano.played, [48, 65]);

      // Se le puede dar la vuelta, y se recuerda.
      await tester.tap(find.byKey(const Key('piano-turn')));
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byKey(const Key('piano-rotation'))),
        isA<RotatedBox>().having((box) => box.quarterTurns, 'turns', 3),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RotatedBox>(find.byKey(const Key('piano-rotation'))),
        isA<RotatedBox>().having((box) => box.quarterTurns, 'turns', 3),
      );

      // Al girar la pantalla, sin girar.
      tester.view.physicalSize = const Size(2340, 1080);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RotatedBox>(find.byKey(const Key('piano-rotation'))),
        isA<RotatedBox>().having((box) => box.quarterTurns, 'turns', 0),
      );
      expect(keyboard(), findsOneWidget);
      expect(orientations, isEmpty);
    });

    testWidgets('en vertical, deslizar de lado no lo cierra', (tester) async {
      portraitScreen(tester);
      androidTouchSlop(tester);
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();

      // Por las teclas y por la cabecera, poco a poco y deprisa.
      final rect = tester.getRect(keyboard());
      final gesture = await tester.startGesture(
        Offset(rect.left + 20, rect.top + 30),
      );
      await tester.pump();
      expect(piano.played, [48]);
      for (var i = 0; i < 60; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      expect(piano.stopped, isEmpty);

      await tester.flingFrom(
        Offset(rect.left - 10, rect.center.dy),
        const Offset(300, 0),
        2000,
      );
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);

      // Se cierra con su botón.
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(keyboard(), findsNothing);
    });

    testWidgets(
      'en vertical, deslizar a lo largo del teclado toca las teclas',
      (tester) async {
        portraitScreen(tester);
        await pumpApp(tester);
        await openPiano(tester);
        await tester.pumpAndSettle();

        final rect = tester.getRect(keyboard());
        final height = rect.height / PianoPanel.initialKeyCount;
        final gesture = await tester.startGesture(
          Offset(rect.left + 20, rect.top + height / 2),
        );
        for (var i = 1; i <= 3; i++) {
          await gesture.moveTo(
            Offset(rect.left + 20, rect.top + height * (i + 0.5)),
          );
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(keyboard(), findsOneWidget);
        expect(piano.played, [48, 50, 52, 53]);
        expect(piano.stopped, isEmpty);
      },
    );

    testWidgets('arrastrar de izquierda a derecha no lo cierra', (
      tester,
    ) async {
      androidTouchSlop(tester);
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();

      // Por todas las teclas, poco a poco: suenan todas.
      final from = whiteKey(tester, 0);
      final to = whiteKey(tester, 4);
      final gesture = await tester.startGesture(from);
      for (var x = from.dx; x < to.dx; x += 4) {
        await gesture.moveTo(Offset(x, from.dy));
        await tester.pump();
      }
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      expect(piano.played, [48, 50, 52, 53, 55]);

      // En la cabecera, fuera de las teclas.
      await tester.dragFrom(
        tester.getCenter(find.text('Piano').first),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      // Y deprisa, entre las teclas y las octavas.
      final strip = tester.getRect(overview());
      await tester.flingFrom(
        Offset(strip.left + 40, strip.top - 4),
        const Offset(400, 0),
        2000,
      );
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
    });

    testWidgets('el piano está siempre marcado en lo que se graba', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      Set<PianoRecordingMode> selected() => tester
          .widget<SegmentedButton<PianoRecordingMode>>(
            find.byKey(const Key('piano-mode')),
          )
          .selected;

      expect(selected(), {PianoRecordingMode.piano});
      // Quitarlo no hace nada.
      await tester.tap(find.byTooltip('El piano se graba siempre'));
      await tester.pump();
      expect(selected(), {PianoRecordingMode.piano});

      await tester.tap(find.byTooltip('Piano y voz'));
      await tester.pump();
      expect(selected(), {
        PianoRecordingMode.piano,
        PianoRecordingMode.pianoAndVoice,
      });
      await tester.tap(find.byTooltip('El piano se graba siempre'));
      await tester.pump();
      expect(selected(), {
        PianoRecordingMode.piano,
        PianoRecordingMode.pianoAndVoice,
      });

      await tester.tap(find.byTooltip('Piano y voz'));
      await tester.pump();
      expect(selected(), {PianoRecordingMode.piano});
    });

    testWidgets('se elige el instrumento, que suena, se graba con cada nota '
        'y se recuerda', (tester) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(find.text('Piano'), findsWidgets);

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      await tester.tapAt(whiteKey(tester, 0));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('piano-instrument')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Órgano'));
      await tester.pumpAndSettle();
      expect(store.settings.instrument, Instrument.organ);
      expect(piano.preparedInstrument, Instrument.organ);
      expect(find.text('Órgano'), findsOneWidget);

      await tester.tapAt(whiteKey(tester, 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(piano.instruments, [Instrument.piano, Instrument.organ]);
      // Al soltar, para que el órgano deje de sonar.
      expect(piano.released, [48, 52]);

      await tester.tap(find.byKey(const Key('piano-stop')));
      await tester.pumpAndSettle();
      expect(
        repository.recordings.single.notes.map(
          (note) => (note.key, note.instrument),
        ),
        [(48, Instrument.piano), (52, Instrument.organ)],
      );

      // Al volver a abrirlo, el órgano.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(find.text('Órgano'), findsOneWidget);
    });

    testWidgets('las octavas se mueven sin saltos, y pellizcando cambia el '
        'tamaño de las teclas', (tester) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      PianoKeyboard keys() => tester.widget<PianoKeyboard>(keyboard());
      final strip = tester.getRect(overview());
      final whiteWidth = strip.width / PianoKeys.whiteKeys.length;

      // Moviendo un tercio de tecla, la parte ampliada empieza a mitad de
      // una tecla.
      final start = keys().firstKey;
      final drag = await tester.startGesture(strip.center);
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();
      await drag.moveBy(Offset(whiteWidth / 3, 0));
      await tester.pump();
      await drag.up();
      expect(keys().firstKey, isNot(keys().firstKey.roundToDouble()));
      expect(keys().firstKey, greaterThan(start));

      // Separando dos dedos, menos teclas y más grandes.
      Future<void> pinch(double from, double to) async {
        final center = strip.center;
        final a = await tester.startGesture(center - Offset(from, 0));
        final b = await tester.startGesture(center + Offset(from, 0));
        for (var step = 1; step <= 4; step++) {
          final half = from + (to - from) * step / 4;
          await a.moveTo(center - Offset(half, 0));
          await b.moveTo(center + Offset(half, 0));
          await tester.pump();
        }
        await a.up();
        await b.up();
        await tester.pump();
      }

      await pinch(40, 80);
      expect(keys().whiteKeys, closeTo(5.5, 0.01));
      await pinch(80, 20);
      expect(keys().whiteKeys, closeTo(22, 0.01));
      // Sin pasarse.
      await pinch(80, 10);
      expect(keys().whiteKeys, PianoPanel.maxKeyCount);

      // Se conserva al cerrarlo.
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(keys().whiteKeys, PianoPanel.maxKeyCount);
    });

    testWidgets('con el sintetizador, sus controles encima de las teclas: '
        'cambian el sonido, que se graba con cada nota y se recuerda', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('synth-controls')), findsNothing);

      await tester.tap(find.byKey(const Key('piano-instrument')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sintetizador'));
      await tester.pumpAndSettle();
      final controls = find.byKey(const Key('synth-controls'));
      expect(controls, findsOneWidget);
      expect(
        tester.getRect(controls).bottom,
        lessThanOrEqualTo(tester.getRect(keyboard()).top),
      );

      // La rueda X, con «Onda y desafinar»: un tercio, de sierra a
      // cuadrada.
      expect(find.text('Sierra'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('synth-knob-x')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      expect(store.settings.synth.wave, SynthWave.square);
      expect(piano.preparedSynth?.wave, SynthWave.square);
      expect(find.text('Cuadrada'), findsOneWidget);

      // Con «Sostenido y relajación», la rueda Y hacia arriba alarga la
      // relajación; mientras se gira no cambia el sonido; al soltar, sí.
      await tester.tap(find.byKey(const Key('synth-pair-2')));
      await tester.pump();
      expect(find.text('Y · RELAJACIÓN'), findsOneWidget);
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('synth-knob-y'))),
      );
      await drag.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(store.settings.synth.release, const SynthPatch().release);
      // La pantalla ya muestra el valor nuevo.
      expect(find.text('300 ms'), findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
      final changed = store.settings.synth;
      expect(changed.release, greaterThan(const SynthPatch().release));
      expect(changed.wave, SynthWave.square);

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      await tester.tapAt(whiteKey(tester, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('piano-stop')));
      await tester.pumpAndSettle();
      final note = editor.pianoSaves.single.$1.single;
      expect(note.instrument, Instrument.synth);
      expect(note.synth, changed);

      // Vuelve al sonido por defecto.
      await tester.tap(find.byKey(const Key('synth-reset')));
      await tester.pumpAndSettle();
      expect(store.settings.synth, const SynthPatch());
    });

    testWidgets('graba solo el piano y lo guarda en la carpeta abierta', (
      tester,
    ) async {
      store.settings = const AppSettings(
        folder: testFolder,
        openFolder: 'Ideas',
        transcription: manual,
      );
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      expect(find.byKey(const Key('piano-stop')), findsOneWidget);
      // Mientras se graba no se cambia qué se graba.
      final modes = tester.widget<SegmentedButton<PianoRecordingMode>>(
        find.byKey(const Key('piano-mode')),
      );
      expect(modes.onSelectionChanged, isNull);

      await tester.tapAt(whiteKey(tester, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(whiteKey(tester, 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('piano-stop')));
      await tester.pumpAndSettle();

      final saved = repository.recordings.single;
      expect(saved.hasVoice, isFalse);
      // Sin audio: solo las notas, en un .mid.
      expect(saved.isNotesOnly, isTrue);
      expect(saved.path, endsWith('.mid'));
      expect(saved.folder, 'Ideas');
      expect(saved.notes.map((n) => n.key), [48, 52]);
      expect(recorder.calls, isEmpty);
      expect(find.text('Guardada como «${saved.name}»'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(RecordingNames.withoutDate(saved.name)), findsOneWidget);
    });

    testWidgets('sin tocar nada no guarda, y lo dice', (tester) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('piano-stop')));
      await tester.pumpAndSettle();

      expect(repository.recordings, isEmpty);
      expect(
        find.text('No hay nada que guardar: no se ha tocado ninguna nota'),
        findsOneWidget,
      );
    });

    testWidgets('con voz graba con el micrófono, y al cerrar el piano se '
        'guarda', (tester) async {
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Piano y voz'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      expect(recorder.calls, ['hasPermission', 'start']);
      await tester.tapAt(whiteKey(tester, 5));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(recorder.calls.last, 'stop');
      final saved = repository.recordings.single;
      expect(saved.hasVoice, isTrue);
      expect(saved.notes.single.key, 57);
      expect(editor.pianoAdded[saved.id], saved.notes);
      expect(find.text(RecordingNames.withoutDate(saved.name)), findsOneWidget);

      // Se recuerda qué se graba.
      await openPiano(tester);
      await tester.pumpAndSettle();
      final modes = tester.widget<SegmentedButton<PianoRecordingMode>>(
        find.byKey(const Key('piano-mode')),
      );
      expect(modes.selected, {
        PianoRecordingMode.piano,
        PianoRecordingMode.pianoAndVoice,
      });
    });

    testWidgets('con voz y sin permiso del micrófono, lo dice', (tester) async {
      recorder.permissionGranted = false;
      await pumpApp(tester);
      await openPiano(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Piano y voz'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('piano-record')), findsOneWidget);
      expect(
        find.text(
          'Permite el acceso al micrófono en los ajustes para poder grabar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('las grabaciones con piano muestran sus notas, y las de solo '
        'piano no se transcriben', (tester) async {
      const notes = [
        PianoNote(
          key: 60,
          start: Duration(seconds: 1),
          duration: Duration(milliseconds: 500),
        ),
      ];
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'p',
          path: '/fake/p.m4a',
          name: 'Solo piano',
          createdAt: DateTime(2026, 9, 28),
          duration: const Duration(seconds: 4),
          notes: notes,
          hasVoice: false,
        ),
      ]);
      store.settings = const AppSettings(
        folder: testFolder,
        compactList: false,
      );
      await pumpApp(tester);

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const Key('waveform-p')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is PianoRollPainter,
          ),
        ),
      );
      expect(paint.painter, isNull);
      expect((paint.foregroundPainter! as PianoRollPainter).notes, notes);
      // Sin voz no se transcribe, ni sola ni desde el menú.
      expect(transcriber.calls, isEmpty);
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Transcribir'), findsNothing);
      expect(find.text('Compartir'), findsOneWidget);
    });

    testWidgets('las de solo notas suenan con el sonido de sus notas, sin '
        'onda, y las añadidas desde fuera leen las notas de su .mid', (
      tester,
    ) async {
      const notes = [
        PianoNote(
          key: 60,
          start: Duration(seconds: 1),
          duration: Duration(milliseconds: 500),
        ),
      ];
      repository = InMemoryRecordingsRepository([
        Recording(
          id: 'm',
          path: '/fake/m.mid',
          name: 'Melodía',
          createdAt: DateTime(2026, 9, 28),
          duration: Duration.zero,
        ),
      ]);
      store.settings = const AppSettings(
        folder: testFolder,
        compactList: false,
        transcription: manual,
      );
      await pumpApp(tester, (editor) => editor.midiNotes = notes);
      await tester.pumpAndSettle();

      expect(editor.notesRead, ['m']);
      final read = repository.byId('m');
      expect(read.notes, notes);
      expect(read.duration, const Duration(milliseconds: 2600));
      expect(find.text('MIDI'), findsOneWidget);
      // Ni onda ni formato que leer de un audio.
      expect(editor.extracted, isEmpty);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(editor.pianoAudios, ['m']);
      expect(player.calls.last, 'play /fake/piano/m.wav @0');
      // Ya tiene sus notas: no se vuelven a leer.
      expect(editor.notesRead, ['m']);
    });

    testWidgets('desde una grabación, «Añadir piano» toca sobre ella mientras '
        'suena y al terminar se añade', (tester) async {
      repository = InMemoryRecordingsRepository([
        sample('a', 'Entrevista', createdAt: DateTime(2026, 9, 1)),
        sample('b', 'Otra', createdAt: DateTime(2026, 9, 2)),
      ]);
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Más opciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir piano'));
      await tester.pumpAndSettle();

      expect(find.text('Sobre «Entrevista»'), findsOneWidget);
      expect(find.byKey(const Key('piano-mode')), findsNothing);

      // Aunque esté activada la lista, al terminar no sigue con otra.
      await tester.tap(find.byKey(const Key('piano-record')));
      await tester.pump();
      expect(player.calls.last, 'play /fake/a.m4a @0');
      expect(recorder.calls, isEmpty);
      await tester.tapAt(whiteKey(tester, 4));
      await tester.pump(const Duration(milliseconds: 100));

      player.statusController.add(PlaybackStatus.completed);
      await tester.pumpAndSettle();

      final saved = repository.byId('a');
      expect(saved.notes.single.key, 55);
      expect(editor.pianoAdded['a'], saved.notes);
      expect(repository.recordings, hasLength(2));
      expect(find.text('Piano añadido a «Entrevista»'), findsWidgets);
      expect(player.calls.where((c) => c.startsWith('play')), hasLength(1));

      // Al cerrarlo, el piano vuelve a grabar como siempre.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openPiano(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-target')), findsNothing);
      expect(find.byKey(const Key('piano-mode')), findsOneWidget);
    });

    testWidgets('se abre desde el pie del menú de las carpetas, que se '
        'cierra', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('folders-button')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('piano-button'));
      final drawer = tester.getRect(find.byType(FolderDrawer));
      // Abajo del todo, aunque haya pocas carpetas.
      expect(tester.getRect(button).bottom, greaterThan(drawer.bottom - 80));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(keyboard(), findsOneWidget);
      expect(find.byType(FolderDrawer), findsNothing);
      // Ya no está en la barra superior.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-button')), findsNothing);
    });

    testWidgets('mientras se graba no se abre', (tester) async {
      await pumpApp(tester);
      await tester.tap(record());
      await pumpAnimations(tester);

      // Ni el menú de las carpetas (con el botón del piano) ni deslizando.
      final folders = tester.widget<IconButton>(
        find.byKey(const Key('folders-button')),
      );
      expect(folders.onPressed, isNull);
      await tester.drag(
        find.byKey(const Key('list-background')),
        const Offset(-300, 0),
      );
      await pumpAnimations(tester);
      expect(keyboard(), findsNothing);
    });
  });
}
