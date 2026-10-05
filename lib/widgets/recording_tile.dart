import 'package:flutter/material.dart';

import '../audio/levels.dart';
import '../controllers/player_controller.dart';
import '../controllers/transcription_controller.dart';
import '../l10n/l10n.dart';
import '../models/recording.dart';
import '../utils/formatters.dart';
import '../utils/recording_names.dart';
import '../utils/search.dart';
import 'waveform_seek_bar.dart';

enum RecordingAction {
  edit,
  addPiano,
  rename,
  transcribe,
  viewTranscript,
  transcribeInLanguage,
  share,
  delete,
}

/// Una acción del menú de una grabación: su icono, su nombre y si se puede
/// elegir.
typedef RecordingActionEntry = ({
  RecordingAction action,
  IconData icon,
  String label,
  bool enabled,
});

/// Lo que se puede hacer con [recording]: en su menú y, si está
/// seleccionada, en el panel de abajo ([RecordingActionsBar]).
List<RecordingActionEntry> recordingActions(
  Recording recording,
  TranscriptionController transcriptions,
  AppLocalizations l10n,
) => [
  (
    action: RecordingAction.edit,
    icon: Icons.content_cut,
    label: l10n.edit,
    enabled: true,
  ),
  (
    action: RecordingAction.addPiano,
    icon: Icons.piano,
    label: l10n.addPiano,
    enabled: true,
  ),
  (
    action: RecordingAction.rename,
    icon: Icons.edit_outlined,
    label: l10n.rename,
    enabled: true,
  ),
  // Solo el piano: no hay voz que transcribir.
  if (recording.hasVoice) ...[
    if (recording.transcript == null)
      (
        action: RecordingAction.transcribe,
        icon: Icons.notes,
        label: l10n.transcribe,
        // Si va en segundo plano, se adelanta.
        enabled: !transcriptions.isRequested(recording),
      )
    else
      (
        action: RecordingAction.viewTranscript,
        icon: Icons.subject,
        label: l10n.viewTranscript,
        enabled: true,
      ),
    (
      action: RecordingAction.transcribeInLanguage,
      icon: Icons.translate,
      label: l10n.transcribeInLanguage,
      enabled: true,
    ),
  ],
  (
    action: RecordingAction.share,
    icon: Icons.share_outlined,
    label: l10n.share,
    enabled: true,
  ),
  (
    action: RecordingAction.delete,
    icon: Icons.delete_outline,
    label: l10n.delete,
    enabled: true,
  ),
];

/// Las acciones del menú de [recording] como botones (solo el icono, con su
/// nombre al mantenerlos pulsados): en el panel de abajo, desplegado, con
/// la grabación seleccionada.
class RecordingActionsBar extends StatelessWidget {
  const RecordingActionsBar({
    super.key,
    required this.recording,
    required this.transcriptions,
    required this.onAction,
  });

  final Recording recording;
  final TranscriptionController transcriptions;
  final void Function(RecordingAction action, BuildContext buttonContext)
  onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: transcriptions,
      builder: (context, _) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          for (final entry in recordingActions(recording, transcriptions, l10n))
            Builder(
              builder: (buttonContext) => IconButton(
                key: Key('action-${entry.action.name}'),
                tooltip: entry.label,
                icon: Icon(entry.icon),
                onPressed: entry.enabled
                    ? () => onAction(entry.action, buttonContext)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Elemento de la lista de grabaciones, con su formato y calidad y la onda de
/// toda la grabación. La onda hace de barra de progreso: muestra lo
/// reproducido y permite saltar. Tocar el nombre permite cambiarlo. Debajo,
/// mientras se escucha o si coincide con la búsqueda, su transcripción, y lo
/// que lleva transcrito si se ha pedido transcribirla (las de segundo plano,
/// solo mientras se escucha).
///
/// En la vista compacta ([compact]) solo tiene una línea de datos (sin el
/// formato) y la onda solo se ve mientras está seleccionada.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.player,
    required this.transcriptions,
    required this.onTogglePlay,
    required this.onSelect,
    required this.onSeek,
    required this.onAction,
    this.onCancelTranscription,
    this.search,
    this.showFolder = false,
    this.compact = false,
  });

  final Recording recording;
  final PlayerController player;
  final TranscriptionController transcriptions;
  final VoidCallback? onCancelTranscription;

  /// Lo que se busca, si se está buscando: se resalta en el nombre y en la
  /// transcripción, que se muestra (desde la primera coincidencia) si está
  /// en ella.
  final SearchQuery? search;

  /// Si se muestra la subcarpeta en la que está (en los resultados de una
  /// búsqueda, que incluye todas las carpetas).
  final bool showFolder;

  /// Si se muestra en la vista compacta.
  final bool compact;

  /// El botón de reproducir: reproduce o pausa.
  final VoidCallback onTogglePlay;

  /// Al tocar la tarjeta: la selecciona, sin reproducirla.
  final VoidCallback onSelect;

  /// Salta a una posición (si no está seleccionada, la selecciona ahí).
  final ValueChanged<Duration> onSeek;
  final void Function(RecordingAction action, BuildContext tileContext)
  onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([player, transcriptions]),
      builder: (context, _) {
        final isCurrent = player.isCurrent(recording);
        final isPlaying = player.isPlaying(recording);
        final duration = recording.duration > Duration.zero
            ? formatDuration(recording.duration)
            : '--:--';
        final audio = recording.audio;
        final mutedStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final highlightStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );
        final transcript = recording.transcript;
        final search = this.search;
        // Mientras se escucha o si tiene lo que se busca.
        final showTranscript =
            isCurrent ||
            (transcript != null &&
                search != null &&
                search.findMatchesIn(transcript.text).isNotEmpty);
        final cardColor = isCurrent
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerLow;
        // Sin audio (solo piano, o en silencio), sin onda.
        final showWaveform = recording.hasVoice && hasAudio(recording.waveform);
        final showProgress =
            transcriptions.isRequested(recording) ||
            (isCurrent && transcriptions.isTranscribing(recording));

        // Los toques en los huecos de la tarjeta no llegan a la lista (que
        // deseleccionaría la grabación).
        return GestureDetector(
          onTap: () {},
          excludeFromSemantics: true,
          child: Card.filled(
            color: cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  isThreeLine: !compact,
                  onTap: onSelect,
                  // En la vista compacta no se ven las notas del piano hasta
                  // seleccionarla: un piano pequeño, a la izquierda del
                  // botón, indica que las tiene.
                  leading: _WithNotesIcon(
                    show: compact && recording.notes.isNotEmpty,
                    ringColor: cardColor,
                    key: Key('notes-icon-${recording.id}'),
                    child: IconButton.filled(
                      // ListTile tiñe los iconos de `leading`; se fija el color
                      // para que contraste con el fondo del botón.
                      color: theme.colorScheme.onPrimary,
                      tooltip: isPlaying ? l10n.pause : l10n.play,
                      // Mientras se lee el audio (p. ej. de Google Drive).
                      icon: player.isLoading(recording)
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: onTogglePlay,
                    ),
                  ),
                  // Tocar el nombre lo edita (el resto de la tarjeta la
                  // selecciona).
                  title: Builder(
                    builder: (titleContext) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(
                        button: true,
                        hint: l10n.rename,
                        child: InkWell(
                          key: Key('name-${recording.id}'),
                          borderRadius: BorderRadius.circular(4),
                          onTap: () =>
                              onAction(RecordingAction.rename, titleContext),
                          // Sin la fecha del principio: ya está debajo.
                          child: Text.rich(
                            _highlighted(
                              RecordingNames.withoutDate(recording.name),
                              search,
                              highlightStyle,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        [
                          if (showFolder && recording.folder.isNotEmpty)
                            recording.folder,
                          formatRecordingDate(recording.createdAt, l10n),
                          duration,
                        ].join(' · '),
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                      ),
                      if (!compact)
                        Text(
                          audio == null
                              ? formatName(recording.format)
                              : formatAudioInfo(audio, l10n),
                          key: Key('audio-info-${recording.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mutedStyle,
                        ),
                    ],
                  ),
                  trailing: Builder(
                    builder: (tileContext) => PopupMenuButton<RecordingAction>(
                      tooltip: l10n.moreOptions,
                      onSelected: (action) => onAction(action, tileContext),
                      itemBuilder: (context) => [
                        for (final entry in recordingActions(
                          recording,
                          transcriptions,
                          l10n,
                        ))
                          PopupMenuItem(
                            value: entry.action,
                            enabled: entry.enabled,
                            child: ListTile(
                              leading: Icon(entry.icon),
                              title: Text(entry.label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // En la vista compacta, solo la seleccionada. Sin voz que se
                // oiga ni notas, no hay nada que dibujar: solo se ve
                // seleccionada, para saltar y ver por dónde va.
                if (isCurrent ||
                    (!compact && (showWaveform || recording.notes.isNotEmpty)))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: WaveformSeekBar(
                      key: Key('waveform-${recording.id}'),
                      levels: recording.waveform,
                      duration: isCurrent && player.duration > Duration.zero
                          ? player.duration
                          : recording.duration,
                      position: isCurrent ? player.position : null,
                      notes: recording.notes,
                      showWaveform: showWaveform,
                      onSeek: onSeek,
                    ),
                  ),
                if (showProgress)
                  _TranscriptionProgress(
                    progress: transcriptions.progressOf(recording),
                    running: transcriptions.isRunning(recording),
                    onCancel: onCancelTranscription,
                  )
                else if (transcript != null && showTranscript)
                  InkWell(
                    key: Key('transcript-${recording.id}'),
                    onTap: () =>
                        onAction(RecordingAction.viewTranscript, context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: 8,
                              top: 2,
                            ),
                            child: Icon(
                              Icons.subject,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text.rich(
                              _highlighted(
                                search?.excerpt(transcript.text) ??
                                    transcript.text,
                                search,
                                highlightStyle,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: mutedStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// [text] con lo que encuentra [search] en el estilo [style].
InlineSpan _highlighted(String text, SearchQuery? search, TextStyle style) {
  final matches = search?.findMatchesIn(text) ?? const [];
  if (matches.isEmpty) return TextSpan(text: text);
  final spans = <TextSpan>[];
  var position = 0;
  for (final match in matches) {
    if (match.start > position) {
      spans.add(TextSpan(text: text.substring(position, match.start)));
    }
    spans.add(
      TextSpan(text: text.substring(match.start, match.end), style: style),
    );
    position = match.end;
  }
  if (position < text.length) {
    spans.add(TextSpan(text: text.substring(position)));
  }
  return TextSpan(children: spans);
}

/// Lo que lleva transcrito una grabación, con un botón para cancelarlo.
class _TranscriptionProgress extends StatelessWidget {
  const _TranscriptionProgress({
    required this.progress,
    required this.running,
    this.onCancel,
  });

  /// Parte transcrita (0–1), o `null` si aún no se sabe.
  final double? progress;

  /// Si se está transcribiendo (si no, espera su turno).
  final bool running;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final progress = this.progress;
    final label = !running
        ? l10n.waitingToTranscribe
        : progress == null
        ? l10n.preparingTranscription
        : l10n.transcribingProgress(formatPercent(progress));
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  key: const Key('transcription-progress'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: running ? progress : 0),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.cancelTranscription,
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// [child] (el botón de reproducir) con, si [show], un piano pequeño en su
/// borde izquierdo: la grabación tiene notas del piano (y su `.mid`).
class _WithNotesIcon extends StatelessWidget {
  const _WithNotesIcon({
    super.key,
    required this.show,
    required this.ringColor,
    required this.child,
  });

  final bool show;

  /// El de la tarjeta, alrededor del piano: lo separa del botón.
  final Color ringColor;
  final Widget child;

  static const size = 20.0;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      alignment: AlignmentDirectional.centerStart,
      children: [
        child,
        PositionedDirectional(
          start: -size / 2,
          child: IgnorePointer(
            child: Semantics(
              label: context.l10n.piano,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2),
                ),
                child: Icon(
                  Icons.piano,
                  size: 12,
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
