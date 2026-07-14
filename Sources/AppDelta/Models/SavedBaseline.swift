import Foundation

struct SavedBaseline: Codable, Equatable, Identifiable, Sendable {
  static let currentSchemaVersion = 2

  let schemaVersion: Int
  let id: UUID
  let createdAt: Date
  let originalApplicationURL: URL
  let snapshot: AppSnapshot

  init(
    id: UUID = UUID(), createdAt: Date = Date(), originalApplicationURL: URL,
    snapshot: AppSnapshot
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.id = id
    self.createdAt = Date(timeIntervalSince1970: floor(createdAt.timeIntervalSince1970))
    self.originalApplicationURL = originalApplicationURL
    self.snapshot = snapshot
  }

  var displayName: String { snapshot.identity.name }

  var versionLabel: String {
    "\(L10n.text(snapshot.identity.version)) (\(L10n.text(snapshot.identity.build)))"
  }

  var summary: SavedBaselineSummary {
    SavedBaselineSummary(
      schemaVersion: schemaVersion,
      id: id,
      createdAt: createdAt,
      originalApplicationURL: originalApplicationURL,
      displayName: displayName,
      version: snapshot.identity.version,
      build: snapshot.identity.build
    )
  }
}

struct SavedBaselineSummary: Codable, Equatable, Identifiable, Sendable {
  let schemaVersion: Int
  let id: UUID
  let createdAt: Date
  let originalApplicationURL: URL
  let displayName: String
  let version: String
  let build: String

  var versionLabel: String {
    "\(L10n.text(version)) (\(L10n.text(build)))"
  }
}
