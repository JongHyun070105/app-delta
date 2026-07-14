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
        detail: L10n.text(
          "Declares a temporary sandbox exception. Its presence does not establish how the app uses it."
        ),
        addedSeverity: .important
      )
    }
    return .init(
      title: key,
      detail: L10n.text(
        "A declared code-signing entitlement changed. App Delta reports the declaration, not runtime behavior."
      ),
      addedSeverity: .attention
    )
  }

  private static var known: [String: CapabilityExplanation] {
    [
      "com.apple.security.app-sandbox": .init(
        title: L10n.text("App Sandbox"),
        detail: L10n.text(
          "Limits access to system resources and user data unless additional capabilities are declared."
        ),
        addedSeverity: .info
      ),
      "com.apple.security.network.client": .init(
        title: L10n.text("Outgoing Network Connections"),
        detail: L10n.text("Allows a sandboxed app to initiate network connections."),
        addedSeverity: .attention
      ),
      "com.apple.security.network.server": .init(
        title: L10n.text("Incoming Network Connections"),
        detail: L10n.text("Allows a sandboxed app to listen for incoming network connections."),
        addedSeverity: .important
      ),
      "com.apple.security.device.camera": .init(
        title: L10n.text("Camera Capability"),
        detail: L10n.text(
          "Allows a sandboxed app to request camera access. It does not prove the camera is used."),
        addedSeverity: .attention
      ),
      "com.apple.security.device.audio-input": .init(
        title: L10n.text("Microphone Capability"),
        detail: L10n.text(
          "Allows a sandboxed app to request audio input access. It does not prove audio is recorded."
        ),
        addedSeverity: .attention
      ),
      "com.apple.security.automation.apple-events": .init(
        title: L10n.text("Apple Events Automation"),
        detail: L10n.text(
          "Allows a sandboxed app to request control of other applications through Apple Events."),
        addedSeverity: .important
      ),
      "com.apple.security.get-task-allow": .init(
        title: L10n.text("Debug Task Access"),
        detail: L10n.text(
          "Allows debuggers to attach to the process and is normally disabled in distribution builds."
        ),
        addedSeverity: .important
      ),
      "com.apple.security.cs.disable-library-validation": .init(
        title: L10n.text("Library Validation Disabled"),
        detail: L10n.text(
          "Relaxes Hardened Runtime library validation so code signed by other teams may be loaded."
        ),
        addedSeverity: .important
      ),
      "com.apple.security.cs.allow-jit": .init(
        title: L10n.text("JIT-Compiled Code"),
        detail: L10n.text("Allows creation of executable memory for just-in-time compilation."),
        addedSeverity: .attention
      ),
      "com.apple.security.cs.allow-unsigned-executable-memory": .init(
        title: L10n.text("Unsigned Executable Memory"),
        detail: L10n.text("Relaxes Hardened Runtime protection for executable memory."),
        addedSeverity: .important
      ),
      "com.apple.developer.system-extension.install": .init(
        title: L10n.text("System Extension Installation"),
        detail: L10n.text(
          "Allows the app to activate bundled system extensions with user approval."),
        addedSeverity: .important
      ),
      "com.apple.developer.networking.networkextension": .init(
        title: L10n.text("Network Extension"),
        detail: L10n.text(
          "Declares one or more Network Extension capabilities such as VPN or traffic filtering."),
        addedSeverity: .important
      ),
    ]
  }
}
