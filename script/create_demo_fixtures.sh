#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/.tmp/demo-fixtures}"
MARKER="/tmp/app-delta-inspected-app-ran"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Baseline" "$OUTPUT_DIR/Candidate"
rm -f "$MARKER"

make_app() {
  local destination="$1"
  local version="$2"
  local build="$3"
  local privacy="$4"
  local app="$destination/DeltaDemo.app"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat >"$destination/DeltaDemo.c" <<'SOURCE'
#include <stdio.h>
int main(void) {
  FILE *marker = fopen("/tmp/app-delta-inspected-app-ran", "w");
  if (marker != NULL) { fclose(marker); }
  return 0;
}
SOURCE
  /usr/bin/clang "$destination/DeltaDemo.c" -o "$app/Contents/MacOS/DeltaDemo"
  rm "$destination/DeltaDemo.c"

  cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>DeltaDemo</string>
  <key>CFBundleIdentifier</key><string>com.example.deltademo</string>
  <key>CFBundleName</key><string>Delta Demo</string>
  <key>CFBundleDisplayName</key><string>Delta Demo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$build</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  $privacy
</dict></plist>
PLIST

  printf 'fixture-content-%s\n' "$version" >"$app/Contents/Resources/model.dat"
  printf '<plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>' >"$destination/entitlements.plist"
  /usr/bin/codesign --force --options runtime --entitlements "$destination/entitlements.plist" --sign - "$app"
}

make_app "$OUTPUT_DIR/Baseline" "1.0.0" "100" ""
make_app "$OUTPUT_DIR/Candidate" "1.1.0" "110" '<key>NSCameraUsageDescription</key><string>Scan a code only after the user clicks Scan.</string>'

CANDIDATE="$OUTPUT_DIR/Candidate/DeltaDemo.app"
mkdir -p "$CANDIDATE/Contents/Frameworks" "$CANDIDATE/Contents/Library/LaunchAgents"
printf 'new-library' >"$CANDIDATE/Contents/Frameworks/libDeltaTelemetry.dylib"
cat >"$CANDIDATE/Contents/Library/LaunchAgents/com.example.deltademo.refresh.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>Label</key><string>com.example.deltademo.refresh</string></dict></plist>
PLIST
cat >"$CANDIDATE/Contents/Resources/PrivacyInfo.xcprivacy" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict><key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryFileTimestamp</string></dict>
  </array>
</dict></plist>
PLIST
printf '<plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/><key>com.apple.security.network.client</key><true/><key>com.apple.security.device.camera</key><true/></dict></plist>' >"$OUTPUT_DIR/Candidate/entitlements.plist"
/usr/bin/codesign --force --deep --options runtime --entitlements "$OUTPUT_DIR/Candidate/entitlements.plist" --sign - "$CANDIDATE"

echo "$OUTPUT_DIR/Baseline/DeltaDemo.app"
echo "$OUTPUT_DIR/Candidate/DeltaDemo.app"
echo "Execution marker (must stay absent): $MARKER"
