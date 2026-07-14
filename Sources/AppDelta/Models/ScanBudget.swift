import Foundation

struct ScanBudget: Sendable {
  var maximumEntries = 200_000
  var maximumDepth = 64
  var maximumPlistBytes = 8 * 1_024 * 1_024
  var maximumToolOutputBytes = 4 * 1_024 * 1_024
  var maximumHashedBytes: Int64 = 512 * 1_024 * 1_024
  var commandTimeout: TimeInterval = 20

  static let `default` = ScanBudget()
}

enum AnalysisError: LocalizedError, Equatable {
  case unsupportedArtifact(String)
  case unreadableArtifact(String)
  case malformedPropertyList(String)
  case noApplicationFound(String)
  case multipleApplications([String])
  case commandFailed(tool: String, message: String)
  case commandTimedOut(String)
  case outputLimitExceeded(String)
  case scanLimitReached(String)
  case unsafePath(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedArtifact(let value): L10n.format("Unsupported artifact: %@", value)
    case .unreadableArtifact(let value): L10n.format("The artifact could not be read: %@", value)
    case .malformedPropertyList(let value): L10n.format("Invalid property list: %@", value)
    case .noApplicationFound(let value):
      L10n.format("No macOS application was found in %@.", value)
    case .multipleApplications(let names):
      L10n.format("More than one application was found: %@.", names.joined(separator: ", "))
    case .commandFailed(let tool, let message): L10n.format("%@ failed: %@", tool, message)
    case .commandTimedOut(let tool):
      L10n.format("%@ did not finish within the time limit.", tool)
    case .outputLimitExceeded(let tool):
      L10n.format("%@ produced more output than App Delta allows.", tool)
    case .scanLimitReached(let message):
      L10n.format("The scan stopped at its safety limit: %@", message)
    case .unsafePath(let path): L10n.format("Unsafe path was rejected: %@", path)
    }
  }
}
