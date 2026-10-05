import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/levels.dart';
import '../l10n/l10n.dart';
import '../models/piano_note.dart';
import '../utils/formatters.dart';

/// Onda de una grabación completa que hace de barra de progreso: la parte ya
/// reproducida se resalta y se puede tocar o arrastrar para saltar a otro
/// punto.
///
/// Si se tocó el piano mientras se grababa, encima de la onda (o sin ella,
/// si no se grabó la voz) se ven las notas como en un editor MIDI: cada una
/// a la altura de su tecla, desde que se pulsó hasta que se soltó.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.levels,
    required this.duration,
    required this.onSeek,
    this.position,
    this.notes = const [],
    this.showWaveform = true,
    this.height = 36,
  });

  /// Niveles (0–1) de toda la grabación, o `null` si aún no se conocen.
  final List<double>? levels;

  /// Notas del piano, con su momento en la grabación.
  final List<PianoNote> notes;

  /// Si se dibuja la onda (la de la voz); si no, solo las notas.
  final bool showWaveform;

  /// Alto con notas del piano.
  static const pianoRollHeight = 64.0;

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
            height: widget.notes.isEmpty
                ? widget.height
                : WaveformSeekBar.pianoRollHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: widget.showWaveform
                  ? SeekWaveformPainter(
                      levels: widget.levels,
                      progress: active ? _fraction : null,
                      playedColor: colors.primary,
                      // Con notas, la voz queda detrás.
                      pendingColor: colors.onSurfaceVariant.withValues(
                        alpha: switch ((widget.notes.isEmpty, active)) {
                          (true, true) => 0.35,
                          (true, false) => 0.5,
                          (false, _) => 0.25,
                        },
                      ),
                    )
                  : null,
              foregroundPainter: widget.notes.isEmpty
                  ? null
                  : PianoRollPainter(
                      notes: widget.notes,
                      duration: widget.duration,
                      progress: active ? _fraction : null,
                      playedColor: colors.primary,
                      pendingColor: colors.tertiary,
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

/// Dibuja las notas del piano como en un editor MIDI: el tiempo en
/// horizontal (toda la grabación, [duration], ocupa el ancho) y la tecla en
/// vertical (las agudas arriba). Con [progress], las que ya han empezado a
/// sonar usan [playedColor].
class PianoRollPainter extends CustomPainter {
  PianoRollPainter({
    required this.notes,
    required this.duration,
    required this.progress,
    required this.playedColor,
    required this.pendingColor,
  });

  final List<PianoNote> notes;
  final Duration duration;
  final double? progress;
  final Color playedColor;
  final Color pendingColor;

  /// Teclas que se ven como mínimo, para que unas pocas notas no se vean
  /// enormes.
  static const _minSpan = 13;

  static const _minWidth = 3.0;

  /// Teclas (la más grave y la más aguda) que se ven para [notes].
  static (int, int) rangeOf(List<PianoNote> notes) {
    var low = notes.map((n) => n.key).reduce(math.min);
    var high = notes.map((n) => n.key).reduce(math.max);
    final missing = _minSpan - (high - low + 1);
    if (missing > 0) {
      low -= missing ~/ 2;
      high += missing - missing ~/ 2;
    }
    return (low, high);
  }

  /// Rectángulo de [note] en un dibujo de tamaño [size].
  Rect rectOf(PianoNote note, Size size) {
    final (low, high) = rangeOf(notes);
    final rowHeight = size.height / (high - low + 1);
    final total = duration.inMicroseconds;
    double x(Duration time) =>
        total <= 0 ? 0 : time.inMicroseconds / total * size.width;
    final left = x(note.start).clamp(0.0, size.width);
    final right = math
        .max(left + _minWidth, x(note.end))
        .clamp(0.0, size.width);
    final top = (high - note.key) * rowHeight;
    return Rect.fromLTRB(left, top, right, top + rowHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;
    final played = Paint()..color = playedColor;
    final pending = Paint()..color = pendingColor;
    final progressX = progress == null ? -1.0 : progress! * size.width;
    for (final note in notes) {
      final rect = rectOf(note, size);
      // Con un pequeño hueco entre teclas vecinas.
      final bar = RRect.fromRectAndRadius(
        rect.deflate(math.min(0.5, rect.height / 6)),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(bar, rect.left <= progressX ? played : pending);
    }
  }

  @override
  bool shouldRepaint(PianoRollPainter oldDelegate) =>
      oldDelegate.notes != notes ||
      oldDelegate.duration != duration ||
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.pendingColor != pendingColor;
}
