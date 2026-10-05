import 'package:flutter/material.dart';

import '../audio/levels.dart';
import '../l10n/l10n.dart';
import '../utils/formatters.dart';

/// Onda de una grabación completa que hace de barra de progreso: la parte ya
/// reproducida se resalta y se puede tocar o arrastrar para saltar a otro
/// punto.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.levels,
    required this.duration,
    required this.onSeek,
    this.position,
    this.height = 36,
  });

  /// Niveles (0–1) de toda la grabación, o `null` si aún no se conocen.
  final List<double>? levels;

  final Duration duration;

  /// Posición de la reproducción, o `null` si esta grabación no está cargada
  /// en el reproductor. Si se indica, se muestran también los tiempos.
  final Duration? position;

  final ValueChanged<Duration> onSeek;
  final double height;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  /// Posición (0–1) mientras el usuario arrastra.
  double? _dragFraction;

  /// Salto de los gestos de accesibilidad: un 5 % de la grabación.
  static const _semanticsStep = 0.05;

  bool get _enabled => widget.duration > Duration.zero;

  double get _fraction {
    if (_dragFraction case final drag?) return drag;
    final position = widget.position;
    final total = widget.duration.inMicroseconds;
    if (position == null || total <= 0) return 0;
    return (position.inMicroseconds / total).clamp(0.0, 1.0);
  }

  Duration _timeAt(double fraction) => widget.duration * fraction;

  void _seekBy(double delta) =>
      widget.onSeek(_timeAt((_fraction + delta).clamp(0.0, 1.0)));

  void _endDrag() {
    final fraction = _dragFraction;
    setState(() => _dragFraction = null);
    if (fraction != null) widget.onSeek(_timeAt(fraction));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = widget.position != null || _dragFraction != null;

    final waveform = LayoutBuilder(
      builder: (context, constraints) {
        double fractionAt(Offset position) =>
            (position.dx / constraints.maxWidth).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _enabled
              ? (details) =>
                    widget.onSeek(_timeAt(fractionAt(details.localPosition)))
              : null,
          onHorizontalDragStart: _enabled
              ? (details) => setState(
                  () => _dragFraction = fractionAt(details.localPosition),
                )
              : null,
          onHorizontalDragUpdate: _enabled
              ? (details) => setState(
                  () => _dragFraction = fractionAt(details.localPosition),
                )
              : null,
          onHorizontalDragEnd: _enabled ? (_) => _endDrag() : null,
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: SeekWaveformPainter(
                levels: widget.levels,
                progress: active ? _fraction : null,
                playedColor: colors.primary,
                pendingColor: colors.onSurfaceVariant.withValues(
                  alpha: active ? 0.35 : 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );

    final timeStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      slider: true,
      label: context.l10n.playbackPosition,
      value: formatDuration(_timeAt(_fraction)),
      increasedValue: formatDuration(
        _timeAt((_fraction + _semanticsStep).clamp(0.0, 1.0)),
      ),
      decreasedValue: formatDuration(
        _timeAt((_fraction - _semanticsStep).clamp(0.0, 1.0)),
      ),
      onIncrease: _enabled ? () => _seekBy(_semanticsStep) : null,
      onDecrease: _enabled ? () => _seekBy(-_semanticsStep) : null,
      child: ExcludeSemantics(
        child: Column(
          children: [
            waveform,
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: widget.position == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(_timeAt(_fraction)),
                            key: const Key('playback-position'),
                            style: timeStyle,
                          ),
                          Text(
                            formatDuration(widget.duration),
                            style: timeStyle,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja la onda en barras que ocupan todo el ancho. Con [progress], las
/// barras hasta ese punto (0–1) usan [playedColor].
class SeekWaveformPainter extends CustomPainter {
  SeekWaveformPainter({
    required this.levels,
    required this.progress,
    required this.playedColor,
    required this.pendingColor,
  });

  final List<double>? levels;
  final double? progress;
  final Color playedColor;
  final Color pendingColor;

  static const _barWidth = 2.0;
  static const _gap = 2.0;
  static const _minBarHeight = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_barWidth + _gap)).floor();
    if (count <= 0) return;
    final bars = resampleLevels(levels ?? const [], count);
    final step = size.width / count;
    final played = Paint()
      ..color = playedColor
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;
    final pending = Paint()
      ..color = pendingColor
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final maxHeight = size.height - _barWidth;
    final progressX = progress == null ? -1.0 : progress! * size.width;

    for (var i = 0; i < count; i++) {
      final x = step * (i + 0.5);
      final height = (bars[i] * maxHeight).clamp(_minBarHeight, maxHeight);
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        x <= progressX ? played : pending,
      );
    }
  }

  @override
  bool shouldRepaint(SeekWaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.pendingColor != pendingColor;
}
