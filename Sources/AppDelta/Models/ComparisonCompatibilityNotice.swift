import Foundation

struct ComparisonCompatibilityNotice: Equatable, Sendable {
  let baselineKind: ArtifactKind
  let candidateKind: ArtifactKind
  let baselineIdentifier: String?
  let candidateIdentifier: String?

  var hasMixedFormats: Bool { baselineKind != candidateKind }

  var hasDifferentIdentifiers: Bool {
    guard let baselineIdentifier, let candidateIdentifier else { return false }
    return baselineIdentifier != candidateIdentifier
  }

  var hasUnconfirmedIdentity: Bool {
    baselineIdentifier == nil || candidateIdentifier == nil
  }

  var title: String {
    if hasMixedFormats, hasDifferentIdentifiers {
      return L10n.text("Different formats and identifiers detected")
    }
    if hasDifferentIdentifiers {
      return L10n.text("These appear to be different applications")
    }
    if hasMixedFormats {
      return L10n.text("Different artifact formats selected")
    }
    return L10n.text("Application identity could not be confirmed")
  }

  var detail: String {
    var messages: [String] = []
    if hasMixedFormats {
      messages.append(
        L10n.format(
          "Comparing %@ with %@ is supported, but packaging differences may produce many file and component changes.",
          baselineKind.label, candidateKind.label))
    }
    if hasDifferentIdentifiers, let baselineIdentifier, let candidateIdentifier {
      messages.append(
        L10n.format(
          "The identifiers are %@ and %@. Confirm that these are the intended versions before interpreting the result.",
          baselineIdentifier, candidateIdentifier))
    } else if hasUnconfirmedIdentity {
      messages.append(
        L10n.text(
          "At least one identifier is unavailable. Check the application names and sources before interpreting the result."
        ))
    }
    return messages.joined(separator: " ")
  }

  static func evaluate(before: AppSnapshot, after: AppSnapshot) -> Self? {
    let notice = Self(
      baselineKind: before.sourceKind,
      candidateKind: after.sourceKind,
      baselineIdentifier: knownIdentifier(before.identity.bundleIdentifier),
      candidateIdentifier: knownIdentifier(after.identity.bundleIdentifier)
    )
    guard notice.hasMixedFormats || notice.hasDifferentIdentifiers || notice.hasUnconfirmedIdentity
    else { return nil }
    return notice
  }

  private static func knownIdentifier(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      trimmed != "Unavailable",
      trimmed != "Unknown",
      trimmed != "unknown.bundle.identifier"
    else { return nil }
    return trimmed
  }
}
