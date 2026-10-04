import Flutter
import UIKit

/// Registra los canales de conversión de audio y de acceso a carpetas.
public class VoicerecorderNativePlugin: NSObject, FlutterPlugin {
  private let codec = AudioCodecHandler()
  private let folders = FolderAccessHandler()

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
  }
}

/// Error con un mensaje para mostrar en Dart.
struct NativeError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
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
            FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

func badArguments(_ result: FlutterResult) {
  result(FlutterError(code: "bad_args", message: "Faltan argumentos", details: nil))
}
