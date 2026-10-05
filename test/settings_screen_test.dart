import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/controllers/whisper_controller.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/screens/settings_screen.dart';
import 'package:voicerecorder/services/settings_store.dart';
import 'package:voicerecorder/services/storage_sync.dart';

import 'fakes.dart';
import 'l10n_helpers.dart';

void main() {
  late InMemorySettingsStore store;
  late FakeFolderAccess folders;
  late FakeDriveService drive;
  late FakeWhisperService whisperService;
  late WhisperController whisper;
  late StorageSync sync;

  const driveAccount = DriveSettings(
    email: 'ana@example.com',
    folderId: 'folder1',
  );

  setUp(() {
    store = InMemorySettingsStore(const AppSettings(folder: testFolder));
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    whisperService = FakeWhisperService();
    whisper = WhisperController(whisperService);
    sync = fakeStorageSync(
      InMemoryRecordingsRepository(),
      store: store,
      folders: folders,
      drive: drive,
    );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    // Pantalla alta, para que quepan todas las opciones.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Se abre desde otra pantalla, como en la app (sin destino, se cierra).
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) =>
                    SettingsScreen(sync: sync, whisper: whisper),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await sync.load();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('elige el formato y la calidad de grabación', (tester) async {
    await pumpSettings(tester);
    expect(find.text('AAC (.m4a)'), findsOneWidget);
    expect(
      find.text('Alta · 44,1 kHz · 128 kbps · 1 MB por minuto'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('format-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WAV (.wav)'));
    await tester.pumpAndSettle();

    expect(store.settings.recording.format, RecordingFormat.wav);
    expect(
      find.text('Alta · 44,1 kHz · 16 bits · 5,3 MB por minuto'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quality-option')));
    await tester.pumpAndSettle();
    // Cada calidad muestra lo que ocupa con el formato elegido.
    expect(find.text('16 kHz · 16 bits · 1,9 MB por minuto'), findsOneWidget);
    await tester.tap(find.text('Baja'));
    await tester.pumpAndSettle();

    expect(
      store.settings.recording,
      const RecordingOptions(
        format: RecordingFormat.wav,
        quality: RecordingQuality.low,
      ),
    );
  });

  testWidgets('elige la duración de la cuenta atrás', (tester) async {
    await pumpSettings(tester);
    expect(find.textContaining('3 segundos antes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('countdown-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 segundos'));
    await tester.pumpAndSettle();

    expect(store.settings.countdownSeconds, 10);
    expect(find.textContaining('10 segundos antes'), findsOneWidget);
  });

  testWidgets('desactiva mantener la pantalla encendida', (tester) async {
    await pumpSettings(tester);
    final option = find.byKey(const Key('keep-screen-on-option'));
    expect(tester.widget<SwitchListTile>(option).value, isTrue);

    await tester.tap(option);
    await tester.pumpAndSettle();

    expect(store.settings.keepScreenOn, isFalse);
    expect(tester.widget<SwitchListTile>(option).value, isFalse);
  });

  group('transcripción', () {
    Future<void> tapOption(WidgetTester tester, String key) async {
      final option = find.byKey(Key(key));
      await tester.scrollUntilVisible(option, 200);
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    testWidgets('elige Whisper y descarga un modelo', (tester) async {
      await pumpSettings(tester);
      await tapOption(tester, 'transcription-engine-option');
      await tester.tap(find.text('Whisper'));
      await tester.pumpAndSettle();

      expect(store.settings.transcription.engine, TranscriptionEngine.whisper);
      // Sin modelo, pide elegir uno.
      expect(find.text('Descargar un modelo'), findsOneWidget);
      expect(find.text('77,7 MB · Más rápido, menos preciso'), findsOneWidget);
      await tester.tap(find.text('Base'));
      await tester.pumpAndSettle();

      expect(whisperService.installs, [WhisperModel.base]);
      whisperService.installing!.add(0.5);
      await tester.pumpAndSettle();
      expect(
        find.text('Descargando Base… 50\u00a0% de 148 MB'),
        findsOneWidget,
      );

      await whisperService.finishInstall();
      await tester.pumpAndSettle();
      expect(find.text('Instalado: Base (148 MB)'), findsOneWidget);
    });

    testWidgets('cancela la descarga', (tester) async {
      await pumpSettings(tester);
      await tapOption(tester, 'whisper-model-option');
      await tester.tap(find.text('Tiny'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cancelar descarga'));
      await tester.pumpAndSettle();

      expect(whisperService.cancelledInstalls, 1);
      expect(
        find.text('Sin instalar. Toca para descargar uno'),
        findsOneWidget,
      );
    });

    testWidgets('elimina el modelo', (tester) async {
      whisperService.installed = WhisperModel.tiny;
      await whisper.load();
      await pumpSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Instalado: Tiny (77,7 MB)'),
        200,
      );

      await tester.tap(find.byTooltip('Eliminar el modelo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Se liberarán 77,7 MB. Podrás volver a descargarlo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(whisperService.uninstalls, 1);
      expect(
        find.text('Sin instalar. Toca para descargar uno'),
        findsOneWidget,
      );
    });

    testWidgets('elige el idioma', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('El de la app (Español)'), 200);

      await tapOption(tester, 'transcription-language-option');
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(store.settings.transcription.language, 'de');
      expect(find.text('Deutsch'), findsOneWidget);
    });
  });

  testWidgets('elige el tema', (tester) async {
    await pumpSettings(tester);
    final option = find.byKey(const Key('theme-option'));
    await tester.scrollUntilVisible(option, 200);
    expect(find.text('Automático (el del sistema)'), findsOneWidget);

    await tester.tap(option);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(store.settings.theme, AppTheme.dark);
    expect(find.text('Oscuro'), findsOneWidget);
  });

  testWidgets('cancelar el diálogo no cambia la calidad', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('quality-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.settings.recording, const RecordingOptions());
  });

  testWidgets('elige otra carpeta donde guardar las grabaciones', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.text('Grabaciones'), findsOneWidget);
    expect(find.textContaining('se guardan en la carpeta elegida'), findsOne);

    await tester.tap(find.byKey(const Key('folder-option')));
    await tester.pumpAndSettle();

    // Sin preguntar: lo que haya en la carpeta son grabaciones.
    expect(find.text('Music'), findsOneWidget);
    expect(store.settings.folder!.id, 'tree://music');
    expect(
      find.text('Las grabaciones se guardan ahora en «Music»'),
      findsOneWidget,
    );
  });

  testWidgets('al dejar de usar la carpeta, pasa a usar Google Drive', (
    tester,
  ) async {
    store.settings = const AppSettings(folder: testFolder, drive: driveAccount);
    await pumpSettings(tester);

    await tester.tap(find.byTooltip('Dejar de usar la carpeta'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('la app pasará a usar las de tu Google Drive'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dejar de usarla'));
    await tester.pumpAndSettle();

    expect(store.settings.folder, isNull);
    expect(store.settings.storage, StorageKind.drive);
    expect(find.text('Ninguna'), findsOneWidget);
    expect(find.textContaining('carpeta «Grabadora» de tu Google'), findsOne);
  });

  testWidgets('no deja de usar la carpeta si se cancela', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byTooltip('Dejar de usar la carpeta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dejarán de verse en la app'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.settings.folder, testFolder);
  });

  testWidgets('no cambia nada si se cancela el selector', (tester) async {
    folders.picked = null;
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('folder-option')));
    await tester.pumpAndSettle();

    expect(store.settings.folder, testFolder);
  });

  testWidgets('conecta y desconecta Google Drive', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('drive-option')));
    await tester.pumpAndSettle();
    expect(find.text('ana@example.com · carpeta «Grabadora»'), findsOneWidget);
    expect(store.settings.drive!.folderId, 'folder1');

    await tester.tap(find.byKey(const Key('drive-option')));
    await tester.pumpAndSettle();
    expect(find.text('¿Desconectar Google Drive?'), findsOneWidget);
    expect(find.textContaining('Dejarán de guardarse copias'), findsOne);
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();

    expect(drive.disconnected, isTrue);
    expect(store.settings.drive, isNull);
    expect(find.text('Guardar una copia en tu Google Drive'), findsOneWidget);
  });

  testWidgets('al desconectar Drive si es el destino, cierra las opciones', (
    tester,
  ) async {
    store.settings = const AppSettings(drive: driveAccount);
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('drive-option')));
    await tester.pumpAndSettle();
    expect(find.textContaining('se quedarán en tu Drive'), findsOneWidget);
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();

    expect(store.settings.storage, isNull);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('no conecta si se cancela el inicio de sesión', (tester) async {
    drive.account = null;
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('drive-option')));
    await tester.pumpAndSettle();

    expect(store.settings.drive, isNull);
    expect(find.text('No se pudo conectar con Google Drive'), findsNothing);
  });

  testWidgets('desactiva Google Drive si no está configurado', (tester) async {
    drive.isAvailable = false;
    await pumpSettings(tester);

    expect(find.textContaining('No disponible'), findsOneWidget);
    final option = tester.widget<SwitchListTile>(
      find.byKey(const Key('drive-option')),
    );
    expect(option.onChanged, isNull);
  });
}
