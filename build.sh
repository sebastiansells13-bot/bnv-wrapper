#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="BNV"
APP_BUNDLE="$APP_NAME.app"
BUNDLE_ID="com.mtsproservices.bnvwrapper"

echo "Building $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc -O src/main.swift -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" -framework Cocoa -framework WebKit

cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

if [ -f "icon.png" ]; then
  echo "Building app icon from icon.png..."
  ICONSET="AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16     icon.png --out "$ICONSET/icon_16x16.png"      > /dev/null
  sips -z 32 32     icon.png --out "$ICONSET/icon_16x16@2x.png"   > /dev/null
  sips -z 32 32     icon.png --out "$ICONSET/icon_32x32.png"      > /dev/null
  sips -z 64 64     icon.png --out "$ICONSET/icon_32x32@2x.png"   > /dev/null
  sips -z 128 128   icon.png --out "$ICONSET/icon_128x128.png"    > /dev/null
  sips -z 256 256   icon.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null
  sips -z 256 256   icon.png --out "$ICONSET/icon_256x256.png"    > /dev/null
  sips -z 512 512   icon.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null
  sips -z 512 512   icon.png --out "$ICONSET/icon_512x512.png"    > /dev/null
  sips -z 1024 1024 icon.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null
  iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
else
  echo "No icon.png found yet — building with the default icon."
fi

echo "Signing app (ad-hoc, stable identifier so camera/permission grants survive rebuilds)..."
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

xattr -cr "$APP_BUNDLE" || true

echo ""
echo "Done. Built: $(pwd)/$APP_BUNDLE"
echo "Double-click it here, or drag it to /Applications."
