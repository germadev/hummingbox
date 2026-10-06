import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/audio_edit.dart';
import '../audio/levels.dart';
import '../l10n/l10n.dart';
import '../models/recording.dart';
import '../services/audio_player_service.dart';
import '../services/recording_editor.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/trim_waveform.dart';

/// Resultado de guardar una edición.
class EditResult {
  const EditResult(this.recording, {required this.isCopy});

  /// La grabación editada o, si [isCopy], la copia nueva.
  final Recording recording;
  final bool isCopy;
}

/// Modo de edición: recortar, cambiar el volumen y añadir fundidos.
///
/// Devuelve un [EditResult] al guardar o `null` si se sale sin guardar.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.recording,
    required this.editor,
    required this.playerFactory,
  });

  final Recording recording;
  final RecordingEditor editor;
  final AudioPlayerService Function() playerFactory;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const _minGainDb = -20.0;
  static const _maxGainDb = 20.0;
  static const _maxFade = Duration(seconds: 5);

  /// Pico al que se lleva el audio al normalizar (−1 dBFS).
  static const _normalizedPeak = 0.891;

  late final AudioPlayerService _player = widget.playerFactory();
  late final List<StreamSubscription<Object?>> _subscriptions;

  EditSession? _session;
  bool _failed = false;
  AudioEdit _edit = const AudioEdit(start: Duration.zero, end: Duration.zero);

  /// Mientras se guarda, si se guarda como copia; `null` si no se está
  /// guardando.
  bool? _savingAsCopy;
  bool get _saving => _savingAsCopy != null;

  bool _previewPlaying = false;
  Duration? _playhead;

  /// Archivo de la escucha previa: la selección con el volumen y los
  /// fundidos, generada para [_previewEdit].
  String? _previewPath;
  AudioEdit? _previewEdit;

  /// Posición del original en la que empieza el archivo que suena (el inicio
  /// de la selección, o cero si suena el original).
  Duration _previewOffset = Duration.zero;

  /// Mientras se genera la escucha previa.
  bool _rendering = false;

  /// Aumenta con cada petición de escucha, para descartar las que se han
  /// quedado atrás.
  int _previewRequest = 0;

  /// Regenera la escucha previa poco después de cambiar algo mientras suena.
  Timer? _refreshPreview;

  @override
  void initState() {
    super.initState();
    _subscriptions = [
      _player.statusChanges.listen(_onPreviewStatus),
      _player.positionChanges.listen(_onPreviewPosition),
    ];
    _open();
  }

  @override
  void dispose() {
    _refreshPreview?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    if (_session case final session?) widget.editor.close(session);
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final session = await widget.editor.open(widget.recording);
      if (!mounted) {
        await widget.editor.close(session);
        return;
      }
      if (session.duration <= Duration.zero) {
        await widget.editor.close(session);
        setState(() => _failed = true);
        return;
      }
      setState(() {
        _session = session;
        _edit = AudioEdit(start: Duration.zero, end: session.duration);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _changed {
    final session = _session;
    return session != null && _edit.changes(session.duration);
  }

  // --- Escucha previa ---

  void _onPreviewStatus(PlaybackStatus status) {
    if (!mounted) return;
    setState(() {
      _previewPlaying = status == PlaybackStatus.playing;
      if (status == PlaybackStatus.completed) _playhead = _edit.start;
    });
  }

  void _onPreviewPosition(Duration position) {
    if (!mounted || !_previewPlaying) return;
    final time = position + _previewOffset;
    if (time >= _edit.end) {
      _player.pause();
      setState(() => _playhead = _edit.start);
      return;
    }
    setState(() => _playhead = time);
  }

  Future<void> _togglePreview() async {
    if (_previewPlaying || _rendering) {
      _previewRequest++;
      _refreshPreview?.cancel();
      setState(() => _rendering = false);
      await _player.pause();
      return;
    }
    final playhead = _playhead;
    final from =
        playhead != null && playhead >= _edit.start && playhead < _edit.end
        ? playhead
        : _edit.start;
    setState(() => _playhead = from);
    await _playPreview(from);
  }

  /// Reproduce desde [from] la selección tal como quedará: con el volumen y
  /// los fundidos. Si no los hay, suena el original decodificado.
  Future<void> _playPreview(Duration from) async {
    final session = _session;
    if (session == null) return;
    final request = ++_previewRequest;
    final edit = _edit;

    final String path;
    final Duration offset;
    if (edit.gainDb == 0 &&
        edit.fadeIn == Duration.zero &&
        edit.fadeOut == Duration.zero) {
      path = session.sourcePath;
      offset = Duration.zero;
    } else {
      if (_previewEdit != edit || _previewPath == null) {
        setState(() => _rendering = true);
        final String rendered;
        try {
          rendered = await widget.editor.renderPreview(session, edit);
        } catch (_) {
          if (mounted && request == _previewRequest) {
            setState(() => _rendering = false);
            _showMessage((l10n) => l10n.previewFailed);
          }
          return;
        }
        // Mientras se generaba, se pausó o se pidió otra.
        if (!mounted || request != _previewRequest) return;
        _previewPath = rendered;
        _previewEdit = edit;
        setState(() => _rendering = false);
      }
      path = _previewPath!;
      offset = edit.start;
    }
    _previewOffset = offset;
    await _player.play(path, position: from - offset);
  }

  /// Tras un cambio mientras suena, vuelve a generar la escucha y sigue desde
  /// el mismo punto.
  void _schedulePreviewRefresh() {
    _refreshPreview?.cancel();
    _refreshPreview = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_previewPlaying) return;
      _playPreview(_playhead ?? _edit.start);
    });
  }

  void _seekPreview(Duration position) {
    setState(() => _playhead = position);
    if (_previewPlaying) _player.seek(position - _previewOffset);
  }

  // --- Cambios ---

  void _setEdit(AudioEdit edit) {
    // Los fundidos no pueden ocupar más de la mitad de la selección.
    final maxFade = _maxFadeFor(edit);
    edit = edit.copyWith(
      fadeIn: edit.fadeIn > maxFade ? maxFade : edit.fadeIn,
      fadeOut: edit.fadeOut > maxFade ? maxFade : edit.fadeOut,
    );
    if (edit == _edit) return;
    setState(() {
      _edit = edit;
      final playhead = _playhead;
      if (playhead != null && (playhead < edit.start || playhead > edit.end)) {
        _playhead = edit.start;
      }
    });
    // Lo que suena tiene que reflejar el cambio.
    if (_previewPlaying) _schedulePreviewRefresh();
  }

  Duration _maxFadeFor(AudioEdit edit) {
    final half = edit.length ~/ 2;
    return half < _maxFade ? half : _maxFade;
  }

  void _reset() {
    final session = _session;
    if (session == null) return;
    _setEdit(AudioEdit(start: Duration.zero, end: session.duration));
  }

  double get _selectionPeak =>
      _session?.analysis.peakBetween(_edit.start, _edit.end) ?? 0;

  bool get _clips => _selectionPeak * _edit.gain > 1.0;

  void _normalize() {
    final peak = _selectionPeak;
    if (peak <= 0) return;
    // Se redondea hacia abajo a medio decibelio para no pasarse del pico.
    final db = (dbFromGain(_normalizedPeak / peak) * 2).floorToDouble() / 2;
    _setEdit(_edit.copyWith(gainDb: db.clamp(_minGainDb, _maxGainDb)));
  }

  /// Niveles de la onda con la ganancia y los fundidos aplicados a la
  /// selección, para ver el efecto antes de guardar.
  List<double> _displayLevels(WavAnalysis analysis) {
    final peaks = analysis.peaks;
    final total = analysis.duration;
    final gain = _edit.gain;
    final fadeIn = _edit.fadeIn.inMicroseconds;
    final fadeOut = _edit.fadeOut.inMicroseconds;
    return List.generate(peaks.length, (i) {
      final time = total * ((i + 0.5) / peaks.length);
      if (time < _edit.start || time > _edit.end) {
        return levelFromPeak(peaks[i]);
      }
      var factor = gain;
      final fromStart = (time - _edit.start).inMicroseconds;
      final toEnd = (_edit.end - time).inMicroseconds;
      if (fromStart < fadeIn) factor *= fromStart / fadeIn;
      if (toEnd < fadeOut) factor *= toEnd / fadeOut;
      return levelFromPeak(math.min(1, peaks[i] * factor));
    });
  }

  // --- Guardar ---

  /// Guarda la edición sustituyendo la original o, si [asCopy], como una
  /// grabación nueva.
  Future<void> _save({required bool asCopy}) async {
    final session = _session;
    if (session == null || _saving) return;

    final copyName = context.l10n.editedCopyName(session.recording.name);
    setState(() => _savingAsCopy = asCopy);
    await _player.stop();
    try {
      final recording = await widget.editor.save(
        session,
        _edit,
        asCopy: asCopy,
        copyName: copyName,
      );
      if (!mounted) return;
      Navigator.pop(context, EditResult(recording, isCopy: asCopy));
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingAsCopy = null);
      _showMessage((l10n) => l10n.editSaveFailed);
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

  Future<void> _confirmExit() async {
    final discard = await showConfirmDialog(
      context,
      title: context.l10n.discardChangesTitle,
      message: context.l10n.discardChangesMessage,
      confirmLabel: context.l10n.discard,
    );
    if (discard && mounted) Navigator.pop(context);
  }

  // --- Interfaz ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving && !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.editRecording),
          actions: [
            TextButton(
              onPressed: _changed && !_saving ? _reset : null,
              child: Text(context.l10n.reset),
            ),
          ],
          bottom: _saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: _buildBody(),
        bottomNavigationBar: _session == null ? null : _buildSaveButtons(),
      ),
    );
  }

  /// «Guardar copia» crea una grabación nueva; «Guardar» sustituye la
  /// original.
  Widget _buildSaveButtons() {
    final canSave = _changed && !_saving;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('save-copy-button'),
                icon: const Icon(Icons.file_copy_outlined),
                label: _ButtonLabel(
                  _savingAsCopy == true
                      ? context.l10n.saving
                      : context.l10n.saveCopy,
                ),
                onPressed: canSave ? () => _save(asCopy: true) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('save-edit-button'),
                icon: const Icon(Icons.save_outlined),
                label: _ButtonLabel(
                  _savingAsCopy == false
                      ? context.l10n.saving
                      : context.l10n.save,
                ),
                onPressed: canSave ? () => _save(asCopy: false) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_failed) {
      return _Message(
        icon: Icons.error_outline,
        text: context.l10n.openAudioFailed,
      );
    }
    final session = _session;
    if (session == null) {
      return _Message(text: context.l10n.preparingAudio, loading: true);
    }

    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AbsorbPointer(
      absorbing: _saving,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.recording.name,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          TrimWaveform(
            key: const Key('trim-waveform'),
            levels: _displayLevels(session.analysis),
            duration: session.duration,
            start: _edit.start,
            end: _edit.end,
            playhead: _playhead,
            onChanged: (start, end) =>
                _setEdit(_edit.copyWith(start: start, end: end)),
            onSeek: _seekPreview,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeLabel(label: l10n.trimStartLabel, time: _edit.start),
              _TimeLabel(label: l10n.durationLabel, time: _edit.length),
              _TimeLabel(label: l10n.trimEndLabel, time: _edit.end),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: IconButton.filledTonal(
              key: const Key('preview-button'),
              iconSize: 32,
              tooltip: _previewPlaying || _rendering
                  ? l10n.pause
                  : l10n.playSelection,
              icon: _rendering
                  ? const SizedBox.square(
                      dimension: 32,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  : Icon(_previewPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePreview,
            ),
          ),
          // Sin audio, solo se recortan las notas.
          if (!widget.recording.isNotesOnly) ..._buildSoundControls(),
        ],
      ),
    );
  }

  /// El volumen y los fundidos.
  List<Widget> _buildSoundControls() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final maxFade = _maxFadeFor(_edit);
    final gainLabel = formatGain(_edit.gainDb);
    return [
      const Divider(height: 32),
      _SectionHeader(
        icon: Icons.volume_up_outlined,
        title: l10n.volume,
        value: gainLabel,
      ),
      Slider(
        key: const Key('gain-slider'),
        value: _edit.gainDb,
        min: _minGainDb,
        max: _maxGainDb,
        divisions: ((_maxGainDb - _minGainDb) * 2).round(),
        onChanged: (value) => _setEdit(_edit.copyWith(gainDb: value)),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: Text(l10n.normalize),
            onPressed: _selectionPeak > 0 ? _normalize : null,
          ),
          if (_clips)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.clippingWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
        ],
      ),
      const Divider(height: 32),
      _SectionHeader(
        icon: Icons.trending_up,
        title: l10n.fadeIn,
        value: formatSeconds(_edit.fadeIn),
      ),
      _FadeSlider(
        key: const Key('fade-in-slider'),
        value: _edit.fadeIn,
        max: maxFade,
        onChanged: (value) => _setEdit(_edit.copyWith(fadeIn: value)),
      ),
      _SectionHeader(
        icon: Icons.trending_down,
        title: l10n.fadeOut,
        value: formatSeconds(_edit.fadeOut),
      ),
      _FadeSlider(
        key: const Key('fade-out-slider'),
        value: _edit.fadeOut,
        max: maxFade,
        onChanged: (value) => _setEdit(_edit.copyWith(fadeOut: value)),
      ),
      const SizedBox(height: 8),
    ];
  }
}

/// Texto de un botón en una sola línea, que se reduce si no cabe (pantallas
/// estrechas o texto grande).
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon, this.loading = false});

  final String text;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator(),
            if (icon != null)
              Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.label, required this.time});

  final String label;
  final Duration time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          formatDuration(time, showTenths: true),
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Control de la duración de un fundido, en décimas de segundo.
class _FadeSlider extends StatelessWidget {
  const _FadeSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final Duration value;
  final Duration max;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final tenths = max.inMilliseconds ~/ 100;
    return Slider(
      value: (value.inMilliseconds / 100).clamp(0, tenths).toDouble(),
      max: math.max(tenths, 1).toDouble(),
      divisions: math.max(tenths, 1),
      onChanged: tenths > 0
          ? (v) => onChanged(Duration(milliseconds: v.round() * 100))
          : null,
    );
  }
}
