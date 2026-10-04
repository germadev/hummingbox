import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Colores de las barras de la onda en el orden en que se dibujan: de la más
/// reciente (a la derecha) a la más antigua.
List<Color> barColors(WidgetTester tester, Finder waveform) {
  final colors = <Color>[];
  expect(
    tester.renderObject(
      find.descendant(of: waveform, matching: find.byType(CustomPaint)),
    ),
    paints..everything((method, arguments) {
      if (method == #drawLine) colors.add((arguments[2] as Paint).color);
      return true;
    }),
  );
  return colors;
}
