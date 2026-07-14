# App Delta v1 implementation plan

## Product contract

App Delta compares two macOS application artifacts and explains only observable
changes. It never launches an inspected application, uploads data, or modifies a
source artifact. Analysis is local and on demand.

Supported inputs:

- `.app`: analyzed directly.
- `.dmg`: attached read-only and without Finder browsing; the selected app is
  analyzed and the image is detached afterward.
- `.pkg` / `.mpkg`: signature, Gatekeeper result, and a bounded payload path
  inventory are compared. Payloads are not installed or fully extracted, and
  package scripts are never run.

## Architecture

1. `ArtifactResolver` validates `.app` inputs and turns a `.dmg` into a
   short-lived, read-only mounted application lease that owns cleanup.
2. `AppAnalyzer` reads `Info.plist`, file metadata, code-signing details,
   entitlements, Gatekeeper assessment, privacy declarations, persistence
   helpers, embedded components, and a bounded file inventory.
3. `DeltaEngine` compares normalized snapshots and emits typed changes with an
   evidence path and severity. Added capabilities are never labeled malware.
4. `ComparisonStore` owns window-level selection and progress state.
5. SwiftUI presents a sidebar-detail desktop interface with drag and drop,
   search, severity filters, keyboard commands, and export.
6. `ReportExporter` writes self-contained JSON and escaped static HTML reports.

## Security boundaries

- Process APIs receive executable paths and argument arrays directly; no shell
  interpolation is used.
- Disk images use `hdiutil attach -readonly -nobrowse -plist`.
- Temporary directories are unique and removed on success and failure.
- Symbolic links are inventoried but never followed outside the bundle.
- File enumeration is bounded by count, path depth, tool output, timeout, and
  total hashed bytes.
- Exported HTML escapes all application-controlled values.
- No safety verdict is produced. The UI separates observed results from
  informational interpretation and preserves accepted, rejected, and
  unavailable trust checks as distinct states with diagnostic evidence.

## Delivery phases

1. Scaffold the Swift package, real `.app` run bundle, and Codex Run action.
2. Implement snapshots and deterministic diffing.
3. Add safe artifact resolution and native inspection commands.
4. Build the native macOS comparison UI and exports.
5. Add synthetic signed fixtures, unit/integration tests, CI, and bilingual docs.
6. Build, run, and manually exercise the complete flow with Computer Use.

## Acceptance criteria

- Compares two valid `.app` bundles without executing either one.
- Reports version, signing, entitlement, privacy, persistence, component, and
  file changes with added/removed/changed states.
- Opens `.dmg` read-only and cleans up its mount; inventories `.pkg` metadata and
  paths without installing, extracting, or executing package content.
- Exports valid JSON and a self-contained, safely escaped HTML report.
- Handles malformed or unsupported artifacts with a useful in-app error.
- Passes unit and integration tests and launches via
  `./script/build_and_run.sh --verify`.
- The primary drag/drop, compare, filter, detail, swap, and export flows are
  manually verified in the built app.
