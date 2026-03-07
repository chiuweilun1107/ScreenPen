#!/bin/bash
# Build ScreenPen.dmg for distribution
set -e

APP_NAME="ScreenPen"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"

echo "==> Building Release..."
cd "$PROJECT_DIR"
xcodebuild -project ScreenPen.xcodeproj -scheme ScreenPen -configuration Release build \
    SYMROOT="$BUILD_DIR/xcode" -quiet

APP_PATH="$BUILD_DIR/xcode/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found"
    exit 1
fi

echo "==> Creating DMG..."
rm -rf "$DMG_DIR" "$DMG_OUTPUT"
mkdir -p "$DMG_DIR"

cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_OUTPUT"

rm -rf "$DMG_DIR"

echo "==> Done: $DMG_OUTPUT"
echo "    Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
