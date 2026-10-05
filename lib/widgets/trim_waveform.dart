import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/levels.dart';
import '../l10n/l10n.dart';
import '../utils/formatters.dart';

enum _Drag { start, end, playhead }

/// Onda con dos asas para elegir la parte de la grabación que se conserva.
///
/// Arrastrar cerca de un asa la mueve; tocar o arrastrar dentro de la
/// selección mueve el cabezal de reproducción.
class TrimWaveform extends StatefulWidget {
  const TrimWaveform({
    super.key,
    required this.levels,
    required this.duration,
    required this.start,
    required this.end,
    required this.onChanged,
    this.playhead,
    this.onSeek,
    this.height = 128,
  });

  /// Niveles (0–1) de toda la grabación.
  final List<double> levels;
  final Duration duration;
  final Duration start;
  final Duration end;
  final void Function(Duration start, Duration end) onChanged;
  final Duration? playhead;
  final ValueChanged<Duration>? onSeek;
  final double height;

  /// Duración mínima de la selección.
  Duration get minLength {
    const preferred = Duration(milliseconds: 500);
    return duration < preferred * 2 ? duration ~/ 2 : preferred;
  }

  @override
  State<TrimWaveform> createState() => _TrimWaveformState();
}

class _TrimWaveformState extends State<TrimWaveform> {
  /// Margen a cada lado para poder agarrar las asas en los extremos.
  static const _inset = 14.0;

  /// Distancia (en píxeles) a la que un toque agarra un asa.
  static const _handleReach = 32.0;

  _Drag? _drag;

  double _fractionOf(Duration time) {
    final total = widget.duration.inMicroseconds;
    return total <= 0 ? 0 : (time.inMicroseconds / total).clamp(0.0, 1.0);
  }

  void _moveStart(Duration time) {
    final latest = widget.end - widget.minLength;
    final start = _clamp(time, Duration.zero, latest);
    if (start != widget.start) widget.onChanged(start, widget.end);
  }

  void _moveEnd(Duration time) {
    final earliest = widget.start + widget.minLength;
    final end = _clamp(time, earliest, widget.duration);
    if (end != widget.end) widget.onChanged(widget.start, end);
  }

  void _seek(Duration time) =>
      widget.onSeek?.call(_clamp(time, widget.start, widget.end));

  static Duration _clamp(Duration value, Duration min, Duration max) =>
      value < min ? min : (value > max ? max : value);

  /// Paso de los botones de accesibilidad: 1 % de la grabación, como mínimo
  /// una décima.
  Duration get _step {
    final step = widget.duration ~/ 100;
    const minimum = Duration(milliseconds: 100);
    return step < minimum ? minimum : step;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final track = math.max(1.0, width - 2 * _inset);
        double xOf(Duration time) => _inset + track * _fractionOf(time);
        Duration timeAt(double x) =>
            widget.duration * ((x - _inset) / track).clamp(0.0, 1.0);

        final startX = xOf(widget.start);
        final endX = xOf(widget.end);

        void onDragUpdate(Offset position) {
          final time = timeAt(position.dx);
          switch (_drag) {
            case _Drag.start:
              _moveStart(time);
            case _Drag.end:
              _moveEnd(time);
            case _Drag.playhead:
              _seek(time);
            case null:
              break;
          }
        }

        void onDragStart(Offset position) {
          final x = position.dx;
          final toStart = (x - startX).abs();
          final toEnd = (x - endX).abs();
          final nearest = toStart < toEnd || (toStart == toEnd && x < startX)
              ? _Drag.start
              : _Drag.end;
          final insideSelection = x > startX && x < endX;
          _drag =
              insideSelection &&
                  math.min(toStart, toEnd) > _handleReach &&
                  widget.onSeek != null
              ? _Drag.playhead
              : nearest;
          onDragUpdate(position);
        }

        Widget handleSemantics(_Drag handle) {
          final isStart = handle == _Drag.start;
          final time = isStart ? widget.start : widget.end;
          final move = isStart ? _moveStart : _moveEnd;
          return Positioned(
            left: xOf(time) - 24,
            width: 48,
            top: 0,
            bottom: 0,
            child: Semantics(
              slider: true,
              label: isStart
                  ? context.l10n.trimStartHandle
                  : context.l10n.trimEndHandle,
              value: formatDuration(time, showTenths: true),
              increasedValue: formatDuration(time + _step, showTenths: true),
              decreasedValue: formatDuration(time - _step, showTenths: true),
              onIncrease: () => move(time + _step),
              onDecrease: () => move(time - _step),
              child: const SizedBox.expand(),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              onDragStart(details.localPosition),
          onHorizontalDragUpdate: (details) =>
              onDragUpdate(details.localPosition),
          onHorizontalDragEnd: (_) => _drag = null,
          onHorizontalDragCancel: () => _drag = null,
          onTapUp: (details) {
            final x = details.localPosition.dx;
            if (x >= startX && x <= endX) _seek(timeAt(x));
          },
          child: SizedBox(
            height: widget.height,
            width: width,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrimPainter(
                      levels: widget.levels,
                      startX: startX,
                      endX: endX,
                      inset: _inset,
                      playheadX: widget.playhead == null
                          ? null
                          : xOf(widget.playhead!),
                      selectedColor: colors.primary,
                      unselectedColor: colors.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      selectionColor: colors.primary.withValues(alpha: 0.08),
                      handleColor: colors.primary,
                      gripColor: colors.onPrimary,
                      playheadColor: colors.onSurface,
                    ),
                  ),
                ),
                handleSemantics(_Drag.start),
                handleSemantics(_Drag.end),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrimPainter extends CustomPainter {
  _TrimPainter({
    required this.levels,
    required this.startX,
    required this.endX,
    required this.inset,
    required this.playheadX,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectionColor,
    required this.handleColor,
    required this.gripColor,
    required this.playheadColor,
  });

  final List<double> levels;
  final double startX;
  final double endX;
  final double inset;
  final double? playheadX;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectionColor;
  final Color handleColor;
  final Color gripColor;
  final Color playheadColor;

  static const _barWidth = 2.0;
  static const _gap = 2.0;
  static const _minBarHeight = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final track = size.width - 2 * inset;
    final centerY = size.height / 2;

    canvas.drawRRect(
      RRect.fromLTRBR(startX, 0, endX, size.height, const Radius.circular(8)),
      Paint()..color = selectionColor,
    );

    final count = ((track + _gap) / (_barWidth + _gap)).floor();
    if (count > 0) {
      final bars = resampleLevels(levels, count);
      final step = track / count;
      final maxHeight = size.height * 0.8;
      final selected = Paint()
        ..color = selectedColor
        ..strokeWidth = _barWidth
        ..strokeCap = StrokeCap.round;
      final unselected = Paint()
        ..color = unselectedColor
        ..strokeWidth = _barWidth
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < count; i++) {
        final x = inset + step * (i + 0.5);
        final height = (bars[i] * maxHeight).clamp(_minBarHeight, maxHeight);
        canvas.drawLine(
          Offset(x, centerY - height / 2),
          Offset(x, centerY + height / 2),
          x >= startX && x <= endX ? selected : unselected,
        );
      }
    }

    if (playheadX case final x?) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        Paint()
          ..color = playheadColor
          ..strokeWidth = 2,
      );
    }

    for (final x in [startX, endX]) {
      _paintHandle(canvas, size, x);
    }
  }

  void _paintHandle(Canvas canvas, Size size, double x) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = handleColor
        ..strokeWidth = 2,
    );
    final grip = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, size.height / 2),
        width: 12,
        height: 36,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(grip, Paint()..color = handleColor);
    final line = Paint()
      ..color = gripColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x, size.height / 2 - 8),
      Offset(x, size.height / 2 + 8),
      line,
    );
  }

  @override
  bool shouldRepaint(_TrimPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.startX != startX ||
      oldDelegate.endX != endX ||
      oldDelegate.playheadX != playheadX ||
      oldDelegate.selectedColor != selectedColor ||
      oldDelegate.unselectedColor != unselectedColor ||
      oldDelegate.playheadColor != playheadColor;
}
