import 'dart:math' as math;

import '../models/recording.dart';
import '../models/transcription.dart';

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

/// [_folded] por código de carácter.
final _foldedUnits = {
  for (final MapEntry(:key, :value) in _folded.entries)
    key.codeUnitAt(0): value.codeUnitAt(0),
};

/// [text] en minúsculas y sin tildes, con la misma longitud que el original.
String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  if (lower.length != text.length) return lower;
  // Solo se copia si hay algo que cambiar (las letras con tilde, ya en
  // minúscula, van de «à» en adelante).
  List<int>? units;
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    if (unit < 0xE0) continue;
    if (_foldedUnits[unit] case final folded?) {
      (units ??= lower.codeUnits.toList())[i] = folded;
    }
  }
  return units == null ? lower : String.fromCharCodes(units);
}

/// Palabras de una búsqueda, normalizadas. Vacío si no hay nada que buscar.
List<String> searchTerms(String query) => [
  for (final term in normalizeForSearch(query).split(RegExp(r'\s+')))
    if (term.isNotEmpty) term,
];

/// Tramo `[start, end)` de un texto.
typedef TextRange = ({int start, int end});

/// Tramos de [text] donde aparece alguna de las palabras de [terms], en
/// orden y sin solaparse.
List<TextRange> findMatches(String text, List<String> terms) {
  if (terms.isEmpty || text.isEmpty) return const [];
  final normalized = normalizeForSearch(text);
  if (normalized.length != text.length) return const [];
  return _merge(_exactRanges(normalized, terms));
}

List<TextRange> _exactRanges(String normalized, List<String> terms) => [
  for (final term in terms) ..._occurrences(normalized, term),
];

Iterable<TextRange> _occurrences(String normalized, String term) sync* {
  var from = 0;
  while (true) {
    final index = normalized.indexOf(term, from);
    if (index < 0) return;
    yield (start: index, end: index + term.length);
    from = index + term.length;
  }
}

/// [ranges] en orden y unidos si se solapan.
List<TextRange> _merge(List<TextRange> ranges) {
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
String searchExcerpt(String text, List<String> terms, {int context = 40}) =>
    _excerpt(text, findMatches(text, terms), context: context);

String _excerpt(String text, List<TextRange> matches, {required int context}) {
  if (matches.isEmpty || matches.first.start <= context) return text;
  var start = matches.first.start - context;
  // Desde el principio de la palabra siguiente.
  final space = text.indexOf(' ', start);
  if (space >= 0 && space < matches.first.start) start = space + 1;
  return '…${text.substring(start)}';
}

/// Palabras de un texto ya normalizado (letras y números seguidos).
final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Palabras solo de letras: en las que llevan números («2024») no se buscan
/// parecidas.
final _lettersOnly = RegExp(r'^\p{L}+$', unicode: true);

/// Letras de los idiomas que no separan las palabras (chino, japonés,
/// coreano): en ellos tampoco.
final _unspacedScript = RegExp(
  '[\u2E80-\u9FFF\uAC00-\uD7AF\uF900-\uFAFF\uFF66-\uFF9F]',
);

/// Cambios que se admiten en una palabra buscada de [length] letras para
/// encontrar otras parecidas: ninguno hasta 3 letras, 1 hasta 6 y 2 en las
/// más largas.
int allowedChanges(int length) => length <= 3 ? 0 : (length <= 6 ? 1 : 2);

/// Letras de más que puede tener al final una palabra parecida (plurales,
/// femeninos, terminaciones…).
const _extraEnding = 3;

/// Indica si para la palabra buscada [term] (normalizada) se buscan también
/// parecidas: si tiene 4 letras o más, solo letras, y no es de un idioma que
/// no separa las palabras.
bool findsSimilarWords(String term) =>
    allowedChanges(term.length) > 0 &&
    _lettersOnly.hasMatch(term) &&
    !_unspacedScript.hasMatch(term);

/// Indica si [word] se parece a la palabra buscada [term] (las dos ya
/// normalizadas): si basta con [allowedChanges] cambios (una letra de más,
/// de menos o distinta, o dos seguidas al revés) para pasar de [term] a
/// [word] o a su principio, sin que sobren más de 3 letras al final. Así
/// «reunon» y «reuniones» encuentran «reunión», y «reunion», «reuniones».
bool isSimilarWord(String term, String word) {
  if (!findsSimilarWords(term)) return false;
  return _isSimilarUnchecked(term, word);
}

bool _isSimilarUnchecked(String term, String word) {
  final changes = allowedChanges(term.length);
  final n = term.length;
  // Principios de [word] que pueden servir: los de n ± changes letras que
  // dejan como mucho 3 letras al final.
  final shortest = math.max(n - changes, word.length - _extraEnding);
  final longest = math.min(word.length, n + changes);
  if (shortest > longest) return false;

  // Distancia entre [term] y cada principio de [word], fila a fila (con las
  // dos filas anteriores, para las letras al revés).
  var before = List<int>.filled(longest + 1, 0);
  var previous = List<int>.generate(longest + 1, (j) => j);
  for (var i = 1; i <= n; i++) {
    final current = List<int>.filled(longest + 1, 0)..[0] = i;
    for (var j = 1; j <= longest; j++) {
      final same = term.codeUnitAt(i - 1) == word.codeUnitAt(j - 1);
      var best = math.min(
        math.min(previous[j] + 1, current[j - 1] + 1),
        previous[j - 1] + (same ? 0 : 1),
      );
      if (i > 1 &&
          j > 1 &&
          term.codeUnitAt(i - 1) == word.codeUnitAt(j - 2) &&
          term.codeUnitAt(i - 2) == word.codeUnitAt(j - 1)) {
        best = math.min(best, before[j - 2] + 1);
      }
      current[j] = best;
    }
    before = previous;
    previous = current;
  }
  for (var j = shortest; j <= longest; j++) {
    if (previous[j] <= changes) return true;
  }
  return false;
}

/// Cómo encuentra una búsqueda una grabación.
enum SearchMatch {
  none,

  /// Con alguna palabra parecida.
  similar,

  /// Con todas las palabras tal cual.
  exact,
}

/// Una búsqueda: sus palabras y si encuentra también las parecidas (ver
/// [isSimilarWord]).
///
/// Recuerda qué palabras ha comparado y lo que ha encontrado en cada texto,
/// así que conviene reutilizarla mientras no cambie lo buscado.
class SearchQuery {
  SearchQuery(this.text, {this.similar = false}) : terms = searchTerms(text) {
    _withSimilar.addAll(terms.where(findsSimilarWords));
  }

  /// Lo escrito.
  final String text;

  /// Si encuentra también las palabras parecidas.
  final bool similar;

  /// Palabras buscadas, normalizadas.
  final List<String> terms;

  bool get isEmpty => terms.isEmpty;

  /// Palabras buscadas para las que se buscan también parecidas (ver
  /// [findsSimilarWords]).
  final _withSimilar = <String>{};

  /// Si cada palabra buscada se parece a cada palabra ya comparada.
  final _compared = <String, Map<String, bool>>{};

  bool _isSimilar(String term, String word) =>
      _canBeSimilar(term, word.length) &&
      _compared
          .putIfAbsent(term, () => {})
          .putIfAbsent(word, () => _isSimilarUnchecked(term, word));

  /// Indica si una palabra de [length] letras puede parecerse a [term] (ver
  /// [isSimilarWord]): las demás ni se comparan.
  bool _canBeSimilar(String term, int length) {
    if (!_withSimilar.contains(term)) return false;
    final changes = allowedChanges(term.length);
    return length >= term.length - changes &&
        length <= term.length + changes + _extraEnding;
  }

  /// Indica si [transcript] tiene alguna palabra parecida a [term], mirando
  /// solo las de una longitud que puede servir.
  bool _hasSimilar(String term, _Indexed transcript) {
    for (final MapEntry(key: length, value: words)
        in transcript.wordsByLength.entries) {
      if (!_canBeSimilar(term, length)) continue;
      if (words.any((word) => _isSimilar(term, word))) return true;
    }
    return false;
  }

  /// Cómo encuentra [recording]: cada palabra buscada tiene que estar (o,
  /// si se buscan parecidas, una parecida) en su nombre o en su
  /// transcripción.
  SearchMatch matchOf(Recording recording) {
    if (isEmpty) return SearchMatch.exact;
    final name = normalizeForSearch(recording.name);
    final transcript = switch (recording.transcript) {
      final transcript? => _Indexed.of(transcript),
      null => null,
    };
    var result = SearchMatch.exact;
    for (final term in terms) {
      if (name.contains(term) || (transcript?.text.contains(term) ?? false)) {
        continue;
      }
      if (!similar) return SearchMatch.none;
      final found =
          _words(name).any((word) => _isSimilar(term, word)) ||
          (transcript != null && _hasSimilar(term, transcript));
      if (!found) return SearchMatch.none;
      result = SearchMatch.similar;
    }
    return result;
  }

  final _matches = <String, List<TextRange>>{};
  final _excerpts = <String, String>{};

  /// Tramos de [text] donde aparece alguna de las palabras buscadas o, si se
  /// buscan parecidas, una parecida (la palabra entera), en orden y sin
  /// solaparse.
  List<TextRange> findMatchesIn(String text) =>
      _matches[text] ??= _findMatchesIn(text);

  List<TextRange> _findMatchesIn(String text) {
    if (isEmpty || text.isEmpty) return const [];
    final normalized = normalizeForSearch(text);
    if (normalized.length != text.length) return const [];
    final ranges = _exactRanges(normalized, terms);
    if (similar) {
      for (final word in _wordPattern.allMatches(normalized)) {
        if (terms.any((term) => _isSimilar(term, word[0]!))) {
          ranges.add((start: word.start, end: word.end));
        }
      }
    }
    return _merge(ranges);
  }

  /// Como [searchExcerpt], con las palabras parecidas si se buscan.
  String excerpt(String text) =>
      _excerpts[text] ??= _excerpt(text, findMatchesIn(text), context: 40);

  static Iterable<String> _words(String normalized) =>
      _wordPattern.allMatches(normalized).map((match) => match[0]!);
}

/// Una transcripción normalizada y sus palabras distintas (por longitud),
/// calculadas una vez por transcripción (las palabras, solo si se buscan
/// parecidas).
class _Indexed {
  _Indexed(String text) : text = normalizeForSearch(text);

  final String text;

  late final Map<int, Set<String>> wordsByLength = () {
    final words = <int, Set<String>>{};
    for (final word in SearchQuery._words(text)) {
      words.putIfAbsent(word.length, () => {}).add(word);
    }
    return words;
  }();

  static final _cache = Expando<_Indexed>();

  static _Indexed of(Transcript transcript) =>
      _cache[transcript] ??= _Indexed(transcript.text);
}
