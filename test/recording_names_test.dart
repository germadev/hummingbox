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
      'una dos tres cuatro cinco seis siete ocho nueve diez once doce',
    );
    expect(excerpt, 'una dos tres cuatro cinco seis siete');
    expect(excerpt.length, lessThanOrEqualTo(RecordingNames.maxExcerptLength));
  });

  test('sin espacios (p. ej. en japonés) se corta sin romper caracteres', () {
    final excerpt = RecordingNames.excerptOf('😀' * 50);
    expect(excerpt.runes.length, RecordingNames.maxExcerptLength);
    expect(excerpt, '😀' * RecordingNames.maxExcerptLength);
  });

  test('quita lo que no vale en un nombre de archivo', () {
    expect(RecordingNames.excerptOf('a/b\\c:d*e"f<g>h|i'), 'a b c d e f g h i');
    expect(RecordingNames.excerptOf('...oculto'), 'oculto');
  });

  test('unique añade un número si el nombre ya está', () {
    expect(RecordingNames.unique('Hola', ['Otra']), 'Hola');
    expect(RecordingNames.unique('Hola', ['hola', 'Hola (2)']), 'Hola (3)');
  });
}
