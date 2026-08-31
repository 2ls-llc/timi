#!/bin/bash
# Builds a universal (arm64 + x86_64) PixelPal.app into dist/.
#
#   ./Packaging/build.sh
#
# Environment:
#   VERSION            marketing version stamped into Info.plist (default 0.1.0)
#   CODESIGN_IDENTITY  signing identity (default "-" = ad-hoc). Ad-hoc builds run
#                      locally; Gatekeeper on other Macs wants the notarized build
#                      (see notarize.sh) or `brew install --no-quarantine`.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
IDENTITY="${CODESIGN_IDENTITY:--}"
APP=dist/PixelPal.app

echo "==> swift build (universal, release)"
swift build -c release --arch arm64 --arch x86_64

BUILD=.build/apple/Products/Release
test -x "$BUILD/PixelPal" || { echo "build product missing"; exit 1; }

echo "==> assembling $APP"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/PixelPal" "$APP/Contents/MacOS/PixelPal"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# KeyboardShortcuts ships localized strings in a SwiftPM resource bundle.
for bundle in "$BUILD"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

if [ ! -f Packaging/AppIcon.icns ]; then
  echo "==> generating AppIcon.icns"
  swift Packaging/make-icon.swift Packaging/AppIcon.icns
fi
cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

echo "==> codesign ($IDENTITY)"
codesign --force --options runtime \
  --entitlements Packaging/PixelPal.entitlements \
  --sign "$IDENTITY" "$APP"

codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/PixelPal"
echo "==> done: $APP (version $VERSION)"
