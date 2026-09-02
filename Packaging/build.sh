#!/bin/bash
# Builds a universal (arm64 + x86_64) Timi.app into dist/.
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

# Building needs FULL Xcode, not just Command Line Tools: a dependency uses
# SwiftUI #Preview macros, whose compiler plugin ships inside Xcode.app.
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.*\.app"; then
  echo "error: full Xcode is required (xcode-select currently points at:"
  echo "       $(xcode-select -p 2>/dev/null || echo '<nothing>'))."
  echo "       Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

VERSION="${VERSION:-0.1.0}"
IDENTITY="${CODESIGN_IDENTITY:--}"
APP=dist/Timi.app

echo "==> swift build (universal, release)"
swift build -c release --arch arm64 --arch x86_64

BUILD=.build/apple/Products/Release
test -x "$BUILD/Timi" || { echo "build product missing"; exit 1; }

echo "==> assembling $APP"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/Timi" "$APP/Contents/MacOS/Timi"
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
# Notarization requires a secure timestamp; ad-hoc signing can't produce one.
TIMESTAMP_FLAG=""
[ "$IDENTITY" != "-" ] && TIMESTAMP_FLAG="--timestamp"
codesign --force --options runtime $TIMESTAMP_FLAG \
  --entitlements Packaging/Timi.entitlements \
  --sign "$IDENTITY" "$APP"

codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/Timi"
echo "==> done: $APP (version $VERSION)"
