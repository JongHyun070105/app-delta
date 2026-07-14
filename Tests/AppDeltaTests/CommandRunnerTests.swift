import XCTest

@testable import AppDelta

final class CommandRunnerTests: XCTestCase {
  func testTimeoutTerminatesUnboundedSystemTool() throws {
    var budget = ScanBudget.default
    budget.commandTimeout = 0.1
    let started = Date()

    XCTAssertThrowsError(
      try BoundedCommandRunner().run(.shasum, arguments: ["/dev/zero"], budget: budget)
    ) { error in
      XCTAssertEqual(error as? AnalysisError, .commandTimedOut("shasum"))
    }
    XCTAssertLessThan(Date().timeIntervalSince(started), 2)
  }

  func testCancelledTaskStillAllowsDiskImageCleanupDiscovery() async throws {
    let task = Task.detached {
      try BoundedCommandRunner().run(
        .hdiutil, arguments: ["info", "-plist"], budget: .default)
    }
    task.cancel()

    let result = try await task.value

    XCTAssertEqual(result.status, 0)
    XCTAssertFalse(result.standardOutput.isEmpty)
  }
}
