import Flutter
import UIKit
import UniformTypeIdentifiers

/// Copia archivos a una carpeta elegida por el usuario (En mi iPhone, iCloud
/// Drive…). El acceso se conserva entre reinicios con un marcador de seguridad.
final class FolderAccessHandler: NSObject, UIDocumentPickerDelegate {
  private let runner = BackgroundRunner(label: "es.germade.voicerecorder.folders")
  private var pendingPick: FlutterResult?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickFolder":
      pickFolder(result)
    case "writeFile":
      guard let folder = args["folder"] as? String,
        let source = args["source"] as? String,
        let name = args["name"] as? String
      else { return badArguments(result) }
      let ref = args["ref"] as? String
      runner.run(result) {
        try FolderAccessHandler.writeFile(folder: folder, ref: ref, source: source, name: name)
      }
    case "renameFile":
      guard let folder = args["folder"] as? String,
        let ref = args["ref"] as? String,
        let name = args["name"] as? String
      else { return badArguments(result) }
      runner.run(result) {
        try FolderAccessHandler.renameFile(folder: folder, ref: ref, name: name)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Selector de carpetas

  private func pickFolder(_ result: @escaping FlutterResult) {
    guard pendingPick == nil else {
      result(FlutterError(code: "busy", message: "Ya se está eligiendo una carpeta", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_view", message: "No hay ninguna pantalla abierta", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pendingPick = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let bookmark = try url.bookmarkData(
        options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      result([
        "id": bookmark.base64EncodedString(),
        "name": FileManager.default.displayName(atPath: url.path),
      ])
    } catch {
      result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  // MARK: - Archivos

  /// Resuelve el marcador de la carpeta y da acceso a ella durante [body].
  private static func withFolder<T>(_ id: String, _ body: (URL) throws -> T) throws -> T {
    guard let data = Data(base64Encoded: id) else {
      throw NativeError("La carpeta elegida no es válida")
    }
    var stale = false
    let folder = try URL(
      resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    guard folder.startAccessingSecurityScopedResource() else {
      throw NativeError("Ya no hay permiso para escribir en la carpeta. Elígela de nuevo.")
    }
    defer { folder.stopAccessingSecurityScopedResource() }
    return try body(folder)
  }

  private static func writeFile(folder: String, ref: String?, source: String, name: String)
    throws -> String
  {
    try withFolder(folder) { directory in
      let fileManager = FileManager.default
      var target = uniqueURL(in: directory, name: name)
      if let ref {
        let existing = directory.appendingPathComponent(ref)
        if fileManager.fileExists(atPath: existing.path) { target = existing }
      }
      let sourceURL = URL(fileURLWithPath: source)
      try coordinate(writingAt: target, options: .forReplacing) { url in
        if fileManager.fileExists(atPath: url.path) {
          try fileManager.removeItem(at: url)
        }
        try fileManager.copyItem(at: sourceURL, to: url)
      }
      return target.lastPathComponent
    }
  }

  private static func renameFile(folder: String, ref: String, name: String) throws -> String {
    try withFolder(folder) { directory in
      let current = directory.appendingPathComponent(ref)
      if ref == name { return ref }
      let target = uniqueURL(in: directory, name: name)
      try coordinate(writingAt: current, options: .forMoving) { url in
        try FileManager.default.moveItem(at: url, to: target)
      }
      return target.lastPathComponent
    }
  }

  /// [name] dentro de [directory] o, si ya existe, "nombre (2).ext", etc.
  private static func uniqueURL(in directory: URL, name: String) -> URL {
    let fileManager = FileManager.default
    var candidate = directory.appendingPathComponent(name)
    let base = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension
    var counter = 2
    while fileManager.fileExists(atPath: candidate.path) {
      let numbered = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
      candidate = directory.appendingPathComponent(numbered)
      counter += 1
    }
    return candidate
  }

  /// Coordina la escritura para que iCloud Drive y otros proveedores vean el
  /// cambio.
  private static func coordinate(
    writingAt url: URL,
    options: NSFileCoordinator.WritingOptions,
    _ body: (URL) throws -> Void
  ) throws {
    var coordinationError: NSError?
    var bodyError: Error?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: url, options: options, error: &coordinationError
    ) { newURL in
      do {
        try body(newURL)
      } catch {
        bodyError = error
      }
    }
    if let coordinationError { throw coordinationError }
    if let bodyError { throw bodyError }
  }
}
