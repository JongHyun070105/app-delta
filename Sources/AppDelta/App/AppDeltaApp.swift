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
  @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button(L10n.text("Choose Baseline…")) { actions?.chooseBaseline() }
        .keyboardShortcut("o", modifiers: [.command])
      Button(L10n.text("Choose Candidate…")) { actions?.chooseCandidate() }
        .keyboardShortcut("o", modifiers: [.command, .shift])
    }

    CommandMenu(L10n.text("Comparison")) {
      Button(L10n.text("Analyze")) { actions?.analyze() }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(actions?.canAnalyze != true)
      Button(L10n.text("Swap Baseline and Candidate")) { actions?.swap() }
        .keyboardShortcut("s", modifiers: [.command, .option])
      Divider()
      Button(L10n.text("Toggle Inspector")) { actions?.toggleInspector() }
        .keyboardShortcut("i", modifiers: [.command, .option])
    }

    CommandMenu(L10n.text("Export")) {
      Button(L10n.text("Export HTML Report…")) { actions?.exportHTML() }
        .disabled(actions?.canExport != true)
      Button(L10n.text("Export JSON…")) { actions?.exportJSON() }
        .disabled(actions?.canExport != true)
    }

    CommandMenu(L10n.text("Language")) {
      Picker(L10n.text("Language"), selection: $language) {
        ForEach(AppLanguage.allCases) { option in
          Text(option.displayName).tag(option.rawValue)
        }
      }
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

    Settings {
      AppDeltaSettingsView()
    }
  }
}
