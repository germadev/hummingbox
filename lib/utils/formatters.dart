import 'package:intl/intl.dart';

/// Formatea una duración como `mm:ss` (o `h:mm:ss` si supera una hora).
///
/// Con [showTenths] añade las décimas de segundo: `mm:ss,d`.
String formatDuration(Duration duration, {bool showTenths = false}) {
  if (duration.isNegative) duration = Duration.zero;

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final buffer = StringBuffer();
  if (hours > 0) {
    buffer
      ..write(hours)
      ..write(':');
  }
  buffer
    ..write(minutes.toString().padLeft(2, '0'))
    ..write(':')
    ..write(seconds.toString().padLeft(2, '0'));
  if (showTenths) {
    final tenths = duration.inMilliseconds.remainder(1000) ~/ 100;
    buffer
      ..write(',')
      ..write(tenths);
  }
  return buffer.toString();
}

/// Formatea la fecha de una grabación de forma relativa a [now]:
/// `Hoy, 17:45`, `Ayer, 09:03` o `4 oct 2026, 17:45`.
String formatRecordingDate(DateTime date, {DateTime? now}) {
  now ??= DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final time = DateFormat.Hm('es').format(date);

  if (day == today) return 'Hoy, $time';
  if (day == yesterday) return 'Ayer, $time';
  return '${DateFormat('d MMM yyyy', 'es').format(date)}, $time';
}

/// Formatea una ganancia en decibelios: `+3,5 dB`, `−2,0 dB` o `0 dB`.
String formatGain(double db) {
  if (db == 0) return '0 dB';
  final value = NumberFormat('0.0', 'es').format(db.abs());
  return '${db > 0 ? '+' : '−'}$value dB';
}

/// Formatea una duración corta en segundos con una décima: `1,5 s`.
String formatSeconds(Duration duration) =>
    '${NumberFormat('0.0', 'es').format(duration.inMilliseconds / 1000)} s';
