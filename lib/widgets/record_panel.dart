import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/recorder_controller.dart';
import '../services/audio_recorder_service.dart';
import '../utils/formatters.dart';
import 'waveform_view.dart';

/// Panel inferior con los controles de grabación.
class RecordPanel extends StatelessWidget {
  const RecordPanel({
    super.key,
    required this.controller,
    required this.onRecordPressed,
    required this.onCancelPressed,
  });

  final RecorderController controller;

  /// Empieza o detiene la grabación según el estado actual.
  final VoidCallback onRecordPressed;
  final VoidCallback onCancelPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainer,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.isActive) ...[
                    _RecordingInfo(controller: controller),
                    const SizedBox(height: 20),
                  ],
                  _Controls(
                    controller: controller,
                    onRecordPressed: onRecordPressed,
                    onCancelPressed: onCancelPressed,
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

class _RecordingInfo extends StatelessWidget {
  const _RecordingInfo({required this.controller});

  final RecorderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paused = controller.status == RecorderStatus.paused;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              paused ? Icons.pause_circle : Icons.circle,
              size: 12,
              color: paused ? theme.colorScheme.onSurfaceVariant : recordRed,
            ),
            const SizedBox(width: 8),
            Text(
              paused ? 'En pausa' : 'Grabando',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDuration(controller.elapsed, showTenths: true),
          key: const Key('elapsed-time'),
          style: theme.textTheme.displayMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        WaveformView(
          amplitudes: controller.amplitudes,
          color: paused
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
              : recordRed,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.onRecordPressed,
    required this.onCancelPressed,
  });

  final RecorderController controller;
  final VoidCallback onRecordPressed;
  final VoidCallback onCancelPressed;

  @override
  Widget build(BuildContext context) {
    final active = controller.isActive;
    final paused = controller.status == RecorderStatus.paused;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SideButton(
          visible: active,
          child: IconButton.filledTonal(
            key: const Key('cancel-button'),
            tooltip: 'Descartar',
            iconSize: 28,
            icon: const Icon(Icons.close),
            onPressed: onCancelPressed,
          ),
        ),
        const SizedBox(width: 32),
        RecordButton(recording: active, onPressed: onRecordPressed),
        const SizedBox(width: 32),
        _SideButton(
          visible: active,
          child: IconButton.filledTonal(
            key: const Key('pause-button'),
            tooltip: paused ? 'Reanudar' : 'Pausar',
            iconSize: 28,
            icon: Icon(paused ? Icons.mic : Icons.pause),
            onPressed: paused ? controller.resume : controller.pause,
          ),
        ),
      ],
    );
  }
}

/// Reserva el hueco de un botón lateral para que el botón central no se mueva.
class _SideButton extends StatelessWidget {
  const _SideButton({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: visible ? Center(child: child) : null,
      ),
    );
  }
}

/// Botón principal: un círculo rojo que se transforma en un cuadrado
/// ("detener") mientras se graba.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.recording,
    required this.onPressed,
  });

  final bool recording;
  final VoidCallback onPressed;

  static const _size = 80.0;

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.outlineVariant;
    final innerSize = recording ? 32.0 : 64.0;

    return Semantics(
      button: true,
      label: recording ? 'Detener y guardar' : 'Grabar',
      excludeSemantics: true,
      child: Tooltip(
        message: recording ? 'Detener y guardar' : 'Grabar',
        child: InkResponse(
          key: const Key('record-button'),
          onTap: onPressed,
          radius: _size / 2,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 4),
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                color: recordRed,
                borderRadius: BorderRadius.circular(recording ? 8 : 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
