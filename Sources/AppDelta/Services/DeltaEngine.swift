import Foundation

struct DeltaEngine: Sendable {
  func compare(before: AppSnapshot, after: AppSnapshot) -> DeltaReport {
    var items: [DeltaItem] = []

    compareScalar(
      "Application Name", before.identity.name, after.identity.name, category: .overview,
      items: &items)
    compareScalar(
      "Bundle Identifier", before.identity.bundleIdentifier, after.identity.bundleIdentifier,
      category: .overview, severity: .important, items: &items)
    compareScalar(
      "Version", before.identity.version, after.identity.version, category: .overview, items: &items
    )
    compareScalar(
      "Build", before.identity.build, after.identity.build, category: .overview, items: &items)
    compareScalar(
      "Minimum macOS", before.identity.minimumSystemVersion, after.identity.minimumSystemVersion,
      category: .overview, items: &items)
    compareScalar(
      "SDK", before.identity.sdkVersion, after.identity.sdkVersion, category: .overview,
      items: &items)
    compareScalar(
      "Bundle Size",
      ByteCountFormatter.string(fromByteCount: before.identity.bundleBytes, countStyle: .file),
      ByteCountFormatter.string(fromByteCount: after.identity.bundleBytes, countStyle: .file),
      category: .overview,
      items: &items
    )

    compareScalar(
      "Signature Verification", before.signing.signatureStatus, after.signing.signatureStatus,
      category: .signing, severity: .important, items: &items)
    compareScalar(
      "Signing Identifier", before.signing.identifier, after.signing.identifier, category: .signing,
      severity: .important, items: &items)
    compareScalar(
      "Team Identifier", before.signing.teamIdentifier, after.signing.teamIdentifier,
      category: .signing, severity: .important, items: &items)
    compareScalar(
      "Certificate Chain", before.signing.authorities.joined(separator: " → "),
      after.signing.authorities.joined(separator: " → "), category: .signing, severity: .important,
      items: &items)
    compareScalar(
      "Gatekeeper Assessment", before.signing.gatekeeperStatus, after.signing.gatekeeperStatus,
      category: .signing, severity: .important, items: &items)
    compareScalar(
      "Gatekeeper Diagnostic", before.signing.gatekeeperMessage,
      after.signing.gatekeeperMessage, category: .signing, items: &items)
    compareScalar(
      "Gatekeeper Source", before.signing.gatekeeperSource, after.signing.gatekeeperSource,
      category: .signing, items: &items)
    compareScalar(
      "Hardened Runtime", before.signing.hardenedRuntime, after.signing.hardenedRuntime,
      category: .signing, severity: .important, items: &items)
    compareScalar(
      "App Sandbox", before.signing.sandboxed, after.signing.sandboxed, category: .signing,
      severity: .important, items: &items)

    compareEntitlements(before.entitlements, after.entitlements, items: &items)
    compareDictionary(
      before.privacyUsageDescriptions, after.privacyUsageDescriptions, category: .privacy,
      titlePrefix: "Privacy declaration", addedSeverity: .attention, items: &items)
    comparePrivacyManifests(before.privacyManifests, after.privacyManifests, items: &items)
    compareSets(
      Set(before.urlSchemes), Set(after.urlSchemes), category: .capabilities, label: "URL scheme",
      addedSeverity: .attention, items: &items)

    let persistenceKinds: Set<AppSnapshot.Component.Kind> = [
      .loginItem, .launchAgent, .launchDaemon,
    ]
    compareComponents(
      before.components.filter { persistenceKinds.contains($0.kind) },
      after.components.filter { persistenceKinds.contains($0.kind) },
      category: .persistence,
      addedSeverity: .important,
      items: &items
    )
    compareComponents(
      before.components.filter { !persistenceKinds.contains($0.kind) },
      after.components.filter { !persistenceKinds.contains($0.kind) },
      category: .components,
      addedSeverity: .attention,
      items: &items
    )
    compareFiles(before.files, after.files, items: &items)

    items.sort {
      if $0.severity != $1.severity { return $0.severity > $1.severity }
      if $0.category != $1.category { return $0.category.rawValue < $1.category.rawValue }
      return $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
    return DeltaReport(before: before, after: after, items: items, generatedAt: Date())
  }

  private func compareEntitlements(
    _ before: [String: PlistValue],
    _ after: [String: PlistValue],
    items: inout [DeltaItem]
  ) {
    for key in Set(before.keys).union(after.keys).sorted() {
      let old = before[key]
      let new = after[key]
      guard old != new else { continue }
      let explanation = CapabilityCatalog.explanation(for: key)
      let kind = deltaKind(before: old, after: new)
      var severity = explanation.addedSeverity
      if key == "com.apple.security.app-sandbox", old == .bool(true), new != .bool(true) {
        severity = .important
      }
      items.append(
        .init(
          id: "entitlement:\(key)",
          category: .capabilities,
          kind: kind,
          severity: severity,
          title: explanation.title,
          detail: explanation.detail,
          evidencePath: "Code signature entitlements / \(key)",
          before: old?.description,
          after: new?.description
        ))
    }
  }

  private func compareDictionary(
    _ before: [String: String],
    _ after: [String: String],
    category: DeltaCategory,
    titlePrefix: String,
    addedSeverity: DeltaSeverity,
    items: inout [DeltaItem]
  ) {
    for key in Set(before.keys).union(after.keys).sorted() where before[key] != after[key] {
      items.append(
        .init(
          id: "\(category.rawValue):\(key)",
          category: category,
          kind: deltaKind(before: before[key], after: after[key]),
          severity: addedSeverity,
          title: "\(titlePrefix): \(key)",
          detail:
            "This is a declaration in Info.plist and does not prove the protected resource is used.",
          evidencePath: "Contents/Info.plist / \(key)",
          before: before[key],
          after: after[key]
        ))
    }
  }

  private func compareSets(
    _ before: Set<String>,
    _ after: Set<String>,
    category: DeltaCategory,
    label: String,
    addedSeverity: DeltaSeverity,
    items: inout [DeltaItem]
  ) {
    for value in after.subtracting(before).sorted() {
      items.append(
        .init(
          id: "\(category.rawValue):added:\(value)", category: category, kind: .added,
          severity: addedSeverity, title: "\(label): \(value)",
          detail: "The candidate declares this value.", evidencePath: nil, before: nil, after: value
        ))
    }
    for value in before.subtracting(after).sorted() {
      items.append(
        .init(
          id: "\(category.rawValue):removed:\(value)", category: category, kind: .removed,
          severity: .info, title: "\(label): \(value)",
          detail: "The candidate no longer declares this value.", evidencePath: nil, before: value,
          after: nil
        ))
    }
  }

  private func comparePrivacyManifests(
    _ before: [String: PlistValue],
    _ after: [String: PlistValue],
    items: inout [DeltaItem]
  ) {
    for path in Set(before.keys).union(after.keys).sorted() where before[path] != after[path] {
      items.append(
        .init(
          id: "privacy-manifest:\(path)",
          category: .privacy,
          kind: deltaKind(before: before[path], after: after[path]),
          severity: after[path] == nil ? .info : .attention,
          title: "Privacy manifest: \(path)",
          detail:
            "Declared required-reason APIs or collected-data metadata changed. This declaration is not evidence of runtime use.",
          evidencePath: path,
          before: before[path]?.description,
          after: after[path]?.description
        ))
    }
  }

  private func compareComponents(
    _ before: [AppSnapshot.Component],
    _ after: [AppSnapshot.Component],
    category: DeltaCategory,
    addedSeverity: DeltaSeverity,
    items: inout [DeltaItem]
  ) {
    let old = Dictionary(
      uniqueKeysWithValues: before.map { ("\($0.kind.rawValue):\($0.path)", $0) })
    let new = Dictionary(uniqueKeysWithValues: after.map { ("\($0.kind.rawValue):\($0.path)", $0) })
    for key in Set(old.keys).union(new.keys).sorted() where old[key] != new[key] {
      let oldValue = old[key]
      let newValue = new[key]
      let component = newValue ?? oldValue!
      items.append(
        .init(
          id: "component:\(key)", category: category,
          kind: deltaKind(before: oldValue, after: newValue),
          severity: newValue == nil ? .info : addedSeverity,
          title: component.path,
          detail:
            "\(component.kind.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized) component.",
          evidencePath: component.path,
          before: oldValue.map(componentDescription),
          after: newValue.map(componentDescription)
        ))
    }
  }

  private func compareFiles(
    _ before: [AppSnapshot.FileEntry], _ after: [AppSnapshot.FileEntry], items: inout [DeltaItem]
  ) {
    let old = Dictionary(uniqueKeysWithValues: before.map { ($0.path, $0) })
    let new = Dictionary(uniqueKeysWithValues: after.map { ($0.path, $0) })
    for path in Set(old.keys).union(new.keys).sorted() where old[path] != new[path] {
      let oldValue = old[path]
      let newValue = new[path]
      items.append(
        .init(
          id: "file:\(path)", category: .files,
          kind: deltaKind(before: oldValue, after: newValue),
          severity: .info, title: path,
          detail: "File inventory metadata changed. Timestamps are intentionally ignored.",
          evidencePath: path,
          before: oldValue.map(fileDescription),
          after: newValue.map(fileDescription)
        ))
    }
  }

  private func compareScalar<T: Equatable>(
    _ title: String,
    _ before: T?,
    _ after: T?,
    category: DeltaCategory,
    severity: DeltaSeverity = .info,
    items: inout [DeltaItem]
  ) {
    guard before != after else { return }
    items.append(
      .init(
        id: "scalar:\(category.rawValue):\(title)", category: category,
        kind: deltaKind(before: before, after: after), severity: severity,
        title: title, detail: "Observable metadata changed between the selected artifacts.",
        evidencePath: nil, before: before.map(String.init(describing:)),
        after: after.map(String.init(describing:))
      ))
  }

  private func deltaKind<T>(before: T?, after: T?) -> DeltaKind {
    switch (before, after) {
    case (nil, .some): .added
    case (.some, nil): .removed
    default: .changed
    }
  }

  private func componentDescription(_ value: AppSnapshot.Component) -> String {
    value.bytes.map {
      "\(value.kind.rawValue), \(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file))"
    } ?? value.kind.rawValue
  }

  private func fileDescription(_ value: AppSnapshot.FileEntry) -> String {
    let size =
      value.bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
    let digest = value.contentSHA256.map { ", SHA-256 \($0.prefix(12))…" } ?? ""
    return "\(value.type.rawValue), \(size)\(value.executable ? ", executable" : "")\(digest)"
  }
}
