import SwiftUI

struct ComparisonDetailView: View {
  @ObservedObject var store: ComparisonStore

  var body: some View {
    VStack(spacing: 0) {
      if let report = store.report {
        ComparisonHeader(report: report)
        Divider()
        if store.selectedCategory == .overview {
          OverviewSummary(
            report: report, items: store.items(for: .overview), selection: $store.selectedItemID)
        } else {
          DiffTable(
            items: store.items(for: store.selectedCategory), selection: $store.selectedItemID)
        }
      }
    }
    .navigationTitle(store.selectedCategory.title)
  }
}

private struct ComparisonHeader: View {
  let report: DeltaReport

  var body: some View {
    HStack(spacing: 16) {
      ArtifactIdentityView(label: "BASELINE", snapshot: report.before, alignment: .leading)
      Image(systemName: "arrow.right")
        .font(.title3)
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
      ArtifactIdentityView(label: "CANDIDATE", snapshot: report.after, alignment: .trailing)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }
}

private struct ArtifactIdentityView: View {
  let label: String
  let snapshot: AppSnapshot
  let alignment: HorizontalAlignment

  private var frameAlignment: Alignment {
    label == "BASELINE" ? .leading : .trailing
  }

  var body: some View {
    VStack(alignment: alignment, spacing: 3) {
      Text(L10n.text(label)).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
      Text("\(snapshot.identity.name) \(L10n.text(snapshot.identity.version))")
        .font(.headline)
        .lineLimit(1)
      Text(L10n.text(snapshot.identity.bundleIdentifier))
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: frameAlignment)
  }
}

private struct OverviewSummary: View {
  let report: DeltaReport
  let items: [DeltaItem]
  @Binding var selection: DeltaItem.ID?

  private var warnings: [String] {
    Array(Set(report.before.warnings + report.after.warnings)).sorted()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          MetricCard(
            title: L10n.text("Observable changes"), value: items.count,
            icon: "rectangle.2.swap")
          MetricCard(
            title: L10n.text("Added"), value: items.filter { $0.kind == .added }.count,
            icon: "plus.circle")
          MetricCard(
            title: L10n.text("Important"), value: items.filter { $0.severity == .important }.count,
            icon: "exclamationmark.shield")
        }

        InterpretationNotice()

        if !warnings.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("Analysis notes"), systemImage: "info.circle")
              .font(.headline)
            ForEach(warnings, id: \.self) { warning in
              Text("• \(warning)").foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }

        Text(L10n.text("All changes")).font(.headline)
        DiffList(items: items, selection: $selection)
      }
      .padding(20)
    }
  }
}

private struct MetricCard: View {
  let title: String
  let value: Int
  let icon: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.title2).foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text(value.formatted()).font(.title2.weight(.semibold)).monospacedDigit()
        Text(title).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(14)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct InterpretationNotice: View {
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "shield.lefthalf.filled").foregroundStyle(.orange)
      Text(
        L10n.text(
          "App Delta does not determine whether an app is safe or malicious. It reports observable changes in signing, declared capabilities, bundled components, package contents, and files."
        )
      )
      .font(.callout)
      Spacer()
    }
    .padding(14)
    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct DiffTable: View {
  let items: [DeltaItem]
  @Binding var selection: DeltaItem.ID?

  var body: some View {
    if items.isEmpty {
      ContentUnavailableView(
        L10n.text("No matching changes"), systemImage: "checkmark.circle",
        description: Text(L10n.text("Adjust the category, search, or severity filter.")))
    } else {
      Table(items, selection: $selection) {
        TableColumn(L10n.text("Change")) { item in
          Label(item.kind.label, systemImage: item.kind.systemImage)
            .foregroundStyle(item.kind.color)
        }
        .width(min: 92, ideal: 110)

        TableColumn(L10n.text("Item")) { item in
          VStack(alignment: .leading, spacing: 2) {
            Text(item.title).lineLimit(1)
            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        .width(min: 220, ideal: 340)

        TableColumn(L10n.text("Baseline")) { item in
          Text(item.before ?? "—").lineLimit(2).textSelection(.enabled)
        }
        .width(min: 130, ideal: 220)

        TableColumn(L10n.text("Candidate")) { item in
          Text(item.after ?? "—").lineLimit(2).textSelection(.enabled)
        }
        .width(min: 130, ideal: 220)
      }
    }
  }
}

private struct DiffList: View {
  let items: [DeltaItem]
  @Binding var selection: DeltaItem.ID?

  var body: some View {
    LazyVStack(spacing: 0) {
      ForEach(items) { item in
        Button {
          selection = item.id
        } label: {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.systemImage)
              .foregroundStyle(item.kind.color)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
              Text(item.title).fontWeight(.medium).foregroundStyle(.primary)
              Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(item.category.title).font(.caption).foregroundStyle(.tertiary)
          }
          .padding(.vertical, 10)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider()
      }
    }
  }
}
