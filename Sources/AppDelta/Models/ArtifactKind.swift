import Foundation

enum ArtifactKind: String, Codable, CaseIterable, Sendable {
  case application = "app"
  case diskImage = "dmg"
  case installerPackage = "pkg"

  init?(url: URL) {
    switch url.pathExtension.lowercased() {
    case "app": self = .application
    case "dmg": self = .diskImage
    case "pkg", "mpkg": self = .installerPackage
    default: return nil
    }
  }

  var label: String {
    switch self {
    case .application: L10n.text("Application")
    case .diskImage: L10n.text("Disk Image")
    case .installerPackage: L10n.text("Installer Package")
    }
  }
}

struct SelectedArtifact: Identifiable, Equatable, Sendable {
  let id = UUID()
  let url: URL
  let kind: ArtifactKind

  init?(url: URL) {
    guard let kind = ArtifactKind(url: url) else { return nil }
    self.url = url
    self.kind = kind
  }

  var displayName: String { url.lastPathComponent }
}
