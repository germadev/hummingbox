import 'dart:math' as math;

import '../models/recording.dart';

/// Letras con tilde o signos que se buscan como su letra base («Grabación»
/// aparece al buscar «grabacion»). Cada una se sustituye por una sola letra,
/// así que las posiciones del texto normalizado son las del original.
const _folded = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
};

/// [text] en minúsculas y sin tildes, con la misma longitud que el original.
String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  if (lower.length != text.length) return lower;
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    buffer.write(_folded[char] ?? char);
  }
  return buffer.toString();
}

/// Palabras de una búsqueda, normalizadas. Vacío si no hay nada que buscar.
List<String> searchTerms(String query) => [
  for (final term in normalizeForSearch(query).split(RegExp(r'\s+')))
    if (term.isNotEmpty) term,
];

/// Indica si [recording] tiene todas las palabras de [terms] en su nombre o
/// en su transcripción (cada palabra en cualquiera de los dos).
bool matchesSearch(Recording recording, List<String> terms) {
  if (terms.isEmpty) return true;
  final name = normalizeForSearch(recording.name);
  final transcript = normalizeForSearch(recording.transcript?.text ?? '');
  return terms.every(
    (term) => name.contains(term) || transcript.contains(term),
  );
}

/// Tramo `[start, end)` de un texto.
typedef TextRange = ({int start, int end});

/// Tramos de [text] donde aparece alguna de las palabras de [terms], en
/// orden y sin solaparse.
List<TextRange> findMatches(String text, List<String> terms) {
  if (terms.isEmpty || text.isEmpty) return const [];
  final normalized = normalizeForSearch(text);
  if (normalized.length != text.length) return const [];
  final ranges = <TextRange>[];
  for (final term in terms) {
    var from = 0;
    while (true) {
      final index = normalized.indexOf(term, from);
      if (index < 0) break;
      ranges.add((start: index, end: index + term.length));
      from = index + term.length;
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <TextRange>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: math.max(last.end, range.end)));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// Parte de [text] alrededor de la primera palabra de [terms] que aparece
/// en él, empezando por una palabra entera y con «…» si no es el principio,
/// para que la coincidencia se vea en las primeras líneas. Si no aparece
/// ninguna, el texto entero.
String searchExcerpt(String text, List<String> terms, {int context = 40}) {
  final matches = findMatches(text, terms);
  if (matches.isEmpty || matches.first.start <= context) return text;
  var start = matches.first.start - context;
  // Desde el principio de la palabra siguiente.
  final space = text.indexOf(' ', start);
  if (space >= 0 && space < matches.first.start) start = space + 1;
  return '…${text.substring(start)}';
}
