import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/utils/recording_names.dart';

void main() {
  final date = DateTime(2026, 3, 7, 9, 5);

  test('el provisional es la fecha y la hora, sin dos puntos', () {
    expect(RecordingNames.provisional(date), '2026-03-07 09.05');
  });

  test('con transcripción, la fecha y sus primeras palabras', () {
    expect(
      RecordingNames.fromTranscript(date, ' Hola, ¿qué tal?  '),
      '2026-03-07.Hola, ¿qué tal',
    );
    expect(RecordingNames.fromTranscript(date, '  … '), isNull);
  });

  test('el extracto no corta palabras ni pasa del máximo', () {
    final excerpt = RecordingNames.excerptOf(
      'Bueno, empezamos la reunión con la fecha de lanzamiento: la movemos '
      'a final de mes para que entre la pantalla nueva de grabar',
    );
    expect(
      excerpt,
      // Sin los dos puntos, que no valen en un nombre de archivo.
      'Bueno, empezamos la reunión con la fecha de lanzamiento la movemos '
      'a final de mes para que entre la',
    );
    expect(excerpt.length, lessThanOrEqualTo(RecordingNames.maxExcerptLength));
  });

  test('sin espacios (p. ej. en japonés) se corta sin romper caracteres', () {
    final excerpt = RecordingNames.excerptOf('😀' * 150);
    // Cada emoji ocupa cuatro bytes: caben 50.
    expect(excerpt, '😀' * 50);
    expect(
      RecordingNames.excerptOf('あ' * 150),
      'あ' * (RecordingNames.maxExcerptBytes ~/ 3),
    );
    expect(
      RecordingNames.excerptOf('a' * 150),
      'a' * RecordingNames.maxExcerptLength,
    );
  });

  test('quita lo que no vale en un nombre de archivo', () {
    expect(RecordingNames.excerptOf('a/b\\c:d*e"f<g>h|i'), 'a b c d e f g h i');
    expect(RecordingNames.excerptOf('...oculto'), 'oculto');
  });

  test('withoutDate quita la fecha del principio', () {
    expect(
      RecordingNames.withoutDate('2026-10-05.Hola, ¿qué tal'),
      'Hola, ¿qué tal',
    );
    expect(RecordingNames.withoutDate('2026-10-05 14.32'), '14.32');
    expect(RecordingNames.withoutDate('2026-10-05 14.32 (2)'), '14.32 (2)');
    expect(RecordingNames.withoutDate('2026-10-05_reunión'), 'reunión');
    // Si no queda nada, o no es una fecha al principio, igual.
    expect(RecordingNames.withoutDate('2026-10-05'), '2026-10-05');
    expect(RecordingNames.withoutDate('2026-10-05.'), '2026-10-05.');
    expect(RecordingNames.withoutDate('Idea 2026-10-05'), 'Idea 2026-10-05');
    expect(RecordingNames.withoutDate('2026-10-050'), '2026-10-050');
  });

  test('unique añade un número si el nombre ya está', () {
    expect(RecordingNames.unique('Hola', ['Otra']), 'Hola');
    expect(RecordingNames.unique('Hola', ['hola', 'Hola (2)']), 'Hola (3)');
  });
}
