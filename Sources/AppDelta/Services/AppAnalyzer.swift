import CryptoKit
import Foundation

protocol ArtifactAnalyzing: Sendable {
  func analyze(_ artifact: SelectedArtifact, budget: ScanBudget) throws -> AppSnapshot
}

extension ArtifactAnalyzing {
  func analyze(_ artifact: SelectedArtifact) throws -> AppSnapshot {
    try analyze(artifact, budget: .default)
  }
}

struct AppAnalyzer: @unchecked Sendable {
  let commandRunner: any CommandRunning
  let fileManager: FileManager
  let resolver: ArtifactResolver

  init(
    commandRunner: any CommandRunning = BoundedCommandRunner(), fileManager: FileManager = .default
  ) {
    self.commandRunner = commandRunner
    self.fileManager = fileManager
    self.resolver = ArtifactResolver(commandRunner: commandRunner, fileManager: fileManager)
  }

  func analyze(_ artifact: SelectedArtifact, budget: ScanBudget = .default) throws -> AppSnapshot {
    try Task.checkCancellation()
    if artifact.kind == .installerPackage {
      return try analyzePackage(artifact, budget: budget)
    }

    let lease = try resolver.resolveApplication(from: artifact, budget: budget)
    defer { lease.cleanup() }
    try Task.checkCancellation()
    var snapshot = try analyzeApplication(
      at: lease.applicationURL,
      sourceName: artifact.displayName,
      sourceKind: artifact.kind,
      budget: budget
    )
    snapshot.warnings.append(contentsOf: lease.warnings)
    return snapshot
  }

  private func analyzeApplication(
    at appURL: URL,
    sourceName: String,
    sourceKind: ArtifactKind,
    budget: ScanBudget
  ) throws -> AppSnapshot {
    let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
    let info = try readPropertyListDictionary(at: infoURL, budget: budget)
    let inventory = try inventoryBundle(at: appURL, budget: budget)
    let privacyManifests = try inspectPrivacyManifests(
      at: appURL, files: inventory.files, budget: budget)
    let signing = try inspectSigning(at: appURL, budget: budget)
    let entitlements = try inspectEntitlements(at: appURL, budget: budget)
    let privacy = info.reduce(into: [String: String]()) { result, entry in
      guard isPrivacyUsageKey(entry.key), let value = entry.value as? String else { return }
      result[entry.key] = value
    }

    return AppSnapshot(
      sourceName: sourceName,
      sourceKind: sourceKind,
      identity: .init(
        name: string(info["CFBundleDisplayName"]) ?? string(info["CFBundleName"])
          ?? appURL.deletingPathExtension().lastPathComponent,
        bundleIdentifier: string(info["CFBundleIdentifier"]) ?? "unknown.bundle.identifier",
        version: string(info["CFBundleShortVersionString"]) ?? L10n.text("Unknown"),
        build: string(info["CFBundleVersion"]) ?? L10n.text("Unknown"),
        minimumSystemVersion: string(info["LSMinimumSystemVersion"]),
        sdkVersion: string(info["DTSDKName"]) ?? string(info["DTPlatformVersion"]),
        executableName: string(info["CFBundleExecutable"]),
        bundleBytes: inventory.totalBytes
      ),
      signing: signing.withSandbox(entitlements["com.apple.security.app-sandbox"] == .bool(true)),
      entitlements: entitlements,
      privacyUsageDescriptions: privacy,
      privacyManifests: privacyManifests.values,
      urlSchemes: extractURLSchemes(info),
      components: inventory.components,
      files: inventory.files,
      warnings: inventory.warnings + privacyManifests.warnings,
      analyzedAt: Date()
    )
  }

  private func analyzePackage(_ artifact: SelectedArtifact, budget: ScanBudget) throws
    -> AppSnapshot
  {
    let source = artifact.url.standardizedFileURL
    guard source.path.hasPrefix("/"), fileManager.isReadableFile(atPath: source.path) else {
      throw AnalysisError.unreadableArtifact(source.lastPathComponent)
    }

    let packageMetadata = try inspectPackageMetadata(at: source, budget: budget)
    let signature = try commandRunner.run(
      .pkgutil, arguments: ["--check-signature", source.path], budget: budget)
    let gatekeeper = try commandRunner.run(
      .spctl,
      arguments: ["--assess", "--type", "install", "--verbose=4", source.path],
      budget: budget
    )
    let payload = try commandRunner.run(
      .pkgutil, arguments: ["--payload-files", source.path], budget: budget)
    guard payload.status == 0 else {
      throw AnalysisError.commandFailed(tool: "pkgutil", message: concise(payload.combinedString))
    }

    let rawPaths = payload.outputString.split(whereSeparator: \.isNewline).map(String.init)
    var warnings =
      packageMetadata.warnings + [
        L10n.text(
          "Installer packages are compared from signed package metadata and payload paths. Package scripts and payload executables are never run."
        )
      ]
    var safePaths: [String] = []
    for path in rawPaths.prefix(budget.maximumEntries) {
      try Task.checkCancellation()
      let normalized = path.replacingOccurrences(of: "\\", with: "/")
      guard !normalized.hasPrefix("/"), !normalized.split(separator: "/").contains(".."),
        !normalized.contains("\0")
      else {
        warnings.append(
          L10n.text(
            "A package payload path was rejected because it could escape the package root."))
        continue
      }
      safePaths.append(normalized)
    }
    if rawPaths.count > budget.maximumEntries {
      warnings.append(
        L10n.format(
          "The package payload list was truncated at %@ entries.",
          budget.maximumEntries.formatted()))
    }

    let fileSize =
      (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    let appPath = safePaths.first {
      $0.lowercased().contains(".app/") || $0.lowercased().hasSuffix(".app")
    }
    let inferredName =
      appPath.flatMap { path -> String? in
        path.split(separator: "/").first(where: { $0.lowercased().hasSuffix(".app") }).map(
          String.init)
      }?.replacingOccurrences(of: ".app", with: "")
      ?? source.deletingPathExtension().lastPathComponent

    let components = Array(Set(safePaths.compactMap { packageComponent(for: $0) })).sorted {
      $0.path < $1.path
    }
    let files = safePaths.map {
      AppSnapshot.FileEntry(
        path: $0, type: .regular, bytes: nil, executable: isLikelyExecutablePath($0))
    }

    return AppSnapshot(
      sourceName: artifact.displayName,
      sourceKind: .installerPackage,
      identity: .init(
        name: inferredName,
        bundleIdentifier: packageMetadata.identifier ?? L10n.text("Unavailable"),
        version: packageMetadata.version ?? L10n.text("Unavailable"),
        build: L10n.text("Not applicable"),
        minimumSystemVersion: nil,
        sdkVersion: nil,
        executableName: nil,
        bundleBytes: fileSize
      ),
      signing: .init(
        identifier: nil,
        teamIdentifier: parseValue("Team Identifier", in: signature.combinedString),
        authorities: signature.combinedString.split(whereSeparator: \.isNewline)
          .map(String.init)
          .filter { $0.contains("Developer ID Installer") || $0.contains("Authority") },
        cdHash: nil,
        signedTime: nil,
        format: L10n.text("Installer package"),
        signatureStatus: verificationState(for: signature, rejectedStatuses: [1]),
        signatureMessage: diagnostic(signature.combinedString, artifactURL: source),
        gatekeeperStatus: verificationState(for: gatekeeper, rejectedStatuses: [3]),
        gatekeeperMessage: diagnostic(gatekeeper.combinedString, artifactURL: source),
        gatekeeperSource: parseGatekeeperSource(gatekeeper.combinedString),
        hardenedRuntime: false,
        sandboxed: false
      ),
      entitlements: [:],
      privacyUsageDescriptions: [:],
      urlSchemes: [],
      components: components,
      files: files,
      warnings: warnings,
      analyzedAt: Date()
    )
  }

  private func inspectSigning(at appURL: URL, budget: ScanBudget) throws -> AppSnapshot.Signing {
    let verify = try commandRunner.run(
      .codesign,
      arguments: ["--verify", "--deep", "--strict", "--verbose=2", appURL.path],
      budget: budget
    )
    let details = try commandRunner.run(
      .codesign,
      arguments: ["--display", "--verbose=4", appURL.path],
      budget: budget
    )
    let gatekeeper = try commandRunner.run(
      .spctl,
      arguments: ["--assess", "--type", "execute", "--verbose=4", appURL.path],
      budget: budget
    )
    let text = details.combinedString
    let flags = parseValue("flags", in: text) ?? ""

    return .init(
      identifier: parseValue("Identifier", in: text),
      teamIdentifier: parseValue("TeamIdentifier", in: text).flatMap { $0 == "not set" ? nil : $0 },
      authorities: text.split(whereSeparator: \.isNewline)
        .map(String.init)
        .compactMap { line in
          line.hasPrefix("Authority=") ? String(line.dropFirst("Authority=".count)) : nil
        },
      cdHash: parseValue("CDHash", in: text),
      signedTime: parseValue("Signed Time", in: text),
      format: parseValue("Format", in: text),
      signatureStatus: verificationState(for: verify, rejectedStatuses: [1]),
      signatureMessage: diagnostic(
        verify.combinedString.isEmpty ? L10n.text("Signature verified.") : verify.combinedString,
        artifactURL: appURL),
      gatekeeperStatus: verificationState(for: gatekeeper, rejectedStatuses: [3]),
      gatekeeperMessage: diagnostic(gatekeeper.combinedString, artifactURL: appURL),
      gatekeeperSource: parseGatekeeperSource(gatekeeper.combinedString),
      hardenedRuntime: flags.contains("runtime"),
      sandboxed: false
    )
  }

  private func inspectPackageMetadata(at source: URL, budget: ScanBudget) throws -> (
    identifier: String?, version: String?, warnings: [String]
  ) {
    let listing = try commandRunner.run(.xar, arguments: ["-tf", source.path], budget: budget)
    guard listing.status == 0 else {
      return (
        nil, nil,
        [
          L10n.text(
            "Package identifier and version were unavailable because its metadata archive could not be listed."
          )
        ]
      )
    }

    let availableEntries = Set(
      listing.outputString.split(whereSeparator: \.isNewline).map(String.init))
    let selectedEntries = ["PackageInfo", "Distribution"].filter(availableEntries.contains)
    guard !selectedEntries.isEmpty else {
      return (
        nil, nil,
        [L10n.text("Package identifier and version were not present in root package metadata.")]
      )
    }

    var identifier: String?
    var version: String?
    var warnings: [String] = []
    for entry in selectedEntries {
      try Task.checkCancellation()
      let extraction = try commandRunner.run(
        .tar,
        arguments: ["-xOf", source.path, entry],
        budget: budget
      )
      guard extraction.status == 0 else {
        warnings.append(L10n.format("Package metadata entry %@ could not be read.", entry))
        continue
      }
      guard extraction.standardOutput.count <= budget.maximumPlistBytes else {
        warnings.append(L10n.format("Package metadata entry %@ exceeded the size limit.", entry))
        continue
      }

      let data = extraction.standardOutput
      let parserDelegate = PackageMetadataXMLDelegate()
      let parser = XMLParser(data: data)
      parser.delegate = parserDelegate
      if parser.parse() {
        identifier = identifier ?? parserDelegate.identifier
        version = version ?? parserDelegate.version
      } else {
        warnings.append(L10n.format("Package metadata entry %@ was malformed XML.", entry))
      }
    }
    if identifier == nil || version == nil {
      warnings.append(L10n.text("Some package identity fields were unavailable."))
    }
    return (identifier, version, warnings)
  }

  private func inspectEntitlements(at appURL: URL, budget: ScanBudget) throws -> [String:
    PlistValue]
  {
    let result = try commandRunner.run(
      .codesign,
      arguments: ["--display", "--entitlements", "-", "--xml", appURL.path],
      budget: budget
    )
    guard result.status == 0, !result.standardOutput.isEmpty else { return [:] }
    guard
      let dictionary = try PropertyListSerialization.propertyList(
        from: result.standardOutput,
        options: [],
        format: nil
      ) as? [String: Any]
    else {
      throw AnalysisError.malformedPropertyList("code-signing entitlements")
    }
    return dictionary.mapValues { PlistValue.convert($0) }
  }

  private func readPropertyListDictionary(at url: URL, budget: ScanBudget) throws -> [String: Any] {
    let values = try url.resourceValues(forKeys: [
      .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey,
    ])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw AnalysisError.unsafePath(url.path)
    }
    guard let size = values.fileSize, size <= budget.maximumPlistBytes else {
      throw AnalysisError.scanLimitReached("property list size")
    }
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard
      let result = try PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    else {
      throw AnalysisError.malformedPropertyList(url.lastPathComponent)
    }
    return result
  }

  private func inventoryBundle(at root: URL, budget: ScanBudget) throws -> (
    files: [AppSnapshot.FileEntry],
    components: [AppSnapshot.Component],
    totalBytes: Int64,
    warnings: [String]
  ) {
    let keys: Set<URLResourceKey> = [
      .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
    ]
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles]
      )
    else {
      throw AnalysisError.unreadableArtifact(root.lastPathComponent)
    }

    let canonicalRoot = root.standardizedFileURL.path + "/"
    var files: [AppSnapshot.FileEntry] = []
    var components = Set<AppSnapshot.Component>()
    var totalBytes: Int64 = 0
    var warnings: [String] = []
    var count = 0
    var hashedBytes: Int64 = 0
    var hashIncomplete = false
    var reportedDepthLimit = false

    while let url = enumerator.nextObject() as? URL {
      try Task.checkCancellation()
      count += 1
      if count > budget.maximumEntries {
        warnings.append(
          L10n.format(
            "The file inventory was truncated at %@ entries.",
            budget.maximumEntries.formatted()))
        break
      }
      guard url.standardizedFileURL.path.hasPrefix(canonicalRoot) else {
        enumerator.skipDescendants()
        warnings.append(L10n.text("A path outside the application bundle was ignored."))
        continue
      }

      let values = try? url.resourceValues(forKeys: keys)
      let relative = String(url.standardizedFileURL.path.dropFirst(canonicalRoot.count))
      if relative.split(separator: "/").count > budget.maximumDepth {
        enumerator.skipDescendants()
        if !reportedDepthLimit {
          warnings.append(
            L10n.format(
              "Paths deeper than %@ components were skipped.",
              budget.maximumDepth.formatted()))
          reportedDepthLimit = true
        }
        continue
      }
      let isSymlink = values?.isSymbolicLink == true
      if isSymlink { enumerator.skipDescendants() }

      let type: AppSnapshot.FileEntry.EntryType
      if isSymlink {
        type = .symbolicLink
      } else if values?.isRegularFile == true {
        type = .regular
      } else if values?.isDirectory == true {
        type = .directory
      } else {
        type = .other
      }

      let bytes = values?.isRegularFile == true ? values?.fileSize.map(Int64.init) : nil
      if let bytes {
        let (sum, overflow) = totalBytes.addingReportingOverflow(bytes)
        totalBytes = overflow ? Int64.max : sum
      }
      let executable = !isSymlink && fileManager.isExecutableFile(atPath: url.path)
      var contentSHA256: String?
      if type == .regular, let bytes {
        let remaining = max(0, budget.maximumHashedBytes - hashedBytes)
        if bytes <= remaining {
          do {
            contentSHA256 = try hashFile(at: url)
            hashedBytes += bytes
          } catch is CancellationError {
            throw CancellationError()
          } catch {
            hashIncomplete = true
          }
        } else {
          hashIncomplete = true
        }
      }
      files.append(
        .init(
          path: relative,
          type: type,
          bytes: bytes,
          executable: executable,
          contentSHA256: contentSHA256
        ))
      if let component = component(for: relative, bytes: bytes, executable: executable) {
        components.insert(component)
      }
    }

    if hashIncomplete {
      let formattedBudget = ByteCountFormatter.string(
        fromByteCount: budget.maximumHashedBytes, countStyle: .file)
      warnings.append(
        L10n.format(
          "Some file content hashes were unavailable or exceeded the %@ safety budget. Those files are compared by metadata only.",
          formattedBudget))
    }

    return (
      files.sorted { $0.path < $1.path },
      components.sorted { $0.path < $1.path },
      totalBytes,
      warnings
    )
  }

  private func component(for path: String, bytes: Int64?, executable: Bool) -> AppSnapshot
    .Component?
  {
    let lower = path.lowercased()
    if lower.contains("contents/library/loginitems/"),
      let root = componentRoot(in: path, suffix: ".app")
    {
      return .init(path: root, kind: .loginItem, bytes: nil)
    }
    if lower.contains("contents/library/launchagents/"), lower.hasSuffix(".plist") {
      return .init(path: path, kind: .launchAgent, bytes: bytes)
    }
    if lower.contains("contents/library/launchdaemons/"), lower.hasSuffix(".plist") {
      return .init(path: path, kind: .launchDaemon, bytes: bytes)
    }
    if lower.contains("contents/xpcservices/"), let root = componentRoot(in: path, suffix: ".xpc") {
      return .init(path: root, kind: .xpcService, bytes: nil)
    }
    if lower.contains("contents/plugins/"), let root = componentRoot(in: path, suffix: ".appex") {
      return .init(path: root, kind: .appExtension, bytes: nil)
    }
    if lower.contains("contents/plugins/"), let root = componentRoot(in: path, suffix: ".bundle") {
      return .init(path: root, kind: .plugin, bytes: nil)
    }
    if lower.contains("contents/frameworks/"),
      let root = componentRoot(in: path, suffix: ".framework")
    {
      return .init(path: root, kind: .framework, bytes: nil)
    }
    if lower.hasSuffix(".dylib") {
      return .init(path: path, kind: .library, bytes: bytes)
    }
    if let root = componentRoot(in: path, suffix: ".app") {
      return .init(path: root, kind: .nestedApplication, bytes: nil)
    }
    if executable, lower.contains("contents/macos/") {
      return .init(path: path, kind: .executable, bytes: bytes)
    }
    return nil
  }

  private func packageComponent(for path: String) -> AppSnapshot.Component? {
    let lower = path.lowercased()
    if lower.contains("library/launchagents/"), lower.hasSuffix(".plist") {
      return .init(path: path, kind: .launchAgent, bytes: nil)
    }
    if lower.contains("library/launchdaemons/"), lower.hasSuffix(".plist") {
      return .init(path: path, kind: .launchDaemon, bytes: nil)
    }
    if lower.contains("library/privilegedhelpertools/") {
      return .init(path: path, kind: .executable, bytes: nil)
    }
    if let root = componentRoot(in: path, suffix: ".framework") {
      return .init(path: root, kind: .framework, bytes: nil)
    }
    if let root = componentRoot(in: path, suffix: ".xpc") {
      return .init(path: root, kind: .xpcService, bytes: nil)
    }
    if let root = componentRoot(in: path, suffix: ".appex") {
      return .init(path: root, kind: .appExtension, bytes: nil)
    }
    if let root = componentRoot(in: path, suffix: ".app") {
      return .init(path: root, kind: .nestedApplication, bytes: nil)
    }
    if isLikelyExecutablePath(path) { return .init(path: path, kind: .executable, bytes: nil) }
    return nil
  }

  private func componentRoot(in path: String, suffix: String) -> String? {
    let components = path.split(separator: "/", omittingEmptySubsequences: true)
    guard let index = components.firstIndex(where: { $0.lowercased().hasSuffix(suffix) }) else {
      return nil
    }
    return components[...index].joined(separator: "/")
  }

  private func hashFile(at url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
      try Task.checkCancellation()
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private func inspectPrivacyManifests(
    at root: URL,
    files: [AppSnapshot.FileEntry],
    budget: ScanBudget
  ) throws -> (values: [String: PlistValue], warnings: [String]) {
    var values: [String: PlistValue] = [:]
    var warnings: [String] = []
    for file in files where file.type == .regular && file.path.lowercased().hasSuffix(".xcprivacy")
    {
      try Task.checkCancellation()
      let manifestURL = root.appendingPathComponent(file.path)
      do {
        let dictionary = try readPropertyListDictionary(at: manifestURL, budget: budget)
        values[file.path] = .dictionary(dictionary.mapValues { PlistValue.convert($0) })
      } catch {
        warnings.append(
          L10n.format(
            "Privacy manifest %@ could not be parsed: %@", file.path, error.localizedDescription))
      }
    }
    return (values, warnings)
  }

  private func isLikelyExecutablePath(_ path: String) -> Bool {
    let lower = path.lowercased()
    return lower.hasPrefix("usr/local/bin/") || lower.contains("/contents/macos/")
      || lower.contains("privilegedhelpertools/")
  }

  private func isPrivacyUsageKey(_ key: String) -> Bool {
    key.hasSuffix("UsageDescription")
      || [
        "NSSystemAdministrationUsageDescription",
        "NSAppDataUsageDescription",
        "OSBundleUsageDescription",
      ].contains(key)
  }

  private func extractURLSchemes(_ info: [String: Any]) -> [String] {
    guard let types = info["CFBundleURLTypes"] as? [[String: Any]] else { return [] }
    return Array(Set(types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] })).sorted()
  }

  private func string(_ value: Any?) -> String? {
    switch value {
    case let value as String: value
    case let value as NSNumber: value.stringValue
    default: nil
    }
  }

  private func parseValue(_ key: String, in text: String) -> String? {
    text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
      let value = String(line)
      guard value.hasPrefix(key + "=") else { return nil }
      return String(value.dropFirst(key.count + 1))
    }.first
  }

  private func parseGatekeeperSource(_ text: String) -> String? {
    parseValue("source", in: text)
  }

  private func verificationState(
    for result: CommandResult, rejectedStatuses: Set<Int32>
  ) -> VerificationState {
    if result.status == 0 { return .accepted }
    if rejectedStatuses.contains(result.status) { return .rejected }
    return .unavailable
  }

  private func concise(_ value: String) -> String {
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return clean.isEmpty
      ? L10n.text("No diagnostic text was returned.") : String(clean.prefix(1_000))
  }

  private func diagnostic(_ value: String, artifactURL: URL) -> String {
    concise(value.replacingOccurrences(of: artifactURL.path, with: "<artifact>"))
  }
}

extension AppAnalyzer: ArtifactAnalyzing {}

extension AppSnapshot.Signing {
  fileprivate func withSandbox(_ value: Bool) -> Self {
    var copy = self
    copy.sandboxed = value
    return copy
  }
}

private final class PackageMetadataXMLDelegate: NSObject, XMLParserDelegate {
  private(set) var identifier: String?
  private(set) var version: String?

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    guard elementName == "pkg-info" || elementName == "product" else { return }
    identifier = identifier ?? attributeDict["identifier"] ?? attributeDict["id"]
    version = version ?? attributeDict["version"]
  }
}
