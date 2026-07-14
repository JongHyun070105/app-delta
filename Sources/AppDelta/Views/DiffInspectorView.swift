import SwiftUI

struct DiffInspectorView: View {
  let item: DeltaItem?

  var body: some View {
    if let item {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Label(item.kind.label, systemImage: item.kind.systemImage)
            .font(.headline)
            .foregroundStyle(item.kind.color)

          VStack(alignment: .leading, spacing: 5) {
            Text(item.title).font(.title3.weight(.semibold)).textSelection(.enabled)
            Text(item.detail).foregroundStyle(.secondary).textSelection(.enabled)
          }

          InspectorValue(title: "Baseline", value: item.before)
          InspectorValue(title: "Candidate", value: item.after)

          if let path = item.evidencePath {
            InspectorValue(title: "Evidence", value: path)
          }

          Divider()
          Text(
            "This report describes observable metadata and declarations. It does not establish runtime behavior or intent."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(18)
      }
    } else {
      ContentUnavailableView(
        "Select a change", systemImage: "sidebar.right",
        description: Text("Detailed values and evidence appear here."))
    }
  }
}

private struct InspectorValue: View {
  let title: String
  let value: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
      Text(value ?? "Not present")
        .font(.callout.monospaced())
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
  }
}
