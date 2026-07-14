import Foundation

enum DeltaCategory: String, Codable, CaseIterable, Identifiable, Sendable {
  case overview
  case signing
  case capabilities
  case privacy
  case persistence
  case components
  case files

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: L10n.text("Overview")
    case .signing: L10n.text("Trust & Signing")
    case .capabilities: L10n.text("Capabilities")
    case .privacy: L10n.text("Privacy")
    case .persistence: L10n.text("Background & Login")
    case .components: L10n.text("Components")
    case .files: L10n.text("Files")
    }
  }

  var systemImage: String {
    switch self {
    case .overview: "rectangle.2.swap"
    case .signing: "checkmark.seal"
    case .capabilities: "key"
    case .privacy: "hand.raised"
    case .persistence: "clock.arrow.circlepath"
    case .components: "shippingbox"
    case .files: "doc.on.doc"
    }
  }
}

enum DeltaKind: String, Codable, CaseIterable, Sendable {
  case added
  case removed
  case changed
  case unchanged
}

enum DeltaSeverity: String, Codable, CaseIterable, Comparable, Sendable {
  case info
  case attention
  case important

  private var rank: Int {
    switch self {
    case .info: 0
    case .attention: 1
    case .important: 2
    }
  }

  static func < (lhs: DeltaSeverity, rhs: DeltaSeverity) -> Bool {
    lhs.rank < rhs.rank
  }
}

struct DeltaItem: Codable, Equatable, Identifiable, Sendable {
  var id: String
  var category: DeltaCategory
  var kind: DeltaKind
  var severity: DeltaSeverity
  var title: String
  var detail: String
  var evidencePath: String?
  var before: String?
  var after: String?
}

struct DeltaReport: Codable, Equatable, Sendable {
  var before: AppSnapshot
  var after: AppSnapshot
  var items: [DeltaItem]
  var generatedAt: Date

  var changedItems: [DeltaItem] { items.filter { $0.kind != .unchanged } }

  func count(for category: DeltaCategory) -> Int {
    changedItems.filter { $0.category == category }.count
  }
}
