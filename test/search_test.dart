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

    SearchMatch match(Recording recording, String text) =>
        SearchQuery(text).matchOf(recording);

    expect(match(reunion, 'reunion'), SearchMatch.exact);
    expect(match(reunion, 'PRESUPUESTO'), SearchMatch.exact);
    // Cada palabra puede estar en el nombre o en la transcripción.
    expect(match(reunion, 'lunes vacaciones'), SearchMatch.exact);
    expect(match(reunion, 'lunes martes'), SearchMatch.none);
    expect(match(recording('Idea'), 'presupuesto'), SearchMatch.none);
    // Sin palabras parecidas, una errata no encuentra nada.
    expect(match(reunion, 'presupusto'), SearchMatch.none);
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

  group('palabras parecidas', () {
    bool similar(String term, String word) =>
        isSimilarWord(normalizeForSearch(term), normalizeForSearch(word));

    test('admite más cambios cuanto más larga es la palabra', () {
      expect(allowedChanges(3), 0);
      expect(allowedChanges(4), 1);
      expect(allowedChanges(6), 1);
      expect(allowedChanges(7), 2);
      expect(similar('sol', 'sal'), isFalse);
      expect(similar('reunon', 'reunión'), isTrue);
      expect(similar('rnuon', 'reunión'), isFalse);
      expect(similar('presupusto', 'presupuesto'), isTrue);
    });

    test('letras de más, de menos, distintas o al revés', () {
      expect(similar('reunion', 'reuinon'), isTrue);
      expect(similar('Ialta', 'Yalta'), isTrue);
      expect(similar('exmen', 'examen'), isTrue);
      expect(similar('examne', 'examen'), isTrue);
    });

    test('plurales y terminaciones, pero no palabras más largas', () {
      expect(similar('reuniones', 'reunión'), isTrue);
      expect(similar('reunon', 'reuniones'), isTrue);
      expect(similar('cosa', 'casamiento'), isFalse);
      expect(similar('certa', 'cartagenero'), isFalse);
    });

    test('ni números ni idiomas sin espacios entre palabras', () {
      expect(similar('2024', '2025'), isFalse);
      expect(similar('会議資料', '会議資金'), isFalse);
    });

    test('los ejemplos de las opciones', () {
      expect(similar('reunon', 'reunión'), isTrue);
      expect(similar('reuniones', 'reunión'), isTrue);
      expect(similar('meetng', 'meeting'), isTrue);
      expect(similar('meetings', 'meeting'), isTrue);
      expect(similar('reunon', 'réunion'), isTrue);
      expect(similar('réunions', 'réunion'), isTrue);
      expect(similar('Besprechng', 'Besprechung'), isTrue);
      expect(similar('Besprechungen', 'Besprechung'), isTrue);
      expect(similar('riunone', 'riunione'), isTrue);
      expect(similar('riunioni', 'riunione'), isTrue);
      expect(similar('reunao', 'reunião'), isTrue);
    });

    test('encuentra con palabras parecidas, después de las exactas', () {
      final reunion = recording(
        'Reunión del lunes',
        transcript: 'Hablamos del presupuesto y de las vacaciones.',
      );

      expect(
        SearchQuery('reuniones presupusto', similar: true).matchOf(reunion),
        SearchMatch.similar,
      );
      expect(
        SearchQuery('reunion', similar: true).matchOf(reunion),
        SearchMatch.exact,
      );
      expect(
        SearchQuery('reuniones martes', similar: true).matchOf(reunion),
        SearchMatch.none,
      );
    });

    test(
      'resalta la palabra parecida entera y el extracto empieza en ella',
      () {
        final query = SearchQuery('presupusto', similar: true);
        const text =
            'Al principio hablamos de muchas cosas sin importancia, y al final '
            'decidimos el presupuesto del año que viene.';

        final matches = query.findMatchesIn(text);
        expect(matches, hasLength(1));
        expect(
          text.substring(matches.single.start, matches.single.end),
          'presupuesto',
        );
        expect(query.excerpt(text), startsWith('…'));
        expect(query.excerpt(text), contains('presupuesto'));
        // Sin palabras parecidas, nada.
        expect(SearchQuery('presupusto').findMatchesIn(text), isEmpty);
      },
    );
  });
}
