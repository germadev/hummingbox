import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/recording.dart';
import '../utils/formatters.dart';

enum RecordingAction { rename, share, delete }

/// Elemento de la lista de grabaciones, con reproductor integrado cuando la
/// grabación es la que está cargada.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.player,
    required this.onTogglePlay,
    required this.onAction,
  });

  final Recording recording;
  final PlayerController player;
  final VoidCallback onTogglePlay;
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
                onTap: onTogglePlay,
                leading: IconButton.filled(
                  // ListTile tiñe los iconos de `leading`; se fija el color
                  // para que contraste con el fondo del botón.
                  color: theme.colorScheme.onPrimary,
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: onTogglePlay,
                ),
                title: Text(
                  recording.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${formatRecordingDate(recording.createdAt)} · $duration',
                ),
                trailing: Builder(
                  builder: (tileContext) => PopupMenuButton<RecordingAction>(
                    tooltip: 'Más opciones',
                    onSelected: (action) => onAction(action, tileContext),
                    itemBuilder: (context) => const [
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
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: isCurrent
                    ? _PlaybackBar(player: player)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barra de progreso con la posición y la duración de la reproducción.
class _PlaybackBar extends StatefulWidget {
  const _PlaybackBar({required this.player});

  final PlayerController player;

  @override
  State<_PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<_PlaybackBar> {
  /// Posición (en ms) mientras el usuario arrastra el control deslizante.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final textStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final max = player.duration.inMilliseconds.toDouble();
    final position = (_dragValue ?? player.position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 0.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: position,
              max: max > 0 ? max : 1,
              onChanged: max > 0
                  ? (value) => setState(() => _dragValue = value)
                  : null,
              onChangeEnd: (value) {
                setState(() => _dragValue = null);
                player.seek(Duration(milliseconds: value.round()));
              },
            ),
          ),
          Text(
            '${formatDuration(Duration(milliseconds: position.round()))}'
            ' / ${formatDuration(player.duration)}',
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
