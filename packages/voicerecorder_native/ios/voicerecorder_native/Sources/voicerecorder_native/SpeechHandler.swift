import Flutter
import Speech

/// Transcribe archivos de audio con el reconocimiento de voz del sistema: en
/// el dispositivo si el idioma lo admite y, si no, en los servidores de Apple
/// (con un límite de un minuto por archivo, así que Dart los divide).
///
/// Todo se llama desde el hilo principal, y los resultados del reconocedor
/// también llegan en él.
final class SpeechHandler {
  private var task: SFSpeechRecognitionTask?
  private var cancelled = false
  private var progress = 0.0

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "check":
      guard let language = args?["language"] as? String else { return badArguments(result) }
      check(language, result: result)
    case "download":
      // En iOS el sistema gestiona los idiomas.
      result(nil)
    case "transcribe":
      guard let path = args?["path"] as? String,
        let language = args?["language"] as? String
      else { return badArguments(result) }
      let durationMs = (args?["durationMs"] as? NSNumber)?.doubleValue ?? 0
      transcribe(path: path, language: language, durationMs: durationMs, result: result)
    case "progress":
      result(progress)
    case "cancel":
      cancelled = true
      task?.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Indica si se puede transcribir en [language] y con qué variante:
  /// `available` (en el dispositivo), `online` (en los servidores de Apple),
  /// `language` (no lo admite), `denied` (sin permiso) o `unavailable`.
  private func check(_ language: String, result: @escaping FlutterResult) {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .denied, .restricted:
      return result(["status": "denied"])
    default:
      break
    }
    guard let locale = Self.locale(for: language),
      let recognizer = SFSpeechRecognizer(locale: locale)
    else {
      return result(["status": "language"])
    }
    let tag = locale.identifier.replacingOccurrences(of: "_", with: "-")
    if recognizer.supportsOnDeviceRecognition {
      result(["status": "available", "language": tag])
    } else if recognizer.isAvailable {
      result(["status": "online", "language": tag])
    } else {
      result(["status": "unavailable"])
    }
  }

  private func transcribe(
    path: String, language: String, durationMs: Double, result: @escaping FlutterResult
  ) {
    guard task == nil else {
      return result(FlutterError(code: "busy", message: "Ya se está transcribiendo", details: nil))
    }
    authorize { [weak self] authorized in
      guard let self = self else { return }
      guard authorized else {
        return result(FlutterError(code: "denied", message: "Sin permiso", details: nil))
      }
      guard let locale = Self.locale(for: language),
        let recognizer = SFSpeechRecognizer(locale: locale),
        recognizer.isAvailable
      else {
        return result(
          FlutterError(code: "unavailable", message: "Reconocedor no disponible", details: nil))
      }

      let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
      request.shouldReportPartialResults = true
      request.taskHint = .dictation
      if recognizer.supportsOnDeviceRecognition {
        request.requiresOnDeviceRecognition = true
      }
      if #available(iOS 16, *) {
        request.addsPunctuation = true
      }

      self.progress = 0
      self.cancelled = false
      // Frases terminadas y la que se está reconociendo. Según la versión de
      // iOS, cada resultado tiene todo el texto o solo el de la última frase.
      var sentences: [String] = []
      var current = ""
      var finished = false
      func finish(_ value: Any?) {
        if finished { return }
        finished = true
        self.task = nil
        result(value)
      }
      func text() -> String {
        (sentences + [current]).filter { !$0.isEmpty }.joined(separator: " ")
      }

      self.task = recognizer.recognitionTask(with: request) { recognition, error in
        if let recognition = recognition {
          let transcription = recognition.bestTranscription
          let full = transcription.formattedString
          let previous = sentences.joined(separator: " ")
          if !previous.isEmpty && full.hasPrefix(previous) {
            current = String(full.dropFirst(previous.count))
              .trimmingCharacters(in: .whitespaces)
          } else {
            current = full
          }
          if let last = transcription.segments.last, durationMs > 0 {
            self.progress = min(1, (last.timestamp + last.duration) * 1000 / durationMs)
          }
          var endOfSentence = recognition.isFinal
          if #available(iOS 14.5, *) {
            endOfSentence = endOfSentence || recognition.speechRecognitionMetadata != nil
          }
          if endOfSentence {
            if !current.isEmpty { sentences.append(current) }
            current = ""
          }
          if recognition.isFinal { return finish(text()) }
        }
        guard let error = error as NSError? else { return }
        if self.cancelled {
          return finish(FlutterError(code: "canceled", message: "Cancelada", details: nil))
        }
        // 1110: no se ha detectado voz (o no más voz).
        if error.domain == "kAFAssistantErrorDomain" && error.code == 1110 {
          return finish(text())
        }
        finish(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func authorize(_ done: @escaping (Bool) -> Void) {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      done(true)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization { status in
        DispatchQueue.main.async { done(status == .authorized) }
      }
    default:
      done(false)
    }
  }

  /// La variante admitida que mejor encaja con [language]: la misma
  /// etiqueta, el mismo idioma con la región del dispositivo o, si no, la
  /// primera del mismo idioma.
  private static func locale(for language: String) -> Locale? {
    let wanted = Locale(identifier: language)
    let code = languageCode(of: wanted)
    let region = regionCode(of: wanted) ?? regionCode(of: Locale.current)
    let sameLanguage = SFSpeechRecognizer.supportedLocales()
      .filter { languageCode(of: $0) == code }
      .sorted { $0.identifier < $1.identifier }
    let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
    return sameLanguage.first {
      $0.identifier.replacingOccurrences(of: "_", with: "-").lowercased() == normalized
    }
      ?? sameLanguage.first { regionCode(of: $0) == region }
      ?? sameLanguage.first
  }

  private static func languageCode(of locale: Locale) -> String? {
    if #available(iOS 16, *) {
      return locale.language.languageCode?.identifier
    }
    return locale.languageCode
  }

  private static func regionCode(of locale: Locale) -> String? {
    if #available(iOS 16, *) {
      return locale.region?.identifier
    }
    return locale.regionCode
  }
}
