import SwiftUI

extension DeltaKind {
  var label: String {
    switch self {
    case .added: L10n.text("Added")
    case .removed: L10n.text("Removed")
    case .changed: L10n.text("Changed")
    case .unchanged: L10n.text("Unchanged")
    }
  }

  var systemImage: String {
    switch self {
    case .added: "plus.circle.fill"
    case .removed: "minus.circle.fill"
    case .changed: "arrow.left.arrow.right.circle.fill"
    case .unchanged: "equal.circle"
    }
  }

  var color: Color {
    switch self {
    case .added: .blue
    case .removed: .secondary
    case .changed: .orange
    case .unchanged: .secondary
    }
  }
}

extension DeltaSeverity {
  var label: String {
    switch self {
    case .info: L10n.text("All changes")
    case .attention: L10n.text("Attention and important")
    case .important: L10n.text("Important only")
    }
  }
}
