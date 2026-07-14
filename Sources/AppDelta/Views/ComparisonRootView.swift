import SwiftUI

struct ComparisonRootView: View {
  @StateObject private var store = ComparisonStore()

  var body: some View {
    Group {
      if store.report == nil {
        SourcePickerView(store: store)
      } else {
        comparisonLayout
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if let label = store.phase.label {
        AnalysisBanner(phase: store.phase, label: label) {
          store.cancelAnalysis()
        }
      }
    }
    .toolbar { toolbarContent }
    .focusedSceneValue(\.comparisonActions, actions)
    .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search changes")
    .inspector(isPresented: $store.showsInspector) {
      DiffInspectorView(item: store.selectedItem)
        .inspectorColumnWidth(min: 260, ideal: 330, max: 480)
    }
  }

  private var comparisonLayout: some View {
    NavigationSplitView {
      ComparisonSidebar(store: store)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
    } detail: {
      ComparisonDetailView(store: store)
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        store.swapArtifacts()
      } label: {
        Label("Swap", systemImage: "arrow.left.arrow.right")
      }
      .help("Swap baseline and candidate")
      .disabled(store.baseline == nil || store.candidate == nil || store.phase.isWorking)

      Button {
        store.analyze()
      } label: {
        Label(store.report == nil ? "Analyze" : "Analyze Again", systemImage: "waveform.path.ecg")
      }
      .buttonStyle(.borderedProminent)
      .disabled(!store.canAnalyze)

      Menu {
        Picker("Minimum severity", selection: $store.minimumSeverity) {
          ForEach(DeltaSeverity.allCases, id: \.self) { severity in
            Text(severity.label).tag(severity)
          }
        }
      } label: {
        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
      }
      .disabled(store.report == nil)

      Menu {
        Button("HTML Report…") { store.export(.html) }
        Button("JSON…") { store.export(.json) }
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
      }
      .disabled(store.report == nil)

      Button {
        store.showsInspector.toggle()
      } label: {
        Label("Inspector", systemImage: "sidebar.right")
      }
      .help("Show or hide the detail inspector")
    }
  }

  private var actions: ComparisonActions {
    .init(
      chooseBaseline: { store.chooseArtifact(for: .baseline) },
      chooseCandidate: { store.chooseArtifact(for: .candidate) },
      analyze: { store.analyze() },
      swap: { store.swapArtifacts() },
      exportHTML: { store.export(.html) },
      exportJSON: { store.export(.json) },
      toggleInspector: { store.showsInspector.toggle() },
      canAnalyze: store.canAnalyze,
      canExport: store.report != nil
    )
  }
}

private struct AnalysisBanner: View {
  let phase: ComparisonStore.Phase
  let label: String
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      if phase.isWorking {
        ProgressView().controlSize(.small)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }
      Text(label)
        .font(.callout)
        .lineLimit(2)
      Spacer()
      if phase.isWorking {
        Button("Cancel", action: cancel)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
    .accessibilityElement(children: .combine)
  }
}
