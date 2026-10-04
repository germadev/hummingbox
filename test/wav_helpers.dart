import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:voicerecorder/audio/wav.dart';

/// Crea un WAV mono con las muestras indicadas.
Future<String> writeWav(
  Directory directory,
  String name,
  List<int> samples, {
  int sampleRate = 1000,
  int channels = 1,
}) async {
  final path = p.join(directory.path, name);
  final writer = await WavWriter.open(
    path,
    PcmFormat(sampleRate: sampleRate, channels: channels),
  );
  await writer.write(Int16List.fromList(samples));
  await writer.close();
  return path;
}

Future<List<int>> readSamples(String path) async {
  final info = await readWavInfo(path);
  return [await for (final block in readWavSamples(path, info)) ...block];
}
