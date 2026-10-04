import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/recorder_controller.dart';
import '../models/recording.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/recordings_repository.dart';
import '../services/share_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/record_panel.dart';
import '../widgets/recording_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.recorderFactory,
    required this.playerFactory,
  });

  final RecordingsRepository repository;
  final AudioRecorderService Function() recorderFactory;
  final AudioPlayerService Function() playerFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecorderController _recorder = RecorderController(
    recorder: widget.recorderFactory(),
    repository: widget.repository,
  );
  late final PlayerController _player = PlayerController(
    player: widget.playerFactory(),
  );

  List<Recording> _recordings = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
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
    }
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
      final started = await _recorder.start();
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

  Future<void> _onAction(
    Recording recording,
    RecordingAction action,
    BuildContext tileContext,
  ) async {
    switch (action) {
      case RecordingAction.rename:
        await _rename(recording);
      case RecordingAction.share:
        await _share(recording, tileContext);
      case RecordingAction.delete:
        await _delete(recording);
    }
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
      await widget.repository.delete(recording);
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

  // --- Interfaz ---

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('Grabadora')),
      body: _buildBody(),
      bottomNavigationBar: RecordPanel(
        controller: _recorder,
        onRecordPressed: _onRecordPressed,
        onCancelPressed: _confirmCancel,
      ),
    );

    // Evita salir de la app por accidente en mitad de una grabación.
    return ListenableBuilder(
      listenable: _recorder,
      child: scaffold,
      builder: (context, child) => PopScope(
        canPop: !_recorder.isActive,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _showMessage('Detén la grabación antes de salir');
        },
        child: child!,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recordings.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final recording = _recordings[index];
        return RecordingTile(
          key: ValueKey(recording.id),
          recording: recording,
          player: _player,
          onTogglePlay: () => _togglePlayback(recording),
          onAction: (action, tileContext) =>
              _onAction(recording, action, tileContext),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.mic_none_rounded,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('Aún no hay grabaciones', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pulsa el botón rojo para empezar a grabar.',
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
