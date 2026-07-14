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

  @MainActor
  func testRefreshingLocalizationKeepsTheCurrentComparison() {
    let previousLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
    defer {
      if let previousLanguage {
        UserDefaults.standard.set(previousLanguage, forKey: AppLanguage.storageKey)
      } else {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
      }
    }

    UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
    let store = ComparisonStore()
    let before = TestFixtures.snapshot()
    let after = TestFixtures.snapshot(version: "2.0")
    store.report = DeltaEngine().compare(before: before, after: after)
    let itemID = store.report?.items.first { $0.id == "scalar:overview:Version" }?.id
    store.selectedItemID = itemID

    UserDefaults.standard.set(AppLanguage.korean.rawValue, forKey: AppLanguage.storageKey)
    store.refreshLocalization()

    XCTAssertEqual(store.report?.before, before)
    XCTAssertEqual(store.report?.after, after)
    XCTAssertEqual(
      store.report?.items.first { $0.id == "scalar:overview:Version" }?.title, "버전")
    XCTAssertEqual(store.selectedItemID, itemID)
  }

  @MainActor
  func testReturningToSourcesKeepsArtifactsAndClearsComparisonState() {
    let store = ComparisonStore()
    let baselineURL = URL(fileURLWithPath: "/tmp/Baseline.app")
    let candidateURL = URL(fileURLWithPath: "/tmp/Candidate.dmg")
    store.setArtifact(url: baselineURL, for: .baseline)
    store.setArtifact(url: candidateURL, for: .candidate)
    store.report = DeltaEngine().compare(
      before: TestFixtures.snapshot(),
      after: TestFixtures.snapshot(version: "2.0"))
    store.searchText = "camera"
    store.selectedItemID = "example"

    store.returnToSourceSelection()

    XCTAssertNil(store.report)
    XCTAssertEqual(store.baseline?.url, baselineURL)
    XCTAssertEqual(store.candidate?.url, candidateURL)
    XCTAssertEqual(store.searchText, "")
    XCTAssertNil(store.selectedItemID)
    XCTAssertEqual(store.phase, .idle)
  }

  @MainActor
  func testMixedSelectionFormatsAreExplainedBeforeAnalysis() {
    let store = ComparisonStore()
    store.setArtifact(url: URL(fileURLWithPath: "/tmp/Baseline.app"), for: .baseline)
    store.setArtifact(url: URL(fileURLWithPath: "/tmp/Candidate.pkg"), for: .candidate)

    XCTAssertNotNil(store.selectionFormatNotice)
  }

  @MainActor
  func testSavedBaselineIsNotReanalyzed() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ComparisonStoreBaseline-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let vault = BaselineVault(directoryURL: directory)
    let record = try vault.save(
      snapshot: TestFixtures.snapshot(version: "1.0"),
      originalApplicationURL: URL(fileURLWithPath: "/Applications/Fixture.app"))
    let analyzer = RecordingAnalyzer(snapshot: TestFixtures.snapshot(version: "2.0"))
    let store = ComparisonStore(analyzer: analyzer, baselineVault: vault)
    store.selectSavedBaseline(record.summary)
    for _ in 0..<100 where store.savedBaseline == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    store.setArtifact(url: URL(fileURLWithPath: "/tmp/Candidate.app"), for: .candidate)

    store.analyze()
    for _ in 0..<100 where store.phase != .completed {
      try await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertEqual(analyzer.callCount, 1)
    XCTAssertEqual(store.report?.before.identity.version, "1.0")
    XCTAssertEqual(store.report?.after.identity.version, "2.0")
  }

  @MainActor
  func testPreparingForUpdateSavesBaselineAndKeepsCandidatePath() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ComparisonStorePrepare-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let vault = BaselineVault(directoryURL: directory)
    let analyzer = RecordingAnalyzer(snapshot: TestFixtures.snapshot(version: "1.4"))
    let store = ComparisonStore(analyzer: analyzer, baselineVault: vault)
    let application = URL(fileURLWithPath: "/Applications/Fixture.app")

    store.preserveBaselineForUpdate(at: application)
    for _ in 0..<100 where store.phase != .completed {
      try await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertEqual(store.savedBaseline?.snapshot.identity.version, "1.4")
    XCTAssertEqual(store.candidate?.url, application)
    XCTAssertEqual(try vault.list().count, 1)
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

private final class RecordingAnalyzer: ArtifactAnalyzing, @unchecked Sendable {
  private let lock = NSLock()
  private let snapshot: AppSnapshot
  private var calls = 0

  init(snapshot: AppSnapshot) {
    self.snapshot = snapshot
  }

  var callCount: Int { lock.withLock { calls } }

  func analyze(_ artifact: SelectedArtifact, budget: ScanBudget) throws -> AppSnapshot {
    lock.withLock { calls += 1 }
    return snapshot
  }
}
