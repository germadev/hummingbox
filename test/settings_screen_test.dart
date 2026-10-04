import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/models/recording_options.dart';
import 'package:voicerecorder/screens/settings_screen.dart';
import 'package:voicerecorder/services/copy_sync.dart';

import 'fakes.dart';

void main() {
  late InMemorySettingsStore store;
  late FakeFolderAccess folders;
  late FakeDriveService drive;
  late CopySync sync;

  setUp(() {
    store = InMemorySettingsStore();
    folders = FakeFolderAccess();
    drive = FakeDriveService();
    sync = fakeCopySync(
      InMemoryRecordingsRepository(),
      store: store,
      folders: folders,
      drive: drive,
    );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(sync: sync)));
    await sync.load();
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

  testWidgets('cancelar el diálogo no cambia la calidad', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('quality-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.settings.recording, const RecordingOptions());
  });

  testWidgets('elige la carpeta donde guardar las grabaciones', (tester) async {
    await pumpSettings(tester);
    expect(find.text('No se guarda en ninguna carpeta'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folder-option')));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsOneWidget);
    expect(store.settings.folder!.id, 'tree://music');

    await tester.tap(find.byTooltip('Dejar de guardar en la carpeta'));
    await tester.pumpAndSettle();
    expect(store.settings.folder, isNull);
    expect(
      find.text('Las copias que ya están en la carpeta se conservan'),
      findsOneWidget,
    );
  });

  testWidgets('pregunta antes de añadir los audios de la carpeta', (
    tester,
  ) async {
    folders.addFile('tree://music', 'Idea.m4a', bytes: List.filled(500000, 0));
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('folder-option')));
    await tester.pumpAndSettle();
    expect(find.text('¿Añadir las grabaciones de la carpeta?'), findsOneWidget);
    expect(find.textContaining('1 audio (0,5 MB)'), findsOneWidget);

    await tester.tap(find.text('No añadir'));
    await tester.pumpAndSettle();

    expect(store.settings.folder!.importFiles, isFalse);
    final option = find.byKey(const Key('import-option'));
    await tester.scrollUntilVisible(option, 100);
    expect(tester.widget<SwitchListTile>(option).value, isFalse);

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(store.settings.folder!.importFiles, isTrue);
  });

  testWidgets('no cambia nada si se cancela el selector', (tester) async {
    folders.picked = null;
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('folder-option')));
    await tester.pumpAndSettle();

    expect(store.settings.folder, isNull);
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
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();

    expect(drive.disconnected, isTrue);
    expect(store.settings.drive, isNull);
    expect(find.text('Guardar una copia en tu Google Drive'), findsOneWidget);
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
