import XCTest

@testable import AppDelta

final class ReportExporterTests: XCTestCase {
  func testHTMLIsStaticAndEscapesArtifactControlledValues() throws {
    let attack = "</script><script>marker()</script><img src=x onerror=alert(1)>"
    let before = TestFixtures.snapshot(name: attack)
    let after = TestFixtures.snapshot(name: "Candidate", version: "2.0")
    let report = DeltaEngine().compare(before: before, after: after)

    let html = String(
      decoding: try ReportExporter().data(for: report, format: .html), as: UTF8.self)

    XCTAssertFalse(html.contains("<script>marker()"))
    XCTAssertFalse(html.contains("<img src=x"))
    XCTAssertTrue(html.contains("&lt;/script&gt;"))
    XCTAssertTrue(html.contains("default-src 'none'"))
  }

  func testJSONRoundTrips() throws {
    let report = DeltaEngine().compare(
      before: TestFixtures.snapshot(),
      after: TestFixtures.snapshot(version: "2.0")
    )
    let data = try ReportExporter().data(for: report, format: .json)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(DeltaReport.self, from: data)
    XCTAssertEqual(decoded.before, report.before)
    XCTAssertEqual(decoded.after, report.after)
    XCTAssertEqual(decoded.items, report.items)
    XCTAssertEqual(
      decoded.generatedAt.timeIntervalSince1970, report.generatedAt.timeIntervalSince1970,
      accuracy: 1)
  }

  func testExportRejectsSymbolicLinkDestination() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "AppDeltaExport-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("real.json")
    let link = directory.appendingPathComponent("report.json")
    try Data().write(to: target)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    let report = DeltaEngine().compare(
      before: TestFixtures.snapshot(), after: TestFixtures.snapshot(version: "2.0"))

    XCTAssertThrowsError(try ReportExporter().write(report, format: .json, to: link)) { error in
      XCTAssertEqual(error as? AnalysisError, .unsafePath(link.path))
    }
  }
}
