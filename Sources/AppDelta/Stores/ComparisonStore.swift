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
      case .inspectingBaseline: "Inspecting baseline…"
      case .inspectingCandidate: "Inspecting candidate…"
      case .comparing: "Building comparison…"
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
  private var analysisTask: Task<Void, Never>?
  private var analysisGeneration: UUID?

  init(
    analyzer: any ArtifactAnalyzing = AppAnalyzer(),
    engine: DeltaEngine = DeltaEngine(),
    exporter: ReportExporter = ReportExporter()
  ) {
    self.analyzer = analyzer
    self.engine = engine
    self.exporter = exporter
  }

  deinit { analysisTask?.cancel() }

  var canAnalyze: Bool {
    baseline != nil && candidate != nil && !phase.isWorking
  }

  var selectedItem: DeltaItem? {
    guard let selectedItemID else { return nil }
    return report?.items.first { $0.id == selectedItemID }
  }

  func setArtifact(url: URL, for slot: Slot) {
    stopCurrentAnalysis()
    guard let artifact = SelectedArtifact(url: url) else {
      phase = .failed("Choose a .app, .dmg, .pkg, or .mpkg artifact.")
      return
    }
    switch slot {
    case .baseline: baseline = artifact
    case .candidate: candidate = artifact
    }
    phase = .idle
  }

  func chooseArtifact(for slot: Slot) {
    let panel = NSOpenPanel()
    panel.title = slot == .baseline ? "Choose Baseline Artifact" : "Choose Candidate Artifact"
    panel.prompt = "Choose"
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
    case .baseline: baseline = nil
    case .candidate: candidate = nil
    }
    report = nil
    selectedItemID = nil
    phase = .idle
  }

  func swapArtifacts() {
    guard !phase.isWorking else { return }
    (baseline, candidate) = (candidate, baseline)
    if let report {
      self.report = engine.compare(before: report.after, after: report.before)
    }
    selectedItemID = nil
  }

  func analyze() {
    guard let baseline, let candidate, canAnalyze else { return }
    stopCurrentAnalysis()
    let analyzer = self.analyzer
    let engine = self.engine
    let generation = UUID()
    analysisGeneration = generation

    analysisTask = Task { [weak self] in
      guard let self else { return }
      do {
        phase = .inspectingBaseline
        let before = try await cancellableDetachedValue(priority: .userInitiated) {
          try analyzer.analyze(baseline)
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

  private func ensureCurrent(_ generation: UUID) throws {
    try Task.checkCancellation()
    guard analysisGeneration == generation else { throw CancellationError() }
  }

  private func stopCurrentAnalysis() {
    analysisGeneration = nil
    analysisTask?.cancel()
    analysisTask = nil
  }

  func export(_ format: ReportFormat) {
    guard let report else { return }
    let panel = NSSavePanel()
    panel.title = "Export App Delta Report"
    panel.prompt = "Export"
    panel.nameFieldStringValue =
      "\(safeName(report.before.identity.name))-to-\(safeName(report.after.identity.name)).\(format.fileExtension)"
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    do {
      try exporter.write(report, format: format, to: destination)
    } catch {
      phase = .failed("The report could not be exported: \(error.localizedDescription)")
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
