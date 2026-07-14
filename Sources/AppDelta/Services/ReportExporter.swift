import Foundation

enum ReportFormat: String, CaseIterable, Identifiable {
  case html
  case json

  var id: String { rawValue }
  var label: String { rawValue.uppercased() }
  var fileExtension: String { rawValue }
}

struct ReportExporter: Sendable {
  func data(for report: DeltaReport, format: ReportFormat) throws -> Data {
    switch format {
    case .json:
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      return try encoder.encode(report)
    case .html:
      return Data(html(for: report).utf8)
    }
  }

  func write(_ report: DeltaReport, format: ReportFormat, to destination: URL) throws {
    if FileManager.default.fileExists(atPath: destination.path) {
      let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
      guard values.isSymbolicLink != true, values.isDirectory != true else {
        throw AnalysisError.unsafePath(destination.path)
      }
    }
    try data(for: report, format: format).write(to: destination, options: .atomic)
  }

  private func html(for report: DeltaReport) -> String {
    let rows = report.changedItems.map { item in
      """
      <tr>
        <td><span class="badge \(item.kind.rawValue)">\(escape(item.kind.label.uppercased()))</span></td>
        <td>\(escape(item.category.title))</td>
        <td><strong>\(escape(item.title))</strong><div class="detail">\(escape(item.detail))</div></td>
        <td>\(escape(item.before ?? "—"))</td>
        <td>\(escape(item.after ?? "—"))</td>
      </tr>
      """
    }.joined(separator: "\n")

    let warnings = Array(Set(report.before.warnings + report.after.warnings)).sorted().map {
      "<li>\(escape($0))</li>"
    }.joined(separator: "\n")

    return """
      <!doctype html>
      <html lang="\(AppLanguage.current.effectiveCode)">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
        <title>App Delta — \(escape(report.before.identity.name)) vs \(escape(report.after.identity.name))</title>
        <style>
          :root { color-scheme: light dark; --muted: #737b87; --line: color-mix(in srgb, currentColor 18%, transparent); --panel: color-mix(in srgb, currentColor 5%, transparent); }
          * { box-sizing: border-box; }
          body { max-width: 1440px; margin: 0 auto; padding: 42px; font: 14px -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.45; }
          h1 { margin: 0 0 8px; font-size: 30px; }
          .subtitle, .detail, footer { color: var(--muted); }
          .summary { display: grid; grid-template-columns: 1fr auto 1fr; gap: 18px; align-items: center; margin: 28px 0; }
          .artifact { padding: 18px; border: 1px solid var(--line); border-radius: 14px; background: var(--panel); }
          .arrow { font-size: 22px; color: var(--muted); }
          table { width: 100%; border-collapse: collapse; border: 1px solid var(--line); }
          th, td { padding: 11px 12px; text-align: left; vertical-align: top; border-bottom: 1px solid var(--line); }
          th { position: sticky; top: 0; background: Canvas; }
          .badge { display: inline-block; min-width: 72px; padding: 3px 8px; border-radius: 999px; text-align: center; font-size: 11px; font-weight: 700; }
          .added { color: #0969da; background: color-mix(in srgb, #0969da 14%, transparent); }
          .removed { color: #6e7781; background: color-mix(in srgb, #6e7781 14%, transparent); }
          .changed { color: #9a6700; background: color-mix(in srgb, #bf8700 16%, transparent); }
          .detail { margin-top: 4px; font-size: 12px; }
          .notice { margin: 26px 0; padding: 14px 16px; border-left: 4px solid #bf8700; background: var(--panel); }
          footer { margin-top: 28px; font-size: 12px; }
        </style>
      </head>
      <body>
        <h1>\(escape(L10n.text("App Delta Report")))</h1>
        <div class="subtitle">\(escape(L10n.format("Generated %@ · %d observable changes", ISO8601DateFormatter().string(from: report.generatedAt), report.changedItems.count)))</div>
        <div class="summary">
          <div class="artifact"><strong>\(escape(L10n.text("Baseline")))</strong><h2>\(escape(report.before.identity.name)) \(escape(report.before.identity.version))</h2><div>\(escape(report.before.identity.bundleIdentifier))</div></div>
          <div class="arrow">→</div>
          <div class="artifact"><strong>\(escape(L10n.text("Candidate")))</strong><h2>\(escape(report.after.identity.name)) \(escape(report.after.identity.version))</h2><div>\(escape(report.after.identity.bundleIdentifier))</div></div>
        </div>
        <div class="notice"><strong>\(escape(L10n.text("Interpretation boundary:")))</strong> \(escape(L10n.text("App Delta does not determine whether an application is safe or malicious. It reports changes in signatures, declared capabilities, bundled code, package contents, and file metadata.")))</div>
        \(warnings.isEmpty ? "" : "<h2>\(escape(L10n.text("Analysis notes")))</h2><ul>\(warnings)</ul>")
        <h2>\(escape(L10n.text("Changes")))</h2>
        <table>
          <thead><tr><th>\(escape(L10n.text("Change")))</th><th>\(escape(L10n.text("Category")))</th><th>\(escape(L10n.text("Item")))</th><th>\(escape(L10n.text("Baseline")))</th><th>\(escape(L10n.text("Candidate")))</th></tr></thead>
          <tbody>\(rows)</tbody>
        </table>
        <footer>\(escape(L10n.text("Generated locally by App Delta. No artifact data was uploaded.")))</footer>
      </body>
      </html>
      """
  }

  private func escape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
  }
}
