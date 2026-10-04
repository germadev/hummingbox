import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/screens/editor_screen.dart';

import 'fakes.dart';

void main() {
  late InMemoryRecordingsRepository repository;
  late FakeRecordingEditor editor;
  late FakeAudioPlayerService player;
  late Recording recording;
  EditResult? result;
  late bool closed;

  setUp(() {
    recording = Recording(
      id: 'a',
      path: '/fake/a.m4a',
      name: 'Entrevista',
      createdAt: DateTime(2026, 9, 28),
      duration: const Duration(seconds: 10),
    );
    repository = InMemoryRecordingsRepository([recording]);
    editor = FakeRecordingEditor(repository: repository);
    player = FakeAudioPlayerService();
    result = null;
    closed = false;
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<EditResult>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditorScreen(
                        recording: recording,
                        editor: editor,
                        playerFactory: () => player,
                      ),
                    ),
                  );
                  closed = true;
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder saveButton() => find.byKey(const Key('save-edit-button'));
  Finder saveCopyButton() => find.byKey(const Key('save-copy-button'));

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  /// Si se puede guardar. Los dos botones se activan a la vez.
  bool canSave(WidgetTester tester) {
    final canSave = enabled(tester, saveButton());
    expect(enabled(tester, saveCopyButton()), canSave);
    return canSave;
  }

  testWidgets('recorta arrastrando las asas', (tester) async {
    await pumpEditor(tester);
    expect(find.text('00:10,0'), findsNWidgets(2)); // Duración y fin.
    expect(canSave(tester), isFalse);

    final waveform = tester.getRect(find.byKey(const Key('trim-waveform')));
    // Asa de inicio, en el margen izquierdo de la onda.
    final start = Offset(waveform.left + 14, waveform.center.dy);
    final track = waveform.width - 28;
    await tester.dragFrom(start, Offset(track / 4, 0));
    await tester.pumpAndSettle();

    expect(find.text('00:02,5'), findsOneWidget); // Inicio.
    expect(find.text('00:07,5'), findsOneWidget); // Duración.
    expect(canSave(tester), isTrue);

    await tester.tap(find.text('Restablecer'));
    await tester.pumpAndSettle();
    expect(find.text('00:00,0'), findsOneWidget);
    expect(canSave(tester), isFalse);
  });

  testWidgets('normaliza y avisa si el audio se va a saturar', (tester) async {
    await pumpEditor(tester);

    // Pico de 0,25: hasta −1 dBFS hay unos 11 dB.
    await tester.tap(find.text('Normalizar'));
    await tester.pump();
    expect(find.text('+11,0 dB'), findsOneWidget);
    expect(find.text('Las partes más fuertes se saturarán'), findsNothing);

    await tester.drag(
      find.byKey(const Key('gain-slider')),
      const Offset(800, 0),
    );
    await tester.pump();
    expect(find.text('+20,0 dB'), findsOneWidget);
    expect(find.text('Las partes más fuertes se saturarán'), findsOneWidget);
  });

  testWidgets('guarda la edición sustituyendo la original', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Normalizar'));
    await tester.pump();

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result!.isCopy, isFalse);
    expect(result!.recording.id, 'a');
    expect(result!.recording.revision, 1);
    expect(editor.savedAsCopy, isFalse);
    expect(editor.savedEdit!.gainDb, 11.0);
    expect(editor.closedSessions, 1);
    expect(repository.recordings, hasLength(1));
  });

  testWidgets('guarda la edición como copia', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Normalizar'));
    await tester.pump();

    await tester.tap(saveCopyButton());
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result!.isCopy, isTrue);
    expect(result!.recording.name, 'Entrevista (editada)');
    expect(editor.savedAsCopy, isTrue);
    expect(editor.savedEdit!.gainDb, 11.0);
    expect(editor.closedSessions, 1);
    expect(repository.recordings, hasLength(2));
  });

  testWidgets('pide confirmación antes de descartar los cambios', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Normalizar'));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
    expect(editor.savedEdit, isNull);
  });

  testWidgets('sale sin preguntar si no hay cambios', (tester) async {
    await pumpEditor(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(editor.closedSessions, 1);
    expect(player.disposed, isTrue);
  });

  testWidgets('escucha la selección y se detiene al final', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('preview-button')));
    await tester.pumpAndSettle();
    expect(player.calls, ['play /fake/a.m4a @0']);
    expect(find.byTooltip('Pausar'), findsOneWidget);

    player.positionController.add(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'pause');
    expect(find.byTooltip('Escuchar la selección'), findsOneWidget);
  });

  testWidgets('avisa si no puede abrir el audio', (tester) async {
    editor.openError = Exception('códec');
    await pumpEditor(tester);

    expect(
      find.text('No se pudo abrir el audio para editarlo.'),
      findsOneWidget,
    );
    expect(saveButton(), findsNothing);
    expect(saveCopyButton(), findsNothing);
  });
}
