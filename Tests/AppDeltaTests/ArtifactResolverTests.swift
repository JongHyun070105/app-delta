import Foundation
import XCTest

@testable import AppDelta

final class ArtifactResolverTests: XCTestCase {
  func testAttachCancellationDiscoversAndDetachesPartialMount() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AppDeltaResolverTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let image = temporaryDirectory.appendingPathComponent("Cancelled.dmg")
    try Data("fixture".utf8).write(to: image)
    let artifact = try XCTUnwrap(SelectedArtifact(url: image))
    let runner = CancelDuringAttachRunner()
    let resolver = ArtifactResolver(commandRunner: runner)

    XCTAssertThrowsError(try resolver.resolveApplication(from: artifact)) { error in
      XCTAssertTrue(error is CancellationError)
    }

    XCTAssertEqual(runner.detachedDevices, ["/dev/disk998"])
  }
}

private final class CancelDuringAttachRunner: CommandRunning, @unchecked Sendable {
  private let lock = NSLock()
  private var sessionRoot: String?
  private var devices: [String] = []

  var detachedDevices: [String] {
    lock.withLock { devices }
  }

  func run(_ tool: SystemTool, arguments: [String], budget: ScanBudget) throws -> CommandResult {
    XCTAssertEqual(tool, .hdiutil)
    switch arguments.first {
    case "verify":
      return result(status: 0)
    case "attach":
      let rootIndex = try XCTUnwrap(arguments.firstIndex(of: "-mountrandom")) + 1
      lock.withLock { sessionRoot = arguments[rootIndex] }
      throw CancellationError()
    case "info":
      let root = try XCTUnwrap(lock.withLock { sessionRoot })
      let plist: [String: Any] = [
        "images": [
          [
            "system-entities": [
              ["dev-entry": "/dev/disk998"],
              [
                "dev-entry": "/dev/disk999",
                "mount-point": URL(fileURLWithPath: root)
                  .appendingPathComponent("MockVolume", isDirectory: true).path,
              ],
            ]
          ]
        ]
      ]
      return result(
        status: 0,
        standardOutput: try PropertyListSerialization.data(
          fromPropertyList: plist, format: .xml, options: 0))
    case "detach":
      if arguments.count > 1 {
        lock.withLock { devices.append(arguments[1]) }
      }
      return result(status: 0)
    default:
      XCTFail("Unexpected hdiutil arguments: \(arguments)")
      return result(status: 1)
    }
  }

  private func result(status: Int32, standardOutput: Data = Data()) -> CommandResult {
    CommandResult(status: status, standardOutput: standardOutput, standardError: Data())
  }
}
