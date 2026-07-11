#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetStatusWidget"
VERSION="${1:-1.0.0}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "==> Building release binary"
cd "$ROOT_DIR"
swift build -c release

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Ad-hoc signing (required for Apple Silicon to launch at all)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Zipping for release upload"
cd "$DIST_DIR"
ZIP_NAME="$APP_NAME-$VERSION-macos.zip"
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_NAME"

echo "==> Done: $DIST_DIR/$ZIP_NAME"
