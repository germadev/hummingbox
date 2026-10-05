import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/recorder_controller.dart';
import '../controllers/transcription_controller.dart';
import '../controllers/whisper_controller.dart';
import '../l10n/l10n.dart';
import '../audio/audio_info.dart';
import '../models/recording.dart';
import '../models/recording_options.dart';
import '../models/transcription.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/recording_editor.dart';
import '../services/recordings_repository.dart';
import '../services/screen_awake.dart';
import '../services/settings_store.dart';
import '../services/share_service.dart';
import '../services/storage_sync.dart';
import '../services/transcriber.dart';
import '../utils/languages.dart';
import '../widgets/dialogs.dart';
import '../widgets/folder_drawer.dart';
import '../widgets/record_panel.dart';
import '../widgets/recording_tile.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'storage_setup_screen.dart';
import 'transcript_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.recorderFactory,
    required this.playerFactory,
    required this.editor,
    required this.sync,
    required this.transcriber,
    required this.whisper,
    this.screen = const PlatformScreenAwake(),
  });

  final RecordingsRepository repository;
  final AudioRecorderService Function() recorderFactory;
  final AudioPlayerService Function() playerFactory;
  final RecordingEditor editor;

  /// Dónde se guardan las grabaciones (la carpeta del dispositivo o Google
  /// Drive) y el resto de las opciones.
  final StorageSync sync;

  /// Transcribe las grabaciones (con el reconocimiento del sistema o con
  /// Whisper).
  final Transcriber transcriber;

  /// Instalación de Whisper.
  final WhisperController whisper;

  /// Mantiene la pantalla encendida mientras se graba (si está activado en
  /// las opciones).
  final ScreenAwake screen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecorderController _recorder = RecorderController(
    recorder: widget.recorderFactory(),
    repository: widget.repository,
    probe: widget.editor.probe,
    trimStart: widget.editor.trimStart,
  );
  late final PlayerController _player = PlayerController(
    player: widget.playerFactory(),
    audioPath: widget.sync.audioPath,
  );
  late final TranscriptionController _transcriptions = TranscriptionController(
    transcriber: widget.transcriber,
    repository: widget.repository,
  );

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<int> _changes;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Todas las grabaciones, de todas las carpetas.
  List<Recording> _recordings = const [];
  bool _loading = true;

  /// Subcarpeta abierta; vacío para la principal.
  String get _folder => widget.sync.settings.openFolder;

  @override
  void initState() {
    super.initState();
    // Al volver a la app se guarda lo pendiente y se buscan cambios en el
    // destino.
    _lifecycle = AppLifecycleListener(onResume: _syncStorage);
    _changes = widget.sync.changes.listen(_onStorageChanged);
    _recorder.addListener(_updateScreen);
    widget.sync.addListener(_updateScreen);
    widget.sync.load();
    widget.whisper.load();
    _loadRecordings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Las grabaciones nuevas se llaman «Grabación N» en el idioma de la app.
    widget.repository.defaultNamePrefix = context.l10n.defaultRecordingName;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _changes.cancel();
    widget.sync.removeListener(_updateScreen);
    if (_screenKeptOn) unawaited(widget.screen.keepOn(false));
    _recorder.dispose();
    _player.dispose();
    _transcriptions.dispose();
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
      _showMessage((l10n) => l10n.loadRecordingsFailed);
      return;
    }
    _syncStorage();
    await _addMissingDetails();
  }

  bool _addingDetails = false;
  bool _detailsPending = false;

  /// Calcula lo que les falta a las grabaciones hechas con versiones
  /// anteriores de la app o añadidas desde el destino: la onda (decodificando
  /// el audio), el formato y, si no se conoce, la duración. Si algo falla,
  /// se reintenta al volver a abrir la app.
  ///
  /// Las que están en Google Drive y no se han descargado se dejan para
  /// cuando se descarguen (p. ej. al escucharlas): no se descarga nada solo
  /// para mostrar la lista.
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
          if (!await widget.sync.hasLocalAudio(recording)) continue;
          await _addDetails(recording);
        }
      } while (_detailsPending && mounted);
    } finally {
      _addingDetails = false;
    }
  }

  Future<void> _addDetails(Recording recording) async {
    final editor = widget.editor;
    final AudioProbe? probe;
    try {
      probe = recording.audio == null
          ? await editor.probe(await widget.sync.audioPath(recording))
          : null;
    } catch (_) {
      return;
    }
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

  void _syncStorage() => unawaited(widget.sync.sync());

  bool _screenKeptOn = false;

  /// Mantiene la pantalla encendida mientras se graba o se espera para
  /// empezar (si está activado): al apagarse, el sistema puede parar la app y
  /// con ella la grabación.
  void _updateScreen() {
    final keepOn = _recorder.isBusy && widget.sync.settings.keepScreenOn;
    if (keepOn == _screenKeptOn) return;
    _screenKeptOn = keepOn;
    unawaited(widget.screen.keepOn(keepOn));
  }

  /// Vuelve a cargar la lista cuando cambian las grabaciones del destino
  /// (hay nuevas, se han borrado o cambiado fuera de la app, o se ha elegido
  /// otro destino). [added] son las nuevas.
  Future<void> _onStorageChanged(int added) async {
    final List<Recording> recordings;
    try {
      recordings = await widget.repository.loadAll();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (_player.currentId case final id?
        when !recordings.any((r) => r.id == id)) {
      await _player.stop();
    }
    setState(() => _recordings = recordings);
    if (added > 0) _showMessage((l10n) => l10n.newRecordingsFound(added));
    unawaited(_addMissingDetails());
  }

  // --- Carpetas ---

  /// Subcarpetas: las creadas en la app, las del destino y las de las
  /// grabaciones.
  List<String> get _folderNames {
    final names = <String>{
      ...widget.sync.settings.folders,
      ...widget.sync.storageFolders,
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
      title: context.l10n.newFolder,
      confirmLabel: context.l10n.create,
    );
    if (input == null || !mounted) return;
    final name = safeFileName(input, fallback: '');
    if (name.isEmpty || name.startsWith('.')) {
      _showMessage((l10n) => l10n.invalidFolderName);
      return;
    }
    await widget.sync.createFolder(name);
    if (!mounted) return;
    await _openFolder(name);
  }

  // --- Grabación ---

  Future<void> _onRecordPressed() async {
    if (_recorder.pending != null) {
      // Empieza ya, sin esperar a la cuenta atrás o a la voz.
      await _recorder.startNow();
    } else if (_recorder.isActive) {
      await _stopRecording();
    } else {
      await _startRecording(
        (options, folder) => _recorder.start(options: options, folder: folder),
      );
    }
  }

  Future<void> _startAfterCountdown() => _startRecording(
    (options, folder) => _recorder.startAfterCountdown(
      seconds: widget.sync.settings.countdownSeconds,
      options: options,
      folder: folder,
    ),
  );

  Future<void> _startWhenVoice() => _startRecording(
    (options, folder) =>
        _recorder.startWhenVoice(options: options, folder: folder),
  );

  /// Empieza a grabar (al momento, tras la cuenta atrás o al detectar la voz)
  /// con el formato elegido y en la carpeta abierta.
  Future<void> _startRecording(
    Future<bool> Function(RecordingOptions options, String folder) start,
  ) async {
    await _player.stop();
    try {
      await widget.sync.load();
      final started = await start(widget.sync.settings.recording, _folder);
      if (!started) {
        _showMessage((l10n) => l10n.microphonePermission);
      }
    } catch (_) {
      _showMessage((l10n) => l10n.startRecordingFailed);
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
      _showMessage((l10n) => l10n.saveRecordingFailed);
      return;
    }
    final saved = recording;
    setState(() => _recordings = [saved, ..._recordings]);
    _showMessage((l10n) => l10n.savedAs(saved.name));
    _syncStorage();
  }

  Future<void> _confirmCancel() async {
    // Mientras se espera para empezar no hay nada grabado que perder.
    if (_recorder.pending != null) {
      await _recorder.cancel();
      return;
    }
    final discard = await showConfirmDialog(
      context,
      title: context.l10n.discardRecordingTitle,
      message: context.l10n.discardRecordingMessage,
      confirmLabel: context.l10n.discard,
    );
    if (discard) await _recorder.cancel();
  }

  // --- Lista de grabaciones ---

  void _togglePlayback(Recording recording) {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToPlay);
      return;
    }
    unawaited(_play(() => _player.toggle(recording)));
  }

  void _seek(Recording recording, Duration position) {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToPlay);
      return;
    }
    if (_player.isCurrent(recording)) {
      _player.seek(position);
    } else {
      unawaited(_play(() => _player.playFrom(recording, position)));
    }
  }

  /// Avisa si no se puede reproducir (p. ej. si no se puede descargar).
  Future<void> _play(Future<void> Function() play) async {
    try {
      await play();
    } catch (_) {
      _showMessage((l10n) => l10n.playFailed);
      return;
    }
    // Si se ha descargado, ya se puede calcular lo que le falte.
    unawaited(_addMissingDetails());
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
      case RecordingAction.transcribe:
        await _transcribe(recording);
      case RecordingAction.viewTranscript:
        await _viewTranscript(recording);
      case RecordingAction.share:
        await _share(recording, tileContext);
      case RecordingAction.delete:
        await _delete(recording);
    }
  }

  Future<void> _edit(Recording recording) async {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToEdit);
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
      (l10n) => result.isCopy ? l10n.savedAs(edited.name) : l10n.changesSaved,
    );
    _syncStorage();
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
      _syncStorage();
    } catch (_) {
      _showMessage((l10n) => l10n.renameFailed);
    }
  }

  Future<void> _share(Recording recording, BuildContext tileContext) async {
    // En iPad la hoja de compartir necesita un punto de anclaje.
    final box = tileContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await shareRecording(
        recording,
        path: await widget.sync.audioPath(recording),
        origin: origin,
      );
    } catch (_) {
      _showMessage((l10n) => l10n.shareFailed);
      return;
    }
    unawaited(_addMissingDetails());
  }

  // --- Transcripción ---

  /// Idioma con el que se transcribe: el elegido en las opciones o el de la
  /// app.
  String _transcriptionLanguage(TranscriptionSettings settings) {
    final app = Localizations.localeOf(context).languageCode;
    return switch (settings.language) {
      TranscriptionSettings.appLanguage => app,
      // Solo Whisper sabe detectarlo.
      TranscriptionSettings.detectLanguage =>
        settings.engine == TranscriptionEngine.whisper
            ? TranscriptionSettings.detectLanguage
            : app,
      final language => language,
    };
  }

  /// Transcribe [recording] con lo elegido en las opciones. Si no se puede,
  /// explica por qué y qué hacer.
  Future<void> _transcribe(Recording recording) async {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToTranscribe);
      return;
    }
    await widget.sync.load();
    if (!mounted) return;
    final settings = widget.sync.settings.transcription;
    try {
      final transcribed = await _transcriptions.transcribe(
        recording,
        engine: settings.engine,
        language: _transcriptionLanguage(settings),
      );
      if (!mounted) return;
      _replaceRecording(transcribed);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.transcriptReady),
            action: SnackBarAction(
              label: context.l10n.view,
              onPressed: () => _viewTranscript(transcribed),
            ),
          ),
        );
    } on TranscriptionException catch (e) {
      await _explainTranscriptionError(e);
    } catch (_) {
      _showMessage((l10n) => l10n.transcriptionFailed);
    }
  }

  Future<void> _explainTranscriptionError(TranscriptionException e) async {
    if (!mounted) return;
    final l10n = context.l10n;
    Future<void> offerSettings(String title, String message) async {
      final open = await showConfirmDialog(
        context,
        title: title,
        message: message,
        confirmLabel: l10n.openSettings,
      );
      if (open && mounted) await _openSettings();
    }

    switch (e.error) {
      case TranscriptionError.canceled:
        return;
      case TranscriptionError.systemUnavailable:
        await offerSettings(
          l10n.systemSpeechUnavailableTitle,
          l10n.systemSpeechUnavailableMessage,
        );
      case TranscriptionError.unsupportedLanguage:
        await offerSettings(
          l10n.systemSpeechUnavailableTitle,
          l10n.unsupportedLanguageMessage(
            languageName(
              e.language ??
                  _transcriptionLanguage(widget.sync.settings.transcription),
            ),
          ),
        );
      case TranscriptionError.needsDownload:
        final language = e.language;
        if (language == null) return;
        final download = await showConfirmDialog(
          context,
          title: l10n.downloadLanguageTitle(languageName(language)),
          message: l10n.downloadLanguageMessage,
          confirmLabel: l10n.download,
        );
        if (!download) return;
        try {
          await widget.transcriber.system.download(language);
        } catch (_) {
          _showMessage((l10n) => l10n.transcriptionFailed);
        }
      case TranscriptionError.downloading:
        _showMessage((l10n) => l10n.languageDownloading);
      case TranscriptionError.denied:
        _showMessage((l10n) => l10n.speechPermission);
      case TranscriptionError.microphone:
        _showMessage((l10n) => l10n.microphonePermission);
      case TranscriptionError.whisperNotInstalled:
        await offerSettings(
          l10n.whisperNotInstalledTitle,
          l10n.whisperNotInstalledMessage,
        );
      case TranscriptionError.noSpeech:
        _showMessage((l10n) => l10n.noSpeechRecognized);
      case TranscriptionError.failed:
        _showMessage((l10n) => l10n.transcriptionFailed);
    }
  }

  Future<void> _viewTranscript(Recording recording) async {
    // La de la lista puede tener la transcripción más al día.
    final current =
        _recordings.where((r) => r.id == recording.id).firstOrNull ?? recording;
    if (current.transcript == null) return;
    final action = await Navigator.push<TranscriptAction>(
      context,
      MaterialPageRoute(
        builder: (context) => TranscriptScreen(recording: current),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TranscriptAction.transcribeAgain:
        await _transcribe(current);
      case TranscriptAction.delete:
        try {
          _replaceRecording(
            await widget.repository.setTranscript(current, null),
          );
          _showMessage((l10n) => l10n.transcriptDeleted);
        } catch (_) {
          _showMessage((l10n) => l10n.deleteFailed);
        }
    }
  }

  void _replaceRecording(Recording recording) {
    if (!mounted) return;
    setState(() {
      _recordings = [
        for (final r in _recordings) r.id == recording.id ? recording : r,
      ];
    });
  }

  Future<void> _delete(Recording recording) async {
    final l10n = context.l10n;
    final settings = widget.sync.settings;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteTitle(recording.name),
      message: switch (settings.storage) {
        StorageKind.folder => l10n.deleteFromFolderMessage(
          settings.folder!.name,
        ),
        StorageKind.drive => l10n.deleteFromDriveMessage,
        null => l10n.deleteMessage,
      },
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;

    _transcriptions.cancel(recording);
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
      _showMessage((l10n) => l10n.recordingDeleted);
    } catch (_) {
      _showMessage((l10n) => l10n.deleteFailed);
    }
  }

  /// Muestra un aviso con el texto que devuelve [message] en el idioma de la
  /// app (se lee al mostrarlo, así que se puede llamar tras un `await`).
  void _showMessage(String Function(AppLocalizations l10n) message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message(context.l10n))));
  }

  Future<void> _openSettings() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(sync: widget.sync, whisper: widget.whisper),
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
    final sync = widget.sync;
    if (!sync.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Hasta que se elige dónde guardar las grabaciones, el menú inicial.
    if (sync.settings.storage == null) return StorageSetupScreen(sync: sync);

    final folder = _folder;
    final folderNames = _folderNames;
    final scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Nombre de la carpeta abierta, arriba a la izquierda.
        title: Text(folder.isEmpty ? context.l10n.appTitle : folder),
        actions: [
          _SyncIndicator(sync: widget.sync, onPressed: _openSettings),
          IconButton(
            key: const Key('settings-button'),
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Se abre deslizando desde la izquierda. Al abrirlo se buscan
      // subcarpetas nuevas.
      drawer: FolderDrawer(
        rootName:
            sync.settings.folder?.name ??
            sync.settings.drive?.folderName ??
            context.l10n.rootFolder,
        folders: folderNames,
        counts: {
          for (final name in ['', ...folderNames]) name: _countIn(name),
        },
        selected: folder,
        onSelected: _openFolder,
        onCreate: _createFolder,
      ),
      onDrawerChanged: (opened) {
        if (opened) _syncStorage();
      },
      // Mientras se graba no se cambia de carpeta.
      drawerEnableOpenDragGesture: !_recorder.isBusy,
      // También se abre deslizando hacia la derecha en cualquier punto de la
      // lista, no solo desde el borde.
      body: _SwipeToOpenDrawer(
        enabled: !_recorder.isBusy,
        onOpen: () => _scaffoldKey.currentState?.openDrawer(),
        child: _buildBody(folder),
      ),
      bottomNavigationBar: RecordPanel(
        controller: _recorder,
        countdownSeconds: widget.sync.settings.countdownSeconds,
        onRecordPressed: _onRecordPressed,
        onCancelPressed: _confirmCancel,
        onCountdownPressed: _startAfterCountdown,
        onVoicePressed: _startWhenVoice,
      ),
    );

    // Evita salir de la app por accidente en mitad de una grabación. En una
    // subcarpeta, «atrás» vuelve a la principal.
    return PopScope(
      canPop: !_recorder.isBusy && folder.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_recorder.pending != null) {
          _recorder.cancel();
        } else if (_recorder.isActive) {
          _showMessage((l10n) => l10n.stopToLeave);
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
          transcriptions: _transcriptions,
          onCancelTranscription: () => _transcriptions.cancel(recording),
          onTogglePlay: () => _togglePlayback(recording),
          onSeek: (position) => _seek(recording, position),
          onAction: (action, tileContext) =>
              _onAction(recording, action, tileContext),
        );
      },
    );
  }
}

/// Llama a [onOpen] al deslizar hacia la derecha (hacia la izquierda en los
/// idiomas que se escriben de derecha a izquierda) en cualquier punto de
/// [child]. Lo que se arrastra dentro de [child] (p. ej. la onda para saltar)
/// tiene prioridad.
class _SwipeToOpenDrawer extends StatefulWidget {
  const _SwipeToOpenDrawer({
    required this.enabled,
    required this.onOpen,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onOpen;
  final Widget child;

  @override
  State<_SwipeToOpenDrawer> createState() => _SwipeToOpenDrawerState();
}

class _SwipeToOpenDrawerState extends State<_SwipeToOpenDrawer> {
  /// Lo que hay que deslizar para abrir el menú.
  static const _distance = 48.0;

  /// Velocidad a partir de la cual basta con un gesto rápido.
  static const _flingVelocity = 300.0;

  double _dragged = 0;
  bool _opened = false;

  double get _direction =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _open() {
    if (_opened) return;
    _opened = true;
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _dragged = 0;
        _opened = false;
      },
      onHorizontalDragUpdate: (details) {
        _dragged += (details.primaryDelta ?? 0) * _direction;
        if (_dragged > _distance) _open();
      },
      onHorizontalDragEnd: (details) {
        final velocity = (details.primaryVelocity ?? 0) * _direction;
        if (_dragged > 0 && velocity > _flingVelocity) _open();
      },
      child: widget.child,
    );
  }
}

/// Indica en la barra superior si se están guardando las grabaciones o
/// leyendo el destino, o si ha habido errores al hacerlo.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.sync, required this.onPressed});

  final StorageSync sync;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        if (sync.syncing) {
          return IconButton(
            tooltip: context.l10n.syncing,
            icon: const Icon(Icons.sync),
            onPressed: onPressed,
          );
        }
        if (sync.errors.isNotEmpty) {
          return IconButton(
            tooltip: context.l10n.syncFailed,
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
              inFolder
                  ? context.l10n.emptyFolderTitle
                  : context.l10n.noRecordingsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              inFolder
                  ? context.l10n.emptyFolderHint
                  : context.l10n.noRecordingsHint,
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
