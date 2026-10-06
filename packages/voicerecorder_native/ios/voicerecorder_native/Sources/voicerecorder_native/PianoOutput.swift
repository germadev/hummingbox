import AVFoundation
import Flutter

/// Suena el piano por un solo nodo de AVAudioEngine, con las notas mezcladas
/// por `PianoMixer` en el hilo del audio: el sistema no tiene que sumar ni
/// cortar reproductores, que es lo que hacía chasquear al tocar.
///
/// Los sonidos de las teclas son WAV mono de 16 bits a la frecuencia de la
/// salida (los escribe la app), que se leen una vez («load») y se tocan por su
/// ruta. Sin notas durante `idleSeconds`, el motor se pausa hasta la
/// siguiente. Las llamadas llegan en el hilo principal.
final class PianoOutput {
  /// Lo que sigue el motor en marcha sin sonar nada.
  private static let idleSeconds: TimeInterval = 20

  private let engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private var sampleRate: Double = 0
  private var sounds: [String: PianoMixer.Sound] = [:]
  private let commands = PianoCommands()
  private var lastActivity = Date()
  private var idleTimer: Timer?
  private var observer: NSObjectProtocol?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "open":
      do {
        try start()
        result(["sampleRate": Int(sampleRate)])
      } catch {
        result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
      }
    case "load":
      guard let path = args["path"] as? String else { return badArguments(result) }
      if sounds[path] != nil { return result(nil) }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let sound = try PianoMixer.Sound(readSamples(path))
          DispatchQueue.main.async {
            self.sounds[path] = sound
            result(nil)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    case "unload":
      for path in args["paths"] as? [String] ?? [] {
        sounds.removeValue(forKey: path)
      }
      result(nil)
    case "play":
      guard let key = args["key"] as? Int, let path = args["path"] as? String else {
        return badArguments(result)
      }
      guard let sound = sounds[path] else {
        return result(FlutterError(code: "not_loaded", message: "Sin cargar: \(path)", details: nil))
      }
      do {
        try start()
      } catch {
        return result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
      }
      commands.add(.play(key, sound))
      result(nil)
    case "release":
      guard let key = args["key"] as? Int else { return badArguments(result) }
      let fadeMs = args["fadeMs"] as? Int ?? 0
      commands.add(.fadeOut(key, max(1, Int(sampleRate * Double(fadeMs) / 1000))))
      lastActivity = Date()
      result(nil)
    case "stop":
      guard let key = args["key"] as? Int else { return badArguments(result) }
      commands.add(.stop(key))
      lastActivity = Date()
      result(nil)
    case "close":
      close()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Pone el motor en marcha, si no lo está ya.
  private func start() throws {
    lastActivity = Date()
    if source == nil {
      try setUp()
    }
    if !engine.isRunning {
      try AVAudioSession.sharedInstance().setActive(true)
      engine.prepare()
      try engine.start()
    }
    if idleTimer == nil {
      idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        self?.pauseIfIdle()
      }
    }
  }

  private func setUp() throws {
    let session = AVAudioSession.sharedInstance()
    // Como hasta ahora: se puede tocar mientras se graba la voz y junto a
    // otra reproducción. Si ya es de grabar y reproducir (p. ej. grabando),
    // no se toca.
    if session.category != .playAndRecord {
      try session.setCategory(
        .playAndRecord, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
    }
    // Que suene enseguida al tocar.
    try? session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)
    let rate = session.sampleRate > 0 ? session.sampleRate : 48000
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else {
      throw NativeError("Formato de audio no admitido")
    }
    let mixer = PianoMixer(sampleRate: Int(rate))
    let commands = self.commands
    let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
      commands.apply(to: mixer)
      let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
      let frames = Int(frameCount)
      guard let first = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
        return noErr
      }
      mixer.render(first, frames: frames)
      for buffer in buffers.dropFirst() {
        guard let other = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
        for i in 0..<frames {
          other[i] = first[i]
        }
      }
      commands.setIdle(mixer.isIdle)
      return noErr
    }
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    source = node
    sampleRate = rate
    // Al cambiar la salida (auriculares, grabar…) el motor se para: se vuelve
    // a poner en marcha si se está tocando.
    observer = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
    ) { [weak self] _ in
      guard let self = self, self.source != nil, !self.engine.isRunning,
        Date().timeIntervalSince(self.lastActivity) < Self.idleSeconds
      else { return }
      try? self.start()
    }
  }

  private func pauseIfIdle() {
    guard Date().timeIntervalSince(lastActivity) > Self.idleSeconds, commands.isIdle else { return }
    if engine.isRunning {
      engine.pause()
    }
    idleTimer?.invalidate()
    idleTimer = nil
  }

  func close() {
    idleTimer?.invalidate()
    idleTimer = nil
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    if let source = source {
      engine.stop()
      engine.detach(source)
    }
    source = nil
    commands.clear()
    sounds.removeAll()
  }
}

/// Lo que se pide al mezclador desde el hilo principal, que aplica el hilo
/// del audio antes de cada trozo sin esperar: si el principal está añadiendo
/// algo, lo aplica en el siguiente.
final class PianoCommands {
  enum Command {
    case play(Int, PianoMixer.Sound)
    case fadeOut(Int, Int)
    case stop(Int)
  }

  private let lock = NSLock()
  private var queued: [Command] = []
  private var applying: [Command] = []
  private var idle = true

  init() {
    queued.reserveCapacity(256)
    applying.reserveCapacity(256)
  }

  /// Si no suena nada ni hay nada por aplicar.
  var isIdle: Bool {
    lock.lock()
    defer { lock.unlock() }
    return idle
  }

  func add(_ command: Command) {
    lock.lock()
    queued.append(command)
    idle = false
    lock.unlock()
  }

  func clear() {
    lock.lock()
    queued.removeAll()
    idle = true
    lock.unlock()
  }

  /// En el hilo del audio.
  func apply(to mixer: PianoMixer) {
    guard lock.try() else { return }
    // Se intercambian (sin copiar: cada lista queda con una sola referencia).
    do {
      let taken = queued
      queued = applying
      applying = taken
    }
    lock.unlock()
    for command in applying {
      switch command {
      case .play(let key, let sound):
        mixer.play(key: key, sound: sound)
      case .fadeOut(let key, let frames):
        mixer.fadeOut(key: key, frames: frames)
      case .stop(let key):
        mixer.fadeOut(key: key, frames: mixer.cutFadeFrames)
      }
    }
    applying.removeAll(keepingCapacity: true)
  }

  /// En el hilo del audio: si el mezclador no suena.
  func setIdle(_ value: Bool) {
    guard lock.try() else { return }
    if queued.isEmpty {
      idle = value
    }
    lock.unlock()
  }
}

/// Las muestras (del primer canal) de un WAV PCM de 16 bits.
private func readSamples(_ path: String) throws -> [Int16] {
  let data = try Data(contentsOf: URL(fileURLWithPath: path))
  return try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [Int16] in
    func uint32(_ offset: Int) -> UInt32 {
      UInt32(raw[offset]) | UInt32(raw[offset + 1]) << 8 | UInt32(raw[offset + 2]) << 16
        | UInt32(raw[offset + 3]) << 24
    }
    func uint16(_ offset: Int) -> Int {
      Int(raw[offset]) | Int(raw[offset + 1]) << 8
    }
    func fourCC(_ offset: Int) -> String {
      String(bytes: raw[offset..<offset + 4], encoding: .ascii) ?? ""
    }
    guard raw.count >= 12, fourCC(0) == "RIFF", fourCC(8) == "WAVE" else {
      throw NativeError("No es un archivo WAV")
    }
    var channels = 0
    var offset = 12
    while offset + 8 <= raw.count {
      let id = fourCC(offset)
      let size = Int(uint32(offset + 4))
      let body = offset + 8
      if id == "fmt " && body + 16 <= raw.count {
        channels = uint16(body + 2)
        guard uint16(body + 14) == 16, channels > 0 else {
          throw NativeError("Formato WAV no admitido")
        }
      } else if id == "data" {
        guard channels > 0 else { throw NativeError("El WAV no tiene bloque fmt") }
        let end = min(raw.count, body + size)
        let frames = max(0, end - body) / (2 * channels)
        return (0..<frames).map { frame in
          let at = body + frame * 2 * channels
          return Int16(bitPattern: UInt16(raw[at]) | UInt16(raw[at + 1]) << 8)
        }
      }
      offset = body + size + (size & 1)
    }
    throw NativeError("El WAV no tiene muestras")
  }
}
