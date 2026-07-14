import Foundation

struct BaselineVault: Sendable {
  private static let maximumMetadataBytes = 1 * 1_024 * 1_024
  private static let maximumSnapshotBytes = 128 * 1_024 * 1_024

  let directoryURL: URL

  init(directoryURL: URL? = nil) {
    if let directoryURL {
      self.directoryURL = directoryURL
    } else {
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first!
      self.directoryURL =
        applicationSupport
        .appendingPathComponent("App Delta", isDirectory: true)
        .appendingPathComponent("Baselines", isDirectory: true)
    }
  }

  func list() throws -> [SavedBaselineSummary] {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
    let files = try fileManager.contentsOfDirectory(
      at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return files.compactMap { url in
      guard url.lastPathComponent.hasSuffix(".metadata.json"),
        let values = try? url.resourceValues(forKeys: [
          .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ]),
        values.isRegularFile == true,
        values.isSymbolicLink != true,
        let fileSize = values.fileSize,
        fileSize <= Self.maximumMetadataBytes,
        let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
        let summary = try? decoder.decode(SavedBaselineSummary.self, from: data),
        summary.schemaVersion == SavedBaseline.currentSchemaVersion,
        metadataURL(for: summary.id).standardizedFileURL == url.standardizedFileURL
      else { return nil }
      return summary
    }.sorted { $0.createdAt > $1.createdAt }
  }

  func load(_ summary: SavedBaselineSummary) throws -> SavedBaseline {
    guard summary.schemaVersion == SavedBaseline.currentSchemaVersion else {
      throw AnalysisError.unreadableArtifact(summary.displayName)
    }
    let source = snapshotURL(for: summary.id)
    try validateManagedFile(source)
    let values = try source.resourceValues(forKeys: [.fileSizeKey])
    guard let fileSize = values.fileSize, fileSize <= Self.maximumSnapshotBytes else {
      throw AnalysisError.scanLimitReached("saved baseline size")
    }
    let data = try Data(contentsOf: source, options: [.mappedIfSafe])
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let record = try decoder.decode(SavedBaseline.self, from: data)
    guard record.schemaVersion == SavedBaseline.currentSchemaVersion, record.summary == summary
    else {
      throw AnalysisError.unreadableArtifact(summary.displayName)
    }
    return record
  }

  @discardableResult
  func save(snapshot: AppSnapshot, originalApplicationURL: URL) throws -> SavedBaseline {
    let record = SavedBaseline(
      originalApplicationURL: originalApplicationURL.standardizedFileURL,
      snapshot: snapshot)
    try FileManager.default.createDirectory(
      at: directoryURL, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let snapshotData = try encoder.encode(record)
    guard snapshotData.count <= Self.maximumSnapshotBytes else {
      throw AnalysisError.scanLimitReached("saved baseline size")
    }
    let summaryData = try encoder.encode(record.summary)
    let snapshotDestination = snapshotURL(for: record.id)
    let metadataDestination = metadataURL(for: record.id)
    try snapshotData.write(to: snapshotDestination, options: [.atomic])
    do {
      try summaryData.write(to: metadataDestination, options: [.atomic])
    } catch {
      try? FileManager.default.removeItem(at: snapshotDestination)
      throw error
    }
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: snapshotDestination.path)
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: metadataDestination.path)
    return record
  }

  func delete(_ summary: SavedBaselineSummary) throws {
    for destination in [snapshotURL(for: summary.id), metadataURL(for: summary.id)] {
      let standardizedDestination = destination.standardizedFileURL
      let parent = standardizedDestination.deletingLastPathComponent().standardizedFileURL
      guard parent == directoryURL.standardizedFileURL else {
        throw AnalysisError.unsafePath(standardizedDestination.path)
      }
      if FileManager.default.fileExists(atPath: standardizedDestination.path) {
        try FileManager.default.removeItem(at: standardizedDestination)
      }
    }
  }

  func delete(_ record: SavedBaseline) throws {
    try delete(record.summary)
  }

  private func validateManagedFile(_ url: URL) throws {
    let standardizedURL = url.standardizedFileURL
    guard standardizedURL.deletingLastPathComponent() == directoryURL.standardizedFileURL else {
      throw AnalysisError.unsafePath(standardizedURL.path)
    }
    let values = try standardizedURL.resourceValues(forKeys: [
      .isRegularFileKey, .isSymbolicLinkKey,
    ])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw AnalysisError.unreadableArtifact(standardizedURL.lastPathComponent)
    }
  }

  private func snapshotURL(for id: UUID) -> URL {
    directoryURL.appendingPathComponent("\(id.uuidString).snapshot.json", isDirectory: false)
  }

  private func metadataURL(for id: UUID) -> URL {
    directoryURL.appendingPathComponent("\(id.uuidString).metadata.json", isDirectory: false)
  }
}
