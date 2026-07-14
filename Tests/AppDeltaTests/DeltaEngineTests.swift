import XCTest

@testable import AppDelta

final class DeltaEngineTests: XCTestCase {
  func testAddedCapabilityAndPrivacyDescriptionAreReported() {
    let before = TestFixtures.snapshot()
    let after = TestFixtures.snapshot(
      version: "2.0",
      entitlements: ["com.apple.security.device.audio-input": .bool(true)],
      privacy: ["NSMicrophoneUsageDescription": "Record voice notes"]
    )

    let report = DeltaEngine().compare(before: before, after: after)

    XCTAssertTrue(
      report.items.contains {
        $0.id == "entitlement:com.apple.security.device.audio-input" && $0.kind == .added
      })
    XCTAssertTrue(
      report.items.contains { $0.id == "privacy:NSMicrophoneUsageDescription" && $0.kind == .added }
    )
    XCTAssertTrue(
      report.items.contains { $0.title == L10n.text("Version") && $0.kind == .changed })
  }

  func testRemovingSandboxIsImportant() {
    let before = TestFixtures.snapshot(entitlements: ["com.apple.security.app-sandbox": .bool(true)]
    )
    let after = TestFixtures.snapshot()

    let item = DeltaEngine().compare(before: before, after: after).items
      .first { $0.id == "entitlement:com.apple.security.app-sandbox" }

    XCTAssertEqual(item?.kind, .removed)
    XCTAssertEqual(item?.severity, .important)
  }

  func testSwapReversesAddedAndRemoved() {
    let before = TestFixtures.snapshot(entitlements: [:])
    let after = TestFixtures.snapshot(entitlements: [
      "com.apple.security.network.server": .bool(true)
    ])
    let engine = DeltaEngine()

    let forward = engine.compare(before: before, after: after)
    let reverse = engine.compare(before: after, after: before)

    XCTAssertEqual(forward.items.first { $0.id.contains("network.server") }?.kind, .added)
    XCTAssertEqual(reverse.items.first { $0.id.contains("network.server") }?.kind, .removed)
  }

  func testCanonicalPlaceholderDoesNotBecomeAChangeWhenLanguageChanges() {
    let previousLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
    defer {
      if let previousLanguage {
        UserDefaults.standard.set(previousLanguage, forKey: AppLanguage.storageKey)
      } else {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
      }
    }
    var before = TestFixtures.snapshot(version: "Unknown")
    before.identity.build = "Not applicable"
    let after = before

    UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
    let english = DeltaEngine().compare(before: before, after: after)
    UserDefaults.standard.set(AppLanguage.korean.rawValue, forKey: AppLanguage.storageKey)
    let korean = DeltaEngine().compare(before: before, after: after)

    XCTAssertFalse(english.items.contains { $0.id == "scalar:overview:Version" })
    XCTAssertFalse(korean.items.contains { $0.id == "scalar:overview:Version" })
  }
}
