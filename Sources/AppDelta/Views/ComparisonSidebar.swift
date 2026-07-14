import SwiftUI

struct ComparisonSidebar: View {
  @ObservedObject var store: ComparisonStore

  var body: some View {
    List(selection: $store.selectedCategory) {
      Section("Report") {
        ForEach(DeltaCategory.allCases) { category in
          HStack(spacing: 10) {
            Image(systemName: category.systemImage)
              .foregroundStyle(.secondary)
              .frame(width: 16)
            Text(category.title)
            Spacer()
            Text(count(for: category).formatted())
              .font(.caption.monospacedDigit())
              .foregroundStyle(.tertiary)
          }
          .tag(category)
        }
      }

      if let report = store.report {
        Section("Artifacts") {
          ArtifactSidebarRow(label: "Baseline", snapshot: report.before)
          ArtifactSidebarRow(label: "Candidate", snapshot: report.after)
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("App Delta")
  }

  private func count(for category: DeltaCategory) -> Int {
    if category == .overview { return store.report?.changedItems.count ?? 0 }
    return store.report?.count(for: category) ?? 0
  }
}

private struct ArtifactSidebarRow: View {
  let label: String
  let snapshot: AppSnapshot

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: "app")
        .foregroundStyle(.secondary)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        Text("\(snapshot.identity.name) \(snapshot.identity.version)")
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
