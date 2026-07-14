import SwiftUI

struct HelpView: View {
  @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
  @State private var searchText = ""

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: language) ?? .system
  }

  private var filteredItems: [HelpItem] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return HelpItem.all }
    return HelpItem.all.filter {
      "\($0.question) \($0.answer)".localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .frame(width: 56, height: 56)
        VStack(alignment: .leading, spacing: 3) {
          Text(L10n.text("App Delta Help"))
            .font(.title.weight(.semibold))
          Text(L10n.text("Understand changes between two macOS app builds."))
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(22)

      Divider()

      if filteredItems.isEmpty {
        ContentUnavailableView.search(text: searchText)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(filteredItems) { item in
              DisclosureGroup {
                Text(item.answer)
                  .foregroundStyle(.secondary)
                  .textSelection(.enabled)
                  .padding(.top, 8)
              } label: {
                Text(item.question).fontWeight(.medium)
              }
              .padding(16)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
          }
          .padding(20)
        }
      }
    }
    .searchable(text: $searchText, prompt: Text(L10n.text("Search help")))
    .environment(\.locale, selectedLanguage.locale)
    .id(language)
  }
}

private struct HelpItem: Identifiable {
  let question: String
  let answer: String

  var id: String { question }

  static var all: [HelpItem] {
    [
      .init(
        question: L10n.text("What are Baseline and Candidate?"),
        answer: L10n.text(
          "Baseline is the previous or trusted state. Candidate is the new state you want to inspect. App Delta reports what changed from Baseline to Candidate."
        )),
      .init(
        question: L10n.text("How do I compare an app before and after its built-in update?"),
        answer: L10n.text(
          "Before updating, choose Prepare App Update and select the installed app. App Delta saves a compact analysis snapshot and keeps the same app path as Candidate. Run the app's update normally, return to App Delta, and compare. You can restore the snapshot later from Saved Baselines."
        )),
      .init(
        question: L10n.text("Is a saved baseline a backup of the application?"),
        answer: L10n.text(
          "No. It is an analysis snapshot used only for comparison. It cannot reinstall or restore the old application. To recover an old build, keep its DMG, use Time Machine, or download an older vendor release."
        )),
      .init(
        question: L10n.text("What if the app was already updated?"),
        answer: L10n.text(
          "App Delta cannot reconstruct files that were already replaced. Use a previous DMG, a vendor or GitHub release, or a Time Machine copy as Baseline. Prepare App Update before the next update."
        )),
      .init(
        question: L10n.text("Does App Delta launch apps or installer scripts?"),
        answer: L10n.text(
          "No. Selected apps are read as files. DMGs are attached read-only, and package scripts and payload executables are never run."
        )),
      .init(
        question: L10n.text("Are selected files uploaded?"),
        answer: L10n.text(
          "No. Analysis and saved baselines stay on this Mac. App Delta has no account, analytics SDK, upload service, or database."
        )),
      .init(
        question: L10n.text("Does a new capability prove the app used it?"),
        answer: L10n.text(
          "No. Entitlements, privacy descriptions, and manifests are declarations. App Delta explains observable metadata changes but does not claim runtime behavior or malicious intent."
        )),
      .init(
        question: L10n.text("Why can Gatekeeper results differ between Macs?"),
        answer: L10n.text(
          "Gatekeeper reflects the current Mac's trust policy, network availability, and cached notarization state. App Delta keeps accepted, rejected, and unavailable results separate."
        )),
      .init(
        question: L10n.text("Where are saved baselines stored?"),
        answer: L10n.text(
          "They are JSON analysis records in your user Library under Application Support/App Delta/Baselines. Delete them from Saved Baselines in the app."
        )),
      .init(
        question: L10n.text("How do I share a comparison?"),
        answer: L10n.text(
          "Export a self-contained HTML report for people to read or JSON for automation. Reports are generated locally and use the currently selected language."
        )),
    ]
  }
}
