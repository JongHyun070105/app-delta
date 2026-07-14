import SwiftUI

struct BaselineLibraryView: View {
  @ObservedObject var store: ComparisonStore
  @Environment(\.dismiss) private var dismiss
  @State private var pendingDeletion: SavedBaselineSummary?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(L10n.text("Saved Baselines"))
          .font(.title2.weight(.semibold))
        Text(
          L10n.text(
            "These are analysis snapshots, not copies of the original applications."
          )
        )
        .foregroundStyle(.secondary)
      }

      if store.savedBaselines.isEmpty {
        ContentUnavailableView(
          L10n.text("No saved baselines"), systemImage: "archivebox",
          description: Text(L10n.text("Prepare an app before updating to save its current state."))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(store.savedBaselines) { record in
          HStack(spacing: 12) {
            Image(systemName: "app.badge.checkmark")
              .font(.title2)
              .foregroundStyle(.tint)
              .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
              Text(record.displayName).fontWeight(.medium)
              Text(
                L10n.format(
                  "%@ · saved %@", record.versionLabel,
                  record.createdAt.formatted(date: .abbreviated, time: .shortened))
              )
              .font(.caption)
              .foregroundStyle(.secondary)
              Text(record.originalApplicationURL.path)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
            Spacer()
            Button(L10n.text("Use")) {
              store.selectSavedBaseline(record)
              dismiss()
            }
            .buttonStyle(.borderedProminent)
            Button {
              pendingDeletion = record
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(L10n.text("Delete saved baseline"))
          }
          .padding(.vertical, 5)
        }
      }

      HStack {
        Text(L10n.text("Stored only on this Mac."))
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button(L10n.text("Done")) { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 680, height: 440)
    .alert(
      L10n.text("Delete this saved baseline?"),
      isPresented: Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      ),
      presenting: pendingDeletion
    ) { record in
      Button(L10n.text("Delete"), role: .destructive) {
        store.deleteSavedBaseline(record)
        pendingDeletion = nil
      }
      Button(L10n.text("Cancel"), role: .cancel) { pendingDeletion = nil }
    } message: { record in
      Text(L10n.format("The saved analysis for %@ will be removed.", record.displayName))
    }
  }
}
