import Foundation

final class ResolvedApplicationLease {
  let applicationURL: URL
  let warnings: [String]
  private let cleanupHandler: () -> Void
  private let lock = NSLock()
  private var cleaned = false

  init(applicationURL: URL, warnings: [String] = [], cleanup: @escaping () -> Void = {}) {
    self.applicationURL = applicationURL
    self.warnings = warnings
    self.cleanupHandler = cleanup
  }

  func cleanup() {
    lock.lock()
    guard !cleaned else {
      lock.unlock()
      return
    }
    cleaned = true
    lock.unlock()
    cleanupHandler()
  }

  deinit { cleanup() }
}

struct ArtifactResolver: @unchecked Sendable {
  private struct Attachment: Sendable {
    let device: String
    let mountPoint: URL?
  }

  let commandRunner: any CommandRunning
  let fileManager: FileManager

  init(
    commandRunner: any CommandRunning = BoundedCommandRunner(), fileManager: FileManager = .default
  ) {
    self.commandRunner = commandRunner
    self.fileManager = fileManager
  }

  func resolveApplication(from artifact: SelectedArtifact, budget: ScanBudget = .default) throws
    -> ResolvedApplicationLease
  {
    switch artifact.kind {
    case .application:
      try validateApplication(at: artifact.url)
      return ResolvedApplicationLease(applicationURL: artifact.url)
    case .diskImage:
      return try resolveDiskImage(at: artifact.url, budget: budget)
    case .installerPackage:
      throw AnalysisError.unsupportedArtifact(
        "Installer packages are analyzed as package metadata rather than mounted applications.")
    }
  }

  private func resolveDiskImage(at imageURL: URL, budget: ScanBudget) throws
    -> ResolvedApplicationLease
  {
    let source = imageURL.standardizedFileURL
    guard source.path.hasPrefix("/"), fileManager.isReadableFile(atPath: source.path) else {
      throw AnalysisError.unreadableArtifact(source.lastPathComponent)
    }

    let verify = try commandRunner.run(
      .hdiutil, arguments: ["verify", "-plist", source.path], budget: budget)
    guard verify.status == 0 else {
      throw AnalysisError.commandFailed(
        tool: "hdiutil verify", message: concise(verify.combinedString))
    }

    let sessionRoot = fileManager.temporaryDirectory
      .appendingPathComponent("AppDelta-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
      at: sessionRoot,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    var attachments: [Attachment] = []
    do {
      let result = try commandRunner.run(
        .hdiutil,
        arguments: [
          "attach", source.path,
          "-readonly", "-verify", "-nobrowse", "-noautoopen", "-owners", "off",
          "-mountrandom", sessionRoot.path, "-plist",
        ],
        budget: budget
      )
      guard result.status == 0 else {
        throw AnalysisError.commandFailed(
          tool: "hdiutil attach", message: concise(result.combinedString))
      }

      attachments = try parseAttachments(result.standardOutput)
      for mountPoint in attachments.compactMap(\.mountPoint) {
        guard
          mountPoint.standardizedFileURL.path.hasPrefix(
            sessionRoot.standardizedFileURL.path + "/")
        else {
          throw AnalysisError.unsafePath(mountPoint.path)
        }
      }

      let applications = try attachments.compactMap(\.mountPoint).flatMap {
        try findApplications(in: $0, budget: budget)
      }.sorted {
        let leftDepth = $0.pathComponents.count
        let rightDepth = $1.pathComponents.count
        return leftDepth == rightDepth
          ? $0.lastPathComponent < $1.lastPathComponent : leftDepth < rightDepth
      }
      guard let application = applications.first else {
        throw AnalysisError.noApplicationFound(source.lastPathComponent)
      }
      try validateApplication(at: application)

      var warnings: [String] = []
      if applications.count > 1 {
        warnings.append(
          "The disk image contains multiple applications. App Delta selected \(application.lastPathComponent)."
        )
      }

      let runner = commandRunner
      let manager = fileManager
      let mountedAttachments = attachments
      return ResolvedApplicationLease(applicationURL: application, warnings: warnings) {
        Self.detach(mountedAttachments, using: runner, budget: budget)
        try? manager.removeItem(at: sessionRoot)
      }
    } catch {
      if attachments.isEmpty {
        attachments = mountedAttachments(under: sessionRoot, source: source, budget: budget)
      }
      Self.detach(attachments, using: commandRunner, budget: budget)
      try? fileManager.removeItem(at: sessionRoot)
      throw error
    }
  }

  private func validateApplication(at url: URL) throws {
    var isDirectory: ObjCBool = false
    guard url.pathExtension.lowercased() == "app",
      fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue,
      fileManager.isReadableFile(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    else {
      throw AnalysisError.unreadableArtifact(url.lastPathComponent)
    }
  }

  private func findApplications(in root: URL, budget: ScanBudget) throws -> [URL] {
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      )
    else {
      throw AnalysisError.unreadableArtifact(root.lastPathComponent)
    }

    var results: [URL] = []
    var visited = 0
    while let candidate = enumerator.nextObject() as? URL {
      try Task.checkCancellation()
      visited += 1
      if visited > min(budget.maximumEntries, 20_000) {
        throw AnalysisError.scanLimitReached("disk image candidate count")
      }
      let values = try? candidate.resourceValues(forKeys: Set(keys))
      if values?.isSymbolicLink == true {
        enumerator.skipDescendants()
        continue
      }
      if values?.isDirectory == true, candidate.pathExtension.lowercased() == "app" {
        results.append(candidate)
        enumerator.skipDescendants()
      }
    }
    return results.sorted {
      let leftDepth = $0.pathComponents.count
      let rightDepth = $1.pathComponents.count
      return leftDepth == rightDepth
        ? $0.lastPathComponent < $1.lastPathComponent : leftDepth < rightDepth
    }
  }

  private func parseAttachments(_ data: Data) throws -> [Attachment] {
    guard
      let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any],
      let entities = plist["system-entities"] as? [[String: Any]]
    else {
      throw AnalysisError.malformedPropertyList("hdiutil attachment result")
    }

    let attachments = try entities.compactMap { entity -> Attachment? in
      guard let device = entity["dev-entry"] as? String else { return nil }
      guard device.hasPrefix("/dev/disk") else {
        throw AnalysisError.unsafePath("invalid disk image attachment")
      }
      let mountPoint = entity["mount-point"] as? String
      if let mountPoint, !mountPoint.hasPrefix("/") {
        throw AnalysisError.unsafePath("invalid disk image attachment")
      }
      return Attachment(
        device: device,
        mountPoint: mountPoint.map { URL(fileURLWithPath: $0, isDirectory: true) })
    }
    guard !attachments.isEmpty else {
      throw AnalysisError.malformedPropertyList("hdiutil attachment result")
    }
    return attachments
  }

  private func mountedAttachments(under root: URL, source: URL, budget: ScanBudget) -> [Attachment]
  {
    guard
      let result = try? commandRunner.run(.hdiutil, arguments: ["info", "-plist"], budget: budget),
      result.status == 0,
      let plist = try? PropertyListSerialization.propertyList(
        from: result.standardOutput, format: nil) as? [String: Any],
      let images = plist["images"] as? [[String: Any]]
    else { return [] }

    let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
    let sourcePath = source.resolvingSymlinksInPath().standardizedFileURL.path
    return images.filter { image in
      let imagePath = (image["image-path"] as? String).map {
        URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL.path
      }
      let entities = image["system-entities"] as? [[String: Any]] ?? []
      let hasOwnedMount = entities.contains { entity in
        guard let mountPoint = entity["mount-point"] as? String else { return false }
        return URL(fileURLWithPath: mountPoint).resolvingSymlinksInPath()
          .standardizedFileURL.path.hasPrefix(rootPath)
      }
      return imagePath == sourcePath || hasOwnedMount
    }.flatMap { image -> [Attachment] in
      guard let entities = image["system-entities"] as? [[String: Any]] else { return [] }
      return entities.compactMap { entity in
        guard let device = entity["dev-entry"] as? String, device.hasPrefix("/dev/disk")
        else { return nil }
        let mountPoint = (entity["mount-point"] as? String).map {
          URL(fileURLWithPath: $0, isDirectory: true)
        }
        return Attachment(
          device: device, mountPoint: mountPoint)
      }
    }
  }

  private static func detach(
    _ attachments: [Attachment], using runner: any CommandRunning, budget: ScanBudget
  ) {
    var seen = Set<String>()
    for device in attachments.map(\.device) where seen.insert(device).inserted {
      let detached = try? runner.run(.hdiutil, arguments: ["detach", device], budget: budget)
      if detached?.status == 0 { return }
      let forced = try? runner.run(
        .hdiutil, arguments: ["detach", device, "-force"], budget: budget)
      if forced?.status == 0 { return }
    }
  }

  private func concise(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600).description
  }
}
