# Timi

Timi is a pixel cat for macOS that also runs a focus timer. She sits on top of
your windows. Her body language shows the state of the timer, so the clock stays
hidden most of the time.

| Idle | Hunt | Finish | Nap | Loaf |
|---|---|---|---|---|
| ![Timi idle](Tests/snapshots/golden-timi-idle@3x.png) | ![Timi hunting](Tests/snapshots/golden-timi-hunt-crouch@3x.png) | ![Timi at the finish](Tests/snapshots/golden-timi-done-banner@3x.png) | ![Timi napping](Tests/snapshots/golden-timi-nap@3x.png) | ![Timi as a loaf](Tests/snapshots/golden-timi-loaf@3x.png) |

![Timi with the controls strip open](Tests/snapshots/hero-hover.png)

## What Timi does

- She breathes faster as a session continues. At the halfway point and when one
  quarter of the time remains, she hops and trills.
- After about 13 seconds without input, she curls into a ball and naps. She
  wakes for each milestone and for the last minute.
- In the last 10 seconds, she hunts. At 0:00 she pounces into confetti, has the
  zoomies, and then rests as a loaf.
- Each completed session earns a heart. The **♥×n** tally at the top left of her
  canvas counts the hearts of today.
- Between sessions, you can drag her, fling her, and pat her. She bounces off
  the screen edges, and she hisses if you throw her too hard.
- She uses about 1.5–2% CPU when idle
  ([measurements](docs/design.md#measurements)). She has no Dock icon and no
  network access.

## Install

```sh
brew install 2ls-llc/tap/timi
```

Apple did not notarize the current releases, so macOS blocks Timi the first
time you open her. To open Timi:

1. Open Timi from your Applications folder.
2. When macOS shows an alert, click **Done**.
3. Open **System Settings > Privacy & Security**.
4. Find the message about Timi.
5. Click **Open Anyway**.
6. If macOS asks for your password, enter it.

You must do these steps again after each update, until we sign and notarize
the releases. In Terminal, this command has the same result:

```sh
xattr -dr com.apple.quarantine /Applications/Timi.app
```

## Use

- **Tap** Timi to start the timer. Tap again to pause, and again to resume.
  After 0:00, a tap resets the timer.
- **Hold** Timi still for half a second to pat her. A pat never changes the
  timer.
- **Drag** Timi to move her, or **fling** her to make her bounce.
- **Scroll** over Timi while the timer is idle to change the length by 1 minute
  per step (1–90 minutes).
- **Hover** over Timi to show the controls strip. While the timer is idle, the
  strip has the presets (`30S`, `5M`, `15M`, `25M`), a `…` chip for a custom
  length, and mute. While the timer runs, it has pause, mute, and reset.
- Press **⌃⌥T** in any app to start, pause, or resume the timer.

The menu bar icon has a menu with every command and your heart counts.
**Settings** includes the hotkey, the sound, and the Cabinet Frame, a CRT stage
from the prototype. Settings also controls when Timi accepts clicks: on hover
(the default), only while you hold ⌥, or always.

## Build from source

```sh
git clone https://github.com/2ls-llc/timi && cd timi
./Packaging/build.sh          # writes dist/Timi.app
```

You need the full Xcode app. Versions before Xcode 16.3 cannot build Timi.

- [Developing Timi](docs/development.md) covers the requirements, the tests,
  the debug console, and the release process.
- The [design notes](docs/design.md) explain how the app ports the prototype.
- The [behavior reference](docs/behavior.md) lists each behavior and its
  constants.

## Credits

Timi started as a web prototype, `Prototype/mochi-timer.jsx`. ("Mochi" was her
working name.) The app keeps every constant of the prototype, with a small
number of documented changes for macOS.

Global hotkeys use
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre
Sorhus, under the MIT License.

© Two Ls LLC
