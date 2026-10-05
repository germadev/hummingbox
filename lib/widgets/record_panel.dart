import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../controllers/player_controller.dart';
import '../controllers/recorder_controller.dart';
import '../l10n/l10n.dart';
import '../services/audio_recorder_service.dart';
import '../utils/formatters.dart';
import 'waveform_view.dart';

/// Panel inferior con los controles de grabación.
///
/// Plegado solo muestra el botón de grabar. Al deslizarlo hacia arriba se
/// despliega el cronómetro y la onda (en gris) sin empezar a grabar, con un
/// botón a cada lado: a la izquierda, grabar tras una cuenta atrás; a la
/// derecha, grabar al detectar la voz. Al deslizarlo hacia abajo se vuelve a
/// plegar. Mientras se graba o se espera para grabar está siempre desplegado.
///
/// Mientras suena una grabación (o está en pausa), el botón del centro la
/// para, y a los lados se activa o desactiva seguir con la siguiente de la
/// lista (izquierda) y repetir (derecha).
class RecordPanel extends StatefulWidget {
  const RecordPanel({
    super.key,
    required this.controller,
    required this.player,
    required this.onStopPlayback,
    this.onTouched,
    this.onBackgroundTapped,
    required this.onRecordPressed,
    required this.onCancelPressed,
    required this.onCountdownPressed,
    required this.onVoicePressed,
    this.countdownSeconds = 3,
  });

  final RecorderController controller;

  /// Reproductor de las grabaciones.
  final PlayerController player;

  /// Para la reproducción.
  final VoidCallback onStopPlayback;

  /// Al tocar el panel, en cualquier punto (p. ej. para quitar el foco del
  /// campo de búsqueda).
  final VoidCallback? onTouched;

  /// Al tocar el panel fuera de sus botones (como el fondo de la lista).
  final VoidCallback? onBackgroundTapped;

  /// Empieza o detiene la grabación según el estado actual (o, si se está
  /// esperando para empezar, empieza ya).
  final VoidCallback onRecordPressed;

  /// Descarta la grabación o cancela la espera.
  final VoidCallback onCancelPressed;
  final VoidCallback onCountdownPressed;
  final VoidCallback onVoicePressed;

  /// Duración de la cuenta atrás, para el texto del botón.
  final int countdownSeconds;

  @override
  State<RecordPanel> createState() => _RecordPanelState();
}

class _RecordPanelState extends State<RecordPanel>
    with SingleTickerProviderStateMixin {
  /// 0 = plegado, 1 = desplegado.
  late final AnimationController _expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.controller.isBusy ? 1 : 0,
  );

  final _infoKey = GlobalKey();

  /// Estado del grabador la última vez que se comprobó. Se inicializa en
  /// [initState] (y no con `late`, que lo evaluaría al leerlo por primera vez,
  /// cuando ya ha cambiado).
  late bool _wasBusy;
  late bool _wasActive;
  PendingStart? _lastPending;
  int _lastCountdown = 0;

  /// Velocidad (px/s) a partir de la cual un gesto se trata como un lanzamiento.
  static const _flingVelocity = 700.0;

  @override
  void initState() {
    super.initState();
    _wasBusy = widget.controller.isBusy;
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

  /// Grabando o esperando para empezar: el panel no se puede plegar.
  bool get _active => widget.controller.isBusy;

  bool get _expanded => _expansion.value > 0.5;

  /// Despliega el panel al empezar a grabar (o a esperar para grabar) y lo
  /// pliega al terminar una grabación; si se cancela una espera, sigue
  /// desplegado. Durante la cuenta atrás vibra cada segundo y al empezar tras
  /// una espera.
  void _onRecorderChanged() {
    final controller = widget.controller;
    final pending = controller.pending;
    if (pending == PendingStart.countdown &&
        controller.countdown != _lastCountdown) {
      HapticFeedback.selectionClick();
    }
    if (_lastPending != null && pending == null && controller.isActive) {
      HapticFeedback.mediumImpact();
    }
    _lastPending = pending;
    _lastCountdown = controller.countdown;

    final busy = controller.isBusy;
    if (busy && !_wasBusy) {
      _animateTo(1);
    } else if (!busy && _wasBusy && _wasActive) {
      _animateTo(0);
    }
    _wasBusy = busy;
    _wasActive = controller.isActive;
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
        child: Listener(
          onPointerDown: (_) => widget.onTouched?.call(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onBackgroundTapped,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  widget.controller,
                  widget.player,
                  _expansion,
                ]),
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
                            child: _RecordingInfo(
                              controller: widget.controller,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Controls(
                      controller: widget.controller,
                      player: widget.player,
                      onStopPlayback: widget.onStopPlayback,
                      expanded: _expanded,
                      countdownSeconds: widget.countdownSeconds,
                      onRecordPressed: widget.onRecordPressed,
                      onCancelPressed: widget.onCancelPressed,
                      onCountdownPressed: widget.onCountdownPressed,
                      onVoicePressed: widget.onVoicePressed,
                    ),
                  ],
                ),
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
                  ? context.l10n.hideRecordPanel
                  : context.l10n.showRecordPanel)
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

/// Estado, cronómetro y onda. Antes de grabar se muestra en gris; al grabar
/// solo se colorea la onda desde el punto en que empieza la grabación.
class _RecordingInfo extends StatelessWidget {
  const _RecordingInfo({required this.controller});

  final RecorderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final pending = controller.pending;
    final (label, icon, iconColor) = switch ((pending, controller.status)) {
      (PendingStart.countdown, _) => (
        l10n.countdownStatus,
        Icons.timer_outlined,
        recordRed,
      ),
      (PendingStart.voice, _) => (
        l10n.waitingForVoice,
        Icons.hearing,
        recordRed,
      ),
      (null, RecorderStatus.idle) => (
        l10n.readyToRecord,
        Icons.circle,
        muted.withValues(alpha: 0.4),
      ),
      (null, RecorderStatus.recording) => (
        l10n.recordingStatus,
        Icons.circle,
        recordRed,
      ),
      (null, RecorderStatus.paused) => (
        l10n.pausedStatus,
        Icons.pause_circle,
        muted,
      ),
    };
    // Solo cambia de color lo grabado; el hueco anterior sigue en gris.
    final idleColor = muted.withValues(alpha: 0.4);
    final waveformColor = switch (controller.status) {
      RecorderStatus.idle => idleColor,
      RecorderStatus.recording => recordRed,
      RecorderStatus.paused => recordRed.withValues(alpha: 0.4),
    };

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
        if (pending == PendingStart.countdown)
          Text(
            '${controller.countdown}',
            key: const Key('countdown-value'),
            style: theme.textTheme.displayMedium?.copyWith(
              color: recordRed,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
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
          key: const Key('recording-waveform'),
          amplitudes: controller.amplitudes,
          color: waveformColor,
          emptyColor: idleColor,
        ),
      ],
    );
  }
}

/// Botón de grabar y, a los lados: descartar y pausar mientras se graba;
/// cuenta atrás y grabar por voz con el panel desplegado antes de grabar; y
/// cancelar mientras se espera para empezar.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.player,
    required this.onStopPlayback,
    required this.expanded,
    required this.countdownSeconds,
    required this.onRecordPressed,
    required this.onCancelPressed,
    required this.onCountdownPressed,
    required this.onVoicePressed,
  });

  final RecorderController controller;
  final PlayerController player;
  final VoidCallback onStopPlayback;
  final bool expanded;
  final int countdownSeconds;
  final VoidCallback onRecordPressed;
  final VoidCallback onCancelPressed;
  final VoidCallback onCountdownPressed;
  final VoidCallback onVoicePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = controller.isActive;
    final waiting = controller.pending != null;
    final paused = controller.status == RecorderStatus.paused;

    // Mientras suena una grabación: parar, lista y repetir.
    if (!active && !waiting && player.isPlayingOrPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SideButton(
            visible: true,
            child: IconButton.filledTonal(
              key: const Key('playlist-button'),
              tooltip: l10n.playAll,
              iconSize: 28,
              isSelected: player.playlist,
              icon: const Icon(Icons.playlist_play),
              onPressed: player.togglePlaylist,
            ),
          ),
          const SizedBox(width: 32),
          StopPlaybackButton(onPressed: onStopPlayback),
          const SizedBox(width: 32),
          _SideButton(
            visible: true,
            child: IconButton.filledTonal(
              key: const Key('loop-button'),
              tooltip: l10n.repeat,
              iconSize: 28,
              isSelected: player.loop,
              icon: const Icon(Icons.repeat),
              selectedIcon: const Icon(Icons.repeat_on),
              onPressed: player.toggleLoop,
            ),
          ),
        ],
      );
    }

    final Widget left = active || waiting
        ? IconButton.filledTonal(
            key: const Key('cancel-button'),
            tooltip: active ? l10n.discard : l10n.cancel,
            iconSize: 28,
            icon: const Icon(Icons.close),
            onPressed: onCancelPressed,
          )
        : IconButton.filledTonal(
            key: const Key('countdown-button'),
            tooltip: l10n.countdownButton(countdownSeconds),
            iconSize: 28,
            icon: const Icon(Icons.timer_outlined),
            onPressed: onCountdownPressed,
          );
    final Widget right = active
        ? IconButton.filledTonal(
            key: const Key('pause-button'),
            tooltip: paused ? l10n.resume : l10n.pause,
            iconSize: 28,
            icon: Icon(paused ? Icons.mic : Icons.pause),
            onPressed: paused ? controller.resume : controller.pause,
          )
        : IconButton.filledTonal(
            key: const Key('voice-button'),
            tooltip: l10n.voiceButton,
            iconSize: 28,
            icon: const Icon(Icons.record_voice_over_outlined),
            onPressed: onVoicePressed,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SideButton(visible: active || waiting || expanded, child: left),
        const SizedBox(width: 32),
        RecordButton(
          recording: active,
          startsNow: waiting,
          onPressed: onRecordPressed,
        ),
        const SizedBox(width: 32),
        _SideButton(visible: active || (!waiting && expanded), child: right),
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
    this.startsNow = false,
  });

  final bool recording;

  /// Si se está esperando para empezar: al pulsarlo se empieza ya.
  final bool startsNow;
  final VoidCallback onPressed;

  static const _size = 80.0;

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.outlineVariant;
    final innerSize = recording ? 32.0 : 64.0;
    final l10n = context.l10n;
    final label = recording
        ? l10n.stopAndSave
        : (startsNow ? l10n.startNow : l10n.record);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
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

/// Botón central mientras suena una grabación: un cuadrado («parar») del
/// color principal, del mismo tamaño que el de grabar.
class StopPlaybackButton extends StatelessWidget {
  const StopPlaybackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = context.l10n.stopPlayback;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const Key('stop-playback-button'),
          onTap: onPressed,
          radius: RecordButton._size / 2,
          child: Container(
            width: RecordButton._size,
            height: RecordButton._size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant, width: 4),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
