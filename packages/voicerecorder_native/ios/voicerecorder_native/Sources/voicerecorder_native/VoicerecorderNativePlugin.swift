import Flutter
import UIKit

/// Registra los canales de conversión de audio, de acceso a carpetas, de la
/// pantalla y del reconocimiento de voz.
public class VoicerecorderNativePlugin: NSObject, FlutterPlugin {
  private let codec = AudioCodecHandler()
  private let folders = FolderAccessHandler()
  private let speech = SpeechHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VoicerecorderNativePlugin()

    let codecChannel = FlutterMethodChannel(
      name: "es.germade.voicerecorder/audio_codec",
      binaryMessenger: registrar.messenger())
    codecChannel.setMethodCallHandler { call, result in
      instance.codec.handle(call, result: result)
    }

    let foldersChannel = FlutterMethodChannel(
      name: "es.germade.voicerecorder/folders",
      binaryMessenger: registrar.messenger())
    foldersChannel.setMethodCallHandler { call, result in
      instance.folders.handle(call, result: result)
    }

    // Mantiene la pantalla encendida mientras la app lo pide (p. ej. mientras
    // se graba). Las llamadas llegan en el hilo principal.
    let screenChannel = FlutterMethodChannel(
      name: "es.germade.voicerecorder/screen",
      binaryMessenger: registrar.messenger())
    screenChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "keepOn":
        let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
        UIApplication.shared.isIdleTimerDisabled = on
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let speechChannel = FlutterMethodChannel(
      name: "es.germade.voicerecorder/speech",
      binaryMessenger: registrar.messenger())
    speechChannel.setMethodCallHandler { call, result in
      instance.speech.handle(call, result: result)
    }
  }
}

/// Error con un mensaje para Dart y, si la app lo traduce, un código
/// («no_permission»…).
struct NativeError: LocalizedError {
  let message: String
  let code: String

  init(_ message: String, code: String = "failed") {
    self.message = message
    self.code = code
  }

  var errorDescription: String? { message }
}

/// Ejecuta tareas en una cola propia y devuelve el resultado en el hilo
/// principal.
final class BackgroundRunner {
  private let queue: DispatchQueue

  init(label: String) {
    queue = DispatchQueue(label: label, qos: .userInitiated)
  }

  func run(_ result: @escaping FlutterResult, _ task: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try task()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: (error as? NativeError)?.code ?? "failed",
              message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

func badArguments(_ result: FlutterResult) {
  result(FlutterError(code: "bad_args", message: "Faltan argumentos", details: nil))
}
