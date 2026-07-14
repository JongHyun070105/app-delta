import Foundation
import XCTest

@testable import AppDelta

final class AppAnalyzerIntegrationTests: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AppDeltaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
  }

  func testApplicationAnalysisFindsChangesWithoutLaunchingExecutable() throws {
    let marker = temporaryDirectory.appendingPathComponent("executable-ran")
    let baseline = try makeApplication(
      name: "Baseline", version: "1.0", marker: marker, cameraUsage: nil)
    let candidate = try makeApplication(
      name: "Candidate",
      version: "2.0",
      marker: marker,
      cameraUsage: "Used only when the user starts a scan.",
      extraEntitlements: [
        "com.apple.security.device.camera": true,
        "com.apple.security.network.client": true,
      ]
    )
    try Data("same length A".utf8).write(
      to: baseline.appendingPathComponent("Contents/Resources/payload.dat"))
    try Data("same length B".utf8).write(
      to: candidate.appendingPathComponent("Contents/Resources/payload.dat"))
    let framework = candidate.appendingPathComponent(
      "Contents/Frameworks/Fixture.framework", isDirectory: true)
    let frameworkVersion = framework.appendingPathComponent("Versions/A", isDirectory: true)
    let frameworkResources = frameworkVersion.appendingPathComponent("Resources", isDirectory: true)
    try FileManager.default.createDirectory(
      at: frameworkResources, withIntermediateDirectories: true)
    let frameworkSource = temporaryDirectory.appendingPathComponent("FixtureFramework.c")
    try Data("int app_delta_fixture(void) { return 1; }\n".utf8).write(to: frameworkSource)
    try run(
      "/usr/bin/clang",
      [
        "-dynamiclib", frameworkSource.path, "-o",
        frameworkVersion.appendingPathComponent("Fixture").path,
      ])
    let frameworkInfo: [String: Any] = [
      "CFBundleExecutable": "Fixture",
      "CFBundleIdentifier": "com.example.fixture-framework",
      "CFBundleName": "Fixture",
      "CFBundlePackageType": "FMWK",
      "CFBundleShortVersionString": "1.0",
      "CFBundleVersion": "1",
    ]
    try PropertyListSerialization.data(fromPropertyList: frameworkInfo, format: .xml, options: 0)
      .write(to: frameworkResources.appendingPathComponent("Info.plist"))
    try FileManager.default.createSymbolicLink(
      atPath: framework.appendingPathComponent("Versions/Current").path, withDestinationPath: "A")
    try FileManager.default.createSymbolicLink(
      atPath: framework.appendingPathComponent("Fixture").path,
      withDestinationPath: "Versions/Current/Fixture")
    try FileManager.default.createSymbolicLink(
      atPath: framework.appendingPathComponent("Resources").path,
      withDestinationPath: "Versions/Current/Resources")
    try run("/usr/bin/codesign", ["--force", "--sign", "-", framework.path])
    try run(
      "/usr/bin/codesign",
      ["--force", "--sign", "-", "--preserve-metadata=entitlements", baseline.path])
    try run(
      "/usr/bin/codesign",
      ["--force", "--sign", "-", "--preserve-metadata=entitlements", candidate.path])

    let analyzer = AppAnalyzer()
    let before = try analyzer.analyze(try XCTUnwrap(SelectedArtifact(url: baseline)))
    let after = try analyzer.analyze(try XCTUnwrap(SelectedArtifact(url: candidate)))
    let report = DeltaEngine().compare(before: before, after: after)

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: marker.path),
      "The inspected executable must never run.")
    XCTAssertEqual(before.identity.version, "1.0")
    XCTAssertEqual(after.identity.version, "2.0")
    XCTAssertEqual(before.signing.signatureStatus, .accepted)
    XCTAssertEqual(after.signing.signatureStatus, .accepted)
    XCTAssertEqual(after.entitlements["com.apple.security.device.camera"], .bool(true))
    XCTAssertTrue(
      report.changedItems.contains { $0.id == "entitlement:com.apple.security.device.camera" })
    XCTAssertTrue(report.changedItems.contains { $0.id == "privacy:NSCameraUsageDescription" })
    XCTAssertTrue(report.changedItems.contains { $0.id == "file:Contents/Resources/payload.dat" })
    XCTAssertFalse(report.changedItems.contains { $0.title == "Gatekeeper Diagnostic" })
    XCTAssertEqual(
      after.components.filter { $0.kind == .framework }.map(\.path),
      ["Contents/Frameworks/Fixture.framework"])
  }

  func testDiskImageIsMountedReadOnlyAndDetachedAfterAnalysis() throws {
    let marker = temporaryDirectory.appendingPathComponent("dmg-app-ran")
    let source = temporaryDirectory.appendingPathComponent("DMG Source", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    _ = try makeApplication(
      name: "DiskImageFixture", version: "1.0", marker: marker, parent: source)
    let diskImage = temporaryDirectory.appendingPathComponent("Fixture.dmg")

    try run(
      "/usr/bin/hdiutil",
      [
        "create", "-quiet", "-format", "UDZO", "-srcfolder", source.path, diskImage.path,
      ])

    let snapshot = try AppAnalyzer().analyze(try XCTUnwrap(SelectedArtifact(url: diskImage)))

    XCTAssertEqual(snapshot.sourceKind, .diskImage)
    XCTAssertEqual(snapshot.identity.name, "DiskImageFixture")
    XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    let info = try run("/usr/bin/hdiutil", ["info", "-plist"], captureOutput: true)
    XCTAssertFalse(
      String(decoding: info, as: UTF8.self).contains("AppDelta-"),
      "Temporary disk-image mounts must be detached.")
  }

  func testDiskImageIsDetachedWhenItContainsNoApplication() throws {
    let source = temporaryDirectory.appendingPathComponent("Empty DMG Source", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("not an application".utf8).write(
      to: source.appendingPathComponent("README.txt"))
    let diskImage = temporaryDirectory.appendingPathComponent("Empty.dmg")

    try run(
      "/usr/bin/hdiutil",
      [
        "create", "-quiet", "-format", "UDZO", "-srcfolder", source.path, diskImage.path,
      ])

    XCTAssertThrowsError(
      try AppAnalyzer().analyze(try XCTUnwrap(SelectedArtifact(url: diskImage)))
    ) { error in
      XCTAssertEqual(error as? AnalysisError, .noApplicationFound("Empty.dmg"))
    }
    let info = try run("/usr/bin/hdiutil", ["info", "-plist"], captureOutput: true)
    XCTAssertFalse(
      String(decoding: info, as: UTF8.self).contains("AppDelta-"),
      "Failed disk-image analysis must still detach every temporary mount.")
  }

  func testPackageScriptsAreNotRun() throws {
    let packageRoot = temporaryDirectory.appendingPathComponent("PackageRoot", isDirectory: true)
    let scripts = temporaryDirectory.appendingPathComponent("Scripts", isDirectory: true)
    let marker = temporaryDirectory.appendingPathComponent("package-script-ran")
    let payloadFile = packageRoot.appendingPathComponent(
      "Library/PrivilegedHelperTools/com.example.helper")
    try FileManager.default.createDirectory(
      at: payloadFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("helper payload".utf8).write(to: payloadFile)
    try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
    let postinstall = scripts.appendingPathComponent("postinstall")
    try Data("#!/bin/sh\ntouch \"\(marker.path)\"\n".utf8).write(to: postinstall)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: postinstall.path)
    let package = temporaryDirectory.appendingPathComponent("Fixture.pkg")

    try run(
      "/usr/bin/pkgbuild",
      [
        "--root", packageRoot.path,
        "--scripts", scripts.path,
        "--identifier", "com.example.fixture",
        "--version", "1.0",
        package.path,
      ])

    let snapshot = try AppAnalyzer().analyze(try XCTUnwrap(SelectedArtifact(url: package)))

    XCTAssertEqual(snapshot.sourceKind, .installerPackage)
    XCTAssertEqual(snapshot.identity.bundleIdentifier, "com.example.fixture")
    XCTAssertEqual(snapshot.identity.version, "1.0")
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: marker.path), "Package scripts must never run.")
    XCTAssertTrue(snapshot.components.contains { $0.path.contains("PrivilegedHelperTools") })
    XCTAssertTrue(snapshot.warnings.contains { $0.contains("never run") })
  }

  func testGatekeeperToolErrorIsUnavailableRatherThanRejected() throws {
    let marker = temporaryDirectory.appendingPathComponent("gatekeeper-app-ran")
    let application = try makeApplication(
      name: "GatekeeperFixture", version: "1.0", marker: marker)
    let analyzer = AppAnalyzer(commandRunner: GatekeeperUnavailableRunner())

    let snapshot = try analyzer.analyze(try XCTUnwrap(SelectedArtifact(url: application)))

    XCTAssertEqual(snapshot.signing.gatekeeperStatus, .unavailable)
    XCTAssertEqual(snapshot.signing.gatekeeperMessage, "assessment service unavailable")
    XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
  }

  func testOversizedPackageMetadataIsStoppedBeforeDiskExtraction() throws {
    let archiveRoot = temporaryDirectory.appendingPathComponent(
      "OversizedPackage", isDirectory: true)
    try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
    try Data(repeating: 0x20, count: ScanBudget.default.maximumToolOutputBytes + 1)
      .write(to: archiveRoot.appendingPathComponent("PackageInfo"))
    let package = temporaryDirectory.appendingPathComponent("Oversized.pkg")
    try run(
      "/usr/bin/xar", ["-cf", package.path, "PackageInfo"], currentDirectory: archiveRoot)

    XCTAssertThrowsError(
      try AppAnalyzer().analyze(try XCTUnwrap(SelectedArtifact(url: package)))
    ) { error in
      XCTAssertEqual(error as? AnalysisError, .outputLimitExceeded("tar"))
    }
  }

  private func makeApplication(
    name: String,
    version: String,
    marker: URL,
    cameraUsage: String? = nil,
    extraEntitlements: [String: Any] = [:],
    parent: URL? = nil
  ) throws -> URL {
    let app = (parent ?? temporaryDirectory).appendingPathComponent(
      "\(name).app", isDirectory: true)
    let macOS = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
    let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
    try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

    var info: [String: Any] = [
      "CFBundleExecutable": name,
      "CFBundleIdentifier": "com.example.\(name.lowercased())",
      "CFBundleName": name,
      "CFBundleDisplayName": name,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": version,
      "CFBundleVersion": version == "1.0" ? "1" : "2",
      "LSMinimumSystemVersion": "14.0",
    ]
    if let cameraUsage { info["NSCameraUsageDescription"] = cameraUsage }
    let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try plist.write(to: app.appendingPathComponent("Contents/Info.plist"))

    let executable = macOS.appendingPathComponent(name)
    let source = temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).c")
    let escapedMarker = marker.path
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    try Data(
      "#include <stdio.h>\nint main(void) { FILE *f = fopen(\"\(escapedMarker)\", \"w\"); if (f) fclose(f); return 0; }\n"
        .utf8
    ).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    try run("/usr/bin/clang", [source.path, "-o", executable.path])
    try Data("fixture".utf8).write(to: resources.appendingPathComponent("payload.dat"))
    var entitlements: [String: Any] = ["com.apple.security.app-sandbox": true]
    for (key, value) in extraEntitlements {
      entitlements[key] = value
    }
    let entitlementsURL = temporaryDirectory.appendingPathComponent(
      "\(name)-\(UUID().uuidString)-entitlements.plist")
    let entitlementData = try PropertyListSerialization.data(
      fromPropertyList: entitlements, format: .xml, options: 0)
    try entitlementData.write(to: entitlementsURL)
    defer { try? FileManager.default.removeItem(at: entitlementsURL) }
    try run(
      "/usr/bin/codesign",
      ["--force", "--sign", "-", "--entitlements", entitlementsURL.path, app.path])
    return app
  }

  @discardableResult
  private func run(
    _ executable: String,
    _ arguments: [String],
    captureOutput: Bool = false,
    currentDirectory: URL? = nil
  ) throws
    -> Data
  {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory
    process.standardOutput = output
    process.standardError = error
    try process.run()
    process.waitUntilExit()
    let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
    let standardError = error.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      throw NSError(
        domain: "AppDeltaTests",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: String(decoding: standardError, as: UTF8.self)]
      )
    }
    return captureOutput ? standardOutput : Data()
  }
}

private struct GatekeeperUnavailableRunner: CommandRunning {
  func run(_ tool: SystemTool, arguments: [String], budget: ScanBudget) throws -> CommandResult {
    if tool == .spctl {
      return CommandResult(
        status: 1,
        standardOutput: Data(),
        standardError: Data("assessment service unavailable".utf8))
    }
    return try BoundedCommandRunner().run(tool, arguments: arguments, budget: budget)
  }
}
