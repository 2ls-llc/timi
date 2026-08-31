#!/bin/bash
# Zips dist/Timi.app for release and prints the sha256 for the Homebrew cask.
#   VERSION=0.1.0 ./Packaging/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP=dist/Timi.app
test -d "$APP" || { echo "run Packaging/build.sh first"; exit 1; }

ZIP="dist/Timi-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo "$SHA" > "$ZIP.sha256"
echo "==> $ZIP"
echo "    sha256: $SHA"
