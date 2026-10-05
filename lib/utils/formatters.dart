import 'package:intl/intl.dart';

import '../audio/audio_info.dart';
import '../l10n/app_localizations.dart';
import '../models/recording_options.dart';

// Los números y las fechas siguen el idioma de la app (`Intl.defaultLocale`,
// que fija `VoiceRecorderApp`).

/// Formatea una duración como `mm:ss` (o `h:mm:ss` si supera una hora).
///
/// Con [showTenths] añade las décimas de segundo con el separador decimal
/// del idioma: `mm:ss,d` o `mm:ss.d`.
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
      ..write(NumberFormat().symbols.DECIMAL_SEP)
      ..write(tenths);
  }
  return buffer.toString();
}

/// Formatea la fecha de una grabación de forma relativa a [now]:
/// `Hoy, 17:45`, `Ayer, 09:03` o `4 oct 2026, 17:45` (en español).
String formatRecordingDate(
  DateTime date,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final time = DateFormat.Hm().format(date);

  if (day == today) return l10n.dateToday(time);
  if (day == yesterday) return l10n.dateYesterday(time);
  return l10n.dateOther(DateFormat.yMMMd().format(date), time);
}

/// Formatea una ganancia en decibelios: `+3,5 dB`, `−2,0 dB` o `0 dB`.
String formatGain(double db) {
  if (db == 0) return '0 dB';
  final value = NumberFormat('0.0').format(db.abs());
  return '${db > 0 ? '+' : '−'}$value dB';
}

/// Formatea una duración corta en segundos con una décima: `1,5 s`.
String formatSeconds(Duration duration) =>
    '${NumberFormat('0.0').format(duration.inMilliseconds / 1000)} s';

/// Nombre corto de un formato: `AAC` o `WAV`.
String formatName(RecordingFormat format) => switch (format) {
  RecordingFormat.aac => 'AAC',
  RecordingFormat.wav => 'WAV',
};

/// Frecuencia de muestreo: `44,1 kHz`, `16 kHz`.
String formatSampleRate(int hertz) =>
    '${NumberFormat('0.##').format(hertz / 1000)} kHz';

/// Tasa de bits: `128 kbps`.
String formatBitRate(int bitsPerSecond) =>
    '${(bitsPerSecond / 1000).round()} kbps';

/// Porcentaje sin decimales, con el formato del idioma: `45 %` o `45%`.
String formatPercent(double fraction) =>
    NumberFormat.percentPattern().format(fraction.clamp(0.0, 1.0));

/// Tamaño en megabytes, con una decimal como mucho: `0,5 MB`, `5,3 MB`.
String formatMegabytes(int bytes) =>
    '${NumberFormat('0.#').format(bytes / 1000000)} MB';

/// Formato y calidad de un archivo de audio: `AAC · 128 kbps · 44,1 kHz` o
/// `WAV · 16 bits · 48 kHz · estéreo` (en español).
String formatAudioInfo(AudioInfo info, AppLocalizations l10n) {
  return [
    formatName(info.format),
    if (info.bitRate case final bitRate?) formatBitRate(bitRate),
    if (info.bitsPerSample case final bits?) l10n.bitDepth(bits),
    formatSampleRate(info.sampleRate),
    if (info.channels == 2) l10n.stereo,
    if (info.channels > 2) l10n.channels(info.channels),
  ].join(' · ');
}
