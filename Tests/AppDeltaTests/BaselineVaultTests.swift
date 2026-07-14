import XCTest

@testable import AppDelta

final class BaselineVaultTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "AppDeltaBaselineVault-\(UUID().uuidString)", isDirectory: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func testSaveLoadAndDeleteRoundTrip() throws {
    let vault = BaselineVault(directoryURL: directory)
    let snapshot = TestFixtures.snapshot(version: "1.4.0")
    let source = URL(fileURLWithPath: "/Applications/Fixture.app")

    let record = try vault.save(snapshot: snapshot, originalApplicationURL: source)
    let summary = try XCTUnwrap(vault.list().first)
    XCTAssertEqual(summary.id, record.id)
    let loaded = try vault.load(summary)
    XCTAssertEqual(loaded.id, record.id)
    XCTAssertEqual(loaded.originalApplicationURL, source)
    XCTAssertEqual(loaded.snapshot, snapshot)

    try vault.delete(record)
    XCTAssertTrue(try vault.list().isEmpty)
  }

  func testCorruptAndFutureSchemaFilesAreSkipped() throws {
    let vault = BaselineVault(directoryURL: directory)
    let valid = try vault.save(
      snapshot: TestFixtures.snapshot(version: "1.0"),
      originalApplicationURL: URL(fileURLWithPath: "/Applications/Fixture.app"))
    try Data("not json".utf8).write(
      to: directory.appendingPathComponent("corrupt.metadata.json"), options: .atomic)
    let metadataURL = directory.appendingPathComponent("\(valid.id.uuidString).metadata.json")
    var future = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
    future["schemaVersion"] = 99
    try JSONSerialization.data(withJSONObject: future).write(
      to: directory.appendingPathComponent("future.metadata.json"), options: .atomic)

    let loaded = try vault.list()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.id, valid.id)
  }

  func testListingDoesNotDecodeTheFullSnapshot() throws {
    let vault = BaselineVault(directoryURL: directory)
    let record = try vault.save(
      snapshot: TestFixtures.snapshot(version: "1.0"),
      originalApplicationURL: URL(fileURLWithPath: "/Applications/Fixture.app"))
    let snapshotURL = directory.appendingPathComponent("\(record.id.uuidString).snapshot.json")
    try Data("broken snapshot".utf8).write(to: snapshotURL, options: .atomic)

    let summary = try XCTUnwrap(vault.list().first)
    XCTAssertThrowsError(try vault.load(summary))
  }
}
