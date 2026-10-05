import 'package:flutter_test/flutter_test.dart';
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/models/transcription.dart';
import 'package:voicerecorder/utils/search.dart';

void main() {
  Recording recording(String name, {String? transcript}) => Recording(
    id: name,
    path: '/fake/$name.m4a',
    name: name,
    createdAt: DateTime(2026, 10, 5),
    duration: Duration.zero,
    transcript: transcript == null
        ? null
        : Transcript(
            text: transcript,
            engine: TranscriptionEngine.system,
            revision: 0,
            createdAt: DateTime(2026, 10, 5),
          ),
  );

  test('normaliza sin cambiar las posiciones', () {
    expect(normalizeForSearch('Canción ÑANDÚ'), 'cancion nandu');
    expect(searchTerms('  Reunión   lunes '), ['reunion', 'lunes']);
    expect(searchTerms('   '), isEmpty);
  });

  test('busca en el nombre y en la transcripción, sin tildes', () {
    final reunion = recording(
      'Reunión del lunes',
      transcript: 'Hablamos del presupuesto y de las vacaciones.',
    );

    expect(matchesSearch(reunion, searchTerms('reunion')), isTrue);
    expect(matchesSearch(reunion, searchTerms('PRESUPUESTO')), isTrue);
    // Cada palabra puede estar en el nombre o en la transcripción.
    expect(matchesSearch(reunion, searchTerms('lunes vacaciones')), isTrue);
    expect(matchesSearch(reunion, searchTerms('lunes martes')), isFalse);
    expect(
      matchesSearch(recording('Idea'), searchTerms('presupuesto')),
      isFalse,
    );
  });

  test('encuentra los tramos que coinciden, unidos si se solapan', () {
    expect(findMatches('Canción de cuna', ['cancion']), [(start: 0, end: 7)]);
    expect(findMatches('la la la', ['la']), [
      (start: 0, end: 2),
      (start: 3, end: 5),
      (start: 6, end: 8),
    ]);
    expect(findMatches('abcdef', ['abc', 'cde']), [(start: 0, end: 5)]);
    expect(findMatches('nada', ['otro']), isEmpty);
  });

  test('el extracto empieza cerca de la coincidencia', () {
    const text =
        'Al principio hablamos de muchas cosas sin importancia, y al final '
        'decidimos el presupuesto del año que viene.';

    final excerpt = searchExcerpt(text, ['presupuesto'], context: 20);

    expect(excerpt, startsWith('…'));
    expect(excerpt, contains('presupuesto'));
    expect(excerpt.length, lessThan(text.length));
    // Empieza por una palabra entera.
    expect(excerpt.substring(1, 2), isNot(' '));
    // Si está al principio, el texto entero.
    expect(searchExcerpt(text, ['principio']), text);
  });
}
