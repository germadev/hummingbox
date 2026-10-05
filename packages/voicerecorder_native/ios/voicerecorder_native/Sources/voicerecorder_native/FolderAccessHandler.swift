import Flutter
import UIKit
import UniformTypeIdentifiers

/// Lee y copia archivos en una carpeta elegida por el usuario (En mi iPhone,
/// iCloud Drive…) y en sus subcarpetas. El acceso se conserva entre reinicios
/// con un marcador de seguridad. Las referencias de los archivos son rutas
/// relativas a la carpeta («Clases/Tema 1.m4a»).
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
      let subfolder = args["subfolder"] as? String ?? ""
      let ref = args["ref"] as? String
      runner.run(result) {
        try FolderAccessHandler.writeFile(
          folder: folder, subfolder: subfolder, ref: ref, source: source, name: name)
      }
    case "listFiles":
      guard let folder = args["folder"] as? String else { return badArguments(result) }
      let subfolder = args["subfolder"] as? String ?? ""
      runner.run(result) {
        try FolderAccessHandler.listFiles(folder: folder, subfolder: subfolder)
      }
    case "readFile":
      guard let folder = args["folder"] as? String,
        let ref = args["ref"] as? String,
        let destination = args["destination"] as? String
      else { return badArguments(result) }
      runner.run(result) {
        try FolderAccessHandler.readFile(folder: folder, ref: ref, destination: destination)
        return nil
      }
    case "createFolder":
      guard let folder = args["folder"] as? String,
        let name = args["name"] as? String
      else { return badArguments(result) }
      runner.run(result) {
        try FolderAccessHandler.createFolder(folder: folder, name: name)
        return nil
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
      throw NativeError(
        "Ya no hay permiso para escribir en la carpeta. Elígela de nuevo.",
        code: "no_permission")
    }
    defer { folder.stopAccessingSecurityScopedResource() }
    return try body(folder)
  }

  private static func writeFile(
    folder: String, subfolder: String, ref: String?, source: String, name: String
  ) throws -> String {
    try withFolder(folder) { directory in
      let fileManager = FileManager.default
      var target: URL
      if let ref, fileManager.fileExists(atPath: directory.appendingPathComponent(ref).path) {
        target = directory.appendingPathComponent(ref)
      } else {
        let parent = subfolder.isEmpty ? directory : directory.appendingPathComponent(subfolder)
        if !subfolder.isEmpty {
          try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        target = uniqueURL(in: parent, name: name)
      }
      let sourceURL = URL(fileURLWithPath: source)
      try coordinate(writingAt: target, options: .forReplacing) { url in
        if fileManager.fileExists(atPath: url.path) {
          try fileManager.removeItem(at: url)
        }
        try fileManager.copyItem(at: sourceURL, to: url)
      }
      return relativePath(of: target, in: directory)
    }
  }

  private static func renameFile(folder: String, ref: String, name: String) throws -> String {
    try withFolder(folder) { directory in
      let current = directory.appendingPathComponent(ref)
      if current.lastPathComponent == name { return ref }
      let target = uniqueURL(in: current.deletingLastPathComponent(), name: name)
      try coordinate(writingAt: current, options: .forMoving) { url in
        try FileManager.default.moveItem(at: url, to: target)
      }
      return relativePath(of: target, in: directory)
    }
  }

  /// Archivos y subcarpetas de la carpeta o de su subcarpeta [subfolder]. Los
  /// archivos de iCloud Drive que no están descargados aparecen con su nombre
  /// real (sin el «.icloud» del marcador).
  private static func listFiles(folder: String, subfolder: String) throws -> [[String: Any]] {
    try withFolder(folder) { directory in
      let parent = subfolder.isEmpty ? directory : directory.appendingPathComponent(subfolder)
      let fileManager = FileManager.default
      var isFolder: ObjCBool = false
      guard fileManager.fileExists(atPath: parent.path, isDirectory: &isFolder),
        isFolder.boolValue
      else { return [] }

      let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
      var urls: [URL] = []
      var listError: Error?
      var coordinationError: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(
        readingItemAt: parent, options: [], error: &coordinationError
      ) { url in
        do {
          urls = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [])
        } catch {
          listError = error
        }
      }
      if let coordinationError { throw coordinationError }
      if let listError { throw listError }

      return urls.compactMap { url -> [String: Any]? in
        var name = url.lastPathComponent
        var placeholder = false
        if name.hasPrefix(".") {
          // Marcador de un archivo de iCloud sin descargar: «.Nombre.m4a.icloud».
          guard name.hasSuffix(".icloud"), name.count > 8 else { return nil }
          name = String(name.dropFirst().dropLast(7))
          placeholder = true
        }
        let values = try? url.resourceValues(forKeys: Set(keys))
        let isDirectory = !placeholder && values?.isDirectory == true
        var entry: [String: Any] = [
          "ref": subfolder.isEmpty ? name : "\(subfolder)/\(name)",
          "name": name,
          "isDirectory": isDirectory,
        ]
        if !placeholder, !isDirectory, let size = values?.fileSize { entry["size"] = size }
        if let date = values?.contentModificationDate {
          entry["modified"] = Int64(date.timeIntervalSince1970 * 1000)
        }
        return entry
      }
    }
  }

  /// Copia el archivo [ref] a [destination]. La lectura coordinada descarga
  /// los archivos de iCloud Drive que todavía no están en el dispositivo.
  private static func readFile(folder: String, ref: String, destination: String) throws {
    try withFolder(folder) { directory in
      let source = directory.appendingPathComponent(ref)
      let target = URL(fileURLWithPath: destination)
      let fileManager = FileManager.default
      var copyError: Error?
      var coordinationError: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(
        readingItemAt: source, options: [], error: &coordinationError
      ) { url in
        do {
          if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
          }
          try fileManager.copyItem(at: url, to: target)
        } catch {
          copyError = error
        }
      }
      if let coordinationError { throw coordinationError }
      if let copyError { throw copyError }
    }
  }

  private static func createFolder(folder: String, name: String) throws {
    try withFolder(folder) { directory in
      try FileManager.default.createDirectory(
        at: directory.appendingPathComponent(name), withIntermediateDirectories: true)
    }
  }

  /// Ruta de [url] relativa a [directory]: «Tema 1.m4a» o «Clases/Tema 1.m4a».
  private static func relativePath(of url: URL, in directory: URL) -> String {
    let base = directory.standardizedFileURL.pathComponents
    let components = url.standardizedFileURL.pathComponents
    guard components.count > base.count, Array(components.prefix(base.count)) == base else {
      return url.lastPathComponent
    }
    return components.dropFirst(base.count).joined(separator: "/")
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
