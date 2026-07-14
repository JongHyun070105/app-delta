import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SourcePickerView: View {
  @ObservedObject var store: ComparisonStore
  @State private var showsBaselineLibrary = false

  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 20)

      VStack(spacing: 9) {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .frame(width: 72, height: 72)
          .accessibilityHidden(true)
        Text(L10n.text("See what changed inside a Mac app"))
          .font(.largeTitle.weight(.semibold))
        Text(
          L10n.text(
            "Compare signatures, declared capabilities, privacy descriptions, background helpers, embedded components, and files — entirely on this Mac."
          )
        )
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 720)
      }

      HStack(spacing: 16) {
        ArtifactDropCard(
          title: L10n.text("Baseline"),
          subtitle: L10n.text("Previous or trusted version"),
          artifact: store.baseline,
          savedBaseline: store.savedBaseline,
          choose: { store.chooseArtifact(for: .baseline) },
          clear: { store.clear(.baseline) },
          receive: { store.setArtifact(url: $0, for: .baseline) }
        )

        Image(systemName: "arrow.right")
          .font(.title2)
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)

        ArtifactDropCard(
          title: L10n.text("Candidate"),
          subtitle: L10n.text("New version to inspect"),
          artifact: store.candidate,
          savedBaseline: nil,
          choose: { store.chooseArtifact(for: .candidate) },
          clear: { store.clear(.candidate) },
          receive: { store.setArtifact(url: $0, for: .candidate) }
        )
      }
      .frame(maxWidth: 900)

      HStack(spacing: 12) {
        Button {
          store.chooseApplicationToPreserve()
        } label: {
          Label(L10n.text("Prepare App Update…"), systemImage: "archivebox")
        }

        Button {
          showsBaselineLibrary = true
        } label: {
          Label(L10n.text("Saved Baselines…"), systemImage: "clock.arrow.circlepath")
        }
        .disabled(store.savedBaselines.isEmpty)
      }

      if let record = store.savedBaseline {
        Label(
          L10n.format(
            "%@ %@ is saved as the baseline. Update the app, then compare its current version.",
            record.displayName, record.versionLabel),
          systemImage: "checkmark.seal.fill"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }

      VStack(spacing: 12) {
        Button {
          store.analyze()
        } label: {
          Label(L10n.text("Compare Artifacts"), systemImage: "rectangle.2.swap")
            .frame(minWidth: 160)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!store.canAnalyze)

        Label(
          L10n.text("Selected apps are inspected, never launched or uploaded."),
          systemImage: "lock.shield"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 20)
    }
    .padding(36)
    .sheet(isPresented: $showsBaselineLibrary) {
      BaselineLibraryView(store: store)
    }
  }
}

private struct ArtifactDropCard: View {
  let title: String
  let subtitle: String
  let artifact: SelectedArtifact?
  let savedBaseline: SavedBaseline?
  let choose: () -> Void
  let clear: () -> Void
  let receive: (URL) -> Void
  @State private var isTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline)
          Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if artifact != nil || savedBaseline != nil {
          Button(L10n.text("Clear"), action: clear)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
      }

      if let savedBaseline {
        HStack(spacing: 14) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 28))
            .foregroundStyle(.tint)
            .frame(width: 46, height: 46)
            .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 4) {
            Text(savedBaseline.displayName).fontWeight(.medium).lineLimit(1)
            Text(
              L10n.format("Saved baseline · %@", savedBaseline.versionLabel)
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .accessibilityElement(children: .combine)
      } else if let artifact {
        HStack(spacing: 14) {
          Image(systemName: icon(for: artifact.kind))
            .font(.system(size: 28))
            .foregroundStyle(.tint)
            .frame(width: 46, height: 46)
            .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 4) {
            Text(artifact.displayName).fontWeight(.medium).lineLimit(1)
            Text(artifact.kind.label).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
        }
        .accessibilityElement(children: .combine)
      } else {
        VStack(spacing: 8) {
          Image(systemName: "arrow.down.doc")
            .font(.system(size: 27))
            .foregroundStyle(.secondary)
          Text(L10n.text("Drop .app, .dmg, or .pkg"))
            .fontWeight(.medium)
          Text(L10n.text("or choose a local artifact"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
      }

      Button(L10n.text(artifact == nil ? "Choose…" : "Replace…"), action: choose)
        .frame(maxWidth: .infinity)
    }
    .padding(18)
    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
          lineWidth: isTargeted ? 2 : 1)
    }
    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
      guard let provider = providers.first else { return false }
      provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
        guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
        DispatchQueue.main.async { receive(url) }
      }
      return true
    }
    .accessibilityLabel(L10n.format("%@ artifact", title))
  }

  private func icon(for kind: ArtifactKind) -> String {
    switch kind {
    case .application: "app"
    case .diskImage: "externaldrive"
    case .installerPackage: "shippingbox"
    }
  }
}
