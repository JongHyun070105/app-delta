import XCTest

@testable import AppDelta

final class ComparisonCompatibilityNoticeTests: XCTestCase {
  func testMixedFormatsRemainSupportedButProduceANotice() throws {
    let before = TestFixtures.snapshot(sourceKind: .application)
    let after = TestFixtures.snapshot(version: "2.0", sourceKind: .diskImage)

    let notice = try XCTUnwrap(
      ComparisonCompatibilityNotice.evaluate(before: before, after: after))

    XCTAssertTrue(notice.hasMixedFormats)
    XCTAssertFalse(notice.hasDifferentIdentifiers)
  }

  func testDifferentBundleIdentifiersAreFlagged() throws {
    let before = TestFixtures.snapshot(bundleIdentifier: "com.example.first")
    let after = TestFixtures.snapshot(
      name: "Other", version: "2.0", bundleIdentifier: "com.example.second")

    let notice = try XCTUnwrap(
      ComparisonCompatibilityNotice.evaluate(before: before, after: after))

    XCTAssertFalse(notice.hasMixedFormats)
    XCTAssertTrue(notice.hasDifferentIdentifiers)
  }

  func testUnknownIdentifierDoesNotClaimAppsAreDifferent() throws {
    let before = TestFixtures.snapshot(bundleIdentifier: "Unavailable")
    let after = TestFixtures.snapshot(version: "2.0", bundleIdentifier: "com.example.fixture")

    let notice = try XCTUnwrap(
      ComparisonCompatibilityNotice.evaluate(before: before, after: after))

    XCTAssertTrue(notice.hasUnconfirmedIdentity)
    XCTAssertFalse(notice.hasDifferentIdentifiers)
  }

  func testMatchingApplicationAndFormatNeedNoNotice() {
    let before = TestFixtures.snapshot()
    let after = TestFixtures.snapshot(version: "2.0")

    XCTAssertNil(ComparisonCompatibilityNotice.evaluate(before: before, after: after))
  }
}
