import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recording.dart';

/// Comparte el audio de [path] de una grabación con otras apps usando el
/// nombre que le dio el usuario como nombre de archivo.
Future<void> shareRecording(
  Recording recording, {
  required String path,
  Rect? origin,
}) async {
  final temp = await getTemporaryDirectory();
  final shareDirectory = Directory(p.join(temp.path, 'share'));
  // Limpia las copias de comparticiones anteriores.
  if (await shareDirectory.exists()) {
    await shareDirectory.delete(recursive: true);
  }
  await shareDirectory.create(recursive: true);

  final fileName = safeFileName(recording.name, fallback: recording.id);
  final copy = await File(
    path,
  ).copy(p.join(shareDirectory.path, '$fileName${recording.format.extension}'));

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(copy.path, mimeType: recording.format.mimeType)],
      sharePositionOrigin: origin,
    ),
  );
}

/// Comparte el texto de la transcripción de una grabación.
Future<void> shareText(String text, {String? subject, Rect? origin}) =>
    SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );

/// Sustituye los caracteres no válidos en nombres de archivo.
String safeFileName(String name, {required String fallback}) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return cleaned.isEmpty || cleaned == '.' || cleaned == '..'
      ? fallback
      : cleaned;
}
