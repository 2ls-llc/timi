#!/bin/bash
# Signs dist/Timi.app with a Developer ID certificate, notarizes it with
# notarytool, and staples the ticket. Run build.sh first with
# CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)".
#
# Required environment:
#   APPLE_ID        Apple ID email
#   APPLE_TEAM_ID   10-char team id
#   APP_PASSWORD    app-specific password for notarytool
# Optional:
#   CODESIGN_IDENTITY  re-sign here if build.sh signed ad-hoc
set -euo pipefail
cd "$(dirname "$0")/.."

APP=dist/Timi.app
test -d "$APP" || { echo "run Packaging/build.sh first"; exit 1; }
: "${APPLE_ID:?set APPLE_ID}"
: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
: "${APP_PASSWORD:?set APP_PASSWORD}"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "==> re-signing with $CODESIGN_IDENTITY"
  codesign --force --options runtime \
    --entitlements Packaging/Timi.entitlements \
    --sign "$CODESIGN_IDENTITY" "$APP"
fi

codesign --verify --deep --strict "$APP"

ZIP=dist/Timi-notarize.zip
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> notarytool submit (waits for Apple)"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APP_PASSWORD" \
  --wait

echo "==> stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
echo "==> notarized: $APP"
