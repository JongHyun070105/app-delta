import XCTest

@testable import AppDelta

final class ArtifactKindTests: XCTestCase {
  func testSupportedExtensionsAreCaseInsensitive() {
    XCTAssertEqual(ArtifactKind(url: URL(fileURLWithPath: "/tmp/App.APP")), .application)
    XCTAssertEqual(ArtifactKind(url: URL(fileURLWithPath: "/tmp/App.dmg")), .diskImage)
    XCTAssertEqual(ArtifactKind(url: URL(fileURLWithPath: "/tmp/App.pkg")), .installerPackage)
    XCTAssertEqual(ArtifactKind(url: URL(fileURLWithPath: "/tmp/App.mpkg")), .installerPackage)
    XCTAssertNil(ArtifactKind(url: URL(fileURLWithPath: "/tmp/App.zip")))
  }
}
