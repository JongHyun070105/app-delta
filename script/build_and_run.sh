#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AppDelta"
BUNDLE_ID="io.github.JongHyun070105.AppDelta"
MIN_SYSTEM_VERSION="14.0"
VERSION="${APP_DELTA_VERSION:-0.2.0}"
BUILD_NUMBER="${APP_DELTA_BUILD_NUMBER:-2}"
SIGNING_IDENTITY="${APP_DELTA_SIGNING_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_RESOURCES="$APP_CONTENTS/Resources"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.png"

CONFIGURATION="debug"
if [[ "$MODE" == "--package" || "$MODE" == "package" || "$MODE" == "--dmg" || "$MODE" == "dmg" ]]; then
  CONFIGURATION="release"
else
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

cd "$ROOT_DIR"
BUILD_ARGS=(-c "$CONFIGURATION")
if [[ "$CONFIGURATION" == "release" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

ICONSET_DIR="$ROOT_DIR/.tmp/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  read -r pixels filename <<<"$spec"
  /usr/bin/sips -z "$pixels" "$pixels" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/AppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>App Delta</string>
  <key>CFBundleDisplayName</key>
  <string>App Delta</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --sign - "$APP_BUNDLE"
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
fi

package_zip() {
  local archive="$DIST_DIR/$APP_NAME-v$VERSION-macos-universal.zip"
  rm -f "$archive"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$archive"
  echo "$archive"
}

package_dmg() {
  local root="$ROOT_DIR/.tmp/dmg-root"
  local image="$DIST_DIR/$APP_NAME-v$VERSION-macos-universal.dmg"
  rm -rf "$root"
  mkdir -p "$root"
  /usr/bin/ditto "$APP_BUNDLE" "$root/$APP_NAME.app"
  ln -s /Applications "$root/Applications"
  rm -f "$image"
  /usr/bin/hdiutil create \
    -volname "App Delta" \
    -srcfolder "$root" \
    -format UDZO \
    -ov \
    "$image" >/dev/null
  /usr/bin/hdiutil verify "$image" >/dev/null
  (
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 "$(basename "$image")" >"$(basename "$image").sha256"
  )
  echo "$image"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
    ;;
  --package|package)
    package_zip
    package_dmg
    ;;
  --dmg|dmg)
    package_dmg
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--dmg]" >&2
    exit 2
    ;;
esac
