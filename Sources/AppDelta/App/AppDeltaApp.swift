import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}

struct ComparisonActions {
  var chooseBaseline: () -> Void
  var chooseCandidate: () -> Void
  var analyze: () -> Void
  var swap: () -> Void
  var exportHTML: () -> Void
  var exportJSON: () -> Void
  var toggleInspector: () -> Void
  var canAnalyze: Bool
  var canExport: Bool
}

private struct ComparisonActionsKey: FocusedValueKey {
  typealias Value = ComparisonActions
}

extension FocusedValues {
  var comparisonActions: ComparisonActions? {
    get { self[ComparisonActionsKey.self] }
    set { self[ComparisonActionsKey.self] = newValue }
  }
}

struct AppDeltaCommands: Commands {
  @FocusedValue(\.comparisonActions) private var actions

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("Choose Baseline…") { actions?.chooseBaseline() }
        .keyboardShortcut("o", modifiers: [.command])
      Button("Choose Candidate…") { actions?.chooseCandidate() }
        .keyboardShortcut("o", modifiers: [.command, .shift])
    }

    CommandMenu("Comparison") {
      Button("Analyze") { actions?.analyze() }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(actions?.canAnalyze != true)
      Button("Swap Baseline and Candidate") { actions?.swap() }
        .keyboardShortcut("s", modifiers: [.command, .option])
      Divider()
      Button("Toggle Inspector") { actions?.toggleInspector() }
        .keyboardShortcut("i", modifiers: [.command, .option])
    }

    CommandMenu("Export") {
      Button("Export HTML Report…") { actions?.exportHTML() }
        .disabled(actions?.canExport != true)
      Button("Export JSON…") { actions?.exportJSON() }
        .disabled(actions?.canExport != true)
    }
  }
}

@main
struct AppDeltaApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("App Delta", id: "comparison") {
      ComparisonRootView()
        .frame(minWidth: 900, minHeight: 600)
    }
    .defaultSize(width: 1180, height: 760)
    .commands { AppDeltaCommands() }
  }
}
