import AVFoundation
import Flutter

/// Convierte entre audio comprimido y WAV PCM de 16 bits con AVAudioFile.
final class AudioCodecHandler {
  private let runner = BackgroundRunner(label: "es.germade.voicerecorder.audio_codec")

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let input = args["input"] as? String,
      let output = args["output"] as? String
    else {
      if call.method == "decodeToWav" || call.method == "encodeToM4a" {
        badArguments(result)
      } else {
        result(FlutterMethodNotImplemented)
      }
      return
    }
    let inputURL = URL(fileURLWithPath: input)
    let outputURL = URL(fileURLWithPath: output)

    switch call.method {
    case "decodeToWav":
      runner.run(result) {
        try AudioCodec.decodeToWav(input: inputURL, output: outputURL)
        return nil
      }
    case "encodeToM4a":
      let bitRate = args["bitRate"] as? Int ?? 128_000
      runner.run(result) {
        try AudioCodec.encodeToM4a(input: inputURL, output: outputURL, bitRate: bitRate)
        return nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

enum AudioCodec {
  static func decodeToWav(input: URL, output: URL) throws {
    try convert(input: input, output: output) { format in
      [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    }
  }

  static func encodeToM4a(input: URL, output: URL, bitRate: Int) throws {
    try convert(input: input, output: output) { format in
      [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVEncoderBitRateKey: bitRate,
      ]
    }
  }

  /// Lee [input] y lo escribe en [output] con los ajustes de archivo que
  /// devuelve [settings]. El tipo de archivo se deduce de la extensión de
  /// [output] (`.wav` o `.m4a`).
  private static func convert(
    input: URL,
    output: URL,
    settings: (AVAudioFormat) -> [String: Any]
  ) throws {
    try autoreleasepool {
      let source = try AVAudioFile(forReading: input)
      let format = source.processingFormat
      try? FileManager.default.removeItem(at: output)

      // El archivo de salida se cierra (y se termina de escribir) al liberarse.
      var destination: AVAudioFile? = try AVAudioFile(
        forWriting: output,
        settings: settings(format),
        commonFormat: format.commonFormat,
        interleaved: format.isInterleaved)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else {
        throw NativeError("No se pudo preparar la conversión del audio")
      }
      while source.framePosition < source.length {
        try source.read(into: buffer)
        if buffer.frameLength == 0 { break }
        try destination?.write(from: buffer)
      }
      if #available(iOS 18.0, *) {
        destination?.close()
      }
      destination = nil
    }
  }
}
