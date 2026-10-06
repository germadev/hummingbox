import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/piano_recorder.dart';
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
import '../services/piano_sound.dart';
import '../services/recording_editor.dart';
import '../services/recordings_repository.dart';
import '../services/screen_awake.dart';
import '../services/settings_store.dart';
import '../services/share_service.dart';
import '../services/storage_sync.dart';
import '../services/transcriber.dart';
import '../utils/languages.dart';
import '../utils/recording_names.dart';
import '../utils/search.dart';
import '../widgets/dialogs.dart';
import '../widgets/folder_drawer.dart';
import '../widgets/piano.dart';
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
    required this.piano,
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

  /// Sonido de las teclas del piano.
  final PianoSound piano;

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

  /// Graba desde el piano (con la misma grabadora, si es con voz).
  late final PianoRecorder _pianoRecorder = PianoRecorder(
    voice: _recorder,
    editor: widget.editor,
  );

  /// Qué se graba desde el piano: se conserva al cerrarlo.
  final _pianoMode = ValueNotifier(PianoRecordingMode.piano);

  /// La grabación a la que se va a añadir piano, si se ha abierto el piano
  /// para acompañarla (hasta que se cierra).
  final _pianoTarget = ValueNotifier<Recording?>(null);

  late final PlayerController _player = PlayerController(
    player: widget.playerFactory(),
    audioPath: widget.sync.audioPath,
    // Con «reproducir lista», sigue con la siguiente de las que se ven.
    queue: () => _visibleRecordings,
  );
  late final TranscriptionController _transcriptions = TranscriptionController(
    transcriber: widget.transcriber,
    repository: widget.repository,
  );

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<int> _changes;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Búsqueda en los nombres y las transcripciones.
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// Si se muestra el campo de búsqueda (al pulsar la lupa o tirar de la
  /// lista hacia abajo; se cierra al perder el foco sin nada escrito).
  bool _searchOpen = false;

  /// Cuánto se ha tirado de la lista hacia abajo: la lupa de la barra lo
  /// indica.
  final _pull = ValueNotifier(_Pull.none);

  /// Parte ampliada del piano: se conserva al cerrarlo.
  final _pianoFirstKey = ValueNotifier(PianoPanel.initialFirstKey);

  /// Teclas blancas de la parte ampliada: se conservan al cerrarlo.
  final _pianoKeyCount = ValueNotifier(PianoPanel.initialKeyCount);

  /// Cómo se gira el piano con la pantalla en vertical: se conserva al
  /// cerrarlo.
  final _pianoPortraitTurns = ValueNotifier(1);

  /// Todas las grabaciones, de todas las carpetas, de la más antigua a la
  /// más reciente.
  List<Recording> _recordings = const [];
  bool _loading = true;

  /// Desplazamiento de la lista: las grabaciones más recientes están al
  /// final.
  final _scroll = ScrollController();

  /// Lo que muestra la lista (la carpeta o los resultados de la búsqueda):
  /// al cambiar, la de una carpeta se muestra desde el final.
  Object? _shownList;

  /// Si ya se puede transcribir automáticamente: tras leer el destino la
  /// primera vez, para no adelantarse a los `.txt` que ya hay.
  bool _autoTranscriptionReady = false;

  /// Por qué se ha detenido la transcripción automática (p. ej. si el
  /// reconocimiento del sistema no está disponible), hasta que cambien las
  /// opciones o se vuelva a la app.
  TranscriptionException? _autoTranscriptionStopped;

  /// Errores de la transcripción automática ya avisados en esta sesión.
  final _reportedAutoErrors = <TranscriptionError>{};

  /// Grabaciones que no se transcriben automáticamente hasta el próximo
  /// arranque: falló o se canceló.
  final _autoTranscriptionSkipped = <String>{};

  /// Opciones de la transcripción con las que se transcribe automáticamente
  /// (si cambian, se vuelve a empezar).
  TranscriptionSettings? _transcriptionSettings;

  /// Subcarpeta abierta; vacío para la principal.
  String get _folder => widget.sync.settings.openFolder;

  @override
  void initState() {
    super.initState();
    // Al volver a la app se guarda lo pendiente y se buscan cambios en el
    // destino.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _changes = widget.sync.changes.listen(_onStorageChanged);
    _recorder.addListener(_updateScreen);
    _player.addListener(_onPlayerChangedWhileAccompanying);
    _recorder.addListener(_pauseAutoTranscription);
    widget.sync.addListener(_updateScreen);
    widget.sync.addListener(_onSettingsChanged);
    _search.addListener(_onSearchChanged);
    _searchFocus.addListener(_onSearchFocusChanged);
    widget.sync.load();
    widget.whisper.load();
    _loadRecordings();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _changes.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _pull.dispose();
    _pianoFirstKey.dispose();
    _pianoKeyCount.dispose();
    _pianoPortraitTurns.dispose();
    _pianoMode.dispose();
    _pianoTarget.dispose();
    _pianoRecorder.dispose();
    _scroll.dispose();
    widget.sync.removeListener(_updateScreen);
    widget.sync.removeListener(_onSettingsChanged);
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
    unawaited(_syncThenTranscribe());
    await _addMissingDetails();
  }

  /// Lee el destino y después empieza a transcribir automáticamente.
  Future<void> _syncThenTranscribe() async {
    try {
      await widget.sync.sync();
    } catch (_) {
      // Se transcribe igualmente.
    }
    _autoTranscriptionReady = true;
    _transcriptionSettings ??= widget.sync.settings.transcription;
    await _transcribeMissing();
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

  /// Al volver a la app se guarda lo pendiente, se buscan cambios en el
  /// destino y después se reanuda la transcripción automática (p. ej. si se
  /// ha dado un permiso o descargado un idioma en los ajustes del sistema).
  void _onResume() {
    _autoTranscriptionStopped = null;
    unawaited(_syncThenTranscribe());
  }

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
    if (added > 0) {
      _scrollToEnd(animate: true);
      _showMessage((l10n) => l10n.newRecordingsFound(added));
    }
    unawaited(_addMissingDetails());
    unawaited(_transcribeMissing());
  }

  /// Lleva la lista al final, donde están las grabaciones más recientes (no
  /// en los resultados de una búsqueda), cuando se haya dibujado.
  void _scrollToEnd({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_query.isEmpty || !_scroll.hasClients) return;
      if (animate) {
        final position = _scroll.position;
        await position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      // La altura de las grabaciones que aún no se han dibujado es estimada:
      // al dibujarlas puede crecer, y se vuelve a bajar hasta el final.
      for (var i = 0; i < 10; i++) {
        if (!mounted || !_scroll.hasClients) return;
        final position = _scroll.position;
        if (position.pixels >= position.maxScrollExtent) return;
        position.jumpTo(position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  // --- Búsqueda ---

  /// Abre el campo de búsqueda con el foco (o le da el foco, si ya está).
  /// Si ya lo tiene, vuelve a mostrar el teclado, que se puede haber ocultado
  /// (p. ej. con «atrás» en Android).
  void _startSearch() {
    if (!_searchOpen) {
      setState(() => _searchOpen = true);
    } else if (_searchFocus.hasFocus) {
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    } else {
      _searchFocus.requestFocus();
    }
  }

  void _closeSearch() {
    _search.clear();
    _searchFocus.unfocus();
    setState(() => _searchOpen = false);
  }

  void _onSearchChanged() => setState(() {});

  SearchQuery? _lastQuery;

  /// Lo que se busca. Se reutiliza mientras no cambie, para no repetir las
  /// comparaciones con las palabras parecidas.
  SearchQuery get _query {
    final text = _search.text;
    final similar = widget.sync.settings.searchSimilarWords;
    if (_lastQuery case final query?
        when query.text == text && query.similar == similar) {
      return query;
    }
    return _lastQuery = SearchQuery(text, similar: similar);
  }

  /// Al tocar el fondo de la lista (fuera de las grabaciones): se quita el
  /// foco del campo de búsqueda (y el teclado; sin nada escrito, se cierra) y
  /// se deselecciona la grabación, salvo que esté sonando (para no cortarla
  /// por un toque sin querer).
  void _onBackgroundTapped() {
    _searchFocus.unfocus();
    if (_player.status != PlaybackStatus.playing) unawaited(_player.stop());
  }

  /// Sin nada escrito, el campo se cierra al perder el foco.
  void _onSearchFocusChanged() {
    if (!_searchFocus.hasFocus && _search.text.trim().isEmpty && _searchOpen) {
      setState(() => _searchOpen = false);
    }
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

  // --- Piano ---

  void _onPianoChanged(bool opened) {
    // Al cerrarlo mientras se graba, se guarda lo grabado.
    if (!opened && _pianoRecorder.isRecording) {
      unawaited(_stopPianoRecording());
    }
    if (!opened) _pianoTarget.value = null;
  }

  /// Abre el piano para tocar sobre [recording] mientras suena.
  void _openPianoOver(Recording recording) {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToPlay);
      return;
    }
    _pianoTarget.value = recording;
    _scaffoldKey.currentState?.openEndDrawer();
  }

  /// Mientras se acompaña una grabación, al terminar de sonar (o si se para)
  /// se guarda lo tocado.
  void _onPlayerChangedWhileAccompanying() {
    final target = _pianoRecorder.target;
    if (target == null || _pianoRecorder.isSaving) return;
    if (!_player.isPlayingOrPaused || !_player.isCurrent(target)) {
      unawaited(_stopPianoRecording());
    }
  }

  /// Empieza a grabar desde el piano: sobre la grabación que se acompaña, si
  /// se abrió para eso, o según [mode]. Con voz, para la reproducción (el
  /// micrófono la grabaría). Devuelve el aviso que se muestra en el piano si
  /// no se puede empezar.
  Future<String?> _startPianoRecording(PianoRecordingMode mode) async {
    final l10n = context.l10n;
    if (_pianoTarget.value case final target?) {
      // Suena desde el principio, sin seguir con otra al terminar.
      try {
        await _pianoRecorder.startOver(
          _latest(target),
          play: () async {
            _player.autoAdvance = false;
            await _player.stop();
            await _player.playFrom(_latest(target), Duration.zero);
          },
        );
      } catch (_) {
        _player.autoAdvance = true;
        return l10n.playFailed;
      }
      return null;
    }
    if (mode == PianoRecordingMode.pianoAndVoice) await _player.stop();
    try {
      final started = await _pianoRecorder.start(
        mode,
        options: widget.sync.settings.recording,
        folder: _folder,
      );
      return started ? null : l10n.microphonePermission;
    } catch (_) {
      return l10n.startRecordingFailed;
    }
  }

  /// Termina la grabación del piano y la añade a la lista.
  Future<Recording?> _stopPianoRecording() async {
    final accompanying = _pianoRecorder.target != null;
    Recording? recording;
    try {
      if (accompanying) {
        // Se para antes de cambiar su audio.
        _player.autoAdvance = true;
        await _player.stop();
      }
      recording = await _pianoRecorder.stop();
    } catch (_) {
      recording = null;
    }
    if (!mounted || recording == null) return null;
    final saved = recording;
    if (_recordings.any((r) => r.id == saved.id)) {
      _replaceRecording(saved);
      _showMessage((l10n) => l10n.pianoAdded(saved.name));
    } else {
      _addNew(saved);
      _showMessage((l10n) => l10n.savedAs(saved.name));
    }
    _syncStorage();
    unawaited(_transcribeMissing());
    return saved;
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
    _addNew(saved);
    _showMessage((l10n) => l10n.savedAs(saved.name));
    _syncStorage();
    unawaited(_transcribeMissing());
  }

  /// Añade a la lista una grabación que se acaba de hacer: al final,
  /// seleccionada (con su transcripción a la vista) y bajando hasta ella.
  void _addNew(Recording recording) {
    setState(() => _recordings = [..._recordings, recording]);
    _player.select(recording);
    _scrollToEnd(animate: true);
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

  /// Selecciona [recording] sin reproducirla: suena con su botón.
  void _select(Recording recording) => unawaited(_player.pick(recording));

  /// Salta a [position] de [recording]: si no es la seleccionada, la
  /// selecciona ahí, sin reproducirla.
  void _seek(Recording recording, Duration position) {
    if (_player.isCurrent(recording)) {
      _player.seek(position);
    } else {
      unawaited(_player.pick(recording, position: position));
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
    unawaited(_transcribeMissing());
  }

  Future<void> _onAction(
    Recording recording,
    RecordingAction action,
    BuildContext tileContext,
  ) async {
    switch (action) {
      case RecordingAction.edit:
        await _edit(recording);
      case RecordingAction.addPiano:
        _openPianoOver(recording);
      case RecordingAction.rename:
        await _rename(recording);
      case RecordingAction.transcribe:
        await _transcribe(recording);
      case RecordingAction.viewTranscript:
        await _viewTranscript(recording);
      case RecordingAction.transcribeInLanguage:
        await _transcribeInLanguage(recording);
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
    if (result.isCopy) {
      _addNew(edited);
    } else {
      setState(() {
        _recordings = [
          for (final r in _recordings) r.id == edited.id ? edited : r,
        ];
      });
    }
    _showMessage(
      (l10n) => result.isCopy ? l10n.savedAs(edited.name) : l10n.changesSaved,
    );
    _syncStorage();
    // La copia, o el audio editado si no tenía transcripción.
    unawaited(_transcribeMissing());
  }

  Future<void> _rename(Recording recording) async {
    final name = await showRenameDialog(context, recording.name);
    if (name == null || name == recording.name) return;
    await _applyName(recording, name);
  }

  /// Cambia el nombre de [recording] (y el de su archivo, al guardarla).
  Future<void> _applyName(Recording recording, String name) async {
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
    unawaited(_transcribeMissing());
  }

  // --- Transcripción ---

  /// Idioma con el que se transcribe [recording]: el elegido para ella, el
  /// de las opciones o el de la app.
  String _transcriptionLanguage(
    TranscriptionSettings settings,
    Recording recording,
  ) {
    final app = Localizations.localeOf(context).languageCode;
    return switch (recording.transcriptionLanguage ?? settings.language) {
      TranscriptionSettings.appLanguage => app,
      // Solo Whisper sabe detectarlo.
      TranscriptionSettings.detectLanguage =>
        settings.engine == TranscriptionEngine.whisper
            ? TranscriptionSettings.detectLanguage
            : app,
      final language => language,
    };
  }

  /// La versión de [recording] de la lista, que puede estar más al día.
  Recording _latest(Recording recording) =>
      _recordings.where((r) => r.id == recording.id).firstOrNull ?? recording;

  /// Transcribe [recording] con lo elegido en las opciones (y su idioma, si
  /// se ha elegido uno para ella). Si no se puede, explica por qué y qué
  /// hacer.
  ///
  /// Si ya tenía transcripción o se ha cambiado su idioma
  /// ([languageChanged]), pregunta si pasa a llamarse como empieza la nueva
  /// (la primera vez, con el nombre provisional, cambia sin preguntar).
  Future<void> _transcribe(
    Recording recording, {
    bool languageChanged = false,
  }) async {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToTranscribe);
      return;
    }
    await widget.sync.load();
    if (!mounted) return;
    final settings = widget.sync.settings.transcription;
    final current = _latest(recording);
    try {
      final transcribed = await _transcriptions.transcribe(
        current,
        engine: settings.engine,
        language: _transcriptionLanguage(settings, current),
      );
      if (!mounted) return;
      _replaceRecording(transcribed);
      // Se guarda como .txt junto al audio.
      _syncStorage();
      // Si la automática se había detenido, ya se puede.
      if (_autoTranscriptionStopped != null) _resumeAutoTranscription();
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
      if (languageChanged || current.transcript != null) {
        await _offerTranscriptName(transcribed);
      }
    } on TranscriptionException catch (e) {
      await _explainTranscriptionError(e, current);
    } catch (_) {
      _showMessage((l10n) => l10n.transcriptionFailed);
    }
  }

  /// Valor del diálogo del idioma de una grabación para usar el de las
  /// opciones (en la grabación, `null`).
  static const _sameAsSettings = '';

  /// Pregunta en qué idioma se transcribe [recording], lo guarda con ella y
  /// la vuelve a transcribir en él.
  Future<void> _transcribeInLanguage(Recording recording) async {
    if (_recorder.isBusy) {
      _showMessage((l10n) => l10n.stopToTranscribe);
      return;
    }
    await widget.sync.load();
    if (!mounted) return;
    final l10n = context.l10n;
    final settings = widget.sync.settings.transcription;
    final current = _latest(recording);
    final language = await showChoiceDialog(
      context,
      title: l10n.recordingLanguage,
      selected: current.transcriptionLanguage ?? _sameAsSettings,
      choices: [
        Choice(
          _sameAsSettings,
          l10n.sameAsSettings,
          subtitle: transcriptionLanguageTitle(
            settings.language,
            l10n,
            appLanguage: Localizations.localeOf(context).languageCode,
          ),
        ),
        Choice(TranscriptionSettings.detectLanguage, l10n.detectLanguageOption),
        for (final code in transcriptionLanguages)
          Choice(code, languageName(code)),
      ],
    );
    if (language == null || !mounted) return;
    final Recording updated;
    try {
      updated = await widget.repository.setTranscriptionLanguage(
        current,
        language == _sameAsSettings ? null : language,
      );
    } catch (_) {
      _showMessage((l10n) => l10n.transcriptionFailed);
      return;
    }
    _replaceRecording(updated);
    await _transcribe(updated, languageChanged: true);
  }

  /// Pregunta si [recording] pasa a llamarse con su fecha y el principio de
  /// su transcripción (p. ej. al volver a transcribirla), si no se llama ya
  /// así.
  Future<void> _offerTranscriptName(Recording recording) async {
    final text = recording.transcript?.text;
    if (text == null) return;
    final proposed = RecordingNames.fromTranscript(recording.createdAt, text);
    if (proposed == null) return;
    final name = RecordingNames.unique(proposed, [
      for (final r in _recordings)
        if (r.folder == recording.folder && r.id != recording.id) r.name,
    ]);
    if (name == recording.name) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.renameToTranscriptTitle,
      message: l10n.renameToTranscriptMessage(recording.name, name),
      confirmLabel: l10n.rename,
      cancelLabel: l10n.keepName,
    );
    if (!confirmed || !mounted) return;
    await _applyName(_latest(recording), name);
  }

  // --- Transcripción automática ---

  /// Transcribe en segundo plano las grabaciones que no tienen transcripción
  /// (si está activado en las opciones), de la más reciente a la más antigua.
  /// Las de Google Drive que no se han descargado se dejan para cuando se
  /// descarguen (p. ej. al escucharlas).
  Future<void> _transcribeMissing() async {
    if (!_autoTranscriptionReady) return;
    if (_findingTranscriptions) {
      // Se repite al terminar para incluir las que han llegado entretanto.
      _transcriptionsPending = true;
      return;
    }
    _findingTranscriptions = true;
    try {
      do {
        _transcriptionsPending = false;
        await widget.sync.load();
        // De la más reciente a la más antigua.
        for (final recording in _recordings.reversed) {
          if (!mounted || !_autoTranscribing) return;
          if (!_needsAutoTranscript(recording)) continue;
          if (!await widget.sync.hasLocalAudio(recording)) continue;
          // Puede haber cambiado entretanto (o haberse detenido).
          if (!mounted || !_autoTranscribing) return;
          final current = _recordings
              .where((r) => r.id == recording.id)
              .firstOrNull;
          if (current != null && _needsAutoTranscript(current)) {
            _transcribeInBackground(current);
          }
        }
      } while (_transcriptionsPending && mounted);
    } finally {
      _findingTranscriptions = false;
    }
  }

  bool _findingTranscriptions = false;
  bool _transcriptionsPending = false;

  /// Indica si se transcribe automáticamente ahora.
  bool get _autoTranscribing =>
      widget.sync.settings.transcription.automatic &&
      _autoTranscriptionStopped == null;

  bool _needsAutoTranscript(Recording recording) =>
      recording.needsTranscript &&
      !_autoTranscriptionSkipped.contains(recording.id) &&
      !_transcriptions.isTranscribing(recording);

  void _transcribeInBackground(Recording recording) {
    final settings = widget.sync.settings.transcription;
    unawaited(
      _transcriptions
          .transcribeInBackground(
            recording,
            engine: settings.engine,
            language: _transcriptionLanguage(settings, recording),
          )
          .then(
            _onTranscribedInBackground,
            onError: (Object error) =>
                _onAutoTranscriptionFailed(recording, error),
          ),
    );
  }

  void _onTranscribedInBackground(Recording? transcribed) {
    // `null` si se ha pedido entretanto (lo recibe quien lo pidió) o se ha
    // retirado.
    if (transcribed == null || !mounted) return;
    _replaceRecording(transcribed);
    // Se guarda como .txt junto al audio.
    _syncStorage();
  }

  Future<void> _onAutoTranscriptionFailed(
    Recording recording,
    Object error,
  ) async {
    if (!mounted) return;
    final exception = error is TranscriptionException
        ? error
        : TranscriptionException(TranscriptionError.failed, cause: error);
    switch (exception.error) {
      case TranscriptionError.noSpeech:
        // No se vuelve a intentar hasta que cambie el audio (salvo que
        // entretanto se haya transcrito o editado).
        final current = _recordings
            .where((r) => r.id == recording.id)
            .firstOrNull;
        if (current == null ||
            current.transcript != null ||
            current.revision != recording.revision) {
          return;
        }
        try {
          _replaceRecording(
            await widget.repository.setTranscript(current, null),
          );
        } catch (_) {
          _autoTranscriptionSkipped.add(recording.id);
        }
      case TranscriptionError.canceled:
      case TranscriptionError.failed:
        _autoTranscriptionSkipped.add(recording.id);
      // Con el idioma elegido para la grabación: solo afecta a ella.
      case TranscriptionError.unsupportedLanguage ||
              TranscriptionError.needsDownload ||
              TranscriptionError.downloading
          when recording.transcriptionLanguage != null:
        _autoTranscriptionSkipped.add(recording.id);
      case TranscriptionError.downloading:
        // Se reanuda al volver a la app.
        _stopAutoTranscription(recording, exception, report: false);
      case TranscriptionError.systemUnavailable:
      case TranscriptionError.unsupportedLanguage:
      case TranscriptionError.needsDownload:
      case TranscriptionError.denied:
      case TranscriptionError.microphone:
      case TranscriptionError.whisperNotInstalled:
        _stopAutoTranscription(recording, exception);
    }
  }

  /// Detiene la transcripción automática por [error] (al transcribir
  /// [recording]), que afectaría a todas, y lo avisa (una vez por sesión) con
  /// la opción de ver por qué.
  void _stopAutoTranscription(
    Recording recording,
    TranscriptionException error, {
    bool report = true,
  }) {
    _autoTranscriptionStopped = error;
    _transcriptions.cancelBackground();
    if (!report || !_reportedAutoErrors.add(error.error) || !mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.autoTranscriptionFailed),
          action: SnackBarAction(
            label: l10n.view,
            onPressed: () => _explainTranscriptionError(error, recording),
          ),
        ),
      );
  }

  void _resumeAutoTranscription() {
    _autoTranscriptionStopped = null;
    unawaited(_transcribeMissing());
  }

  /// Mientras se graba, la transcripción automática espera.
  void _pauseAutoTranscription() {
    _transcriptions.backgroundPaused = _recorder.isBusy;
  }

  /// Si cambian las opciones de la transcripción, vuelve a empezar con las
  /// nuevas (o se detiene, si se ha desactivado).
  void _onSettingsChanged() {
    if (!widget.sync.isLoaded) return;
    final settings = widget.sync.settings.transcription;
    final previous = _transcriptionSettings;
    _transcriptionSettings = settings;
    if (previous == null || previous == settings) return;
    _transcriptions.cancelBackground();
    _reportedAutoErrors.clear();
    _resumeAutoTranscription();
  }

  Future<void> _explainTranscriptionError(
    TranscriptionException e,
    Recording recording,
  ) async {
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
                  _transcriptionLanguage(
                    widget.sync.settings.transcription,
                    recording,
                  ),
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
      case TranscriptAction.transcribeInLanguage:
        await _transcribeInLanguage(current);
      case TranscriptAction.delete:
        try {
          _replaceRecording(
            await widget.repository.setTranscript(current, null),
          );
          // También su .txt del destino.
          _syncStorage();
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

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettingsScreen(sync: widget.sync, whisper: widget.whisper),
      ),
    );
    // P. ej. si se ha instalado Whisper.
    if (mounted) _resumeAutoTranscription();
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
    final searching = _searchOpen;
    final scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // El botón de carpetas.
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          // Mientras se graba no se cambia de carpeta.
          child: IconButton(
            key: const Key('folders-button'),
            tooltip: context.l10n.folders,
            icon: const Icon(Icons.folder_outlined),
            onPressed: _recorder.isBusy
                ? null
                : () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        // La lupa, siempre a la izquierda, junto a las carpetas, y en una
        // subcarpeta su nombre. Al buscar, el campo ocupa desde ahí hasta las
        // opciones, con la lupa en el mismo sitio.
        centerTitle: false,
        titleSpacing: 0,
        title: searching
            ? _SearchField(
                controller: _search,
                focusNode: _searchFocus,
                pull: _pull,
                onClear: _closeSearch,
              )
            : Row(
                children: [
                  _SearchButton(pull: _pull, onPressed: _startSearch),
                  if (folder.isNotEmpty)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Text(
                          folder,
                          key: const Key('folder-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                ],
              ),
        actions: [
          if (!searching)
            _SyncIndicator(sync: widget.sync, onPressed: _openSettings),
          // Vista compacta o detallada de la lista, donde al buscar está la
          // X del campo. Muestra la vista a la que cambia.
          if (!searching)
            IconButton(
              key: const Key('view-mode-button'),
              tooltip: sync.settings.compactList
                  ? context.l10n.detailedView
                  : context.l10n.compactView,
              icon: Icon(
                sync.settings.compactList
                    ? Icons.view_agenda_outlined
                    : Icons.view_headline,
              ),
              onPressed: () => unawaited(
                widget.sync.setCompactList(!sync.settings.compactList),
              ),
            ),
          IconButton(
            key: const Key('settings-button'),
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Se abre deslizando hacia la derecha en la lista (ver
      // [_SwipeToOpenDrawers]) o con su botón. Al abrirlo se buscan
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
        // Mientras se graba no se abre el piano: su sonido podría cortar la
        // grabación. Al abrirlo se cierra este menú.
        onOpenPiano: _recorder.isBusy
            ? null
            : () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      onDrawerChanged: (opened) {
        if (opened) _syncStorage();
      },
      // No desde el borde, donde se va atrás con los gestos del sistema.
      drawerEnableOpenDragGesture: false,
      // El piano, que se abre deslizando hacia la izquierda y ocupa todo el
      // ancho.
      endDrawer: Drawer(
        key: const Key('piano-drawer'),
        width: MediaQuery.sizeOf(context).width,
        shape: const RoundedRectangleBorder(),
        child: PianoPanel(
          sound: widget.piano,
          firstKey: _pianoFirstKey,
          keyCount: _pianoKeyCount,
          instrument: sync.settings.instrument,
          onInstrumentChanged: (instrument) =>
              unawaited(widget.sync.setInstrument(instrument)),
          synth: sync.settings.synth,
          onSynthChanged: (synth) => unawaited(widget.sync.setSynth(synth)),
          recorder: _pianoRecorder,
          mode: _pianoMode,
          target: _pianoTarget,
          portraitTurns: _pianoPortraitTurns,
          onRecord: _startPianoRecording,
          onStop: _stopPianoRecording,
          onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        ),
      ),
      // No desde el borde, donde se va atrás con los gestos del sistema: se
      // abre deslizando en la lista (ver [_SwipeToOpenDrawers]).
      endDrawerEnableOpenDragGesture: false,
      onEndDrawerChanged: _onPianoChanged,
      // Se abren deslizando en cualquier punto de la lista salvo junto a los
      // bordes: hacia la derecha las carpetas y hacia la izquierda el piano.
      // Mientras se graba, ninguno.
      body: _SwipeToOpenDrawers(
        enabled: !_recorder.isBusy,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenEndDrawer: () => _scaffoldKey.currentState?.openEndDrawer(),
        // Los toques en las grabaciones no llegan aquí.
        child: GestureDetector(
          key: const Key('list-background'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _onBackgroundTapped,
          child: _buildBody(folder),
        ),
      ),
      bottomNavigationBar: RecordPanel(
        controller: _recorder,
        countdownSeconds: widget.sync.settings.countdownSeconds,
        player: _player,
        onStopPlayback: () => unawaited(_player.stop()),
        // Como el fondo de la lista: quita el foco del campo de búsqueda y,
        // fuera de los botones, la selección.
        onTouched: _searchFocus.unfocus,
        onBackgroundTapped: _onBackgroundTapped,
        onRecordPressed: _onRecordPressed,
        onCancelPressed: _confirmCancel,
        onCountdownPressed: _startAfterCountdown,
        onVoicePressed: _startWhenVoice,
        selectionActions: (context) {
          final id = _player.currentId;
          final selected = _recordings.where((r) => r.id == id).firstOrNull;
          if (selected == null) return null;
          return RecordingActionsBar(
            key: ValueKey(selected.id),
            recording: selected,
            transcriptions: _transcriptions,
            onAction: (action, buttonContext) =>
                _onAction(selected, action, buttonContext),
          );
        },
      ),
    );

    // «Atrás» lo decide siempre la app (ver [_onBack]).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: scaffold,
    );
  }

  /// «Atrás» del sistema, de lo más concreto a lo más general: cierra el
  /// piano; quita el foco del campo de búsqueda y después la selección de la
  /// grabación; cierra la búsqueda; en una subcarpeta vuelve a la principal
  /// y en la principal abre el menú de las carpetas. Con ese menú abierto en
  /// la principal, se sale de la app. En mitad de una grabación no se sale.
  Future<void> _onBack() async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return;
    if (scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    } else if (scaffold.isDrawerOpen) {
      if (_folder.isEmpty) {
        await SystemNavigator.pop();
      } else {
        scaffold.closeDrawer();
      }
    } else if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
    } else if (_player.currentId != null) {
      await _player.stop();
    } else if (_searchOpen) {
      _closeSearch();
    } else if (_recorder.pending != null) {
      await _recorder.cancel();
    } else if (_recorder.isActive) {
      _showMessage((l10n) => l10n.stopToLeave);
    } else if (_folder.isNotEmpty) {
      await _openFolder('');
    } else {
      scaffold.openDrawer();
    }
  }

  int _countIn(String folder) =>
      _recordings.where((recording) => recording.folder == folder).length;

  /// Las grabaciones que se ven, en orden: las de la carpeta abierta o, al
  /// buscar, de todas las carpetas, primero las que tienen las palabras tal
  /// cual y después las que tienen alguna parecida.
  List<Recording> get _visibleRecordings {
    final query = _query;
    if (query.isEmpty) {
      return [
        for (final recording in _recordings)
          if (recording.folder == _folder) recording,
      ];
    }
    final matches = {
      for (final recording in _recordings) recording: query.matchOf(recording),
    };
    return [
      for (final kind in [SearchMatch.exact, SearchMatch.similar])
        for (final MapEntry(key: recording, value: match) in matches.entries)
          if (match == kind) recording,
    ];
  }

  Widget _buildBody(String folder) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final query = _query;
    final searching = !query.isEmpty;
    final recordings = _visibleRecordings;
    // Al abrir la app o una carpeta (o al terminar de buscar), desde el
    // final, con las más recientes; los resultados, desde el principio.
    final Object shown = searching ? const _SearchResults() : folder;
    if (shown != _shownList) {
      _shownList = shown;
      if (!searching) _scrollToEnd();
    }
    final l10n = context.l10n;
    // Tirando hacia abajo desde arriba de la lista se busca.
    return _PullToSearch(
      pull: _pull,
      onPull: _startSearch,
      child: recordings.isEmpty
          ? switch ((searching, folder.isEmpty)) {
              (true, _) => _EmptyState(
                icon: Icons.search_off,
                title: l10n.noSearchResultsTitle,
                hint: l10n.noSearchResultsHint(_search.text.trim()),
              ),
              (false, true) => _EmptyState(
                icon: Icons.mic_none_rounded,
                title: l10n.noRecordingsTitle,
                hint: l10n.noRecordingsHint,
              ),
              (false, false) => _EmptyState(
                icon: Icons.folder_open,
                title: l10n.emptyFolderTitle,
                hint: l10n.emptyFolderHint,
              ),
            }
          : _buildList(recordings, shown, searching ? query : null),
    );
  }

  /// Margen bajo la última grabación: cabe un aviso de dos líneas.
  static const _listBottomPadding = 88.0;

  Widget _buildList(
    List<Recording> recordings,
    Object shown,
    SearchQuery? query,
  ) {
    return ListView.builder(
      // Una lista nueva para cada carpeta y para los resultados.
      key: ValueKey(shown),
      controller: _scroll,
      // También con pocas grabaciones, para poder tirar hacia abajo.
      physics: _PullToSearch.physics,
      // Abajo, sitio para los avisos (p. ej. «Guardada como…»), que salen
      // encima del panel de grabar: la última grabación queda por encima.
      padding: const EdgeInsets.only(top: 8, bottom: _listBottomPadding),
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final recording = recordings[index];
        return RecordingTile(
          key: ValueKey(recording.id),
          recording: recording,
          player: _player,
          transcriptions: _transcriptions,
          search: query,
          // En los resultados de una búsqueda, su subcarpeta.
          showFolder: query != null,
          compact: widget.sync.settings.compactList,
          onCancelTranscription: () => _transcriptions.cancel(recording),
          onTogglePlay: () => _togglePlayback(recording),
          onSelect: () => _select(recording),
          onSeek: (position) => _seek(recording, position),
          onAction: (action, tileContext) =>
              _onAction(recording, action, tileContext),
        );
      },
    );
  }
}

/// Llama a [onOpenDrawer] al deslizar hacia la derecha y a [onOpenEndDrawer]
/// al deslizar hacia la izquierda (al revés en los idiomas que se escriben
/// de derecha a izquierda) en cualquier punto de [child]. Lo que se arrastra
/// dentro de [child] (p. ej. la onda para saltar) tiene prioridad.
class _SwipeToOpenDrawers extends StatefulWidget {
  const _SwipeToOpenDrawers({
    required this.enabled,
    required this.onOpenDrawer,
    required this.onOpenEndDrawer,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenEndDrawer;
  final Widget child;

  @override
  State<_SwipeToOpenDrawers> createState() => _SwipeToOpenDrawersState();
}

class _SwipeToOpenDrawersState extends State<_SwipeToOpenDrawers> {
  /// Lo que hay que deslizar para abrir el menú.
  static const _distance = 48.0;

  /// Velocidad a partir de la cual basta con un gesto rápido.
  static const _flingVelocity = 300.0;

  /// Margen junto a los bordes izquierdo y derecho en el que deslizar no
  /// abre nada: desde el borde se va atrás con los gestos del sistema. Si
  /// el sistema reserva más, lo suyo.
  static const edgeMargin = 32.0;

  double _dragged = 0;
  bool _opened = false;

  /// Si el gesto empezó junto a un borde: no abre nada.
  bool _fromEdge = false;

  double get _direction =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  /// Abre el menú de las carpetas si [forward] (hacia la derecha) o, si no,
  /// el piano.
  void _open({required bool forward}) {
    if (_opened || _fromEdge) return;
    _opened = true;
    (forward ? widget.onOpenDrawer : widget.onOpenEndDrawer)();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: (details) {
        final width = MediaQuery.sizeOf(context).width;
        final insets = MediaQuery.systemGestureInsetsOf(context);
        final x = details.globalPosition.dx;
        _fromEdge =
            x <= math.max(edgeMargin, insets.left) ||
            x >= width - math.max(edgeMargin, insets.right);
      },
      onHorizontalDragStart: (_) {
        _dragged = 0;
        _opened = false;
      },
      onHorizontalDragUpdate: (details) {
        _dragged += (details.primaryDelta ?? 0) * _direction;
        if (_dragged.abs() > _distance) _open(forward: _dragged > 0);
      },
      onHorizontalDragEnd: (details) {
        final velocity = (details.primaryVelocity ?? 0) * _direction;
        if (_dragged > 0 && velocity > _flingVelocity) {
          _open(forward: true);
        } else if (_dragged < 0 && velocity < -_flingVelocity) {
          _open(forward: false);
        }
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

/// Lista vacía: sin grabaciones, carpeta vacía o búsqueda sin resultados.
/// Se puede desplazar, para que tirar hacia abajo también funcione aquí.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: _PullToSearch.physics,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de búsqueda de la barra superior: la lupa a la izquierda (la que
/// baja al tirar de la lista), el texto y la X para borrar y cerrar, todo
/// centrado en vertical como los botones de la barra.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.pull,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<_Pull> pull;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      key: const Key('search-field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        prefixIcon: _SearchButton(pull: pull),
        suffixIcon: IconButton(
          tooltip: l10n.clearSearch,
          icon: const Icon(Icons.close),
          onPressed: onClear,
        ),
      ),
    );
  }
}

/// Lo que muestra la lista mientras se busca: los resultados, de todas las
/// carpetas.
@immutable
class _SearchResults {
  const _SearchResults();
}

/// Cuánto se ha tirado de la lista hacia abajo para buscar.
@immutable
class _Pull {
  const _Pull(this.distance, {this.armed = false});

  static const none = _Pull(0);

  /// Lo que ha bajado la lista.
  final double distance;

  /// Si se ha pasado el punto: al soltar, se busca.
  final bool armed;

  double get progress =>
      (distance / _PullToSearch.distance).clamp(0.0, 1.0).toDouble();

  @override
  bool operator ==(Object other) =>
      other is _Pull && other.distance == distance && other.armed == armed;

  @override
  int get hashCode => Object.hash(distance, armed);
}

/// Llama a [onPull] al tirar de [child] hacia abajo cuando ya está arriba del
/// todo y soltar tras pasar un punto ([distance]); si se suelta antes, no
/// hace nada. Mientras tanto, publica en [pull] lo que se ha tirado, para que
/// la lupa de la barra lo indique.
///
/// La lista baja (rebota también en Android) y en el hueco que deja aparece
/// «Tira para buscar» y, pasado el punto, «Suelta para buscar». Al pasarlo,
/// la lupa se pone del color principal y el móvil vibra; volviendo a subir
/// antes de soltar se cancela.
class _PullToSearch extends StatefulWidget {
  const _PullToSearch({
    required this.pull,
    required this.onPull,
    required this.child,
  });

  /// Desplazamiento de la lista y de los estados vacíos: siempre se pueden
  /// desplazar (también con pocas grabaciones) y rebotan, para que la lista
  /// baje al tirar.
  static const physics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  /// Lo que tiene que bajar la lista para buscar al soltarla.
  static const distance = 72.0;

  final ValueNotifier<_Pull> pull;
  final VoidCallback onPull;
  final Widget child;

  @override
  State<_PullToSearch> createState() => _PullToSearchState();
}

class _PullToSearchState extends State<_PullToSearch> {
  /// Si se está arrastrando la lista.
  bool _dragging = false;

  /// Si se ha tirado de la lista (y no ha rebotado al llegar arriba
  /// deslizándola): solo entonces baja la lupa.
  bool _pulling = false;

  /// Si el arrastre empezó con la lista arriba del todo: solo así se busca
  /// al tirar (no al llegar arriba subiendo por la lista con el mismo
  /// arrastre).
  bool _fromTop = false;

  bool get _armed => widget.pull.value.armed;

  /// Si ya se ha buscado al soltar: mientras la lista vuelve a su sitio, la
  /// lupa ya no indica nada (pasa directamente a no tener fondo).
  bool _searched = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    final pulled = math.max(0.0, metrics.minScrollExtent - metrics.pixels);
    var armed = _armed;
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _dragging = dragDetails != null;
        if (_dragging) {
          armed = false;
          _fromTop = metrics.pixels <= metrics.minScrollExtent + 0.5;
        }
      case ScrollUpdateNotification(:final dragDetails):
        // Al soltar, la lista vuelve a su sitio sin que se arrastre.
        if (_dragging && dragDetails == null) _release();
        if (_dragging && _fromTop) {
          if (pulled > 0) _pulling = true;
          armed = pulled >= _PullToSearch.distance;
        }
      case ScrollEndNotification():
        if (_dragging) _release();
        _pulling = false;
        armed = false;
        _searched = false;
      default:
        break;
    }
    if (_searched) {
      widget.pull.value = _Pull.none;
      return false;
    }
    if (armed && !_armed) unawaited(HapticFeedback.mediumImpact());
    // El color de la lupa se mantiene mientras la lista vuelve a su sitio.
    widget.pull.value = _Pull(_pulling ? pulled : 0, armed: armed);
    return false;
  }

  void _onPointerUp() {
    if (!_dragging) return;
    _release();
    _pulling = false;
  }

  /// Al soltar tras pasar el punto, se busca.
  void _release() {
    _dragging = false;
    if (!_armed) return;
    _searched = true;
    widget.pull.value = _Pull.none;
    widget.onPull();
  }

  /// Margen de la lista sobre la primera grabación: el texto no pasa de ahí.
  static const _listPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    // Al levantar el dedo se busca ya, sin esperar a que la lista empiece a
    // volver a su sitio.
    return Listener(
      onPointerUp: (_) => _onPointerUp(),
      onPointerCancel: (_) => _onPointerUp(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.child,
            // En el hueco que deja la lista al bajar, sin tapar nada.
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<_Pull>(
                  valueListenable: widget.pull,
                  builder: (context, pull, _) {
                    if (pull.distance <= 0) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: pull.distance + _listPadding,
                        child: ClipRect(
                          child: Center(
                            child: Opacity(
                              opacity: pull.progress,
                              child: Text(
                                pull.armed
                                    ? l10n.releaseToSearch
                                    : l10n.pullToSearch,
                                key: const Key('pull-to-search-hint'),
                                maxLines: 1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La lupa de la barra superior: en el centro o, mientras se busca, a la
/// izquierda del campo. Al tirar de la lista hacia abajo ([pull]) aparece
/// detrás de ella un círculo gris claro, que pasa al color principal al
/// pasar el punto en que se busca.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.pull, this.onPressed});

  final ValueNotifier<_Pull> pull;

  /// Al pulsarla; `null` para la del campo de búsqueda, que no es un botón.
  final VoidCallback? onPressed;

  /// Diámetro del círculo.
  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<_Pull>(
      valueListenable: pull,
      builder: (context, pull, _) {
        final icon = Icon(
          Icons.search,
          color: pull.armed ? colors.onPrimary : null,
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            if (pull.distance > 0)
              Opacity(
                opacity: pull.progress,
                child: AnimatedContainer(
                  key: const Key('pull-to-search'),
                  duration: const Duration(milliseconds: 150),
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pull.armed
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                  ),
                ),
              ),
            if (onPressed case final onPressed?)
              IconButton(
                key: const Key('search-button'),
                tooltip: context.l10n.search,
                icon: icon,
                onPressed: onPressed,
              )
            else
              SizedBox.square(dimension: kMinInteractiveDimension, child: icon),
          ],
        );
      },
    );
  }
}
