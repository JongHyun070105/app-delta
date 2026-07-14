import XCTest

@testable import AppDelta

final class ComparisonStoreTests: XCTestCase {
  @MainActor
  func testChangingViewFiltersClearsStaleInspectorSelection() {
    let store = ComparisonStore()
    store.selectedItemID = "example"
    store.searchText = "network"
    XCTAssertNil(store.selectedItemID)

    store.selectedItemID = "example"
    store.selectedCategory = .privacy
    XCTAssertNil(store.selectedItemID)

    store.selectedItemID = "example"
    store.minimumSeverity = .important
    XCTAssertNil(store.selectedItemID)
  }

  @MainActor
  func testCancellingAnalysisPreventsStaleResultFromBeingPublished() async throws {
    let analyzer = SlowCancellationAwareAnalyzer()
    let store = ComparisonStore(analyzer: analyzer)
    store.setArtifact(url: URL(fileURLWithPath: "/tmp/Baseline.app"), for: .baseline)
    store.setArtifact(url: URL(fileURLWithPath: "/tmp/Candidate.app"), for: .candidate)

    store.analyze()
    for _ in 0..<100 where !analyzer.hasStarted {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(analyzer.hasStarted)

    store.cancelAnalysis()
    try await Task.sleep(for: .milliseconds(150))

    XCTAssertEqual(store.phase, .idle)
    XCTAssertNil(store.report)
    XCTAssertTrue(analyzer.observedCancellation)
  }
}

private final class SlowCancellationAwareAnalyzer: ArtifactAnalyzing, @unchecked Sendable {
  private let lock = NSLock()
  private var started = false
  private var cancelled = false

  var hasStarted: Bool {
    lock.withLock { started }
  }

  var observedCancellation: Bool {
    lock.withLock { cancelled }
  }

  func analyze(_ artifact: SelectedArtifact, budget: ScanBudget) throws -> AppSnapshot {
    lock.withLock { started = true }
    for _ in 0..<100 {
      if Task.isCancelled {
        lock.withLock { cancelled = true }
        throw CancellationError()
      }
      Thread.sleep(forTimeInterval: 0.01)
    }
    return TestFixtures.snapshot(name: artifact.displayName)
  }
}
