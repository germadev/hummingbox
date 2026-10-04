import 'package:flutter/material.dart';

import '../app.dart';
import '../controllers/recorder_controller.dart';
import '../services/audio_recorder_service.dart';
import '../utils/formatters.dart';
import 'waveform_view.dart';

/// Panel inferior con los controles de grabación.
///
/// Plegado solo muestra el botón de grabar. Al deslizarlo hacia arriba se
/// despliega el cronómetro y la onda (en gris) sin empezar a grabar; al
/// deslizarlo hacia abajo se vuelve a plegar. Mientras se graba está siempre
/// desplegado.
class RecordPanel extends StatefulWidget {
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
  State<RecordPanel> createState() => _RecordPanelState();
}

class _RecordPanelState extends State<RecordPanel>
    with SingleTickerProviderStateMixin {
  /// 0 = plegado, 1 = desplegado.
  late final AnimationController _expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.controller.isActive ? 1 : 0,
  );

  final _infoKey = GlobalKey();

  /// Estado del grabador la última vez que se comprobó. Se inicializa en
  /// [initState] (y no con `late`, que lo evaluaría al leerlo por primera vez,
  /// cuando ya ha cambiado).
  late bool _wasActive;

  /// Velocidad (px/s) a partir de la cual un gesto se trata como un lanzamiento.
  static const _flingVelocity = 700.0;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.controller.isActive;
    widget.controller.addListener(_onRecorderChanged);
  }

  @override
  void didUpdateWidget(RecordPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onRecorderChanged);
      widget.controller.addListener(_onRecorderChanged);
      _onRecorderChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onRecorderChanged);
    _expansion.dispose();
    super.dispose();
  }

  bool get _active => widget.controller.isActive;

  bool get _expanded => _expansion.value > 0.5;

  /// Despliega el panel al empezar a grabar y lo pliega al terminar.
  void _onRecorderChanged() {
    if (_active == _wasActive) return;
    _wasActive = _active;
    _animateTo(_active ? 1 : 0);
  }

  void _animateTo(double target) {
    _expansion.animateTo(target, curve: Curves.easeOutCubic);
  }

  void _toggle() {
    if (_active) return;
    _animateTo(_expanded ? 0 : 1);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_active) return;
    final height = _infoKey.currentContext?.size?.height ?? 0;
    if (height <= 0) return;
    _expansion.value -= details.primaryDelta! / height;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_active) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() >= _flingVelocity) {
      _animateTo(velocity < 0 ? 1 : 0);
    } else {
      _animateTo(_expanded ? 1 : 0);
    }
  }

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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.controller, _expansion]),
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DragHandle(
                    visible: !_active,
                    expanded: _expanded,
                    onPressed: _toggle,
                  ),
                  SizeTransition(
                    sizeFactor: _expansion,
                    alignment: Alignment.bottomCenter,
                    child: FadeTransition(
                      opacity: _expansion,
                      // Plegado del todo, el contenido no se pinta ni se
                      // anuncia, pero se sigue midiendo para el arrastre.
                      child: Offstage(
                        offstage: _expansion.value == 0 && !_active,
                        child: Padding(
                          key: _infoKey,
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
                          child: _RecordingInfo(controller: widget.controller),
                        ),
                      ),
                    ),
                  ),
                  _Controls(
                    controller: widget.controller,
                    onRecordPressed: widget.onRecordPressed,
                    onCancelPressed: widget.onCancelPressed,
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

/// Tirador que indica que el panel se puede deslizar. Al tocarlo se pliega o
/// se despliega.
class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.visible,
    required this.expanded,
    required this.onPressed,
  });

  final bool visible;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Semantics(
        button: visible,
        label: visible
            ? (expanded
                  ? 'Ocultar el panel de grabación'
                  : 'Mostrar el panel de grabación')
            : null,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('panel-handle'),
          behavior: HitTestBehavior.opaque,
          onTap: visible ? onPressed : null,
          child: SizedBox(
            width: 96,
            height: 24,
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado, cronómetro y onda. Antes de grabar se muestra en gris.
class _RecordingInfo extends StatelessWidget {
  const _RecordingInfo({required this.controller});

  final RecorderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (label, icon, iconColor) = switch (controller.status) {
      RecorderStatus.idle => (
        'Lista para grabar',
        Icons.circle,
        muted.withValues(alpha: 0.4),
      ),
      RecorderStatus.recording => ('Grabando', Icons.circle, recordRed),
      RecorderStatus.paused => ('En pausa', Icons.pause_circle, muted),
    };
    final recording = controller.status == RecorderStatus.recording;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDuration(controller.elapsed, showTenths: true),
          key: const Key('elapsed-time'),
          style: theme.textTheme.displayMedium?.copyWith(
            color: controller.isActive ? null : muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        WaveformView(
          amplitudes: controller.amplitudes,
          color: recording ? recordRed : muted.withValues(alpha: 0.4),
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
