import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/transcription_controller.dart';
import '../l10n/l10n.dart';
import '../models/recording.dart';
import '../utils/formatters.dart';
import '../utils/search.dart';
import 'waveform_seek_bar.dart';

enum RecordingAction { edit, rename, transcribe, viewTranscript, share, delete }

/// Elemento de la lista de grabaciones, con su formato y calidad y la onda de
/// toda la grabación. La onda hace de barra de progreso: muestra lo
/// reproducido y permite saltar. Tocar el nombre permite cambiarlo. Debajo,
/// el principio de su transcripción o lo que lleva transcrito.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.player,
    required this.transcriptions,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onAction,
    this.onCancelTranscription,
    this.highlight = const [],
    this.showFolder = false,
  });

  final Recording recording;
  final PlayerController player;
  final TranscriptionController transcriptions;
  final VoidCallback? onCancelTranscription;

  /// Palabras buscadas (normalizadas): se resaltan en el nombre y en la
  /// transcripción, que se muestra desde la primera que aparece.
  final List<String> highlight;

  /// Si se muestra la subcarpeta en la que está (en los resultados de una
  /// búsqueda, que incluye todas las carpetas).
  final bool showFolder;
  final VoidCallback onTogglePlay;

  /// Salta a una posición, empezando a reproducir si hace falta.
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

        return Card.filled(
          color: isCurrent
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerLow,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                isThreeLine: true,
                onTap: onTogglePlay,
                leading: IconButton.filled(
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
                // Tocar el nombre lo edita (el resto de la tarjeta reproduce).
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
                        child: Text.rich(
                          _highlighted(
                            recording.name,
                            highlight,
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
                    ),
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
                      PopupMenuItem(
                        value: RecordingAction.edit,
                        child: ListTile(
                          leading: const Icon(Icons.content_cut),
                          title: Text(l10n.edit),
                        ),
                      ),
                      PopupMenuItem(
                        value: RecordingAction.rename,
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.rename),
                        ),
                      ),
                      if (recording.transcript == null)
                        PopupMenuItem(
                          value: RecordingAction.transcribe,
                          enabled: !transcriptions.isTranscribing(recording),
                          child: ListTile(
                            leading: const Icon(Icons.notes),
                            title: Text(l10n.transcribe),
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: RecordingAction.viewTranscript,
                          child: ListTile(
                            leading: const Icon(Icons.subject),
                            title: Text(l10n.viewTranscript),
                          ),
                        ),
                      PopupMenuItem(
                        value: RecordingAction.share,
                        child: ListTile(
                          leading: const Icon(Icons.share_outlined),
                          title: Text(l10n.share),
                        ),
                      ),
                      PopupMenuItem(
                        value: RecordingAction.delete,
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(l10n.delete),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: WaveformSeekBar(
                  key: Key('waveform-${recording.id}'),
                  levels: recording.waveform,
                  duration: isCurrent && player.duration > Duration.zero
                      ? player.duration
                      : recording.duration,
                  position: isCurrent ? player.position : null,
                  onSeek: onSeek,
                ),
              ),
              if (transcriptions.isTranscribing(recording))
                _TranscriptionProgress(
                  progress: transcriptions.progressOf(recording),
                  running: transcriptions.isRunning(recording),
                  onCancel: onCancelTranscription,
                )
              else if (recording.transcript case final transcript?)
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
                              searchExcerpt(transcript.text, highlight),
                              highlight,
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
        );
      },
    );
  }
}

/// [text] con las palabras de [terms] en el estilo [style].
InlineSpan _highlighted(String text, List<String> terms, TextStyle style) {
  final matches = findMatches(text, terms);
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
