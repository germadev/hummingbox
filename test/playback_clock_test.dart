import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/audio/playback_clock.dart';

Duration ms(num value) => Duration(microseconds: (value * 1000).round());

void main() {
  late PlaybackClock clock;

  setUp(() => clock = PlaybackClock());

  test('no avanza hasta que avanza el reproductor', () {
    clock.reset(Duration.zero);
    // Mientras arranca, el reproductor sigue en 0.
    clock.report(Duration.zero, ms(0));
    expect(clock.positionAt(ms(100)), Duration.zero);
    expect(clock.isAdvancingAt(ms(100)), isFalse);

    clock.report(ms(20), ms(120));
    expect(clock.positionAt(ms(120)), ms(20));
    expect(clock.positionAt(ms(150)), ms(50));
    expect(clock.isAdvancingAt(ms(150)), isTrue);
  });

  test('entre posición y posición, avanza al ritmo del reloj', () {
    clock.report(ms(1000), ms(0));
    expect(clock.positionAt(ms(16)), ms(1016));
    expect(clock.positionAt(ms(33)), ms(1033));
  });

  test('no retrocede si el reproductor da una posición un poco anterior', () {
    clock.report(ms(1000), ms(0));
    expect(clock.positionAt(ms(100)), ms(1100));
    clock.report(ms(1060), ms(100));
    expect(clock.positionAt(ms(100)), ms(1100));
    expect(clock.positionAt(ms(116)), greaterThanOrEqualTo(ms(1100)));
  });

  test('si el reproductor salta, va con él', () {
    clock.report(ms(1000), ms(0));
    clock.report(ms(30000), ms(100));
    expect(clock.positionAt(ms(100)), ms(30000));
    expect(clock.positionAt(ms(116)), ms(30016));

    // Hacia atrás: se queda ahí hasta que vuelve a avanzar.
    clock.report(ms(5000), ms(200));
    expect(clock.positionAt(ms(300)), ms(5000));
    clock.report(ms(5020), ms(300));
    expect(clock.positionAt(ms(316)), ms(5036));
  });

  test('sin noticias del reproductor, se para', () {
    clock.report(ms(1000), ms(0));
    expect(clock.isAdvancingAt(ms(400)), isTrue);
    expect(clock.isAdvancingAt(ms(600)), isFalse);
    expect(clock.positionAt(ms(2000)), ms(1500));

    // Al volver a dar posiciones, sigue desde ahí, acercándose poco a poco.
    clock.report(ms(1520), ms(2000));
    expect(clock.isAdvancingAt(ms(2000)), isTrue);
    expect(clock.positionAt(ms(2000)), ms(1502));
    expect(clock.positionAt(ms(2016)), ms(1518));
  });

  test('al pausar se queda donde está; al parar, vuelve al principio', () {
    clock.report(ms(1000), ms(0));
    expect(clock.positionAt(ms(100)), ms(1100));
    // La última posición llega con algo de retraso.
    clock.pause(ms(1080));
    expect(clock.positionAt(ms(200)), ms(1100));

    clock.report(ms(1100), ms(300));
    clock.pause(Duration.zero);
    expect(clock.positionAt(ms(400)), Duration.zero);
  });

  test('con posiciones a destiempo, a saltos y a veces hacia atrás, la '
      'línea avanza a velocidad constante y sin retroceder', () {
    final random = math.Random(1);
    const frame = 1000 / 60;
    // El audio empieza a sonar 80 ms después de pedirlo.
    double truth(double time) => math.max(0, time - 80);
    // Respuestas pendientes: cuándo llegan y lo que dicen.
    final pending = <(double, Duration)>[];
    Duration? previous;
    var maxError = 0.0;
    var maxStep = 0.0;
    for (var i = 0; i < 60 * 20; i++) {
      final now = i * frame;
      // Lo que ha llegado desde el fotograma anterior.
      for (final (arrival, position) in [...pending]) {
        if (arrival <= now) {
          clock.report(position, ms(now));
          pending.remove((arrival, position));
        }
      }
      // En cada fotograma se pregunta, y la respuesta tarda de 1 a 30 ms. El
      // reproductor la da en pasos de 20 ms y, a veces, 30 ms por detrás.
      var position = (truth(now) / 20).floor() * 20.0;
      if (random.nextDouble() < 0.05) position = math.max(0, position - 30);
      pending.add((now + 1 + random.nextDouble() * 29, ms(position)));

      final shown = clock.positionAt(ms(now));
      if (previous != null) {
        expect(shown, greaterThanOrEqualTo(previous), reason: 'a los $now ms');
        if (now > 500) {
          maxStep = math.max(
            maxStep,
            (shown - previous).inMicroseconds / 1000 - frame,
          );
        }
      }
      previous = shown;
      if (now > 1000) {
        maxError = math.max(
          maxError,
          (shown.inMicroseconds / 1000 - truth(now)).abs(),
        );
      }
    }
    // Cada fotograma avanza lo que dura (con muy poca diferencia) y va con
    // el audio.
    expect(maxStep, lessThan(5));
    expect(maxError, lessThan(60));
  });
}
