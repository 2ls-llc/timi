# Developing Timi

This document explains how to build, test, debug, and release Timi. For how the
app works, read the [design notes](design.md).

## Requirements

To build Timi, you need the full Xcode app. The Command Line Tools alone cannot
build Timi. A dependency uses SwiftUI `#Preview` macros, and their compiler
plugin is part of Xcode. KeyboardShortcuts 2.4.0 also needs Swift 6.1 or
later. Swift 6.1 first shipped with Xcode 16.3, so older versions of Xcode
cannot build Timi. The CI workflows use Xcode 26.2.

If the build fails with the error *external macro implementation type
'PreviewsMacros.SwiftUIView' could not be found*, do these steps:

1. If Xcode is not on your Mac, install it.
2. Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
3. Build again.

## Build and test

```sh
swift build            # debug build
swift test             # 116 tests: timer, physics, engine, DSP, canvas,
                       # session stats, formatting, persistence, and
                       # golden snapshots (Tests/snapshots/golden-*)
swift run Timi         # run without an app bundle (no notifications or login item)
./Packaging/build.sh   # dist/Timi.app
```

`dist/Timi.app` is universal (Apple silicon and Intel), sandboxed, and has an
ad-hoc signature.

## Debug console

Set `TIMI_DEBUG_DIR` to enable a debug console that reads commands from a file:

```sh
TIMI_DEBUG_DIR=/tmp/timi swift run Timi
```

Write commands to `/tmp/timi/cmd`, one command per line. The commands control
the app and save images of the panel. `Sources/Timi/App/DebugHarness.swift`
lists the commands. The console works only without the App Sandbox, for
example with `swift run`. The sandboxed app cannot read the folder.

## Releases

The scripts in `Packaging/` make a release:

```sh
./Packaging/build.sh                    # universal .app with an ad-hoc signature
CODESIGN_IDENTITY="Developer ID Application: …" ./Packaging/build.sh
APPLE_ID=… APPLE_TEAM_ID=… APP_PASSWORD=… ./Packaging/notarize.sh
VERSION=0.1.0 ./Packaging/release.sh    # zip and sha256 for the cask
```

Each push to `main`, and each pull request, runs `.github/workflows/ci.yml`.
This workflow runs the tests and the universal build.

A tag that begins with `v` runs `.github/workflows/release.yml`. This workflow
does these steps:

1. It runs the tests.
2. It builds the universal app.
3. If the signing secrets exist, it signs and notarizes the app. If they do not
   exist, it makes an ad-hoc build, and the release notes tell users how to
   open Timi the first time.
4. It publishes a GitHub release with the zip.
5. If the `TAP_GITHUB_TOKEN` secret exists, it opens a pull request that
   updates `Casks/timi.rb` in `2ls-llc/homebrew-tap`.
