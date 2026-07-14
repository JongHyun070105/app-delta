import Foundation

struct CapabilityExplanation {
  var title: String
  var detail: String
  var addedSeverity: DeltaSeverity
}

enum CapabilityCatalog {
  static func explanation(for key: String) -> CapabilityExplanation {
    if let known = known[key] { return known }
    if key.contains("temporary-exception") {
      return .init(
        title: key,
        detail:
          "Declares a temporary sandbox exception. Its presence does not establish how the app uses it.",
        addedSeverity: .important
      )
    }
    return .init(
      title: key,
      detail:
        "A declared code-signing entitlement changed. App Delta reports the declaration, not runtime behavior.",
      addedSeverity: .attention
    )
  }

  private static let known: [String: CapabilityExplanation] = [
    "com.apple.security.app-sandbox": .init(
      title: "App Sandbox",
      detail:
        "Limits access to system resources and user data unless additional capabilities are declared.",
      addedSeverity: .info
    ),
    "com.apple.security.network.client": .init(
      title: "Outgoing Network Connections",
      detail: "Allows a sandboxed app to initiate network connections.",
      addedSeverity: .attention
    ),
    "com.apple.security.network.server": .init(
      title: "Incoming Network Connections",
      detail: "Allows a sandboxed app to listen for incoming network connections.",
      addedSeverity: .important
    ),
    "com.apple.security.device.camera": .init(
      title: "Camera Capability",
      detail:
        "Allows a sandboxed app to request camera access. It does not prove the camera is used.",
      addedSeverity: .attention
    ),
    "com.apple.security.device.audio-input": .init(
      title: "Microphone Capability",
      detail:
        "Allows a sandboxed app to request audio input access. It does not prove audio is recorded.",
      addedSeverity: .attention
    ),
    "com.apple.security.automation.apple-events": .init(
      title: "Apple Events Automation",
      detail:
        "Allows a sandboxed app to request control of other applications through Apple Events.",
      addedSeverity: .important
    ),
    "com.apple.security.get-task-allow": .init(
      title: "Debug Task Access",
      detail:
        "Allows debuggers to attach to the process and is normally disabled in distribution builds.",
      addedSeverity: .important
    ),
    "com.apple.security.cs.disable-library-validation": .init(
      title: "Library Validation Disabled",
      detail:
        "Relaxes Hardened Runtime library validation so code signed by other teams may be loaded.",
      addedSeverity: .important
    ),
    "com.apple.security.cs.allow-jit": .init(
      title: "JIT-Compiled Code",
      detail: "Allows creation of executable memory for just-in-time compilation.",
      addedSeverity: .attention
    ),
    "com.apple.security.cs.allow-unsigned-executable-memory": .init(
      title: "Unsigned Executable Memory",
      detail: "Relaxes Hardened Runtime protection for executable memory.",
      addedSeverity: .important
    ),
    "com.apple.developer.system-extension.install": .init(
      title: "System Extension Installation",
      detail: "Allows the app to activate bundled system extensions with user approval.",
      addedSeverity: .important
    ),
    "com.apple.developer.networking.networkextension": .init(
      title: "Network Extension",
      detail:
        "Declares one or more Network Extension capabilities such as VPN or traffic filtering.",
      addedSeverity: .important
    ),
  ]
}
