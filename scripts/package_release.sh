#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.release-build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/TrackpadControl.app"
ZIP_PATH="$DIST_DIR/TrackpadControl-macOS.zip"
DMG_PATH="$DIST_DIR/TrackpadControl-macOS.dmg"
PKG_PATH="$DIST_DIR/TrackpadControl-macOS.pkg"
PKG_ROOT_DIR="$ROOT_DIR/.pkg-root"
PKG_APP_DIR="$PKG_ROOT_DIR/Applications"

rm -rf "$DERIVED_DATA_DIR" "$APP_PATH" "$ZIP_PATH" "$DMG_PATH" "$PKG_PATH" "$PKG_ROOT_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/TrackpadControl.xcodeproj" \
  -scheme TrackpadControl \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

cp -R "$DERIVED_DATA_DIR/Build/Products/Release/TrackpadControl.app" "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

hdiutil create \
  -volname "Trackpad Control" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

mkdir -p "$PKG_APP_DIR"
cp -R "$APP_PATH" "$PKG_APP_DIR/TrackpadControl.app"

pkgbuild \
  --root "$PKG_ROOT_DIR" \
  --identifier "com.ritam.TrackpadControl.pkg" \
  --install-location "/" \
  "$PKG_PATH"

echo "Created:"
echo "  $APP_PATH"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $PKG_PATH"
