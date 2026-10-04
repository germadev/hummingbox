import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/recorder_controller.dart';
import '../models/recording.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/copy_sync.dart';
import '../services/recording_editor.dart';
import '../services/recordings_repository.dart';
import '../services/share_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/folder_drawer.dart';
import '../widgets/record_panel.dart';
import '../widgets/recording_tile.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.recorderFactory,
    required this.playerFactory,
    required this.editor,
    required this.sync,
  });

  final RecordingsRepository repository;
  final AudioRecorderService Function() recorderFactory;
  final AudioPlayerService Function() playerFactory;
  final RecordingEditor editor;

  /// Copias de las grabaciones en una carpeta y en Google Drive.
  final CopySync sync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecorderController _recorder = RecorderController(
    recorder: widget.recorderFactory(),
    repository: widget.repository,
    probe: widget.editor.probe,
  );
  late final PlayerController _player = PlayerController(
    player: widget.playerFactory(),
  );

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<List<Recording>> _imports;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Todas las grabaciones, de todas las carpetas.
  List<Recording> _recordings = const [];
  bool _loading = true;

  /// Subcarpeta abierta; vacío para la principal.
  String get _folder => widget.sync.settings.openFolder;

  @override
  void initState() {
    super.initState();
    // Al volver a la app se reintentan las copias pendientes y se buscan
    // grabaciones nuevas en la carpeta.
    _lifecycle = AppLifecycleListener(onResume: _syncCopies);
    _imports = widget.sync.imports.listen(_onImported);
    widget.sync.load();
    _loadRecordings();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _imports.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    try {
      final recordings = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('No se pudieron cargar las grabaciones');
      return;
    }
    _syncCopies();
    await _addMissingDetails();
  }

  bool _addingDetails = false;
  bool _detailsPending = false;

  /// Calcula lo que les falta a las grabaciones hechas con versiones
  /// anteriores de la app o importadas de la carpeta: la onda (decodificando
  /// el audio), el formato y, si no se conoce, la duración. Si algo falla, se
  /// reintenta al volver a abrir la app.
  Future<void> _addMissingDetails() async {
    if (_addingDetails) {
      // Se repite al terminar para incluir las que han llegado entretanto.
      _detailsPending = true;
      return;
    }
    _addingDetails = true;
    try {
      do {
        _detailsPending = false;
        final pending = [
          for (final recording in _recordings)
            if (recording.waveform == null || recording.audio == null)
              recording,
        ];
        for (final recording in pending) {
          if (!mounted) return;
          await _addDetails(recording);
        }
      } while (_detailsPending && mounted);
    } finally {
      _addingDetails = false;
    }
  }

  Future<void> _addDetails(Recording recording) async {
    final editor = widget.editor;
    final probe = recording.audio == null
        ? await editor.probe(recording.path)
        : null;
    List<double>? levels;
    if (recording.waveform == null) {
      try {
        levels = await editor.extractWaveform(recording);
      } catch (_) {
        // Se sigue mostrando sin onda.
      }
    }
    final duration = recording.duration == Duration.zero
        ? probe?.duration
        : null;
    if (!mounted || (probe == null && levels == null)) return;

    // Si entretanto se ha editado o borrado, ya no hace falta.
    final current = _recordings.where((r) => r.id == recording.id);
    if (current.isEmpty || current.single.revision != recording.revision) {
      return;
    }
    try {
      final updated = await widget.repository.setDetails(
        recording,
        waveform: levels,
        duration: duration,
        audio: probe?.info,
      );
      if (!mounted) return;
      setState(() {
        _recordings = [
          for (final r in _recordings)
            r.id == recording.id
                ? r.copyWith(
                    waveform: updated.waveform,
                    duration: updated.duration,
                    audio: updated.audio,
                  )
                : r,
        ];
      });
    } catch (_) {
      // Se reintenta en el siguiente arranque.
    }
  }

  void _syncCopies() => unawaited(widget.sync.sync());

  /// Añade a la lista las grabaciones que se acaban de traer de la carpeta.
  void _onImported(List<Recording> imported) {
    if (!mounted) return;
    final known = {for (final r in _recordings) r.id};
    final added = [
      for (final r in imported)
        if (!known.contains(r.id)) r,
    ];
    if (added.isEmpty) return;
    setState(() {
      _recordings = [..._recordings, ...added]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
    _showMessage(
      added.length == 1
          ? 'Se ha añadido 1 grabación de la carpeta'
          : 'Se han añadido ${added.length} grabaciones de la carpeta',
    );
    unawaited(_addMissingDetails());
  }

  // --- Carpetas ---

  /// Subcarpetas: las creadas en la app, las de la carpeta del dispositivo y
  /// las de las grabaciones.
  List<String> get _folderNames {
    final names = <String>{
      ...widget.sync.settings.folders,
      ...widget.sync.deviceFolders,
      for (final recording in _recordings) recording.folder,
      _folder,
    }..remove('');
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _openFolder(String folder) async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
    await _player.stop();
    await widget.sync.openFolder(folder);
  }

  Future<void> _createFolder() async {
    final input = await showNameDialog(
      context,
      title: 'Nueva carpeta',
      confirmLabel: 'Crear',
    );
    if (input == null || !mounted) return;
    final name = safeFileName(input, fallback: '');
    if (name.isEmpty || name.startsWith('.')) {
      _showMessage('Ese nombre no vale para una carpeta');
      return;
    }
    await widget.sync.createFolder(name);
    if (!mounted) return;
    await _openFolder(name);
  }

  // --- Grabación ---

  Future<void> _onRecordPressed() async {
    if (_recorder.isActive) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    await _player.stop();
    try {
      await widget.sync.load();
      final started = await _recorder.start(
        options: widget.sync.settings.recording,
        folder: _folder,
      );
      if (!started) {
        _showMessage(
          'Permite el acceso al micrófono en los ajustes para poder grabar',
        );
      }
    } catch (_) {
      _showMessage('No se pudo iniciar la grabación');
    }
  }

  Future<void> _stopRecording() async {
    Recording? recording;
    try {
      recording = await _recorder.stop();
    } catch (_) {
      recording = null;
    }
    if (!mounted) return;
    if (recording == null) {
      _showMessage('No se pudo guardar la grabación');
      return;
    }
    final saved = recording;
    setState(() => _recordings = [saved, ..._recordings]);
    _showMessage('Guardada como «${saved.name}»');
    _syncCopies();
  }

  Future<void> _confirmCancel() async {
    final discard = await showConfirmDialog(
      context,
      title: '¿Descartar la grabación?',
      message: 'Se perderá el audio grabado hasta ahora.',
      confirmLabel: 'Descartar',
    );
    if (discard) await _recorder.cancel();
  }

  // --- Lista de grabaciones ---

  void _togglePlayback(Recording recording) {
    if (_recorder.isActive) {
      _showMessage('Detén la grabación para poder reproducir');
      return;
    }
    _player.toggle(recording);
  }

  void _seek(Recording recording, Duration position) {
    if (_recorder.isActive) {
      _showMessage('Detén la grabación para poder reproducir');
      return;
    }
    if (_player.isCurrent(recording)) {
      _player.seek(position);
    } else {
      _player.playFrom(recording, position);
    }
  }

  Future<void> _onAction(
    Recording recording,
    RecordingAction action,
    BuildContext tileContext,
  ) async {
    switch (action) {
      case RecordingAction.edit:
        await _edit(recording);
      case RecordingAction.rename:
        await _rename(recording);
      case RecordingAction.share:
        await _share(recording, tileContext);
      case RecordingAction.delete:
        await _delete(recording);
    }
  }

  Future<void> _edit(Recording recording) async {
    if (_recorder.isActive) {
      _showMessage('Detén la grabación para poder editar');
      return;
    }
    await _player.stop();
    if (!mounted) return;
    final result = await Navigator.push<EditResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          recording: recording,
          editor: widget.editor,
          playerFactory: widget.playerFactory,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final edited = result.recording;
    setState(() {
      _recordings = result.isCopy
          ? [edited, ..._recordings]
          : [for (final r in _recordings) r.id == edited.id ? edited : r];
    });
    _showMessage(
      result.isCopy ? 'Guardada como «${edited.name}»' : 'Cambios guardados',
    );
    _syncCopies();
  }

  Future<void> _rename(Recording recording) async {
    final name = await showRenameDialog(context, recording.name);
    if (name == null || name == recording.name) return;
    try {
      final renamed = await widget.repository.rename(recording, name);
      if (!mounted) return;
      setState(() {
        _recordings = [
          for (final r in _recordings) r.id == renamed.id ? renamed : r,
        ];
      });
      _syncCopies();
    } catch (_) {
      _showMessage('No se pudo renombrar la grabación');
    }
  }

  Future<void> _share(Recording recording, BuildContext tileContext) async {
    // En iPad la hoja de compartir necesita un punto de anclaje.
    final box = tileContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await shareRecording(recording, origin: origin);
    } catch (_) {
      _showMessage('No se pudo compartir la grabación');
    }
  }

  Future<void> _delete(Recording recording) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar «${recording.name}»?',
      message: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;

    if (_player.isCurrent(recording)) await _player.stop();
    try {
      await widget.sync.delete(recording);
      if (!mounted) return;
      setState(() {
        _recordings = [
          for (final r in _recordings)
            if (r.id != recording.id) r,
        ];
      });
      _showMessage('Grabación eliminada');
    } catch (_) {
      _showMessage('No se pudo eliminar la grabación');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettings() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(sync: widget.sync),
      ),
    );
  }

  // --- Interfaz ---

  @override
  Widget build(BuildContext context) {
    // Las carpetas y la abierta dependen de las opciones.
    return ListenableBuilder(
      listenable: Listenable.merge([_recorder, widget.sync]),
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final folder = _folder;
    final folderNames = _folderNames;
    final scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Nombre de la carpeta abierta, arriba a la izquierda.
        title: Text(folder.isEmpty ? 'Grabadora' : folder),
        actions: [
          _SyncIndicator(sync: widget.sync, onPressed: _openSettings),
          IconButton(
            key: const Key('settings-button'),
            tooltip: 'Opciones',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Se abre deslizando desde la izquierda. Al abrirlo se buscan
      // subcarpetas nuevas.
      drawer: FolderDrawer(
        rootName: widget.sync.settings.folder?.name ?? 'Grabaciones',
        folders: folderNames,
        counts: {
          for (final name in ['', ...folderNames]) name: _countIn(name),
        },
        selected: folder,
        onSelected: _openFolder,
        onCreate: _createFolder,
      ),
      onDrawerChanged: (opened) {
        if (opened) _syncCopies();
      },
      // Mientras se graba no se cambia de carpeta.
      drawerEnableOpenDragGesture: !_recorder.isActive,
      body: _buildBody(folder),
      bottomNavigationBar: RecordPanel(
        controller: _recorder,
        onRecordPressed: _onRecordPressed,
        onCancelPressed: _confirmCancel,
      ),
    );

    // Evita salir de la app por accidente en mitad de una grabación. En una
    // subcarpeta, «atrás» vuelve a la principal.
    return PopScope(
      canPop: !_recorder.isActive && folder.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_recorder.isActive) {
          _showMessage('Detén la grabación antes de salir');
        } else {
          _openFolder('');
        }
      },
      child: scaffold,
    );
  }

  int _countIn(String folder) =>
      _recordings.where((recording) => recording.folder == folder).length;

  Widget _buildBody(String folder) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final recordings = [
      for (final recording in _recordings)
        if (recording.folder == folder) recording,
    ];
    if (recordings.isEmpty) {
      return _EmptyState(inFolder: folder.isNotEmpty);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final recording = recordings[index];
        return RecordingTile(
          key: ValueKey(recording.id),
          recording: recording,
          player: _player,
          onTogglePlay: () => _togglePlayback(recording),
          onSeek: (position) => _seek(recording, position),
          onAction: (action, tileContext) =>
              _onAction(recording, action, tileContext),
        );
      },
    );
  }
}

/// Indica en la barra superior si se están guardando copias o si ha habido
/// errores al hacerlo.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.sync, required this.onPressed});

  final CopySync sync;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        if (sync.syncing) {
          return IconButton(
            tooltip: 'Guardando copias…',
            icon: const Icon(Icons.sync),
            onPressed: onPressed,
          );
        }
        if (sync.errors.isNotEmpty) {
          return IconButton(
            tooltip: 'No se pudieron guardar algunas copias',
            icon: Icon(
              Icons.sync_problem,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onPressed,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.inFolder});

  /// Si es una subcarpeta (vacía) y no la carpeta principal.
  final bool inFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inFolder ? Icons.folder_open : Icons.mic_none_rounded,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              inFolder ? 'Esta carpeta está vacía' : 'Aún no hay grabaciones',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              inFolder
                  ? 'Pulsa el botón rojo para grabar en ella.'
                  : 'Pulsa el botón rojo para empezar a grabar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
