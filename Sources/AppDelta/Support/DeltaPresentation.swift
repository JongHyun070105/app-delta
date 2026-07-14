import SwiftUI

extension DeltaKind {
  var label: String {
    switch self {
    case .added: "Added"
    case .removed: "Removed"
    case .changed: "Changed"
    case .unchanged: "Unchanged"
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
    case .info: "All changes"
    case .attention: "Attention and important"
    case .important: "Important only"
    }
  }
}
