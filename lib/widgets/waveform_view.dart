import 'package:flutter/material.dart';

/// Dibuja la onda de los niveles de entrada como barras verticales,
/// con la muestra más reciente a la derecha.
///
/// Si no hay muestras suficientes para llenar el ancho, el hueco de la
/// izquierda (antes de que empezara la grabación) se dibuja como silencio
/// con [emptyColor].
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.amplitudes,
    required this.color,
    this.emptyColor,
    this.height = 64,
  });

  /// Niveles normalizados entre 0 y 1.
  final List<double> amplitudes;

  /// Color de las barras con muestras.
  final Color color;

  /// Color de las barras sin muestras. Si es `null`, se usa [color].
  final Color? emptyColor;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: amplitudes,
          color: color,
          emptyColor: emptyColor ?? color,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.emptyColor,
  });

  final List<double> amplitudes;
  final Color color;
  final Color emptyColor;

  static const _barWidth = 3.0;
  static const _gap = 3.0;
  static const _minBarHeight = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paintFor(Color color) => Paint()
      ..color = color
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;
    final filled = paintFor(color);
    final empty = paintFor(emptyColor);
    final centerY = size.height / 2;
    final maxBars = (size.width / (_barWidth + _gap)).floor();

    // Recorre las muestras de la más reciente a la más antigua, de derecha a
    // izquierda; los huecos sin muestras se dibujan como silencio.
    for (var i = 0; i < maxBars; i++) {
      final sampleIndex = amplitudes.length - 1 - i;
      final hasSample = sampleIndex >= 0;
      final level = hasSample ? amplitudes[sampleIndex] : 0.0;
      final barHeight = (level * (size.height - _barWidth)).clamp(
        _minBarHeight,
        size.height - _barWidth,
      );
      final x = size.width - _barWidth / 2 - i * (_barWidth + _gap);
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        hasSample ? filled : empty,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.emptyColor != emptyColor ||
      !_sameSamples(oldDelegate.amplitudes);

  bool _sameSamples(List<double> other) {
    if (other.length != amplitudes.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != amplitudes[i]) return false;
    }
    return true;
  }
}
