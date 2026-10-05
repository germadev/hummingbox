import 'dart:convert';

/// Nombres automáticos de las grabaciones nuevas (y de sus archivos):
/// «2026-10-05 14.32» mientras no tienen transcripción y
/// «2026-10-05.hola qué tal» cuando la tienen.
abstract final class RecordingNames {
  /// Caracteres, como mucho, del principio de la transcripción en el nombre.
  static const maxExcerptLength = 100;

  /// Bytes (en UTF-8), como mucho, del principio de la transcripción en el
  /// nombre: los nombres de archivo suelen poder tener 255, y en japonés o
  /// chino cada carácter ocupa tres.
  static const maxExcerptBytes = 200;

  /// Nombre provisional de una grabación creada en [createdAt]: la fecha y
  /// la hora (con punto, que los dos puntos no valen en un nombre de
  /// archivo).
  static String provisional(DateTime createdAt) =>
      '${_date(createdAt)} ${_two(createdAt.hour)}.${_two(createdAt.minute)}';

  /// Nombre de una grabación creada en [createdAt] con la transcripción
  /// [text]: la fecha y el principio del texto. `null` si el texto no tiene
  /// nada que se pueda usar.
  static String? fromTranscript(DateTime createdAt, String text) {
    final excerpt = excerptOf(text);
    return excerpt.isEmpty ? null : '${_date(createdAt)}.$excerpt';
  }

  /// Las primeras palabras de [text] (hasta [maxExcerptLength] caracteres
  /// y [maxExcerptBytes] bytes), sin lo que no vale en un nombre de archivo
  /// ni la puntuación de los extremos.
  static String excerptOf(String text) {
    final words = text
        .replaceAll(_invalid, ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    var excerpt = '';
    for (final word in words) {
      final longer = excerpt.isEmpty ? word : '$excerpt $word';
      if (!_fits(longer)) {
        // Una sola palabra muy larga (o un texto sin espacios, como en
        // japonés o chino): se corta.
        if (excerpt.isEmpty) {
          for (final char in word.runes) {
            final next = excerpt + String.fromCharCode(char);
            if (!_fits(next)) break;
            excerpt = next;
          }
        }
        break;
      }
      excerpt = longer;
    }
    return excerpt.replaceAll(_edgePunctuation, '');
  }

  /// [name] sin la fecha del principio («2026-10-05.hola qué tal» →
  /// «hola qué tal»), para mostrarlo junto a la fecha de la grabación. Si
  /// no queda nada, [name].
  static String withoutDate(String name) {
    final rest = name.replaceFirst(_leadingDate, '');
    return rest.isEmpty ? name : rest;
  }

  static final _leadingDate = RegExp(r'^\d{4}-\d{2}-\d{2}(?:[.\s_-]+|$)');

  /// [name] o, si ya lo tiene otra grabación de la misma carpeta ([taken],
  /// sin distinguir mayúsculas, como muchos sistemas de archivos), con un
  /// número detrás: «… (2)», «… (3)»…
  static String unique(String name, Iterable<String> taken) {
    final used = {for (final other in taken) other.toLowerCase()};
    if (!used.contains(name.toLowerCase())) return name;
    for (var number = 2; ; number++) {
      final candidate = '$name ($number)';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
  }

  static bool _fits(String excerpt) =>
      excerpt.runes.length <= maxExcerptLength &&
      utf8.encode(excerpt).length <= maxExcerptBytes;

  static final _invalid = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
  static final _edgePunctuation = RegExp(
    r'^[\s\p{P}]+|[\s\p{P}]+$',
    unicode: true,
  );

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
      '${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
