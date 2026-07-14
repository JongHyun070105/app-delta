import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ComparisonStore: ObservableObject {
  enum Slot { case baseline, candidate }

  enum Phase: Equatable {
    case idle
    case inspectingBaseline
    case inspectingCandidate
    case comparing
    case completed
    case failed(String)

    var label: String? {
      switch self {
      case .idle, .completed: nil
      case .inspectingBaseline: L10n.text("Inspecting baseline…")
      case .inspectingCandidate: L10n.text("Inspecting candidate…")
      case .comparing: L10n.text("Building comparison…")
      case .failed(let message): message
      }
    }

    var isWorking: Bool {
      switch self {
      case .inspectingBaseline, .inspectingCandidate, .comparing: true
      default: false
      }
    }
  }

  @Published var baseline: SelectedArtifact?
  @Published var candidate: SelectedArtifact?
  @Published var savedBaseline: SavedBaseline?
  @Published var savedBaselines: [SavedBaselineSummary]
  @Published var phase: Phase = .idle
  @Published var report: DeltaReport?
  @Published var selectedCategory: DeltaCategory = .overview {
    didSet { selectedItemID = nil }
  }
  @Published var selectedItemID: DeltaItem.ID?
  @Published var searchText = "" {
    didSet { selectedItemID = nil }
  }
  @Published var minimumSeverity: DeltaSeverity = .info {
    didSet { selectedItemID = nil }
  }
  @Published var showsInspector = true

  private let analyzer: any ArtifactAnalyzing
  private let engine: DeltaEngine
  private let exporter: ReportExporter
  private let baselineVault: BaselineVault
  private var analysisTask: Task<Void, Never>?
  private var baselineListTask: Task<Void, Never>?
  private var analysisGeneration: UUID?
  private var baselineListGeneration: UUID?

  init(
    analyzer: any ArtifactAnalyzing = AppAnalyzer(),
    engine: DeltaEngine = DeltaEngine(),
    exporter: ReportExporter = ReportExporter(),
    baselineVault: BaselineVault = BaselineVault()
  ) {
    self.analyzer = analyzer
    self.engine = engine
    self.exporter = exporter
    self.baselineVault = baselineVault
    savedBaselines = []
    loadBaselineSummaries()
  }

  deinit {
    analysisTask?.cancel()
    baselineListTask?.cancel()
  }

  var canAnalyze: Bool {
    (baseline != nil || savedBaseline != nil) && candidate != nil && !phase.isWorking
  }

  var canSwap: Bool {
    baseline != nil && candidate != nil && savedBaseline == nil && !phase.isWorking
  }

  var compatibilityNotice: ComparisonCompatibilityNotice? {
    guard let report else { return nil }
    return ComparisonCompatibilityNotice.evaluate(before: report.before, after: report.after)
  }

  var selectionFormatNotice: String? {
    let baselineKind = savedBaseline?.snapshot.sourceKind ?? baseline?.kind
    guard let baselineKind, let candidateKind = candidate?.kind, baselineKind != candidateKind
    else {
      return nil
    }
    return L10n.format(
      "Different formats selected: %@ and %@. Comparison is supported, but packaging differences may appear as broad changes.",
      baselineKind.label, candidateKind.label)
  }

  var selectedItem: DeltaItem? {
    guard let selectedItemID else { return nil }
    return report?.items.first { $0.id == selectedItemID }
  }

  func setArtifact(url: URL, for slot: Slot) {
    stopCurrentAnalysis()
    guard let artifact = SelectedArtifact(url: url) else {
      phase = .failed(L10n.text("Choose a .app, .dmg, .pkg, or .mpkg artifact."))
      return
    }
    switch slot {
    case .baseline:
      baseline = artifact
      savedBaseline = nil
    case .candidate: candidate = artifact
    }
    phase = .idle
  }

  func chooseArtifact(for slot: Slot) {
    let panel = NSOpenPanel()
    panel.title = L10n.text(
      slot == .baseline ? "Choose Baseline Artifact" : "Choose Candidate Artifact")
    panel.prompt = L10n.text("Choose")
    panel.canChooseFiles = true
    // Application bundles are directory packages. NSOpenPanel requires
    // directory selection for them even when treatsFilePackagesAsDirectories
    // is false; extension validation still rejects ordinary folders.
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.resolvesAliases = false
    panel.treatsFilePackagesAsDirectories = false
    var supportedTypes: [UTType] = [.applicationBundle, .diskImage]
    if let installerPackage = UTType("com.apple.installer-package-archive") {
      supportedTypes.append(installerPackage)
    }
    panel.allowedContentTypes = supportedTypes
    guard panel.runModal() == .OK, let url = panel.url else { return }
    setArtifact(url: url, for: slot)
  }

  func clear(_ slot: Slot) {
    stopCurrentAnalysis()
    switch slot {
    case .baseline:
      baseline = nil
      savedBaseline = nil
    case .candidate: candidate = nil
    }
    report = nil
    selectedItemID = nil
    phase = .idle
  }

  func swapArtifacts() {
    guard canSwap else { return }
    (baseline, candidate) = (candidate, baseline)
    if let report {
      self.report = engine.compare(before: report.after, after: report.before)
    }
    selectedItemID = nil
  }

  func analyze() {
    guard let candidate, canAnalyze else { return }
    let baselineArtifact = baseline
    let savedSnapshot = savedBaseline?.snapshot
    stopCurrentAnalysis()
    let analyzer = self.analyzer
    let engine = self.engine
    let generation = UUID()
    analysisGeneration = generation

    analysisTask = Task { [weak self] in
      guard let self else { return }
      do {
        let before: AppSnapshot
        if let savedSnapshot {
          before = savedSnapshot
        } else {
          guard let baselineArtifact else { throw CancellationError() }
          phase = .inspectingBaseline
          before = try await cancellableDetachedValue(priority: .userInitiated) {
            try analyzer.analyze(baselineArtifact)
          }
        }
        try ensureCurrent(generation)

        phase = .inspectingCandidate
        let after = try await cancellableDetachedValue(priority: .userInitiated) {
          try analyzer.analyze(candidate)
        }
        try ensureCurrent(generation)

        phase = .comparing
        let comparison = try await cancellableDetachedValue(priority: .userInitiated) {
          engine.compare(before: before, after: after)
        }
        try ensureCurrent(generation)

        report = comparison
        selectedCategory = .overview
        selectedItemID = nil
        phase = .completed
        analysisGeneration = nil
        analysisTask = nil
      } catch is CancellationError {
        if analysisGeneration == generation {
          phase = .idle
          analysisGeneration = nil
          analysisTask = nil
        }
      } catch {
        if analysisGeneration == generation {
          phase = .failed(error.localizedDescription)
          analysisGeneration = nil
          analysisTask = nil
        }
      }
    }
  }

  func cancelAnalysis() {
    stopCurrentAnalysis()
    phase = .idle
  }

  func returnToSourceSelection() {
    stopCurrentAnalysis()
    report = nil
    selectedCategory = .overview
    selectedItemID = nil
    searchText = ""
    phase = .idle
  }

  func chooseApplicationToPreserve() {
    let panel = NSOpenPanel()
    panel.title = L10n.text("Prepare App Update Comparison")
    panel.prompt = L10n.text("Preserve Baseline")
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.resolvesAliases = false
    panel.treatsFilePackagesAsDirectories = false
    panel.allowedContentTypes = [.applicationBundle]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    preserveBaselineForUpdate(at: url)
  }

  func preserveBaselineForUpdate(at url: URL) {
    guard let artifact = SelectedArtifact(url: url), artifact.kind == .application else {
      phase = .failed(L10n.text("Choose a macOS application to preserve before updating."))
      return
    }
    stopCurrentAnalysis()
    baselineListTask?.cancel()
    baselineListTask = nil
    baselineListGeneration = nil
    let analyzer = self.analyzer
    let vault = baselineVault
    let generation = UUID()
    analysisGeneration = generation

    analysisTask = Task { [weak self] in
      guard let self else { return }
      var writtenRecord: SavedBaseline?
      do {
        phase = .inspectingBaseline
        let snapshot = try await cancellableDetachedValue(priority: .userInitiated) {
          try analyzer.analyze(artifact)
        }
        try ensureCurrent(generation)
        let record = try await cancellableDetachedValue(priority: .utility) {
          try vault.save(snapshot: snapshot, originalApplicationURL: url)
        }
        writtenRecord = record
        try ensureCurrent(generation)
        let summaries = try await cancellableDetachedValue(priority: .utility) {
          try vault.list()
        }
        try ensureCurrent(generation)
        savedBaselines = summaries
        baseline = nil
        savedBaseline = record
        candidate = artifact
        report = nil
        selectedItemID = nil
        phase = .completed
        writtenRecord = nil
        analysisGeneration = nil
        analysisTask = nil
      } catch is CancellationError {
        if let writtenRecord {
          try? await cancellableDetachedValue(priority: .utility) {
            try vault.delete(writtenRecord)
          }
        }
        if analysisGeneration == generation {
          phase = .idle
          analysisGeneration = nil
          analysisTask = nil
        }
      } catch {
        if let writtenRecord {
          try? await cancellableDetachedValue(priority: .utility) {
            try vault.delete(writtenRecord)
          }
        }
        if analysisGeneration == generation {
          phase = .failed(
            L10n.format("The baseline could not be saved: %@", error.localizedDescription))
          analysisGeneration = nil
          analysisTask = nil
        }
      }
    }
  }

  func selectSavedBaseline(_ summary: SavedBaselineSummary) {
    stopCurrentAnalysis()
    baseline = nil
    savedBaseline = nil
    report = nil
    selectedItemID = nil
    phase = .inspectingBaseline
    let vault = baselineVault
    let generation = UUID()
    analysisGeneration = generation

    analysisTask = Task { [weak self] in
      guard let self else { return }
      do {
        let record = try await cancellableDetachedValue(priority: .userInitiated) {
          try vault.load(summary)
        }
        try ensureCurrent(generation)
        savedBaseline = record
        if FileManager.default.fileExists(atPath: record.originalApplicationURL.path) {
          candidate = SelectedArtifact(url: record.originalApplicationURL)
        }
        phase = .idle
        analysisGeneration = nil
        analysisTask = nil
      } catch is CancellationError {
        if analysisGeneration == generation {
          phase = .idle
          analysisGeneration = nil
          analysisTask = nil
        }
      } catch {
        if analysisGeneration == generation {
          phase = .failed(
            L10n.format("The saved baseline could not be loaded: %@", error.localizedDescription))
          analysisGeneration = nil
          analysisTask = nil
        }
      }
    }
  }

  func deleteSavedBaseline(_ summary: SavedBaselineSummary) {
    baselineListTask?.cancel()
    let vault = baselineVault
    let generation = UUID()
    baselineListGeneration = generation
    baselineListTask = Task { [weak self] in
      guard let self else { return }
      do {
        let summaries = try await cancellableDetachedValue(priority: .utility) {
          try vault.delete(summary)
          return try vault.list()
        }
        try ensureCurrentBaselineList(generation)
        savedBaselines = summaries
        if savedBaseline?.id == summary.id {
          savedBaseline = nil
        }
      } catch is CancellationError {
        // A newer list operation owns publication and cleanup.
      } catch {
        if baselineListGeneration == generation {
          phase = .failed(
            L10n.format("The saved baseline could not be deleted: %@", error.localizedDescription))
        }
      }
      if baselineListGeneration == generation {
        baselineListTask = nil
        baselineListGeneration = nil
      }
    }
  }

  func refreshLocalization() {
    if let report {
      self.report = engine.compare(before: report.before, after: report.after)
    }
    objectWillChange.send()
  }

  private func ensureCurrent(_ generation: UUID) throws {
    try Task.checkCancellation()
    guard analysisGeneration == generation else { throw CancellationError() }
  }

  private func stopCurrentAnalysis() {
    analysisGeneration = nil
    analysisTask?.cancel()
    analysisTask = nil
  }

  private func ensureCurrentBaselineList(_ generation: UUID) throws {
    try Task.checkCancellation()
    guard baselineListGeneration == generation else { throw CancellationError() }
  }

  private func loadBaselineSummaries() {
    baselineListTask?.cancel()
    let vault = baselineVault
    let generation = UUID()
    baselineListGeneration = generation
    baselineListTask = Task { [weak self] in
      guard let self else { return }
      do {
        let summaries = try await cancellableDetachedValue(priority: .utility) {
          try vault.list()
        }
        try ensureCurrentBaselineList(generation)
        savedBaselines = summaries
      } catch {
        // A corrupt or inaccessible vault must not block launching the application.
      }
      if baselineListGeneration == generation {
        baselineListTask = nil
        baselineListGeneration = nil
      }
    }
  }

  func export(_ format: ReportFormat) {
    guard let report else { return }
    let panel = NSSavePanel()
    panel.title = L10n.text("Export App Delta Report")
    panel.prompt = L10n.text("Export")
    panel.nameFieldStringValue =
      "\(safeName(report.before.identity.name))-to-\(safeName(report.after.identity.name)).\(format.fileExtension)"
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    do {
      try exporter.write(report, format: format, to: destination)
    } catch {
      phase = .failed(
        L10n.format("The report could not be exported: %@", error.localizedDescription))
    }
  }

  func items(for category: DeltaCategory) -> [DeltaItem] {
    guard let report else { return [] }
    return report.changedItems.filter { item in
      let categoryMatches = category == .overview ? true : item.category == category
      let severityMatches = item.severity >= minimumSeverity
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let searchMatches =
        query.isEmpty
        || [item.title, item.detail, item.before ?? "", item.after ?? "", item.evidencePath ?? ""]
          .joined(separator: " ")
          .localizedCaseInsensitiveContains(query)
      return categoryMatches && severityMatches && searchMatches
    }
  }

  private func safeName(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
  }
}

private func cancellableDetachedValue<Value: Sendable>(
  priority: TaskPriority,
  operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
  let task = Task.detached(priority: priority, operation: operation)
  return try await withTaskCancellationHandler {
    try await task.value
  } onCancel: {
    task.cancel()
  }
}
