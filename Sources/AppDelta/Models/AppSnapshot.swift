import Foundation

enum VerificationState: String, Codable, Equatable, Sendable, CustomStringConvertible {
  case accepted
  case rejected
  case unavailable

  var description: String { L10n.text(rawValue.capitalized) }
}

struct AppSnapshot: Codable, Equatable, Sendable {
  struct Identity: Codable, Equatable, Sendable {
    var name: String
    var bundleIdentifier: String
    var version: String
    var build: String
    var minimumSystemVersion: String?
    var sdkVersion: String?
    var executableName: String?
    var bundleBytes: Int64
  }

  struct Signing: Codable, Equatable, Sendable {
    var identifier: String?
    var teamIdentifier: String?
    var authorities: [String]
    var cdHash: String?
    var signedTime: String?
    var format: String?
    var signatureStatus: VerificationState
    var signatureMessage: String
    var gatekeeperStatus: VerificationState
    var gatekeeperMessage: String
    var gatekeeperSource: String?
    var hardenedRuntime: Bool
    var sandboxed: Bool
  }

  struct Component: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
      case executable
      case framework
      case xpcService
      case appExtension
      case plugin
      case loginItem
      case launchAgent
      case launchDaemon
      case nestedApplication
      case library
    }

    var path: String
    var kind: Kind
    var bytes: Int64?
  }

  struct FileEntry: Codable, Equatable, Hashable, Sendable {
    enum EntryType: String, Codable, Sendable {
      case regular
      case directory
      case symbolicLink
      case other
    }

    var path: String
    var type: EntryType
    var bytes: Int64?
    var executable: Bool
    var contentSHA256: String? = nil
  }

  var sourceName: String
  var sourceKind: ArtifactKind
  var identity: Identity
  var signing: Signing
  var entitlements: [String: PlistValue]
  var privacyUsageDescriptions: [String: String]
  var privacyManifests: [String: PlistValue] = [:]
  var urlSchemes: [String]
  var components: [Component]
  var files: [FileEntry]
  var warnings: [String]
  var analyzedAt: Date
}

enum PlistValue: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
  case string(String)
  case bool(Bool)
  case integer(Int64)
  case real(Double)
  case array([PlistValue])
  case dictionary([String: PlistValue])
  case data(String)
  case date(String)
  case null

  var description: String {
    switch self {
    case .string(let value): value
    case .bool(let value): value ? "true" : "false"
    case .integer(let value): String(value)
    case .real(let value): String(value)
    case .array(let values): values.map(\.description).joined(separator: ", ")
    case .dictionary(let values):
      values.keys.sorted().map { "\($0): \(values[$0]?.description ?? "")" }.joined(separator: ", ")
    case .data(let value): value
    case .date(let value): value
    case .null: "null"
    }
  }
}

extension PlistValue {
  static func convert(_ value: Any, depth: Int = 0) -> PlistValue {
    guard depth < 64 else { return .string("<depth limit reached>") }

    switch value {
    case let value as String:
      return .string(value)
    case let value as Bool:
      return .bool(value)
    case let value as Int:
      return .integer(Int64(value))
    case let value as Int64:
      return .integer(value)
    case let value as NSNumber:
      if CFGetTypeID(value) == CFBooleanGetTypeID() {
        return .bool(value.boolValue)
      }
      return .real(value.doubleValue)
    case let value as Double:
      return .real(value)
    case let value as Date:
      return .date(ISO8601DateFormatter().string(from: value))
    case let value as Data:
      return .data(value.base64EncodedString())
    case let value as [Any]:
      return .array(value.map { convert($0, depth: depth + 1) })
    case let value as [String: Any]:
      return .dictionary(value.mapValues { convert($0, depth: depth + 1) })
    default:
      return .null
    }
  }
}
