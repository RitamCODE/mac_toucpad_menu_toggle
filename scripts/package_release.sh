#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.release-build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/TrackpadControl.app"
ZIP_PATH="$DIST_DIR/TrackpadControl-macOS.zip"

rm -rf "$DERIVED_DATA_DIR" "$APP_PATH" "$ZIP_PATH"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/TrackpadControl.xcodeproj" \
  -scheme TrackpadControl \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

cp -R "$DERIVED_DATA_DIR/Build/Products/Release/TrackpadControl.app" "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created:"
echo "  $APP_PATH"
echo "  $ZIP_PATH"
