import 'dart:math' as math;
import 'dart:typed_data';

import 'wav.dart';

/// Frecuencia de muestreo con la que trabajan los reconocedores de voz.
const speechSampleRate = 16000;

/// Formato del audio que se transcribe: 16 kHz y un canal.
const speechFormat = PcmFormat(sampleRate: speechSampleRate, channels: 1);

/// Muestras de cada bloque con el que se mide el nivel: 100 ms.
const speechBlockFrames = speechSampleRate ~/ 10;

/// Audio preparado para transcribir: un WAV de 16 kHz y un canal, y la
/// energía de cada bloque de 100 ms (para dividirlo por los silencios).
class SpeechAudio {
  const SpeechAudio({
    required this.path,
    required this.info,
    required this.energies,
  });

  final String path;
  final WavInfo info;

  /// Media de los cuadrados de las muestras (0–1) de cada bloque de
  /// [speechBlockFrames].
  final List<double> energies;

  Duration get duration => info.duration;
}

/// Convierte el WAV PCM de 16 bits de [input] (con cualquier frecuencia y
/// número de canales) en un WAV de 16 kHz y un canal en [output], por
/// bloques, sin cargarlo entero en memoria.
///
/// Al reducir la frecuencia, cada muestra es la media de las que sustituye
/// (así se atenúan las frecuencias que no caben); al aumentarla, se
/// interpola.
Future<SpeechAudio> convertToSpeechAudio(String input, String output) async {
  final source = await readWavInfo(input);
  final channels = source.format.channels;
  final writer = await WavWriter.open(output, speechFormat);
  final resampler = _Resampler(source.format.sampleRate / speechSampleRate);
  final energies = <double>[];
  var blockSum = 0.0;
  var blockCount = 0;
  final pending = <int>[];

  Future<void> flush() async {
    if (pending.isEmpty) return;
    await writer.write(Int16List.fromList(pending));
    pending.clear();
  }

  void emit(double sample) {
    final value = sample.clamp(-32768.0, 32767.0).round();
    pending.add(value);
    final normalized = value / 32768;
    blockSum += normalized * normalized;
    if (++blockCount == speechBlockFrames) {
      energies.add(blockSum / blockCount);
      blockSum = 0;
      blockCount = 0;
    }
  }

  try {
    await for (final samples in readWavSamples(input, source)) {
      for (var i = 0; i + channels <= samples.length; i += channels) {
        var sum = 0;
        for (var c = 0; c < channels; c++) {
          sum += samples[i + c];
        }
        resampler.add(sum / channels, emit);
      }
      await flush();
    }
    if (blockCount > 0) energies.add(blockSum / blockCount);
  } finally {
    await flush();
    await writer.close();
  }
  return SpeechAudio(
    path: output,
    info: await readWavInfo(output),
    energies: energies,
  );
}

/// Cambia la frecuencia de muestreo de un canal sobre la marcha.
class _Resampler {
  _Resampler(this.ratio);

  /// Muestras de entrada por cada muestra de salida.
  final double ratio;

  // Al reducir: suma y número de las muestras de la salida en curso, y
  // cuántas se han emitido (la siguiente acaba en la muestra de entrada
  // `(_emitted + 1) * ratio`; se calcula cada vez para no acumular errores).
  double _sum = 0;
  int _count = 0;
  int _emitted = 0;

  // Al aumentar: posición de la siguiente muestra de salida (en muestras de
  // entrada) y la muestra anterior.
  double _next = 0;
  double _previous = 0;

  int _index = 0;

  void add(double sample, void Function(double sample) emit) {
    if (ratio == 1) {
      emit(sample);
    } else if (ratio > 1) {
      _sum += sample;
      _count++;
      _index++;
      if (_index >= (_emitted + 1) * ratio - 1e-6) {
        emit(_sum / _count);
        _sum = 0;
        _count = 0;
        _emitted++;
      }
    } else {
      // La muestra [_index] está en esa posición; entre ella y la anterior
      // se interpola.
      while (_next <= _index) {
        final fraction = _next - (_index - 1);
        emit(
          _index == 0 ? sample : _previous + (sample - _previous) * fraction,
        );
        _next += ratio;
      }
      _previous = sample;
      _index++;
    }
  }
}

/// Tramo de audio que se transcribe de una vez: las muestras `[start, end)`.
typedef SpeechChunk = ({int start, int end});

/// Divide [frameCount] muestras de 16 kHz en tramos de [maxLength] como
/// mucho, para los reconocedores que no admiten audios largos (o para no
/// cargar en memoria uno muy largo).
///
/// Cada corte se hace en el bloque de 100 ms más silencioso (según
/// [energies]) de los últimos [window] antes del límite, para no partir una
/// palabra.
List<SpeechChunk> planSpeechChunks(
  List<double> energies,
  int frameCount, {
  required Duration maxLength,
  Duration window = const Duration(seconds: 10),
}) {
  final maxFrames = speechFormat.framesIn(maxLength);
  final windowFrames = math.min(speechFormat.framesIn(window), maxFrames ~/ 2);
  final chunks = <SpeechChunk>[];
  var start = 0;
  while (frameCount - start > maxFrames) {
    final limit = start + maxFrames;
    // Bloques completos entre el principio de la ventana y el límite.
    final first = (limit - windowFrames) ~/ speechBlockFrames;
    final last = math.min(limit ~/ speechBlockFrames, energies.length) - 1;
    var cut = limit;
    if (last >= first && first >= 0) {
      var quietest = last;
      for (var block = last; block >= first; block--) {
        if (energies[block] < energies[quietest]) quietest = block;
      }
      cut = quietest * speechBlockFrames + speechBlockFrames ~/ 2;
    }
    if (cut <= start) cut = limit;
    chunks.add((start: start, end: cut));
    start = cut;
  }
  chunks.add((start: start, end: frameCount));
  return chunks;
}

/// Lee las muestras `[start, end)` del WAV de 16 kHz y un canal de [path]
/// como números de -1 a 1, como los espera Whisper.
Future<Float32List> readSpeechSamples(
  String path,
  WavInfo info, {
  int start = 0,
  int? end,
}) async {
  final last = math.min(end ?? info.frameCount, info.frameCount);
  final samples = Float32List(math.max(0, last - start));
  var offset = 0;
  await for (final block in readWavSamples(
    path,
    info,
    start: start,
    end: last,
  )) {
    for (var i = 0; i < block.length && offset < samples.length; i++) {
      samples[offset++] = block[i] / 32768;
    }
  }
  return offset == samples.length
      ? samples
      : Float32List.sublistView(samples, 0, offset);
}

/// Copia las muestras `[start, end)` del WAV de [input] a un WAV nuevo en
/// [output].
Future<WavInfo> writeSpeechChunk(
  String input,
  WavInfo info,
  String output, {
  required int start,
  required int end,
}) async {
  final writer = await WavWriter.open(output, info.format);
  try {
    await for (final block in readWavSamples(
      input,
      info,
      start: start,
      end: end,
    )) {
      await writer.write(block);
    }
  } finally {
    await writer.close();
  }
  return readWavInfo(output);
}
