import SwiftUI

struct ComparisonRootView: View {
  @StateObject private var store = ComparisonStore()
  @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: language) ?? .system
  }

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
    .searchable(
      text: $store.searchText, placement: .toolbar, prompt: Text(L10n.text("Search changes"))
    )
    .inspector(isPresented: $store.showsInspector) {
      DiffInspectorView(item: store.selectedItem)
        .id(language)
        .inspectorColumnWidth(min: 260, ideal: 330, max: 480)
    }
    .environment(\.locale, selectedLanguage.locale)
    .onChange(of: language) { _, _ in store.refreshLocalization() }
  }

  private var comparisonLayout: some View {
    NavigationSplitView {
      ComparisonSidebar(store: store)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
    } detail: {
      ComparisonDetailView(store: store)
        .id(language)
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if store.report != nil {
      ToolbarItem(placement: .navigation) {
        Button {
          store.returnToSourceSelection()
        } label: {
          Label(L10n.text("Back to Sources"), systemImage: "chevron.backward")
        }
        .help(L10n.text("Return to the artifact selection screen"))
      }
    }

    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        store.swapArtifacts()
      } label: {
        Label(L10n.text("Swap"), systemImage: "arrow.left.arrow.right")
      }
      .help(L10n.text("Swap baseline and candidate"))
      .disabled(!store.canSwap)

      Button {
        store.analyze()
      } label: {
        Label(
          L10n.text(store.report == nil ? "Analyze" : "Analyze Again"),
          systemImage: "waveform.path.ecg")
      }
      .buttonStyle(.borderedProminent)
      .disabled(!store.canAnalyze)

      Menu {
        Picker(L10n.text("Minimum severity"), selection: $store.minimumSeverity) {
          ForEach(DeltaSeverity.allCases, id: \.self) { severity in
            Text(severity.label).tag(severity)
          }
        }
      } label: {
        Label(L10n.text("Filter"), systemImage: "line.3.horizontal.decrease.circle")
      }
      .disabled(store.report == nil)

      Menu {
        Button(L10n.text("HTML Report…")) { store.export(.html) }
        Button(L10n.text("JSON…")) { store.export(.json) }
      } label: {
        Label(L10n.text("Export"), systemImage: "square.and.arrow.up")
      }
      .disabled(store.report == nil)

      Menu {
        Picker(L10n.text("Language"), selection: $language) {
          ForEach(AppLanguage.allCases) { option in
            Text(option.displayName).tag(option.rawValue)
          }
        }
      } label: {
        Label(L10n.text("Language"), systemImage: "globe")
      }

      Button {
        store.showsInspector.toggle()
      } label: {
        Label(L10n.text("Inspector"), systemImage: "sidebar.right")
      }
      .help(L10n.text("Show or hide the detail inspector"))
    }
  }

  private var actions: ComparisonActions {
    .init(
      chooseBaseline: { store.chooseArtifact(for: .baseline) },
      chooseCandidate: { store.chooseArtifact(for: .candidate) },
      analyze: { store.analyze() },
      returnToSources: { store.returnToSourceSelection() },
      swap: { store.swapArtifacts() },
      exportHTML: { store.export(.html) },
      exportJSON: { store.export(.json) },
      toggleInspector: { store.showsInspector.toggle() },
      canAnalyze: store.canAnalyze,
      canExport: store.report != nil,
      canSwap: store.canSwap,
      canReturnToSources: store.report != nil
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
        Button(L10n.text("Cancel"), action: cancel)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
    .accessibilityElement(children: .combine)
  }
}
