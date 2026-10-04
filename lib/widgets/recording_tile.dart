import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/recording.dart';
import '../utils/formatters.dart';
import 'waveform_seek_bar.dart';

enum RecordingAction { edit, rename, share, delete }

/// Elemento de la lista de grabaciones, con su formato y calidad y la onda de
/// toda la grabación. La onda hace de barra de progreso: muestra lo
/// reproducido y permite saltar. Tocar el nombre permite cambiarlo.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.player,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onAction,
  });

  final Recording recording;
  final PlayerController player;
  final VoidCallback onTogglePlay;

  /// Salta a una posición, empezando a reproducir si hace falta.
  final ValueChanged<Duration> onSeek;
  final void Function(RecordingAction action, BuildContext tileContext)
  onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: player,
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
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: onTogglePlay,
                ),
                // Tocar el nombre lo edita (el resto de la tarjeta reproduce).
                title: Builder(
                  builder: (titleContext) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(
                      button: true,
                      hint: 'Cambiar el nombre',
                      child: InkWell(
                        key: Key('name-${recording.id}'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: () =>
                            onAction(RecordingAction.rename, titleContext),
                        child: Text(
                          recording.name,
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
                      '${formatRecordingDate(recording.createdAt)} · $duration',
                    ),
                    Text(
                      audio == null
                          ? formatName(recording.format)
                          : formatAudioInfo(audio),
                      key: Key('audio-info-${recording.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                  ],
                ),
                trailing: Builder(
                  builder: (tileContext) => PopupMenuButton<RecordingAction>(
                    tooltip: 'Más opciones',
                    onSelected: (action) => onAction(action, tileContext),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: RecordingAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.content_cut),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: RecordingAction.rename,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Renombrar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: RecordingAction.share,
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Compartir'),
                        ),
                      ),
                      PopupMenuItem(
                        value: RecordingAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
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
            ],
          ),
        );
      },
    );
  }
}
