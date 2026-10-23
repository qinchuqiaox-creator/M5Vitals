#!/bin/bash
# Build M5Vitals.app from source. Requires only Xcode Command Line Tools.
#   BUNDLE_ID=com.yourname.m5vitals ./build.sh
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/M5Vitals.swift"
APP="$HOME/Applications/M5Vitals.app"
BUNDLE_ID="${BUNDLE_ID:-com.example.m5vitals}"
APP_NAME="M5Vitals"
VERSION="1.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

/usr/bin/swiftc -O -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI -framework AppKit \
  "$SRC" -o "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP" 2>&1 | tail -2
echo "built: $APP ($BUNDLE_ID)"
