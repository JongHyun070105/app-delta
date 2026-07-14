import Foundation

@testable import AppDelta

enum TestFixtures {
  static func snapshot(
    name: String = "Fixture",
    version: String = "1.0",
    team: String? = "TEAM123",
    entitlements: [String: PlistValue] = [:],
    privacy: [String: String] = [:],
    components: [AppSnapshot.Component] = [],
    files: [AppSnapshot.FileEntry] = []
  ) -> AppSnapshot {
    AppSnapshot(
      sourceName: "\(name).app",
      sourceKind: .application,
      identity: .init(
        name: name,
        bundleIdentifier: "com.example.\(name.lowercased())",
        version: version,
        build: "1",
        minimumSystemVersion: "14.0",
        sdkVersion: "macosx14.0",
        executableName: name,
        bundleBytes: 1_024
      ),
      signing: .init(
        identifier: "com.example.\(name.lowercased())",
        teamIdentifier: team,
        authorities: ["Developer ID Application: Example"],
        cdHash: "abc",
        signedTime: nil,
        format: "app bundle",
        signatureStatus: .accepted,
        signatureMessage: "valid",
        gatekeeperStatus: .accepted,
        gatekeeperMessage: "accepted",
        gatekeeperSource: "Notarized Developer ID",
        hardenedRuntime: true,
        sandboxed: entitlements["com.apple.security.app-sandbox"] == .bool(true)
      ),
      entitlements: entitlements,
      privacyUsageDescriptions: privacy,
      urlSchemes: [],
      components: components,
      files: files,
      warnings: [],
      analyzedAt: Date(timeIntervalSince1970: 0)
    )
  }
}
