import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/voice_detector.dart';

void main() {
  /// Índice del primer nivel en el que se detecta voz, o `null`.
  int? detect(VoiceDetector detector, List<double> levels) {
    for (var i = 0; i < levels.length; i++) {
      if (detector.add(levels[i])) return i;
    }
    return null;
  }

  test('detecta la voz sobre el ruido de fondo', () {
    final levels = [...List.filled(20, -55.0), -30.0, -28.0, -25.0];

    // Hacen falta dos niveles altos seguidos.
    expect(detect(VoiceDetector(), levels), 21);
  });

  test('un pico aislado no basta', () {
    final levels = [...List.filled(20, -55.0), -20.0, -55.0, -20.0, -55.0];

    expect(detect(VoiceDetector(), levels), isNull);
  });

  test('no detecta nada mientras se estabiliza el micrófono', () {
    // Al empezar, el micrófono puede dar silencio total o un golpe.
    final levels = [-160.0, -160.0, -10.0, -10.0, -55.0, -55.0, -55.0];

    expect(detect(VoiceDetector(), levels), isNull);
  });

  test('se adapta a un ambiente ruidoso', () {
    final detector = VoiceDetector();
    // Calle: el ruido ya supera el mínimo absoluto.
    expect(detect(detector, List.filled(30, -40.0)), isNull);
    expect(detector.noiseDb, closeTo(-40, 0.5));

    // Hablar por encima del ruido sí se detecta.
    expect(detect(detector, [-25.0, -24.0]), 1);
  });

  test('en silencio total exige el mínimo absoluto', () {
    final detector = VoiceDetector();
    detect(detector, List.filled(20, -90.0));

    // 12 dB por encima del ruido, pero aún por debajo de −45 dBFS.
    expect(detect(detector, [-70.0, -70.0, -60.0, -60.0]), isNull);
    expect(detect(detector, [-35.0, -35.0]), 1);
  });
}
