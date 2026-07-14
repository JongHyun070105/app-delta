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
    case .unsupportedArtifact(let value): "Unsupported artifact: \(value)"
    case .unreadableArtifact(let value): "The artifact could not be read: \(value)"
    case .malformedPropertyList(let value): "Invalid property list: \(value)"
    case .noApplicationFound(let value): "No macOS application was found in \(value)."
    case .multipleApplications(let names):
      "More than one application was found: \(names.joined(separator: ", "))."
    case .commandFailed(let tool, let message): "\(tool) failed: \(message)"
    case .commandTimedOut(let tool): "\(tool) did not finish within the time limit."
    case .outputLimitExceeded(let tool): "\(tool) produced more output than App Delta allows."
    case .scanLimitReached(let message): "The scan stopped at its safety limit: \(message)"
    case .unsafePath(let path): "Unsafe path was rejected: \(path)"
    }
  }
}
