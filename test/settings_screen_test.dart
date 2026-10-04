import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
