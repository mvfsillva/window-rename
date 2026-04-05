#!/usr/bin/env bash
#
# build-app.sh — Build SpaceRenamer.app bundle from Swift Package Manager output.
#
# Usage:
#   ./scripts/build-app.sh          # builds release .app bundle under build/
#   ./scripts/build-app.sh --debug  # builds debug .app bundle under build/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="release"
if [[ "${1:-}" == "--debug" ]]; then
    CONFIG="debug"
fi

APP_NAME="SpaceRenamer"
BUNDLE_ID="com.mvfsillva.SpaceRenamer"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="14.0"

BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# ---------------------------------------------------------------------------
# Step 1 — Build the binary
# ---------------------------------------------------------------------------
echo "==> Building $APP_NAME ($CONFIG)..."
cd "$PROJECT_DIR"
swift build -c "$CONFIG"

# Locate the built binary
BINARY="$PROJECT_DIR/.build/$CONFIG/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2 — Create .app bundle structure
# ---------------------------------------------------------------------------
echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# ---------------------------------------------------------------------------
# Step 3 — Copy the binary
# ---------------------------------------------------------------------------
cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# ---------------------------------------------------------------------------
# Step 4 — Generate Info.plist
# ---------------------------------------------------------------------------
cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${APP_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD_NUMBER}</string>
	<key>LSMinimumSystemVersion</key>
	<string>${MIN_MACOS}</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAccessibilityUsageDescription</key>
	<string>SpaceRenamer needs Accessibility access to intercept global keyboard shortcuts for switching between named Spaces and quick renaming.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# ---------------------------------------------------------------------------
# Step 5 — Generate PkgInfo
# ---------------------------------------------------------------------------
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo "==> Built: $APP_BUNDLE"
echo "    Binary: $MACOS_DIR/$APP_NAME"
echo "    Config: $CONFIG"
du -sh "$APP_BUNDLE" | awk '{print "    Size:  " $1}'
