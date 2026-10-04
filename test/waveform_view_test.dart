import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/widgets/waveform_view.dart';

import 'waveform_helpers.dart';

void main() {
  const red = Color(0xFFFF0000);
  const grey = Color(0xFF888888);

  Future<void> pumpWaveform(
    WidgetTester tester,
    List<double> amplitudes, {
    Color? emptyColor,
  }) {
    return tester.pumpWidget(
      Center(
        // Caben 10 barras de 3 px con huecos de 3 px.
        child: SizedBox(
          width: 60,
          child: WaveformView(
            key: const Key('waveform'),
            amplitudes: amplitudes,
            color: red,
            emptyColor: emptyColor,
          ),
        ),
      ),
    );
  }

  testWidgets('solo colorea las barras con muestras', (tester) async {
    await pumpWaveform(tester, [0.5, 1.0, 0.8], emptyColor: grey);

    expect(barColors(tester, find.byKey(const Key('waveform'))), [
      ...List.filled(3, isSameColorAs(red)),
      ...List.filled(7, isSameColorAs(grey)),
    ]);
  });

  testWidgets('sin color para el hueco, usa el de las muestras', (
    tester,
  ) async {
    await pumpWaveform(tester, [0.5]);

    expect(
      barColors(tester, find.byKey(const Key('waveform'))),
      List.filled(10, isSameColorAs(red)),
    );
  });

  testWidgets('con más muestras de las que caben, muestra las últimas', (
    tester,
  ) async {
    await pumpWaveform(tester, List.filled(25, 0.5), emptyColor: grey);

    expect(
      barColors(tester, find.byKey(const Key('waveform'))),
      List.filled(10, isSameColorAs(red)),
    );
  });
}
