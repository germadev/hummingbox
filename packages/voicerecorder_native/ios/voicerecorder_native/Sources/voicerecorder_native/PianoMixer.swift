import Foundation

/// Mezcla las notas del piano en un solo flujo de audio, sin chasquidos.
///
/// Cada nota es el sonido de su tecla (muestras de 16 bits, mono, a la
/// frecuencia de la salida), que ya empieza y termina en silencio. Una tecla
/// suena una sola vez: al volver a tocarla, la nota anterior se apaga en
/// `cutFadeMs` en vez de cortarse. Al soltarla o pararla, su volumen baja
/// muestra a muestra. Lo que suenan juntas no pasa de `ceiling`: el volumen de
/// todas baja con una curva suave a lo largo del trozo (`block` fotogramas)
/// anterior al que se pasaría, y vuelve poco a poco (`limitReleaseMs`). Por
/// eso la salida va un trozo por detrás.
///
/// No es seguro entre hilos: lo usa solo el hilo del audio.
final class PianoMixer {
  /// Pico al que se limita lo que suenan juntas (del máximo).
  static let ceiling: Float = 0.9

  /// Fotogramas de cada trozo: lo que va por detrás la salida.
  static let block = 256

  /// Lo que tarda en apagarse una nota al volver a tocar su tecla.
  static let cutFadeMs = 10

  /// Lo que tarda el volumen en volver del todo al dejar de limitar.
  static let limitReleaseMs = 300

  /// Notas que pueden sonar a la vez.
  static let maxVoices = 64

  private static let scale: Float = 1 / 32768

  /// De 0 a 1 a lo largo de un trozo, con una curva suave.
  private static let ramp: [Float] = (0..<PianoMixer.block).map { i in
    Float((1 - cos(Double.pi * Double(i + 1) / Double(PianoMixer.block))) / 2)
  }

  /// El sonido de una tecla: muestras de 16 bits, mono.
  final class Sound {
    let samples: [Int16]

    init(_ samples: [Int16]) {
      self.samples = samples
    }
  }

  private struct Voice {
    let key: Int
    let sound: Sound
    var position = 0
    var gain: Float = 1

    /// Lo que baja `gain` en cada fotograma (al apagarse).
    var fade: Float = 0
  }

  private var voices: [Voice] = []

  /// Fotogramas en los que se apaga una nota al volver a tocar su tecla.
  let cutFadeFrames: Int

  /// Lo que puede subir el volumen de un trozo al siguiente.
  private let releaseStep: Float

  /// El trozo que sale después: mezclado, sin limitar, y su pico.
  private var pending: [Float]
  private var pendingPeak: Float = 0

  /// El trozo siguiente, para saber cómo acaba el volumen de `pending`.
  private var next: [Float]

  /// Volumen al principio de `pending`.
  private var gain: Float = 1

  /// Lo que sale, ya limitado, por dónde va y si suena algo.
  private var output: [Float]
  private var outputPosition: Int
  private var outputSilent = true

  init(sampleRate: Int) {
    cutFadeFrames = max(1, sampleRate * Self.cutFadeMs / 1000)
    releaseStep = Float(Self.block) / (Float(sampleRate) * Float(Self.limitReleaseMs) / 1000)
    pending = [Float](repeating: 0, count: Self.block)
    next = [Float](repeating: 0, count: Self.block)
    output = [Float](repeating: 0, count: Self.block)
    outputPosition = Self.block
    voices.reserveCapacity(Self.maxVoices * 2 + 1)
  }

  /// Si no suena nada ni queda nada por salir.
  var isIdle: Bool {
    voices.isEmpty && pendingPeak == 0 && outputSilent
  }

  /// Suena la tecla `key` con `sound`; si ya sonaba, la anterior se apaga.
  func play(key: Int, sound: Sound) {
    fadeOut(key: key, frames: cutFadeFrames)
    if voices.count >= Self.maxVoices {
      // Sin sitio: se apaga la que lleva más tiempo sonando.
      if let oldest = voices.firstIndex(where: { $0.fade == 0 }) {
        fadeOut(at: oldest, frames: cutFadeFrames)
      }
      if voices.count >= Self.maxVoices * 2 {
        voices.removeFirst()
      }
    }
    voices.append(Voice(key: key, sound: sound))
  }

  /// La tecla `key` se apaga en `frames` fotogramas.
  func fadeOut(key: Int, frames: Int) {
    for index in voices.indices where voices[index].key == key && voices[index].fade == 0 {
      fadeOut(at: index, frames: frames)
    }
  }

  /// Todas las notas se apagan enseguida.
  func stopAll() {
    for index in voices.indices where voices[index].fade == 0 {
      fadeOut(at: index, frames: cutFadeFrames)
    }
  }

  private func fadeOut(at index: Int, frames: Int) {
    voices[index].fade = voices[index].gain / Float(max(1, frames))
  }

  /// Escribe en `out` `frames` fotogramas, entre −1 y 1.
  func render(_ out: UnsafeMutablePointer<Float>, frames: Int) {
    var written = 0
    while written < frames {
      if outputPosition == Self.block {
        nextBlock()
      }
      let count = min(frames - written, Self.block - outputPosition)
      output.withUnsafeBufferPointer { source in
        for i in 0..<count {
          out[written + i] = source[outputPosition + i]
        }
      }
      outputPosition += count
      written += count
    }
  }

  /// Mezcla el trozo siguiente y deja en `output` el que sale, limitado.
  private func nextBlock() {
    let nextPeak = mix(into: &next)
    // El volumen al final de este trozo (y al principio del siguiente) no
    // pasa del que necesitan los dos, y sube poco a poco.
    let end = min(min(limit(of: pendingPeak), limit(of: nextPeak)), gain + releaseStep)
    let start = gain
    let ramp = Self.ramp
    pending.withUnsafeBufferPointer { values in
      output.withUnsafeMutableBufferPointer { out in
        for i in 0..<Self.block {
          let value = values[i] * (start + (end - start) * ramp[i])
          out[i] = min(1, max(-1, value))
        }
      }
    }
    outputPosition = 0
    outputSilent = pendingPeak == 0
    // Se intercambian (sin copiar: cada trozo queda con una sola referencia).
    do {
      let done = pending
      pending = next
      next = done
    }
    pendingPeak = nextPeak
    gain = end
  }

  private func limit(of peak: Float) -> Float {
    peak > Self.ceiling ? Self.ceiling / peak : 1
  }

  /// Suma en `buffer` lo que suenan las notas en un trozo y devuelve su pico.
  private func mix(into buffer: inout [Float]) -> Float {
    let block = Self.block
    let scale = Self.scale
    var peak: Float = 0
    buffer.withUnsafeMutableBufferPointer { into in
      for i in 0..<block {
        into[i] = 0
      }
      var index = 0
      while index < voices.count {
        var voice = voices[index]
        let start = voice.position
        let count = max(0, min(block, voice.sound.samples.count - start))
        var gain = voice.gain
        let fade = voice.fade
        var ended = false
        voice.sound.samples.withUnsafeBufferPointer { samples in
          for i in 0..<count {
            if fade != 0 {
              gain -= fade
              if gain <= 0 {
                ended = true
                break
              }
            }
            into[i] += Float(samples[start + i]) * gain * scale
          }
        }
        voice.gain = gain
        voice.position += count
        if ended || voice.position >= voice.sound.samples.count {
          voices.remove(at: index)
        } else {
          voices[index] = voice
          index += 1
        }
      }
      for i in 0..<block {
        peak = max(peak, abs(into[i]))
      }
    }
    return peak
  }
}
